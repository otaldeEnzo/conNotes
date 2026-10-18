use std::collections::HashMap;
use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;
use uuid::Uuid;

use crate::document::{Document, InkStroke, StrokePoint};
use crate::undo::UndoManager;

/// Sessão completa de documento contendo estado e histórico de undo
pub struct DocumentSession {
    pub document: Document,
    pub undo_manager: UndoManager,
}

impl DocumentSession {
    pub fn new() -> Self {
        Self {
            document: Document::new(),
            undo_manager: UndoManager::new(50),
        }
    }
}

/// Gerenciador Global de Instâncias de Sessões para FFI Multi-Aba
pub struct EngineContext {
    pub sessions: HashMap<Uuid, DocumentSession>,
}

impl EngineContext {
    pub fn new() -> Self {
        Self {
            sessions: HashMap::new(),
        }
    }
}

// Singleton seguro protegido por Mutex para chamadas C-ABI
static ENGINE: std::sync::OnceLock<Mutex<EngineContext>> = std::sync::OnceLock::new();

fn get_engine() -> &'static Mutex<EngineContext> {
    ENGINE.get_or_init(|| Mutex::new(EngineContext::new()))
}

fn lock_engine() -> std::sync::MutexGuard<'static, EngineContext> {
    get_engine()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn into_raw_cstring(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Cria um novo documento no motor nativo e retorna seu UUID como string C-ABI
#[no_mangle]
pub extern "C" fn connotes_create_document() -> *mut c_char {
    std::panic::catch_unwind(|| {
        let mut engine = lock_engine();
        let session = DocumentSession::new();
        let id = session.document.id;
        let id_str = id.to_string();

        engine.sessions.insert(id, session);
        into_raw_cstring(id_str)
    })
    .unwrap_or(std::ptr::null_mut())
}

/// Destrói um documento no motor nativo liberando todos os buffers da memória
#[no_mangle]
pub extern "C" fn connotes_destroy_document(doc_id_ptr: *const c_char) {
    if doc_id_ptr.is_null() {
        return;
    }
    let _ = std::panic::catch_unwind(|| {
        let c_str = unsafe { CStr::from_ptr(doc_id_ptr) };
        if let Ok(str_slice) = c_str.to_str() {
            if let Ok(id) = Uuid::parse_str(str_slice) {
                let mut engine = lock_engine();
                engine.sessions.remove(&id);
            }
        }
    });
}

/// Adiciona um traço com buffer de pontos contíguo transferido diretamente da memória do Dart (Zero-Copy)
#[no_mangle]
pub extern "C" fn connotes_add_stroke(
    doc_id_ptr: *const c_char,
    points_ptr: *const StrokePoint,
    points_count: usize,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    stroke_width: f32,
) -> *mut c_char {
    if doc_id_ptr.is_null() || points_ptr.is_null() || points_count == 0 {
        return std::ptr::null_mut();
    }

    std::panic::catch_unwind(|| {
        let c_str = unsafe { CStr::from_ptr(doc_id_ptr) };
        let str_slice = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };
        let doc_id = match Uuid::parse_str(str_slice) {
            Ok(id) => id,
            Err(_) => return std::ptr::null_mut(),
        };

        let points = unsafe { std::slice::from_raw_parts(points_ptr, points_count) }.to_vec();
        let stroke = InkStroke::new(points, [r, g, b, a], stroke_width);
        let stroke_id_str = stroke.id.to_string();

        let mut engine = lock_engine();
        if let Some(session) = engine.sessions.get_mut(&doc_id) {
            // O histórico de Undo/Redo primário é gerenciado incrementalmente por deltas no Dart (AppUndoManager),
            // evitando clonagem O(N) do documento inteiro a cada traço desenhado.
            session.document.add_stroke(stroke);
        }

        into_raw_cstring(stroke_id_str)
    })
    .unwrap_or(std::ptr::null_mut())
}

/// Duplicação paralela de traços no motor nativo via Rayon
#[no_mangle]
pub extern "C" fn connotes_duplicate_strokes(
    doc_id_ptr: *const c_char,
    ids_json_ptr: *const c_char,
    dx: f32,
    dy: f32,
) -> *mut c_char {
    if doc_id_ptr.is_null() || ids_json_ptr.is_null() {
        return std::ptr::null_mut();
    }

    std::panic::catch_unwind(|| {
        let c_str = unsafe { CStr::from_ptr(doc_id_ptr) };
        let doc_id = match Uuid::parse_str(c_str.to_str().unwrap_or("")) {
            Ok(id) => id,
            Err(_) => return std::ptr::null_mut(),
        };

        let ids_str = unsafe { CStr::from_ptr(ids_json_ptr) }.to_str().unwrap_or("[]");
        let ids: Vec<Uuid> = serde_json::from_str(ids_str).unwrap_or_default();

        let mut engine = lock_engine();
        if let Some(session) = engine.sessions.get_mut(&doc_id) {
            let new_ids = session.document.duplicate_strokes_parallel(&ids, dx, dy);
            let result_json = serde_json::to_string(&new_ids).unwrap_or_else(|_| "[]".to_string());
            return into_raw_cstring(result_json);
        }

        into_raw_cstring("[]".to_string())
    })
    .unwrap_or(std::ptr::null_mut())
}

/// Desfaz (Undo) no documento nativo
#[no_mangle]
pub extern "C" fn connotes_undo(doc_id_ptr: *const c_char) -> bool {
    if doc_id_ptr.is_null() {
        return false;
    }
    std::panic::catch_unwind(|| {
        let doc_id = match Uuid::parse_str(unsafe { CStr::from_ptr(doc_id_ptr) }.to_str().unwrap_or("")) {
            Ok(id) => id,
            Err(_) => return false,
        };

        let mut engine = lock_engine();
        if let Some(session) = engine.sessions.get_mut(&doc_id) {
            if let Some(restored) = session.undo_manager.undo(&session.document) {
                session.document = restored;
                return true;
            }
        }
        false
    })
    .unwrap_or(false)
}

/// Refaz (Redo) no documento nativo
#[no_mangle]
pub extern "C" fn connotes_redo(doc_id_ptr: *const c_char) -> bool {
    if doc_id_ptr.is_null() {
        return false;
    }
    std::panic::catch_unwind(|| {
        let doc_id = match Uuid::parse_str(unsafe { CStr::from_ptr(doc_id_ptr) }.to_str().unwrap_or("")) {
            Ok(id) => id,
            Err(_) => return false,
        };

        let mut engine = lock_engine();
        if let Some(session) = engine.sessions.get_mut(&doc_id) {
            if let Some(restored) = session.undo_manager.redo(&session.document) {
                session.document = restored;
                return true;
            }
        }
        false
    })
    .unwrap_or(false)
}

/// Libera uma string alocada pelo Rust
#[no_mangle]
pub extern "C" fn connotes_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = std::panic::catch_unwind(|| unsafe {
            let _ = CString::from_raw(ptr);
        });
    }
}



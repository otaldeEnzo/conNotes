use std::fs;
use std::path::{Path, PathBuf};
use crate::types::{FolderItem, NoteItem};

pub fn get_vault_dir() -> PathBuf {
    let mut dir = dirs::document_dir().unwrap_or_else(|| PathBuf::from("."));
    dir.push("ConnectedNotesVault");
    if !dir.exists() {
        let _ = fs::create_dir_all(&dir);
    }
    dir
}

pub fn sanitize_filename(name: &str) -> String {
    let sanitized: String = name
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
            other => other,
        })
        .collect();
    let trimmed = sanitized.trim();
    if trimmed.is_empty() {
        "Sem_Titulo".to_string()
    } else {
        trimmed.to_string()
    }
}

// Export all notes and folders into the local Vault directory mirroring the sidebar hierarchy
pub fn sync_vault_to_disk(folders: &[FolderItem], notes: &[NoteItem]) -> Result<(), String> {
    let vault_root = get_vault_dir();

    // 1. Collect expected valid paths for active folders and notes
    let mut valid_paths = std::collections::HashSet::new();
    valid_paths.insert(vault_root.clone());
    for folder in folders.iter().filter(|f| f.parent_id.is_none()) {
        collect_folder_paths(folder, folders, notes, &vault_root, &mut valid_paths);
    }
    for note in notes.iter().filter(|n| n.folder_id.is_none() && n.parent_id.is_none()) {
        collect_note_paths(note, notes, &vault_root, &mut valid_paths);
    }

    // 2. Remove files and directories in vault_root that are no longer in valid_paths
    clean_orphans(&vault_root, &valid_paths);

    // 3. Export root folders and their nested contents
    for folder in folders.iter().filter(|f| f.parent_id.is_none()) {
        sync_folder_recursive(folder, folders, notes, &vault_root)?;
    }

    // 4. Export root standalone notes (notes with no folder and no parent note)
    for note in notes.iter().filter(|n| n.folder_id.is_none() && n.parent_id.is_none()) {
        sync_note_hierarchy(note, notes, &vault_root)?;
    }

    Ok(())
}

fn collect_folder_paths(
    folder: &FolderItem,
    all_folders: &[FolderItem],
    all_notes: &[NoteItem],
    parent_path: &Path,
    valid_paths: &mut std::collections::HashSet<PathBuf>,
) {
    let folder_name = sanitize_filename(&folder.name);
    let folder_dir = parent_path.join(&folder_name);
    valid_paths.insert(folder_dir.clone());

    for sub_folder in all_folders.iter().filter(|f| f.parent_id == Some(folder.id)) {
        collect_folder_paths(sub_folder, all_folders, all_notes, &folder_dir, valid_paths);
    }

    for note in all_notes.iter().filter(|n| n.folder_id == Some(folder.id) && n.parent_id.is_none()) {
        collect_note_paths(note, all_notes, &folder_dir, valid_paths);
    }
}

fn collect_note_paths(
    note: &NoteItem,
    all_notes: &[NoteItem],
    parent_dir: &Path,
    valid_paths: &mut std::collections::HashSet<PathBuf>,
) {
    let note_title = sanitize_filename(&note.title);
    let sub_notes: Vec<&NoteItem> = all_notes.iter().filter(|n| n.parent_id == Some(note.id)).collect();

    if sub_notes.is_empty() {
        let file_path = parent_dir.join(format!("{}.cncanvas", note_title));
        valid_paths.insert(file_path);
    } else {
        let note_folder = parent_dir.join(&note_title);
        valid_paths.insert(note_folder.clone());
        let parent_file_path = note_folder.join(format!("{}.cncanvas", note_title));
        valid_paths.insert(parent_file_path);
        for sub in sub_notes {
            collect_note_paths(sub, all_notes, &note_folder, valid_paths);
        }
    }
}

fn clean_orphans(dir: &Path, valid_paths: &std::collections::HashSet<PathBuf>) {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with('.') {
                    continue;
                }
                clean_orphans(&path, valid_paths);
                if !valid_paths.contains(&path) {
                    let _ = fs::remove_dir_all(&path);
                }
            } else if path.extension().map_or(false, |ext| ext == "cncanvas") {
                if !valid_paths.contains(&path) {
                    let _ = fs::remove_file(&path);
                }
            }
        }
    }
}

fn sync_folder_recursive(
    folder: &FolderItem,
    all_folders: &[FolderItem],
    all_notes: &[NoteItem],
    parent_path: &Path,
) -> Result<(), String> {
    let folder_name = sanitize_filename(&folder.name);
    let folder_dir = parent_path.join(&folder_name);
    if !folder_dir.exists() {
        fs::create_dir_all(&folder_dir).map_err(|e| e.to_string())?;
    }

    // Sub-folders
    for sub_folder in all_folders.iter().filter(|f| f.parent_id == Some(folder.id)) {
        sync_folder_recursive(sub_folder, all_folders, all_notes, &folder_dir)?;
    }

    // Direct notes in this folder that have no parent note
    for note in all_notes.iter().filter(|n| n.folder_id == Some(folder.id) && n.parent_id.is_none()) {
        sync_note_hierarchy(note, all_notes, &folder_dir)?;
    }

    Ok(())
}

fn sync_note_hierarchy(
    note: &NoteItem,
    all_notes: &[NoteItem],
    parent_dir: &Path,
) -> Result<(), String> {
    let note_title = sanitize_filename(&note.title);
    let sub_notes: Vec<&NoteItem> = all_notes.iter().filter(|n| n.parent_id == Some(note.id)).collect();

    if sub_notes.is_empty() {
        // Simple note file: e.g. "Calculo.cncanvas"
        let file_path = parent_dir.join(format!("{}.cncanvas", note_title));
        save_note_file(note, &file_path)?;
    } else {
        // Parent note with sub-notes: create a directory named after parent note
        let note_folder = parent_dir.join(&note_title);
        if !note_folder.exists() {
            fs::create_dir_all(&note_folder).map_err(|e| e.to_string())?;
        }

        // Save parent note inside its directory
        let parent_file_path = note_folder.join(format!("{}.cncanvas", note_title));
        save_note_file(note, &parent_file_path)?;

        // Save all sub-notes inside the parent note directory
        for sub in sub_notes {
            sync_note_hierarchy(sub, all_notes, &note_folder)?;
        }
    }

    Ok(())
}

pub fn save_note_file(note: &NoteItem, path: &Path) -> Result<(), String> {
    let json_content = serde_json::to_string_pretty(note).map_err(|e| e.to_string())?;
    fs::write(path, json_content).map_err(|e| e.to_string())
}

pub fn load_note_from_file(path: &Path) -> Result<NoteItem, String> {
    let content = fs::read_to_string(path).map_err(|e| e.to_string())?;
    let note: NoteItem = serde_json::from_str(&content).map_err(|e| e.to_string())?;
    Ok(note)
}

pub fn load_vault_from_disk() -> (Vec<FolderItem>, Vec<NoteItem>) {
    let vault_root = get_vault_dir();
    let mut folders = Vec::new();
    let mut notes = Vec::new();

    if vault_root.exists() {
        scan_dir_recursive(&vault_root, None, None, &mut folders, &mut notes);
    }

    (folders, notes)
}

fn scan_dir_recursive(
    dir: &Path,
    parent_folder_id: Option<usize>,
    parent_note_id: Option<usize>,
    folders: &mut Vec<FolderItem>,
    notes: &mut Vec<NoteItem>,
) {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                let folder_name = entry.file_name().to_string_lossy().to_string();
                if folder_name.starts_with('.') {
                    continue;
                }
                let next_folder_id = folders.len() + 1;
                let folder_item = FolderItem {
                    id: next_folder_id,
                    name: folder_name,
                    expanded: true,
                    parent_id: parent_folder_id,
                };
                folders.push(folder_item);

                scan_dir_recursive(&path, Some(next_folder_id), parent_note_id, folders, notes);
            } else if path.extension().map_or(false, |ext| ext == "cncanvas") {
                if let Ok(mut note) = load_note_from_file(&path) {
                    note.folder_id = parent_folder_id;
                    note.parent_id = parent_note_id;
                    notes.push(note);
                }
            }
        }
    }
}

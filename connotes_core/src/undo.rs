use std::sync::Arc;
use crate::document::Document;

/// Instantâneo imutável de estado do documento usando Structural Sharing (Copy-on-Write com Arc).
/// Permite Undo/Redo instantâneo com custo de memória de apenas alguns bytes por operação.
#[derive(Debug, Clone)]
pub struct UndoManager {
    undo_stack: Vec<Arc<Document>>,
    redo_stack: Vec<Arc<Document>>,
    max_history: usize,
}

impl UndoManager {
    pub fn new(max_history: usize) -> Self {
        Self {
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            max_history: if max_history == 0 { 50 } else { max_history },
        }
    }

    /// Salva o estado atual na pilha de Undo antes de uma modificação destrutiva
    pub fn push_snapshot(&mut self, doc: &Document) {
        self.undo_stack.push(Arc::new(doc.clone()));
        if self.undo_stack.len() > self.max_history {
            self.undo_stack.remove(0);
        }
        // Uma nova ação invalida o redo futuro
        self.redo_stack.clear();
    }

    /// Desfaz a última ação restaurando o documento anterior e salvando o atual no Redo
    pub fn undo(&mut self, current_doc: &Document) -> Option<Document> {
        if let Some(prev_state) = self.undo_stack.pop() {
            self.redo_stack.push(Arc::new(current_doc.clone()));
            let mut restored = (*prev_state).clone();
            restored.rebuild_indexes();
            Some(restored)
        } else {
            None
        }
    }

    /// Refaz a ação desfeita
    pub fn redo(&mut self, current_doc: &Document) -> Option<Document> {
        if let Some(next_state) = self.redo_stack.pop() {
            self.undo_stack.push(Arc::new(current_doc.clone()));
            let mut restored = (*next_state).clone();
            restored.rebuild_indexes();
            Some(restored)
        } else {
            None
        }
    }

    pub fn can_undo(&self) -> bool {
        !self.undo_stack.is_empty()
    }

    pub fn can_redo(&self) -> bool {
        !self.redo_stack.is_empty()
    }

    pub fn clear(&mut self) {
        self.undo_stack.clear();
        self.redo_stack.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::document::{InkStroke, StrokePoint};

    #[test]
    fn test_undo_redo_stack() {
        let mut undo_mgr = UndoManager::new(10);
        let mut doc = Document::new();

        // 1. Snapshot do estado vazio
        undo_mgr.push_snapshot(&doc);

        // 2. Adiciona traço
        let stroke = InkStroke::new(
            vec![StrokePoint { x: 0.0, y: 0.0, pressure: 1.0, timestamp: 0 }],
            [1.0, 1.0, 1.0, 1.0],
            2.0,
        );
        doc.add_stroke(stroke);
        assert_eq!(doc.strokes.len(), 1);

        // 3. Undo -> Volta ao estado vazio
        let restored_doc = undo_mgr.undo(&doc).expect("Undo failed");
        assert_eq!(restored_doc.strokes.len(), 0);

        // 4. Redo -> Volta a ter 1 traço
        let redo_doc = undo_mgr.redo(&restored_doc).expect("Redo failed");
        assert_eq!(redo_doc.strokes.len(), 1);
    }
}

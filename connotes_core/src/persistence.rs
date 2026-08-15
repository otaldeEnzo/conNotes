use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use crate::document::Document;

/// Versão do formato binário de arquivo .connote
pub const CONNOTE_BINARY_VERSION: u32 = 1;
pub const CONNOTE_MAGIC_HEADER: &[u8; 8] = b"CONNOTE\0";

pub struct Persistence;

impl Persistence {
    /// Salva o documento de forma ultra-compacta no formato binário .connote com cabeçalho mágico e versionamento.
    pub fn save_to_file<P: AsRef<Path>>(doc: &Document, path: P) -> Result<(), std::io::Error> {
        let mut file = File::create(path)?;
        
        // Escreve cabeçalho mágico (8 bytes)
        file.write_all(CONNOTE_MAGIC_HEADER)?;
        // Escreve versão do formato (4 bytes)
        file.write_all(&CONNOTE_BINARY_VERSION.to_le_bytes())?;

        // Serializa os dados do documento com bincode
        let encoded_bytes = bincode::serialize(doc).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        file.write_all(&encoded_bytes)?;
        file.flush()?;

        Ok(())
    }

    /// Salva o documento de forma assíncrona em uma thread do pool Rayon sem congelar a UI.
    pub fn save_async<P: AsRef<Path> + Send + 'static>(doc: Document, path: P) {
        rayon::spawn(move || {
            if let Err(e) = Self::save_to_file(&doc, path) {
                eprintln!("[connotes_core] Erro no auto-save assíncrono: {:?}", e);
            }
        });
    }

    /// Carrega o documento do arquivo binário .connote e reconstrói os índices espaciais em O(N).
    pub fn load_from_file<P: AsRef<Path>>(path: P) -> Result<Document, std::io::Error> {
        let mut file = File::open(path)?;
        let mut header = [0u8; 8];
        file.read_exact(&mut header)?;

        if &header != CONNOTE_MAGIC_HEADER {
            return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "Magic header inválido"));
        }

        let mut version_bytes = [0u8; 4];
        file.read_exact(&mut version_bytes)?;
        let _version = u32::from_le_bytes(version_bytes);

        let mut payload = Vec::new();
        file.read_to_end(&mut payload)?;

        let mut doc: Document = bincode::deserialize(&payload).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        doc.rebuild_indexes();

        Ok(doc)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::document::{InkStroke, StrokePoint};

    #[test]
    fn test_binary_save_load() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_note.connote");

        let mut doc = Document::new();
        let stroke = InkStroke::new(
            vec![
                StrokePoint { x: 123.4, y: 567.8, pressure: 0.9, timestamp: 42 },
            ],
            [0.0, 1.0, 0.5, 1.0],
            3.5,
        );
        doc.add_stroke(stroke);

        // Salva
        Persistence::save_to_file(&doc, &file_path).expect("Falha ao salvar");

        // Carrega
        let loaded_doc = Persistence::load_from_file(&file_path).expect("Falha ao carregar");
        assert_eq!(loaded_doc.strokes.len(), 1);
        assert_eq!(loaded_doc.strokes[0].points[0].x, 123.4);
        assert_eq!(loaded_doc.strokes[0].points[0].y, 567.8);

        // Limpa arquivo temporário
        let _ = std::fs::remove_file(file_path);
    }
}

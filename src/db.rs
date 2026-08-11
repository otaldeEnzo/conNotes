use crate::{Connector, FolderItem, NoteCard, NoteItem, Point, Stroke};
use rusqlite::{Connection, Result, params};
use serde_json;

pub fn init_db(db_path: &str) -> Result<Connection> {
    let conn = Connection::open(db_path)?;
    conn.busy_timeout(std::time::Duration::from_millis(3000))
        .ok();

    println!("init_db: calling execute_batch...");
    conn.execute_batch(
        "PRAGMA foreign_keys = ON;
        
        CREATE TABLE IF NOT EXISTS folders (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            expanded INTEGER NOT NULL DEFAULT 1,
            parent_id INTEGER
        );

        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            parent_id INTEGER,
            folder_id INTEGER,
            icon TEXT NOT NULL,
            tags TEXT NOT NULL,
            paper_mode TEXT
        );

        CREATE TABLE IF NOT EXISTS cards (
            id INTEGER PRIMARY KEY,
            note_id INTEGER NOT NULL,
            number TEXT NOT NULL,
            card_type TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            x REAL NOT NULL,
            y REAL NOT NULL,
            width REAL NOT NULL,
            height REAL NOT NULL,
            selected INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS connectors (
            id INTEGER PRIMARY KEY,
            note_id INTEGER NOT NULL,
            from_id INTEGER NOT NULL,
            to_id INTEGER NOT NULL,
            color TEXT NOT NULL,
            FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS strokes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id INTEGER NOT NULL,
            points TEXT NOT NULL,
            color TEXT NOT NULL,
            thickness REAL NOT NULL,
            is_highlighter INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS user_profile (
            user_id TEXT PRIMARY KEY,
            device_name TEXT NOT NULL,
            secret_pin TEXT NOT NULL,
            created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS trusted_devices (
            device_id TEXT PRIMARY KEY,
            device_name TEXT NOT NULL,
            paired_at TEXT NOT NULL
        );
        
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );",
    )?;

    println!("init_db: execute_batch FINISHED!");

    Ok(conn)
}

pub fn seed_default_data() -> (Vec<FolderItem>, Vec<NoteItem>) {
    let folders = vec![
        FolderItem {
            id: 1,
            name: "Física Quântica".to_string(),
            expanded: true,
            parent_id: None,
        },
        FolderItem {
            id: 2,
            name: "Cálculo & Análise".to_string(),
            expanded: true,
            parent_id: None,
        },
    ];

    let notes = vec![
        NoteItem {
            id: 1,
            title: "Dinamica Quantica".to_string(),
            parent_id: None,
            folder_id: Some(1),
            icon: "math".to_string(),
            tags: vec!["#fisica".to_string(), "#quantica".to_string()],
            cards: vec![
                NoteCard {
                    id: 1,
                    number: "1".to_string(),
                    card_type: "text".to_string(),
                    title: "Physics Formulas".to_string(),
                    content: "∫₀^∞ e^-x³ dx = √π / 2".to_string(),
                    x: 320.0,
                    y: 140.0,
                    width: 300.0,
                    height: 180.0,
                    selected: false,
                    collapsed: false,
                    locked: false,
                    accent_color: None,
                },
                NoteCard {
                    id: 2,
                    number: "2".to_string(),
                    card_type: "plot".to_string(),
                    title: "f(x) = e^{-0.1x} sin(x)".to_string(),
                    content: "".to_string(),
                    x: 560.0,
                    y: 260.0,
                    width: 380.0,
                    height: 320.0,
                    selected: true,
                    collapsed: false,
                    locked: false,
                    accent_color: None,
                },
            ],
            connectors: vec![Connector {
                id: 101,
                from_id: 1,
                to_id: 2,
                color: "#00e1ff".to_string(),
                label: None,
                line_style: None,
            }],
            strokes: vec![],
            paper_mode: Some(crate::types::PaperMode::DotGrid),
            note_type: None,
        },
        NoteItem {
            id: 10,
            title: "Subnota: Matriz Densidade".to_string(),
            parent_id: Some(1),
            folder_id: Some(1),
            icon: "math".to_string(),
            tags: vec!["#quantica".to_string()],
            cards: vec![NoteCard {
                id: 101,
                number: "1".to_string(),
                card_type: "text".to_string(),
                title: "Operador de Densidade".to_string(),
                content: "ρ = ∑ p_i |ψ_i⟩⟨ψ_i|".to_string(),
                x: 340.0,
                y: 160.0,
                width: 320.0,
                height: 180.0,
                selected: true,
                collapsed: false,
                locked: false,
                accent_color: None,
            }],
            connectors: vec![],
            strokes: vec![],
            paper_mode: Some(crate::types::PaperMode::DotGrid),
            note_type: None,
        },
        NoteItem {
            id: 2,
            title: "Simulacao Python".to_string(),
            parent_id: None,
            folder_id: Some(1),
            icon: "code".to_string(),
            tags: vec!["#codigo".to_string(), "#python".to_string()],
            cards: vec![NoteCard {
                id: 3,
                number: "3".to_string(),
                card_type: "code".to_string(),
                title: "Python Code".to_string(),
                content:
                    "def quantum_sim(params):\n    ...\n    params = Invarf()\n    return (ix)"
                        .to_string(),
                x: 400.0,
                y: 200.0,
                width: 340.0,
                height: 220.0,
                selected: false,
                collapsed: false,
                locked: false,
                accent_color: None,
            }],
            connectors: vec![],
            strokes: vec![],
            paper_mode: Some(crate::types::PaperMode::DotGrid),
            note_type: None,
        },
        NoteItem {
            id: 3,
            title: "Series de Taylor".to_string(),
            parent_id: None,
            folder_id: Some(2),
            icon: "plot".to_string(),
            tags: vec!["#calculo".to_string(), "#matematica".to_string()],
            cards: vec![NoteCard {
                id: 4,
                number: "1".to_string(),
                card_type: "text".to_string(),
                title: "Aproximação de Taylor".to_string(),
                content: "Fórmula de Taylor:\nf(x) = ∑ \\frac{f^{(n)}{a}}{n!} (x-a)^n".to_string(),
                x: 350.0,
                y: 180.0,
                width: 320.0,
                height: 190.0,
                selected: false,
                collapsed: false,
                locked: false,
                accent_color: None,
            }],
            connectors: vec![],
            strokes: vec![],
            paper_mode: Some(crate::types::PaperMode::DotGrid),
            note_type: None,
        },
    ];

    (folders, notes)
}

pub fn save_all(conn: &mut Connection, folders: &[FolderItem], notes: &[NoteItem]) -> Result<()> {
    let tx = conn.transaction()?;

    tx.execute("DELETE FROM strokes", [])?;
    tx.execute("DELETE FROM connectors", [])?;
    tx.execute("DELETE FROM cards", [])?;
    tx.execute("DELETE FROM notes", [])?;
    tx.execute("DELETE FROM folders", [])?;

    for folder in folders {
        tx.execute(
            "INSERT INTO folders (id, name, expanded, parent_id) VALUES (?1, ?2, ?3, ?4)",
            params![
                folder.id,
                folder.name,
                if folder.expanded { 1 } else { 0 },
                folder.parent_id
            ],
        )?;
    }

    for note in notes {
        let tags_json = serde_json::to_string(&note.tags).unwrap_or_else(|_| "[]".to_string());
        let paper_mode_str = note.paper_mode.as_ref().map(|p| serde_json::to_string(p).unwrap_or_default());
        tx.execute(
            "INSERT INTO notes (id, title, parent_id, folder_id, icon, tags, paper_mode) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![note.id, note.title, note.parent_id, note.folder_id, note.icon, tags_json, paper_mode_str],
        )?;

        for card in &note.cards {
            tx.execute(
                "INSERT INTO cards (id, note_id, number, card_type, title, content, x, y, width, height, selected)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
                params![
                    card.id,
                    note.id,
                    card.number,
                    card.card_type,
                    card.title,
                    card.content,
                    card.x,
                    card.y,
                    card.width,
                    card.height,
                    if card.selected { 1 } else { 0 }
                ],
            )?;
        }

        for connector in &note.connectors {
            tx.execute(
                "INSERT INTO connectors (id, note_id, from_id, to_id, color) VALUES (?1, ?2, ?3, ?4, ?5)",
                params![connector.id, note.id, connector.from_id, connector.to_id, connector.color],
            )?;
        }

        for stroke in &note.strokes {
            let points_json =
                serde_json::to_string(&stroke.points).unwrap_or_else(|_| "[]".to_string());
            tx.execute(
                "INSERT INTO strokes (note_id, points, color, thickness, is_highlighter) VALUES (?1, ?2, ?3, ?4, ?5)",
                params![
                    note.id,
                    points_json,
                    stroke.color,
                    stroke.thickness,
                    if stroke.is_highlighter { 1 } else { 0 }
                ],
            )?;
        }
    }

    tx.commit()?;
    Ok(())
}

pub fn load_all(conn: &Connection) -> Result<(Vec<FolderItem>, Vec<NoteItem>)> {
    println!("load_all: START");
    let mut stmt_folders =
        conn.prepare("SELECT id, name, expanded, parent_id FROM folders ORDER BY id ASC")?;
    let folder_rows = stmt_folders.query_map([], |row| {
        let expanded_int: i32 = row.get(2)?;
        Ok(FolderItem {
            id: row.get(0)?,
            name: row.get(1)?,
            expanded: expanded_int != 0,
            parent_id: row.get(3)?,
        })
    })?;

    let mut folders = Vec::new();
    for f in folder_rows {
        folders.push(f?);
    }

    let mut stmt_notes = conn
        .prepare("SELECT id, title, parent_id, folder_id, icon, tags, paper_mode FROM notes ORDER BY id ASC")?;
    let note_rows = stmt_notes.query_map([], |row| {
        let tags_json: String = row.get(5)?;
        let tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();
        let pm_str: Option<String> = row.get(6).ok();
        let paper_mode: Option<crate::types::PaperMode> = pm_str.and_then(|s| serde_json::from_str(&s).ok());
        Ok((
            row.get::<_, usize>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, Option<usize>>(2)?,
            row.get::<_, Option<usize>>(3)?,
            row.get::<_, String>(4)?,
            tags,
            paper_mode,
        ))
    })?;

    let mut notes = Vec::new();
    for n in note_rows {
        let (id, title, parent_id, folder_id, icon, tags, paper_mode) = n?;

        // Load cards
        let mut stmt_cards = conn.prepare(
            "SELECT id, number, card_type, title, content, x, y, width, height, selected FROM cards WHERE note_id = ?1 ORDER BY id ASC",
        )?;
        let card_rows = stmt_cards.query_map(params![id], |row| {
            let sel_int: i32 = row.get(9)?;
            let raw_type: String = row.get(2)?;
            let card_type = if raw_type == "math" { "text".to_string() } else { raw_type };
            Ok(NoteCard {
                id: row.get(0)?,
                number: row.get(1)?,
                card_type,
                title: row.get(3)?,
                content: row.get(4)?,
                x: row.get(5)?,
                y: row.get(6)?,
                width: row.get(7)?,
                height: row.get(8)?,
                selected: sel_int != 0,
                collapsed: false,
                locked: false,
                accent_color: None,
            })
        })?;
        let mut cards = Vec::new();
        for c in card_rows {
            cards.push(c?);
        }

        // Load connectors
        let mut stmt_conn = conn.prepare(
            "SELECT id, from_id, to_id, color FROM connectors WHERE note_id = ?1 ORDER BY id ASC",
        )?;
        let conn_rows = stmt_conn.query_map(params![id], |row| {
            Ok(Connector {
                id: row.get(0)?,
                from_id: row.get(1)?,
                to_id: row.get(2)?,
                color: row.get(3)?,
                label: None,
                line_style: None,
            })
        })?;
        let mut connectors = Vec::new();
        for cn in conn_rows {
            connectors.push(cn?);
        }

        // Load strokes
        let mut stmt_strokes = conn.prepare(
            "SELECT points, color, thickness, is_highlighter FROM strokes WHERE note_id = ?1 ORDER BY id ASC",
        )?;
        let stroke_rows = stmt_strokes.query_map(params![id], |row| {
            let points_json: String = row.get(0)?;
            let points: Vec<Point> = serde_json::from_str(&points_json).unwrap_or_default();
            let hl_int: i32 = row.get(3)?;
            Ok(Stroke {
                points,
                color: row.get(1)?,
                thickness: row.get(2)?,
                is_highlighter: hl_int != 0,
            })
        })?;
        let mut strokes = Vec::new();
        for st in stroke_rows {
            strokes.push(st?);
        }

        notes.push(NoteItem {
            id,
            title,
            parent_id,
            folder_id,
            icon,
            cards,
            connectors,
            strokes,
            tags,
            paper_mode,
            note_type: None,
        });
    }

    Ok((folders, notes))
}

pub fn load_user_profile(conn: &Connection) -> Result<Option<crate::types::UserProfile>> {
    let mut stmt = conn.prepare("SELECT user_id, device_name, secret_pin, created_at FROM user_profile LIMIT 1")?;
    let mut rows = stmt.query_map([], |row| {
        Ok(crate::types::UserProfile {
            user_id: row.get(0)?,
            device_name: row.get(1)?,
            secret_pin: row.get(2)?,
            created_at: row.get(3)?,
        })
    })?;
    if let Some(user) = rows.next() {
        return Ok(Some(user?));
    }
    Ok(None)
}

pub fn save_user_profile(conn: &Connection, profile: &crate::types::UserProfile) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO user_profile (user_id, device_name, secret_pin, created_at) VALUES (?1, ?2, ?3, ?4)",
        params![profile.user_id, profile.device_name, profile.secret_pin, profile.created_at],
    )?;
    Ok(())
}

pub fn add_trusted_device(conn: &Connection, device: &crate::types::DeviceItem) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO trusted_devices (device_id, device_name, paired_at) VALUES (?1, ?2, ?3)",
        params![device.device_id, device.device_name, device.paired_at],
    )?;
    Ok(())
}

pub fn get_trusted_devices(conn: &Connection) -> Result<Vec<crate::types::DeviceItem>> {
    let mut stmt = conn.prepare("SELECT device_id, device_name, paired_at FROM trusted_devices")?;
    let rows = stmt.query_map([], |row| {
        Ok(crate::types::DeviceItem {
            device_id: row.get(0)?,
            device_name: row.get(1)?,
            paired_at: row.get(2)?,
        })
    })?;
    let mut list = Vec::new();
    for r in rows {
        list.push(r?);
    }
    Ok(list)
}

pub fn get_vault_stats(conn: &Connection) -> Result<(usize, usize, String)> {
    let mut notes_count = 0;
    let mut cards_count = 0;
    
    if let Ok(mut stmt) = conn.prepare("SELECT COUNT(*) FROM notes") {
        if let Ok(mut rows) = stmt.query([]) {
            if let Some(row) = rows.next().unwrap_or(None) {
                notes_count = row.get::<_, usize>(0).unwrap_or(0);
            }
        }
    }
    
    if let Ok(mut stmt) = conn.prepare("SELECT COUNT(*) FROM cards") {
        if let Ok(mut rows) = stmt.query([]) {
            if let Some(row) = rows.next().unwrap_or(None) {
                cards_count = row.get::<_, usize>(0).unwrap_or(0);
            }
        }
    }
    
    // Fake disk size for now
    let size = "2.4 MB".to_string();
    
    Ok((notes_count, cards_count, size))
}
pub fn backup_vault(source_path: &str, dest_path: &str) -> std::io::Result<u64> {
    std::fs::copy(source_path, dest_path)
}

pub fn restore_vault(backup_path: &str, target_path: &str) -> std::io::Result<u64> {
    std::fs::copy(backup_path, target_path)
}

pub fn rename_global_tag(conn: &Connection, old_tag: &str, new_tag: &str) -> Result<()> {
    let mut stmt = conn.prepare("SELECT id, tags FROM notes")?;
    let mut notes_to_update = Vec::new();
    let rows = stmt.query_map([], |row| {
        let id: usize = row.get(0)?;
        let tags_json: String = row.get(1)?;
        Ok((id, tags_json))
    })?;
    for row in rows {
        if let Ok((id, tags_json)) = row {
            let mut tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();
            let mut modified = false;
            for t in tags.iter_mut() {
                if t == old_tag {
                    *t = new_tag.to_string();
                    modified = true;
                }
            }
            if modified {
                notes_to_update.push((id, serde_json::to_string(&tags).unwrap_or_default()));
            }
        }
    }
    for (id, new_json) in notes_to_update {
        conn.execute("UPDATE notes SET tags = ?1 WHERE id = ?2", params![new_json, id])?;
    }
    Ok(())
}

pub fn merge_global_tags(conn: &Connection, tag1: &str, tag2: &str, merged_tag: &str) -> Result<()> {
    let mut stmt = conn.prepare("SELECT id, tags FROM notes")?;
    let mut notes_to_update = Vec::new();
    let rows = stmt.query_map([], |row| {
        let id: usize = row.get(0)?;
        let tags_json: String = row.get(1)?;
        Ok((id, tags_json))
    })?;
    for row in rows {
        if let Ok((id, tags_json)) = row {
            let tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();
            let mut modified = false;
            let mut new_tags = Vec::new();
            let mut has_merged = false;
            for t in tags {
                if t == tag1 || t == tag2 {
                    if !has_merged {
                        new_tags.push(merged_tag.to_string());
                        has_merged = true;
                        modified = true;
                    } else {
                        modified = true;
                    }
                } else {
                    new_tags.push(t);
                }
            }
            if modified {
                notes_to_update.push((id, serde_json::to_string(&new_tags).unwrap_or_default()));
            }
        }
    }
    for (id, new_json) in notes_to_update {
        conn.execute("UPDATE notes SET tags = ?1 WHERE id = ?2", params![new_json, id])?;
    }
    Ok(())
}

pub fn load_setting(conn: &Connection, key: &str) -> Result<Option<String>> {
    let mut stmt = conn.prepare("SELECT value FROM settings WHERE key = ?1")?;
    let mut rows = stmt.query_map(params![key], |row| {
        row.get::<_, String>(0)
    })?;
    if let Some(Ok(val)) = rows.next() {
        return Ok(Some(val));
    }
    Ok(None)
}

pub fn save_setting(conn: &Connection, key: &str, value: &str) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        params![key, value],
    )?;
    Ok(())
}

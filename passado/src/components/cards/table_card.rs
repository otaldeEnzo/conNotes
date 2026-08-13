use crate::types::*;
use crate::icons::*;
use dioxus::prelude::*;

#[component]
pub fn TableCard(card: NoteCard) -> Element {
    let mut rows = use_signal(|| vec![
        vec!["Item".to_string(), "Valor".to_string(), "Status".to_string()],
        vec!["Projeto A".to_string(), "100".to_string(), "Concluído".to_string()],
        vec!["Projeto B".to_string(), "250".to_string(), "Em andamento".to_string()],
    ]);

    let add_row = move |_| {
        rows.with_mut(|r| {
            let col_count = if let Some(first) = r.first() {
                first.len()
            } else {
                3
            };
            r.push(vec!["".to_string(); col_count]);
        });
    };

    let remove_row = move |_| {
        rows.with_mut(|r| {
            if r.len() > 1 {
                r.pop();
            }
        });
    };

    let add_col = move |_| {
        rows.with_mut(|r| {
            for row in r.iter_mut() {
                row.push("".to_string());
            }
        });
    };

    let remove_col = move |_| {
        rows.with_mut(|r| {
            if let Some(first) = r.first() {
                if first.len() > 1 {
                    for row in r.iter_mut() {
                        row.pop();
                    }
                }
            }
        });
    };

    rsx! {
        div { class: "card-content-table", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 8px;",
            div { style: "display: flex; gap: 6px; flex-wrap: wrap; align-items: center; justify-content: space-between;",
                div { style: "display: flex; gap: 4px;",
                    button {
                        style: "background: var(--glass-bg); border: 1px solid var(--accent-cyan); color: var(--accent-cyan); border-radius: 6px; padding: 2px 8px; font-size: 11px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 4px;",
                        onclick: add_row,
                        IconPlus {}
                        " Linha"
                    }
                    button {
                        style: "background: var(--glass-bg); border: 1px solid #ef4444; color: #ef4444; border-radius: 6px; padding: 2px 8px; font-size: 11px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 4px;",
                        onclick: remove_row,
                        IconTrash {}
                        " Linha"
                    }
                }
                div { style: "display: flex; gap: 4px;",
                    button {
                        style: "background: var(--glass-bg); border: 1px solid var(--accent-cyan); color: var(--accent-cyan); border-radius: 6px; padding: 2px 8px; font-size: 11px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 4px;",
                        onclick: add_col,
                        IconPlus {}
                        " Coluna"
                    }
                    button {
                        style: "background: var(--glass-bg); border: 1px solid #ef4444; color: #ef4444; border-radius: 6px; padding: 2px 8px; font-size: 11px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 4px;",
                        onclick: remove_col,
                        IconTrash {}
                        " Coluna"
                    }
                }
            }
            div { style: "overflow: auto; flex: 1; height: 100%; border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.15); background: var(--glass-bg); padding: 4px; display: flex; flex-direction: column;",
                table { style: "width: 100%; height: 100%; border-collapse: collapse; font-size: 12px; color: #fff;",
                    tbody { style: "height: 100%;",
                        for (r_idx, row) in rows().iter().enumerate() {
                            tr {
                                key: "{r_idx}",
                                style: if r_idx == 0 {
                                    "background: rgba(255, 255, 255, 0.08); font-weight: 600; border-bottom: 1px solid rgba(255,255,255,0.2);"
                                } else {
                                    "border-bottom: 1px solid rgba(255,255,255,0.06);"
                                },
                                for (c_idx, cell) in row.iter().enumerate() {
                                    td { key: "{c_idx}", style: "padding: 4px 6px; border-right: 1px solid rgba(255,255,255,0.05); height: 100%;",
                                        input {
                                            style: "background: transparent; border: none; color: #fff; width: 100%; height: 100%; font-size: 12px; outline: none; padding: 2px 4px; border-radius: 4px;",
                                            value: "{cell}",
                                            oninput: move |e: FormEvent| {
                                                let val = e.value();
                                                rows.with_mut(|r| {
                                                    if let Some(r_row) = r.get_mut(r_idx) {
                                                        if let Some(r_cell) = r_row.get_mut(c_idx) {
                                                            *r_cell = val;
                                                        }
                                                    }
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


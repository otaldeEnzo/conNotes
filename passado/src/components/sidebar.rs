use crate::icons::*;
use crate::types::*;
use dioxus::prelude::*;

pub fn render_folder_node(
    folder: FolderItem,
    mut folders: Signal<Vec<FolderItem>>,
    mut notes: Signal<Vec<NoteItem>>,
    active_tab_id: Signal<Option<usize>>,
    open_tab_ids: Signal<Vec<usize>>,
    mut dragged_sidebar_note_id: Signal<Option<usize>>,
    mut sidebar_drag_target_id: Signal<Option<usize>>,
    mut is_note_type_menu_open: Signal<bool>,
    mut subnote_parent_target: Signal<Option<usize>>,
    mut folder_target_for_new_note: Signal<Option<usize>>,
    mut editing_folder_id: Signal<Option<usize>>,
    editing_note_id: Signal<Option<usize>>,
    depth: usize,
) -> Element {
    let folder_id = folder.id;
    let is_expanded = folder.expanded;

    let mut delete_folder = move |id: usize| {
        folders.with_mut(|f_list| {
            f_list.retain(|f| f.id != id);
        });
        notes.with_mut(|n_list| {
            for n in n_list.iter_mut() {
                if n.folder_id == Some(id) {
                    n.folder_id = None;
                }
            }
        });
        folders.with_mut(|f_list| {
            for f in f_list.iter_mut() {
                if f.parent_id == Some(id) {
                    f.parent_id = None;
                }
            }
        });
    };

    let toggle_expanded = move |_: MouseEvent| {
        folders.with_mut(|f_list| {
            if let Some(f) = f_list.iter_mut().find(|f| f.id == folder_id) {
                f.expanded = !f.expanded;
            }
        });
    };

    let subfolders: Vec<FolderItem> = folders()
        .iter()
        .filter(|f| f.parent_id == Some(folder_id))
        .cloned()
        .collect();
    let child_notes: Vec<NoteItem> = notes()
        .iter()
        .filter(|n| n.folder_id == Some(folder_id) && n.parent_id.is_none() && n.note_type.as_deref() != Some("settings") && n.id != 9999)
        .cloned()
        .collect();

    let is_drag_over = sidebar_drag_target_id() == Some(9000 + folder_id);
    let folder_class = if is_drag_over {
        "folder-group drag-over"
    } else {
        "folder-group"
    };

    let mut finish_folder_edit = move || {
        folders.with_mut(|f_list| {
            if let Some(f) = f_list.iter_mut().find(|f| f.id == folder_id) {
                if f.name.trim().is_empty() {
                    f.name = "Nova Pasta".to_string();
                } else {
                    f.name = f.name.trim().to_string();
                }
            }
        });
        editing_folder_id.set(None);
    };

    let is_editing = editing_folder_id() == Some(folder_id);

    rsx! {
        div {
            key: "{folder_id}",
            class: "{folder_class}",
            style: "padding-left: 4px;",

            onmouseenter: move |_: MouseEvent| {
                if dragged_sidebar_note_id().is_some() {
                    sidebar_drag_target_id.set(Some(9000 + folder_id));
                }
            },
            onmouseup: move |e: MouseEvent| {
                if let Some(src_id) = dragged_sidebar_note_id() {
                    e.stop_propagation();
                    notes.with_mut(|n_list| {
                        if let Some(n) = n_list.iter_mut().find(|n| n.id == src_id) {
                            n.folder_id = Some(folder_id);
                            n.parent_id = None;
                        }
                    });
                    dragged_sidebar_note_id.set(None);
                    sidebar_drag_target_id.set(None);
                }
            },

            div {
                class: "folder-header",
                onclick: toggle_expanded,

                span { class: "folder-chevron",
                    if is_expanded { IconChevronDown {} } else { IconChevronRight {} }
                }
                span { class: "folder-icon",
                    IconFolder { expanded: is_expanded }
                }

                if is_editing {
                    input {
                        class: "inline-title-input",
                        value: "{folder.name}",
                        onclick: move |e: MouseEvent| e.stop_propagation(),
                        oninput: move |e: FormEvent| {
                            let val = e.value();
                            folders.with_mut(|f_list| {
                                if let Some(f) = f_list.iter_mut().find(|f| f.id == folder_id) {
                                    f.name = val;
                                }
                            });
                        },
                        onkeydown: move |e: KeyboardEvent| {
                            if e.key() == Key::Enter || e.key() == Key::Escape {
                                finish_folder_edit();
                            }
                        },
                        onblur: move |_: FocusEvent| {
                            finish_folder_edit();
                        }
                    }
                } else {
                    span { class: "folder-name", "{folder.name}" }
                }

                div { class: "folder-actions-wrapper",
                    button {
                        class: "folder-action-btn",
                        title: "Nova Nota",
                        onclick: move |e: MouseEvent| {
                            e.stop_propagation();
                            subnote_parent_target.set(None);
                            folder_target_for_new_note.set(Some(folder_id));
                            is_note_type_menu_open.set(true);
                        },
                        IconPlus {}
                    }
                    button {
                        class: "folder-action-btn",
                        title: "Nova Subpasta",
                        onclick: move |e: MouseEvent| {
                            e.stop_propagation();
                            let next_id = folders().len() + 1 + 9000;
                            folders.with_mut(|f_list| {
                                f_list.push(FolderItem {
                                    id: next_id,
                                    name: "Nova Subpasta".to_string(),
                                    expanded: true,
                                    parent_id: Some(folder_id),
                                });
                            });
                            editing_folder_id.set(Some(next_id));
                        },
                        IconFolderPlus {}
                    }
                    button {
                        class: "folder-action-btn delete-btn",
                        title: "Excluir Pasta",
                        onclick: move |e: MouseEvent| {
                            e.stop_propagation();
                            delete_folder(folder_id);
                        },
                        IconTrash {}
                    }
                }
            }

            if is_expanded {
                div { class: "folder-contents",
                    for sub in subfolders {
                        {render_folder_node(
                            sub,
                            folders,
                            notes,
                            active_tab_id,
                            open_tab_ids,
                            dragged_sidebar_note_id,
                            sidebar_drag_target_id,
                            is_note_type_menu_open,
                            subnote_parent_target,
                            folder_target_for_new_note,
                            editing_folder_id,
                            editing_note_id,
                            depth + 1,
                        )}
                    }
                    for note in child_notes {
                        {render_note_node(
                            note,
                            folders,
                            notes,
                            active_tab_id,
                            open_tab_ids,
                            dragged_sidebar_note_id,
                            sidebar_drag_target_id,
                            is_note_type_menu_open,
                            subnote_parent_target,
                            folder_target_for_new_note,
                            editing_folder_id,
                            editing_note_id,
                            depth + 1,
                        )}
                    }
                }
            }
        }
    }
}

pub fn render_note_node(
    note: NoteItem,
    folders: Signal<Vec<FolderItem>>,
    mut notes: Signal<Vec<NoteItem>>,
    mut active_tab_id: Signal<Option<usize>>,
    mut open_tab_ids: Signal<Vec<usize>>,
    mut dragged_sidebar_note_id: Signal<Option<usize>>,
    mut sidebar_drag_target_id: Signal<Option<usize>>,
    mut is_note_type_menu_open: Signal<bool>,
    mut subnote_parent_target: Signal<Option<usize>>,
    mut folder_target_for_new_note: Signal<Option<usize>>,
    editing_folder_id: Signal<Option<usize>>,
    mut editing_note_id: Signal<Option<usize>>,
    depth: usize,
) -> Element {
    let note_id = note.id;
    let card_type = get_note_card_type_from_icon(&note.icon);

    let mut delete_note = move |id: usize| {
        open_tab_ids.with_mut(|tabs| {
            tabs.retain(|&t_id| t_id != id);
        });
        if active_tab_id() == Some(id) {
            active_tab_id.set(open_tab_ids().last().copied());
        }

        fn get_child_note_ids(parent_id: usize, notes: &[NoteItem]) -> Vec<usize> {
            let mut ids = vec![];
            for n in notes {
                if n.parent_id == Some(parent_id) {
                    ids.push(n.id);
                    ids.extend(get_child_note_ids(n.id, notes));
                }
            }
            ids
        }

        let mut ids_to_delete = vec![id];
        ids_to_delete.extend(get_child_note_ids(id, &notes()));

        notes.with_mut(|n_list| {
            n_list.retain(|n| !ids_to_delete.contains(&n.id));
        });
    };

    let mut open_note_in_tab = move |id: usize| {
        if !open_tab_ids().contains(&id) {
            open_tab_ids.with_mut(|tabs| tabs.push(id));
        }
        active_tab_id.set(Some(id));
    };

    let child_notes: Vec<NoteItem> = notes()
        .iter()
        .filter(|n| n.parent_id == Some(note_id))
        .cloned()
        .collect();

    let is_selected = active_tab_id() == Some(note_id);
    let is_drag_over = sidebar_drag_target_id() == Some(note_id);
    let is_being_dragged = dragged_sidebar_note_id() == Some(note_id);
    let note_class = if is_being_dragged {
        "note-item is-being-dragged"
    } else if is_selected {
        "note-item active"
    } else if is_drag_over {
        "note-item drag-over"
    } else {
        "note-item"
    };

    let mut finish_note_edit = move || {
        notes.with_mut(|n_list| {
            if let Some(n) = n_list.iter_mut().find(|n| n.id == note_id) {
                if n.title.trim().is_empty() {
                    let c_type = get_note_card_type_from_icon(&n.icon);
                    n.title = match c_type.as_str() {
                        "math" => "Nova Nota (Matemática)".to_string(),
                        "plot" => "Nova Nota (Gráfico)".to_string(),
                        "code" => "Nova Nota (Código)".to_string(),
                        _ => "Nova Nota (Texto)".to_string(),
                    };
                } else {
                    n.title = n.title.trim().to_string();
                }
            }
        });
        editing_note_id.set(None);
    };

    let is_editing = editing_note_id() == Some(note_id);

    rsx! {
        div {
            key: "{note_id}",
            class: "note-item-wrapper",
            style: "padding-left: 4px;",

            div {
                class: "{note_class}",
                draggable: "false",
                onclick: move |_: MouseEvent| {
                    if sidebar_drag_target_id().is_none() || sidebar_drag_target_id() == Some(note_id) {
                        open_note_in_tab(note_id);
                    }
                },
                onmousedown: move |_e: MouseEvent| {
                    dragged_sidebar_note_id.set(Some(note_id));
                },
                onmouseenter: move |_: MouseEvent| {
                    if dragged_sidebar_note_id().is_some() {
                        sidebar_drag_target_id.set(Some(note_id));
                    }
                },
                onmouseup: move |e: MouseEvent| {
                    if let Some(src_id) = dragged_sidebar_note_id() {
                        e.stop_propagation();
                        if src_id != note_id {
                            let parent_folder_id = notes().iter().find(|n| n.id == note_id).and_then(|pn| pn.folder_id);
                            notes.with_mut(|n_list| {
                                if let Some(n) = n_list.iter_mut().find(|n| n.id == src_id) {
                                    n.parent_id = Some(note_id);
                                    n.folder_id = parent_folder_id;
                                }
                            });
                        }
                        dragged_sidebar_note_id.set(None);
                        sidebar_drag_target_id.set(None);
                    }
                },

                span { class: "note-icon",
                    IconNote { card_type: card_type }
                }

                if is_editing {
                    input {
                        class: "inline-title-input",
                        value: "{note.title}",
                        onclick: move |e: MouseEvent| e.stop_propagation(),
                        oninput: move |e: FormEvent| {
                            let val = e.value();
                            notes.with_mut(|n_list| {
                                if let Some(n) = n_list.iter_mut().find(|n| n.id == note_id) {
                                    n.title = val;
                                }
                            });
                        },
                        onkeydown: move |e: KeyboardEvent| {
                            if e.key() == Key::Enter || e.key() == Key::Escape {
                                finish_note_edit();
                            }
                        },
                        onblur: move |_: FocusEvent| {
                            finish_note_edit();
                        }
                    }
                } else {
                    span { class: "note-title", "{note.title}" }
                }

                div { class: "note-actions-wrapper",
                    button {
                        class: "note-action-btn",
                        title: "Criar Subnota",
                        onclick: move |e: MouseEvent| {
                            e.stop_propagation();
                            folder_target_for_new_note.set(None);
                            subnote_parent_target.set(Some(note_id));
                            is_note_type_menu_open.set(true);
                        },
                        IconPlus {}
                    }
                    button {
                        class: "note-action-btn delete-btn",
                        title: "Excluir Nota",
                        onclick: move |e: MouseEvent| {
                            e.stop_propagation();
                            delete_note(note_id);
                        },
                        IconTrash {}
                    }
                }
            }

            if !child_notes.is_empty() {
                div { class: "subnotes-container",
                    for child in child_notes {
                        {render_note_node(
                            child,
                            folders,
                            notes,
                            active_tab_id,
                            open_tab_ids,
                            dragged_sidebar_note_id,
                            sidebar_drag_target_id,
                            is_note_type_menu_open,
                            subnote_parent_target,
                            folder_target_for_new_note,
                            editing_folder_id,
                            editing_note_id,
                            depth + 1,
                        )}
                    }
                }
            }
        }
    }
}

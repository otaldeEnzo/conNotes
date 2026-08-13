use dioxus::prelude::*;

#[component]
pub fn IconChevronRight() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 12px; height: 12px; fill: none; stroke: currentColor; stroke_width: 2.5; stroke_linecap: round; stroke_linejoin: round;",
            polyline { points: "9 18 15 12 9 6" }
        }
    }
}

#[component]
pub fn IconChevronDown() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 12px; height: 12px; fill: none; stroke: currentColor; stroke_width: 2.5; stroke_linecap: round; stroke_linejoin: round;",
            polyline { points: "6 9 12 15 18 9" }
        }
    }
}

#[component]
pub fn IconFolder(expanded: bool) -> Element {
    if expanded {
        rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: var(--accent-emerald); stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                path { d: "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" }
                path { d: "M2 10h20" }
            }
        }
    } else {
        rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: var(--accent-emerald); stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                path { d: "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" }
            }
        }
    }
}

#[component]
pub fn IconNote(card_type: String) -> Element {
    match card_type.as_str() {
        "math" => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: var(--accent-cyan); stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                path { d: "M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z" }
                path { d: "M12 6v12M6 12h12" }
            }
        },
        "plot" => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: var(--accent-violet); stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                path { d: "M18 20V10M12 20V4M6 20v-6" }
            }
        },
        "plot3d" => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: #38bdf8; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                path { d: "M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" }
                polyline { points: "3.27 6.96 12 12.01 20.73 6.96" }
                line { x1: "12", y1: "22.08", x2: "12", y2: "12" }
            }
        },
        "image" => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: #f43f5e; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                rect { x: "3", y: "3", width: "18", height: "18", rx: "2", ry: "2" }
                circle { cx: "8.5", cy: "8.5", r: "1.5" }
                polyline { points: "21 15 16 10 5 21" }
            }
        },
        "table" => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: #10b981; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                rect { x: "3", y: "3", width: "18", height: "18", rx: "2" }
                path { d: "M3 9h18M3 15h18M9 3v18M15 3v18" }
            }
        },
        "flashcard" => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: #f59e0b; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                rect { x: "2", y: "4", width: "16", height: "16", rx: "2" }
                path { d: "M6 20h14a2 2 0 0 0 2-2V6" }
            }
        },
        "code" => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: var(--accent-purple); stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                polyline { points: "16 18 22 12 16 6" }
                polyline { points: "8 6 2 12 8 18" }
            }
        },
        _ => rsx! {
            svg {
                view_box: "0 0 24 24",
                style: "width: 16px; height: 16px; fill: none; stroke: var(--text-secondary); stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
                path { d: "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" }
                polyline { points: "14 2 14 8 20 8" }
                line { x1: "16", y1: "13", x2: "8", y2: "13" }
                line { x1: "16", y1: "17", x2: "8", y2: "17" }
            }
        },
    }
}

#[component]
pub fn IconTrash() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: #ef4444; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            polyline { points: "3 6 5 6 21 6" }
            path { d: "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" }
        }
    }
}

#[component]
pub fn IconPlus() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2.5; stroke_linecap: round; stroke_linejoin: round;",
            line { x1: "12", y1: "5", x2: "12", y2: "19" }
            line { x1: "5", y1: "12", x2: "19", y2: "12" }
        }
    }
}

#[component]
pub fn IconFolderPlus() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2.5; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M12 22H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2v2" }
            line { x1: "16", y1: "19", x2: "22", y2: "19" }
            line { x1: "19", y1: "16", x2: "19", y2: "22" }
        }
    }
}

pub fn get_note_card_type_from_icon(icon: &str) -> String {
    match icon {
        "math" => "math".to_string(),
        "plot" => "plot".to_string(),
        "plot3d" => "plot3d".to_string(),
        "image" => "image".to_string(),
        "table" => "table".to_string(),
        "flashcard" => "flashcard".to_string(),
        "code" => "code".to_string(),
        _ => "text".to_string(),
    }
}

#[component]
pub fn IconSettings() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            circle { cx: "12", cy: "12", r: "3" }
            path { d: "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" }
        }
    }
}

#[component]
pub fn IconPalette() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            circle { cx: "13.5", cy: "6.5", r: ".5", fill: "currentColor" }
            circle { cx: "17.5", cy: "10.5", r: ".5", fill: "currentColor" }
            circle { cx: "8.5", cy: "7.5", r: ".5", fill: "currentColor" }
            circle { cx: "6.5", cy: "12.5", r: ".5", fill: "currentColor" }
            path { d: "M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.92 0 1.7-.72 1.7-1.65 0-.43-.17-.83-.44-1.14-.27-.31-.43-.72-.43-1.18 0-.92.75-1.67 1.67-1.67H16.5c3.04 0 5.5-2.46 5.5-5.5 0-4.97-4.48-9-10-9z" }
        }
    }
}

#[component]
pub fn IconSync() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" }
        }
    }
}

#[component]
pub fn IconSparkles() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z" }
        }
    }
}

#[component]
pub fn IconUser() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" }
            circle { cx: "12", cy: "7", r: "4" }
        }
    }
}

#[component]
pub fn IconKey() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "m21 2-2 2m-1.5 1.5L14 9.5a5 5 0 1 0 4.5 4.5l-4-4 2-2 2 2 2.5-2.5Z" }
            circle { cx: "7.5", cy: "16.5", r: ".5", fill: "currentColor" }
        }
    }
}

#[component]
pub fn IconSearch() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            circle { cx: "11", cy: "11", r: "8" }
            line { x1: "21", y1: "21", x2: "16.65", y2: "16.65" }
        }
    }
}

#[component]
pub fn IconGalaxy() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 20px; height: 20px; fill: none; stroke: #00e1ff; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            circle { cx: "12", cy: "12", r: "3" }
            path { d: "M12 2a10 10 0 0 1 10 10c0 5.523-4.477 10-10 10S2 17.523 2 12 6.477 2 12 2Z", stroke_dasharray: "4 4" }
        }
    }
}

#[component]
pub fn IconLock() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            rect { x: "3", y: "11", width: "18", height: "11", rx: "2", ry: "2" }
            path { d: "M7 11V7a5 5 0 0 1 10 0v4" }
        }
    }
}

#[component]
pub fn IconCheck() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2.5; stroke_linecap: round; stroke_linejoin: round;",
            polyline { points: "20 6 9 17 4 12" }
        }
    }
}

#[component]
pub fn IconGlobe() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            circle { cx: "12", cy: "12", r: "10" }
            line { x1: "2", y1: "12", x2: "22", y2: "12" }
            path { d: "M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" }
        }
    }
}

#[component]
pub fn IconLaptop() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            rect { x: "2", y: "3", width: "20", height: "14", rx: "2", ry: "2" }
            line { x1: "2", y1: "20", x2: "22", y2: "20" }
        }
    }
}

#[component]
pub fn IconDatabase() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5" }
            path { d: "M3 12c0 1.66 4 3 9 3s9-1.34 9-3" }
            ellipse { cx: "12", cy: "5", rx: "9", ry: "3" }
        }
    }
}

#[component]
pub fn IconVolume() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            polygon { points: "11 5 6 9 2 9 2 15 6 15 11 19 11 5" }
            path { d: "M15.54 8.46a5 5 0 0 1 0 7.07" }
            path { d: "M19.07 4.93a10 10 0 0 1 0 14.14" }
        }
    }
}

#[component]
pub fn IconCopy() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            rect { x: "9", y: "9", width: "13", height: "13", rx: "2", ry: "2" }
            path { d: "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" }
        }
    }
}

#[component]
pub fn IconUnlock() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            rect { x: "3", y: "11", width: "18", height: "11", rx: "2", ry: "2" }
            path { d: "M7 11V7a5 5 0 0 1 9.9-1" }
        }
    }
}

#[component]
pub fn IconChevronUp() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 12px; height: 12px; fill: none; stroke: currentColor; stroke_width: 2.5; stroke_linecap: round; stroke_linejoin: round;",
            polyline { points: "18 15 12 9 6 15" }
        }
    }
}

#[component]
pub fn IconClose() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 12px; height: 12px; fill: none; stroke: currentColor; stroke_width: 2.5; stroke_linecap: round; stroke_linejoin: round;",
            line { x1: "18", y1: "6", x2: "6", y2: "18" }
            line { x1: "6", y1: "6", x2: "18", y2: "18" }
        }
    }
}

#[component]
pub fn IconBackup() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" }
            polyline { points: "17 8 12 3 7 8" }
            line { x1: "12", y1: "3", x2: "12", y2: "15" }
        }
    }
}

#[component]
pub fn IconRestore() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" }
            path { d: "M3 3v5h5" }
            path { d: "M12 7v5l4 2" }
        }
    }
}

#[component]
pub fn IconArrowRight() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            line { x1: "5", y1: "12", x2: "19", y2: "12" }
            polyline { points: "12 5 19 12 12 19" }
        }
    }
}

#[component]
pub fn IconBrush() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08" }
            path { d: "M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.08 5.03.8 5.03.8s-.28 3.95.8 5.03c.5.5.69-2.02 2.02-2.02 1.67 0 3.02-1.35 3.02-3.02 0-1.67-1.35-3.02-3.02-3.02z" }
        }
    }
}

#[component]
pub fn IconRefresh() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 14px; height: 14px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M21 2v6h-6" }
            path { d: "M3 12a9 9 0 0 1 15-6.7L21 8" }
            path { d: "M3 22v-6h6" }
            path { d: "M21 12a9 9 0 0 1-15 6.7L3 16" }
        }
    }
}

#[component]
pub fn IconChart() -> Element {
    rsx! {
        svg {
            view_box: "0 0 24 24",
            style: "width: 16px; height: 16px; fill: none; stroke: currentColor; stroke_width: 2; stroke_linecap: round; stroke_linejoin: round;",
            path { d: "M3 3v18h18" }
            path { d: "m19 9-5 5-4-4-3 3" }
        }
    }
}

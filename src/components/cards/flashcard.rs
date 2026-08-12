use crate::types::*;
use crate::icons::*;
use dioxus::prelude::*;

#[component]
pub fn Flashcard(card: NoteCard) -> Element {
    let mut is_flipped = use_signal(|| false);
    let mut front_text = use_signal(|| "Pergunta / Conceito Principal".to_string());
    let mut back_text = use_signal(|| {
        if card.content.is_empty() {
            "Resposta / Explicação Detalhada".to_string()
        } else {
            card.content.clone()
        }
    });

    rsx! {
        div { class: "card-content-flashcard", style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 8px;",
            div { style: "display: flex; justify-content: space-between; align-items: center;",
                span { style: "font-size: 11px; font-weight: 600; color: rgba(255, 255, 255, 0.6);",
                    if is_flipped() { "VERSO (RESPOSTA)" } else { "FRENTE (PERGUNTA)" }
                }
                button {
                    style: "background: var(--glass-bg); border: 1px solid var(--accent-cyan); color: var(--accent-cyan); border-radius: 6px; padding: 3px 10px; font-size: 11px; font-weight: 600; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; gap: 4px;",
                    onclick: move |_| is_flipped.toggle(),
                    IconRefresh {}
                    "Virar Card"
                }
            }

            // CONTAINER 3D COM PERSPECTIVA
            div { style: "width: 100%; height: 160px; perspective: 1000px;",
                div {
                    style: format!(
                        "position: relative; width: 100%; height: 100%; border-radius: 12px; transition: transform 0.6s cubic-bezier(0.4, 0, 0.2, 1); transform-style: preserve-3d; transform: {};",
                        if is_flipped() { "rotateY(180deg)" } else { "rotateY(0deg)" }
                    ),

                    // LADO FRENTE (PERGUNTA)
                    div {
                        style: "position: absolute; inset: 0; width: 100%; height: 100%; backface-visibility: hidden; -webkit-backface-visibility: hidden; border-radius: 12px; padding: 12px; display: flex; flex-direction: column; background: var(--glass-bg); border: 1px solid var(--accent-cyan); backdrop-filter: blur(12px); box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);",
                        textarea {
                            style: "width: 100%; height: 100%; background: transparent; border: none; color: var(--accent-cyan); font-weight: 600; font-size: 14px; text-align: center; resize: none; outline: none; padding-top: 36px;",
                            value: "{front_text}",
                            placeholder: "Digite a Pergunta ou Conceito...",
                            oninput: move |e: FormEvent| front_text.set(e.value())
                        }
                    }

                    // LADO VERSO (RESPOSTA) - ROTACIONADO 180deg
                    div {
                        style: "position: absolute; inset: 0; width: 100%; height: 100%; backface-visibility: hidden; -webkit-backface-visibility: hidden; transform: rotateY(180deg); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; background: var(--glass-bg); border: 1px solid var(--accent-emerald, #10b981); backdrop-filter: blur(12px); box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);",
                        textarea {
                            style: "width: 100%; height: 100%; background: transparent; border: none; color: var(--accent-emerald, #10b981); font-weight: 600; font-size: 14px; text-align: center; resize: none; outline: none; padding-top: 36px;",
                            value: "{back_text}",
                            placeholder: "Digite a Resposta ou Explicação...",
                            oninput: move |e: FormEvent| back_text.set(e.value())
                        }
                    }
                }
            }
        }
    }
}


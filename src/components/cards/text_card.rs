use crate::types::*;
use crate::icons::*;
use dioxus::prelude::*;

// Typeset Math AST representation
#[derive(Debug, Clone)]
enum MathNode {
    Text(String),
    Symbol(String),
    Frac(Vec<MathNode>, Vec<MathNode>),
    Sqrt(Vec<MathNode>),
    SubSup {
        base: Option<Vec<MathNode>>,
        sub: Option<Vec<MathNode>>,
        sup: Option<Vec<MathNode>>,
    },
    Group(Vec<MathNode>),
}

// Tokenizer for simple LaTeX math
#[derive(Debug, Clone, PartialEq)]
enum Token {
    Command(String),
    Char(char),
    LBrace,
    RBrace,
    Sub,
    Sup,
    Space,
}

fn tokenize_math(input: &str) -> Vec<Token> {
    let mut tokens = Vec::new();
    let chars: Vec<char> = input.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        match chars[i] {
            '\\' => {
                i += 1;
                let mut cmd = String::new();
                while i < chars.len() && chars[i].is_alphabetic() {
                    cmd.push(chars[i]);
                    i += 1;
                }
                if cmd.is_empty() && i < chars.len() {
                    cmd.push(chars[i]);
                    i += 1;
                }
                tokens.push(Token::Command(cmd));
            }
            '{' => {
                tokens.push(Token::LBrace);
                i += 1;
            }
            '}' => {
                tokens.push(Token::RBrace);
                i += 1;
            }
            '_' => {
                tokens.push(Token::Sub);
                i += 1;
            }
            '^' => {
                tokens.push(Token::Sup);
                i += 1;
            }
            ' ' | '\t' | '\n' => {
                tokens.push(Token::Space);
                i += 1;
            }
            c => {
                tokens.push(Token::Char(c));
                i += 1;
            }
        }
    }
    tokens
}

// Parser that parses tokens into MathNode AST
struct MathParser {
    tokens: Vec<Token>,
    pos: usize,
}

impl MathParser {
    fn new(tokens: Vec<Token>) -> Self {
        Self { tokens, pos: 0 }
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn next(&mut self) -> Option<Token> {
        if self.pos < self.tokens.len() {
            let t = self.tokens[self.pos].clone();
            self.pos += 1;
            Some(t)
        } else {
            None
        }
    }

    fn parse(&mut self) -> Vec<MathNode> {
        let mut nodes = Vec::new();
        while self.pos < self.tokens.len() {
            if let Some(node) = self.parse_node() {
                nodes.push(node);
            }
        }
        nodes
    }

    fn parse_group_or_single(&mut self) -> Vec<MathNode> {
        self.skip_spaces();
        if let Some(Token::LBrace) = self.peek() {
            self.next(); // consume '{'
            let mut inner = Vec::new();
            while let Some(t) = self.peek() {
                if *t == Token::RBrace {
                    self.next(); // consume '}'
                    break;
                }
                if let Some(node) = self.parse_node() {
                    inner.push(node);
                }
            }
            inner
        } else if let Some(_) = self.peek() {
            if let Some(node) = self.parse_node() {
                vec![node]
            } else {
                vec![]
            }
        } else {
            vec![]
        }
    }

    fn skip_spaces(&mut self) {
        while let Some(Token::Space) = self.peek() {
            self.next();
        }
    }

    fn parse_node(&mut self) -> Option<MathNode> {
        let tok = self.next()?;
        let base_node = match tok {
            Token::Space => return Some(MathNode::Text(" ".to_string())),
            Token::LBrace => {
                let mut inner = Vec::new();
                while let Some(t) = self.peek() {
                    if *t == Token::RBrace {
                        self.next();
                        break;
                    }
                    if let Some(n) = self.parse_node() {
                        inner.push(n);
                    }
                }
                MathNode::Group(inner)
            }
            Token::RBrace => return None,
            Token::Command(cmd) => match cmd.as_str() {
                "frac" | "dfrac" => {
                    let num = self.parse_group_or_single();
                    let den = self.parse_group_or_single();
                    MathNode::Frac(num, den)
                }
                "sqrt" => {
                    let arg = self.parse_group_or_single();
                    MathNode::Sqrt(arg)
                }
                "int" => MathNode::Symbol("∫".to_string()),
                "iint" => MathNode::Symbol("∬".to_string()),
                "iiint" => MathNode::Symbol("∭".to_string()),
                "oint" => MathNode::Symbol("∮".to_string()),
                "sum" => MathNode::Symbol("∑".to_string()),
                "prod" => MathNode::Symbol("∏".to_string()),
                "lim" => MathNode::Symbol("lim".to_string()),
                "sin" | "cos" | "tan" | "csc" | "sec" | "cot" | "arcsin" | "arccos" | "arctan" | "sinh" | "cosh" | "tanh" | "log" | "ln" | "exp" | "max" | "min" => MathNode::Symbol(cmd.clone()),
                "to" | "rightarrow" => MathNode::Symbol("→".to_string()),
                "leftarrow" => MathNode::Symbol("←".to_string()),
                "Rightarrow" => MathNode::Symbol("⇒".to_string()),
                "Leftarrow" => MathNode::Symbol("⇐".to_string()),
                "pi" => MathNode::Symbol("π".to_string()),
                "theta" => MathNode::Symbol("θ".to_string()),
                "alpha" => MathNode::Symbol("α".to_string()),
                "beta" => MathNode::Symbol("β".to_string()),
                "gamma" => MathNode::Symbol("γ".to_string()),
                "delta" => MathNode::Symbol("δ".to_string()),
                "epsilon" => MathNode::Symbol("ε".to_string()),
                "zeta" => MathNode::Symbol("ζ".to_string()),
                "eta" => MathNode::Symbol("η".to_string()),
                "iota" => MathNode::Symbol("ι".to_string()),
                "kappa" => MathNode::Symbol("κ".to_string()),
                "lambda" => MathNode::Symbol("λ".to_string()),
                "mu" => MathNode::Symbol("μ".to_string()),
                "nu" => MathNode::Symbol("ν".to_string()),
                "xi" => MathNode::Symbol("ξ".to_string()),
                "rho" => MathNode::Symbol("ρ".to_string()),
                "sigma" => MathNode::Symbol("σ".to_string()),
                "tau" => MathNode::Symbol("τ".to_string()),
                "upsilon" => MathNode::Symbol("υ".to_string()),
                "phi" => MathNode::Symbol("ϕ".to_string()),
                "chi" => MathNode::Symbol("χ".to_string()),
                "psi" => MathNode::Symbol("ψ".to_string()),
                "omega" => MathNode::Symbol("ω".to_string()),
                "Gamma" => MathNode::Symbol("Γ".to_string()),
                "Delta" => MathNode::Symbol("Δ".to_string()),
                "Theta" => MathNode::Symbol("Θ".to_string()),
                "Lambda" => MathNode::Symbol("Λ".to_string()),
                "Xi" => MathNode::Symbol("Ξ".to_string()),
                "Pi" => MathNode::Symbol("Π".to_string()),
                "Sigma" => MathNode::Symbol("Σ".to_string()),
                "Upsilon" => MathNode::Symbol("Υ".to_string()),
                "Phi" => MathNode::Symbol("Φ".to_string()),
                "Psi" => MathNode::Symbol("Ψ".to_string()),
                "Omega" => MathNode::Symbol("Ω".to_string()),
                "infty" => MathNode::Symbol("∞".to_string()),
                "approx" => MathNode::Symbol("≈".to_string()),
                "neq" => MathNode::Symbol("≠".to_string()),
                "leq" | "le" => MathNode::Symbol("≤".to_string()),
                "geq" | "ge" => MathNode::Symbol("≥".to_string()),
                "pm" => MathNode::Symbol("±".to_string()),
                "mp" => MathNode::Symbol("∓".to_string()),
                "times" => MathNode::Symbol("×".to_string()),
                "div" => MathNode::Symbol("÷".to_string()),
                "partial" => MathNode::Symbol("∂".to_string()),
                "nabla" => MathNode::Symbol("∇".to_string()),
                "cdot" => MathNode::Symbol("·".to_string()),
                "in" => MathNode::Symbol("∈".to_string()),
                "notin" => MathNode::Symbol("∉".to_string()),
                "subset" => MathNode::Symbol("⊂".to_string()),
                "supset" => MathNode::Symbol("⊃".to_string()),
                "cup" => MathNode::Symbol("∪".to_string()),
                "cap" => MathNode::Symbol("∩".to_string()),
                "forall" => MathNode::Symbol("∀".to_string()),
                "exists" => MathNode::Symbol("∃".to_string()),
                "emptyset" => MathNode::Symbol("∅".to_string()),
                "left" | "right" => {
                    self.skip_spaces();
                    if let Some(t) = self.next() {
                        match t {
                            Token::Char(c) => MathNode::Symbol(c.to_string()),
                            _ => MathNode::Text("".to_string()),
                        }
                    } else {
                        MathNode::Text("".to_string())
                    }
                }
                "quad" | "qquad" => MathNode::Text("  ".to_string()),
                other => MathNode::Text(format!("\\{}", other)),
            },
            Token::Char(c) => MathNode::Text(c.to_string()),
            Token::Sub | Token::Sup => {
                let is_sub = tok == Token::Sub;
                let script = self.parse_group_or_single();
                return Some(MathNode::SubSup {
                    base: None,
                    sub: if is_sub { Some(script.clone()) } else { None },
                    sup: if !is_sub { Some(script) } else { None },
                });
            }
        };

        // Check if followed by '_' or '^'
        let mut sub = None;
        let mut sup = None;

        while let Some(t) = self.peek() {
            if *t == Token::Sub && sub.is_none() {
                self.next();
                sub = Some(self.parse_group_or_single());
            } else if *t == Token::Sup && sup.is_none() {
                self.next();
                sup = Some(self.parse_group_or_single());
            } else {
                break;
            }
        }

        if sub.is_some() || sup.is_some() {
            Some(MathNode::SubSup {
                base: Some(vec![base_node]),
                sub,
                sup,
            })
        } else {
            Some(base_node)
        }
    }
}

// RSX renderer for MathNode AST
fn render_math_nodes(nodes: &[MathNode]) -> Element {
    rsx! {
        span { style: "display: inline-flex; align-items: center; flex-wrap: nowrap; vertical-align: middle; line-height: 1.2;",
            for (idx, node) in nodes.iter().enumerate() {
                match node {
                    MathNode::Text(txt) => {
                        let is_space = txt == " ";
                        let is_alpha = txt.chars().all(|c| c.is_alphabetic());
                        let style_str = if is_space {
                            "white-space: pre;"
                        } else if is_alpha {
                            "font-family: 'Cambria Math', 'STIX Two Math', 'Times New Roman', serif; font-style: italic; margin: 0 1px;"
                        } else {
                            "font-family: 'Cambria Math', 'STIX Two Math', 'Times New Roman', serif; font-style: normal; margin: 0 1px;"
                        };
                        rsx! {
                            span { key: "{idx}", style: "{style_str}", "{txt}" }
                        }
                    },
                    MathNode::Symbol(sym) => rsx! {
                        span { key: "{idx}", style: "font-size: 1.15em; font-family: serif; margin: 0 2px;", "{sym}" }
                    },
                    MathNode::Frac(num, den) => rsx! {
                        span { key: "{idx}", style: "display: inline-flex; flex-direction: column; align-items: center; text-align: center; vertical-align: middle; margin: 0 3px; font-size: 0.9em;",
                            span { style: "border-bottom: 1.5px solid currentColor; padding: 0 2px 1px 2px; width: 100%; box-sizing: border-box;",
                                {render_math_nodes(num)}
                            }
                            span { style: "padding: 1px 2px 0 2px; width: 100%; box-sizing: border-box;",
                                {render_math_nodes(den)}
                            }
                        }
                    },
                    MathNode::Sqrt(arg) => rsx! {
                        span { key: "{idx}", style: "display: inline-flex; align-items: center; margin: 0 2px;",
                            span { style: "font-size: 1.2em; line-height: 1; margin-right: -1px;", "√" }
                            span { style: "border-top: 1.5px solid currentColor; padding-top: 1px; padding-left: 2px; padding-right: 2px;",
                                {render_math_nodes(arg)}
                            }
                        }
                    },
                    MathNode::SubSup { base, sub, sup } => rsx! {
                        span { key: "{idx}", style: "display: inline-flex; align-items: center; vertical-align: middle;",
                            if let Some(b) = base {
                                {render_math_nodes(b)}
                            }
                            span { style: "display: inline-flex; flex-direction: column; font-size: 0.72em; line-height: 1; margin-left: 1px; vertical-align: middle;",
                                if let Some(sp) = sup {
                                    span { style: "margin-bottom: 2px;", {render_math_nodes(sp)} }
                                }
                                if let Some(sb) = sub {
                                    span { style: "margin-top: 1px;", {render_math_nodes(sb)} }
                                }
                            }
                        }
                    },
                    MathNode::Group(inner) => rsx! {
                        span { key: "{idx}", {render_math_nodes(inner)} }
                    },
                }
            }
        }
    }
}

// Parses latex block string into MathNode list
fn parse_latex_expr(expr: &str) -> Vec<MathNode> {
    let tokens = tokenize_math(expr);
    let mut parser = MathParser::new(tokens);
    parser.parse()
}

fn render_inline_markdown(text: &str) -> Element {
    let mut parts = Vec::new();
    let mut rest = text;

    while !rest.is_empty() {
        if let Some(start_span) = rest.find("<span style=\"") {
            if let Some(style_end) = rest[start_span + 13..].find("\">") {
                let style_attr = &rest[start_span + 13..start_span + 13 + style_end];
                let inner_start = start_span + 13 + style_end + 2;
                if let Some(close_span) = rest[inner_start..].find("</span>") {
                    let before = &rest[..start_span];
                    let span_content = &rest[inner_start..inner_start + close_span];
                    if !before.is_empty() {
                        parts.push((0, before.to_string(), String::new()));
                    }
                    parts.push((4, span_content.to_string(), style_attr.to_string()));
                    rest = &rest[inner_start + close_span + 7..];
                    continue;
                }
            }
        }

        if let Some(start) = rest.find("**") {
            if let Some(end) = rest[start + 2..].find("**") {
                let before = &rest[..start];
                let bold_text = &rest[start + 2..start + 2 + end];
                if !before.is_empty() {
                    parts.push((0, before.to_string(), String::new()));
                }
                parts.push((1, bold_text.to_string(), String::new()));
                rest = &rest[start + 2 + end + 2..];
                continue;
            }
        }
        if let Some(start) = rest.find('`') {
            if let Some(end) = rest[start + 1..].find('`') {
                let before = &rest[..start];
                let code_text = &rest[start + 1..start + 1 + end];
                if !before.is_empty() {
                    parts.push((0, before.to_string(), String::new()));
                }
                parts.push((2, code_text.to_string(), String::new()));
                rest = &rest[start + 1 + end + 1..];
                continue;
            }
        }
        if let Some(start) = rest.find('*') {
            if let Some(end) = rest[start + 1..].find('*') {
                let before = &rest[..start];
                let italic_text = &rest[start + 1..start + 1 + end];
                if !before.is_empty() {
                    parts.push((0, before.to_string(), String::new()));
                }
                parts.push((3, italic_text.to_string(), String::new()));
                rest = &rest[start + 1 + end + 1..];
                continue;
            }
        }
        parts.push((0, rest.to_string(), String::new()));
        break;
    }

    rsx! {
        span {
            for (idx, (kind, chunk, extra)) in parts.into_iter().enumerate() {
                {
                    match kind {
                        1 => rsx! { span { key: "{idx}", style: "font-weight: bold; color: #ffffff;", "{chunk}" } },
                        2 => rsx! { span { key: "{idx}", style: "background: rgba(0, 240, 255, 0.12); border: 1px solid rgba(0, 240, 255, 0.3); border-radius: 4px; padding: 1px 5px; font-family: monospace; color: #00f0ff; font-size: 0.92em;", "{chunk}" } },
                        3 => rsx! { span { key: "{idx}", style: "font-style: italic; color: #e2e8f0;", "{chunk}" } },
                        4 => rsx! { span { key: "{idx}", style: "{extra}", "{chunk}" } },
                        _ => rsx! { span { key: "{idx}", "{chunk}" } },
                    }
                }
            }
        }
    }
}

// Render full text content segment containing math delimiters $$...$$ or $...$
fn render_typeset_content(content: &str) -> Element {
    if content.trim().is_empty() {
        return rsx! { span { style: "color: rgba(255,255,255,0.4); font-style: italic;", "Clique para editar o texto ou fórmulas..." } };
    }

    let mut segments = Vec::new();
    let mut rest = content;

    while !rest.is_empty() {
        if let Some(start_disp) = rest.find("$$") {
            if let Some(end_disp) = rest[start_disp + 2..].find("$$") {
                let text_before = &rest[..start_disp];
                let math_content = &rest[start_disp + 2..start_disp + 2 + end_disp];
                if !text_before.is_empty() {
                    segments.push((false, text_before.to_string(), false));
                }
                segments.push((true, math_content.to_string(), true));
                rest = &rest[start_disp + 2 + end_disp + 2..];
                continue;
            }
        }

        if let Some(start_inline) = rest.find('$') {
            if let Some(end_inline) = rest[start_inline + 1..].find('$') {
                let text_before = &rest[..start_inline];
                let math_content = &rest[start_inline + 1..start_inline + 1 + end_inline];
                if !text_before.is_empty() {
                    segments.push((false, text_before.to_string(), false));
                }
                segments.push((true, math_content.to_string(), false));
                rest = &rest[start_inline + 1 + end_inline + 1..];
                continue;
            }
        }

        segments.push((false, rest.to_string(), false));
        break;
    }

    let rendered_segments = segments.into_iter().enumerate().map(|(idx, (is_math, text, is_display))| {
        let has_latex_cmds = text.contains('\\') || text.contains('^') || text.contains('_') || text.contains('∫') || text.contains('√') || text.contains('∞');
        if is_math || has_latex_cmds {
            if is_display {
                rsx! {
                    div {
                        key: "{idx}",
                        style: "display: flex; justify-content: center; margin: 8px 0; font-size: 1.15em; color: #00f0ff; overflow-x: auto;",
                        {render_math_nodes(&parse_latex_expr(&text))}
                    }
                }
            } else {
                rsx! {
                    span {
                        key: "{idx}",
                        style: "display: inline-flex; align-items: center; margin: 0 3px; color: #00f0ff; vertical-align: middle;",
                        {render_math_nodes(&parse_latex_expr(&text))}
                    }
                }
            }
        } else {
            rsx! {
                span { key: "{idx}", {render_inline_markdown(&text)} }
            }
        }
    });

    rsx! {
        span { style: "white-space: pre-wrap; word-break: break-word; font-size: 13.5px; color: #f8fafc; line-height: 1.5;",
            {rendered_segments}
        }
    }
}

// Render full markdown text segment containing math delimiters $$...$$, task checkboxes (- [ ]), titles or Mermaid diagrams
fn render_typeset_content_with_tasks(
    content: &str,
    font_size: &str,
    font_family: &str,
    text_color: &str,
    on_toggle_task: EventHandler<usize>,
) -> Element {
    if content.trim().is_empty() {
        return rsx! { span { style: "color: rgba(255,255,255,0.4); font-style: italic;", "Clique para editar o texto, fórmulas ou diagramas..." } };
    }

    let is_mermaid = content.contains("```mermaid");
    if is_mermaid {
        let clean_mermaid = content
            .replace("```mermaid", "")
            .replace("```", "")
            .trim()
            .to_string();
        return rsx! {
            div {
                style: "width: 100%; height: 100%; display: flex; flex-direction: column; gap: 8px; padding: 6px; background: rgba(5, 10, 20, 0.6); border: 1px solid rgba(0, 240, 255, 0.3); border-radius: 8px; box-sizing: border-box;",
                div { style: "display: flex; align-items: center; justify-content: space-between; font-size: 10px; font-family: monospace; font-weight: bold; color: #00f0ff; text-transform: uppercase; border-bottom: 1px solid rgba(0, 240, 255, 0.2); padding-bottom: 4px;",
                    span { style: "display: flex; align-items: center; gap: 4px;", IconNote { card_type: "code".to_string() } " DIAGRAMA MERMAID" }
                    span { style: "color: #c084fc;", "Flowchart" }
                }
                div { style: "display: flex; flex-direction: column; gap: 6px; align-items: center; justify-content: center; padding: 10px 0;",
                    for (line_idx, line) in clean_mermaid.lines().enumerate() {
                        {
                            let line_str = line.trim();
                            if !line_str.is_empty() {
                                rsx! {
                                    div {
                                        key: "{line_idx}",
                                        style: "background: rgba(0, 240, 255, 0.1); border: 1px solid rgba(0, 240, 255, 0.4); border-radius: 6px; padding: 4px 12px; font-size: 11px; font-family: monospace; color: #00f0ff; box-shadow: 0 0 10px rgba(0, 240, 255, 0.15);",
                                        "{line_str}"
                                    }
                                }
                            } else {
                                rsx! { div {} }
                            }
                        }
                    }
                }
            }
        };
    }

    let lines: Vec<&str> = content.lines().collect();

    let container_style = format!(
        "width: 100%; height: 100%; white-space: pre-wrap; word-break: break-word; font-size: {}; font-family: {}; color: {}; line-height: 1.6; display: flex; flex-direction: column; gap: 4px;",
        font_size, font_family, text_color
    );

    rsx! {
        div { style: "{container_style}",
            for (line_idx, line) in lines.iter().enumerate() {
                {
                    let trimmed = line.trim();
                    let is_task_checked = trimmed.starts_with("- [x]") || trimmed.starts_with("- [X]");
                    let is_task_unchecked = trimmed.starts_with("- [ ]");

                    if is_task_checked || is_task_unchecked {
                        let text_part = if is_task_checked { &trimmed[5..] } else { &trimmed[5..] };
                        rsx! {
                            div {
                                key: "line_{line_idx}",
                                style: "display: flex; align-items: center; gap: 8px; font-size: 13px; font-family: sans-serif;",
                                input {
                                    r#type: "checkbox",
                                    checked: is_task_checked,
                                    style: "cursor: pointer; accent-color: #00f0ff; width: 14px; height: 14px;",
                                    onmousedown: move |e| e.stop_propagation(),
                                    onclick: move |e| {
                                        e.stop_propagation();
                                        on_toggle_task.call(line_idx);
                                    }
                                }
                                span {
                                    style: if is_task_checked { "text-decoration: line-through; color: rgba(255, 255, 255, 0.45);" } else { "color: #00f0ff; font-weight: 500;" },
                                    "{text_part}"
                                }
                            }
                        }
                    } else if trimmed.starts_with("# ") {
                        let heading_text = &trimmed[2..];
                        rsx! {
                            div {
                                key: "line_{line_idx}",
                                style: "font-size: 1.25em; font-weight: bold; color: #00f0ff; margin-top: 4px; margin-bottom: 2px; border-bottom: 1px solid rgba(0, 240, 255, 0.2); padding-bottom: 2px;",
                                "{heading_text}"
                            }
                        }
                    } else {
                        rsx! {
                            div { key: "line_{line_idx}",
                                {render_typeset_content(line)}
                            }
                        }
                    }
                }
            }
        }
    }
}

#[component]
pub fn TextCard(
    card: NoteCard,
    on_update_content: EventHandler<String>,
    #[props(default)] on_ai_click: EventHandler<String>,
) -> Element {
    let mut is_editing = use_signal(|| card.content.trim().is_empty());
    let mut text_val = use_signal(|| card.content.clone());

    let mut font_size = use_signal(|| "13.5px".to_string());
    let font_family = use_signal(|| "sans-serif".to_string());
    let mut text_color = use_signal(|| "#f8fafc".to_string());
    let mut show_latex_menu = use_signal(|| false);
    let mut sel_range = use_signal(|| (0usize, 0usize));

    use_effect(use_reactive((&card.content,), move |(content,)| {
        if text_val() != content {
            text_val.set(content.clone());
        }
    }));

    let format_helpers = vec![
        ("**", "**", "negrito", "B"),
        ("*", "*", "itálico", "I"),
        ("`", "`", "código", "`"),
        ("\n- [ ] ", "", "tarefa", "✓"),
        ("\n# ", "", "Título", "H1"),
        ("\n> ", "", "citação", "\""),
    ];

    let update_selection = move |_| {
        spawn(async move {
            let eval = document::eval(r#"
                let el = document.activeElement;
                if (el && el.tagName === 'TEXTAREA') {
                    return [el.selectionStart, el.selectionEnd];
                }
                return [0, 0];
            "#);
            if let Ok(val) = eval.await {
                if let Some(arr) = val.as_array() {
                    if arr.len() == 2 {
                        let s = arr[0].as_u64().unwrap_or(0) as usize;
                        let e = arr[1].as_u64().unwrap_or(0) as usize;
                        sel_range.set((s, e));
                    }
                }
            }
        });
    };

    let mut insert_format = move |(pre, suf, def_txt): (&str, &str, &str)| {
        let current = text_val();
        let (s, e) = sel_range();
        let updated = if s < e && e <= current.len() {
            let selected = &current[s..e];
            format!("{}{}{}{}{}", &current[..s], pre, selected, suf, &current[e..])
        } else if current.trim().is_empty() {
            format!("{}{}{}", pre, def_txt, suf)
        } else {
            format!("{}\n{}{}{}", current, pre, def_txt, suf)
        };
        text_val.set(updated.clone());
        on_update_content.call(updated);
        is_editing.set(true);
    };

    let toggle_checkbox = move |line_idx: usize| {
        let content_str = text_val();
        let lines: Vec<&str> = content_str.lines().collect();
        let mut new_lines = Vec::new();
        for (i, line) in lines.iter().enumerate() {
            if i == line_idx {
                if line.contains("- [ ]") {
                    new_lines.push(line.replace("- [ ]", "- [x]"));
                } else if line.contains("- [x]") {
                    new_lines.push(line.replace("- [x]", "- [ ]"));
                } else {
                    new_lines.push(line.to_string());
                }
            } else {
                new_lines.push(line.to_string());
            }
        }
        let updated = new_lines.join("\n");
        text_val.set(updated.clone());
        on_update_content.call(updated);
    };

    let latex_shortcuts = vec![
        ("Cálculo & Integrais", vec![
            ("\\int ", "\\int"),
            ("\\int_{a}^{b} ", "\\int_{a}^{b}"),
            ("\\iint ", "\\iint"),
            ("\\oint ", "\\oint"),
            ("\\sum_{i=1}^{n} ", "\\sum"),
            ("\\prod_{i=1}^{n} ", "\\prod"),
        ]),
        ("Derivadas & Raízes", vec![
            ("\\frac{df}{dx} ", "df/dx"),
            ("\\frac{\\partial f}{\\partial x} ", "∂f/∂x"),
            ("f'(x) ", "f'(x)"),
            ("\\sqrt{x} ", "\\sqrt"),
            ("\\sqrt[n]{x} ", "\\sqrt[n]"),
            ("\\frac{a}{b} ", "\\frac"),
        ]),
        ("Potências & Limites", vec![
            ("x^{n} ", "xⁿ"),
            ("x_{n} ", "xₙ"),
            ("e^{x} ", "eˣ"),
            ("\\lim_{x \\to 0} ", "\\lim"),
            ("\\infty ", "∞"),
        ]),
        ("Letras Gregas", vec![
            ("\\alpha ", "α"),
            ("\\beta ", "β"),
            ("\\gamma ", "γ"),
            ("\\delta ", "δ"),
            ("\\theta ", "θ"),
            ("\\pi ", "π"),
            ("\\sigma ", "σ"),
            ("\\omega ", "ω"),
            ("\\Delta ", "Δ"),
            ("\\Omega ", "Ω"),
            ("\\phi ", "ϕ"),
            ("\\lambda ", "λ"),
        ]),
        ("Operadores & Relações", vec![
            ("\\pm ", "±"),
            ("\\approx ", "≈"),
            ("\\neq ", "≠"),
            ("\\le ", "≤"),
            ("\\ge ", "≥"),
            ("\\times ", "×"),
            ("\\div ", "÷"),
            ("\\cdot ", "·"),
            ("\\rightarrow ", "→"),
        ]),
    ];

    let body_elem = if is_editing() {
        let textarea_style = format!(
            "flex: 1; width: 100%; height: 100%; min-height: 0; padding: 10px; margin: 0; background: rgba(5, 10, 20, 0.6); border: 1px solid rgba(0, 240, 255, 0.25); border-radius: 8px; outline: none; font-size: {}; font-family: {}; line-height: 1.6; color: {}; resize: none; box-sizing: border-box; backdrop-filter: blur(8px);",
            font_size(),
            if font_family() == "monospace" { "'Fira Code', monospace" } else if font_family() == "serif" { "serif" } else { "sans-serif" },
            text_color()
        );
        rsx! {
            textarea {
                class: "card-body-textarea",
                style: "{textarea_style}",
                placeholder: "Digite seu texto, notas, tarefas (- [ ]) ou fórmulas LaTeX ($...$ ou $$...$$)...",
                value: "{text_val}",
                onmousedown: move |e| e.stop_propagation(),
                onclick: move |e| {
                    e.stop_propagation();
                    update_selection(());
                },
                onselect: move |_| update_selection(()),
                onkeyup: move |_| update_selection(()),
                onmouseup: move |_| update_selection(()),
                onwheel: move |e| e.stop_propagation(),
                oninput: move |e| {
                    let val = e.value();
                    text_val.set(val.clone());
                    on_update_content.call(val);
                },
                onblur: move |_| {
                    if !text_val().trim().is_empty() {
                        is_editing.set(false);
                    }
                }
            }
        }
    } else {
        rsx! {
            div {
                style: "flex: 1; width: 100%; height: 100%; min-height: 0; padding: 10px; background: rgba(10, 16, 30, 0.5); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 8px; cursor: pointer; box-sizing: border-box; display: flex; flex-direction: column; backdrop-filter: blur(8px); transition: all 0.2s ease; overflow-y: auto;",
                title: "Clique simples para editar",
                onclick: move |e| {
                    e.stop_propagation();
                    is_editing.set(true);
                },
                onwheel: move |e| e.stop_propagation(),
                if text_val().trim().is_empty() {
                    span {
                        style: "color: rgba(255, 255, 255, 0.4); font-style: italic; font-size: 13px;",
                        "Digite seu texto ou fórmulas aqui (clique simples)..."
                    }
                } else {
                    {render_typeset_content_with_tasks(&text_val(), &font_size(), &font_family(), &text_color(), EventHandler::new(toggle_checkbox))}
                }
            }
        }
    };

    rsx! {
        div {
            style: "position: relative; width: 100%; height: 100%; display: flex; flex-direction: column; padding: 0; margin: 0; box-sizing: border-box;",
            onwheel: move |e| e.stop_propagation(),

            // FLOATING MOSCARO TOOLBAR PILL ABOVE CARD (Uma única cápsula contínua e fluida)
            if card.selected || is_editing() {
                div {
                    class: "floating-card-toolbar",
                    style: "position: relative; display: flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 9999px; background: rgba(10, 16, 28, 0.92); border: 1px solid rgba(0, 240, 255, 0.35); box-shadow: 0 10px 32px rgba(0, 0, 0, 0.75), 0 0 15px rgba(0, 240, 255, 0.25); backdrop-filter: blur(20px);",
                    onmousedown: move |e| {
                        e.prevent_default();
                        e.stop_propagation();
                    },
                    onclick: move |e| e.stop_propagation(),

                    // SEÇÃO 1: FORMATOS RICH TEXT COMPACTOS
                    for (prefix, suffix, default_text, label) in format_helpers {
                        button {
                            key: "{default_text}",
                            r#type: "button",
                            title: "Inserir {default_text}",
                            style: "background: rgba(0, 240, 255, 0.08); color: #00f0ff; border: none; border-radius: 6px; padding: 2px 6px; font-size: 10px; font-weight: bold; font-family: monospace; cursor: pointer; transition: all 0.15s ease;",
                            onmousedown: move |e| e.prevent_default(),
                            onclick: move |_| insert_format((prefix, suffix, default_text)),
                            "{label}"
                        }
                    }

                    div { style: "width: 1px; height: 14px; background: rgba(0, 240, 255, 0.25); margin: 0 2px;" }

                    // SEÇÃO 2: TIPOGRAFIA E CORES COMPACTAS
                    button {
                        r#type: "button",
                        title: "Mudar Tamanho",
                        style: "background: rgba(255,255,255,0.08); color: #e2e8f0; border: none; border-radius: 6px; padding: 2px 6px; font-size: 9.5px; font-weight: bold; cursor: pointer;",
                        onmousedown: move |e| e.prevent_default(),
                        onclick: move |_| {
                            let (s, e) = sel_range();
                            let current = text_val();
                            if s < e && e <= current.len() {
                                let selected = &current[s..e];
                                let next_size = match font_size().as_str() {
                                    "13.5px" => "16px",
                                    "16px" => "19px",
                                    _ => "13.5px",
                                };
                                let updated = format!("{}<span style=\"font-size: {}\">{}</span>{}", &current[..s], next_size, selected, &current[e..]);
                                text_val.set(updated.clone());
                                on_update_content.call(updated);
                            } else {
                                let next_size = match font_size().as_str() {
                                    "13.5px" => "16px",
                                    "16px" => "19px",
                                    _ => "13.5px",
                                };
                                font_size.set(next_size.to_string());
                            }
                        },
                        "Aa {font_size}"
                    }

                    // Seletor Rápido de Cores (Pontos de 10px)
                    div { style: "display: flex; align-items: center; gap: 3px; margin: 0 2px;",
                        for color in ["#f8fafc", "#00f0ff", "#d8b4fe", "#22c55e", "#fbbf24", "#f43f5e"] {
                            {
                                let c_str = color.to_string();
                                rsx! {
                                    div {
                                        key: "{color}",
                                        title: "Cor {color}",
                                        style: "width: 10px; height: 10px; border-radius: 50%; background-color: {color}; cursor: pointer; border: 1px solid rgba(255,255,255,0.4); box-shadow: 0 0 4px {color}; transition: transform 0.15s ease;",
                                        onmousedown: move |e| e.prevent_default(),
                                        onclick: move |_| {
                                            let (s, e) = sel_range();
                                            let current = text_val();
                                            if s < e && e <= current.len() {
                                                let selected = &current[s..e];
                                                let updated = format!("{}<span style=\"color: {}\">{}</span>{}", &current[..s], c_str, selected, &current[e..]);
                                                text_val.set(updated.clone());
                                                on_update_content.call(updated);
                                            } else {
                                                text_color.set(c_str.clone());
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    div { style: "width: 1px; height: 14px; background: rgba(0, 240, 255, 0.25); margin: 0 2px;" }

                    // SEÇÃO 3: ATALHOS ESPECIAIS INTEGRADOS NA PÍLULA
                    button {
                        r#type: "button",
                        title: "Menu de Atalhos LaTeX",
                        style: if show_latex_menu() { "background: rgba(168, 85, 247, 0.35); color: #ffffff; border: none; border-radius: 6px; padding: 2px 7px; font-size: 10px; font-weight: bold; cursor: pointer; display: flex; align-items: center; gap: 4px;" } else { "background: rgba(168, 85, 247, 0.15); color: #d8b4fe; border: none; border-radius: 6px; padding: 2px 7px; font-size: 10px; font-weight: bold; cursor: pointer; display: flex; align-items: center; gap: 4px; transition: all 0.15s ease;" },
                        onmousedown: move |e| e.prevent_default(),
                        onclick: move |_| show_latex_menu.toggle(),
                        svg {
                            width: "11",
                            height: "11",
                            view_box: "0 0 24 24",
                            fill: "none",
                            stroke: "currentColor",
                            stroke_width: "2.2",
                            path { d: "M12 4v16M8 8h8M8 16h8" }
                        }
                        "LaTeX "
                        span { style: "font-size: 8px;", if show_latex_menu() { IconChevronUp {} } else { IconChevronDown {} } }
                    }

                    button {
                        r#type: "button",
                        title: "Inserir Diagrama Mermaid",
                        style: "background: rgba(0, 240, 255, 0.15); color: #00f0ff; border: none; border-radius: 6px; padding: 2px 7px; font-size: 10px; font-weight: bold; cursor: pointer; display: flex; align-items: center; gap: 4px; transition: all 0.15s ease;",
                        onmousedown: move |e| e.prevent_default(),
                        onclick: move |_| insert_format(("```mermaid\ngraph TD\n    A[Início] --> B[Processo]\n    B --> C[Fim]\n```", "", "")),
                        svg {
                            width: "11",
                            height: "11",
                            view_box: "0 0 24 24",
                            fill: "none",
                            stroke: "currentColor",
                            stroke_width: "2",
                            circle { cx: "6", cy: "6", r: "3" }
                            circle { cx: "18", cy: "6", r: "3" }
                            circle { cx: "12", cy: "18", r: "3" }
                            path { d: "M8.5 7.5l3 7.5M15.5 7.5l-3 7.5" }
                        }
                        "Mermaid"
                    }

                    div { style: "width: 1px; height: 14px; background: rgba(255,255,255,0.2); margin: 0 2px;" }

                    button {
                        r#type: "button",
                        style: if is_editing() { "background: #00f0ff; color: #03060d; border: none; border-radius: 9999px; padding: 2px 8px; font-size: 10px; font-weight: bold; cursor: pointer; display: flex; align-items: center; gap: 4px; box-shadow: 0 0 6px rgba(0,240,255,0.4);" } else { "background: rgba(255,255,255,0.12); color: #e2e8f0; border: none; border-radius: 9999px; padding: 2px 8px; font-size: 10px; cursor: pointer; display: flex; align-items: center; gap: 4px;" },
                        onmousedown: move |e| e.prevent_default(),
                        onclick: move |_| is_editing.toggle(),
                        if is_editing() {
                            svg {
                                width: "11",
                                height: "11",
                                view_box: "0 0 24 24",
                                fill: "none",
                                stroke: "currentColor",
                                stroke_width: "2.5",
                                polyline { points: "20 6 9 17 4 12" }
                            }
                        } else {
                            svg {
                                width: "11",
                                height: "11",
                                view_box: "0 0 24 24",
                                fill: "none",
                                stroke: "currentColor",
                                stroke_width: "2.2",
                                path { d: "M12 20h9" }
                                path { d: "M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" }
                            }
                        }
                        if is_editing() { "Concluído" } else { "Editar" }
                    }
                }
            }

            // MENU FLUTUANTE EXPANDIDO DE ATALHOS LATEX (Item 24)
            if show_latex_menu() {
                div {
                    style: "position: absolute; top: -145px; left: 0; right: 0; z-index: 100; background: rgba(10, 16, 30, 0.95); border: 1px solid rgba(168, 85, 247, 0.5); border-radius: 8px; padding: 8px; box-shadow: 0 8px 24px rgba(0,0,0,0.6); backdrop-filter: blur(12px); max-height: 140px; overflow-y: auto; display: flex; flex-direction: column; gap: 6px;",
                    onmousedown: move |e| {
                        e.prevent_default();
                        e.stop_propagation();
                    },
                    onclick: move |e| e.stop_propagation(),
                    onwheel: move |e| e.stop_propagation(),

                    for (cat_name, items) in latex_shortcuts {
                        {
                            rsx! {
                                div { key: "{cat_name}", style: "display: flex; flex-direction: column; gap: 3px;",
                                    div { style: "font-size: 9px; font-weight: bold; color: #d8b4fe; text-transform: uppercase; letter-spacing: 0.5px;", "{cat_name}" }
                                    div { style: "display: flex; flex-wrap: wrap; gap: 3px;",
                                        for (snippet, label) in items {
                                            {
                                                let snip = snippet;
                                                rsx! {
                                                    button {
                                                        key: "{label}",
                                                        r#type: "button",
                                                        title: "Inserir {snip}",
                                                        style: "background: rgba(168, 85, 247, 0.15); color: #00f0ff; border: 1px solid rgba(168, 85, 247, 0.3); border-radius: 4px; padding: 2px 6px; font-size: 10px; font-family: monospace; cursor: pointer; transition: all 0.1s ease;",
                                                        onmousedown: move |e| e.prevent_default(),
                                                        onclick: move |_| {
                                                            insert_format(("$ ", " $", snip));
                                                        },
                                                        "{label}"
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

            // 100% CARD BODY AREA FOR CONTENT
            div {
                style: "flex: 1; width: 100%; min-height: 0; overflow-y: auto; display: flex; flex-direction: column;",
                onclick: move |e| {
                    e.stop_propagation();
                    is_editing.set(true);
                },
                onwheel: move |e| e.stop_propagation(),
                {body_elem}
            }
        }
    }
}

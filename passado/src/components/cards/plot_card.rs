use crate::types::*;
use crate::icons::*;
use dioxus::prelude::*;
use std::f64::consts::{E, PI};

// =========================================================================
// 1. LATEX SANITIZER & EXPRESSION PREPROCESSOR
// =========================================================================

/// Preprocesses raw user input (plain text or LaTeX) into clean math string.
pub fn preprocess_expression(raw: &str) -> String {
    let mut s = raw.trim().to_string();

    // Strip LaTeX math delimiters
    if s.starts_with("\\[") && s.ends_with("\\]") {
        s = s[2..s.len() - 2].trim().to_string();
    } else if s.starts_with("\\(") && s.ends_with("\\)") {
        s = s[2..s.len() - 2].trim().to_string();
    } else if s.starts_with('$') && s.ends_with('$') && s.len() >= 2 {
        s = s[1..s.len() - 1].trim().to_string();
    }

    // Clean common function prefixes (e.g. f(x) =, y =, x =, z =, f(x,y) =)
    loop {
        let lower = s.to_lowercase();
        if lower.starts_with("f(x,y)=") || lower.starts_with("f(x, y)=") {
            if let Some(idx) = s.find('=') { s = s[idx + 1..].trim().to_string(); continue; }
        }
        if lower.starts_with("f(x)=") || lower.starts_with("f(x) =") {
            if let Some(idx) = s.find('=') { s = s[idx + 1..].trim().to_string(); continue; }
        }
        if lower.starts_with("f(y)=") || lower.starts_with("f(y) =") {
            if let Some(idx) = s.find('=') { s = s[idx + 1..].trim().to_string(); continue; }
        }
        if lower.starts_with("z=") || lower.starts_with("z =") {
            if let Some(idx) = s.find('=') { s = s[idx + 1..].trim().to_string(); continue; }
        }
        if lower.starts_with("y=") || lower.starts_with("y =") {
            if let Some(idx) = s.find('=') { s = s[idx + 1..].trim().to_string(); continue; }
        }
        if lower.starts_with("x=") || lower.starts_with("x =") {
            if let Some(idx) = s.find('=') { s = s[idx + 1..].trim().to_string(); continue; }
        }
        break;
    }

    // Convert LaTeX fractions: \frac{a}{b} -> ((a)/(b))
    while let Some(idx) = s.find("\\frac") {
        if let Some(rest) = parse_two_curly_args(&s[idx + 5..]) {
            let (num, denom, len) = rest;
            let replacement = format!("(({})/({}))", num, denom);
            s.replace_range(idx..idx + 5 + len, &replacement);
        } else {
            break;
        }
    }

    // Convert LaTeX square roots: \sqrt[n]{x} or \sqrt{x}
    while let Some(idx) = s.find("\\sqrt") {
        let rest_str = &s[idx + 5..];
        if rest_str.starts_with('[') {
            if let Some(end_bracket) = rest_str.find(']') {
                let root_n = &rest_str[1..end_bracket];
                if let Some((arg, len)) = parse_curly_arg(&rest_str[end_bracket + 1..]) {
                    let replacement = format!("(({})^(1/({})))", arg, root_n);
                    s.replace_range(idx..idx + 5 + end_bracket + 1 + len, &replacement);
                    continue;
                }
            }
        } else if let Some((arg, len)) = parse_curly_arg(rest_str) {
            let replacement = format!("sqrt({})", arg);
            s.replace_range(idx..idx + 5 + len, &replacement);
            continue;
        }
        break;
    }

    // Replace LaTeX symbols & commands
    s = s.replace("\\left(", "(")
         .replace("\\right)", ")")
         .replace("\\left[", "(")
         .replace("\\right]", ")")
         .replace("\\cdot", "*")
         .replace("\\times", "*")
         .replace("\\div", "/")
         .replace("\\pi", "pi")
         .replace("\\tau", "tau")
         .replace("\\sin", "sin")
         .replace("\\cos", "cos")
         .replace("\\tan", "tan")
         .replace("\\asin", "asin")
         .replace("\\acos", "acos")
         .replace("\\atan", "atan")
         .replace("\\sinh", "sinh")
         .replace("\\cosh", "cosh")
         .replace("\\tanh", "tanh")
         .replace("\\ln", "ln")
         .replace("\\log", "log")
         .replace("\\exp", "exp")
         .replace("\\abs", "abs");

    // Replace LaTeX exponent brackets e.g. x^{2} -> x^(2)
    let mut clean_exp = String::new();
    let chars: Vec<char> = s.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '^' && i + 1 < chars.len() && chars[i + 1] == '{' {
            clean_exp.push('^');
            clean_exp.push('(');
            i += 2;
            let mut depth = 1;
            while i < chars.len() && depth > 0 {
                if chars[i] == '{' { depth += 1; }
                else if chars[i] == '}' { depth -= 1; }
                if depth > 0 {
                    clean_exp.push(chars[i]);
                } else {
                    clean_exp.push(')');
                }
                i += 1;
            }
        } else {
            clean_exp.push(chars[i]);
            i += 1;
        }
    }

    clean_exp
}

fn parse_curly_arg(s: &str) -> Option<(String, usize)> {
    let trimmed = s.trim_start();
    if !trimmed.starts_with('{') { return None; }
    let start_offset = s.len() - trimmed.len();
    let mut depth = 0;
    let mut arg = String::new();
    for (i, c) in trimmed.chars().enumerate() {
        if c == '{' {
            depth += 1;
            if depth > 1 { arg.push(c); }
        } else if c == '}' {
            depth -= 1;
            if depth == 0 {
                return Some((arg, start_offset + i + 1));
            } else {
                arg.push(c);
            }
        } else {
            arg.push(c);
        }
    }
    None
}

fn parse_two_curly_args(s: &str) -> Option<(String, String, usize)> {
    let (arg1, len1) = parse_curly_arg(s)?;
    let (arg2, len2) = parse_curly_arg(&s[len1..])?;
    Some((arg1, arg2, len1 + len2))
}

// =========================================================================
// 2. MATHEMATICAL EVALUATOR
// =========================================================================

struct MathEvaluator<'a> {
    src: &'a str,
    pos: usize,
    x: f64,
    y: f64,
}

impl<'a> MathEvaluator<'a> {
    fn new(src: &'a str, x: f64, y: f64) -> Self {
        Self { src, pos: 0, x, y }
    }

    fn peek(&self) -> Option<char> {
        self.src[self.pos..].chars().next()
    }

    fn get_char(&mut self) -> Option<char> {
        let c = self.peek()?;
        self.pos += c.len_utf8();
        Some(c)
    }

    fn skip_whitespace(&mut self) {
        while let Some(c) = self.peek() {
            if c.is_whitespace() {
                self.get_char();
            } else {
                break;
            }
        }
    }

    fn parse_expression(&mut self) -> f64 {
        self.skip_whitespace();
        let mut left = self.parse_term();
        loop {
            self.skip_whitespace();
            match self.peek() {
                Some('+') => {
                    self.get_char();
                    left += self.parse_term();
                }
                Some('-') => {
                    self.get_char();
                    left -= self.parse_term();
                }
                _ => break,
            }
        }
        left
    }

    fn parse_term(&mut self) -> f64 {
        self.skip_whitespace();
        let mut left = self.parse_factor();
        loop {
            self.skip_whitespace();
            match self.peek() {
                Some('*') => {
                    self.get_char();
                    left *= self.parse_factor();
                }
                Some('/') => {
                    self.get_char();
                    let denom = self.parse_factor();
                    if denom != 0.0 {
                        left /= denom;
                    } else {
                        left = f64::NAN;
                    }
                }
                Some('%') => {
                    self.get_char();
                    left %= self.parse_factor();
                }
                Some(c) if c.is_alphabetic() || c == '(' => {
                    left *= self.parse_factor();
                }
                _ => break,
            }
        }
        left
    }

    fn parse_factor(&mut self) -> f64 {
        self.skip_whitespace();
        let mut left = self.parse_power();
        self.skip_whitespace();
        if self.peek() == Some('^') {
            self.get_char();
            let right = self.parse_factor();
            left = left.powf(right);
        }
        left
    }

    fn parse_power(&mut self) -> f64 {
        self.skip_whitespace();
        if self.peek() == Some('-') {
            self.get_char();
            return -self.parse_power();
        }
        if self.peek() == Some('+') {
            self.get_char();
            return self.parse_power();
        }
        self.parse_primary()
    }

    fn parse_primary(&mut self) -> f64 {
        self.skip_whitespace();
        match self.peek() {
            Some('(') => {
                self.get_char();
                let val = self.parse_expression();
                self.skip_whitespace();
                if self.peek() == Some(')') {
                    self.get_char();
                }
                val
            }
            Some(c) if c.is_ascii_digit() || c == '.' => self.parse_number(),
            Some(c) if c.is_alphabetic() => self.parse_identifier(),
            _ => 0.0,
        }
    }

    fn parse_number(&mut self) -> f64 {
        let start = self.pos;
        while let Some(c) = self.peek() {
            if c.is_ascii_digit() || c == '.' {
                self.get_char();
            } else {
                break;
            }
        }
        self.src[start..self.pos].parse::<f64>().unwrap_or(0.0)
    }

    fn parse_identifier(&mut self) -> f64 {
        let start = self.pos;
        while let Some(c) = self.peek() {
            if c.is_alphanumeric() || c == '_' {
                self.get_char();
            } else {
                break;
            }
        }
        let id = &self.src[start..self.pos];
        self.skip_whitespace();

        if self.peek() == Some('(') {
            self.get_char();
            let arg = self.parse_expression();
            self.skip_whitespace();
            if self.peek() == Some(')') {
                self.get_char();
            }
            match id {
                "sin" => arg.sin(),
                "cos" => arg.cos(),
                "tan" => arg.tan(),
                "asin" => arg.asin(),
                "acos" => arg.acos(),
                "atan" => arg.atan(),
                "sinh" => arg.sinh(),
                "cosh" => arg.cosh(),
                "tanh" => arg.tanh(),
                "sqrt" => arg.sqrt(),
                "cbrt" => arg.cbrt(),
                "exp" => arg.exp(),
                "ln" | "log" => arg.ln(),
                "log10" => arg.log10(),
                "abs" => arg.abs(),
                "floor" => arg.floor(),
                "ceil" => arg.ceil(),
                "round" => arg.round(),
                "sign" | "signum" => arg.signum(),
                _ => arg,
            }
        } else {
            match id {
                "x" => self.x,
                "y" => self.y,
                "pi" => PI,
                "tau" => PI * 2.0,
                "e" => E,
                _ => 0.0,
            }
        }
    }
}

pub fn eval_expr(expr: &str, x: f64, y: f64) -> f64 {
    let clean = preprocess_expression(expr);
    let clean = clean.trim().to_lowercase();
    if clean.is_empty() {
        return f64::NAN;
    }
    let mut evaluator = MathEvaluator::new(&clean, x, y);
    let val = evaluator.parse_expression();
    if val.is_nan() || val.is_infinite() { f64::NAN } else { val }
}

fn project_3d_rot(
    x: f64,
    y: f64,
    z: f64,
    width: f64,
    height: f64,
    pitch: f64,
    yaw: f64,
    pan_offset: (f64, f64),
    zoom: f64,
) -> (f64, f64) {
    let x1 = x * yaw.cos() - y * yaw.sin();
    let y1 = x * yaw.sin() + y * yaw.cos();
    let z1 = z;

    let y2 = y1 * pitch.cos() - z1 * pitch.sin();
    let z2 = y1 * pitch.sin() + z1 * pitch.cos();
    let x2 = x1;

    let scale = 18.0 * zoom;
    let screen_x = width / 2.0 + pan_offset.0 + x2 * scale;
    let screen_y = height / 2.0 + pan_offset.1 - y2 * scale * 0.7 - z2 * scale * 0.6 + 10.0;

    (screen_x, screen_y)
}

fn z_height_color(z: f64, min_z: f64, max_z: f64) -> String {
    let range = (max_z - min_z).max(0.001);
    let norm = ((z - min_z) / range).clamp(0.0, 1.0);
    let hue = 220.0 + norm * 120.0;
    format!("hsl({:.0}, 85%, 60%)", hue)
}

fn format_tick(val: f64) -> String {
    if (val - val.round()).abs() < 1e-7 {
        format!("{:.0}", val.round())
    } else {
        let s = format!("{:.6}", val);
        let trimmed = s.trim_end_matches('0').trim_end_matches('.');
        trimmed.to_string()
    }
}

// Helper structs for SVG pre-render calculations
struct Render2DData {
    cx: f64,
    cy: f64,
    scale_x: f64,
    scale_y: f64,
    grid_x: Vec<(f64, bool, String)>,
    grid_y: Vec<(f64, bool, String)>,
    function_paths: Vec<(String, &'static str)>,
}

struct Render3DData {
    axis_x: (String, (f64, f64)),
    axis_y: (String, (f64, f64)),
    axis_z: (String, (f64, f64)),
    mesh_lines: Vec<(String, String)>,
}

// =========================================================================
// 3. MAIN COMPONENT: PLOT CARD
// =========================================================================

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PlotFunction {
    pub id: usize,
    pub expr: String,
    pub active: bool,
}

pub fn parse_plot_functions(content: &str) -> Vec<PlotFunction> {
    let trimmed = content.trim();
    if trimmed.is_empty() {
        return vec![PlotFunction {
            id: 1,
            expr: "sin(x)".to_string(),
            active: true,
        }];
    }

    if let Ok(parsed) = serde_json::from_str::<Vec<PlotFunction>>(trimmed) {
        if !parsed.is_empty() {
            return parsed;
        }
    }

    let parts: Vec<&str> = trimmed
        .split(|c| c == ',' || c == ';' || c == '\n')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .collect();

    if parts.is_empty() {
        vec![PlotFunction {
            id: 1,
            expr: "sin(x)".to_string(),
            active: true,
        }]
    } else {
        parts
            .into_iter()
            .enumerate()
            .map(|(idx, s)| PlotFunction {
                id: idx + 1,
                expr: s.to_string(),
                active: true,
            })
            .collect()
    }
}

pub fn serialize_plot_functions(funcs: &[PlotFunction]) -> String {
    serde_json::to_string(funcs).unwrap_or_default()
}

#[component]
pub fn PlotCard(
    card: NoteCard,
    on_update_content: EventHandler<String>,
    #[props(default)] on_update_title: EventHandler<String>,
    #[props(default)] on_ai_click: EventHandler<String>,
) -> Element {
    let mut functions = use_signal(|| parse_plot_functions(&card.content));
    let mut draft_exprs = use_signal(|| {
        let mut map = std::collections::HashMap::new();
        for f in functions() {
            map.insert(f.id, f.expr.clone());
        }
        map
    });

    use_effect(use_reactive((&card.content,), move |(content,)| {
        let parsed = parse_plot_functions(&content);
        if parsed != functions() {
            functions.set(parsed.clone());
            draft_exprs.with_mut(|map| {
                for f in &parsed {
                    map.entry(f.id).or_insert_with(|| f.expr.clone());
                }
            });
        }
    }));

    let active_funcs: Vec<(usize, String)> = functions()
        .into_iter()
        .filter(|f| f.active && !f.expr.trim().is_empty())
        .map(|f| (f.id, f.expr))
        .collect();

    let active_preprocessed: Vec<(usize, String, String)> = active_funcs
        .iter()
        .map(|(id, expr)| (*id, expr.clone(), preprocess_expression(expr)))
        .collect();

    let is_3d = active_preprocessed.iter().any(|(_, _, clean)| {
        (clean.contains('x') && clean.contains('y')) || clean.contains('z')
    });

    let mut zoom_level = use_signal(|| 1.0f64);
    let mut pan_offset = use_signal(|| (0.0f64, 0.0f64));

    let mut pitch = use_signal(|| 0.55f64);
    let mut yaw = use_signal(|| -0.6f64);

    let mut is_dragging = use_signal(|| false);
    let mut drag_mode = use_signal(|| "rotate");
    let mut drag_start = use_signal(|| (0.0f64, 0.0f64));

    let mut hover_pos = use_signal(|| Option::<(f64, f64)>::None);
    let mut inspected_point = use_signal(|| Option::<(f64, f64, f64)>::None);
    let mut point_x_str = use_signal(|| String::new());

    // Auto-update inspected_point position whenever active expressions change
    use_effect(use_reactive((&active_preprocessed,), move |(active_exprs,)| {
        if let Some((px, py, _old_z)) = inspected_point() {
            if let Some((_, _, first_clean)) = active_exprs.first() {
                let new_z = eval_expr(first_clean, px, py);
                if !new_z.is_nan() {
                    inspected_point.set(Some((px, py, new_z)));
                }
            }
        }
    }));

    let width = (card.width - 32.0).max(100.0);
    let height = (card.height - 80.0).max(100.0);

    let expr_for_down = active_preprocessed
        .first()
        .map(|(_, _, clean)| clean.clone())
        .unwrap_or_default();
    let expr_for_down_click = expr_for_down.clone();

    let on_update_content_cb = on_update_content.clone();
    let on_update_title_cb = on_update_title.clone();

    let mut commit_funcs = move |new_funcs: Vec<PlotFunction>| {
        functions.set(new_funcs.clone());
        let json_str = serialize_plot_functions(&new_funcs);
        on_update_content_cb.call(json_str);

        let active_exprs: Vec<String> = new_funcs
            .iter()
            .filter(|f| f.active && !f.expr.trim().is_empty())
            .map(|f| f.expr.trim().to_string())
            .collect();

        let new_title = if active_exprs.is_empty() {
            "Gráfico".to_string()
        } else if active_exprs.iter().any(|e| {
            let clean = preprocess_expression(e);
            (clean.contains('x') && clean.contains('y')) || clean.contains('z')
        }) {
            format!("f(x,y) = {}", active_exprs.join(", "))
        } else {
            format!("f(x) = {}", active_exprs.join(", "))
        };
        on_update_title_cb.call(new_title);
    };

    let add_function = move |_| {
        let mut current = functions();
        let max_id = current.iter().map(|f| f.id).max().unwrap_or(0);
        let new_func = PlotFunction {
            id: max_id + 1,
            expr: "".to_string(),
            active: true,
        };
        draft_exprs.with_mut(|map| {
            map.insert(new_func.id, "".to_string());
        });
        current.push(new_func);
        commit_funcs(current);
    };

    let handle_svg_mouse_down = move |evt: MouseEvent| {
        evt.stop_propagation();
        let trigger_button = evt.trigger_button();
        let is_shift = evt.modifiers().shift();

        let coords = evt.element_coordinates();
        drag_start.set((coords.x, coords.y));

        if trigger_button == Some(dioxus::html::input_data::MouseButton::Primary) {
            let current_zoom = zoom_level();
            let cx = width / 2.0 + pan_offset().0;
            let cy = height / 2.0 + pan_offset().1;
            let scale_x = 28.0 * current_zoom;
            let scale_y = 28.0 * current_zoom;

            let math_x = (coords.x - cx) / scale_x;
            let math_y = (cy - coords.y) / scale_y;

            if !is_3d {
                let is_fn_of_y = expr_for_down_click.contains('y');
                if is_fn_of_y {
                    let calc_x = eval_expr(&expr_for_down_click, 0.0, math_y);
                    if !calc_x.is_nan() {
                        inspected_point.set(Some((calc_x, math_y, calc_x)));
                        point_x_str.set(format!("{:.3}", math_y));
                    }
                } else {
                    let calc_y = eval_expr(&expr_for_down_click, math_x, 0.0);
                    if !calc_y.is_nan() {
                        inspected_point.set(Some((math_x, 0.0, calc_y)));
                        point_x_str.set(format!("{:.3}", math_x));
                    }
                }
            } else {
                let val_z = eval_expr(&expr_for_down_click, math_x, math_y);
                if !val_z.is_nan() {
                    inspected_point.set(Some((math_x, math_y, val_z)));
                    point_x_str.set(format!("{:.2}", math_x));
                }
            }
        }

        if trigger_button == Some(dioxus::html::input_data::MouseButton::Auxiliary) {
            is_dragging.set(true);
            if is_shift {
                drag_mode.set("pan");
            } else if is_3d {
                drag_mode.set("rotate");
            } else {
                drag_mode.set("pan");
            }
        }
    };

    let handle_svg_mouse_move = move |evt: MouseEvent| {
        let coords = evt.element_coordinates();
        hover_pos.set(Some((coords.x, coords.y)));

        if is_dragging() {
            evt.stop_propagation();
            let start = drag_start();
            let dx = coords.x - start.0;
            let dy = coords.y - start.1;
            drag_start.set((coords.x, coords.y));

            if is_3d && drag_mode() == "rotate" {
                yaw.with_mut(|y| *y += dx * 0.008);
                pitch.with_mut(|p| *p = (*p + dy * 0.008).clamp(-1.4, 1.4));
            } else {
                pan_offset.with_mut(|p| {
                    p.0 += dx;
                    p.1 += dy;
                });
            }
        }
    };

    let handle_svg_mouse_up = move |_| {
        is_dragging.set(false);
    };

    let handle_svg_mouse_leave = move |_| {
        is_dragging.set(false);
        hover_pos.set(None);
    };

    let handle_wheel = move |evt: WheelEvent| {
        evt.stop_propagation();
        let delta = evt.delta().strip_units().y;
        zoom_level.with_mut(|z| *z = (*z * if delta > 0.0 { 0.9 } else { 1.1 }).clamp(0.1, 50.0));
    };

    let reset_view = move |_| {
        zoom_level.set(1.0);
        pan_offset.set((0.0, 0.0));
        pitch.set(0.55);
        yaw.set(-0.6);
        inspected_point.set(None);
    };

    let colors = ["#00f0ff", "#ff007f", "#00ff99", "#ffb700", "#b55fe6", "#f43f5e", "#a855f7"];

    // Pre-calculate 2D Render Data
    let render_2d = if !is_3d {
        let current_zoom = zoom_level();
        let cx = width / 2.0 + pan_offset().0;
        let cy = height / 2.0 + pan_offset().1;
        let scale_x = 28.0 * current_zoom;
        let scale_y = 28.0 * current_zoom;

        let raw_step = 50.0 / scale_x;
        let mag = 10.0f64.powf(raw_step.log10().floor());
        let norm_step = raw_step / mag;
        let step = if norm_step < 2.0 { 1.0 } else if norm_step < 5.0 { 2.0 } else { 5.0 } * mag;

        let min_math_x = (-cx) / scale_x;
        let max_math_x = (width - cx) / scale_x;
        let min_math_y = (cy - height) / scale_y;
        let max_math_y = cy / scale_y;

        let start_grid_x = (min_math_x / step).floor() as i64;
        let end_grid_x = (max_math_x / step).ceil() as i64;
        let start_grid_y = (min_math_y / step).floor() as i64;
        let end_grid_y = (max_math_y / step).ceil() as i64;

        let grid_x: Vec<(f64, bool, String)> = (start_grid_x..=end_grid_x).map(|i| {
            let val = i as f64 * step;
            (val, i == 0, format_tick(val))
        }).collect();
        let grid_y: Vec<(f64, bool, String)> = (start_grid_y..=end_grid_y).map(|j| {
            let val = j as f64 * step;
            (val, j == 0, format_tick(val))
        }).collect();

        let function_paths: Vec<(String, &'static str)> = active_preprocessed.iter().enumerate().map(|(idx, (_id, _raw, clean_expr))| {
            let mut path_data = String::new();
            let steps = 240;
            let mut first = true;

            let is_fn_of_y = clean_expr.contains('y');

            for i in 0..=steps {
                let t = i as f64 / steps as f64;
                let (x, y) = if is_fn_of_y {
                    let math_y = min_math_y + t * (max_math_y - min_math_y);
                    let calc_x = eval_expr(clean_expr, 0.0, math_y);
                    (calc_x, math_y)
                } else {
                    let math_x = min_math_x + t * (max_math_x - min_math_x);
                    let calc_y = eval_expr(clean_expr, math_x, 0.0);
                    (math_x, calc_y)
                };

                if x.is_nan() || x.is_infinite() || y.is_nan() || y.is_infinite() || x.abs() > 1000.0 || y.abs() > 1000.0 {
                    first = true;
                    continue;
                }

                let screen_x = cx + x * scale_x;
                let screen_y = cy - y * scale_y;

                if first {
                    path_data.push_str(&format!("M {:.1} {:.1}", screen_x, screen_y));
                    first = false;
                } else {
                    path_data.push_str(&format!(" L {:.1} {:.1}", screen_x, screen_y));
                }
            }

            (path_data, colors[idx % colors.len()])
        }).collect();

        Some(Render2DData { cx, cy, scale_x, scale_y, grid_x, grid_y, function_paths })
    } else {
        None
    };

    // Pre-calculate 3D Render Data
    let render_3d = if is_3d {
        let current_zoom = zoom_level();
        let p_val = pitch();
        let y_val = yaw();
        let grid_size = 16;
        let range = 4.0;
        let step = (range * 2.0) / grid_size as f64;

        let mut mesh_lines = Vec::new();
        let mut grid = vec![vec![((0.0, 0.0), 0.0); grid_size + 1]; grid_size + 1];

        let mut min_z = f64::MAX;
        let mut max_z = f64::MIN;

        for i in 0..=grid_size {
            for j in 0..=grid_size {
                let x = -range + i as f64 * step;
                let y = -range + j as f64 * step;
                let z = eval_expr(&expr_for_down, x, y);
                let (sx, sy) = project_3d_rot(x, y, z, width, height, p_val, y_val, pan_offset(), current_zoom);
                grid[i][j] = ((sx, sy), z);
                if !z.is_nan() {
                    min_z = min_z.min(z);
                    max_z = max_z.max(z);
                }
            }
        }

        for i in 0..=grid_size {
            let mut path_x = String::new();
            let mut path_y = String::new();
            for j in 0..=grid_size {
                let (p_x, _z1) = grid[i][j];
                let (p_y, _z2) = grid[j][i];
                if j == 0 {
                    path_x.push_str(&format!("M {:.1} {:.1}", p_x.0, p_x.1));
                    path_y.push_str(&format!("M {:.1} {:.1}", p_y.0, p_y.1));
                } else {
                    path_x.push_str(&format!(" L {:.1} {:.1}", p_x.0, p_x.1));
                    path_y.push_str(&format!(" L {:.1} {:.1}", p_y.0, p_y.1));
                }
            }
            let z_avg = grid[i][grid_size / 2].1;
            let color = z_height_color(z_avg, min_z, max_z);
            mesh_lines.push((path_x, color.clone()));
            mesh_lines.push((path_y, color));
        }

        let origin = project_3d_rot(0.0, 0.0, 0.0, width, height, p_val, y_val, pan_offset(), current_zoom);
        let axis_x_p = project_3d_rot(range * 1.2, 0.0, 0.0, width, height, p_val, y_val, pan_offset(), current_zoom);
        let axis_y_p = project_3d_rot(0.0, range * 1.2, 0.0, width, height, p_val, y_val, pan_offset(), current_zoom);
        let axis_z_p = project_3d_rot(0.0, 0.0, range * 1.2, width, height, p_val, y_val, pan_offset(), current_zoom);

        let axis_x = (format!("M {:.1} {:.1} L {:.1} {:.1}", origin.0, origin.1, axis_x_p.0, axis_x_p.1), (axis_x_p.0 + 4.0, axis_x_p.1));
        let axis_y = (format!("M {:.1} {:.1} L {:.1} {:.1}", origin.0, origin.1, axis_y_p.0, axis_y_p.1), (axis_y_p.0 + 4.0, axis_y_p.1));
        let axis_z = (format!("M {:.1} {:.1} L {:.1} {:.1}", origin.0, origin.1, axis_z_p.0, axis_z_p.1), (axis_z_p.0 + 4.0, axis_z_p.1));

        Some(Render3DData { axis_x, axis_y, axis_z, mesh_lines })
    } else {
        None
    };

    rsx! {
        div { class: "moscaro plot-card-container", style: "display: flex; flex-direction: column; gap: 6px; width: 100%; height: 100%; min-height: 0; flex: 1; overflow: hidden; padding: 6px;",

            // FLOATING MOSCARO TOOLBAR PILL (aparece quando card selecionado ou hover)
            if card.selected {
                div {
                    class: "floating-card-toolbar plot-toolbar",
                    style: "position: relative; z-index: 10;",
                    onmousedown: move |e| {
                        e.prevent_default();
                        e.stop_propagation();
                    },
                    onclick: move |e| e.stop_propagation(),

                    // Plot type indicator
                    span { style: "font-size: 10px; font-family: monospace; font-weight: bold; color: #a855f7; text-transform: uppercase; letter-spacing: 0.5px; padding: 2px 8px; background: rgba(168, 85, 247, 0.15); border: 1px solid rgba(168, 85, 247, 0.3); border-radius: 9999px;",
                        if is_3d { "🧊 3D Surface" } else { "📈 2D Plot" }
                    }

                    div { style: "width: 1px; height: 14px; background: rgba(168, 85, 247, 0.25); margin: 0 4px;" }

                    // Add function
                    button {
                        r#type: "button",
                        title: "Adicionar função",
                        
                        onmousedown: move |e| e.prevent_default(),
                        onclick: add_function,
                        "+ Função"
                    }

                    // Reset camera
                    button {
                        r#type: "button",
                        title: "Resetar Câmera (Zoom/Pan)",
                        
                        onmousedown: move |e| e.prevent_default(),
                        onclick: reset_view,
                        "Reset"
                    }

                    div { style: "width: 1px; height: 14px; background: rgba(255,255,255,0.15); margin: 0 4px;" }

                    // AI assistant for this plot
                    button {
                        r#type: "button",
                        title: "Assistente de IA para este gráfico",
                        style: "background: linear-gradient(135deg, rgba(168, 85, 247, 0.22), rgba(0, 225, 255, 0.22)); color: #d8b4fe; border: 1px solid rgba(168, 85, 247, 0.45); border-radius: 9999px; padding: 2px 8px; font-size: 10px; font-weight: bold; cursor: pointer; display: flex; align-items: center; gap: 4px;",
                        onmousedown: move |e| e.prevent_default(),
                        onclick: move |_| on_ai_click.call(card.content.clone()),
                        "✨ IA"
                    }
                }
            }

            // TOP CONTROLS & MULTI-FUNCTION MANAGEMENT PANEL
            div { class: "moscaro plot-functions-panel", style: "display: flex; flex-direction: column; gap: 4px; width: 100%; max-height: 120px; overflow-y: auto; padding: 6px; border-radius: 10px; border: 1px solid rgba(0, 240, 255, 0.2); background: rgba(5, 10, 20, 0.5); backdrop-filter: blur(8px);",
                for (idx, func) in functions().into_iter().enumerate() {
                    {
                        let func_id = func.id;
                        let is_active = func.active;
                        let draft_val = draft_exprs().get(&func_id).cloned().unwrap_or_else(|| func.expr.clone());
                        let color = colors[idx % colors.len()];

                        rsx! {
                            div {
                                key: "fn_row_{func_id}",
                                class: "moscaro plot-function-row",
                                style: "display: flex; gap: 6px; align-items: center; width: 100%; padding: 4px; border-radius: 8px; background: rgba(0, 0, 0, 0.2); border: 1px solid rgba(255, 255, 255, 0.08); transition: all 0.15s ease;",
                                onmouseenter: move |_| {},
                                onmouseleave: move |_| {},

                                // Active toggle button
                                button {
                                    style: format!(
                                        "height: 22px; width: 22px; font-size: 10px; border-radius: 9999px; border: 1px solid {}; background: {}; color: {}; cursor: pointer; display: flex; align-items: center; justify-content: center; font-weight: bold; flex-shrink: 0; transition: all 0.15s ease;",
                                        color,
                                        if is_active { color } else { "transparent" },
                                        if is_active { "#03060d" } else { color }
                                    ),
                                    title: if is_active { "Desativar função" } else { "Ativar função" },
                                    onclick: move |e| {
                                        e.stop_propagation();
                                        let mut current = functions();
                                        if let Some(f) = current.iter_mut().find(|f| f.id == func_id) {
                                            f.active = !f.active;
                                        }
                                        commit_funcs(current);
                                    },
                                    if is_active { "✓" } else { "" }
                                }

                                // Expression input
                                input {
                                    class: "plot-expr-input",
                                    style: "flex: 1; height: 22px; font-family: 'Fira Code', monospace; font-size: 11px; font-weight: 600; color: #00f0ff; background: rgba(0, 240, 255, 0.06); border: 1px solid rgba(0, 240, 255, 0.25); border-radius: 6px; padding: 0 8px; outline: none; box-sizing: border-box; transition: border-color 0.15s ease, box-shadow 0.15s ease;",
                                    placeholder: "f(x) = ... (Enter para plotar)",
                                    value: "{draft_val}",
                                    onmousedown: move |e| e.stop_propagation(),
                                    onclick: move |e| e.stop_propagation(),
                                    oninput: move |e: FormEvent| {
                                        let val = e.value();
                                        draft_exprs.with_mut(|map| { map.insert(func_id, val); });
                                    },
                                    onkeydown: move |e: KeyboardEvent| {
                                        if e.key() == Key::Enter {
                                            e.stop_propagation();
                                            let draft_val = draft_exprs().get(&func_id).cloned().unwrap_or_default();
                                            let mut current = functions();
                                            if let Some(f) = current.iter_mut().find(|f| f.id == func_id) {
                                                f.expr = draft_val;
                                            }
                                            commit_funcs(current);
                                        }
                                    },
                                    onfocus: move |_| {},
                                    onblur: move |_| {},
                                }

                                // Plot button
                                button {
                                    class: "moscaro plot-btn-plot",
                                    style: "height: 22px; padding: 0 8px; font-size: 9px; font-family: monospace; font-weight: bold; color: #00f0ff; background: rgba(0, 240, 255, 0.12); border: 1px solid rgba(0, 240, 255, 0.3); border-radius: 9999px; cursor: pointer; flex-shrink: 0; transition: all 0.15s ease;",
                                    title: "Plotar função (Enter)",
                                    onclick: move |e| {
                                        e.stop_propagation();
                                        let draft_val = draft_exprs().get(&func_id).cloned().unwrap_or_default();
                                        let mut current = functions();
                                        if let Some(f) = current.iter_mut().find(|f| f.id == func_id) {
                                            f.expr = draft_val;
                                        }
                                        commit_funcs(current);
                                    },
                                    "Plotar"
                                }

                                // Remove button
                                button {
                                    class: "moscaro plot-btn-remove",
                                    style: "height: 22px; width: 22px; font-size: 12px; color: #f43f5e; background: rgba(244, 63, 94, 0.1); border: 1px solid rgba(244, 63, 94, 0.25); border-radius: 9999px; cursor: pointer; display: flex; align-items: center; justify-content: center; flex-shrink: 0; transition: all 0.15s ease;",
                                    title: "Remover função",
                                    onclick: move |e| {
                                        e.stop_propagation();
                                        let mut current = functions();
                                        current.retain(|f| f.id != func_id);
                                        draft_exprs.with_mut(|map| { map.remove(&func_id); });
                                        commit_funcs(current);
                                    },
                                    "×"
                                }
                            }
                        }
                    }
                }
            }

            // BARRA DE AÇÃO (+ FUNÇÃO E RESET) - agora integrada na toolbar flutuante quando selecionado
            // Mantemos aqui apenas para quando não estiver selecionado
            div { class: "moscaro plot-action-bar", style: "display: flex; gap: 6px; align-items: center; justify-content: space-between; width: 100%; padding: 4px 0; opacity: 0.7; transition: opacity 0.2s ease;",
                button {
                    class: "moscaro plot-btn-add",
                    style: "height: 22px; padding: 0 8px; font-size: 10px; font-family: monospace; font-weight: bold; color: var(--accent-emerald, #00ffaa); background: var(--glass-bg); border: 1px solid var(--accent-emerald, #00ffaa); border-radius: 9999px; cursor: pointer; transition: all 0.2s ease; display: flex; align-items: center; gap: 4px;",
                    onclick: add_function,
                    title: "Adicionar mais uma função ao gráfico",
                    IconPlus {}
                    " Função"
                }

                button {
                    class: "moscaro plot-btn-reset",
                    style: "height: 22px; padding: 0 8px; font-size: 10px; font-family: monospace; font-weight: bold; color: var(--accent-cyan); background: var(--glass-bg); border: 1px solid var(--accent-cyan); border-radius: 9999px; cursor: pointer; transition: all 0.2s ease; display: flex; align-items: center; gap: 4px;",
                    onclick: reset_view,
                    title: "Resetar Posição / Câmera",
                    IconRefresh {}
                    "Reset Câmera"
                }
            }

            // CANVAS AREA
            div { class: "moscaro plot-canvas-area", style: "position: relative; flex: 1; width: 100%; height: 100%; min-height: 0; border-radius: 10px; overflow: hidden; background: #03060d; border: 1px solid rgba(255, 255, 255, 0.08); cursor: crosshair;",
                onmousedown: handle_svg_mouse_down,
                onmousemove: handle_svg_mouse_move,
                onmouseup: handle_svg_mouse_up,
                onmouseleave: handle_svg_mouse_leave,
                onwheel: handle_wheel,

                // MODE BADGE (2D / 3D INSTRUCTIONS)
                div { class: "moscaro plot-mode-badge", style: "position: absolute; top: 8px; right: 10px; font-size: 9px; font-family: monospace; font-weight: bold; color: var(--accent-cyan, #a855f7); background: var(--glass-bg); padding: 3px 8px; border-radius: 9999px; border: 1px solid var(--accent-cyan); pointer-events: none; backdrop-filter: blur(4px); box-shadow: 0 0 12px rgba(0, 240, 255, 0.15); display: flex; align-items: center; gap: 4px;",
                    if is_3d {
                        IconChart {}
                        span { " 3D • Scroll-Click: Girar | Shift+Scroll-Click: Mover" }
                    } else {
                        IconChart {}
                        span { " 2D • Scroll-Click: Mover | Clique: Ponto" }
                    }
                }

                if let Some((_p_x, p_y, p_z)) = inspected_point() {
                    if !is_3d {
                        div { class: "moscaro plot-point-panel", style: "position: absolute; bottom: 10px; left: 10px; font-size: 10px; font-family: monospace; color: #00ffaa; background: rgba(5, 10, 20, 0.95); padding: 6px 10px; border-radius: 8px; border: 1px solid rgba(0, 255, 170, 0.5); backdrop-filter: blur(8px); box-shadow: 0 4px 16px rgba(0,0,0,0.6), 0 0 12px rgba(0, 255, 170, 0.2); display: flex; align-items: center; gap: 6px;",
                            onmousedown: move |e| e.stop_propagation(),
                            onclick: move |e| e.stop_propagation(),
                            span { style: "font-weight: bold; color: #00ffaa;", "Ponto P:" }
                            span { "x:" }
                            input {
                                class: "moscaro plot-point-input",
                                style: "width: 55px; background: rgba(0, 255, 170, 0.1); border: 1px solid rgba(0, 255, 170, 0.4); border-radius: 6px; color: #00ffaa; font-family: monospace; font-size: 10px; padding: 2px 6px; outline: none; text-align: center; transition: border-color 0.15s ease, box-shadow 0.15s ease;",
                                value: "{point_x_str}",
                                onmousedown: move |e| e.stop_propagation(),
                                onclick: move |e| e.stop_propagation(),
                                oninput: move |e: FormEvent| {
                                    point_x_str.set(e.value());
                                },
                                onkeydown: move |e: KeyboardEvent| {
                                    if e.key() == Key::Enter {
                                        e.stop_propagation();
                                        if let Ok(new_x) = point_x_str().trim().parse::<f64>() {
                                            if let Some((_, _, first_clean)) = active_preprocessed.first() {
                                                let is_fn_of_y = first_clean.contains('y');
                                                if is_fn_of_y {
                                                    let calc_x = eval_expr(first_clean, 0.0, new_x);
                                                    if !calc_x.is_nan() {
                                                        inspected_point.set(Some((calc_x, new_x, calc_x)));
                                                        point_x_str.set(format!("{:.3}", new_x));
                                                    }
                                                } else {
                                                    let calc_y = eval_expr(first_clean, new_x, 0.0);
                                                    if !calc_y.is_nan() {
                                                        inspected_point.set(Some((new_x, 0.0, calc_y)));
                                                        point_x_str.set(format!("{:.3}", new_x));
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            span { "y: {p_z:.3}" }
                        }
                    } else {
                        div { class: "moscaro plot-point-panel", style: "position: absolute; bottom: 10px; left: 10px; font-size: 10px; font-family: monospace; color: #00ffaa; background: rgba(5, 10, 20, 0.95); padding: 6px 10px; border-radius: 8px; border: 1px solid rgba(0, 255, 170, 0.5); backdrop-filter: blur(8px); box-shadow: 0 4px 16px rgba(0,0,0,0.6), 0 0 12px rgba(0, 255, 170, 0.2); display: flex; align-items: center; gap: 6px;",
                            onmousedown: move |e| e.stop_propagation(),
                            onclick: move |e| e.stop_propagation(),
                            span { style: "font-weight: bold; color: #00ffaa;", "Ponto 3D P:" }
                            span { "x:" }
                            input {
                                class: "moscaro plot-point-input",
                                style: "width: 45px; background: rgba(0, 255, 170, 0.1); border: 1px solid rgba(0, 255, 170, 0.4); border-radius: 6px; color: #00ffaa; font-family: monospace; font-size: 10px; padding: 2px 6px; outline: none; text-align: center; transition: border-color 0.15s ease, box-shadow 0.15s ease;",
                                value: "{point_x_str}",
                                onmousedown: move |e| e.stop_propagation(),
                                onclick: move |e| e.stop_propagation(),
                                oninput: move |e: FormEvent| {
                                    point_x_str.set(e.value());
                                },
                                onkeydown: move |e: KeyboardEvent| {
                                    if e.key() == Key::Enter {
                                        e.stop_propagation();
                                        if let Ok(new_x) = point_x_str().trim().parse::<f64>() {
                                            if let Some((_, _, first_clean)) = active_preprocessed.first() {
                                                let val_z = eval_expr(first_clean, new_x, p_y);
                                                if !val_z.is_nan() {
                                                    inspected_point.set(Some((new_x, p_y, val_z)));
                                                    point_x_str.set(format!("{:.2}", new_x));
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            span { "y: {p_y:.2}, z: {p_z:.2}" }
                        }
                    }
                }

                svg {
                    width: "100%",
                    height: "100%",
                    view_box: "0 0 {width} {height}",
                    style: "width: 100%; height: 100%; display: block;",

                    if let Some(d2) = render_2d {
                        // 2D Renderer
                        g {
                            for (idx, (val_x, is_zero, tick_str)) in d2.grid_x.iter().enumerate() {
                                line {
                                    key: "gx_{idx}",
                                    x1: "{d2.cx + val_x * d2.scale_x}", y1: "0",
                                    x2: "{d2.cx + val_x * d2.scale_x}", y2: "{height}",
                                    stroke: if *is_zero { "rgba(168, 85, 247, 0.7)" } else { "rgba(255, 255, 255, 0.06)" },
                                    stroke_width: if *is_zero { "1.5" } else { "1" }
                                }
                                if !is_zero {
                                    text {
                                        key: "gt_{idx}",
                                        x: "{d2.cx + val_x * d2.scale_x + 3.0}",
                                        y: "{d2.cy.clamp(15.0, height - 15.0) + 12.0}",
                                        fill: "rgba(255, 255, 255, 0.4)",
                                        font_size: "9",
                                        font_family: "monospace",
                                        "{tick_str}"
                                    }
                                }
                            }

                            for (idx, (val_y, is_zero, tick_str)) in d2.grid_y.iter().enumerate() {
                                line {
                                    key: "gy_{idx}",
                                    x1: "0", y1: "{d2.cy - val_y * d2.scale_y}",
                                    x2: "{width}", y2: "{d2.cy - val_y * d2.scale_y}",
                                    stroke: if *is_zero { "rgba(168, 85, 247, 0.7)" } else { "rgba(255, 255, 255, 0.06)" },
                                    stroke_width: if *is_zero { "1.5" } else { "1" }
                                }
                                if !is_zero {
                                    text {
                                        key: "gyt_{idx}",
                                        x: "{d2.cx.clamp(5.0, width - 35.0) + 4.0}",
                                        y: "{d2.cy - val_y * d2.scale_y - 3.0}",
                                        fill: "rgba(255, 255, 255, 0.4)",
                                        font_size: "9",
                                        font_family: "monospace",
                                        "{tick_str}"
                                    }
                                }
                            }

                            text { x: "{width - 15.0}", y: "{d2.cy.clamp(15.0, height - 15.0) - 5.0}", fill: "#a855f7", font_size: "11", font_weight: "bold", font_family: "monospace", "X" }
                            text { x: "{d2.cx.clamp(5.0, width - 20.0) + 6.0}", y: "15", fill: "#a855f7", font_size: "11", font_weight: "bold", font_family: "monospace", "Y" }

                            for (idx, (path_data, color)) in d2.function_paths.iter().enumerate() {
                                path {
                                    key: "p_{idx}",
                                    d: "{path_data}",
                                    fill: "none",
                                    stroke: "{color}",
                                    stroke_width: "2.5",
                                    stroke_linecap: "round"
                                }
                            }

                            if let Some((px, _py, pz)) = inspected_point() {
                                circle {
                                    cx: "{d2.cx + px * d2.scale_x}",
                                    cy: "{d2.cy - pz * d2.scale_y}",
                                    r: "5",
                                    fill: "#00ffaa", stroke: "#060a12", stroke_width: "2"
                                }
                            }
                        }
                    }

                    if let Some(d3) = render_3d {
                        g {
                            path { d: "{d3.axis_x.0}", stroke: "#ef4444", stroke_width: "2", stroke_dasharray: "2 2" }
                            path { d: "{d3.axis_y.0}", stroke: "#22c55e", stroke_width: "2", stroke_dasharray: "2 2" }
                            path { d: "{d3.axis_z.0}", stroke: "#3b82f6", stroke_width: "2", stroke_dasharray: "2 2" }

                            text { x: "{d3.axis_x.1.0}", y: "{d3.axis_x.1.1}", fill: "#ef4444", font_size: "11", font_weight: "bold", font_family: "monospace", "X" }
                            text { x: "{d3.axis_y.1.0}", y: "{d3.axis_y.1.1}", fill: "#22c55e", font_size: "11", font_weight: "bold", font_family: "monospace", "Y" }
                            text { x: "{d3.axis_z.1.0}", y: "{d3.axis_z.1.1}", fill: "#3b82f6", font_size: "11", font_weight: "bold", font_family: "monospace", "Z" }

                            for (idx, (line_path, col)) in d3.mesh_lines.iter().enumerate() {
                                path {
                                    key: "m3d_{idx}",
                                    d: "{line_path}",
                                    fill: "none",
                                    stroke: "{col}",
                                    stroke_width: "1.3"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

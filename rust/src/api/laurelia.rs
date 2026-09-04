/// Binding FRB del LLM Laurelia (inferencia en Rust con Candle).
///
/// Espejo de `laurelia_chat_godot.rs` de Gtool, pero sin Godot: el modelo es
/// un singleton global (Mutex) y la descarga la hace Dart por HTTP.

use candle_core::{DType, Device, Tensor};
use std::path::Path;
use std::sync::Mutex;

use crate::laurelia::weights::Weights;
use crate::laurelia::{Config, LaureliaTokenizer, LLM};

pub struct LaureliaState {
    model: Option<LLM>,
    tokenizer: Option<LaureliaTokenizer>,
    device: Device,
    max_new_tokens: usize,
    temperature: f32,
    top_k: usize,
    top_p: f32,
    repetition_penalty: f32,
    eos_token_id: Option<u32>,
}

static STATE: Mutex<LaureliaState> = Mutex::new(LaureliaState {
    model: None,
    tokenizer: None,
    device: Device::Cpu,
    max_new_tokens: 50,
    temperature: 0.7,
    top_k: 40,
    top_p: 0.9,
    repetition_penalty: 1.2,
    eos_token_id: None,
});

/// Carga tokenizer + checkpoint desde rutas locales (la descarga por HTTP la
/// hace Dart). Retorna true si tuvo éxito.
#[flutter_rust_bridge::frb]
pub fn laurelia_load_model(ckpt_path: String, tokenizer_path: String) -> bool {
    if !Path::new(&ckpt_path).exists() {
        return false;
    }
    if !Path::new(&tokenizer_path).exists() {
        return false;
    }

    let dtype = DType::F32;
    let device = Device::Cpu;

    let mut st = STATE.lock().unwrap();

    let model = if ckpt_path.ends_with(".pt") || ckpt_path.ends_with(".pth") {
        match Weights::load_pth(&ckpt_path, &Config::default(), dtype, &device) {
            Ok(m) => m,
            Err(_) => return false,
        }
    } else {
        match Weights::load(&ckpt_path, &Config::default(), dtype, &device) {
            Ok(m) => m,
            Err(_) => return false,
        }
    };

    let tokenizer = match LaureliaTokenizer::from_file(&tokenizer_path) {
        Ok(t) => t,
        Err(_) => return false,
    };

    st.eos_token_id = tokenizer.eos_token_id();
    st.model = Some(model);
    st.tokenizer = Some(tokenizer);
    true
}

/// Carga solo el tokenizer (para contar tokens antes de descargar el modelo).
#[flutter_rust_bridge::frb]
pub fn laurelia_load_tokenizer(tokenizer_path: String) -> bool {
    let tokenizer = match LaureliaTokenizer::from_file(&tokenizer_path) {
        Ok(t) => t,
        Err(_) => return false,
    };
    let mut st = STATE.lock().unwrap();
    st.tokenizer = Some(tokenizer);
    true
}

/// Cantidad de tokens totales que representa un texto (prefill + generación).
/// Retorna -1 si no hay tokenizer cargado o falla el encode.
#[flutter_rust_bridge::frb]
pub fn laurelia_count_tokens(text: String) -> i64 {
    let st = STATE.lock().unwrap();
    let tokenizer = match st.tokenizer.as_ref() {
        Some(t) => t,
        None => return -1,
    };
    match tokenizer.encode(&text) {
        Ok(ids) => ids.len() as i64,
        Err(_) => -1,
    }
}

/// Vocabulario del tokenizer. -1 si no está cargado.
#[flutter_rust_bridge::frb]
pub fn laurelia_vocab_size() -> i64 {
    let st = STATE.lock().unwrap();
    match st.tokenizer.as_ref() {
        Some(t) => t.vocab_size() as i64,
        None => -1,
    }
}

/// Parámetros del modelo (dim, layers, heads, vocab). String JSON simple.
#[flutter_rust_bridge::frb]
pub fn laurelia_model_info() -> String {
    let st = STATE.lock().unwrap();
    let model = match st.model.as_ref() {
        Some(m) => m,
        None => return "{}".to_string(),
    };
    format!(
        "{{\"dim\":{},\"heads\":{},\"layers\":{},\"kv_groups\":{},\"ffn_dim\":{},\"block_size\":{},\"emb_num\":{}}}",
        model.config.dim,
        model.config.heads,
        model.config.layers,
        model.config.kv_groups,
        model.config.ffn_dim,
        model.config.block_size,
        model.config.emb_num,
    )
}

/// Genera texto a partir de un prompt. Retorna string vacío si no hay modelo.
#[flutter_rust_bridge::frb]
pub fn laurelia_generate(
    prompt: String,
    max_new_tokens: i64,
    temperature: f64,
    top_k: i64,
    top_p: f64,
    repetition_penalty: f64,
) -> String {
    let st = STATE.lock().unwrap();
    let model = match st.model.as_ref() {
        Some(m) => m,
        None => return String::new(),
    };
    let tokenizer = match st.tokenizer.as_ref() {
        Some(t) => t,
        None => return String::new(),
    };

    let ids = match tokenizer.encode(&prompt) {
        Ok(ids) => ids,
        Err(_) => return String::new(),
    };
    if ids.is_empty() {
        return String::new();
    }

    let input = match Tensor::from_vec(ids.clone(), (1, ids.len()), model.device()) {
        Ok(t) => t,
        Err(_) => return String::new(),
    };

    let max_new = max_new_tokens.max(1) as usize;
    let temp = temperature as f32;
    let top_k = top_k.max(1) as usize;
    let top_p = top_p as f32;
    let rep = repetition_penalty as f32;

    let out = match model.generate(&input, max_new, temp, top_k, top_p, rep, st.eos_token_id) {
        Ok(o) => o,
        Err(_) => return String::new(),
    };

    let ids_out = match out.reshape((out.elem_count(),)) {
        Ok(t) => match t.to_vec1() {
            Ok(v) => v,
            Err(_) => return String::new(),
        },
        Err(_) => return String::new(),
    };

    match tokenizer.decode(&ids_out) {
        Ok(text) => text,
        Err(_) => String::new(),
    }
}

#[flutter_rust_bridge::frb]
pub fn laurelia_is_loaded() -> bool {
    STATE.lock().unwrap().model.is_some()
}

/// Libera el modelo y el tokenizer de memoria.
#[flutter_rust_bridge::frb]
pub fn laurelia_unload_model() {
    let mut st = STATE.lock().unwrap();
    st.model = None;
    st.tokenizer = None;
}
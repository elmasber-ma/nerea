-- Pagina 3: Chat LLM Laurelia (descarga por HTTP + inferencia en Rust).
-- Flujo igual al ejemplo de Godot:
--   1. laurelia_download()   -> baja checkpoint.pt + tokenizer.json de HF
--   2. laurelia_load()       -> carga el modelo en Rust (Candle)
--   3. laurelia_generate()   -> genera texto; el resultado va a "laurelia_out"
-- Globals disponibles:
--   laurelia_download() / laurelia_load() / laurelia_unload()
--   laurelia_generate(prompt, max_tokens)
--   laurelia_count_tokens(texto) / laurelia_vocab() / laurelia_is_loaded()
--   laurelia_status()        -> estado actual (texto)

page.title = "Chat Laurelia (pagina 3)"

gui_rect({
  text = "LLM Laurelia en Rust (Candle)",
  bg_color = "#6a1b9a", radius = 12, padding = 14, align = "center",
  font = { size = 18, bold = true, color = "white" },
})

gui_spacer({ space = 10 })

gui_text({ id = "laurelia_model", text = "Modelo seleccionado: base", font = { size = 14, bold = true } })

gui_button({ text = "Seleccionar modelo base", on_click = "set_base" })
gui_button({ text = "Seleccionar modelo fine", on_click = "set_fine" })

gui_spacer({ space = 8 })

gui_button({ text = "Descargar modelo base (652 MB)", on_click = "descargar_base" })
gui_button({ text = "Descargar modelo fine (652 MB)", on_click = "descargar_fine" })

gui_spacer({ space = 8 })

gui_button({ text = "Descargar y cargar en Rust (desde disco)", on_click = "descargar_y_cargar" })

gui_button({ text = "Eliminar modelo base", on_click = "del_base" })
gui_button({ text = "Eliminar modelo fine", on_click = "del_fine" })

gui_spacer({ space = 8 })

gui_button({ text = "Cargar en Rust", on_click = "cargar" })
gui_button({ text = "Liberar modelo", on_click = "liberar" })

gui_button({ text = "Ver estado (donde, cuantos MB, cargado?)", on_click = "info" })

gui_text({
  id = "laurelia_info",
  text = "Estado: toca 'Ver estado'",
  font = { size = 12 },
  multiline = true,
})

gui_divider({ height = 24 })

gui_input({ id = "prompt", label = "Prompt", value = "Hola, como estas?" })

gui_button({ text = "Generar", on_click = "generar" })

gui_text({ id = "laurelia_out", text = "Resultado aparecera aqui", font = { size = 14 }, multiline = true })

gui_divider({ height = 24 })

gui_text({ id = "laurelia_status", text = "Estado: listo", font = { size = 13 }, multiline = true })

gui_button({ text = "Contar tokens del prompt", on_click = "contar" })
gui_text({ id = "token_count", text = "Tokens: -", font = { size = 13 } })

gui_divider({ height = 24 })

gui_button({ text = "< Volver a la pagina 1 (Rust)", on_click = "volver" })

handler("set_base", function()
  laurelia_set_model("base")
  engine_set("laurelia_model", "Modelo seleccionado: base")
end)

handler("set_fine", function()
  laurelia_set_model("fine")
  engine_set("laurelia_model", "Modelo seleccionado: fine")
end)

handler("descargar_base", function()
  laurelia_set_model("base")
  engine_set("laurelia_model", "Modelo seleccionado: base")
  laurelia_download()
end)

handler("descargar_fine", function()
  laurelia_set_model("fine")
  engine_set("laurelia_model", "Modelo seleccionado: fine")
  laurelia_download()
end)

handler("del_base", function()
  laurelia_delete_model("base")
end)

handler("del_fine", function()
  laurelia_delete_model("fine")
end)

handler("descargar_y_cargar", function()
  local modelo = engine_get("laurelia_model")
  if string.find(modelo, "fine") then
    laurelia_set_model("fine")
  else
    laurelia_set_model("base")
  end
  laurelia_download_and_load()
end)

handler("cargar", function()
  laurelia_load()
end)

handler("liberar", function()
  laurelia_unload()
end)

handler("info", function()
  laurelia_info()
end)

handler("generar", function()
  local prompt = engine_get("prompt")
  if prompt == "" then
    engine_set("laurelia_out", "Escribe un prompt primero")
    return
  end
  laurelia_generate(prompt, 50)
end)

handler("contar", function()
  local prompt = engine_get("prompt")
  local n = laurelia_count_tokens(prompt)
  engine_set("token_count", "Tokens: " .. tostring(n))
end)

handler("volver", function()
  navigate("demo")
end)

laurelia_info()

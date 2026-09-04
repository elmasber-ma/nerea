-- Pagina 2: Reproductor de audio/video (media_kit / libmpv + FFmpeg).
-- Abre archivos de Android con el selector nativo y los reproduce.
-- Globals de reproductor disponibles:
--   player_pick()     -> abrir selector de archivos y reproducir
--   player_open(ruta) -> reproducir una ruta directa
--   player_play() / player_pause() / player_toggle() / player_stop()
--   player_status()   -> estado actual (texto)

page.title = "Reproductor (pagina 2)"

gui_rect({
  text = "Reproductor media_kit (libmpv)",
  bg_color = "#1976d2", radius = 12, padding = 14, align = "center",
  font = { size = 18, bold = true, color = "white" },
})

gui_spacer({ space = 10 })

gui_video({ height = 220, align = "center" })

gui_spacer({ space = 10 })

gui_button({ text = "Abrir archivo de Android", on_click = "abrir" })
gui_button({ text = "Reproducir / Pausar", on_click = "toggle" })
gui_button({ text = "Detener", on_click = "detener" })

gui_divider({ height = 24 })

gui_text({ id = "player_status", text = "Estado: sin archivo", font = { size = 14 } })

gui_divider({ height = 24 })

gui_button({ text = "< Volver a la pagina 1 (Rust)", on_click = "volver" })

handler("abrir", function()
  player_pick()
end)

handler("toggle", function()
  player_toggle()
end)

handler("detener", function()
  player_stop()
end)

handler("volver", function()
  navigate("demo")
end)
-- Pagina demo: la GUI se construye llamando funciones, sin "type = string".
-- Funciones: gui_heading | gui_text | gui_input | gui_button | gui_rect |
--            gui_image | gui_divider | gui_spacer | gui_video
-- Handlers: handler(nombre, funcion) + globales del motor:
--   engine_get(id)             -> leer valor de un widget
--   engine_set(id, valor)      -> actualizar un widget (re-render)
--   navigate("pagina")         -> cambiar de pagina (demo | player)
--   rust_greet / rust_sum / rust_fibonacci -> llamar a Rust
--   player_pick()              -> abrir selector de archivos y reproducir

page.title = "Demo Lua + Rust"

gui_rect({
  text = "Motor: Flutter + Rust, GUI en Lua",
  bg_color = "#1976d2", radius = 12, padding = 14, align = "center",
  font = { size = 18, bold = true, color = "white" },
})

gui_spacer({ space = 10 })

gui_image({
  src = "https://picsum.photos/seed/pr_app/640/300",
  fit = "cover", height = 190,
})

gui_spacer({ space = 10 })

gui_text({
  text = "Escribe tu nombre y presiona un boton. La llamada a Rust ocurre desde Lua.",
  font = { size = 14 }, color = "#555555", padding = 4,
})

gui_input({ id = "name", label = "Nombre", value = "Ana" })

gui_spacer({ space = 6 })

gui_text({
  text = "Acciones Rust:", align = "center",
  font = { size = 15, bold = true, color = "#1976d2" },
})

gui_button({ text = "Saludar (Rust)", on_click = "saludar" })
gui_button({ text = "Sumar 21 + 21 (Rust)", on_click = "sumar" })
gui_button({ text = "Fibonacci(40) (Rust)", on_click = "fib" })

gui_divider({ height = 26 })

gui_text({ id = "greeting", text = "Saludo pendiente...", font = { size = 16 } })
gui_text({ id = "result", text = "Resultado: -", font = { size = 16 } })

gui_divider({ height = 26 })

gui_text({
  text = "Paginas:", align = "center",
  font = { size = 15, bold = true, color = "#1976d2" },
})

gui_button({ text = "Ir al reproductor (pagina 2)", on_click = "ir_player" })
gui_button({ text = "Chat Laurelia (pagina 3)", on_click = "ir_laurelia" })

handler("saludar", function()
  local nombre = engine_get("name")
  local saludo = rust_greet(nombre)
  engine_set("greeting", "-> " .. saludo)
end)

handler("sumar", function()
  local r = rust_sum(21, 21)
  engine_set("result", "21 + 21 = " .. tostring(r))
end)

handler("fib", function()
  local r = rust_fibonacci(40)
  engine_set("result", "Fibonacci(40) = " .. tostring(r))
end)

handler("ir_player", function()
  navigate("player")
end)

handler("ir_laurelia", function()
  navigate("laurelia")
end)
# Reporte: error al cargar página Lua (`attempt to index a nil value`)

## Error reportado

Al cargar una página Lua (URL raw de GitHub o botón Demo) desde el APK:

```
No se pudo cargar: Exception: [unknown] attempt to index a nil value
```

## Diagnóstico

El mensaje tiene dos partes clave:

1. **`attempt to index a nil value`** → Lua (o la API Dart del motor Lua) intentó leer un campo sobre `nil`, es decir, "no hay tabla ahí".
2. **`[unknown]` sin `archivo:línea`** → el error NO ocurrió dentro del script Lua (ahí aparecería `[código:línea]`), sino del lado Dart, en el parseo posterior a la ejecución.

En lua_dardo_plus este mensaje se lanza desde `_getTable`/`_setTable` (lib/src/state/lua_state_impl.dart). Al no haber un closure Lua activo, `formatError` devuelve `[unknown]`.

## Causa raíz (bug en nuestro código)

En `lib/engine/page_engine.dart`, `_parsePage()` leía los nodos de `page.body` así:

```dart
for (var i = 1; i <= count; i++) {
  _lua.getField(-1, '$i');   // clave STRING: "1", "2", ...
```

Pero Lua guarda los elementos de un array (`{ {...}, {...}, ... }`) con claves de tipo **entero** (`1`, `2`, ...), no string.

En `LuaTable.get(key)` de lua_dardo_plus:

- `get(1)` (int) → lee el array (`arr[idx-1]`).
- `get("1")` (string) → busca en el mapa hash → **no existe** → devuelve `nil`.

Consecuencia: `getField(-1, '1')` devolvía `nil`, y el siguiente `getField(-1, 'type')` sobre ese `nil` reventaba con `attempt to index a nil value`.

Esto pasaba del lado Dart (por eso `[unknown]`) y afectaba a **todas** las páginas (Demo y URL), no era un problema del contenido del script ni de la URL.

## Corrección

En `lib/engine/page_engine.dart:155`:

```dart
// antes
_lua.getField(-1, '$i');   // clave string → nil → error

// después
_lua.getI(-1, i);          // clave entera → lee body[i] correctamente
```

`getI(idx, i)` pasa la clave como entero, que es como Lua almacena los elementos del array.

- Commit: `10fd068`
- Estado: pusheado a `main`; CI genera el APK nuevo para verificar.

## Notas del análisis (contexto)

- Se verificó el código fuente de `lua_dardo_plus` v0.3.0 (pub.dev) para confirmar el comportamiento de `LuaTable.get/put`, `_getTable`, `_setTable`, `getI` y `loadString`/`call`.
- Se descartó que el problema fuera la URL, el contenido del `demo.lua` (HTML/BOM/unicode) o la API de Rust: todos los caminos de carga pasan por el mismo `_parsePage()`.
- `invokeHandler` usa claves string correctamente (la tabla `handlers` es un hash con claves nombre), así que no requirió cambios.

# Last Knight 3D · Godot 4 (Forward+, PC)

Responde en español.

## Forma de trabajar
- Ve al grano: sin introducciones ni resúmenes de lo que vas a hacer.
- Al explicar cambios de código, enseña solo las funciones o líneas tocadas, con el archivo.
- Si una tarea es grande o ambigua, haz una sola pregunta antes de empezar.
- Al terminar un cambio importante, añade 2–3 líneas a `docs/ESTADO.md`.

## Estructura
- `src/core`: la simulación de Last Knight 2D, tal cual (posiciones en px, 32 px = 1 casilla = 2 m). No dibuja; lo visual sale por `SimFx`.
- `src/vista3d`: la vista 3D. `MazmorraGridMap` (piso en GridMap), `KitMazmorra` (MeshLibrary), `Actores3D` (héroe, enemigos, botín…), `Fx3D` (lo que pide `SimFx`).
- `src/ui`: HUD, inventario y personaje de Last Knight 2D (2D encima del 3D).
- `src/view`: solo `atlas.gd` y `view_fx.gd`, porque la interfaz usa sus iconos y colores. No añadir más vista 2D.
- Conversión: `MazmorraGridMap.a3d(x, y, z)` px → m y `a_px(v)` m → px.

## Ejecutar y probar
- Godot 4.7.2, renderizador Forward+.
- Importar: `godot --headless --path . --editor --quit`.
- Pruebas del núcleo: `godot --headless --path . -s tests/test_botin.gd` y `tests/test_clases.gd` (deben decir «todo bien»).
- Captura: `xvfb-run -a godot --path . -- --bot --shot=/tmp/x.png,200` (sin GPU: `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`).
- Opciones: `--clase=knight|dk|archer|mage|dl --piso=N --semilla=… --inclinacion=45 --giro=0 --bot`.

# Last Knight 3D · Godot 4 (Forward+, PC)

Responde en español.

## Forma de trabajar
- Antes de hacer nada, plantea lo que haga falta decidir como preguntas numeradas (1, 2, 3…) que se contesten con sí o no, por orden, y termina con «¿Qué hacemos?». Diego contesta por número y no se empieza hasta tener las respuestas.
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

## Arte
- Kit de la mazmorra: `python3 tools/blender/kit_mazmorra.py assets/kit/kit_mazmorra.glb` (módulo bpy: `pip install bpy`).
- Monstruos: `python3 tools/blender/monstruos_glb.py <SPRITE_FACTORY> assets/monstruos [id…]`.
- Armas en la mano: Diego las coloca a ojo con `colocar_arma.bat` (en la raíz de SPRITE_FACTORY, con `tools/agarre/{colocar_arma,agarre,monstruos_glb}.py`): panel «Agarre» de Blender, guarda `agarres_3d` en la ficha (matriz respecto al hueso de la mano, en metros). El conversor los usa y deja `agarre_<mano>_<tipo>` en el .glb; los del esqueleto valen para todos los de Mixamo que no tengan los suyos.
- Sets de armadura: `python3 tools/blender/armadura_set.py tools/armaduras/caballero_oscuro.glb assets/armaduras/caballero_oscuro` (reglas de corte en `SETS`; colocación en `Armadura3D.AJUSTE`). Cada recurso nuevo se apunta en `docs/LICENCIAS.md`.
- Armadura: `xvfb-run -a godot --path . -s res://tools/vitrina_armadura.gd -- --shot=/tmp/v.png [--cerca=0..3] [--anim=walk] [--fantasma]` (el héroe con las 4 calidades y las piezas del suelo; para ajustar `Armadura3D.AJUSTE`).
- Sala de prueba: `scenes/sala_prueba.tscn` (`--heroe=… --anim=… --zoom=… --centro=x,z`).
- Paquetes de fuera (Poly Haven, Sketchfab): `python3 tools/blender/props_glb.py <carpeta con lo que pasó Diego> assets/props [paquete…]` → `Props3D.crear(paquete, pieza)`. Autores y licencias en `docs/CREDITOS_Y_LICENCIAS.md` y `assets/creditos.json` (los dos al día).
- Enemigos que aprenden (`Aprendizaje`, `docs/APRENDIZAJE.md`): puesto fijo por piso, 6 tácticas, memoria por tipo y por puesto en `user://aprendizaje.json`, títulos Experto/Asesino. Sala del aprendizaje: `--sala=10` del Piso de prueba; F3 o `--f3`, panel de lo aprendido.
- Pantalla de inicio (`MenuInicio`): el juego arranca en ella. Nueva partida (con elección de clase), Piso de prueba, Opciones, Créditos y Salir; de fondo, un piso 1 fijo sin enemigos con la cámara girando. Esc en la partida abre la pausa (Continuar, Opciones, Volver al menú). Opciones guardadas en `user://opciones.cfg` (`Opciones`).
- Inca (la ciudad, `Ciudad`): la partida empieza ahí. Kit: `python3 tools/blender/kit_ciudad.py assets/kit/kit_ciudad.glb`. Zona segura; la entrada del norte deja elegir oleada (`Hero.piso_max`), tras el jefe se elige bajar o subir y al morir se vuelve sin mochila ni el oro de la bajada. `--ciudad[=portal|puerta|escalera]`.
- Piso de prueba: se entra desde el menú (`PisoPrueba`, sin enemigos). Adornos por propósito de sala: `Repartidor.PROPOSITOS`.
- Sonidos: `python3 tools/sonidos.py assets/sonidos` (sintetizados; `Fx3D.sonido` elige entre las tomas `_1`, `_2`…). Efectos de golpe: `xvfb-run -a godot --path . -s res://tools/vitrina_sangre.gd -- --shot=/tmp/s.png`; rompibles, trampas y mímico: `tools/vitrina_mazmorra.gd`.

## Ejecutar y probar
- Espacio de trabajo nuevo: `bash tools/preparar_entorno.sh` (Godot 4.7.2, Vulkan por software y bpy). Diego ha autorizado instalar Godot en cualquier chat de este proyecto.
- Godot 4.7.2, renderizador Forward+.
- Importar: `godot --headless --path . --editor --quit`.
- Pruebas del núcleo: `godot --headless --path . -s tests/test_botin.gd` `tests/test_clases.gd`, `tests/test_modelos.gd` `tests/test_demonios.gd`, `tests/test_zoom.gd`, `tests/test_combate.gd` `tests/test_dos_espadas.gd`, `tests/test_armadura.gd`, `tests/test_piso_prueba.gd`, `tests/test_menu.gd`, `tests/test_grupos.gd`, `tests/test_botin_explota.gd`, `tests/test_mazmorra.gd`, `tests/test_devorador.gd`, `tests/test_rigidez.gd`, `tests/test_ciudad.gd` y `tests/test_aprendizaje.gd` (deben decir «todo bien»).
- Captura: `xvfb-run -a godot --path . -- --bot --shot=/tmp/x.png,200` (sin GPU: `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`).
- Opciones (las que empiezan partida se saltan el menú): `--partida` `--ciudad[=portal|puerta|escalera]` `--prueba=N --sala=N` `--menu[=clase|opciones|pausa]` (capturas del menú) `--clase=knight|dk|archer|mage|dl --piso=N --semilla=… --heroe=… --junto=<monstruo>|jefe|elite|reto|trampa --equipo=0..3 --f3 --morir --zoom=… --giro=… --inclinacion=… --perspectiva --bot`.
- El juego arranca en pantalla completa (o como diga Opciones); F11 cambia a ventana y se guarda; F1 créditos; Esc pausa. Rueda o +/− para el zoom (7–20 m).
- Todo lo estático que guarde recursos (texturas, mallas, traducciones) se suelta en `_exit_tree` de la escena principal; si no, Godot se cuelga al cerrar.
- Repositorio: github.com/digamelongames-creator/Lk-3d (rama `main`). Cada entrega se sube ahí y además se pasa el zip.

# Last Knight 3D · Godot 4 (Forward+, PC)

Responde en español.

## Forma de trabajar
- **Al empezar, lee entero `docs/ESTADO.md`**: ahí está cómo trabajamos, qué falta, qué se ha decidido o rechazado y qué está hecho. Es la fuente de verdad del proyecto; si una ficha del Proyecto dice otra cosa, manda `ESTADO.md`.
- Antes de hacer nada, plantea lo que haga falta decidir como preguntas numeradas (1, 2, 3…) que se contesten con sí o no, por orden, y termina con «¿Qué hacemos?». Diego contesta por número y no se empieza hasta tener las respuestas.
- Ve al grano: sin introducciones ni resúmenes de lo que vas a hacer.
- Al explicar cambios de código, enseña solo las funciones o líneas tocadas, con el archivo.
- Si una tarea es grande o ambigua, haz una sola pregunta antes de empezar.
- **Al terminar, pon al día `docs/ESTADO.md`**: 2–3 líneas arriba de «Hecho» y, sobre todo, las listas de pendientes (quita lo terminado, añade lo nuevo, apunta decisiones y rechazos).
- Otros chats trabajan a la vez: `git fetch` y `git rebase origin/main` antes de empezar y antes de subir.
- **No hagas capturas de pantalla del juego salvo que Diego las pida**: lo prueba él en su PC (aquí no hay tarjeta gráfica y cada captura tarda minutos). Comprueba con las pruebas `tests/`.
- No dibujes imágenes provisionales por código si Diego va a pasar las suyas.

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
- Efectos de las magias (`Hechizos3D`): catálogo `assets/vfx/catalogo.json` (una ficha por efecto: hoja, forma proyectil|golpe|suelo|aura, tam, brillo, velocidad, alto, luz, sonido, al_acabar, pegado). Imágenes de ChatGPT de Diego (carpeta `C:\VFX_MAGIAS`, nombre = hoja): `python3 tools/vfx_hoja.py lote <carpeta>`. Panel de ajuste F4 en el piso de prueba (F6 prueba el efecto; «Guardar» escribe el catálogo). Sala «Efectos» (`--sala=11`, mago y muñecos). Lo que es código: el enganche de cada habilidad en `Hechizos3D._enganches()`.
- Legendarios (`Legendarios`, `src/core/legendarios.gd`): efecto único por pieza del caballero (`EFECTO`, `TEXTO`); la simulación llama a sus ganchos (tajo3, critico, muere, bloqueo, herido, bebe, paso) y la vista los dibuja en `Hechizos3D._legendarios()`. Las piezas mejoran +10 % por afijo y oleada (`Items.escalar`).
- Temas de la mazmorra (`TemaMazmorra`, `src/vista3d/tema_mazmorra.gd`): cada piso puede vestirse con sus texturas, luz, niebla y abismo (`L.tema3d`) sin tocar el mapa. `KitMazmorra.mesh_library(tema)` da las mismas piezas con los materiales del tema (suelo liso con la textura, muros con la roca y vetas que brillan, canales de lava); `Abismo3D.crear(G, padre, tema)` pone el mar de lava, cascadas, luces y brasas. Texturas: imágenes de Pixmith (color y mapa de alturas en gris) → `python3 tools/texturas.py <color> assets/texturas/<tema> <nombre> [--alturas=<png>] [--brillo|--todo-brilla]` (arregla los bordes, saca relieve, rugosidad y lo que brilla). Hoy solo el Inframundo: pisos 8–9 de las partidas (pasarelas sobre lava, `Plataformas.PISOS`) y el «Piso de prueba 7» (`--prueba=7`, botón en «Salas de prueba»): piso generado de pasarelas, sin enemigos. Piezas de Tripo del tema: `Inframundo3D` (paquete `inframundo` de `props_glb.py`). «Prueba puente» (`PruebaPuente`, `--prueba=9`): la imagen 8 montada a mano con el paquete `puente`, cámara fija (`CamaraIso.fijar`, ajustar `CAM_DESDE/CAM_HACIA/CAM_FOV`) y sin interfaz; para comparar con la imagen: `xvfb-run -a -s "-screen 0 1536x1024x24" godot --path . --resolution 1536x1024 --windowed -- --prueba=9 --shot=/tmp/p.png,30` (Diego autorizó capturas de esta prueba). Prueba: `tests/test_temas.gd`.
- Sonidos: `python3 tools/sonidos.py assets/sonidos` (sintetizados; `Fx3D.sonido` elige entre las tomas `_1`, `_2`…). Efectos de golpe: `xvfb-run -a godot --path . -s res://tools/vitrina_sangre.gd -- --shot=/tmp/s.png`; rompibles, trampas y mímico: `tools/vitrina_mazmorra.gd`.

## Ejecutar y probar
- Espacio de trabajo nuevo: `bash tools/preparar_entorno.sh` (Godot 4.7.2, Vulkan por software y bpy). Diego ha autorizado instalar Godot en cualquier chat de este proyecto.
- Godot 4.7.2, renderizador Forward+.
- Importar: `godot --headless --path . --editor --quit`.
- Pruebas del núcleo: `godot --headless --path . -s tests/test_botin.gd` `tests/test_clases.gd`, `tests/test_modelos.gd` `tests/test_demonios.gd`, `tests/test_zoom.gd`, `tests/test_combate.gd` `tests/test_dos_espadas.gd`, `tests/test_armadura.gd`, `tests/test_piso_prueba.gd`, `tests/test_menu.gd`, `tests/test_grupos.gd`, `tests/test_botin_explota.gd`, `tests/test_mazmorra.gd`, `tests/test_devorador.gd`, `tests/test_rigidez.gd`, `tests/test_ciudad.gd`, `tests/test_aprendizaje.gd`, `tests/test_efectos.gd`, `tests/test_cofres_secretas.gd`, `tests/test_legendarios.gd` y `tests/test_temas.gd` (deben decir «todo bien»).
- Captura: `xvfb-run -a godot --path . -- --bot --shot=/tmp/x.png,200` (sin GPU: `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`).
- Opciones (las que empiezan partida se saltan el menú): `--partida` `--ciudad[=portal|puerta|escalera]` `--prueba=N --sala=N` `--menu[=clase|opciones|pausa]` (capturas del menú) `--clase=knight|dk|archer|mage|dl --piso=N --semilla=… --heroe=… --junto=<monstruo>|jefe|elite|reto|trampa --equipo=0..3 --f3 --morir --zoom=… --giro=… --inclinacion=… --perspectiva --bot`.
- El juego arranca en pantalla completa (o como diga Opciones); F11 cambia a ventana y se guarda; F1 créditos; Esc pausa. Rueda o +/− para el zoom (7–20 m).
- Todo lo estático que guarde recursos (texturas, mallas, traducciones) se suelta en `_exit_tree` de la escena principal; si no, Godot se cuelga al cerrar.
- Repositorio: github.com/digamelongames-creator/Lk-3d (rama `main`). Cada entrega se sube ahí y además se pasa el zip.

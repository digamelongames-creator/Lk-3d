# Escenas a partir de una imagen de referencia

Procedimiento para montar en Last Knight 3D una sala que se parezca a una imagen: salas especiales, salas de jefe y escenas de vitrina. Nació del Inframundo (la Prueba puente costó 12 capturas y casi una hora). El objetivo: 3–5 capturas.

Piezas del sistema:
- `assets/escenas/<nombre>.json`: la escena en datos (rejilla, cámara, entorno y objetos). Formato en `src/vista3d/escena3d.gd`.
- `assets/props/catalogo.json`: la ficha de cada pieza (tipo, medidas, dónde puede ir, rango de visibilidad, triángulos). Medidas y triángulos: `godot --headless --path . -s tools/catalogo.gd`.
- `Escena3D` (`src/vista3d/escena3d.gd`): monta la escena en tres modos e informa del rendimiento.
- `tools/escena.py`: cámara calculada, colocar por la imagen, proyectar y comparar con nota.
- `tools/texturas.py --mosaico`: texturas del tema con la prueba 3×3.

## 0. Decidir antes de empezar (preguntas a Diego)

1. **Clase de sala**: normal (modular, no usa esto), **especial**, **de jefe** o **de vitrina** (solo para ver, sin interfaz).
2. **Cámara**: la **del juego** (ortográfica, giro 45°, inclinación 33°, 17 m de alto) para todo lo que va dentro de un piso; una **propia** solo para vitrinas y cinemáticas. Decidido por Diego (11 nov): lo que va dentro de un piso se diseña con la cámara del juego.
3. **Tema** (`TemaMazmorra`) y **número** de prueba (el «numero» del archivo; el menú «Salas de prueba» lo lista solo).

## Carpetas (en el PC de Diego)

```
C:\Carpeta Juego\Escenas\<nombre>\
    referencia.png          la imagen (Pixmith), con la cámara decidida
    puntos.json             puntos conocidos de la imagen (para la cámara)
    piezas_tripo\           dibujos de cada pieza para Tripo (los hace Claude con Pixmith)
    piezas_tripo_hechas\    lo que devuelve Tripo (.glb, lo deja Diego)
    capturas\               capturas de cada vuelta con su informe
```

## 1. Referencia

- Pedir la imagen a Pixmith **con la cámara decidida**. Para la cámara del juego, decirlo en el encargo con detalle («true isometric orthographic projection, no perspective, vertical edges parallel, rotated 45° so the floor grid runs diagonally, pitched 33° down») y el héroe pequeño en el centro (≈1/14 del alto: así sale el zoom de 17 m).
- **Sin `reference_images`** de capturas del juego: Pixmith copia su pobreza y la imagen pierde riqueza (Diego, 12 nov). Mejor un encargo largo y detallado (paleta, luz, materiales, qué hay en cada zona de la imagen) y 2 variantes; se elige la de ángulo más parecido al del juego.
- Anotar qué manda en la imagen (protagonista, plano medio, fondo) y la lista de piezas: cuáles ya están en el catálogo y cuáles faltan.

## 2. Cámara calculada (no a ojo)

- Escribir `puntos.json` con 6–8 puntos de la imagen cuya posición en el mundo se decide ahora (esquinas del suelo, base de la puerta, borde del puente…), repartidos por toda la imagen.
- `python3 tools/escena.py camara <nombre> puntos.json` (cámara propia; `--fov=45` para fijar el campo de visión). Con cámara del juego ajusta el centro y el zoom.
- Comprobar con `proyectar` que lo importante cae donde en la imagen. Error aceptable: < 40 px.

## 3. Bloques (modo geometría)

- Escribir la escena con `{"bloque": [ancho, alto, fondo]}` para lo que aún no existe y `{"pieza": …}` para lo del catálogo; la rejilla (`rejilla.suelo`, rectángulos de casillas de 2 m) dice por dónde se anda y `rejilla.abismo` dónde se cae (vacío: la escena pone la roca, las cascadas y las luces; el tema solo la niebla). Lo demás es roca: no se pisa (pretiles, repisas).
- Con la cámara del juego, la cámara sigue al héroe: la casilla `inicio` es el centro de la imagen (sale de `colocar` en el centro).
- Al mirar las capturas: con la vista ortográfica, la cara de un bloque alto (repisa, acantilado) tapa todo lo que queda debajo en pantalla; en geometría parece un suelo, en el modo final la niebla de altura lo funde.
- Colocar lo que se ve en la imagen con `python3 tools/escena.py colocar <nombre> <px> <py> <altura>`: devuelve dónde va en el mundo.
- Captura en modo geometría (abajo) y comparación. Validar: tamaños, siluetas, cámara, que el héroe se ve y que se distingue por dónde se anda. **No pedir piezas a Tripo hasta que esto esté bien.**

## 4. Piezas

- Por cada bloque que falta: dibujo con Pixmith (pieza sola, de frente o de tres cuartos, fondo gris liso, luz de estudio) en `piezas_tripo\`. Diego las pasa por Tripo a `piezas_tripo_hechas\`.
- Añadir la pieza al paquete en `tools/blender/props_glb.py` con `archivo`, la medida del bloque (`alto`/`ancho`/`fondo`), `tris` (3 000–20 000) y `brillo` si tiene lava; convertir; ficha en el catálogo y `tools/catalogo.gd`.
- Cambiar el bloque por la pieza en la escena. Captura en modo materiales.

## 5. Materiales (modo materiales)

- Texturas del tema: `python3 tools/texturas.py … --mosaico` y mirar el 3×3 (costura, patrón repetido, escala). Altura: la de Pixmith si cuadra (parecido ≥ 0,35); si no, sale del color.
- Captura en modo materiales: luz neutra fija, sin niebla ni partículas. Validar color de la piedra, escala de losas, brillo de grietas.

## 6. Luz y ambiente (modo final)

- `entorno` de la escena y objetos `sol`, `luz`, `fuego`, `lava`, `cascada`, `cadena`, `jaula`.
- Jerarquía: emisión (lava, grietas) → luces locales (pocas y bien puestas) → ambiente → contraste (zonas oscuras y punto focal).
- Captura final, comparación e informe.

## Capturas (aquí, sin tarjeta gráfica)

```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1536x1024x24" \
  godot --path . --resolution 1536x1024 --windowed -- --prueba=<numero> --modo=geometria|materiales|final [--zoom=<el de la escena>] [--sin-interfaz] --shot=/tmp/c.png,30
python3 tools/escena.py comparar referencia.png /tmp/c.png --salida=/tmp/comparacion.png --informe=/tmp/c_informe.json
```
- `--sin-interfaz` quita el HUD (para que no tape la imagen al comparar); `--zoom` el de la cámara calculada.
- En geometría la nota de parecido sale baja (25–30): lo que vale es que cuadren tamaños, siluetas y por dónde se anda.
- Cada captura deja `<captura>_informe.json` (rendimiento). `comparar` le añade la nota de parecido por zonas.
- **Cambiar una sola cosa por vuelta** (geometría, materiales o luz), nunca las tres a la vez.
- Mientras se ajusta, basta media resolución (`--resolution 768x512`, puntos de la cámara a la mitad); la buena, al final.
- Guardar cada captura con su informe en `capturas\` (vuelta, modo, qué cambió).

## Fallos ya conocidos (comprobar antes de capturar)

- Materiales con máscara de brillo: `emission_operator = MULTIPLY` (con ADD brilla toda la superficie).
- Luz direccional principal: `light_volumetric_fog_energy = 0` (si no, toda la niebla se tiñe del color de la luz).
- Luces bajo un suelo sin sombras: que su alcance no llegue al suelo de encima (si no, lo atraviesan y lo queman).
- Partículas: tamaño en la malla (`QuadMesh.size`) y textura redonda (`MazmorraGridMap._punto()`); si no, salen cuadrados enormes.
- Lava: `fog_disabled` la deja siempre brillante; lo lejano y hondo, mejor quitarlo que apagarlo.
- Fondo: medirlo con `colocar`/`proyectar`; lo puesto «a ojo» sale enorme y cerca.
- Nombres de clase nuevos: buscar antes si ya existen (`grep -r "class_name X"`): `Temas` chocó con el editor de mapas.
- Al salir de una escena: entorno y cámara vuelven solos (`Escena3D.quitar`, `camara.fija = false` en `main3d._entrar`).

## Rendimiento (por clase de sala; medir en el PC de Diego con F7)

| Clase | Luces | Con sombra | Triángulos en escena | Partículas |
|---|---|---|---|---|
| especial | ≤ 20 | ≤ 1 | ≤ 600 000 | ≤ 6 |
| de jefe | ≤ 30 | ≤ 2 | ≤ 900 000 | ≤ 10 |
| vitrina | sin límite fijo (no se juega) | | | |

- Aquí valen los recuentos (objetos, triángulos, luces, llamadas de dibujo, memoria). Los fotogramas por segundo y el tiempo por fotograma solo valen con tarjeta gráfica («con_tarjeta_grafica» en el informe): F7 en el PC de Diego guarda el informe en `user://informes/`.
- La nota visual y el rendimiento se valoran por separado.
- `MultiMeshInstance3D` solo para lo pequeño y repetido (piedras, velas, escombros); lo grande, piezas sueltas (Godot deja de dibujar cada una fuera de la pantalla).
- El detalle por distancia (LOD) lo genera Godot al importar; el **rango de visibilidad** es otra cosa: va en la ficha del catálogo («visible_hasta»).

## Entrega

`tests/test_escenas.gd` y las demás pruebas «todo bien», `ESTADO.md`, `LICENCIAS.md` (piezas de Tripo de Diego: Tripo Premium, uso comercial; imágenes de Pixmith: ChatGPT, uso comercial), subir a `main` y zip.

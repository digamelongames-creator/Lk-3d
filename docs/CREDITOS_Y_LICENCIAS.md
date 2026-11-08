# Créditos y licencias

Todo lo que el juego usa y no está hecho desde cero en este repositorio, con lo que hace falta para publicarlo en Steam. La pantalla de créditos sale de `assets/creditos.json`: si se añade algo aquí, se añade también allí.

Última revisión: 8 de noviembre de 2026.

## Resumen para Steam

| ¿Se puede vender? | Qué |
|---|---|
| Sí, sin dar créditos | Poly Haven (CC0) y el kit de la mazmorra hecho por script |
| Sí, dando créditos | Los 5 paquetes de Sketchfab (CC BY 4.0), las fuentes (OFL 1.1) y Godot (MIT) |
| **Por confirmar** | Personajes de Tripo, texturas `Pared_1`, `Suelo1`, `Suelo_2` y los gráficos 2D de Last Knight |
| No (descartados) | Fougères castle (CC BY-NC), Armor Set (CC BY-NC-SA) |

Antes de publicar hay que resolver lo que está **por confirmar**.

## Modelos 3D

### Paquetes de Sketchfab: CC BY 4.0

Se pueden usar en un juego de pago. Obligatorio: nombrar al autor, enlazar la licencia y decir que se han cambiado. Todos se han cambiado con `tools/blender/props_glb.py`: escala, origen, menos polígonos y texturas reducidas. En Low Poly y Gothic, además, texturas nuevas de Poly Haven.

| Paquete | Autor | Origen | En el juego |
|---|---|---|---|
| Modular Dungeon Kit | HenryBoadle | [Sketchfab](https://sketchfab.com/3d-models/modular-dungeon-kit-ecbeefd3212f447ba2f10f1986ad5769) | `assets/props/dungeon_kit.glb` |
| Weapon set | rudolfs | [Sketchfab](https://sketchfab.com/3d-models/weapon-set-cb2e607fc7734e6fbf84211b6a65912f) | `assets/props/armas.glb` |
| Ancient Ruins Pack | Toni García Vilche (zul_gv) | [Sketchfab](https://sketchfab.com/3d-models/ancient-ruins-pack-4dad3b80562842f88d6568c5e1c469c2) | `assets/props/ruinas.glb` |
| Free Modular Low Poly Dungeon Pack | RgsDev | [Sketchfab](https://sketchfab.com/3d-models/free-modular-low-poly-dungeon-pack-31f2e88017574702bb2c1c1e286dc747) | `assets/props/low_poly.glb` |
| Gothic Interior Kit (Mid-Poly) | Zver 3D | [Sketchfab](https://sketchfab.com/3d-models/gothic-interior-kit-mid-poly-cd988423f3ff4cec8193cb1abfa11b8f) | `assets/props/gotico.glb` |

Licencia: https://creativecommons.org/licenses/by/4.0/

### Poly Haven: CC0

Dominio público: se puede vender sin dar créditos (se citan igualmente). Todo está en `assets/props/polyhaven.glb`, salvo el ladrillo, que está en `assets/texturas/polyhaven/`.

| Recurso | Origen | Uso |
|---|---|---|
| Treasure Chest | https://polyhaven.com/a/treasure_chest | Cofre que se abre |
| Lion Head | https://polyhaven.com/a/lion_head | Adorno de pared |
| Wooden Crate 01 | https://polyhaven.com/a/wooden_crate_01 | Caja |
| Wooden Chair 01 | https://polyhaven.com/a/WoodenChair_01 | Silla (reducida al 55 %) |
| Rock Moss Set 02 | https://polyhaven.com/a/rock_moss_set_02 | Rocas con musgo |
| Rock Face 02 | https://polyhaven.com/a/rock_face_02 | Roca grande de cueva |
| Namaqualand Stones 01 | https://polyhaven.com/a/namaqualand_stones_01 | Piedras sueltas |
| Dandelion 01 | https://polyhaven.com/a/dandelion_01 | Plantas |
| Patterned Brick Wall | https://polyhaven.com/a/patterned_brick_wall | Ladrillo de Low Poly y Gothic |

Licencia: https://polyhaven.com/license

### Personajes: Tripo AI + Adobe Mixamo (**por confirmar**)

Afecta al esqueleto (el héroe), la Bufona, los demonios y Prueba2 (`assets/monstruos/*.glb`, que salen de `C:\SPRITE_FACTORY`).

- **Tripo:** según su ayuda oficial, con el plan gratuito Tripo se queda todos los derechos de los modelos generados, y el uso comercial solo viene con un plan de pago. **Hay que confirmar con qué plan se generó cada modelo.** Si fue con el gratuito, antes de vender hay que regenerarlos con un plan de pago o cambiarlos. Guía: https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially
- **Mixamo:** el rig y las animaciones se pueden usar gratis en juegos comerciales y no hace falta dar créditos. Lo único prohibido es distribuir los archivos de personajes o animaciones sueltos. Metidos en el juego no hay problema. https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html

### Hecho para el juego

- Kit de la mazmorra (muros, suelos, arcos, antorchas, braseros…): `tools/blender/kit_mazmorra.py` → `assets/kit/kit_mazmorra.glb`. Propio.

## Fuentes: SIL Open Font License 1.1

Se pueden vender dentro del juego. Hay que incluir el aviso de copyright y la licencia, que están en `assets/fonts/`.

- Cinzel: © 2020 The Cinzel Project Authors (https://github.com/NDISCOVER/Cinzel). Licencia: `assets/fonts/OFL-Cinzel.txt`.
- Pixelify Sans: © 2021 The Pixelify Sans Project Authors (https://github.com/eifetx/Pixelify-Sans). Licencia: `assets/fonts/OFL.txt`.

## Motor: Godot Engine (MIT)

El juego tiene que incluir el aviso de copyright y la licencia de Godot, además de las licencias de terceros que lleva el motor (FreeType, ENet, mbedTLS…). Detalles: https://godotengine.org/license. La forma más sencilla es un apartado «Licencias» en el menú o un archivo de texto junto al ejecutable. Se puede sacar con `Engine.get_license_text()` y `Engine.get_copyright_info()`.

## Por confirmar (antes de Steam)

| Qué | Dónde | Qué falta |
|---|---|---|
| Plan de Tripo de los personajes | `assets/monstruos/` | Confirmar que es de pago (si no, regenerar o cambiar) |
| Texturas Pared_1, Suelo1, Suelo_2 | `assets/texturas/muros`, `assets/texturas/suelos` | Saber de dónde salen y con qué licencia |
| Gráficos 2D de Last Knight (iconos, sprites, cofres, retratos) | `assets/web/img`, `assets/web/gen` | Saber de dónde salen; la interfaz usa los iconos |

## Descartados (no meter en el juego)

| Paquete | Motivo |
|---|---|
| Rempart Walls scenery 1 – Fougères castle (noxfcna) | CC BY-NC 4.0: no permite vender. Además, es un escaneo de 615.000 triángulos |
| Armor Set (gimora) | CC BY-NC-SA 4.0: no permite vender. Además, no tiene esqueleto |
| Medieval Wall of Bricks Assets (nathan.arditti) | CC BY 4.0, pero 2,6 millones de triángulos y 140 MB |
| Patterned Brick Wall 2k | Repetido: se usa la versión 1k |

## Cómo se citan en los créditos

Formato CC BY: «Título» de Autor, licencia CC BY 4.0, con el enlace a la licencia y la nota de que se ha modificado. La pantalla de créditos del final del juego (`src/ui/creditos.gd`, que de momento sale con F1) lo muestra así. En la página de Steam conviene repetirlo en un apartado de créditos de la descripción o en un archivo `CREDITS.txt` incluido con el juego.

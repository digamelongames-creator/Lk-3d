# Estado · 7 nov 2026

## Hecho
- Muros con cara: un núcleo por casilla y una cara de sillería en cada lado que da al suelo (zócalo, sillares a matajunta y cornisa). Hay 8 variantes: lisa ×2, columna (cada 3 casillas), arco ciego, nicho, reja, rota y con hiedra. Además, columna en las esquinas que entran y que salen. Los muros miden 3 m. Lo que va colgado de la pared deja la cara lisa detrás.
- Monstruos de SPRITE_FACTORY en 3D animado: `tools/blender/monstruos_glb.py` lee las fichas de la fábrica (animaciones, tramos, armas) y deja `assets/monstruos/*.glb`. `Modelo3D` los anima según la simulación (andar, correr, preparar golpe con el golpe al final de la preparación, herido y morir). El esqueleto y la Bufona ya salen en partida. Los demonios se ven en la sala de prueba, pero aún no están en la simulación.
- Héroe: si existe `assets/monstruos/heroe.glb`, se usa con la espada de la fábrica en el hueso de la mano (`Modelo3D.enganche`). Mientras tanto, cápsula. Para probar: `--heroe=esqueleto`.
- Kit de arquitectura generado en Blender (`tools/blender/kit_mazmorra.py` → `assets/kit/kit_mazmorra.glb`). Tiene 3 muros de bloques, 3 suelos de losas, arco, pilar, antorcha, brasero, estandarte, barril y caja. `KitMazmorra` lo carga y pone los materiales de Godot según el nombre del material de Blender.
- Cámara isométrica ortográfica (`CamaraIso`: giro de 45° e inclinación de 33°), muros de 2,5 m. La opción `--perspectiva` vuelve a la vista en perspectiva.
- Sala de prueba `scenes/sala_prueba.tscn` con la sala de combate del concept: arcos, antorchas, braseros, estandartes, círculo grabado, rejilla y sangre.
- Proyecto nuevo en Forward+ (PC). Del repositorio `last-knight` se ha traído sin cambios `src/core` (simulación, botín, runas, clases, árbol, decorador, generador), los datos (`assets/web/data`, `assets/deco`) y la interfaz (`hud`, `inventory`, `personaje`). En `hud.gd` y `view_fx.gd` solo se han quitado tipos que apuntaban a la vista 2D.
- La mazmorra se monta con 3 GridMap (suelo, muros, objetos) a partir de la rejilla de `DungeonGen`. Las antorchas y lo del Decorador (velas con luz, calaveras, alfombras, losas) van como nodos sueltos.
- Kit provisional generado por código (`KitMazmorra`). Si existe `assets/kit/mazmorra.meshlib`, se usa ese.
- Héroe, enemigos, botín, oro, cofres y puertas son provisionales (cápsulas y cajas). El equipo puesto se cuelga de enganches en la mano derecha, la izquierda y la cabeza, y cambia al tocar el inventario.
- Muros que se vuelven transparentes al tapar al héroe, radio de luz del héroe, niebla volumétrica, glow, SSAO y números de daño en 3D.
- Cámara con inclinación de 45° por defecto y giro configurable (0° como Diablo 4, 45° en diagonal como Diablo 2).
- `test_botin` y `test_clases` dan «todo bien».

## Falta
- Modelo del héroe (Mixamo) en `SPRITE_FACTORY/input/characters/heroe/base.fbx` y su ficha `config/characters/heroe.json`.
- Los demonios (mini, middle, capitán, de fuego) en la simulación, con sus datos de `datos.json`.
- Piezas de muro según las vecinas (rotas, con hiedra, de esquina) y el arco en las puertas del juego, porque las puertas siguen siendo cajas de Actores3D.
- Más luz por pared: hoy el generador solo pone antorchas en las paredes del norte.
- Modelos del héroe y los monstruos (los .fbx de SPRITE_FACTORY y Mixamo) con AnimationTree. Los enganches pasan a ser BoneAttachment3D.
- Pisos 3–5 (abismo, alturas y escaleras largas): ahora el abismo sale como vacío y no hay alturas.
- Efectos de las habilidades y las runas (rayos, tajos, fuego): `Runes.bolts/slashes/fires` no se pintan.
- Sonido, menús de inicio y pausa, guardar y continuar desde el menú.
- Salas hechas a mano: cambiar el generador por plantillas de sala unidas por pasillos.

# Estado · 7 nov 2026

## Hecho
- Armadura visible (`Armadura3D`): casco, peto con 2 hombreras, guantes, cinturón y botas, colgados de los huesos de Mixamo y con piezas provisionales. Cuando exista `assets/armaduras/<casco|peto|hombrera|guante|cinturon|bota>.glb` se usa ese modelo (el izquierdo sale en espejo y se ajusta en `AJUSTE`). Aura según la calidad: básico sin aura, mágico/dorado/legendario con brillo de borde que late, y dorado/legendario además con chispas.
- Autoequipado: la pieza recogida se pone sola si su hueco está vacío; si no, va a la mochila (`Sim.try_pickup`). En el suelo, las piezas se ven con su forma 3D, su aura y una luz de su color. La espada y el escudo también se ven con su modelo. Prueba: `tests/test_armadura.gd`. Vitrina para ajustar las piezas: `tools/vitrina_armadura.gd`. Opción `--equipo=0..3` (equipo de esa calidad y piezas en el suelo).
- Combate 3D (`Sim.INTERRUMPIR`, `EMPUJE`, `LUNGE`): el héroe no avanza al atacar, tus golpes no cortan el ataque del enemigo (salvo la parada perfecta), el empujón se queda al 30% y los enemigos no hacen gesto de dolor. Prueba: `tests/test_combate.gd`.
- Panel «Has caído» con Revivir (en el sitio, media vida, sin apartar enemigos) y Nueva partida. Al morir, el héroe queda tumbado y con su luz. Prueba: `--morir`.
- Arreglado el cuelgue al cerrar el juego: faltaba `Idioma.soltar()` (la traducción propia se liberaba después de los scripts). Además, al salir se vacían las cachés estáticas (`KitMazmorra`, `Modelo3D`, `Atlas`, `Fonts`).
- Zoom con la rueda del ratón o con + y −, entre 7 y 20 m, con indicador en pantalla (`tests/test_zoom.gd`).
- Escudo redondo de madera con borde y umbo de hierro (brilla con su calidad si es mágico o mejor). Ya no sale la caja blanca, y con modelo no se pone caja de casco.
- El héroe usa el modelo del esqueleto, con la espada del equipo en la mano. Los esqueletos enemigos salen más oscuros y rojizos. Los enemigos humanos (caballeros, renegados) usan Prueba2 de forma provisional.
- Demonios en la simulación (`monsters.json`, piso 1 de prueba, `from`/`to` = 1). Hay 4 minidemonios juntos, un middle, un capitán y un demonio de fuego, cada uno en su sala. El capitán salta (`monster_skills` → `salto`): al caer daña, aturde al héroe 2 s (`Hero.aturdido`) y da dos puñetazos. Brasas y humo en 3D según la ficha. Prueba: `tests/test_demonios.gd`.
- El juego arranca en pantalla completa (`window/size/mode=3`) y F11 cambia a ventana. Opción de prueba: `--junto=<monstruo>`.
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
- Modelos de armadura de Diego (en `C:\\SPRITE_FACTORY\\armaduras\\`) y ajustarlos a los huesos. Espadas y escudos nuevos, en otro chat.
- Pasar los demonios a sus pisos de verdad (2–4) cuando acabe la prueba.
- Modelos propios para los humanos: riggear en Mixamo los de `input/raw` (elf, violeta, cuernitos, medusa, vaquita).
- Piezas de muro según las vecinas (rotas, con hiedra, de esquina) y el arco en las puertas del juego, porque las puertas siguen siendo cajas de Actores3D.
- Más luz por pared: hoy el generador solo pone antorchas en las paredes del norte.
- Modelos del héroe y los monstruos (los .fbx de SPRITE_FACTORY y Mixamo) con AnimationTree. Los enganches pasan a ser BoneAttachment3D.
- Pisos 3–5 (abismo, alturas y escaleras largas): ahora el abismo sale como vacío y no hay alturas.
- Efectos de las habilidades y las runas (rayos, tajos, fuego): `Runes.bolts/slashes/fires` no se pintan.
- Sonido, menús de inicio y pausa, guardar y continuar desde el menú.
- Salas hechas a mano: cambiar el generador por plantillas de sala unidas por pasillos.

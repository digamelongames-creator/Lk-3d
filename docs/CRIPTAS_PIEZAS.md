# Criptas (pisos 1–2): piezas para el creador de mundos

Repertorio de piezas 3D que el creador de mundos (`Arquitectura` → `Decorador` → `Amueblado3D`) va a colocar solo en las Criptas.
Proceso, igual que en el Inframundo y el Abismo de cristal: encargo a Pixmith (una imagen por pieza, fondo neutro, vista 3/4 desde arriba como la cámara del juego, sin capturas del juego como referencia) → Diego la pasa a 3D con Tripo → `python3 tools/blender/props_glb.py <carpeta> assets/props criptas` → ficha en `assets/props/catalogo.json`.

Carpeta: `C:\Carpeta Juego\Temas\criptas\piezas_tripo\` (una imagen por pieza, con el nombre de la tabla).

**Estilo común de todos los encargos:** fantasía oscura realista, piedra caliza gris verdosa envejecida, hierro oxidado y madera vieja. Iluminación neutra de estudio, fondo gris liso y la pieza entera y centrada, sin suelo ni sombras de otros objetos. Vista isométrica 3/4 desde arriba (35°). Sin texto.

## Arquitectura (sustituyen o completan las caras del muro y las puertas)

| Pieza | Medidas (an × al × fo) | Dónde | Encargo para Pixmith |
|---|---|---|---|
| `cr_columna_muro` | 0,8 × 3 × 0,5 m | cara de muro, extremos y ritmo de los tramos | Media columna adosada a un muro, románica, fuste liso con capitel de hojas y basa cuadrada, piedra caliza desgastada con musgo en la base |
| `cr_arco_ciego` | 2 × 3 × 0,4 m | cara de muro (capillas, salones) | Arco ciego de medio punto tallado en un muro de sillería, dovelas marcadas, interior algo hundido y oscuro, hollín en la clave |
| `cr_nicho_huesos` | 2 × 3 × 0,6 m | cara de muro (criptas, osarios) | Nicho funerario de tres alturas en muro de sillería, cada hueco con calaveras y huesos apilados, telarañas |
| `cr_lapida_muro` | 2 × 3 × 0,3 m | cara de muro (criptas) | Lápida grande empotrada en muro con relieve de un caballero yacente, letras borradas e ilegibles, grietas |
| `cr_puerta_arco` | 2,4 × 3,2 × 0,8 m | marco de las puertas en muros altos | Portal de piedra con arco de medio punto, jambas con columnillas y cadenas oxidadas colgando a los lados, sin puerta (hueco abierto) |
| `cr_muro_bajo_roto` | 2 × 1,1 × 0,8 m | (referencia del borde de los muros bajos) | Tramo de muro de sillería derruido a la altura de la cintura, borde superior roto e irregular, cascotes caídos al pie |
| `cr_esquina_columna` | 0,9 × 3 × 0,9 m | esquinas | Pilastra de esquina de sillería con molduras en la base y la cornisa, aristas desgastadas |
| `cr_pilar_sala` | 1 × 3 × 1 m | columnata (rasgo `columnata`) | Pilar exento románico de sección cuadrada con columnillas en las esquinas, capitel tallado, base con musgo |
| `cr_brocal_estanque` | 2 × 0,5 × 2 m | borde de los estanques (rasgo `estanques`) | Brocal bajo de piedra para un estanque cuadrado de agua oscura, losas del borde gastadas, una esquina rota |

## Protagonistas de sala (uno por sala, según su papel)

| Pieza | Medidas | Sala | Encargo para Pixmith |
|---|---|---|---|
| `cr_altar` | 2 × 1,1 × 1 m | capilla, santuario | Altar de piedra con mantel rojo desgarrado, candelabros de hierro con velas derretidas y un cáliz, escalón delante |
| `cr_sarcofago` | 1,2 × 0,9 × 2,2 m | cripta | Sarcófago de piedra con tapa tallada de un caballero con espada, tapa algo desplazada, grietas y polvo |
| `cr_sarcofago_abierto` | 1,2 × 0,9 × 2,2 m | cripta, guarida | El mismo sarcófago con la tapa caída a un lado, rota en dos, y el interior vacío y oscuro |
| `cr_monton_huesos` | 1,6 × 0,8 × 1,6 m | osario | Montón de calaveras y huesos largos apilados en pirámide, algunas velas encima |
| `cr_trono_roto` | 1,4 × 2,2 × 1,2 m | salón, guarida | Trono de piedra de respaldo alto con calaveras talladas, un brazo roto, cojín podrido |
| `cr_mesa_guardia` | 2 × 0,9 × 1 m | almacén, entrada | Mesa de madera maciza vieja con jarra, pan duro, dados y una vela; un taburete volcado al lado |
| `cr_cofre_reliquias` | 1 × 0,7 × 0,6 m | tesoro | Arca de reliquias de madera con herrajes dorados y cerradura, sobre dos piedras |

## Junto a la pared y relleno

| Pieza | Medidas | Dónde | Encargo para Pixmith |
|---|---|---|---|
| `cr_estanteria_urnas` | 2 × 2 × 0,5 m | pared (osario, almacén) | Estantería de madera carcomida con urnas funerarias de barro, algunas rotas, telarañas |
| `cr_sarcofagos_pared` | 2,2 × 1 × 1 m | pared (cripta) | Dos sarcófagos sencillos de piedra pegados a la pared, uno encima de otro en un hueco de sillería |
| `cr_candelabro_pie` | 0,6 × 1,8 × 0,6 m | esquina, junto a protagonistas | Candelabro de pie de hierro forjado con cinco velas derretidas y cera chorreando |
| `cr_estatua_monje` | 0,8 × 2,2 × 0,7 m | pared (capilla, salón) | Estatua de piedra de un monje encapuchado rezando, rostro en sombra, manos juntas, base cuadrada |
| `cr_rejas_celda` | 2 × 3 × 0,2 m | pared (guarida) | Reja de hierro oxidado de una celda, encajada en un hueco de piedra, con un grillete colgando |
| `cr_cadenas_pared` | 1,2 × 1,6 × 0,3 m | colgado | Argolla de hierro en la pared con dos cadenas y grilletes colgando, óxido |
| `cr_estandarte_roto` | 1 × 2 × 0,1 m | colgado (salón, entrada) | Estandarte de tela granate desgarrado con un emblema de calavera y corona, colgado de una barra de hierro |
| `cr_cascotes` | 1,5 × 0,4 × 1,5 m | libre (ruina, pasillos) | Cascotes de sillería caídos, piedras de varios tamaños y polvo |
| `cr_velas_suelo` | 0,8 × 0,3 × 0,8 m | libre (capilla, osario) | Grupo de velas derretidas en el suelo sobre un charco de cera, de distintas alturas |

Total: 25 piezas. Cuando estén convertidas, `Amueblado3D.PIEZAS` y las caras de `Arquitectura._componer` las usan en lugar de las del kit y los paquetes de fuera.

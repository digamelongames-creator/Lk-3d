class_name Ritmo
## Ajustes de ritmo y sensación (rama prueba-ritmo): todo en un solo sitio para retocarlo.

## velocidad de movimiento del héroe (1,10 = +10 %)
const VEL_HEROE := 1.10
## zoom de la cámara (píxeles de la resolución base 1280×720 por píxel del mundo).
## 8/3 = 4 píxeles de pantalla por píxel del mundo a 1080p (antes 2 = 3 píxeles)
const ZOOM := 8.0 / 3.0
## opacidad de la oscuridad fuera de las luces (la web usa 0,95; 1 = negro total)
const OSCURIDAD := 1.0
## intensidad de las antorchas (luz y resplandor) respecto a la web
const ANTORCHAS := .5
## vibración de la cámara al recibir daño (1,25 = +25 %)
const VIBRA_DANO := 1.25
## vibración al matar (1,25 = +25 %; ya había una de 5 px, 10 con campeón).
## No se acumula: matar a varios a la vez toma la mayor, no la suma.
const VIBRA_MATAR := 1.25
## voltereta (dash): recarga ×3; duración +10 % con la misma velocidad = +10 % de distancia
const DASH_RECARGA := 3.0
const DASH_TIEMPO := 1.10

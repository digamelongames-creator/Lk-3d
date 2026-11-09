# Enemigos que aprenden

Decidido por Diego el 9 de noviembre de 2026. Código: `src/core/aprendizaje.gd` (`Aprendizaje`), enganchado en `Sim`.

## Idea

- Cada piso tiene más o menos las mismas salas y los mismos enemigos. Cada enemigo recibe un **puesto fijo** por orden de reparto: «2-37» es el enemigo 37 del piso 2. La mazmorra cambia de forma, pero el 37 de hoy es el 37 de mañana y recuerda lo que aprendió.
- Si un piso sale con menos enemigos, los puestos que sobran esperan a la siguiente partida sin perder nada.
- **No aprenden movimientos nuevos.** Les damos 6 tácticas y aprenden cuál les funciona mejor:

| Táctica | Qué hace |
|---|---|
| Directo | Va a por ti y golpea (lo de siempre). |
| Rodear | Busca un hueco libre a tu alrededor, separándose de los demás, y golpea desde ahí. |
| Por la espalda | Te rodea por el lado más corto hasta quedar detrás y golpea. |
| Contraataque | Espera justo fuera de tu alcance y entra al acabar tu tajo o tu voltereta. |
| Rematar | Se queda a distancia mientras tienes vida y entra a por ti cuando te queda menos del 45 %. |
| Escolta | Se queda entre su jefe y tú; ataca cuando te acercas al jefe. Solo si su sala tiene élite o jefe. |

- Si lleva 4 s sin golpear, deja la táctica y va a por ti (nadie se queda esperando para siempre).
- Al despertar elige la táctica de ese combate: casi siempre la mejor que conoce y el 15 % de las veces una al azar, para seguir probando.

## Memorias

- **Por tipo y papel** («esqueleto/esbirro», «knight/grupo», «esqueleto/elite», «…/jefe», «…/pasillo»): la comparten todos los de ese tipo y papel, así que aprenden rápido.
- **Por puesto**: le da su carácter. Cuantos más combates propios tiene, más pesa lo suyo (con 8 combates, la mitad).

## Nota de cada combate

Combate = de que despierta a que muere, te mata o se acaba el piso.
Nota = daño que te hizo ÷ tu vida máxima ÷ segundos (mínimo 4) × 20, más 2 si te mató.
Si te matan, se cierran los combates de todos los despiertos (el premio solo para quien dio el golpe). Al revivir empiezan otro.

## Títulos

- **Asesino**: el puesto te ha matado 3 veces (`ASESINO_N`).
- **Experto**: el puesto lleva 12 combates (`EXPERTO_N`).
- Salen encima de la cabeza (en las élites, delante del nombre). Por ahora mantienen su puesto y no ascienden.

## Archivo y servidor

`user://aprendizaje.json` (en Windows, `%APPDATA%\Godot\app_userdata\Last Knight 3D\aprendizaje.json`). Se guarda al bajar de piso, al morir, al volver al menú y al salir. Borrarlo pone a todos los enemigos a cero.

```json
{"version": 1,
 "tipos":   {"esqueleto/esbirro": {"espalda": [n, suma_de_notas], "...": []}},
 "puestos": {"2-37": {"t": {"contra": [n, suma]}, "combates": 14, "muertes": 3}}}
```

Solo hay cuentas y sumas, así que lo de muchos jugadores se junta **sumando** (`Aprendizaje.fusionar`). Plan del servidor: cada partida sube su archivo (o lo nuevo desde la última vez), el servidor los suma una vez al día y todos descargan el total.

## Para probar

- Piso de prueba → sala «Aprendizaje» (`--sala=10`): un miniboss y 4 esbirros con los puestos «prueba-1» a «prueba-5». Al entrar sale la ronda 1; cuando mueren todos, a los 2,5 s sale otra con los mismos (que recuerdan) y vida llena para ti.
- **F3** (o `--f3`): panel con los enemigos cercanos, su puesto, su papel, su título, el número de combates, la táctica de ahora y las notas de cada táctica, de mejor a peor.
- Prueba automática: `tests/test_aprendizaje.gd`.

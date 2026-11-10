# Last Knight 3D · Producto mínimo

Decidido por Diego el 10 de noviembre de 2026.

El producto mínimo es **el primer juego completo que se podría enseñar o subir como demo a Steam**. Tiene una clase, 10 pisos, Inca con tiendas y guardado. Todo lo que no esté en esta lista va después.

## Decisiones (10 nov 2026)

| # | Decisión | Respuesta |
|---|---|---|
| 1 | Una sola clase: el caballero, que ya tiene armadura | Sí |
| 2 | 10 pisos, con el campeón como jefe en los pisos 5 y 10 | Sí |
| 3 | Inca, tanda 2 (tenderos, tiendas y almacén compartido) dentro del mínimo | Sí |
| 4 | Guardado con varias ranuras dentro del mínimo | Sí |
| 5 | Cooperativo fuera del mínimo, pero con la simulación preparada | Sí |
| 6 | Enemigos que aprenden fuera del mínimo | Sí |
| 7 | Cooperativo de hasta 4 jugadores | Sí |
| 8 | Preparar la simulación para servidor **antes** de Inca, tanda 2 | Sí |
| 9 | Cerrar el juego o volver al menú en mitad de la mazmorra cuenta como morir | Sí (confirmado) |
| — | El multijugador será cooperativo en tiempo real (no solo comercio) | Sí |

## Qué entra

| Parte | Estado | Falta |
|---|---|---|
| Caballero: combate, 3 habilidades, árbol y runas | Hecho | Equilibrio con la hoja |
| Set del Caballero Oscuro visible pieza a pieza | Hecho | — |
| Pisos 1–10: grupos, élites, jefe, reto, trampas, rompibles y mímico | Hecho | Probar los 10 pisos y ajustar la dificultad |
| Inca, tanda 1 (ciudad, zona segura, bajar y subir) | Hecho | Que Diego la pruebe |
| Inca, tanda 2: herrero, alquimista, runista y almacén compartido | Por hacer | Después de preparar la simulación |
| Guardado con ranuras; salir en la mazmorra cuenta como morir | Por hacer | Guardado con número de versión |
| Menú, opciones, pausa y créditos | Hecho | — |
| Sonido | Sintetizado | Paquete definitivo (opcional) |
| Licencias para Steam | En marcha | Confirmar el plan de Tripo |

## Qué queda fuera (para después)

- Las otras 4 clases. Siguen en el código y se pueden elegir, pero no se pulen ni se equilibran para el mínimo.
- El cooperativo en tiempo real (hasta 4 jugadores), el comercio entre jugadores y «publicar partida».
- Los enemigos que aprenden. Lo que ya existe (`Aprendizaje`) se queda, pero no es requisito ni se sigue ampliando para el mínimo.
- Inca, tanda 3 (vecinos que pasean).
- Los pisos a partir del 11.

## Preparar la simulación para el cooperativo (paso 8)

El objetivo es que, cuando llegue el cooperativo, la simulación pueda funcionar en un servidor sin rehacerla. No se programa red todavía. Son cinco reglas:

1. **La simulación solo cambia por órdenes.** Cada fotograma, el héroe manda una orden (moverse hacia, atacar, habilidad N, usar, recoger…). La pantalla y el teclado no tocan la simulación directamente.
2. **Varios héroes.** La simulación deja de suponer un único héroe (`p`). Tiene una lista de héroes, aunque de momento solo haya uno.
3. **Los objetos y el oro los aprueba la simulación.** Cada pieza lleva un identificador único. Comprar, vender, recoger, tirar y guardar en el almacén pasan por la simulación, que comprueba que es posible. La interfaz solo lo pide.
4. **Todo el azar sale de la semilla.** La simulación ya usa un único generador (`rng`, Mulberry32). Hay que comprobar que ninguna parte de la vista decide nada de la partida.
5. **Guardado con versión.** El archivo de guardado lleva un número de versión y una función que convierte las partidas viejas.

Las tiendas y el almacén de Inca, tanda 2, se hacen ya con estas reglas.

## Cuándo está terminado el mínimo

- Se puede jugar de Inca al piso 10 con el caballero sin errores, guardando y cargando.
- La hoja de equilibrio cuadra con lo que se siente al jugar: la élite es un reto, el jefe tarda de 20 a 60 s y morir es posible pero no constante.
- Todas las pruebas `tests/` dicen «todo bien».
- `docs/LICENCIAS.md` está completo y todo lo que se usa permite venderlo.

## Orden de trabajo

1. Diego prueba lo pendiente (Inca tanda 1, rama `pasillos-contorno`, combate rígido, tandas de diversión).
2. Equilibrio: se ajusta la hoja `equilibrio_last_knight_3d.xlsx` y se pasan los valores al código.
3. Se prepara la simulación para el cooperativo (las 5 reglas).
4. Inca, tanda 2, y guardado con ranuras.
5. Pisos 6–10: se prueban y se ajustan.
6. Repaso para la demo: licencias, créditos y rendimiento en el PC mínimo.

## Preguntas abiertas

- ¿Qué PC mínimo se pone como objetivo (para Steam y para el rendimiento)?
- ¿Qué hace especial a un legendario? Ahora, afijo a afijo, un dorado bueno le gana.
- ¿El equipo debe mejorar con la oleada? Ahora da lo mismo en el piso 1 que en el 10.

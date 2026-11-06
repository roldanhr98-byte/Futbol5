# E4 — Integración al nivel de UCS: datos de animación, golpeo sincronizado e IA con los parámetros de UCS (2026-11-06)

Pedido: integrar todo el sistema como UCS, sin auditorías ni recomendaciones. Eso incluye:

- usar en el juego real los datos de `animdb.adb`;
- que la física y las animaciones coincidan (sin pelota pegada al pie ni teletransportada);
- integrar todas las acciones;
- estudiar la IA de UCS y llevarla a la nuestra;
- probar, compilar el APK y entregar el enlace.

## Qué se encontró en UCS (comprobado)

1. **Configuración de juego** (`libMPX.so`, una función que carga 210 parámetros):
   - cada parámetro se pide por nombre con un valor por defecto entero, en punto fijo 4096 = 1.0 si es una escala;
   - tabla completa en [`E4_parametros_ucs.csv`](E4_parametros_ucs.csv), extraída leyendo el código ARM64 con capstone;
   - el **valor** está comprobado; el **significado** se infiere del nombre;
   - el servidor de UCS podría cambiar algún valor (no se pudo comprobar sin conexión).
2. **`animdb.adb`** ([E3](E3_conduccion_ucs.md)):
   - por clip: cuadro del toque, pie, destino de la pelota tras el toque, giro, ventana del joystick y velocidades;
   - en las recepciones, los vectores de pelota **no** son el punto de contacto: a 0.6 m de mediana de la parte del cuerpo
     en ese cuadro, en 92 recepciones verificadas. Son el destino tras el toque, como en la conducción, y así se usan.

## Qué quedó implementado

| Área | Cambio | Dónde |
|---|---|---|
| Conducción | Toque orientado con 41 clips de UCS (82 con espejos), elegido por la ventana del joystick de UCS, cortado tras el toque que gira; arranque con pelota con los clips de arranque de UCS | `JsonBallMove` (E3) |
| Golpeo de primera | El impulso sale en el paso en que la pelota que llega y la punta del pie **animado** están más cerca (espera ≤ 0.1 s; la pelota no se mueve a mano) | `BallHandler._ball_still_arriving` |
| Tras un golpe propio | Sin toque orientado ni arranque durante 1.2 s (el que pasaba alcanzaba su propio pase filtrado y empezaba un movimiento) | `JsonBallMove.STEER_AFTER_KICK_S` |
| Presión | Hasta 2 presionan y 1 entra (`MaxActivePresses`/`MaxActiveTackles`); la cobertura pasa a segundo presionador si llega en ≤ 1.2 s; presión al 95 % (`PressureSpeedRate`) | `TeamBrain`, `AIInput` |
| Ataque | Amplitud al 60 % del ancho (`WidthOpenPlay`); el portador pasa sin presión entre 0.5 y 2 s (`BotMin/MaxKickFrames`) | `TeamBrain`, `AIInput` |
| Arquero | Reacción de 0.25 a 0.07 s según reflejos (`ResponseGKSave` 15/4 cuadros) | `Goalkeeper` |
| Botines | ~0.26 m (antes ~0.40 m) | `json_human.scn` (E3) |
| animdb | Base de datos propia con todas las animaciones por acción y los datos de UCS; la lee el juego (`AnimDB`) | `assets/animations/animdb.json` |

## Medido

Ver la sección «Resultados» al final (se completa con las corridas reales).

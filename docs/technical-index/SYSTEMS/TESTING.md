# TESTING — Marco de pruebas headless y suites

## Identificación

- **Responsabilidad exacta:** verificar la simulación (física de la pelota, locomoción, conducción, pases, tiros, presión, patada sincronizada, reglas de partido, controles táctiles, modelo) **sin pantalla ni dependencias externas**, con un marco propio de ~150 líneas. Cada método `test_*` de una subclase de `TestCase` es una prueba.
- **Estado:** operativo. **Última ejecución completa (2026-10-26):** headless con las librerías del pack: **121 pruebas, 0 fallidas, 2 omitidas (necesitan render), 686 comprobaciones, 0 `SCRIPT ERROR`, ~92 s**. Con render (`xvfb-run`, por filtro): `gameplay_feel` 10/33, `control_and_keeper` 7/26, `goalkeeper` 5/25, `pack_motion` 2/24, `player_actions` 4/13, `practice` 4/37, todas 0 fallidas y 0 omitidas. La suite completa con render **no se terminó**: `test_ai_match` simula partidos de 120 s con 10 personajes animados y con `llvmpipe` tarda decenas de minutos. **Sin** las librerías del pack: las pruebas del pack, arquero, práctica, sensación de juego e IA se omiten.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-28
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes |
|---|---|---|
| `tools/run_tests.sh` | Punto de entrada: reimporta el proyecto, ejecuta la escena de pruebas con `--headless --fixed-fps 60`, quita colores ANSI y **falla si la salida contiene `SCRIPT ERROR`** | `GODOT_BIN` (por defecto `godot`), filtro opcional por nombre de archivo |
| `tests/run_tests.tscn` + `tests/run_tests.gd` | Escena y ejecutor: descubre `tests/test_*.gd`, ejecuta cada `test_*` (con `await`), cuenta comprobaciones y sale con código 1 si hay fallos | `--filter <subcadena>` |
| `tests/test_case.gd` | Clase base `TestCase` | `check`, `check_near`, `note`, `physics_frames`, `wait_seconds`, `spawn`, `cleanup`, `make_world`, `make_match`, `add_player` |

## Reglas del marco (verificadas en el código)

- **Pruebas omitidas** (`TestCase.skip(motivo)`): se muestran como `[SKIP]` y se cuentan aparte; **no cuentan como aprobadas ni como comprobaciones**. Se usan cuando falta un recurso restringido que no se versiona (la librería local del pack, ver [ANIMATION_PACK](ANIMATION_PACK.md)) o cuando hace falta render (`DisplayServer` = headless no anima el esqueleto). `TestCase.cleanup()` restaura los interruptores globales (`FootballerVisual.prefer_pack`, `BallHandler.clip_kicks_enabled`).
- **Con render:** `xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <nombre>` (la suite completa tarda ~4 min por `llvmpipe`); `tests/test_pack_motion.gd` mide el esqueleto realmente animado.
- Las lambdas de GDScript capturan las variables **por valor**: para que una señal escriba en una variable local se usa un `Dictionary`/`Array`.
- Una prueba que ejecuta **0 comprobaciones se considera FALLIDA** (`run_tests.gd`).
- Un error de script **a mitad** de una prueba aborta su cuerpo pero el ejecutor la cuenta como correcta si ya hizo ≥ 1 comprobación. Por eso `tools/run_tests.sh` busca `SCRIPT ERROR` en la salida y devuelve 1. **Si se ejecuta Godot directamente (sin el script), esa protección no existe.** (Corrección del 2026-10-26: `test_animation_tree_responds_to_speed` lanzaba un `SCRIPT ERROR` por leer `parameters/TimeScale/scale` — el nodo real se llama `LocoScale` — y figuraba como correcta con 1 comprobación.)
- La ventana de pruebas se fija en 1280×720 (los controles táctiles se posicionan respecto a ella).
- Determinismo: `BallHandler.rng.seed` se fija en `TestCase.add_player` (`12345 + id`); la física de Jolt corre a 60 Hz con `--fixed-fps 60`.
- `TestCase.make_match` crea cancha + pelota + `MatchContext` **sin cámara ni `MatchManager`**; `add_player(..., with_visual=false)` crea el futbolista sin modelo.
- **El aislamiento no es total:** una misma prueba puede dar mediciones distintas ejecutada sola o dentro de la suite completa (verificado con los duelos de presión: 24 robos / 47 fallos solo con `press`, 22 / 48 en la suite completa; las cotas de aceptación son lo bastante amplias para pasar en ambos casos). Para comparar mediciones antes y después de un cambio, usar siempre el mismo modo de ejecución.
- Las pruebas escriben mediciones con `note()` (líneas `·` en la salida); esas cifras son las que citan las fichas.

## Suites (medido el 2026-10-26)

| Archivo | Pruebas | Comprobaciones | Sistema | Ficha |
|---|---|---|---|---|
| `tests/test_ball_physics.gd` | 9 | 24 | Pelota (rebote, rodadura, arrastre, Magnus, red, estado serializable) | [BALL](BALL.md) |
| `tests/test_locomotion.gd` | 6 | 18 | Locomoción (aceleración, giro, frenada, sprint, paredes) | [PLAYER](PLAYER.md) |
| `tests/test_dribbling.gd` | 6 | 14 | Conducción y toques | [PLAYER](PLAYER.md) |
| `tests/test_kick_timing.gd` | 3 | 15 | Contacto sincronizado y curvas de la patada | [PLAYER](PLAYER.md), [ANIMATIONS](ANIMATIONS.md) |
| `tests/test_passing.gd` | 8 | 27 | Pase asistido y error por atributos | [ASSISTANCE](ASSISTANCE.md) |
| `tests/test_shooting.gd` | 6 | 16 | Tiro asistido | [ASSISTANCE](ASSISTANCE.md) |
| `tests/test_press.gd` | 5 | 14 | Presión y robo | [ASSISTANCE](ASSISTANCE.md) |
| `tests/test_match_flow.gd` | 7 | 31 | Reglas del partido (saque, gol, gol en contra, reinicio, pausa, fin) | [MATCH](MATCH.md) |
| `tests/test_touch_controls.gd` | 4 | 20 | Controles táctiles | [INPUTS](INPUTS.md), [UI_HUD](UI_HUD.md) |
| `tests/test_player_model.gd` | 4 | 36 | Modelo, esqueleto, clips, kit | [ANIMATIONS](ANIMATIONS.md) |
| `tests/test_pack_retarget.gd` | 6 | 100 | Retarget del pack: pistas limpias, orientación, pies en el suelo, velocidades naturales, contactos medidos | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_pack_locomotion.gd` | 4 | 71 | Marcha del pack, respaldo de Tripo, catálogo único, acciones sin solaparse | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_pack_kick.gd` | 8 | 105 | Contacto pie–pelota con clips: sincronía, fuera de alcance, patada en falso, ajuste de zancada, instante por trayectoria | [PLAYER](PLAYER.md) |
| `tests/test_pack_dribble_metrics.gd` | 2 | 23 | Métricas de conducción y ejecución de pase/tiro a trote/carrera/sprint (procedural vs clip) | [PLAYER](PLAYER.md) |
| `tests/test_pack_reactions.gd` | 6 | 18 | Celebrar/lamentarse en un gol y recepción, con respaldo de Tripo | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_pack_motion.gd` | 2 (render) | 24 (render) | Deslizamiento del pie de apoyo y punta del pie viva en el impulso (**solo con render**) | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_goalkeeper.gd` | 5 | 25 | Arquero: posición, planificador de manos, bloqueo y saque, contacto real, tasa de atajadas por velocidad | [GOALKEEPER](GOALKEEPER.md) |
| `tests/test_ai_match.gd` | 4 | 16 | Partido completo 4+arquero contra 4+arquero con IA (pases, tiros, robos, sin trabarse), pelota nunca bloqueada, tiros con ángulo útil, patadas al aire acotadas y colores de cada equipo | [MATCH](MATCH.md), [PLAYER](PLAYER.md) |
| `tests/test_aerial_kicks.gd` | 1 | 2 | Voleas y cabezazos: contacto de pie/cabeza con la pelota en vuelo | [PLAYER](PLAYER.md) |
| `tests/test_player_actions.gd` | 4 | 13 | Barrida planificada, caídas y levantarse, regate (ruleta), raíz de las acciones | [PLAYER](PLAYER.md) |
| `tests/test_gameplay_feel.gd` | 10 | 33 | Sensación de juego medida: conducción lenta, sprint, frenar con la pelota, giros de 90°/180°, control lateral, pase pulsado en carrera, recepción sin frenar, acciones que no bloquean | [PLAYER](PLAYER.md) |
| `tests/test_control_and_keeper.gd` | 7 | 26 | Cedida recibida con el pie vs disparo atajado, arquero manejado por la persona (joystick, atrapar, sacar), indicadores de jugador, cambio al arquero, saque inicial | [GOALKEEPER](GOALKEEPER.md), [UI_HUD](UI_HUD.md), [MATCH](MATCH.md) |
| `tests/test_pass_receiver_control.gd` | 4 | 16 | Control de la persona en los pases: receptor controlado al pasar (con y sin destinatario), sin cambio durante el vuelo de un pase largo, control al compañero que se queda con la pelota, la IA del equipo de la persona no pasa ni patea, la IA sigue jugando sin persona | [MATCH](MATCH.md) |
| `tests/test_animation_inventory.gd` | 2 | 5 | Inventario medido de las 171 animaciones (trayectoria de los pies, empujes, veredicto de conducción); `INVENTORY_OUT` escribe el informe, `DRIBBLE_CANDIDATE` valida un clip nuevo | [ANIMATION_PACK](ANIMATION_PACK.md) |
| `tests/test_kick_reach.gd` | 2 | 17 (render) / 10 | Golpeo pedido con la pelota propia fuera del alcance: el jugador ajusta la carrera y golpea con contacto o cancela con aviso | [PLAYER](PLAYER.md) |
| `tests/test_shared_ball_mechanics.gd` | 2 | 8 | La IA usa la misma mecánica de pelota que la persona (sin atajos) | [PLAYER](PLAYER.md) |
| `tests/test_dribble_reference.gd` | 1 (render) | 6 (render) | Conducción recta medida contra el video de referencia (intervalo, pie, alternancia, distancia, deriva) | [PLAYER](PLAYER.md) |
| `tests/test_drag_back.gd` | 4 | 54 (headless) / 52 (render) | Vuelta atrás pisando la pelota: caminando, al trote y a la carrera en 6 momentos del ciclo (pisada o media vuelta), sprint sin pisada, la IA con la misma mecánica; con render, la suela sobre la pelota | [PLAYER](PLAYER.md) |
| `tests/test_practice.gd` | 4 | 37 | Galería (133 clips, roles), reproducción de todos los clips, raíz y espejo, malabares por impulsos | [ANIMATIONS](ANIMATIONS.md) |
| **Total (headless)** | **121 + 2 omitidas** | **686** | | |

Comando por sistema: `tools/run_tests.sh pack_kick`, `pack_dribble`, `pack_reactions`, `pack_locomotion`, `pack_retarget`, `ball_physics`, `locomotion`, `dribbling`, `kick_timing`, `passing`, `shooting`, `press`, `match_flow`, `touch_controls`, `player_model`. Todo: `tools/run_tests.sh`.

## Lo que NO cubren las pruebas (verificado)

| Área | Situación |
|---|---|
| Cámara (`MatchCamera`) | Sin aserciones; solo se instancia en `test_match_flow` ([CAMERA](CAMERA.md)) |
| Gráficos y diagnóstico (`GraphicsSettings`, `DiagnosticsOverlay`) | Sin pruebas ([PERFORMANCE](PERFORMANCE.md)) |
| Menú de pausa y marcador del `Hud` | Sin pruebas ([UI_HUD](UI_HUD.md)) |
| `GameEvent`/`InputFrame` `to_dict`/`from_dict`, `PlayerAttributes` serialización | Sin pruebas directas ([NETWORK](NETWORK.md), [PROGRESSION](PROGRESSION.md)) |
| Persistencia en `user://` (`Tuning.save_user_settings`, `GraphicsSettings.save_settings`) | Sin pruebas |
| Audio, estadísticas, online | No existen |
| IA frente a humanos, arquero con el esqueleto vivo en un partido completo con render, sala de práctica con toques reales | Sin pruebas (la IA y el arquero se miden en simulación headless; la práctica se probó con render solo por filtro) |
| Android (dispositivo/emulador) y aspecto visual | No se prueba; solo capturas manuales con Xvfb. Las pruebas del pack miden el esqueleto animado con render por software, no un móvil |
| Pack de animaciones en un clon limpio | Sin las librerías del pack (`pack_clips.res`, `pack_keeper.res`) las pruebas que las necesitan se **omiten** |
| Un caso de prueba por atributo | No existe: los atributos se ejercitan solo a través de pase, tiro, conducción y locomoción (varios no se usan en el código: ver [PROGRESSION](PROGRESSION.md)) |

## Cómo añadir una prueba

1. Crear `tests/test_<tema>.gd` con `extends TestCase` y métodos `func test_...() -> void:` (pueden usar `await`).
2. Usar `make_match()` y `add_player(ctx, equipo, posición, atributos, ScriptedInput)` y avanzar con `await wait_seconds(s)` / `physics_frames(n)`; cada prueba debe hacer **al menos un** `check`.
3. Ejecutar `tools/run_tests.sh <tema>`, luego `python3 tools/docs_index.py sync` (añade la prueba a la ficha) y `check`.
4. No registrar una prueba como aprobada si no se ejecutó (regla del CHANGELOG).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): evolución 9/24 → 40/113 → 44/140 → 54/188 → 57/209 → 57/212 (reproducida commit a commit el 2026-10-26).

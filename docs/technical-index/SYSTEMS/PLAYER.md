# PLAYER — Futbolista de campo

## Identificación

- **Responsabilidad exacta:** el futbolista de campo, controlado únicamente a través de `InputFrame`: movimiento con aceleración progresiva y giro dependiente de la velocidad (`Locomotion`), conducción por toques físicos, control de primer toque, posesión, robo (`BallHandler`), y la patada de pase/tiro cuyo impulso se aplica en el instante de contacto de la animación. La presión defensiva y las asistencias de pase/tiro viven en [ASSISTANCE](ASSISTANCE.md); el modelo y las animaciones en [ANIMATIONS](ANIMATIONS.md).
- **Estado:** implementado para **un** jugador humano por equipo. No hay IA ni cambio de jugador.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-27
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos / nodos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/player/footballer.gd` | Clase `Footballer` (`CharacterBody3D`): orquesta entrada → presión → locomoción → `move_and_slide` → manejo de pelota → visual. Crea la cápsula de colisión (`CollisionShape3D`) y el hijo `Visual` | `Footballer.setup`, `Footballer._physics_process`, `Footballer.place_at`, `Footballer.capture_state` | `MatchContext`, `Locomotion`, `BallHandler`, `PressController`, `FootballerVisual` |
| `scripts/player/locomotion.gd` | Clase `Locomotion` (`RefCounted`, pura): velocidad, giro, agarre lateral, frenada, sprint y resistencia | `Locomotion.step`, `Locomotion.speed_for_magnitude`, `Locomotion.max_run_speed`, `Locomotion.max_sprint_speed` | `PlayerTuning`, `PlayerAttributes` |
| `scripts/player/ball_handler.gd` | Clase `BallHandler` (`RefCounted`): toques, primer toque, posesión, robo, botones con carga, patada con contacto sincronizado | `BallHandler.update`, `BallHandler._try_dribble_touch`, `BallHandler._try_first_touch`, `BallHandler.request_kick`, `BallHandler.attempt_tackle` | `Ball`, `PassAssist`, `ShotAssist`, `KickModel` |
| `scripts/player/player_tuning.gd` | Recurso `PlayerTuning`: todos los parámetros de locomoción y conducción | ver «Mapa de parámetros» | — |
| `scenes/player/footballer.tscn` | Nodo raíz `Footballer` (`CharacterBody3D`) con el script; el resto se crea en `_ready` | nodo `Footballer` | `scripts/player/footballer.gd` |
| `scripts/player/human_input.gd` | `InputSource` que lee `InputMap` (ver [INPUTS](INPUTS.md)) | `HumanInput.poll` | — |

**No modificar para cambiar la sensación de movimiento:** `ball_handler.gd` (la pelota no depende de cómo se acelera) ni `scripts/ui/touch_controls.gd`. **No modificar para cambiar la conducción:** `locomotion.gd`.

## Mapa de parámetros

<!-- AUTO:params:PlayerTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `walk_speed` | `1.8` | float | `scripts/player/player_tuning.gd:7` | `scripts/player/ball_handler.gd:1162`, `scripts/player/ball_handler.gd:1284`, `scripts/player/ball_handler.gd:1325`, `scripts/player/locomotion.gd:120` (+1) |  (Velocidades (m/s)) |
| `jog_speed` | `3.6` | float | `scripts/player/player_tuning.gd:8` | `scripts/player/ball_handler.gd:248`, `scripts/player/ball_handler.gd:971`, `scripts/player/ball_handler.gd:972`, `scripts/player/ball_handler.gd:974` (+6) |  (Velocidades (m/s)) |
| `run_speed` | `5.2` | float | `scripts/player/player_tuning.gd:9` | `scripts/player/locomotion.gd:57`, `scripts/player/locomotion.gd:172` |  (Velocidades (m/s)) |
| `sprint_speed` | `6.8` | float | `scripts/player/player_tuning.gd:10` | `scripts/player/ball_handler.gd:248`, `scripts/player/ball_handler.gd:974`, `scripts/player/locomotion.gd:60` |  (Velocidades (m/s)) |
| `backpedal_factor` | `0.72` | float | `scripts/player/player_tuning.gd:11` | **sin uso** |  (Velocidades (m/s)) |
| `accel` | `6.2` | float | `scripts/player/player_tuning.gd:15` | `scripts/player/ball_handler.gd:1285`, `scripts/player/locomotion.gd:139`, `scripts/player/locomotion.gd:176` | Aceleracion al empujar el joystick (m/s^2). (Aceleracion) |
| `decel` | `9.5` | float | `scripts/player/player_tuning.gd:17` | `scripts/player/ball_handler.gd:1163`, `scripts/player/ball_handler.gd:1165`, `scripts/player/locomotion.gd:131`, `scripts/player/locomotion.gd:134` (+2) | Desaceleracion al soltar el joystick. (Aceleracion) |
| `brake` | `14.0` | float | `scripts/player/player_tuning.gd:19` | `scripts/player/ball_handler.gd:1231`, `scripts/player/locomotion.gd:133`, `scripts/player/locomotion.gd:144` | Desaceleracion cuando el joystick apunta contra el movimiento (frenada). (Aceleracion) |
| `lateral_grip` | `9.0` | float | `scripts/player/player_tuning.gd:21` | `scripts/player/locomotion.gd:148` | Agarre lateral: cuanto rapido se elimina la velocidad lateral respecto al cuerpo (1/s). (Aceleracion) |
| `turn_rate_standing` | `620.0` | float | `scripts/player/player_tuning.gd:25` | `scripts/player/ball_handler.gd:466`, `scripts/player/locomotion.gd:106`, `scripts/player/locomotion.gd:167` | Velocidad de giro parado (grados/s). (Giro) |
| `turn_rate_sprint` | `165.0` | float | `scripts/player/player_tuning.gd:27` | `scripts/player/ball_handler.gd:466`, `scripts/player/locomotion.gd:106` | Velocidad de giro a sprint maximo (grados/s). (Giro) |
| `sharp_turn_angle_deg` | `115.0` | float | `scripts/player/player_tuning.gd:29` | `scripts/player/locomotion.gd:112` | Si el angulo al objetivo supera esto a mas de 70 % de la velocidad maxima, hay que frenar antes de girar. (Giro) |
| `stamina_drain_sprint` | `0.16` | float | `scripts/player/player_tuning.gd:32` | `scripts/player/locomotion.gd:81` |  (Resistencia) |
| `stamina_regen` | `0.07` | float | `scripts/player/player_tuning.gd:33` | `scripts/player/locomotion.gd:85`, `scripts/player/locomotion.gd:164` |  (Resistencia) |
| `stamina_regen_standing` | `0.14` | float | `scripts/player/player_tuning.gd:34` | `scripts/player/locomotion.gd:85`, `scripts/player/locomotion.gd:164` |  (Resistencia) |
| `exhausted_speed_factor` | `0.82` | float | `scripts/player/player_tuning.gd:36` | `scripts/player/locomotion.gd:62` | Fraccion de velocidad de sprint que aun se mantiene con la resistencia agotada. (Resistencia) |
| `touch_reach` | `0.95` | float | `scripts/player/player_tuning.gd:40` | `scripts/ai/ai_input.gd:130`, `scripts/player/ball_handler.gd:244`, `scripts/player/ball_handler.gd:387`, `scripts/player/ball_handler.gd:744` (+1) | Distancia maxima (m) a la que puede dar un toque. (Conduccion) |
| `touch_interval_jog` | `0.28` | float | `scripts/player/player_tuning.gd:42` | `scripts/player/ball_handler.gd:984` | Segundos entre toques (trote). (Conduccion) |
| `touch_interval_sprint` | `0.38` | float | `scripts/player/player_tuning.gd:44` | `scripts/player/ball_handler.gd:984` | Segundos entre toques (sprint, toques mas largos y espaciados). (Conduccion) |
| `carry_gap_stand` | `0.38` | float | `scripts/player/player_tuning.gd:46` | `scripts/player/ball_handler.gd:972`, `scripts/player/ball_handler.gd:1174`, `scripts/player/ball_handler.gd:1181`, `scripts/player/ball_handler.gd:1207` | Distancia objetivo (m) de la pelota al pie PARADO: es la que define el control cercano. (Conduccion) |
| `touch_lead_jog` | `0.70` | float | `scripts/player/player_tuning.gd:48` | `scripts/player/ball_handler.gd:972`, `scripts/player/ball_handler.gd:974` | Distancia objetivo (m) a la que se coloca la pelota delante del jugador al trotar / sprintar. (Conduccion) |
| `touch_lead_sprint` | `1.20` | float | `scripts/player/player_tuning.gd:49` | `scripts/player/ball_handler.gd:974` |  (Conduccion) |
| `settle_gap` | `0.38` | float | `scripts/player/player_tuning.gd:51` | `scripts/player/ball_handler.gd:1158`, `scripts/player/ball_handler.gd:1299`, `scripts/player/ball_handler.gd:1364`, `scripts/player/ball_handler.gd:1366` | Distancia (m) a la que queda la pelota al parar (soltar el joystick): pisada / parada. (Conduccion) |
| `lateral_hold_seconds` | `0.40` | float | `scripts/player/player_tuning.gd:53` | `scripts/player/ball_handler.gd:1336`, `scripts/player/ball_handler.gd:1337` | Segundos que el cuerpo conserva su orientacion tras un control lateral. (Conduccion) |
| `lateral_max_stick` | `0.5` | float | `scripts/player/player_tuning.gd:56` | `scripts/player/ball_handler.gd:1333` | Intensidad maxima del joystick para que un empuje de costado sea control lateral (mas fuerte = giro normal). 0.5: en el movil el joystick rara vez va a fondo y con 0.75 el jugador se desplazaba de lado en vez de girar. (Conduccion) |
| `shield_radius` | `2.6` | float | `scripts/player/player_tuning.gd:58` | `scripts/player/ball_handler.gd:1291`, `scripts/player/ball_handler.gd:1326` | Radio (m) dentro del cual un rival hace que el portador proteja la pelota con el cuerpo. (Conduccion) |
| `touch_overshoot_sprint` | `0.82` | float | `scripts/player/player_tuning.gd:60` | `scripts/player/ball_handler.gd:1198` | Desviacion tipica (m) de los toques largos a sprint con control 0 (disminuye con la habilidad). (Conduccion) |
| `touch_escape_factor` | `1.05` | float | `scripts/player/player_tuning.gd:62` | `scripts/player/ball_handler.gd:1098` | Toque de recuperacion: se adelanta cuando la pelota va a quedar a mas de este multiplo del alcance en 0.14 s. (Conduccion) |
| `touch_error_deg` | `4.0` | float | `scripts/player/player_tuning.gd:64` | `scripts/player/ball_handler.gd:1257` | Error angular base de un toque (grados) con control de balon 50. (Conduccion) |
| `touch_error_max_deg` | `8.0` | float | `scripts/player/player_tuning.gd:66` | `scripts/player/ball_handler.gd:1264` | Tope (grados) del error angular de un toque aunque se sumen sprint y giro. (Conduccion) |
| `touch_error_sprint` | `2.0` | float | `scripts/player/player_tuning.gd:68` | `scripts/player/ball_handler.gd:1258` | Error extra por sprint (multiplicador) y por giro brusco. (Conduccion) |
| `touch_error_turn` | `1.9` | float | `scripts/player/player_tuning.gd:69` | `scripts/player/ball_handler.gd:1259` |  (Conduccion) |
| `kick_lockout` | `0.35` | float | `scripts/player/player_tuning.gd:71` | `scripts/player/ball_handler.gd:833` | Segundos de bloqueo despues de un pase/tiro antes de poder volver a tocar la pelota. (Conduccion) |
| `possession_radius` | `1.1` | float | `scripts/player/player_tuning.gd:72` | `scripts/ai/ai_input.gd:589`, `scripts/assistance/press_controller.gd:44`, `scripts/assistance/press_controller.gd:49`, `scripts/assistance/press_controller.gd:51` (+3) |  (Conduccion) |
| `kick_contact_radius` | `0.30` | float | `scripts/player/player_tuning.gd:76` | `scripts/player/ball_handler.gd:724` | Radio (m) entre el pie (posicion de contacto medida del clip) y el centro de la pelota para que el golpeo cuente. (Patada con animacion del pack) |
| `kick_foot_max_height` | `0.25` | float | `scripts/player/player_tuning.gd:79` | `scripts/player/ball_handler.gd:580` | Altura maxima (m) de la punta del pie y velocidad minima de avance (m/s) para que un punto de la trayectoria del clip cuente como golpeo: el pie debe ir bajo y lanzado, no subiendo ni frenando. (Patada con animacion del pack) |
| `kick_foot_min_speed` | `3.0` | float | `scripts/player/player_tuning.gd:80` | `scripts/player/ball_handler.gd:580` |  (Patada con animacion del pack) |
| `kick_adjust_max` | `0.30` | float | `scripts/player/player_tuning.gd:83` | `scripts/player/ball_handler.gd:600`, `scripts/player/ball_handler.gd:650` | Ajuste de zancada: desplazamiento maximo (m) del cuerpo hacia la pelota durante la latencia para que el pie llegue. Crece con la velocidad (a sprint la zancada es larga): kick_adjust_max + kick_adjust_sprint * ratio de sprint. (Patada con animacion del pack) |
| `kick_adjust_sprint` | `0.28` | float | `scripts/player/player_tuning.gd:84` | `scripts/player/ball_handler.gd:600`, `scripts/player/ball_handler.gd:650` |  (Patada con animacion del pack) |
| `kick_start_residual` | `0.18` | float | `scripts/player/player_tuning.gd:86` | `scripts/player/ball_handler.gd:637`, `scripts/player/ball_handler.gd:669` | Error maximo (m) que se acepta al INICIAR el balanceo, medido tras el ajuste con la pelota y el jugador predichos al contacto. (Patada con animacion del pack) |
| `kick_latency` | `0.20` | float | `scripts/player/player_tuning.gd:88` | `scripts/player/ball_handler.gd:444` | Latencia objetivo (s) entre soltar el boton y el golpeo; el clip se acelera/recorta para llegar a ella. (Patada con animacion del pack) |
| `kick_clip_speed_max` | `1.6` | float | `scripts/player/player_tuning.gd:90` | `scripts/player/ball_handler.gd:446` | Aceleracion maxima del clip de patada (1 = velocidad original del clip). (Patada con animacion del pack) |
| `kick_turn_scale` | `0.35` | float | `scripts/player/player_tuning.gd:92` | `scripts/player/ball_handler.gd:463`, `scripts/player/ball_handler.gd:467`, `scripts/player/ball_handler.gd:687` | Fraccion de la velocidad de giro que se conserva mientras el pie se prepara (el pie de apoyo fija la direccion). (Patada con animacion del pack) |
| `kick_follow_through` | `0.30` | float | `scripts/player/player_tuning.gd:94` | `scripts/player/ball_handler.gd:692` | Segundos de continuacion del clip tras el golpeo antes de devolver el cuerpo a la marcha. (Patada con animacion del pack) |
| `first_touch_absorb` | `0.65` | float | `scripts/player/player_tuning.gd:98` | `scripts/player/ball_handler.gd:1457` | Fraccion de energia que absorbe el control orientado (0 = rebote total). (Contacto con balon) |
| `body_mass` | `75.0` | float | `scripts/player/player_tuning.gd:99` | **sin uso** |  (Contacto con balon) |
| `capsule_radius` | `0.3` | float | `scripts/player/player_tuning.gd:100` | `scripts/player/ball_handler.gd:1037`, `scripts/player/footballer.gd:81` |  (Contacto con balon) |
| `capsule_height` | `1.75` | float | `scripts/player/player_tuning.gd:101` | `scripts/player/ball_handler.gd:1037`, `scripts/player/footballer.gd:82`, `scripts/player/footballer.gd:84` |  (Contacto con balon) |
<!-- /AUTO -->

### Riesgos al modificar (con las pruebas que los vigilan)

| Parámetro(s) | Efecto real y riesgo |
|---|---|
| `walk_speed`, `jog_speed`, `run_speed`, `sprint_speed` | `Locomotion.speed_for_magnitude` / `max_sprint_speed`. La animación acompaña hasta `FootballerVisual.MAX_TIME_SCALE (2.9) × NATURAL_SPEED["run"] (2.5) = 7.25 m/s`: **por encima de ~7.2 m/s los pies patinan** (la cadencia se satura). El `BlendSpace` de locomoción llega hasta 7.5. Los atributos escalan la velocidad con `PlayerAttributes.factor("speed", 0.12)`. |
| `accel`, `decel`, `brake` | `test_acceleration_is_progressive` (v(0.2 s) < 50 % de la velocidad de carrera; 90 % entre 0.9 y 2.2 s; medido 1.05 s) y `test_stops_without_sliding_like_ice` (frena en < 0.9 s y < 2 m; medido 0.55 s / 1.38 m). |
| `turn_rate_standing`, `turn_rate_sprint`, `sharp_turn_angle_deg` | `test_turning_rate_depends_on_speed` (giro de 90° parado entre 0.08 y 0.30 s; a sprint ≥ 0.25 s y > 1.5× el parado; medidos 0.15 s / 0.30 s) y `test_reversal_at_sprint_brakes_first_and_never_slides_sideways`. |
| `lateral_grip` | Es el «anti-hielo»: elimina la velocidad lateral respecto al cuerpo. Valores bajos = deslizamiento; la prueba exige desplazamiento lateral < 2.0 m al invertir a sprint (medido 0.67 m). |
| `touch_reach`, `touch_interval_*`, `touch_lead_*`, `touch_overshoot_sprint`, `touch_error_*` | Conducción: `test_dribble_at_jog_keeps_ball_close_with_physical_touches` (pelota < 2 m el 85 % del tiempo y 8–40 toques en 6 s; medido 100 % y 21 toques), `test_sprint_dribble_is_less_precise_than_jog`, `test_better_ball_carrying_means_tighter_control`, `test_turning_with_ball_changes_ball_direction_physically`. Subir `touch_lead_*` o `touch_overshoot_sprint` alarga los toques y pierde la pelota más seguido. |
| `possession_radius` | Define «tiene la pelota»: lo usan `BallHandler.has_possession`, el primer toque y `PressController._find_carrier`. Cambiarlo altera cuándo se activa la presión y el robo. |
| `kick_lockout` | Bloqueo de toques tras un pase/tiro (`BallHandler._after_kick`). Muy bajo: el jugador vuelve a empujar la pelota recién pateada. |
| `first_touch_absorb` | Fracción de energía absorbida en el control (`BallHandler._try_first_touch`, escalada por `ball_control`). |
| `capsule_radius`, `capsule_height` | Tamaño de la cápsula física (`Footballer._ready`). **No** escalan el modelo (que usa `FootballerVisual.MODEL_HEIGHT_SCALE = 1.75`): si se cambia uno, cambiar el otro a mano. |
| `stamina_*`, `exhausted_speed_factor` | Resistencia en `Locomotion.step` (el sprint la consume; agotado, la velocidad máxima cae). `test_sprint_is_faster_and_drains_stamina`. |
| `backpedal_factor`, `body_mass` | **Sin uso**: definidos pero ningún código los lee. |

### Valores fijos en el código de este sistema

Ver la tabla «Valores fijos» de [ARCHITECTURE.md](../ARCHITECTURE.md) (carga del pase 0.8 s, retardo de contacto, buffer 0.3 s, márgenes de alcance, bloqueo +0.4 s, pérdida 0.9 al patear, tope conduciendo 0.86–0.97).

## Mapa de funciones

<!-- AUTO:funcs:scripts/player/footballer.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Footballer._ready()` | 69 |  |
| `Footballer.setup(context: MatchContext, team_index: int, id: int, attrs: PlayerAttributes, source: InputSource)` | 100 | Configura el jugador dentro de un partido. |
| `Footballer.expect_pass(point: Vector3, kind: StringName, from: Node = null)` | 118 | Un companero (`from`) acaba de pasarle la pelota: guarda el punto de llegada para ir a buscarla. |
| `Footballer.has_incoming_pass()` | 125 | true mientras hay un pase en camino hacia este jugador (y la pelota no la tiene nadie todavia). |
| `Footballer.pass_meet_point()` | 130 | Punto donde salir a buscar el pase que viene: el primero de la trayectoria PREDICHA de la pelota al que el jugador llega antes que ella (a r |
| `Footballer.set_attributes(attrs: PlayerAttributes)` | 146 |  |
| `Footballer._exit_tree()` | 151 |  |
| `Footballer.set_ball_ghost(on: bool)` | 159 | Durante un golpeo en el aire (cabezazo, volea) la pelota atraviesa el cuerpo hasta el contacto del clip: si no, rebota contra la capsula ant |
| `Footballer.has_ball()` | 162 |  |
| `Footballer.reset_motion()` | 165 |  |
| `Footballer.place_at(pos: Vector3, yaw: float)` | 174 |  |
| `Footballer._physics_process(delta: float)` | 187 |  |
| `Footballer._keep_inside(dir: Vector3)` | 362 | Quita la componente que saca al jugador mas alla de las lineas (con medio metro de margen). |
| `Footballer._ai_commits_tackle(carrier: Footballer)` | 375 | La IA no disputa en cada ocasion: contiene (jockey) y entra cuando la pelota queda expuesta (toque largo del portador, pelota suelta) o, con |
| `Footballer._gait_overlays(desired_dir: Vector3, want_sprint: bool, stick_mag: float, speed_before: float, delta: float)` | 382 |  |
| `Footballer._cancel_reaction()` | 417 |  |
| `Footballer._on_match_event(e: GameEvent)` | 427 | Reacciones de presentacion a eventos del partido: - Gol: el goleador, el asistente, el resto del equipo y el rival reaccionan distinto (un a |
| `Footballer._try_block_jump(e: GameEvent)` | 463 |  |
| `Footballer.rng_delay()` | 478 |  |
| `Footballer._set_reaction(situation: StringName, wait: float, cut: float)` | 481 |  |
| `Footballer._update_reaction(delta: float)` | 488 | La reaccion a un gol arranca cuando el jugador casi se ha detenido (o tras REACTION_MAX_WAIT) para no animar un clip en el sitio sobre un cu |
| `Footballer._check_player_collisions()` | 502 | Un choque a velocidad con otro jugador provoca un tropiezo (presentacion) o, si es fuerte, un golpe de hombro y caida. |
| `Footballer.capture_state()` | 524 | Datos replicables del jugador (para snapshots de red / pruebas). |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/player/locomotion.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Locomotion._init(t: PlayerTuning = null, a: PlayerAttributes = null)` | 38 |  |
| `Locomotion.dir_from_yaw(y: float)` | 43 | Vector de direccion (unitario) para un yaw. yaw = 0 mira hacia -Z. |
| `Locomotion.yaw_from_dir(d: Vector3)` | 46 |  |
| `Locomotion.forward()` | 49 |  |
| `Locomotion.right()` | 52 |  |
| `Locomotion.max_run_speed()` | 56 |  |
| `Locomotion.max_sprint_speed()` | 59 |  |
| `Locomotion.step(desired_dir: Vector3, magnitude: float, want_sprint: bool, delta: float, speed_cap: float = -1.0)` | 68 | Avanza un paso de simulacion. desired_dir: direccion deseada en el mundo (unitaria o cero). magnitude: 0..1 (intensidad del joystick). speed |
| `Locomotion._step_jockey(desired_dir: Vector3, magnitude: float, delta: float, speed_cap: float)` | 157 |  |
| `Locomotion.speed_for_magnitude(m: float)` | 184 | Velocidad objetivo (m/s) para una intensidad de joystick 0..1 (sin sprint). |
| `Locomotion.turn_rate_blocks_speed(angle_diff: float)` | 194 |  |
| `Locomotion.face_towards(dir: Vector3, delta: float, rate_deg: float = 540.0)` | 198 | Orienta el cuerpo sin moverlo (por ejemplo, al encarar la pelota estando parado). |
| `Locomotion.stop()` | 205 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/player/ball_handler.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `BallHandler._init(o: Footballer)` | 139 |  |
| `BallHandler.ball()` | 143 |  |
| `BallHandler.ball_offset()` | 146 |  |
| `BallHandler.ball_distance()` | 150 |  |
| `BallHandler.possession_radius()` | 155 | Radio (m) dentro del cual se considera que el jugador lleva la pelota. Crece con la velocidad: a sprint la pelota va mas adelantada y seguir |
| `BallHandler.has_possession()` | 158 |  |
| `BallHandler.is_dribbling()` | 174 | Conduce aunque el ultimo toque largo la haya alejado un poco: fue el ultimo en tocarla, no la pateo (pase/tiro) y sigue cerca. Sirve para no |
| `BallHandler.seconds_since_kick()` | 182 | Segundos de simulacion desde el ultimo pase o tiro de este jugador. |
| `BallHandler.incoming_ball_eta(radius: float = 2.5)` | 187 | Segundos hasta que una pelota que se ACERCA pase a menos de radius del jugador (INF si no viene hacia el, va alta o es de otro). Prediccion  |
| `BallHandler.incoming_ball_point()` | 202 | Punto (en el suelo) de la trayectoria de la pelota que viene mas cercano al jugador: donde preparar el golpeo de primera. |
| `BallHandler.is_waiting_first_time()` | 211 | Hay una orden de pase/tiro esperando una pelota que llega (golpeo de primera, sin control previo). |
| `BallHandler.ball_owned_by_other()` | 217 | La pelota es de otro jugador (la conduce o la acaba de controlar): no se la puede conducir ni controlar, solo disputar. Un companero que la  |
| `BallHandler.controls_ball()` | 233 | El equipo del jugador controla la pelota: esta cerca Y fue tocada por ultima vez por su equipo. Una pelota suelta o ultimo tocada por el riv |
| `BallHandler.can_reach(reach: float)` | 237 |  |
| `BallHandler.touch_reach()` | 242 | Alcance efectivo de un toque: el jugador estira mas la pierna a mayor velocidad. |
| `BallHandler._sprint_ratio()` | 246 |  |
| `BallHandler.assist_pass_level()` | 250 |  |
| `BallHandler.assist_shot_level()` | 253 |  |
| `BallHandler.update(frame: InputFrame, stick_world: Vector3, stick_mag: float, desired_dir: Vector3, dt: float)` | 257 | Paso de simulacion. stick_world: direccion del joystick en el mundo; desired_dir: direccion deseada final. |
| `BallHandler._update_buttons(frame: InputFrame, stick_world: Vector3, dt: float)` | 302 |  |
| `BallHandler.curl_from(at_press: Vector3, at_release: Vector3)` | 358 | Efecto pedido con el joystick: angulo (con signo) entre la direccion al pulsar y al soltar. Un giro de 15-60 grados a la derecha del tiro cu |
| `BallHandler._queue(action: StringName, charge: float, lob: bool, stick_world: Vector3, curl: float = 0.0)` | 367 |  |
| `BallHandler._try_execute_pending()` | 375 |  |
| `BallHandler.contact_delay(action: StringName, charge: float)` | 396 | Segundos entre el inicio de la patada y el golpeo (la animacion y el impulso comparten este instante). |
| `BallHandler.request_kick(action: StringName, stick_world: Vector3, charge: float, lob: bool)` | 400 | Comienza una patada: arranca la animacion y programa el impulso para el instante de contacto. |
| `BallHandler.is_kick_in_progress()` | 417 |  |
| `BallHandler.uses_clip_kicks()` | 423 | true si este futbolista patea con los clips del pack (visual con libreria y clips de patada en el sitio). |
| `BallHandler.foot_contact_world(contact: Dictionary, pos: Vector3, yaw: float)` | 429 | Posicion MUNDIAL de la punta del pie en el golpeo de un clip, para un jugador en pos con orientacion yaw. contact.pos es (adelante, arriba,  |
| `BallHandler.clip_timing(contact_time: float, action: StringName, charge: float)` | 441 | Velocidad de reproduccion, punto de inicio y latencia real para que el clip llegue a su contacto en kick_latency. La latencia se cuantiza a  |
| `BallHandler._predicted_yaw(latency: float)` | 459 | Vector (pelota - pie) en el plano, en metros, al instante de contacto del clip, PREDICHO desde el estado actual (jugador y pelota siguen su  |
| `BallHandler.abort_kick()` | 471 | Aborta una patada en curso y la accion pendiente (caida, barrida): no se aplica ningun impulso. |
| `BallHandler.cancel_charge()` | 482 | Cancela la carga de pase/tiro en curso sin ejecutar nada (la IA lo usa cuando la pelota se le fue). |
| `BallHandler.clip_plant_velocity(clip: StringName, contact_time: float, foot: int, playback: float)` | 495 | Velocidad (adelante, derecha) en m/s del cuerpo que deja QUIETO el pie de apoyo de un clip en el sitio en los KICK_PLANT_TIME previos al con |
| `BallHandler.plant_velocity(contact: Dictionary, yaw: float, v: Vector3)` | 513 | Velocidad del cuerpo (mundo) con el pie de apoyo plantado para un contacto, con orientacion yaw y velocidad previa v. La velocidad del clip  |
| `BallHandler.kick_body_travel(v: Vector3, latency: float, plant_v: Vector3)` | 523 | Recorrido del cuerpo en las proximas latency s de una patada que empieza (o sigue) con velocidad v: a velocidad constante hasta plantar el p |
| `BallHandler.kick_nudge_cap(v: Vector3)` | 528 | Ajuste de paso maximo (m/s) a la velocidad de cuerpo v. |
| `BallHandler.kick_adjust_capacity(v: Vector3, latency: float)` | 532 | Metros de ajuste de paso que caben antes de plantar el pie en una patada de latencia `latency`. |
| `BallHandler.is_clip_kick_in_progress()` | 536 | true durante una patada con clip (balanceo hasta el contacto). |
| `BallHandler.kick_body_velocity()` | 540 | Velocidad del cuerpo durante una patada con clip: la de partida, frenada con el pie de apoyo plantado. |
| `BallHandler._steer_clip_kick()` | 547 | Ajuste de paso en lazo cerrado: cada fotograma se vuelve a predecir donde estara el pie en el contacto y se corrige lo que falta con el cuer |
| `BallHandler.predicted_foot_to_ball(contact: Dictionary, latency: float, body_v: Variant = null)` | 559 |  |
| `BallHandler.contact_samples(contact: Dictionary)` | 571 | Puntos validos de golpeo de un clip: muestras de la trayectoria del pie (adelante, arriba, derecha) con la punta baja y lanzada hacia adelan |
| `BallHandler.plan_aerial_kick(action: StringName, charge: float)` | 594 | Planifica un golpeo con la pelota en el aire: busca, entre los clips de cabezazo y volea, el instante en que la cabeza o la punta del pie (c |
| `BallHandler.plan_clip_kick(action: StringName, charge: float, lob: bool)` | 643 | Elige el mejor clip, pierna E INSTANTE DE CONTACTO para la accion. El instante sale de la trayectoria real del pie del clip (contact_samples |
| `BallHandler._start_clip_kick(action: StringName, plan: Dictionary, stick_world: Vector3, charge: float, lob: bool)` | 671 |  |
| `BallHandler._log_kick(action: StringName, result: StringName, extra: Dictionary = {})` | 695 |  |
| `BallHandler._finish_clip_kick()` | 704 | Resuelve el golpeo de una patada con clip: valido solo si la pelota esta a kick_contact_radius del pie REAL (posicion de contacto del clip,  |
| `BallHandler._finish_kick()` | 737 |  |
| `BallHandler.perform_action(action: StringName, stick_world: Vector3, charge: float, lob: bool)` | 752 | Ejecuta el golpeo de una accion (pase, filtrado, centro o tiro) en el instante de contacto. |
| `BallHandler.perform_through(stick_world: Vector3, charge: float, lob: bool)` | 767 | Pase filtrado: al espacio por delante del desmarque del receptor. |
| `BallHandler.perform_cross(stick_world: Vector3, charge: float, low: bool)` | 780 | Centro al area: con ALTO sale raso; con carga alta, tenso; si no, elevado. |
| `BallHandler.perform_pass(stick_world: Vector3, charge: float, lob: bool)` | 794 | Ejecuta un pase ahora mismo (la pelota debe estar a alcance). Devuelve el resultado. |
| `BallHandler.perform_shot(stick_world: Vector3, charge: float, lob: bool)` | 810 |  |
| `BallHandler._after_kick(action: StringName, res: KickModel.KickResult)` | 827 |  |
| `BallHandler.get_dt()` | 871 |  |
| `BallHandler._sample_feet(dt: float)` | 876 | Lee las puntas de los pies del esqueleto animado. Si no se mueven (headless, maniqui) feet_live queda en false y la conduccion usa la cadenc |
| `BallHandler.foot_distance(i: int, ball_pos: Vector3)` | 916 | Distancia (m) del centro de la pelota al pie i (segmento del tobillo a la punta). |
| `BallHandler._foot_strike(b: Ball, mode: StringName, close_in: bool = false)` | 928 | Pie (0 izquierdo, 1 derecho) que puede tocar la pelota ahora: punta baja, a FOOT_CONTACT de la pelota, por detras de ella y yendo hacia dela |
| `BallHandler.carry_gap(speed: float, skill: float)` | 968 |  Modelo de control cercano. Una sola ley define la sensacion: la pelota se coloca a `carry_gap()` metros del pie, y esa distancia crece con  |
| `BallHandler._carry_skill()` | 977 |  |
| `BallHandler._touch_interval(ratio: float)` | 982 | Segundos entre toques. Con el pack, la cadencia sigue a la de los pasos de la animacion (uno por apoyo a trote, uno cada dos apoyos a carrer |
| `BallHandler.nearest_opponent(radius: float)` | 996 | Rival mas cercano a este jugador dentro de `radius` (o null). Lo usan la proteccion y el calculo de presion. |
| `BallHandler._touch_mode(desired_dir: Vector3, stick_mag: float, turn_angle: float)` | 1012 | Modo del proximo toque segun la intencion del joystick y el estado del cuerpo. |
| `BallHandler._shrug_resting_ball()` | 1030 | Pelota quieta apoyada sobre el cuerpo (encajada entre las cabezas u hombros de dos jugadores pegados): nadie puede tocarla con el pie y el p |
| `BallHandler.force_dribble_touch(dir: Vector3)` | 1052 | Un toque de conduccion en la direccion dada (lo usa una accion con raiz, que no pasa por update()). |
| `BallHandler._try_dribble_touch(desired_dir: Vector3, stick_mag: float)` | 1055 |  |
| `BallHandler._carry_speed_after_turn(stick_mag: float, turn_angle: float)` | 1279 | Velocidad a la que el jugador podra llevar la pelota tras el giro (en un giro cerrado el cuerpo frena antes de acelerar hacia el rumbo nuevo |
| `BallHandler._shield_dir(dist: float)` | 1290 | Direccion en la que conviene colocar la pelota al pararla: lejos del rival mas cercano (proteccion). Cero si no hay rival a quien proteger l |
| `BallHandler.plan_carry(desired_dir: Vector3, stick_mag: float, dt: float)` | 1310 | Decide, ANTES de que el cuerpo gire, hacia donde mira el jugador mientras lleva la pelota. Lo llama el futbolista al principio del paso de f |
| `BallHandler.settle_steer()` | 1346 | Frenar con la pelota: con el joystick suelto, si la pelota propia sigue rodando lejos del pie, el jugador la acompana hasta tenerla al alcan |
| `BallHandler.carry_turn_scale(desired_dir: Vector3)` | 1374 | Escala del giro del cuerpo mientras conduce. Con la pelota al alcance pero NO hacia el rumbo pedido (un cambio de direccion grande), el cuer |
| `BallHandler.carry_steer(desired_dir: Vector3)` | 1395 | Recuperar la pelota propia que se queda atras o al costado en un giro: en vez de correr hacia donde apunta el joystick dejando la pelota (fa |
| `BallHandler.carry_face()` | 1419 | Direccion a la que debe mirar el cuerpo mientras conduce (control lateral o proteccion). Cero = libre. |
| `BallHandler._try_first_touch(desired_dir: Vector3)` | 1425 |  |
| `BallHandler.attempt_tackle(carrier: Footballer)` | 1485 | Intenta quitar la pelota. No esta garantizado: depende de distancia, orientacion, equilibrio, velocidad relativa y atributos de ambos jugado |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/player/ball_handler.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `BallHandler.kicked(action: StringName, result: KickModel.KickResult)` | 11 | Interaccion del futbolista con la pelota. Todo ocurre mediante IMPULSOS en el instante del contacto: nunca se fija la posicion de la pelota ni se anula su velocidad. - Conduccion: toques periodicos cuya fuerza depende de la velocidad, el giro y los atributos. - Control de primer toque: absorbe parte de la energia de un balon que llega (con error). - Pase y tiro: se calculan con PassAssist / ShotAssist; se ejecutan al soltar el boton y se guardan en buffer 0.3 s si la pelota aun no esta a alcance. - Disputa: robo probabilistico dependiente de orientacion, atributos y velocidad relativa. |
| `BallHandler.touched_ball(kind: StringName)` | 12 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/player/footballer.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Footballer.kicked(action: StringName, result: KickModel.KickResult)` | 8 | Futbolista de campo. Orquesta: entrada (InputFrame) -> intencion -> locomocion -> contacto con la pelota. No importa si lo controla una persona, la IA o la red: todos pasan por InputFrame.  Estado replicable separado de la presentacion: la presentacion es FootballerVisual (hijo "Visual"). |
| `Footballer.tackled(won: bool)` | 9 |  |
<!-- /AUTO -->

## Recorrido de ejecución

**Cada paso de física** (`Footballer._physics_process`):
1. `InputSource.poll` → `InputFrame` (si `MatchContext.input_enabled` es falso, un `InputFrame` vacío).
2. `MatchContext.screen_to_world(frame.move)` → dirección deseada en el mundo (relativa a la cámara).
3. Si `press_held` y el equipo no controla el balón: `PressController.update` sustituye la dirección/intensidad (la presión intenta robar con `BallHandler.attempt_tackle`).
4. Con la pelota cerca (`BallHandler.has_possession`) se limita la velocidad (`0.86–0.97 × max_sprint_speed` según `ball_carrying`).
5. `Locomotion.step`: velocidad objetivo por intensidad del joystick (`walk/jog/run`) o `sprint`; giro limitado por velocidad; si el giro es muy cerrado a alta velocidad el objetivo baja a `walk_speed` (frenar antes de girar); aceleración con `accel/decel/brake`; el agarre elimina la componente lateral.
6. `move_and_slide` (la colisión con paredes/jugadores corrige la velocidad real) → `rotation.y = locomotion.yaw`.
7. `BallHandler.update` en este orden: botones con carga (`_update_buttons`) → si hay patada en curso, avanzar su temporizador y, al llegar el contacto, `_finish_kick` → ejecutar acción pendiente en buffer (`_try_execute_pending` → `request_kick`) → si hay `lockout`, nada más → `_try_first_touch` → `_try_dribble_touch`.
8. `FootballerVisual.update_motion` (animación y lean).

**Conducción** (`BallHandler._try_dribble_touch`; corregida en la integración del pack, ver [ANIMATION_PACK](ANIMATION_PACK.md) «ANTES y DESPUÉS»: error del toque sobre la velocidad relativa al jugador, hueco planificado acotado al alcance del siguiente toque, umbral de re-toque según ese hueco y, con el pack, cadencia = apoyos de la animación): cuando el temporizador de toque expira y la pelota está al alcance (`touch_reach`·0.85, o más en giros/lateral), se calcula una posición objetivo delante del jugador (`touch_lead_jog`/`touch_lead_sprint`), la velocidad necesaria para colocarla allí y se aplica con `Ball.kick` (error angular y de módulo según sprint, giro y atributos). Nunca se fija la posición de la pelota.

**Patada** (pase/tiro). Dos caminos; elige `BallHandler.uses_clip_kicks()`:

- **Con el pack** (visual con `PackLibrary` y clips de patada en el sitio): al soltar el botón (o por buffer de 0.3 s) `_try_execute_pending` llama a `plan_clip_kick`, que para cada clip candidato (`AnimationCatalog.kick_candidates`: pase → `Soccer_Pass` / `strike_foward_jog_inplace`, ambos pies; tiro y pase alto → `strike_foward_jog_inplace`) recorre los puntos válidos de la **trayectoria medida de la punta del pie** (`contact_samples`: punta a ≤ `kick_foot_max_height`, avanzando ≥ `kick_foot_min_speed`), predice jugador y pelota hasta ese instante (`predicted_foot_to_ball`: velocidades y giro reducido por `kick_turn_scale`) y calcula cuánto debería moverse el cuerpo (ajuste de zancada ≤ `kick_adjust_max` + `kick_adjust_sprint`·ratio de sprint). Solo si el residuo queda ≤ `kick_start_residual` empieza la patada (`_start_clip_kick`): reproduce el clip acelerado (≤ ×`kick_clip_speed_max`) y desde el punto necesario para llegar al contacto en `kick_latency` s; mueve el cuerpo con `Footballer.nudge_velocity` (no entra en `Locomotion`) y baja el giro (`Locomotion.turn_scale`). **Si ningún pie llega, no hay patada**: tras el buffer se cuenta `kick_stats["out_of_reach"]` y se emite `KICK_WHIFF` con `reason = "out_of_reach"`. En el contacto `_finish_clip_kick` mide la distancia entre la pelota y el pie **real** (posición de contacto del clip con el jugador donde está ahora): ≤ `kick_contact_radius` → `perform_pass`/`perform_shot` (impulso con las asistencias, `PASS`/`SHOT` con `clip`, `foot_distance`, `latency`, `adjust_m`); si no, `KICK_WHIFF` con `reason = "missed"`, sin impulso ni teletransporte. Cada intento queda en `kick_log` y `kick_stats`.
- **Sin el pack** (o sin visual): el camino antiguo. `request_kick` fija `contact_delay` y arranca `ProceduralPose` con ese tiempo; en el contacto `_finish_kick`, si la pelota sigue a `touch_reach + 0.5`, `perform_pass`/`perform_shot`; si no, `KICK_WHIFF`.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh pack_kick` (contacto pie–pelota con clips; se omite sin la librería local), `tools/run_tests.sh pack_dribble` (métricas de conducción y ejecución de pase/tiro por régimen, ~15 s), `tools/run_tests.sh locomotion`, `tools/run_tests.sh dribbling`, `tools/run_tests.sh kick_timing`, `tools/run_tests.sh touch_controls` (extremo a extremo con joystick táctil). Todo: `tools/run_tests.sh`.
- **Última ejecución completa (2026-10-26):** headless con la librería local: 85 pruebas, 0 fallidas, 2 omitidas (necesitan render), 529 comprobaciones; con render (Xvfb): 85 pruebas, 0 fallidas, 553 comprobaciones; sin la librería local: 85 pruebas, 0 fallidas, 26 omitidas, 221 comprobaciones. `test_kick_timing` cubre solo el camino procedural (fuerza `prefer_pack = false`).

<!-- AUTO:tests:tests/test_locomotion.gd -->
| Prueba | Línea |
|---|---|
| `test_acceleration_is_progressive` | 15 |
| `test_sprint_is_faster_and_drains_stamina` | 35 |
| `test_stops_without_sliding_like_ice` | 46 |
| `test_turning_rate_depends_on_speed` | 61 |
| `test_reversal_at_sprint_brakes_first_and_never_slides_sideways` | 83 |
| `test_attributes_scale_speed_within_limits` | 107 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_dribbling.gd -->
| Prueba | Línea |
|---|---|
| `test_dribble_at_jog_keeps_ball_close_with_physical_touches` | 34 |
| `test_sprint_dribble_is_less_precise_than_jog` | 42 |
| `test_better_ball_carrying_means_tighter_control` | 50 |
| `test_no_touch_when_standing_still` | 56 |
| `test_turning_with_ball_changes_ball_direction_physically` | 64 |
| `test_player_collides_with_walls` | 80 |
| `test_ball_resting_on_two_players_is_shrugged_off` | 92 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_kick_timing.gd -->
| Prueba | Línea |
|---|---|
| `test_ball_impulse_happens_at_contact_not_at_button_release` | 9 |
| `test_kick_whiffs_if_the_ball_moves_away_during_the_swing` | 46 |
| `test_pose_curves_are_continuous_and_peak_at_contact` | 71 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_pack_kick.gd -->
| Prueba | Línea |
|---|---|
| `test_only_in_place_clips_are_connected_to_kicks` | 29 |
| `test_pass_contact_is_synchronised_with_the_foot_arrival` | 42 |
| `test_each_candidate_foot_hits_when_the_ball_is_on_it` | 85 |
| `test_ball_out_of_reach_gives_no_kick_and_no_teleport` | 109 |
| `test_ball_leaving_during_the_swing_is_a_real_whiff` | 128 |
| `test_reach_is_limited_by_the_leg_not_a_fixed_radius` | 151 |
| `test_stride_adjustment_reaches_a_ball_slightly_off_the_foot` | 183 |
| `test_contact_instant_comes_from_the_foot_trajectory` | 212 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_pack_dribble_metrics.gd -->
| Prueba | Línea |
|---|---|
| `test_dribble_distribution_at_jog_run_and_sprint` | 132 |
| `test_pass_and_shot_execution_rate_per_speed` | 154 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_pack_reactions.gd -->
| Prueba | Línea |
|---|---|
| `test_goal_makes_the_scoring_team_celebrate_and_the_other_one_mourn` | 22 |
| `test_own_goal_scorer_is_on_the_conceding_team` | 46 |
| `test_reaction_waits_for_a_running_player_to_slow_down` | 55 |
| `test_slow_first_touch_plays_receive_and_fast_one_does_not` | 75 |
| `test_kick_cancels_a_reaction_and_actions_never_overlap` | 106 |
| `test_tripo_fallback_for_goal_reactions_and_no_invented_receive` | 116 |
<!-- /AUTO -->

- **Qué podría romperse:** deslizamiento tipo hielo o giros instantáneos; pelota que se escapa al trotar; patada que se aplica antes/después del gesto; jugador atravesando paredes (`test_player_collides_with_walls`).

## Control cercano del balón: cómo se siente y por qué (medido)

La conducción es un modelo de **toques por impulso con una distancia objetivo que depende de la velocidad**
(`BallHandler.carry_gap`): parado la pelota queda pegada al pie y a sprint se empuja al espacio. No hay imán ni
posición forzada: cada toque es un `Ball.kick` calculado para que la pelota llegue a ese punto cuando el jugador
llegue allí.

| Modo de toque (`BallHandler.last_touch_mode`) | Cuándo | Qué hace |
|---|---|---|
| `settle` | joystick suelto | Para la pelota junto al pie. Frenando desde carrera la amortigua hasta donde el cuerpo va a detenerse; con un rival cerca la coloca del lado protegido y el cuerpo se interpone. |
| `lateral` | empuje de costado (55°–125°) a poca velocidad y joystick suave | Desplaza la pelota al lado **sin girar el cuerpo** durante `lateral_hold_seconds`; el jugador se mueve de lado con la mezcla direccional. Después gira normalmente. |
| `redirect` | cambio de rumbo > 55° | Lleva la pelota al rumbo nuevo y más pegada al pie cuanto más cerrado es el giro. |
| `setup` | hay un pase o tiro pulsado esperando | Acerca la pelota al pie (60 % de la distancia normal) para poder ejecutar sin frenar. |
| `carry` | conducción normal | Coloca la pelota a `carry_gap(velocidad)` delante, con el toque largo aleatorio del sprint. |

**Parámetros** (`PlayerTuning`): `carry_gap_stand` 0.38 m, `touch_lead_jog` 0.70 m, `touch_lead_sprint` 1.20 m,
`settle_gap` 0.38 m, `touch_escape_factor` (toque de recuperación si la pelota va a salirse en 0.14 s),
`touch_error_max_deg` (tope del error del toque), `lateral_hold_seconds`, `lateral_max_stick`, `shield_radius`.

**Medidas** (`tests/test_gameplay_feel.gd`, con la librería del pack):

| Situación | Resultado |
|---|---|
| Conducción lenta (joystick 0.25 / 0.40 / 0.55) | pelota a 0.58 / 0.61 / 0.65 m de media, máximo 0.69 m |
| Trote vs sprint | 0.65 m vs 1.27 m de media; máximo a sprint 1.56 m |
| Frenar desde trote / sprint | la pelota queda a 0.37 / 0.35 m y se detiene (0.00 m/s) |
| Giro sobre la pelota parado (90° / 180° / 270°) | 0.36 / 0.39 / 0.29 m |
| Control lateral | 0.70 m de desplazamiento lateral en 0.5 s con el cuerpo fijo, pelota a 0.33 m |
| Giros conduciendo (60/90/135/−90°), 20 intentos por ritmo | pierde la pelota: trote 0/20, carrera 1/20, sprint 0/20 |
| Pase pulsado conduciendo | parado 12/12, trote 12/12, carrera 12/12, sprint 12/12 |
| Recepción en carrera | la controla sin bajar de 1.26 m/s, pelota a 0.76 m |
| Acción cancelada (pelota retirada) | sin patada colgada, sin bloqueo, el jugador sigue respondiendo |

**Orientación del cuerpo al conducir** (`BallHandler.plan_carry`, lo llama `Footballer` antes de mover el cuerpo):
decide si el jugador conserva su orientación (control lateral) o da la espalda al rival (proteger la pelota). Usa el
mismo `Locomotion.face_override` que el marcaje en jockey, así que la animación direccional ya lo acompaña.

## Limitaciones conocidas

- Proteger la pelota parado no es indefinido: `BallHandler.attempt_tackle` reduce el escudo del portador cuando está quieto, y el defensor rodea el cuerpo para atacar la pelota por el lado libre (`PressController`). Medido: un portador inmóvil la conserva 5–17 s ante un presionador.
- La IA (`AIInput`) y el cambio de jugador existen (ver [MATCH](MATCH.md)); `PlayerActions` añade barrida, caídas, levantarse y regate (`skill_pressed`, tecla U / botón REGATE) con movimiento de raíz. Límite: la IA no se ha calibrado contra humanos.
- Las señales `Footballer.tackled`/`Footballer.kicked` y `BallHandler.touched_ball` se emiten sin ningún consumidor.
- `Footballer.display_name`, `shirt_number` y `is_human_controlled` no los usa ninguna lógica o interfaz todavía.
- **Patada con clip (medido, `test_pack_dribble_metrics`):** latencia 0.20 s frente a 0.10–0.18 s de la patada procedural; a sprint el pase/tiro se ejecuta el 88 % de las pulsaciones (el resto se descarta por no haber pie que llegue). El ajuste de zancada (media 0.26–0.47 m) mueve el cuerpo sin pasos animados y es sobre todo lateral: puede verse un deslizamiento leve (solo medido, no mirado en vídeo). `soccer_penalty_kick` y `Chip` no están conectados (llevan carrera de 2.5 / 4.4 m).
- **Cadencia de toques ≠ fase del paso:** con el pack el intervalo entre toques sigue a la frecuencia de apoyos de la animación, pero no se sincroniza con el pie que pisa.
- **Sin estado de caída/falta/salto:** `fall`, `getup`, `soccer_tackle`, `soccer_trip` y los saltos del catálogo no tienen disparador (no se inventó mecánica).
- El atributo `dribbling` (regate) no se usa; no hay amagues ni regates con ventanas de ejecución (solo toques de colocación).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Control asistido» (locomoción y conducción), «Esqueleto único v1.0» (patada sincronizada).

## Pies animados, entrada y transiciones (2026-10-27)

- **Conducción con el pie real:** `BallHandler._sample_feet` lee las puntas de los pies del esqueleto animado; con el esqueleto vivo (`feet_live`, nunca en headless) un toque solo ocurre si una punta baja está a `FOOT_CONTACT` (0.28 m) de la pelota y yendo hacia delante (`_foot_strike`), y la pelota se deja a `_foot_reach + FOOT_BALL_LEAD` (alcance real de la zancada). Si la pelota se escapa junto al cuerpo o el cuerpo la alcanza, se toca igual tras una espera corta. El primer toque espera a que la pelota llegue al pie o al cuerpo (~0.5 m). Medido con render en `test_live_feet`.
- **Entrada con botón** (`PlayerActions.tackle_request`): de pie, carga con el hombro (`shoulder_charge`, pierde `Jogging_Stumble`), barrida forzada o entrada al aire. La persona no roba por mantener PRESIÓN; la IA sí disputa sola.
- **Caídas:** a sprint `Sprint_To_Backslide` (o su versión en el sitio sin espacio), `fallen_idle` antes de levantarse.
- **Transiciones** (`Footballer._gait_overlays`): `Idle_To_Sprint`, `Sprint_Turn`, parada agotado con `Running_Tired`. Bloqueo con `Defender_2`.
- **Recepción asistida:** con el joystick suelto el jugador de la persona sale al punto de encuentro del pase (`pass_meet_point`).

## Patadas sincronizadas, pie de apoyo y conducción en giros (2026-10-27, segunda ronda)

Diagnóstico con el esqueleto animado (render) y el video del usuario `prueba01` (8.0–9.9 s: con TIRO cargando, el
jugador gira hacia el arco y la pelota sigue sola hasta la banda).

- **Golpe en el instante del contacto** (`BallHandler.clip_timing`): la latencia se cuantiza a pasos de física y el
  inicio del clip se ajusta para que la pose de contacto caiga exactamente en el paso del impulso. El AnimationTree
  avanza en `_process` (después de la física): la imagen que se dibuja con el impulso es la del contacto (punta del pie
  a 0.05 m de la pelota); la anterior tiene el pie aún armado (~0.28 m). Una prueba que lea la pose dentro del paso del
  impulso ve la imagen anterior.
- **Pie de apoyo plantado** (`KICK_PLANT_TIME`, `clip_plant_velocity`, `kick_body_velocity`): en los 0.10 s previos al
  contacto el cuerpo se mueve a la velocidad que deja quieto el pie de apoyo del clip (los clips en el sitio mueven ese
  pie hacia atrás a la velocidad de carrera que representan). Desliz medido: 0.4–1.3 m/s (antes 1.4–7.4 m/s).
- **Compromiso durante el balanceo** (`Footballer._physics_process`, `kick_desired_dir`): el joystick no gira ni acelera
  al jugador mientras patea; el ajuste de paso se corrige en lazo cerrado (`_steer_clip_kick`) hasta plantar el pie.
  El plan solo acepta el ajuste que cabe antes de plantar el pie (`kick_adjust_capacity`: `KICK_NUDGE_MAX` +
  `KICK_NUDGE_PER_MS` × velocidad, durante latencia − `KICK_PLANT_TIME`); a sprint, sin esto, 7 de 8 pases fallaban el
  golpe (ajuste pedido 0.53 m, posible 0.32 m). Al terminar la patada el cuerpo recupera la velocidad que traía.
- **Clip según la velocidad del jugador** (`PLANT_MISMATCH_COST`, `PLANT_SPEED_GAIN_MAX`): se prefieren los clips cuya
  velocidad de apoyo encaja con la del jugador (parado: `Soccer_Pass`; corriendo: `strike_foward_jog_inplace`) y la
  velocidad de apoyo no supera la del cuerpo en más de 1.5 m/s (un jugador parado no sale disparado).
- **Golpeo de primera** (`is_waiting_first_time`, `PENDING_FIRST_TIME_MAX`): con la pelota viniendo hacia el jugador
  la orden espera hasta 1.4 s y el jugador va a la trayectoria (`incoming_ball_point`) sin controlarla antes.
- **Recuperar la pelota en un giro** (`carry_steer`): si la pelota propia queda fuera del alcance del toque y no está
  delante del rumbo pedido, el jugador va a un punto detrás de ella; el toque usa el rumbo del joystick. **Media vuelta**
  (`REVERSAL_TOUCH_GAP`): con más de 100° de giro el toque de arrastre no espera la cadencia de la carrera.
- **Curvas:** el toque coloca la pelota sobre el arco que va a recorrer el cuerpo (giro anticipado), no en la tangente.
- **Arrancada** (`ACCEL_TOUCH_PER_FRACTION`, `ACCEL_TOUCH_MAX`): con SPRINT, en línea recta y lejos de la punta, el
  toque se alarga hasta 0.3 m × (1 − control) (pelota a ~1.0 m con control medio); a velocidad punta vuelve el control
  cercano. En giros no se aplica (alargarlo en el giro perdía la pelota: 6 de 20 giros a sprint).
- **Pelota apoyada en el cuerpo** (`_shrug_resting_ball`, `RESTING_BALL_SECONDS`): si la pelota queda quieta sobre la
  cabeza / hombros (encajada entre dos jugadores pegados), el jugador se la quita con un toque. Hallado en un partido de
  10 min: 436.8 s trabada a 1.6 m de altura (nadie podía tocarla con el pie).
- **`has_possession()`**: pelota al pie Y no es de otro (`MatchContext.possessor`). Exigir ser ya el poseedor arbitrado
  cortaba la conducción en zigzag (8 de 16 toques con el pie frente a 18 de 21).

Medido con render (`test_live_feet`, `test_live_kicks`): curva 100 % con la pelota cerca (antes 83 %), medias vueltas
100 % (antes 44 %), zigzag 18/21 toques con el pie; batería de 50 golpeos variados: 49 con contacto (punta del pie a
≤0.30 m en la imagen del golpe), 1 cancelado porque el rival tocó antes, 0 impulsos sin contacto, 0 jugadores bloqueados.

## Conducción tras el video `videofutbol` (2026-10-27, tercera ronda)

Fallos vistos fotograma a fotograma (con el joystick recortado en cada imagen) y su corrección:

- **Soltar el joystick y la pelota se iba sola (10.2 s del video)** → `BallHandler.settle_steer`: con el joystick
  suelto y la pelota propia fuera del alcance del pie, el jugador la acompaña; al alcance, frena y el toque de parada
  (que ya no espera a la zancada) la deja al pie. Medido con render: desde paso lento, trote, carrera y sprint queda
  parado con la pelota a 0.29–0.65 m en 0.55–1.18 s; una pelota que sale rodando a 1.6 m/s se para en 0.65–0.9 s.
- **Girar sin avanzar (67–70 s)** → `BallHandler.carry_turn_scale`: despacio, el cuerpo giraba 180° en <0.3 s y dejaba
  la pelota a la espalda; ahora gira a `BALL_TURN_SCALE` hasta que el toque de giro la lleva al rumbo nuevo. Media
  vuelta: toque por el costado del cuerpo y sin chocar con él (`REVERSAL_GHOST_SECONDS`); a sprint antes se perdía a
  6.5 m, ahora la conserva (separación máxima 1.1 m).
- **El cuerpo frenaba su propia pelota** (curvas) → mientras conduce, la cápsula del jugador no choca con la pelota que
  lleva (`DRIBBLE_GHOST_RANGE`; los demás jugadores sí). Curva continua de 10 s: antes pelota cerca 73 % y atrás 34 %,
  ahora 100 % y 0 %.
- **Desplazamiento lateral con el joystick a medias (45 s)** → `PlayerTuning.lateral_max_stick` 0.75 → 0.5.
- **Contacto con todo el pie** (`foot_distance`, tobillo–punta) en vez de solo la punta.
- **Reloj de simulación, no del sistema:** «no tocar ni perseguir el propio envío» (`OWN_KICK_SECONDS` 0.7 s) y «no
  controlar la pelota que acabo de tocar» (450 ms) se medían con `Time.get_ticks_msec()`, así que la regla cambiaba con
  la velocidad de la simulación (la suite lo detectó: tras un pase con el joystick suelto, `settle_steer` perseguía el
  propio pase a 0.96 m/s). Ahora cuentan pasos de física (`seconds_since_kick`, `Ball.last_touch_frame`) y
  `settle_steer` no persigue el propio pase. Medido: la prueba con render simula a ~2× tiempo real (602 pasos en
  5.0 s), de modo que los 450 ms equivalían a 54 pasos (0.9 s de juego) en las pruebas y a 27 en el móvil; con 0.45 s
  de simulación la curva bajaba a 10 de 18 toques con el pie. Se fija `OWN_TOUCH_NO_CONTROL_SECONDS` = 0.9 s, el valor
  con el que se midió la conducción (curva 11/18, zigzag 10/14, igual que antes).
- Limitación medida: en curvas cerradas continuas el 39 % de los toques son de rescate (ningún pie llega a tiempo);
  exigir un pie cerca para el rescate rompía el frenado y los giros (probado y revertido).

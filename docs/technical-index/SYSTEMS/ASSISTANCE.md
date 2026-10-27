# ASSISTANCE — Pase, tiro y presión asistidos

## Identificación

- **Responsabilidad exacta:** convertir la *intención* del jugador (joystick, carga del botón) en un golpe o un movimiento defensivo con ayuda **moderada y configurable**, sin garantizar el resultado:
  - **Pase** (`PassAssist.compute`): elige al compañero que mejor coincide con la dirección apuntada (ángulo, distancia, línea libre), corrige la dirección de forma acotada y calcula la fuerza.
  - **Tiro** (`ShotAssist.compute`): corrige hacia un punto del arco solo si se apunta al arco o cerca; la ayuda se desvanece al apuntar fuera.
  - **Presión** (`PressController.update`): botón mantenido; busca el punto de intercepción de la **pelota**, se contiene a distancia y deja que el joystick ajuste el ángulo sin cancelar la búsqueda.
  - **Modelo de error** (`KickModel`): ruido gaussiano acotado que depende de distancia, potencia, equilibrio, orientación, velocidad, pierna de golpeo y atributos.
- **Estado:** implementado y probado (sin compañeros reales en la escena de juego: las pruebas los crean).
- **Última verificación:** <!-- AUTO:verified -->
2026-10-26
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/assistance/assist_tuning.gd` | Recurso `AssistTuning` con niveles y límites de las tres asistencias | `AssistTuning.Level`, `AssistTuning.LEVEL_VALUES`, `AssistTuning.set_all_levels` | — |
| `scripts/assistance/pass_assist.gd` | Clase `PassAssist` (estática): candidato, dirección, fuerza y error del pase | `PassAssist.compute`, `PassAssist._lane_clearance` | `KickModel`, `MatchContext`, `BallTuning` |
| `scripts/assistance/shot_assist.gd` | Clase `ShotAssist` (estática): punto de mira, corrección, trayectoria y error del tiro | `ShotAssist.compute` | `Goal.aim_point`, `PitchConfig`, `BallTuning`, `MatchContext` |
| `scripts/assistance/press_controller.gd` | Clase `PressController` (`RefCounted` con estado): intercepción, contención y disputa | `PressController.update`, `PressController.PressOutput`, `PressController._project`, `PressController._find_carrier` | `KickModel`, `MatchContext`, `Tuning` |
| `scripts/assistance/kick_model.gd` | Clase `KickModel` (estática): ángulos en XZ, error, equilibrio, pierna débil, velocidad exacta para una distancia | `KickModel.KickResult`, `KickModel.balance_state`, `KickModel.ground_speed_for_distance`, `KickModel.lob_speed_for_distance` | `Footballer`, `BallTuning` |

**No modificar para cambiar la asistencia:** `ball_handler.gd` (solo llama a `compute` y aplica el resultado) ni `Ball`. **Quién llama:** `BallHandler.perform_pass` / `perform_shot` y `Footballer._physics_process` (presión).

## Mapa de parámetros

<!-- AUTO:params:AssistTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `pass_assist` | `0.65` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:16` | `scripts/ui/hud.gd:163`, `scripts/assistance/assist_tuning.gd:57`, `scripts/gameplay/tuning.gd:38`, `scripts/gameplay/tuning.gd:45` (+1) |  (Pase) |
| `pass_cone_deg` | `52.0` | float | `scripts/assistance/assist_tuning.gd:18` | `scripts/assistance/pass_assist.gd:28` | Angulo maximo entre la direccion del joystick y un companero para considerarlo. (Pase) |
| `pass_max_distance` | `24.0` | float | `scripts/assistance/assist_tuning.gd:20` | `scripts/assistance/pass_assist.gd:35` | Alcance maximo de busqueda (m). (Pase) |
| `pass_max_correction_deg` | `18.0` | float | `scripts/assistance/assist_tuning.gd:22` | `scripts/assistance/pass_assist.gd:69` | Correccion angular maxima (grados) cuando la asistencia es 1. (Pase) |
| `pass_weight_angle` | `1.0` | float | `scripts/assistance/assist_tuning.gd:23` | `scripts/assistance/pass_assist.gd:43` |  (Pase) |
| `pass_weight_distance` | `0.35` | float | `scripts/assistance/assist_tuning.gd:24` | `scripts/assistance/pass_assist.gd:43` |  (Pase) |
| `pass_weight_lane` | `0.8` | float | `scripts/assistance/assist_tuning.gd:25` | `scripts/assistance/pass_assist.gd:43` |  (Pase) |
| `pass_lane_block_radius` | `0.8` | float | `scripts/assistance/assist_tuning.gd:27` | `scripts/assistance/pass_assist.gd:42` | Radio de un rival para bloquear la linea de pase. (Pase) |
| `pass_error_deg` | `2.6` | float | `scripts/assistance/assist_tuning.gd:29` | `scripts/assistance/pass_assist.gd:100` | Error base de pase en grados (atributo de precision 50, 8 m). (Pase) |
| `shot_assist` | `0.55` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:32` | `scripts/ui/hud.gd:164`, `scripts/assistance/assist_tuning.gd:58`, `scripts/gameplay/tuning.gd:39`, `scripts/gameplay/tuning.gd:46` (+1) |  (Tiro) |
| `shot_cone_deg` | `38.0` | float | `scripts/assistance/assist_tuning.gd:33` | `scripts/assistance/shot_assist.gd:37` |  (Tiro) |
| `shot_max_correction_deg` | `10.0` | float | `scripts/assistance/assist_tuning.gd:34` | `scripts/assistance/shot_assist.gd:61` |  (Tiro) |
| `shot_post_margin` | `0.28` | float | `scripts/assistance/assist_tuning.gd:36` | `scripts/assistance/shot_assist.gd:28`, `scripts/assistance/shot_assist.gd:54` | Margen (m) que se deja respecto a los postes al apuntar. (Tiro) |
| `shot_error_deg` | `2.2` | float | `scripts/assistance/assist_tuning.gd:37` | `scripts/assistance/shot_assist.gd:80` |  (Tiro) |
| `press_assist` | `0.7` | 0.0, 1.0 | `scripts/assistance/assist_tuning.gd:40` | `scripts/ui/hud.gd:165`, `scripts/assistance/assist_tuning.gd:59`, `scripts/assistance/press_controller.gd:111`, `scripts/gameplay/tuning.gd:40` (+1) |  (Presion defensiva) |
| `press_lookahead` | `0.55` | float | `scripts/assistance/assist_tuning.gd:42` | `scripts/assistance/press_controller.gd:65`, `scripts/assistance/press_controller.gd:66` | Segundos hacia delante para predecir la posicion de intercepcion. (Presion defensiva) |
| `press_standoff` | `1.4` | float | `scripts/assistance/assist_tuning.gd:44` | `scripts/assistance/press_controller.gd:77`, `scripts/assistance/press_controller.gd:106` | Distancia a la que el defensor se mantiene (m) antes de disputar. (Presion defensiva) |
| `press_tackle_range` | `0.90` | float | `scripts/assistance/assist_tuning.gd:46` | `scripts/assistance/press_controller.gd:117` | Distancia a la que se intenta quitar la pelota (m). (Presion defensiva) |
| `press_around_offset` | `0.30` | float | `scripts/assistance/assist_tuning.gd:48` | `scripts/assistance/press_controller.gd:85` | Cuanto rodea el defensor al portador para atacar la pelota por el lado libre (m mas alla de la pelota). (Presion defensiva) |
| `press_speed_factor` | `0.93` | float | `scripts/assistance/assist_tuning.gd:49` | `scripts/assistance/press_controller.gd:59` |  (Presion defensiva) |
| `press_stick_influence` | `0.55` | float | `scripts/assistance/assist_tuning.gd:51` | `scripts/assistance/press_controller.gd:94` | Cuanto influye el joystick (0..1) en el angulo de aproximacion. (Presion defensiva) |
| `press_tackle_cooldown` | `1.3` | float | `scripts/assistance/assist_tuning.gd:53` | `scripts/assistance/press_controller.gd:119` | Segundos de enfriamiento entre intentos de robo. (Presion defensiva) |
<!-- /AUTO -->

Niveles de la interfaz (`Hud._cycle_assist`): `AssistTuning.LEVEL_VALUES` = Desactivada 0.0, Baja 0.35, Media 0.65, Alta 0.95; se guardan en `user://settings.cfg` (`Tuning.save_user_settings`). `Footballer.assist_override_pass`/`assist_override_shot` (≥ 0) los sustituyen por jugador (usado por las pruebas).

### Qué hace cada ajuste (verificado en el código)

| Ajuste | Comportamiento real |
|---|---|
| `pass_assist` (0–1) | Escala el cono de búsqueda (`pass_cone_deg × lerp(0.65, 1, nivel)`, ×0.75 sin joystick) y la corrección (`diff × nivel`, tope `pass_max_correction_deg × nivel`). Con nivel 0 no se busca compañero ni se corrige. |
| `pass_weight_*` | Puntaje del candidato = `w_ángulo·(1 − áng/cono) + w_distancia·cercanía_a_la_distancia_ideal + w_línea·línea_libre`; la distancia ideal crece con la carga (`4.5 + 13·carga` m). |
| `shot_assist` (0–1) | La corrección es `diff × nivel × peso`, con tope `shot_max_correction_deg × nivel`; `peso` cae a 0 cuando el punto de impacto proyectado en la línea de gol queda fuera de los postes más un margen que depende de `shot_cone_deg` y de la distancia. Con intención centrada y nivel ≥ 0.4 sugiere el lado opuesto al arquero (factor 0.62 del ancho útil). |
| `press_assist` | **Solo** escala la intensidad del movimiento de presión (`× lerp(0.9, 1.0, nivel)`); con nivel 0 la presión **sigue funcionando** (el botón es una acción del usuario). |
| `press_standoff`, `press_lookahead` | Distancia de contención ante un portador y horizonte (×2) de la intercepción. |
| `press_speed_factor` | Fracción de la velocidad máxima de sprint con que se calcula la intercepción (`chase_speed`, mínimo 2.5 m/s). |
| `press_stick_influence` | Peso de la componente lateral del joystick (×1.2) sobre la dirección de búsqueda. |
| `press_tackle_range`, `press_tackle_cooldown` | Alcance y enfriamiento del intento de robo (`BallHandler.attempt_tackle`, cuya probabilidad depende del atributo `marking`, orientación, equilibrio, velocidad relativa y, del portador, `strength`/`balance`). |
| `pass_error_deg`, `shot_error_deg` | Desviación típica base (grados) antes de multiplicadores. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/assistance/pass_assist.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PassAssist.compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float)` | 10 | Pase asistido. El jugador apunta con el joystick; el sistema elige el companero que mejor coincide con esa INTENCION (direccion, distancia,  |
| `PassAssist._lane_clearance(from_pos: Vector3, to_pos: Vector3, opponents: Array[Footballer], block_radius: float)` | 128 | 1.0 = linea totalmente libre; baja cuanto mas cerca de la linea de pase este un rival. |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/shot_assist.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `ShotAssist.compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool, rng: RandomNumberGenerator, assist_level: float)` | 9 | Tiro asistido. El jugador apunta con el joystick; si esa intencion apunta al arco (o cerca), se corrige MODERADAMENTE la direccion hacia un  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/press_controller.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PressController.reset()` | 27 |  |
| `PressController.update(defender: Footballer, ctx: MatchContext, stick_world: Vector3, stick_mag: float, dt: float)` | 30 |  |
| `PressController._project(vel: Vector3, t: float, decelerates: bool)` | 122 |  |
| `PressController.defender_pitch_clamp(ctx: MatchContext, p: Vector3)` | 132 |  |
| `PressController._find_carrier(ctx: MatchContext, ball: Ball, team: int, radius: float)` | 137 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/assistance/kick_model.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `KickModel.flat(v: Vector3)` | 26 |  |
| `KickModel.angle_between_deg(a: Vector3, b: Vector3)` | 29 |  |
| `KickModel.signed_angle_deg(from_dir: Vector3, to_dir: Vector3)` | 36 |  |
| `KickModel.rotate_toward(dir: Vector3, target_dir: Vector3, max_deg: float)` | 44 | Gira "dir" hacia "target_dir" como maximo max_deg grados (plano XZ). |
| `KickModel.gaussian_clipped(rng: RandomNumberGenerator, sigma: float, clip: float = 2.2)` | 49 |  |
| `KickModel.balance_state(f: Footballer)` | 53 | 1.0 = totalmente equilibrado. Baja con giros bruscos, frenadas y cansancio. |
| `KickModel.misalignment(f: Footballer, dir: Vector3)` | 64 | Proporcion de desalineacion entre el cuerpo y la direccion del golpe (0..1). |
| `KickModel.is_weak_foot(f: Footballer, ball_pos: Vector3)` | 68 | True si el balon queda del lado del pie no dominante. |
| `KickModel.weak_foot_error_mult(f: Footballer)` | 75 | Penalizacion de la pierna debil segun el atributo (1.0 = sin penalizacion). |
| `KickModel.weak_foot_power_mult(f: Footballer)` | 78 |  |
| `KickModel.ground_speed_for_distance(d: float, arrival: float)` | 84 | Velocidad inicial (m/s) para recorrer d metros por el suelo y llegar con "arrival" m/s. Modelo exacto de la pelota: desaceleracion = rodadur |
| `KickModel.lob_speed_for_distance(d: float, angle_deg: float)` | 92 | Velocidad de lanzamiento para un pase elevado que cubre d metros con el angulo dado (grados). |
<!-- /AUTO -->

## Recorrido de ejecución

Fórmulas tal como están en el código (2026-10-26). `asistencia` = nivel 0–1 (`Tuning.assist` o `Footballer.assist_override_*`); `carga` = 0–1.

**Pase** (`PassAssist.compute`, llamado por `BallHandler.perform_pass` en el instante de contacto):
1. Dirección de intención = joystick, o la orientación del cuerpo si el joystick está neutro.
2. Si `asistencia > 0`: cada compañero (`MatchContext.teammates_of`) a entre 1.2 m y `pass_max_distance`, dentro del cono (`pass_cone_deg × lerp(0.65, 1, asistencia)`, ×0.75 sin joystick), se puntúa: `w_ángulo·(1 − áng/cono) + w_distancia·clamp(1 − |dist − ideal|/(ideal + 6), 0, 1) + w_línea·línea_libre`, con `ideal = 4.5 + 13·carga` m. Gana el mayor (`PassAssist._lane_clearance` penaliza rivales a menos de `2·pass_lane_block_radius` de la línea).
3. Con compañero: punto de mira = posición + `velocidad × tiempo_de_vuelo × 0.85`; la dirección se corrige `clamp(diff·asistencia, ±pass_max_correction_deg·asistencia)`. Sin compañero (**pase al espacio**): distancia = `lerp(4.5, 19.0, carga)` a lo largo de la intención y **sin corrección**.
4. Fuerza: `power_mult = factor("long_pass" si dist > 11 m, si no "short_pass"; 0.12)`. Pase raso: `v0 = KickModel.ground_speed_for_distance(dist, llegada)` con `llegada = pass_arrival_speed` hacia un compañero o 0.8 m/s al espacio, `× lerp(1, driven_pass_extra, carga)` con compañero, limitado a `[pass_speed_min (1.6 al espacio), pass_speed_max·power_mult]`. Pase elevado (`lob`): `KickModel.lob_speed_for_distance(dist, lob_angle_deg)` limitado a `[6, 20·power_mult]`. Tipos resultantes: `driven` (carga > 0.45), `short`, `space`, `lob`.
5. Error: `σ = pass_error_deg·(1.45 − 0.9·precisión)·(0.6 + 0.4·√(dist/8))·(1 + 0.9·(1 − equilibrio))·(1 + 0.6·desalineación)·(1 + 0.5·(v/vmax)²)·(1 + 0.45·carga²)·lerp(1.1, 0.88, compostura)·(pierna débil)`; la desviación es gaussiana recortada (`KickModel.gaussian_clipped`) y la potencia lleva un ruido gaussiano de σ 2.5–5 % recortado a ±10 %.
6. Devuelve `KickModel.KickResult` (velocidad, giro de rodadura —o retroceso de 18 rad/s en el elevado—, objetivo, error aplicado, `sigma_deg`, `weak_foot`). `BallHandler` lo aplica con `Ball.kick`.

**Tiro** (`ShotAssist.compute`, desde `BallHandler.perform_shot`):
1. Intención hacia el arco rival (`ctx.attacking_goal`). Se proyecta la intención sobre la línea de gol (`z_hit`); `peso = clamp(1 − exceso/max(extra, 0.2), 0, 1)` con `exceso = max(|z_hit| − (mitad_arco − shot_post_margin), 0)` y `extra = dist·tan(shot_cone_deg/2)·0.55`. Apuntar fuera del arco y de ese margen deja el peso en 0 (sin ayuda).
2. Punto de mira: `Goal.aim_point(lateral, altura, shot_post_margin)`. Con intención centrada (`|lateral| < 0.22`), `peso > 0` y asistencia ≥ 0.4, se sugiere el lado contrario al arquero (`lateral = ±0.62`); **hoy no hay arquero, así que el lado es aleatorio** (`rng`). Altura: `0.88` si es elevado, si no `lerp(0.08, 0.5, carga·0.75)` (máx. 0.3 a menos de 4 m).
3. Corrección: `clamp(diff·asistencia·peso, ±shot_max_correction_deg·asistencia)`.
4. Potencia: `lerp(shot_speed_min, shot_speed_max, carga) × factor("shot_power", 0.14)` (× pierna débil), tope `shot_speed_max·1.2`.
5. Error horizontal: `σ = shot_error_deg·(1.5 − 0.9·precisión)·(1 + 0.9·carga²)·(1 + 0.8·(1 − equilibrio))·(1 + 0.7·desalineación)·(1 + 0.5·(v/vmax)²)·[si dist < 10 m: lerp(1.15, 0.85, finalización)]·lerp(1.1, 0.88, compostura)·(pierna débil)`; el error vertical usa `σ·0.6`.
6. Trayectoria: velocidad vertical = `lerp(por defecto, la necesaria para llegar al punto de mira, asistencia·peso·0.9)`, limitada a `speed·sin(40°)`, más el error vertical; `KickResult.on_target` es una predicción **sin arrastre**.

**Presión** (`PressController.update`, desde `Footballer._physics_process` mientras `press_held` y el equipo no tiene la pelota):
1. No hace nada si la pelota está sostenida (`Ball.is_held`) o si un compañero la controla.
2. Portador rival = el rival más cercano a la pelota dentro de `possession_radius` (se conserva el anterior mientras esté a < 1.5× ese radio).
3. Punto de intercepción: 3 iteraciones con `chase_speed = max(max_sprint_speed·press_speed_factor, 2.5)`, tiempo acotado a `2·press_lookahead`; la pelota suelta se proyecta con una deceleración fija de 1.1 m/s² (`PressController._project`).
4. Aproximación: contra un portador el punto se retrasa `0.6·press_standoff` a lo largo de la dirección del portador; a menos de `1.2·press_standoff` de la pelota va directo al punto de intercepción.
5. Joystick: añade solo la componente lateral (`press_stick_influence·1.2`); si la mezcla se desviara más de lo que permite (`dot < 0.35`) se atenúa a 0.8/0.2.
6. Velocidad: 1.0 si `dist > 5 m`, si no `clamp(0.4 + dist/6, 0.4, 1)`; 0.55 como máximo en contención (portador y pelota a < `1.2·press_standoff`); `× lerp(0.9, 1, press_assist)`; sprint si `dist > 6 m` y no agotado.
7. Intento de robo (`attempt_tackle`): pelota a ≤ `press_tackle_range`, sin enfriamiento, pelota a menos de 0.6 m de altura y el defensor mirándola (< 85°); luego `BallHandler.attempt_tackle` decide con probabilidad según `marking`, orientación, equilibrio, velocidad relativa y los atributos del portador.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh passing`, `tools/run_tests.sh shooting`, `tools/run_tests.sh press`.
- **Resultados medidos (2026-10-26, semillas fijas):** pase de 11 m con asistencia 0.65: 17/24 llegan frente a 0/24 sin asistencia; pase largo con precisión 15 y asistencia 0.95: 16/30 (la asistencia no garantiza); σ de pase 4.64° (atributos 10) vs 1.52° (atributos 100); pase al espacio por carga 0 / 0.5 / 1: 4.8 / 11.9 / 19.3 m (previstos 4.5 / 11.75 / 19); tiro con asistencia 0.55 desde 8.5 m sin arquero: 27/40 goles y 3 impactos en poste/travesaño; 40 duelos de presión con marcaje 50: 24 robos ganados / 47 intentos fallidos ejecutando solo `press` (repetido 3 veces, idéntico) y 22 / 48 dentro de la suite completa (ver «Reglas del marco» en [TESTING](TESTING.md)).

<!-- AUTO:tests:tests/test_passing.gd -->
| Prueba | Línea |
|---|---|
| `test_assisted_pass_arrives_far_more_often_than_unassisted` | 29 |
| `test_pass_is_never_guaranteed_with_poor_accuracy_at_long_range` | 50 |
| `test_attributes_and_weak_foot_change_error` | 66 |
| `test_pass_to_space_when_no_teammates_scales_with_charge` | 90 |
| `test_lob_pass_flies_over_the_ground_and_lands_near_target` | 110 |
| `test_pass_can_be_intercepted_by_a_defender` | 138 |
| `test_active_defender_takes_possession_of_intercepted_pass` | 158 |
| `test_assist_picks_best_aligned_and_ignores_out_of_cone` | 181 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_shooting.gd -->
| Prueba | Línea |
|---|---|
| `test_assist_improves_on_target_rate_but_never_guarantees` | 21 |
| `test_assist_fades_when_aiming_clearly_away_from_goal` | 32 |
| `test_charge_controls_power_and_attributes_scale_it_moderately` | 49 |
| `test_lob_shot_is_higher_than_driven_shot` | 73 |
| `test_physical_shot_outcomes_include_goals_posts_and_misses` | 82 |
| `test_far_shots_are_much_harder_than_close_ones` | 115 |
<!-- /AUTO -->

<!-- AUTO:tests:tests/test_press.gd -->
| Prueba | Línea |
|---|---|
| `test_press_closes_distance_to_a_loose_ball_even_when_the_stick_changes_direction` | 8 |
| `test_press_never_exceeds_physical_speed_limits` | 29 |
| `test_press_intercept_point_is_ahead_of_a_moving_carrier` | 45 |
| `test_press_released_stops_the_chase` | 64 |
| `test_tackle_success_is_probabilistic` | 76 |
<!-- /AUTO -->

- **Qué podría romperse:** asistencia que garantice el resultado (todas las pruebas de «no garantizada» fallarían); pases que no llegan a su distancia si se cambia la física de la pelota sin revisar `KickModel.ground_speed_for_distance`; presión que abandona la pelota al mover el joystick.

## Limitaciones conocidas

- La asistencia de pase solo se ejercita con compañeros creados en pruebas; en la escena de partido hay un único jugador por equipo.
- `Hud._cycle_assist` asigna los niveles con nombres de propiedad dinámicos (`"%s_assist" % kind`): una búsqueda por `pass_assist` no los encuentra.
- No hay amagues/regates ni pase filtrado diferenciado; el «pase al espacio» solo existe cuando no hay candidato.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Control asistido».

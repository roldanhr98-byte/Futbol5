# BALL — Pelota

## Identificación

- **Responsabilidad exacta:** física independiente de la pelota (`RigidBody3D` con Jolt): gravedad, masa, rebote, fricción, rodadura, resistencia del aire cuadrática, efecto Magnus, amortiguación en la red, límites de velocidad, golpes por **impulso**, retención por el arquero (`hold`/`release`) y teletransporte controlado (saques).
- **Principio de diseño:** la pelota nunca se coloca en el pie ni se anula su velocidad para simular control; los jugadores solo la cambian con `Ball.kick`/`Ball.push` en el instante del contacto.
- **Estado:** implementado.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-28
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos / nodos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/ball/ball.gd` | Clase `Ball` (`RigidBody3D`): construcción, física por paso, API de golpes | `Ball.apply_tuning`, `Ball._integrate_forces`, `Ball.kick`, `Ball.rolling_spin`, `Ball.reset_at`, `Ball.hold`, `Ball.enter_net`, `Ball._on_body_entered` | `Tuning.ball`, `BallState` |
| `scripts/ball/ball_tuning.gd` | Recurso `BallTuning` con todos los parámetros de la pelota, pase y tiro | ver «Mapa de parámetros» | — |
| `scenes/ball/ball.tscn` | Nodo raíz `Ball` (`RigidBody3D`) con el script; la colisión (`CollisionShape3D`) y la malla (`Visual`) se crean en `Ball._build` | nodo `Ball` | `scripts/ball/ball.gd` |
| `assets/ball/ball.gdshader` | Aspecto (parches sobre un icosaedro); **no** afecta a la física | uniforms `base_color`, `patch_color`, `patch_threshold` | — |
| `project.godot` | `physics/3d/physics_engine="Jolt Physics"`, `common/physics_ticks_per_second=60`, `3d/default_gravity=9.81`, `jolt_physics_3d/limits/max_angular_velocity=200.0`, nombres de capas | secciones `[physics]`, `[layer_names]` | Jolt |

**Archivos externos que alteran el rebote o el contacto (no editarlos para cambiar la pelota):**

| Archivo | Qué define | Valor actual |
|---|---|---|
| `scripts/pitch/pitch.gd` (`Pitch._build_floor`) | material del piso | `friction = 0.8`, `bounce = 0.0` |
| `scripts/pitch/pitch.gd` (`Pitch._build_walls`) | material de las paredes (`wall_pm`) | `friction = 0.4`, `bounce = 0.5` |
| `scripts/pitch/goal.gd` (`Goal._add_frame_piece`) | material de postes y travesaño | `bounce = 0.45`, `friction = 0.3` |
| `scripts/pitch/goal.gd` (`Goal._build_net`) | superficies del grupo `net_surface` y volumen de red | usan `BallTuning.net_restitution` y `net_damping` vía `Ball` |

**No modificar para cambiar la física de la pelota:** `scripts/player/ball_handler.gd` (decide *cuándo* se golpea, no cómo rueda), `scripts/assistance/*` (calculan velocidades objetivo), `assets/ball/ball.gdshader` (solo visual).

## Mapa de parámetros

<!-- AUTO:params:BallTuning -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `radius` | `0.1` | float | `scripts/ball/ball_tuning.gd:8` | `scripts/ball/ball.gd:122`, `scripts/ball/ball_predictor.gd:21`, `scripts/ball/ball_predictor.gd:31`, `scripts/ball/ball_predictor.gd:32` (+10) | Radio real en metros (circunferencia ~63 cm). (Cuerpo) |
| `mass` | `0.42` | float | `scripts/ball/ball_tuning.gd:10` | `scripts/ball/ball.gd:123`, `scripts/ball/ball_predictor.gd:28`, `scripts/assistance/kick_model.gd:68`, `scripts/assistance/kick_model.gd:116` | Masa en kg (futsal: 400-440 g). (Cuerpo) |
| `visual_scale` | `1.25` | float | `scripts/ball/ball_tuning.gd:12` | `scripts/ball/ball.gd:140`, `scripts/ball/ball.gd:141` | Escala solo visual para que se lea bien con camara alta (no afecta a la fisica). (Cuerpo) |
| `bounce` | `0.54` | 0.0, 1.0 | `scripts/ball/ball_tuning.gd:16` | `scripts/ball/ball.gd:131`, `scripts/ball/ball_predictor.gd:34` | Coeficiente de restitucion. El balon de futsal rebota ~50-60 % de la altura de caida. (Contacto) |
| `friction` | `0.6` | 0.0, 2.0 | `scripts/ball/ball_tuning.gd:17` | `scripts/ball/ball.gd:132` |  (Contacto) |
| `angular_damp` | `0.01` | float | `scripts/ball/ball_tuning.gd:18` | `scripts/ball/ball.gd:128` |  (Contacto) |
| `drag_coefficient` | `0.25` | float | `scripts/ball/ball_tuning.gd:22` | `scripts/ball/ball.gd:366`, `scripts/ball/ball_predictor.gd:28`, `scripts/assistance/kick_model.gd:116` | Cd del balon en el aire. (Resistencia) |
| `air_density` | `1.2` | float | `scripts/ball/ball_tuning.gd:23` | `scripts/ball/ball.gd:366`, `scripts/ball/ball_predictor.gd:28`, `scripts/assistance/kick_model.gd:116` |  (Resistencia) |
| `rolling_decel` | `0.55` | float | `scripts/ball/ball_tuning.gd:25` | `scripts/ball/ball.gd:390`, `scripts/ball/ball_predictor.gd:41`, `scripts/assistance/kick_model.gd:117`, `scripts/player/ball_handler.gd:1385` (+4) | Desaceleracion de rodadura sobre el piso (m/s^2). (Resistencia) |
| `spin_decel_ground` | `6.0` | float | `scripts/ball/ball_tuning.gd:27` | `scripts/ball/ball.gd:398`, `scripts/ball/ball.gd:400` | Perdida de giro sobre el piso (rad/s^2). (Resistencia) |
| `magnus_k` | `0.0018` | float | `scripts/ball/ball_tuning.gd:29` | `scripts/ball/ball.gd:372`, `scripts/assistance/kick_model.gd:68` | Coeficiente tipo Magnus: F = k * (omega x v). (Resistencia) |
| `net_damping` | `7.0` | float | `scripts/ball/ball_tuning.gd:31` | `scripts/ball/ball.gd:235` | Dentro de la red: coeficiente de amortiguacion continua (1/s) y restitucion del impacto contra la malla. (Resistencia) |
| `net_restitution` | `0.12` | 0.0, 1.0 | `scripts/ball/ball_tuning.gd:32` | `scripts/ball/ball.gd:423` |  (Resistencia) |
| `max_speed` | `38.0` | float | `scripts/ball/ball_tuning.gd:33` | `scripts/ball/ball.gd:408`, `scripts/ball/ball.gd:409` |  (Resistencia) |
| `max_spin` | `150.0` | float | `scripts/ball/ball_tuning.gd:34` | `scripts/ball/ball.gd:410`, `scripts/ball/ball.gd:411` |  (Resistencia) |
| `pass_speed_min` | `4.0` | float | `scripts/ball/ball_tuning.gd:37` | `scripts/assistance/cross_assist.gd:83`, `scripts/assistance/pass_assist.gd:102`, `scripts/assistance/pass_assist.gd:224` |  (Pase) |
| `pass_speed_max` | `21.0` | float | `scripts/ball/ball_tuning.gd:38` | `scripts/assistance/cross_assist.gd:83`, `scripts/assistance/pass_assist.gd:103`, `scripts/assistance/pass_assist.gd:224` |  (Pase) |
| `pass_arrival_speed` | `4.5` | float | `scripts/ball/ball_tuning.gd:40` | `scripts/assistance/pass_assist.gd:64`, `scripts/assistance/pass_assist.gd:98` | Velocidad a la que queremos que el pase raso llegue al receptor. (Pase) |
| `lob_angle_deg` | `38.0` | float | `scripts/ball/ball_tuning.gd:41` | `scripts/assistance/pass_assist.gd:90` |  (Pase) |
| `driven_pass_extra` | `1.25` | float | `scripts/ball/ball_tuning.gd:42` | `scripts/assistance/pass_assist.gd:101` |  (Pase) |
| `shot_speed_min` | `9.0` | float | `scripts/ball/ball_tuning.gd:45` | `scripts/assistance/shot_assist.gd:110`, `scripts/assistance/shot_assist.gd:112` |  (Tiro) |
| `shot_speed_max` | `27.0` | float | `scripts/ball/ball_tuning.gd:46` | `scripts/assistance/shot_assist.gd:110`, `scripts/assistance/shot_assist.gd:112`, `scripts/assistance/shot_assist.gd:116` |  (Tiro) |
| `shot_charge_time` | `0.9` | float | `scripts/ball/ball_tuning.gd:48` | `scripts/ai/ai_input.gd:471`, `scripts/player/ball_handler.gd:344` | Segundos para cargar el tiro al maximo. (Tiro) |
| `shot_loft_low_deg` | `4.0` | float | `scripts/ball/ball_tuning.gd:49` | `scripts/assistance/shot_assist.gd:150`, `scripts/assistance/shot_assist.gd:155`, `scripts/assistance/shot_assist.gd:156`, `scripts/assistance/shot_assist.gd:216` |  (Tiro) |
| `shot_loft_high_deg` | `22.0` | float | `scripts/ball/ball_tuning.gd:50` | `scripts/assistance/shot_assist.gd:155`, `scripts/assistance/shot_assist.gd:156` |  (Tiro) |
| `shot_spin_factor` | `14.0` | float | `scripts/ball/ball_tuning.gd:52` | `scripts/assistance/shot_assist.gd:175` | Factor de efecto (spin) aplicado segun la desviacion lateral del golpeo. (Tiro) |
<!-- /AUTO -->

### Riesgos al modificar (verificados con las pruebas y mediciones de esta sesión)

| Parámetro | Efecto real y riesgo |
|---|---|
| `bounce` | Controla el rebote contra el piso (el piso tiene `bounce = 0.0`, y el resultado observado coincide con usar el valor de la pelota; la regla de combinación de Jolt **no se verificó en su documentación**, solo por medición). Sensibilidad medida desde 2 m (ver tabla abajo). `test_bounce_height_matches_futsal_spec` exige 0.45–0.70 m: bajar el valor por debajo de ~0.45 romperá esa prueba. También cambia el rebote contra postes y paredes (sus materiales tienen bounce propio, pero la pelota aporta el suyo) y los pases elevados al caer. |
| `friction` | Afecta al agarre contra el piso (acople rodadura/giro) y a los rebotes laterales. Al cambiarlo, revisar `test_rolling_decelerates_and_stops`. |
| `mass` | Escala el impulso de cada golpe (`kick` aplica `Δv · mass`) y entra en `k = ½·ρ·Cd·A/m` del arrastre; `KickModel.ground_speed_for_distance` usa la misma `mass`, así que los pases al espacio se recalculan solos, pero cambia el balance del Magnus y de las colisiones con cuerpos. |
| `radius` | Define la colisión, la altura de reposo, el área del arrastre, `rolling_spin = ω = (↑ × v)/r` y la regla de gol (`Goal.is_ball_in_goal` exige que el centro esté al menos un radio detrás de la línea). |
| `drag_coefficient`, `air_density`, `rolling_decel` | Alimentan **también** la fórmula exacta de `KickModel.ground_speed_for_distance`. Cambiarlos sin retocar nada más es coherente; pero si se cambia la física en `_integrate_forces` sin cambiar la fórmula, los pases al espacio dejarán de llegar a la distancia pedida (`test_pass_to_space_when_no_teammates_scales_with_charge`: 4.8 / 11.9 / 19.3 m). |
| `angular_damp` | Se aplica con `angular_damp_mode = REPLACE`; si se vuelve a `COMBINE` se suma el amortiguamiento por defecto de Godot (`default_linear_damp`/`default_angular_damp`) y la pelota frena claramente más de lo modelado (defecto ya corregido, ver CHANGELOG). |
| `max_spin` y `jolt_physics_3d/limits/max_angular_velocity` | Jolt limita por defecto el giro a 47.1 rad/s; con ese límite `rolling_spin` se truncaba y la pelota resbalaba al inicio. El proyecto lo sube a 200. Si se baja, reaparece el deslizamiento. |
| `net_damping`, `net_restitution` | Solo actúan dentro del volumen de red y contra superficies `net_surface`; evitan que la pelota rebote fuera del arco tras el gol. |
| `max_speed` | Tope duro de velocidad lineal en `_integrate_forces`. Debe ser mayor que `BallTuning.shot_speed_max · 1.2` (tope de `ShotAssist`). |

### Sensibilidad de `bounce` (medida el 2026-10-26 con una prueba temporal, pelota soltada desde 2 m sobre el piso de la cancha)

| `BallTuning.bounce` | 0.25 | 0.35 | 0.45 | **0.54 (actual)** | 0.62 |
|---|---|---|---|---|---|
| Altura del primer rebote | 0.123 m | 0.236 m | 0.385 m | **0.550 m** | 0.719 m |

La referencia de 50–65 cm desde 2 m para un balón de futsal es la que usa el proyecto en comentarios y pruebas; **no se contrastó con la fuente oficial en esta sesión**.

## Mapa de funciones

<!-- AUTO:funcs:scripts/ball/ball.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Ball._ready()` | 71 |  |
| `Ball._build()` | 77 |  |
| `Ball.apply_tuning()` | 121 | Aplica los parametros de BallTuning (se puede llamar en caliente desde el laboratorio). |
| `Ball.kick(target_velocity: Vector3, spin: Vector3 = Vector3.ZERO, kicker: Node = null)` | 146 | Golpe: aplica el impulso necesario para que la pelota salga con la velocidad y el giro dados. |
| `Ball.set_knuckle(accel: float, freq: float, phase: float)` | 158 | Activa el "flotado" del tiro sin giro recien pateado: amplitud (m/s^2), frecuencia (Hz) y fase (rad) de la fuerza lateral. Se llama justo de |
| `Ball.rolling_spin(velocity: Vector3)` | 167 | Giro de rodadura sin deslizamiento para una velocidad horizontal dada (w = up x v / r). Un golpe raso real transmite este giro; sin el, la p |
| `Ball.push(impulse: Vector3, actor: Node = null)` | 171 | Impulso arbitrario (desvios, choques) sin cambiar el ultimo toque salvo que se indique actor. |
| `Ball.register_touch(actor: Node)` | 176 |  |
| `Ball.reset_at(pos: Vector3, vel: Vector3 = Vector3.ZERO)` | 190 | Teletransporte controlado (saques de centro, reinicios). No se usa durante el juego normal. |
| `Ball.hold(anchor: Node3D, by: Node)` | 202 |  |
| `Ball.release(by: Node, velocity: Vector3 = Vector3.ZERO)` | 212 |  |
| `Ball.is_held()` | 221 |  |
| `Ball.is_grounded()` | 224 |  |
| `Ball.speed()` | 227 |  |
| `Ball.ground_speed()` | 230 |  |
| `Ball.enter_net()` | 233 |  |
| `Ball.exit_net()` | 237 |  |
| `Ball.capture_state(tick: int = 0)` | 242 |  |
| `Ball.apply_state(s: BallState)` | 255 |  |
| `Ball._process(delta: float)` | 274 |  |
| `Ball._physics_process(_delta: float)` | 298 |  |
| `Ball._update_trail(delta: float)` | 304 | Estela: se activa con un tiro rapido o con mucho efecto lateral en el aire y se desvanece al frenar o tocar el suelo. |
| `Ball._integrate_forces(state: PhysicsDirectBodyState3D)` | 338 |  |
| `Ball._on_body_entered(body: Node)` | 416 |  |
<!-- /AUTO -->

### Constantes de capas y señales

<!-- AUTO:consts:scripts/ball/ball.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `Ball.LAYER_WORLD` | `1` | 16 |  |
| `Ball.LAYER_BALL` | `2` | 17 |  |
| `Ball.LAYER_PLAYERS` | `4` | 18 |  |
| `Ball.LAYER_KEEPERS` | `8` | 19 |  |
| `Ball.LAYER_GOAL_FRAME` | `16` | 20 |  |
| `Ball.TRAIL_POINTS` | `18` | 50 | Estela de los tiros fuertes o con efecto (solo presentacion): cinta con las ultimas posiciones de la pelota. La forma de la curva que dibuja es la de la trayectoria real (no se inventa nada). |
| `Ball.TRAIL_MIN_SPEED` | `15.0` | 51 |  |
| `Ball.TRAIL_MIN_SPIN` | `14.0` | 52 |  |
| `Ball.KNUCKLE_MIN_SPEED` | `12.0` | 62 | Tiro sin giro que "flota" (knuckle, lo pone el tiro potente con set_knuckle): aceleracion lateral oscilante (m/s^2) mientras la pelota va rapida por el aire con poco giro, como la de las pelotas reales sin giro (la estela de aire se desprende de forma irregular). Cualquier golpe, bote o choque la apaga. |
| `Ball.KNUCKLE_MAX_SPIN` | `12.0` | 63 |  |
| `Ball.KNUCKLE_MAX_TIME` | `1.5` | 64 |  |
| `Ball.VISUAL_SPIN_DEG_PER_FRAME` | `20.0` | 265 | Grados maximos que gira el balon DIBUJADO por imagen. El patron (parches sobre los 12 vertices de un icosaedro) se repite cada ~63 grados: un pase a 6 m/s rueda a ~57 rad/s = 55 grados por imagen a 60 fps y se ve QUIETO; a 10 m/s, 92 grados por imagen, y parece girar despacio o al reves (efecto rueda de carro). El dibujo sigue el eje y el sentido reales pero sin pasar de este giro por imagen (legible tambien a 30 fps). La fisica (giro real, Magnus) no cambia. |
| `Ball.VISUAL_SHUTTER` | `0.5` | 268 | Fraccion de la imagen con el obturador abierto: el patron se desenfoca a lo largo del giro REAL de ese tiempo (el shader lo promedia alrededor del eje), como en la television: rapido quedan bandas y se ven los polos del eje. |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/ball/ball.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Ball.touched(actor: Node)` | 11 | Pelota independiente con fisica 3D (RigidBody3D / Jolt).  Reglas del diseno: - Nunca se teletransporta al pie del jugador ni se anula su velocidad para simular control. - Los jugadores interactuan solo mediante impulsos (kick) en el instante del contacto. - Resistencia del aire, efecto Magnus y rodadura se calculan en _integrate_forces. - Excepcion explicita: el arquero puede sostenerla (hold/release) mientras la tiene en las manos. |
| `Ball.hit_goal_frame(position: Vector3, speed: float)` | 12 |  |
| `Ball.floor_bounce(position: Vector3, speed: float)` | 13 |  |
| `Ball.released(by: Node)` | 14 |  |
<!-- /AUTO -->

## Recorrido de ejecución

1. **Creación:** `Ball._ready` → `Tuning.ball` → `Ball._build` (capas, `contact_monitor`, `continuous_cd`, `can_sleep = false`, colisión esférica, malla) → `Ball.apply_tuning` (radio, masa, **inercia de esfera hueca** `2/3·m·r²`, material físico con `bounce`/`friction`, modos de amortiguamiento `REPLACE`).
2. **Cada paso de física (60 Hz):** `Ball._integrate_forces`: (a) si hay teletransporte pendiente, lo aplica y sale; (b) detecta contacto con el piso (normal con `y > 0.6`); (c) emite `floor_bounce` al invertirse la velocidad vertical; (d) resta arrastre `½·ρ·Cd·A·v²/m`; (e) suma Magnus `k·(ω×v)/m` en el aire; (f) sobre el piso aplica `rolling_decel` y escala el giro para no pelear con la fricción; (e2) con `knuckle_accel > 0` (tiro potente sin giro, `Ball.set_knuckle`) suma una aceleración lateral oscilante (y 0.4 de ella arriba/abajo) mientras va por el aire a más de `KNUCKLE_MIN_SPEED` 12 m/s con menos de `KNUCKLE_MAX_SPIN` 12 rad/s, hasta `KNUCKLE_MAX_TIME` 1.5 s; cualquier golpe, bote, choque o teletransporte la apaga; (g) amortigua con `exp(-net_damping·dt)` dentro de la red; (h) recorta a `max_speed`/`max_spin`.
3. **Golpe (jugador, asistencia, arquero):** `Ball.kick(v_objetivo, spin, actor)` → `apply_central_impulse((v_objetivo − v)·mass)` + `apply_torque_impulse((spin − ω)·I)` → `register_touch` (guarda último y penúltimo en tocar; emite `touched`).
4. **Contactos especiales:** `Ball._on_body_entered` → poste/travesaño (grupo `goal_frame`): señal `hit_goal_frame`; superficies de red (grupo `net_surface`): `linear_velocity *= net_restitution`.
5. **Giro dibujado** (`Ball._process`, solo presentación): la malla gira con el eje y el sentido del giro real pero como mucho `VISUAL_SPIN_DEG_PER_FRAME` 20° por imagen (el patrón se repite cada ~63°: a 6 m/s el giro real de 55°/imagen se veía quieto y a 10 m/s, al revés); el shader (`assets/ball/ball.gdshader`, `spin_axis`/`spin_arc`) promedia el patrón a lo largo del giro real de medio fotograma (`VISUAL_SHUTTER` 0.5), como el obturador de una cámara: rápido quedan bandas y se ven los polos del eje.
6. **Giro de rodadura:** los golpes rasos usan `Ball.rolling_spin(v)` para que la pelota ruede sin deslizar; sin él la pelota resbala al inicio y pierde velocidad hasta empezar a rodar (fricción de deslizamiento; magnitud no aislada en una medición).

## Pruebas

- **Ejecutar:** `tools/run_tests.sh ball_physics` (9 pruebas, ~0.4 s). Para el efecto en pases: `tools/run_tests.sh passing`.
- **Última ejecución completa (2026-10-26):** 57 pruebas / 212 comprobaciones sin fallos; `ball_physics`: rebote 0.550 m desde 2 m; rodadura `v0 = 5.96 m/s`, `v(2 s) = 4.45 m/s`, recorrido hasta detenerse 26.5 m.

<!-- AUTO:tests:tests/test_ball_physics.gd -->
| Prueba | Línea |
|---|---|
| `test_bounce_height_matches_futsal_spec` | 4 |
| `test_rolling_decelerates_and_stops` | 23 |
| `test_kick_applies_impulse_not_teleport` | 42 |
| `test_ball_stays_inside_walls` | 54 |
| `test_goal_detected_once_when_fully_across_line` | 65 |
| `test_ball_on_the_line_is_not_a_goal` | 80 |
| `test_post_deflects_ball_physically` | 92 |
| `test_crossbar_deflects_ball` | 109 |
| `test_state_roundtrip` | 126 |
<!-- /AUTO -->

- **Qué podría romperse al tocar este sistema:** altura de rebote fuera de 0.45–0.70 m; pases al espacio que no llegan a su distancia; la pelota atravesando paredes (`test_ball_stays_inside_walls`); gol detectado dos veces o con la pelota en la línea (`Goal.is_ball_in_goal`); rebote saliendo de la red.

## Limitaciones conocidas

- Durante pruebas headless con `--fixed-fps` Jolt puede imprimir `Jolt Physics job system exceeded the maximum number of jobs` (aviso del motor, visto en `test_ball_stays_inside_walls`); no se investigó su causa ni se midió en un dispositivo.
- No existe ningún `.tres` de la pelota en `resources/tuning/` (`Tuning.BALL_PATH` apunta a un archivo inexistente): los valores vigentes son los valores por defecto de `BallTuning`.
- No hay sonido de pelota (no existe sistema de audio).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base física», «Control asistido» (corrección del límite angular de Jolt y del modo de amortiguamiento) y «Esqueleto único v1.0».

## Efecto pedido y estela (2026-10-27)

- El Magnus existente curva la pelota con el giro lateral de un tiro con chanfle (1.3 m en ~17 m, `test_ball_curl`).
- Estela (`Ball._update_trail`): cinta con las últimas posiciones en tiros rápidos o con mucho efecto (solo presentación; dibuja la trayectoria real).

## Efecto natural, flotado y giro dibujado (2026-10-28)

- Cada tiro sale con el giro de su golpeo (`ShotAssist.compute`, ver [ASSISTANCE](ASSISTANCE.md#tiros-dirigidos-al-arco-efecto-natural-del-golpeo-y-arquero-2026-10-28)):
  empeine con rosca hacia el lado del pie, colocado con más rosca, potente casi sin giro con **flotado**
  (`Ball.set_knuckle`), vaselina con contragiro. Los pases ya rodaban con su giro de rodadura (`rolling_spin`) y el
  elevado con retroceso; los centros con rosca hacia el arco.
- Flotado medido (`test_ball_curl`): potente de 18 m, 3 rad/s de giro, aceleración 4.6 m/s² a 2.3 Hz: 0.15 m de desvío
  en la línea respecto al mismo tiro sin flotado.
- Giro dibujado medido (`test_ball_curl::test_drawn_ball_spin_is_readable`, 60 fps): pase a 2 / 6 / 12 m/s gira 19 /
  57 / 114° por imagen; se dibuja 18.8 / 19.9 / 19.8° con el eje real y desenfoque en 9 / 29 / 57°. Revisión visual con
  `tools/ball_spin_view.tscn` (tiras de imágenes consecutivas: pase lento nítido, pase rápido con gajos arrastrados,
  chanfle arrastrado de lado, potente sin giro con los gajos quietos).

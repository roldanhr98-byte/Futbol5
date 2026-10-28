# CAMERA — Cámara de partido

## Identificación

- **Responsabilidad exacta:** cámara elevada estilo transmisión. Sigue una mezcla entre el jugador controlado y la pelota (con anticipación por velocidad de la pelota), amortigua posición y zoom de forma independiente de los FPS, mantiene un **yaw fijo** (el joystick siempre es relativo a la pantalla) y no baja de la altura de las paredes. También convierte vectores 2D de pantalla en direcciones de mundo (`screen_to_world_dir`).
- **Estado:** implementado; **sin pruebas que comprueben su comportamiento**. `test_match_flow` instancia `MatchScene` (que crea la cámara y la hace correr), pero ninguna aserción mira el encuadre ni `screen_to_world_dir`.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-28
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/camera/match_camera.gd` | Clase `MatchCamera` (`Camera3D`) | `MatchCamera._target_focus`, `MatchCamera._target_distance`, `MatchCamera._apply_transform`, `MatchCamera.screen_to_world_dir`, `MatchCamera.snap_to_target` | `PitchConfig` (límites y altura de paredes), `Tuning.pitch` |

**Quién la crea y la usa:** `MatchScene._ready` (la instancia, `camera.setup(ball, controlled, Tuning.pitch)`), `MatchContext.screen_to_world` (la consulta), `MatchScene._on_kickoff_requested` (`snap_to_target` en cada saque).

## Mapa de parámetros

<!-- AUTO:params:MatchCamera -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `pitch_deg` | `52.0` | float | `scripts/camera/match_camera.gd:10` | `scripts/camera/match_camera.gd:142` | Camara elevada estilo transmision deportiva. Sigue una mezcla entre el jugador controlado y la pelota con amortiguacion exponencial (independiente de los FPS), ajusta el encuadre segun la separacion entre ambos y nunca entra en el volumen de las paredes. Mantiene un yaw fijo: el joystick siempre es relativo a la pantalla. Con el contexto del partido (ctx) el encuadre es dinamico: mas cerca que una vista general, se adelanta hacia donde ataca el equipo con la pelota y se abre lo justo para que las opciones de pase del poseedor sigan en cuadro. |
| `base_distance` | `16.0` | float | `scripts/camera/match_camera.gd:11` | `scripts/camera/match_camera.gd:46`, `scripts/camera/match_camera.gd:139` |  |
| `max_distance` | `27.0` | float | `scripts/camera/match_camera.gd:12` | `scripts/camera/match_camera.gd:139` |  |
| `attack_lead` | `2.5` | float | `scripts/camera/match_camera.gd:14` | `scripts/camera/match_camera.gd:92` | Metros que el foco se adelanta hacia el arco que ataca el equipo con la pelota (se ve el espacio por delante). |
| `button_bias` | `1.0` | float | `scripts/camera/match_camera.gd:16` | `scripts/camera/match_camera.gd:47`, `scripts/camera/match_camera.gd:136` | Desplazamiento lateral de la imagen (m): la jugada queda algo a la izquierda, lejos de los botones de accion. |
| `pass_options_in_frame` | `2` | int | `scripts/camera/match_camera.gd:18` | `scripts/camera/match_camera.gd:125` | Companeros del poseedor (los mas cercanos a la pelota) que el encuadre mantiene visibles como opciones de pase. |
| `pass_option_range` | `15.0` | float | `scripts/camera/match_camera.gd:20` | `scripts/camera/match_camera.gd:122` | Mas alla de esta distancia a la pelota (m) un companero no fuerza a abrir el plano. |
| `follow_halflife` | `0.22` | float | `scripts/camera/match_camera.gd:22` | `scripts/camera/match_camera.gd:72` | Semivida del suavizado de posicion (s). Mayor = camara mas lenta. |
| `zoom_halflife` | `0.55` | float | `scripts/camera/match_camera.gd:23` | `scripts/camera/match_camera.gd:73` |  |
| `ball_lead_time` | `0.28` | float | `scripts/camera/match_camera.gd:24` | `scripts/camera/match_camera.gd:83` |  |
| `focus_weight_with_ball` | `0.4` | float | `scripts/camera/match_camera.gd:25` | `scripts/camera/match_camera.gd:88` |  |
| `focus_weight_without_ball` | `0.72` | float | `scripts/camera/match_camera.gd:26` | `scripts/camera/match_camera.gd:88` |  |
| `ball` | `null` | Node3D | `scripts/camera/match_camera.gd:28` | `scripts/camera/match_camera.gd:50`, `scripts/camera/match_camera.gd:66`, `scripts/camera/match_camera.gd:79`, `scripts/camera/match_camera.gd:80` (+4) |  |
| `focus_actor` | `null` | Node3D | `scripts/camera/match_camera.gd:29` | `scripts/camera/match_camera.gd:51`, `scripts/camera/match_camera.gd:57`, `scripts/camera/match_camera.gd:85`, `scripts/camera/match_camera.gd:86` (+2) |  |
| `pitch_config` | `null` | PitchConfig | `scripts/camera/match_camera.gd:30` | `scripts/camera/match_camera.gd:44`, `scripts/camera/match_camera.gd:45`, `scripts/camera/match_camera.gd:53`, `scripts/camera/match_camera.gd:95` (+2) |  |
| `ctx` | `null` | MatchContext | `scripts/camera/match_camera.gd:32` | `scripts/gameplay/match_scene.gd:82`, `scripts/camera/match_camera.gd:102`, `scripts/camera/match_camera.gd:104`, `scripts/camera/match_camera.gd:119` | Contexto del partido (opcional): da el poseedor y sus companeros para el encuadre dinamico. |
| `_focus` | `Vector3.ZERO` | Vector3 | `scripts/camera/match_camera.gd:34` | `scripts/camera/match_camera.gd:60`, `scripts/camera/match_camera.gd:72`, `scripts/camera/match_camera.gd:144`, `scripts/camera/match_camera.gd:148` |  |
| `_distance` | `20.0` | float | `scripts/camera/match_camera.gd:35` | `scripts/camera/match_camera.gd:46`, `scripts/camera/match_camera.gd:61`, `scripts/camera/match_camera.gd:73`, `scripts/camera/match_camera.gd:143` |  |
| `_initialized` | `false` | bool | `scripts/camera/match_camera.gd:36` | `scripts/camera/match_camera.gd:63`, `scripts/camera/match_camera.gd:68` |  |
<!-- /AUTO -->

Valores fijos (no son `@export`): `fov = 42`, `near = 0.5`, `far = 140`, `keep_aspect = KEEP_HEIGHT` (`_ready`); la cámara se mantiene a `pitch_cfg.wall_height + 2.0` de altura mínima; el foco se limita a `x ∈ ±(half_length − 8)` y `z ∈ ±0.55·half_width`; el zoom crece `0.55` por metro de separación jugador-pelota por encima de 7 m (`_target_distance`); «cerca de la pelota» = a menos de 3 m (`_target_focus`).

### Riesgos al modificar

| Parámetro | Efecto real y riesgo |
|---|---|
| `pitch_deg` (55°) | Inclinación de la cámara. **Cambia la relación pantalla→mundo del joystick** (vía `screen_to_world_dir`); con ángulos bajos el eje «arriba» se comprime. |
| `base_distance` (20) / `max_distance` (30) | Distancia al foco. Más lejos = jugadores más pequeños (legibilidad en móvil). |
| `follow_halflife` (0.22 s) / `zoom_halflife` (0.55 s) | Semivida del suavizado. Menor = cámara más pegada (más movimiento); mayor = más retraso. |
| `ball_lead_time` (0.28 s) | Cuánto se adelanta el foco según la velocidad de la pelota. |
| `focus_weight_with_ball` (0.4) / `focus_weight_without_ball` (0.72) | `foco = jugador.lerp(pelota_adelantada, w)`: `w` es el peso de la **pelota** (0 = sigue solo al jugador, 1 = solo a la pelota). Con la pelota a menos de 3 m del jugador se usa 0.4; si no, 0.72. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/camera/match_camera.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchCamera._ready()` | 38 |  |
| `MatchCamera.setup(ball_node: Node3D, actor: Node3D, cfg: PitchConfig = null)` | 49 |  |
| `MatchCamera.set_focus_actor(actor: Node3D)` | 56 |  |
| `MatchCamera.snap_to_target()` | 59 |  |
| `MatchCamera._process(delta: float)` | 65 |  |
| `MatchCamera._target_focus()` | 76 |  |
| `MatchCamera._possessor()` | 101 |  |
| `MatchCamera.frame_points()` | 108 | Puntos que deben quedar en cuadro: pelota, jugador enfocado y las opciones de pase mas cercanas del poseedor. |
| `MatchCamera._target_distance()` | 130 |  |
| `MatchCamera._apply_transform()` | 141 |  |
| `MatchCamera._damp_float(current_value: float, target: float, halflife: float, delta: float)` | 150 |  |
| `MatchCamera._damp_vec3(current_value: Vector3, target: Vector3, halflife: float, delta: float)` | 154 |  |
| `MatchCamera.screen_to_world_dir(v: Vector2)` | 159 | Convierte un vector 2D de pantalla (x derecha, y abajo) en direccion de mundo sobre el plano XZ. |
<!-- /AUTO -->

## Recorrido de ejecución

1. `MatchScene._ready` → `camera.setup(ball, controlled, Tuning.pitch)` → `snap_to_target`.
2. Cada `_process`: `_target_focus` (pelota + velocidad XZ × `ball_lead_time`; si hay jugador, mezcla `a.lerp(lead_ball, w)`; `y = 0`; límites del campo) → `_damp_vec3` (suavizado exponencial por semivida) → `_target_distance` → `_apply_transform` (`look_at_from_position` desde `foco + (0, sin p, cos p)·distancia`, con `y ≥ wall_height + 2`).
3. `screen_to_world_dir(v)`: `right·v.x + back·v.y` con los ejes X y Z de la cámara proyectados sobre el plano XZ y normalizados.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh match_flow` (instancia `MatchScene` y, con ella, la cámara; solo comprueba reglas de partido).
- **Última ejecución (2026-10-26):** suite completa 57 pruebas / 212 comprobaciones sin fallos.
- **Alcance real:** **no hay ninguna prueba del encuadre, del zoom, de los límites del foco ni de `screen_to_world_dir`**. Las demás suites usan `TestCase.make_match`, que **no crea cámara**: `MatchContext.screen_to_world` cae entonces a `Vector3(v.x, 0, v.y)`. El encuadre se valida solo visualmente con `tools/shot_runner.gd` (Xvfb).
- **Qué podría romperse (y ninguna prueba lo detectaría):** joystick que «no va hacia donde apunta» tras tocar `pitch_deg`/orientación; cámara que atraviesa paredes si cambian `PitchConfig.wall_height` o las luces. Tras cualquier cambio de cámara hay que mirar una captura (`tools/shot_runner.gd`).

## Limitaciones conocidas

- `MatchCamera.set_focus_actor` no tiene llamadores (preparado para el cambio de jugador, que no existe).
- Sin sacudida, cámaras de repetición ni modo de zoom manual.
- No hay un perfil de cámara para pantallas verticales (el juego está fijado a horizontal: `display/window/handheld/orientation=0`).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base del juego».

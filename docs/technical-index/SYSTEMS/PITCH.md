# PITCH — Cancha, paredes y arcos

## Identificación

- **Responsabilidad exacta:** construir por código la cancha de futsal (por defecto 40 × 20 m): superficie, líneas reglamentarias en **una sola malla**, paredes de contención con colisión, baranda visible, iluminación, elementos ambientales; y los **arcos** (postes y travesaño con colisión física, red visible de una malla, red absorbente, detección de gol).
- **Estado:** implementado. La opción `PitchConfig.boundary_mode` está **declarada pero ningún código la usa**: las paredes siempre se construyen (`OUT_OF_BOUNDS` no existe).
- **Última verificación:** <!-- AUTO:verified -->
2026-10-26
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos / nodos | Dependencias directas |
|---|---|---|---|
| `scripts/pitch/pitch.gd` | Clase `Pitch` (`Node3D`): `build(cfg)` crea piso, líneas, paredes, arcos, luz y ambiente | `Pitch.build`, `Pitch._build_floor`, `Pitch._build_lines`, `Pitch._build_walls`, `Pitch._build_goals`, `Pitch._build_lighting`, `Pitch._build_ambient`, clase interna `Pitch.LineBuilder` | `PitchConfig`, `Goal`, `MeshUtil`, `GraphicsSettings` |
| `scripts/pitch/goal.gd` | Clase `Goal`: marco, red, volumen de red, detección de gol | `Goal.setup`, `Goal._build_frame`, `Goal._build_net`, `Goal._physics_process`, `Goal.is_ball_in_goal`, `Goal.aim_point` | `PitchConfig`, `Ball`, `MeshUtil` |
| `scripts/pitch/pitch_config.gd` | Recurso `PitchConfig` con todas las medidas | ver «Mapa de parámetros» | — |
| `scripts/pitch/mesh_util.gd` | Utilidades de malla/cuerpos estáticos/materiales | `MeshUtil.add_box_body`, `MeshUtil.add_quad`, `MeshUtil.build_mesh` | — |
| `assets/pitch/court.gdshader` | Superficie de juego (franjas y ruido, sin texturas) | uniforms `color_a`, `color_b`, `stripe_width` | — |
| `assets/pitch/net.gdshader` | Rejilla de la red con antialiasing por derivadas | uniforms `net_color`, `cell`, `line_width` | — |

**No modificar para cambiar medidas:** las posiciones de saque (`MatchScene.kickoff_positions`) y el área de colisión del piso se derivan de la configuración, salvo los números fijos indicados abajo.

## Mapa de parámetros

<!-- AUTO:params:PitchConfig -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `length` | `40.0` | float | `scripts/pitch/pitch_config.gd:10` | `scripts/ai/ai_input.gd:349`, `scripts/ai/ai_input.gd:352`, `scripts/pitch/pitch.gd:73`, `scripts/pitch/pitch.gd:85` (+5) |  (Dimensiones) |
| `width` | `20.0` | float | `scripts/pitch/pitch_config.gd:11` | `scripts/ai/ai_input.gd:354`, `scripts/gameplay/match_scene.gd:65`, `scripts/pitch/pitch.gd:74`, `scripts/pitch/pitch.gd:85` (+3) |  (Dimensiones) |
| `goal_width` | `3.0` | float | `scripts/pitch/pitch_config.gd:14` | `scripts/pitch/goal.gd:44`, `scripts/pitch/goal.gd:104`, `scripts/pitch/goal.gd:107`, `scripts/pitch/goal.gd:116` (+1) |  (Arco) |
| `goal_height` | `2.0` | float | `scripts/pitch/pitch_config.gd:15` | `scripts/assistance/shot_assist.gd:124`, `scripts/goalkeeper/goalkeeper.gd:268`, `scripts/pitch/goal.gd:39`, `scripts/pitch/goal.gd:77` (+4) |  (Arco) |
| `goal_depth` | `1.0` | float | `scripts/pitch/pitch_config.gd:16` | `scripts/pitch/goal.gd:76`, `scripts/pitch/pitch.gd:248`, `scripts/pitch/pitch.gd:249` |  (Arco) |
| `post_radius` | `0.04` | float | `scripts/pitch/pitch_config.gd:17` | `scripts/pitch/goal.gd:38`, `scripts/pitch/pitch.gd:238`, `scripts/pitch/pitch.gd:246`, `scripts/pitch/pitch.gd:249` |  (Arco) |
| `line_width` | `0.08` | float | `scripts/pitch/pitch_config.gd:20` | `scripts/pitch/pitch.gd:172`, `scripts/pitch/pitch.gd:173`, `scripts/pitch/pitch.gd:174`, `scripts/pitch/pitch.gd:182` (+5) |  (Marcas) |
| `center_circle_radius` | `3.0` | float | `scripts/pitch/pitch_config.gd:21` | `scripts/pitch/pitch.gd:182` |  (Marcas) |
| `penalty_area_radius` | `6.0` | float | `scripts/pitch/pitch_config.gd:23` | `scripts/goalkeeper/goalkeeper.gd:348`, `scripts/pitch/pitch.gd:185` | Radio de los cuartos de circulo del area de penal (desde cada poste). (Marcas) |
| `penalty_mark_distance` | `6.0` | float | `scripts/pitch/pitch_config.gd:24` | `scripts/pitch/pitch.gd:198` |  (Marcas) |
| `second_penalty_mark_distance` | `10.0` | float | `scripts/pitch/pitch_config.gd:26` | `scripts/pitch/pitch.gd:199` | Segundo punto penal (reglamento futsal, falta acumulada). (Marcas) |
| `corner_arc_radius` | `0.25` | float | `scripts/pitch/pitch_config.gd:27` | `scripts/pitch/pitch.gd:205` |  (Marcas) |
| `substitution_zone_length` | `5.0` | float | `scripts/pitch/pitch_config.gd:28` | `scripts/pitch/pitch.gd:203` |  (Marcas) |
| `boundary_mode` | `BoundaryMode.WALLS` | BoundaryMode | `scripts/pitch/pitch_config.gd:31` | **sin uso** |  (Entorno) |
| `wall_height` | `3.0` | float | `scripts/pitch/pitch_config.gd:33` | `scripts/camera/match_camera.gd:97`, `scripts/pitch/pitch.gd:223` | Altura de las paredes que mantienen la pelota en juego. (Entorno) |
| `barrier_visible_height` | `1.0` | float | `scripts/pitch/pitch_config.gd:35` | `scripts/pitch/pitch.gd:253` | Altura visible de la valla/baranda (el resto es colision invisible). (Entorno) |
| `run_off` | `2.5` | float | `scripts/pitch/pitch_config.gd:36` | `scripts/pitch/pitch.gd:73`, `scripts/pitch/pitch.gd:74` |  (Entorno) |
<!-- /AUTO -->

### Receta: «quiero cambiar el tamaño del arco» (consumidores verificados con búsqueda en el código)

Cambiar `PitchConfig.goal_width`, `goal_height`, `goal_depth` o `post_radius` (en `scripts/pitch/pitch_config.gd`) afecta a, y **solo** a:

| Consumidor | Qué usa |
|---|---|
| `Goal._build_frame` | posición/altura de postes y longitud del travesaño |
| `Goal._build_net` | malla de la red, colisiones `net_surface` y `Area3D` del volumen de red |
| `Goal.is_ball_in_goal` | regla de gol: `|z| ≤ half_goal`, `y ≤ goal_height` |
| `Goal.aim_point` | punto de mira dentro del arco (lo usa `ShotAssist`) |
| `Pitch._build_walls` | hueco de la pared de fondo (`half_goal + 2·post_radius`) y dintel sobre el arco (usa `goal_height`, `goal_depth`) |
| `Pitch._build_lines` | arcos del área de penal centrados en los postes (usa `half_goal`) |
| `ShotAssist.compute` | zona útil del arco y predicción de «a puerta» |

Quedan **fijos en el código** (no derivan del tamaño): `MatchScene.kickoff_positions` (±1.4, ±6, ±11 m), `Goal.is_ball_in_goal` exige además que el centro esté ≥ un radio de pelota tras la línea. Verificar con `tools/run_tests.sh ball_physics`, `tools/run_tests.sh shooting` y `tools/run_tests.sh match_flow`; las pruebas leen `Tuning.pitch`, así que se adaptan a medidas nuevas.

## Mapa de funciones

<!-- AUTO:funcs:scripts/pitch/pitch.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Pitch._ready()` | 19 |  |
| `Pitch.build(cfg: PitchConfig)` | 23 |  |
| `Pitch._clear()` | 33 |  |
| `Pitch.set_ball(ball: Ball)` | 38 |  |
| `Pitch.get_goal(side: int)` | 42 |  |
| `Pitch.reset_goal_latches()` | 45 |  |
| `Pitch.contains_xz(p: Vector3, margin: float = 0.0)` | 50 | Devuelve true si un punto XZ esta dentro de la superficie de juego (con margen opcional). |
| `Pitch.clamp_to_pitch(p: Vector3, margin: float = 0.3)` | 53 |  |
| `Pitch._build_floor()` | 61 |  |
| `Pitch.LineBuilder._p(x: float, z: float)` | 115 |  |
| `Pitch.LineBuilder.segment(x0: float, z0: float, x1: float, z1: float)` | 118 |  |
| `Pitch.LineBuilder._quad(a: Vector3, b: Vector3, c: Vector3, e: Vector3)` | 131 |  |
| `Pitch.LineBuilder.arc(cx: float, cz: float, r: float, a0: float, a1: float, segments: int)` | 145 | Arco de circunferencia (angulos en radianes, medidos desde +X hacia +Z). |
| `Pitch.LineBuilder.disc(cx: float, cz: float, r: float, segments: int = 14)` | 156 |  |
| `Pitch._build_lines()` | 169 |  |
| `Pitch._build_walls()` | 220 |  |
| `Pitch._add_visual_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material)` | 266 |  |
| `Pitch._build_goals()` | 278 |  |
| `Pitch._build_lighting()` | 288 |  |
| `Pitch._build_ambient()` | 318 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/pitch/goal.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Goal.setup(cfg: PitchConfig, goal_side: int)` | 19 |  |
| `Goal.set_ball(b: Ball)` | 29 |  |
| `Goal.reset_latch()` | 32 |  |
| `Goal._build_frame()` | 37 |  |
| `Goal._add_frame_piece(pos: Vector3, shape: CylinderShape3D, r: float, h: float, horizontal: bool)` | 46 |  |
| `Goal._build_net()` | 75 |  |
| `Goal._on_net_entered(body: Node3D)` | 124 |  |
| `Goal._on_net_exited(body: Node3D)` | 128 |  |
| `Goal._physics_process(_delta: float)` | 134 |  |
| `Goal.is_ball_in_goal(local_ball_pos: Vector3)` | 148 | La pelota cuenta como gol cuando su centro esta al menos un radio detras de la linea (cruzo completamente) y dentro del marco (entre postes  |
| `Goal.goal_center_world()` | 156 |  |
| `Goal.aim_point(lateral: float, height_ratio: float, margin: float)` | 161 | Punto objetivo dentro del arco. lateral: -1..1 (a lo largo de la linea, en el eje mundial Z), height: 0..1 de la altura util. |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/pitch/pitch.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Pitch.goal_scored(goal: Goal, ball_position: Vector3)` | 9 | Cancha de futsal / futbol 5. Se construye proceduralmente a partir de PitchConfig: superficie, lineas reglamentarias (una sola malla), paredes de contencion, arcos con redes, iluminacion deportiva y elementos ambientales opcionales.  Ejes: X = largo (arcos en x = +-length/2), Z = ancho, Y = arriba. |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/pitch/goal.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `Goal.goal_scored(goal: Goal, ball_position: Vector3)` | 8 | Arco: postes y travesano con colision fisica (rebotes reales), red visible de una sola malla, colisiones simples para la red y deteccion de gol cuando la pelota cruza COMPLETAMENTE la linea.  Marco local: +X apunta hacia afuera del campo (detras del arco), +Y arriba, Z lateral. |
<!-- /AUTO -->

## Recorrido de ejecución

1. `MatchScene._ready` crea `Pitch` y llama `Pitch.build(Tuning.pitch)` (también lo hace `Pitch._ready` si no se construyó antes).
2. `Pitch.build`: `_build_floor` (cuerpo estático con material `friction 0.8 / bounce 0.0`, plano con `court.gdshader`, zona exterior) → `_build_lines` (todos los trazos en una `ArrayMesh`, elevada 2.5 cm) → `_build_walls` (paredes laterales, fondos con hueco para el arco, dintel, baranda visible) → `_build_goals` (un `Goal` por lado, `side = ±1`) → `_build_lighting` (sol direccional en el grupo `sun_light`, `Environment`) → `_build_ambient` (bancos, gradas, torres de luz; se oculta según `GraphicsSettings.ambient_props_enabled`).
3. `Pitch.set_ball(ball)` entrega la pelota a cada `Goal`.
4. Cada paso de física `Goal._physics_process` convierte la posición de la pelota al marco local del arco y, si `is_ball_in_goal`, emite `goal_scored` una vez (cerrojo `_latched`, que se libera cuando la pelota vuelve a estar más de 0.5 m delante de la línea o con `reset_latch`). `Pitch` reenvía la señal; `MatchManager._on_goal` la consume.
5. La red: `Area3D` llama `Ball.enter_net`/`exit_net` (amortigua) y las superficies del grupo `net_surface` frenan el impacto (`Ball._on_body_entered`).

## Pruebas

- **Ejecutar:** `tools/run_tests.sh ball_physics` (gol, línea, postes, travesaño, paredes) y `tools/run_tests.sh match_flow` (gol → marcador).
- **Comprobación visual (renderizado por software):** `tools/shot_runner.gd` (ver [TOOLS_AND_ASSETS](TOOLS_AND_ASSETS.md)); la cancha se vio correcta en capturas del 2026-10-26 (círculo central, áreas, arcos con red, baranda, gradas).
- **Qué podría romperse:** colisiones de paredes (la pelota saldría del campo), gol doble (cerrojo), hueco de pared de fondo desalineado con los postes, altura del dintel.

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

## Limitaciones conocidas

- `PitchConfig.boundary_mode` sin efecto (ver arriba); no hay saques de banda/esquina/falta: la pelota rebota siempre en las paredes.
- Sin bancos/gradas con colisión; son meramente visuales.
- Rendimiento de la cancha no medido en un dispositivo (solo renderizado por software en el entorno de desarrollo).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base física» (cancha, arcos, red absorbente).

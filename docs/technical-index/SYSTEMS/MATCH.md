# MATCH — Reglas y flujo del partido, contexto y composición de la escena

## Identificación

- **Responsabilidad exacta:**
  - `MatchManager`: máquina de estados del partido (saque → juego → gol → saque…, pausa, fin de tiempo), marcador, reloj, goles en contra y asistencias. **No crea ni mueve entidades**: pide la reposición con la señal `kickoff_requested`.
  - `MatchContext`: vista compartida (pelota, cancha, cámara, futbolistas, `tick`, `match_time`, `input_enabled`) y bus de eventos. **No contiene reglas.**
  - `MatchScene`: raíz de composición. Crea cancha, pelota, cámara, equipos, `MatchManager`, `Hud`, y reposiciona en cada saque.
- **Estado:** implementado y probado: **4 contra 4 con arquero** por equipo (`home_field_players = away_field_players = 4`, `with_keepers`), un humano local (el compañero más cercano a la pelota se controla con el cambio de jugador, `auto_switch`) y el resto con `AIInput`; árbitro y presentación previa (`intro_seconds`, `with_referee`). Las pruebas de flujo desactivan arqueros, árbitro y presentación para aislar el reloj.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-26
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/gameplay/match_manager.gd` | Estados, marcador, reloj, saque, gol (`_on_goal`), pausa | `MatchManager.State`, `MatchManager._on_goal`, `MatchManager._begin_kickoff`, `MatchManager.toggle_pause`, `MatchManager.restart_play`, `MatchManager.restart_match` | `MatchContext`, `Pitch.goal_scored`, `Ball.touched`, `GameEvent` |
| `scripts/gameplay/match_context.gd` | Contexto compartido | `MatchContext.emit_event`, `MatchContext.attacking_goal`, `MatchContext.teammates_of`, `MatchContext.screen_to_world`, `MatchContext.keeper_defending` | `Ball`, `Pitch`, `MatchCamera`, `Footballer` |
| `scripts/gameplay/match_scene.gd` | Composición y formación de saque | `MatchScene._ready`, `MatchScene._spawn_teams`, `MatchScene.kickoff_positions`, `MatchScene._on_kickoff_requested` | todo lo anterior + `Hud`, `HumanInput`, `PlayerAttributes` |
| `scenes/main/match.tscn` | Escena principal (`run/main_scene`): un `Node3D` con `match_scene.gd`; todo lo demás se crea por código | nodo `Match` | `MatchScene` |

**No modificar para cambiar el balance de juego:** `match_manager.gd` no tiene física; el gol lo decide `Goal` (ver [PITCH](PITCH.md)).

## Mapa de parámetros

<!-- AUTO:params:MatchManager -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `duration_seconds` | `300.0` | float | `scripts/gameplay/match_manager.gd:18` | `scripts/gameplay/match_manager.gd:99`, `scripts/gameplay/match_scene.gd:68` | Duracion en segundos (0 = sin limite, util en el laboratorio). |
| `goal_celebration_seconds` | `3.0` | float | `scripts/gameplay/match_manager.gd:19` | `scripts/gameplay/match_manager.gd:139`, `scripts/gameplay/match_manager.gd:143` |  |
| `pre_kickoff_seconds` | `1.2` | float | `scripts/gameplay/match_manager.gd:20` | `scripts/gameplay/match_manager.gd:79` |  |
| `intro_seconds` | `0.0` | float | `scripts/gameplay/match_manager.gd:22` | `scripts/gameplay/match_manager.gd:78`, `scripts/gameplay/match_manager.gd:79`, `scripts/gameplay/match_scene.gd:69` | Presentacion antes del primer saque (calentamiento y arbitro). 0 = sin presentacion. |
| `assist_window_seconds` | `6.0` | float | `scripts/gameplay/match_manager.gd:24` | `scripts/gameplay/match_manager.gd:134` | Ventana para considerar asistencia el pase previo al gol. |
| `ctx` | `—` | MatchContext | `scripts/gameplay/match_manager.gd:26` | `scripts/gameplay/match_manager.gd:36`, `scripts/gameplay/match_manager.gd:37`, `scripts/gameplay/match_manager.gd:38`, `scripts/gameplay/match_manager.gd:43` (+19) |  |
| `state` | `State.PRE_KICKOFF` | State | `scripts/gameplay/match_manager.gd:27` | `scripts/ui/hud.gd:187`, `scripts/gameplay/match_manager.gd:53`, `scripts/gameplay/match_manager.gd:63`, `scripts/gameplay/match_manager.gd:66` (+6) |  |
| `score` | `[0, 0]` | Array[int] | `scripts/gameplay/match_manager.gd:28` | `scripts/ui/hud.gd:63`, `scripts/gameplay/match_manager.gd:42`, `scripts/gameplay/match_manager.gd:102`, `scripts/gameplay/match_manager.gd:103` (+3) |  |
| `kickoff_team` | `0` | int | `scripts/gameplay/match_manager.gd:29` | `scripts/gameplay/match_manager.gd:45`, `scripts/gameplay/match_manager.gd:55`, `scripts/gameplay/match_manager.gd:75` |  |
| `_state_timer` | `0.0` | float | `scripts/gameplay/match_manager.gd:31` | `scripts/gameplay/match_manager.gd:79`, `scripts/gameplay/match_manager.gd:82`, `scripts/gameplay/match_manager.gd:83`, `scripts/gameplay/match_manager.gd:92` (+4) |  |
| `_state_before_pause` | `State.PLAYING` | State | `scripts/gameplay/match_manager.gd:32` | `scripts/gameplay/match_manager.gd:54`, `scripts/gameplay/match_manager.gd:65`, `scripts/gameplay/match_manager.gd:67` |  |
| `_last_touch_time_by_actor` | `{}` | Dictionary | `scripts/gameplay/match_manager.gd:33` | `scripts/gameplay/match_manager.gd:116`, `scripts/gameplay/match_manager.gd:134` |  |
| `_last_scoring_team` | `0` | int | `scripts/gameplay/match_manager.gd:111` | `scripts/gameplay/match_manager.gd:107`, `scripts/gameplay/match_manager.gd:137` |  |
<!-- /AUTO -->

<!-- AUTO:params:MatchScene -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `duration_seconds` | `300.0` | float | `scripts/gameplay/match_scene.gd:8` | `scripts/gameplay/match_scene.gd:68` |  |
| `home_field_players` | `4` | int | `scripts/gameplay/match_scene.gd:10` | `scripts/gameplay/match_scene.gd:98` | Cantidad de futbolistas de campo por equipo en esta etapa (1 = etapa inicial). |
| `away_field_players` | `4` | int | `scripts/gameplay/match_scene.gd:11` | `scripts/gameplay/match_scene.gd:105` |  |
| `auto_switch` | `true` | bool | `scripts/gameplay/match_scene.gd:13` | `scripts/gameplay/match_scene.gd:217` | Cambia solo al jugador del humano mas cercano a la pelota cuando el actual queda lejos. |
| `ai_skill` | `0.6` | float | `scripts/gameplay/match_scene.gd:15` | `scripts/gameplay/match_scene.gd:100`, `scripts/gameplay/match_scene.gd:107`, `scripts/gameplay/match_scene.gd:243`, `scripts/gameplay/match_scene.gd:265` (+1) | Calidad de decision de la IA (0..1). |
| `intro_seconds` | `4.5` | float | `scripts/gameplay/match_scene.gd:17` | `scripts/gameplay/match_scene.gd:69` | Presentacion antes del primer saque (s): calentamiento de los jugadores y arbitro contando. 0 = sin presentacion. |
| `with_referee` | `true` | bool | `scripts/gameplay/match_scene.gd:18` | `scripts/gameplay/match_scene.gd:61` |  |
| `referee` | `null` | Referee | `scripts/gameplay/match_scene.gd:19` | `scripts/gameplay/match_scene.gd:62`, `scripts/gameplay/match_scene.gd:63`, `scripts/gameplay/match_scene.gd:64`, `scripts/gameplay/match_scene.gd:65` |  |
| `ctx` | `—` | MatchContext | `scripts/gameplay/match_scene.gd:21` | `scripts/gameplay/match_scene.gd:44`, `scripts/gameplay/match_scene.gd:53`, `scripts/gameplay/match_scene.gd:54`, `scripts/gameplay/match_scene.gd:59` (+5) |  |
| `pitch` | `—` | Pitch | `scripts/gameplay/match_scene.gd:22` | `scripts/gameplay/match_scene.gd:45`, `scripts/gameplay/match_scene.gd:46`, `scripts/gameplay/match_scene.gd:47`, `scripts/gameplay/match_scene.gd:48` (+3) |  |
| `ball` | `—` | Ball | `scripts/gameplay/match_scene.gd:23` | `scripts/gameplay/match_scene.gd:40`, `scripts/gameplay/match_scene.gd:49`, `scripts/gameplay/match_scene.gd:50`, `scripts/gameplay/match_scene.gd:51` (+11) |  |
| `camera` | `—` | MatchCamera | `scripts/gameplay/match_scene.gd:24` | `scripts/gameplay/match_scene.gd:56`, `scripts/gameplay/match_scene.gd:57`, `scripts/gameplay/match_scene.gd:58`, `scripts/gameplay/match_scene.gd:59` (+9) |  |
| `manager` | `—` | MatchManager | `scripts/gameplay/match_scene.gd:25` | `scripts/gameplay/match_scene.gd:66`, `scripts/gameplay/match_scene.gd:67`, `scripts/gameplay/match_scene.gd:68`, `scripts/gameplay/match_scene.gd:69` (+7) |  |
| `hud` | `—` | Hud | `scripts/gameplay/match_scene.gd:26` | `scripts/gameplay/match_scene.gd:73`, `scripts/gameplay/match_scene.gd:74`, `scripts/gameplay/match_scene.gd:75`, `scripts/gameplay/match_scene.gd:76` (+7) |  |
| `controlled` | `null` | Footballer | `scripts/gameplay/match_scene.gd:27` | `scripts/gameplay/match_scene.gd:86`, `scripts/gameplay/match_scene.gd:113`, `scripts/gameplay/match_scene.gd:114`, `scripts/gameplay/match_scene.gd:177` (+26) |  |
| `home` | `[]` | Array[Footballer] | `scripts/gameplay/match_scene.gd:28` | `scripts/gameplay/match_scene.gd:103`, `scripts/gameplay/match_scene.gd:112`, `scripts/gameplay/match_scene.gd:113`, `scripts/gameplay/match_scene.gd:165` (+6) |  |
| `away` | `[]` | Array[Footballer] | `scripts/gameplay/match_scene.gd:29` | `scripts/gameplay/match_scene.gd:110`, `scripts/gameplay/match_scene.gd:165` |  |
| `keepers` | `[]` | Array[Goalkeeper] | `scripts/gameplay/match_scene.gd:30` | `scripts/gameplay/match_scene.gd:124`, `scripts/gameplay/match_scene.gd:181` |  |
| `marker` | `null` | PlayerMarker | `scripts/gameplay/match_scene.gd:32` | `scripts/gameplay/match_scene.gd:82`, `scripts/gameplay/match_scene.gd:83`, `scripts/gameplay/match_scene.gd:194`, `scripts/gameplay/match_scene.gd:195` | Indicadores sobre el jugador controlado y sobre el que recibiria el control con CAMBIO. |
| `next_marker` | `null` | PlayerMarker | `scripts/gameplay/match_scene.gd:33` | `scripts/gameplay/match_scene.gd:84`, `scripts/gameplay/match_scene.gd:85`, `scripts/gameplay/match_scene.gd:196` |  |
| `controlled_keeper` | `null` | Goalkeeper | `scripts/gameplay/match_scene.gd:36` | `scripts/gameplay/match_scene.gd:177`, `scripts/gameplay/match_scene.gd:187`, `scripts/gameplay/match_scene.gd:204`, `scripts/gameplay/match_scene.gd:205` (+7) | Arquero propio bajo control de la persona (null = lo lleva la IA). Mientras lo maneja, el jugador de campo `controlled` queda en manos de la IA pero se recuerda para devolverle el control. |
| `with_keepers` | `true` | bool | `scripts/gameplay/match_scene.gd:38` | `scripts/gameplay/match_scene.gd:115` | Con false no se crean arqueros (algunas pruebas y la practica los omiten). |
| `_switch_cooldown` | `0.0` | float | `scripts/gameplay/match_scene.gd:191` | `scripts/gameplay/match_scene.gd:199`, `scripts/gameplay/match_scene.gd:217`, `scripts/gameplay/match_scene.gd:248`, `scripts/gameplay/match_scene.gd:270` (+1) |  |
<!-- /AUTO -->

`MatchScene.duration_seconds` (300) se copia a `MatchManager.duration_seconds` en `_ready`; **el valor efectivo es el de la escena**. `0` = sin límite (lo usan las pruebas).

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| `duration_seconds` | `test_pause_and_full_time` usa 3 s y espera `FULL_TIME` a los 3.5 s. |
| `goal_celebration_seconds` (3), `pre_kickoff_seconds` (1.2) | Tiempo con `input_enabled = false`. |
| `assist_window_seconds` (6) | Un pase solo cuenta como asistencia si el pasador tocó la pelota hace ≤ 6 s (`_last_touch_time_by_actor`). |
| `home_field_players` / `away_field_players` | 4 por defecto. Los jugadores que no controla el humano usan `AIInput` (roles cierre/alas/pivote); con `InputSource` vacío se quedarían quietos. Las pruebas de flujo los ponen a 1/0 y desactivan arqueros, árbitro y presentación. |
| `MatchScene.kickoff_positions` | Formación de saque de 4 jugadores por equipo (cierre, alas, pivote); los arqueros van a su arco. |
| Orden de señales `goal_scored` → `score_changed` → mensaje → evento `GOAL` | `Hud` se suscribe a `score_changed`, `clock_changed`, `message`, `state_changed`. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/gameplay/match_manager.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchManager.setup(context: MatchContext)` | 35 |  |
| `MatchManager.start_match()` | 41 |  |
| `MatchManager.restart_play()` | 52 | Reinicia la jugada actual (sin tocar el marcador): saque de centro del mismo equipo. |
| `MatchManager.restart_match()` | 58 |  |
| `MatchManager.toggle_pause()` | 62 |  |
| `MatchManager.is_playing()` | 71 |  |
| `MatchManager._begin_kickoff(team: int, intro: bool = false)` | 74 |  |
| `MatchManager._physics_process(delta: float)` | 85 |  |
| `MatchManager._on_ball_touched(actor: Node)` | 113 |  |
| `MatchManager._on_goal(goal: Goal, _ball_pos: Vector3)` | 118 |  |
| `MatchManager._set_state(s: State)` | 147 |  |
| `MatchManager.format_clock(seconds: float)` | 151 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/gameplay/match_manager.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `MatchManager.state_changed(new_state: int)` | 8 | Reglas y flujo del partido: saque, juego, gol (la pelota cruza COMPLETAMENTE la linea), celebracion, reinicio de jugada / partido, pausa y fin de tiempo. No crea ni mueve entidades por si mismo: pide a la escena que las reposicione mediante la senal kickoff_requested. Pensado para que un servidor autoritativo pueda ejecutar este mismo codigo. |
| `MatchManager.score_changed(home: int, away: int)` | 9 |  |
| `MatchManager.goal_scored(team: int, scorer_id: int, assist_id: int, own_goal: bool)` | 10 |  |
| `MatchManager.kickoff_requested(kicking_team: int)` | 11 |  |
| `MatchManager.message(text: String, seconds: float)` | 12 |  |
| `MatchManager.clock_changed(seconds: float)` | 13 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/gameplay/match_scene.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchScene._ready()` | 43 |  |
| `MatchScene._spawn_teams()` | 96 |  |
| `MatchScene._seed_ai(f: Footballer, id: int)` | 126 |  |
| `MatchScene._make_footballer(team: int, id: int, source: InputSource)` | 130 |  |
| `MatchScene._on_quit_requested()` | 140 | Con el partido como escena actual, «Salir» cierra el juego; si lo aloja otro nodo (pruebas) solo avisa. |
| `MatchScene._on_practice_requested()` | 146 | Abre la sala de practica (galeria de animaciones y malabares) y vuelve aqui con «Volver». |
| `MatchScene.kickoff_positions(team: int, kicking: bool = true)` | 154 | Formacion de saque: 4 jugadores de campo por equipo (cierre, alas, pivote); los arqueros van a su arco. El equipo que saca coloca a su pivot |
| `MatchScene._on_kickoff_requested(kicking_team: int)` | 163 |  |
| `MatchScene.human_actor()` | 176 | Nodo que maneja la persona ahora mismo: el arquero si lo ha tomado, si no el jugador de campo. Lo usan la camara y los indicadores. |
| `MatchScene.own_keeper()` | 180 | Arquero propio (el que defiende el arco de este equipo). |
| `MatchScene._charge_state()` | 186 |  |
| `MatchScene._physics_process(delta: float)` | 193 |  |
| `MatchScene._ball_in_own_third()` | 221 | true si la pelota esta en el tercio defensivo propio (zona donde tiene sentido manejar al arquero). |
| `MatchScene._keeper_is_best_candidate()` | 226 | true si al pulsar CAMBIO conviene pasar al arquero: la jugada esta en el area propia y el arquero es quien mejor puede intervenir (mas cerca |
| `MatchScene.take_keeper_control()` | 238 | Pasa el control de la persona al arquero propio: el jugador de campo que llevaba vuelve a la IA. |
| `MatchScene.release_keeper_control()` | 254 | Devuelve el control a un jugador de campo (el mas cercano a la pelota) y el arquero vuelve a la IA. |
| `MatchScene.switch_candidate()` | 276 | Companero que recibiria el control al pulsar CAMBIO: el mas cercano a la pelota, sin contar al actual. Lo usan tanto el cambio como el indic |
| `MatchScene.switch_to_nearest_to_ball()` | 289 | Pasa el control humano al companero mas cercano a la pelota (distinto del actual). |
| `MatchScene._auto_switch()` | 294 |  |
| `MatchScene._give_control(target: Footballer)` | 310 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/gameplay/match_context.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchContext.update_ball_stall(delta: float)` | 23 | Actualiza el contador de pelota muerta (lo llama MatchManager cada paso de fisica mientras se juega). |
| `MatchContext.emit_event(e: GameEvent)` | 29 |  |
| `MatchContext.register_footballer(f: Footballer)` | 34 |  |
| `MatchContext.unregister_footballer(f: Footballer)` | 38 |  |
| `MatchContext.teammates_of(p: Footballer)` | 41 |  |
| `MatchContext.opponents_of(p: Footballer)` | 48 |  |
| `MatchContext.opponents_of_team(team: int)` | 55 |  |
| `MatchContext.attacking_goal(team: int)` | 63 | Arco que ataca un equipo: el equipo 0 ataca +X. |
| `MatchContext.defending_goal(team: int)` | 66 |  |
| `MatchContext.register_keeper(k: Node)` | 69 |  |
| `MatchContext.unregister_keeper(k: Node)` | 73 |  |
| `MatchContext.keeper_defending(team: int)` | 76 |  |
| `MatchContext.nearest_footballer(pos: Vector3, team: int = -1, exclude: Footballer = null)` | 83 | Jugador (no arquero) del equipo dado mas cercano a un punto. |
| `MatchContext.screen_to_world(v: Vector2)` | 96 | Convierte un vector 2D de pantalla en direccion de mundo usando la camara si existe. |
<!-- /AUTO -->

## Recorrido de ejecución

**Arranque** (`MatchScene._ready`): `Pitch.build(Tuning.pitch)` → `Ball` en `(0, 0.2, 0)` → `MatchCamera` → equipos (`_spawn_teams`: atributos neutros `PlayerAttributes.reset_to(55)`, el primero de casa con `HumanInput`) → `MatchManager.setup(ctx)` (conecta `Pitch.goal_scored` y `Ball.touched`) → `Hud` (`bind`) → `camera.setup` → `GraphicsSettings.apply()` → `manager.start_match()`.

**Saque:** `_begin_kickoff(team)`: `input_enabled = false`, `Pitch.reset_goal_latches()`, estado `PRE_KICKOFF` durante `pre_kickoff_seconds`, señal `kickoff_requested` → `MatchScene._on_kickoff_requested`: `ball.reset_at((0, 0.11, 0))`, `place_at` de cada futbolista (equipo 0 mira a +X), `camera.snap_to_target()`. Al acabar el temporizador: `input_enabled = true`, estado `PLAYING`. El equipo que saca se registra en `kickoff_team` y en el evento, pero **las posiciones no dependen de quién saca**.

**Gol** (`_on_goal`, solo en `PLAYING`): el equipo anotador es el que ataca ese arco (arco `+X` → equipo 0). Gol en contra si el último toque fue de un equipo distinto del anotador. Asistencia: `previous_toucher` del equipo anotador, distinto del goleador y dentro de la ventana. Sube el marcador, `input_enabled = false`, estado `GOAL` durante `goal_celebration_seconds`, mensaje «¡GOL!», evento `GOAL`, y el siguiente saque lo hace el equipo que recibió el gol (`1 − _last_scoring_team`).

**Fin:** al llegar `match_time ≥ duration_seconds` (si > 0): estado `FULL_TIME`, `input_enabled = false`, mensaje con el marcador 6 s, evento `MATCH_END`.

**Pausa:** `toggle_pause` (tecla Esc, botón táctil «II», o `Hud`): `get_tree().paused`, estado `PAUSED`; restaura el estado anterior al reanudar. `MatchManager` es `PROCESS_MODE_PAUSABLE`; `Hud` y `TouchControls` son `ALWAYS`.

## Pruebas

- **Ejecutar:** `tools/run_tests.sh match_flow`.
- **Última ejecución (2026-10-26):** 6 pruebas / 28 comprobaciones sin fallos (suite completa: 57 / 212).

<!-- AUTO:tests:tests/test_match_flow.gd -->
| Prueba | Línea |
|---|---|
| `test_match_starts_with_kickoff_then_plays` | 17 |
| `test_goal_updates_score_stats_and_restarts_kickoff` | 28 |
| `test_ball_on_the_line_without_crossing_is_no_goal` | 58 |
| `test_own_goal_is_credited_to_the_opponent` | 67 |
| `test_restart_play_keeps_score_and_restart_match_resets_it` | 80 |
| `test_pause_and_full_time` | 98 |
| `test_full_scene_has_a_keeper_per_team_and_a_goal_still_counts_when_the_keeper_is_beaten` | 112 |
<!-- /AUTO -->

- **Qué podría romperse:** gol que se cuenta dos veces (se controla con `Pitch.reset_goal_latches` y el estado `PLAYING`), gol en contra mal atribuido, reloj que avanza en pausa, jugadores que no vuelven a su sitio tras un gol.

## Saque inicial y cambio de jugador

- **Saque:** `MatchScene.kickoff_positions(team, kicking)` coloca al pivote del equipo que saca a `KICKOFF_TAKER_X`
  = 0.62 m de la pelota (puede jugarla de inmediato) y al rival más adelantado a `KICKOFF_WAIT_X` = 3.4 m (fuera del
  círculo central). Medido: ejecutor a 0.62 m, rival más cercano a 3.40 m, y la pelota se pone en juego en los
  primeros 5 s (`tests/test_control_and_keeper.gd`).
- **Cambio:** `switch_candidate()` es el compañero más cercano a la pelota y lo usan tanto el botón CAMBIO como el
  indicador del siguiente jugador, así que ambos señalan siempre al mismo. Con la jugada en el tercio defensivo
  propio, CAMBIO pasa al **arquero** (`take_keeper_control`) si es quien mejor puede intervenir.

## Limitaciones conocidas

- **«Salir» no hace nada:** `Hud.quit_requested` → `MatchScene.quit_requested`, pero **nadie conecta esa señal** ni llama a `get_tree().quit()`. En un móvil no hay salida desde el menú.
- **Tras `FULL_TIME` no hay salida de la pantalla:** `toggle_pause` ignora el estado `FULL_TIME` (no se puede abrir el menú de pausa para «Reiniciar partido») y no existe pantalla de resultado. Verificado leyendo el código; la prueba `test_pause_and_full_time` solo comprueba que el partido termina y la entrada se bloquea.
- Sin reglas de saque de banda, córner, tiro libre, falta, tarjetas ni sustituciones: la pelota rebota en las paredes (ver [PITCH](PITCH.md)).
- La IA (`AIInput`) es simple: decide cada 0.12 s con reglas (tiro solo con ángulo de arco ≥ 16° y sin rival a menos de 0.95 m de la pelota, pase por presión o a un compañero libre, barullo resuelto tras 0.9 s despejando, un único portador por equipo) y no se ha calibrado contra jugadores humanos. Medido con 3 partidos de 120 s: la pelota nunca queda quieta más de ~2 s en juego y ~29 % de sus patadas se pierden por un toque rival o de un compañero (`test_ai_match`). Sin estadísticas por jugador: los eventos se emiten pero nadie los agrega.
- `MatchContext.keepers` nunca se rellena (no hay arquero; ver [GOALKEEPER](GOALKEEPER.md)).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Partido jugable».

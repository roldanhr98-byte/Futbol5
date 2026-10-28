# MATCH — Reglas y flujo del partido, contexto y composición de la escena

## Identificación

- **Responsabilidad exacta:**
  - `MatchManager`: máquina de estados del partido (saque → juego → gol → saque…, pausa, fin de tiempo), marcador, reloj, goles en contra y asistencias. **No crea ni mueve entidades**: pide la reposición con la señal `kickoff_requested`.
  - `MatchContext`: vista compartida (pelota, cancha, cámara, futbolistas, `tick`, `match_time`, `input_enabled`) y bus de eventos. **No contiene reglas.**
  - `MatchScene`: raíz de composición. Crea cancha, pelota, cámara, equipos, `MatchManager`, `Hud`, y reposiciona en cada saque.
- **Estado:** implementado y probado: **4 contra 4 con arquero** por equipo (`home_field_players = away_field_players = 4`, `with_keepers`), un humano local (el compañero más cercano a la pelota se controla con el cambio de jugador, `auto_switch`) y el resto con `AIInput`; árbitro y presentación previa (`intro_seconds`, `with_referee`). Las pruebas de flujo desactivan arqueros, árbitro y presentación para aislar el reloj.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-28
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
| `duration_seconds` | `300.0` | float | `scripts/gameplay/match_manager.gd:23` | `scripts/ui/hud.gd:219`, `scripts/gameplay/match_manager.gd:151`, `scripts/gameplay/match_scene.gd:92` | Duracion en segundos (0 = sin limite, util en el laboratorio). |
| `goal_celebration_seconds` | `3.0` | float | `scripts/gameplay/match_manager.gd:24` | `scripts/gameplay/match_manager.gd:158`, `scripts/gameplay/match_manager.gd:287`, `scripts/gameplay/match_manager.gd:291` |  |
| `replay_after_seconds` | `1.3` | float | `scripts/gameplay/match_manager.gd:26` | `scripts/gameplay/match_manager.gd:158` | Segundos de festejo en vivo antes de la repeticion del gol (0 o menos = sin repeticion). |
| `replay_active` | `false` | bool | `scripts/gameplay/match_manager.gd:28` | `scripts/gameplay/match_manager.gd:89`, `scripts/gameplay/match_scene.gd:238`, `scripts/gameplay/match_scene.gd:242` | true mientras se ve la repeticion (la pausa del juego no se puede abrir encima). |
| `_replay_done` | `false` | bool | `scripts/gameplay/match_manager.gd:29` | `scripts/gameplay/match_manager.gd:158`, `scripts/gameplay/match_manager.gd:159`, `scripts/gameplay/match_manager.gd:285` |  |
| `pre_kickoff_seconds` | `1.2` | float | `scripts/gameplay/match_manager.gd:30` | `scripts/gameplay/match_manager.gd:111` |  |
| `intro_seconds` | `0.0` | float | `scripts/gameplay/match_manager.gd:32` | `scripts/gameplay/match_manager.gd:110`, `scripts/gameplay/match_manager.gd:111`, `scripts/gameplay/match_scene.gd:94` | Presentacion antes del primer saque (calentamiento y arbitro). 0 = sin presentacion. |
| `assist_window_seconds` | `6.0` | float | `scripts/gameplay/match_manager.gd:34` | `scripts/gameplay/match_manager.gd:281` | Ventana para considerar asistencia el pase previo al gol. |
| `ctx` | `—` | MatchContext | `scripts/gameplay/match_manager.gd:36` | `scripts/gameplay/match_manager.gd:61`, `scripts/gameplay/match_manager.gd:62`, `scripts/gameplay/match_manager.gd:63`, `scripts/gameplay/match_manager.gd:64` (+37) |  |
| `state` | `State.PRE_KICKOFF` | State | `scripts/gameplay/match_manager.gd:37` | `scripts/ui/hud.gd:241`, `scripts/gameplay/match_manager.gd:79`, `scripts/gameplay/match_manager.gd:91`, `scripts/gameplay/match_manager.gd:94` (+9) |  |
| `score` | `[0, 0]` | Array[int] | `scripts/gameplay/match_manager.gd:38` | `scripts/ui/hud.gd:78`, `scripts/gameplay/match_manager.gd:68`, `scripts/gameplay/match_manager.gd:154`, `scripts/gameplay/match_manager.gd:155` (+4) |  |
| `kickoff_team` | `0` | int | `scripts/gameplay/match_manager.gd:39` | `scripts/gameplay/match_manager.gd:71`, `scripts/gameplay/match_manager.gd:81`, `scripts/gameplay/match_manager.gd:103` |  |
| `_state_timer` | `0.0` | float | `scripts/gameplay/match_manager.gd:41` | `scripts/gameplay/match_manager.gd:111`, `scripts/gameplay/match_manager.gd:114`, `scripts/gameplay/match_manager.gd:115`, `scripts/gameplay/match_manager.gd:124` (+11) |  |
| `active_set_piece` | `null` | SetPiece | `scripts/gameplay/match_manager.gd:44` | `scripts/gameplay/match_manager.gd:106`, `scripts/gameplay/match_manager.gd:136`, `scripts/gameplay/match_manager.gd:137`, `scripts/gameplay/match_manager.gd:141` (+6) | Balon parado en curso (lo crea la escena) o arquero que hace el saque de arco. El juego se reanuda cuando el saque se ejecuta de verdad (la pelota sale del pie o de las manos del ejecutor). |
| `goal_kick_keeper` | `null` | Node | `scripts/gameplay/match_manager.gd:45` | `scripts/gameplay/match_manager.gd:107`, `scripts/gameplay/match_manager.gd:227`, `scripts/gameplay/match_manager.gd:243`, `scripts/gameplay/match_manager.gd:244` (+2) |  |
| `set_piece_kind` | `""` | String | `scripts/gameplay/match_manager.gd:46` | `scripts/gameplay/match_manager.gd:223`, `scripts/gameplay/match_manager.gd:253` |  |
| `set_piece_team` | `-1` | int | `scripts/gameplay/match_manager.gd:47` | `scripts/gameplay/match_manager.gd:224` |  |
| `training` | `false` | bool | `scripts/gameplay/match_manager.gd:50` | `scripts/gameplay/match_manager.gd:162`, `scripts/gameplay/match_manager.gd:221`, `scripts/gameplay/match_scene.gd:93` | Entrenamiento (sin rivales de campo): los saques siempre los hace el equipo de la persona, salvo el saque de arco del arquero rival; tras un gol vuelve a sacar el equipo de la persona. |
| `set_piece_pos` | `Vector3.ZERO` | Vector3 | `scripts/gameplay/match_manager.gd:51` | `scripts/gameplay/match_manager.gd:225` |  |
| `set_piece_setup_seconds` | `0.9` | float | `scripts/gameplay/match_manager.gd:53` | `scripts/gameplay/match_manager.gd:232` | Segundos de pelota muerta antes de habilitar al ejecutor (la escena coloca a los jugadores). |
| `stats` | `{"throw_in": 0, "corner": 0, "goal_kick": 0, "free_kick": 0, "penalty": 0}` |  | `scripts/gameplay/match_manager.gd:56` | `scripts/gameplay/match_manager.gd:140`, `scripts/gameplay/match_manager.gd:228` |  |
| `_state_before_pause` | `State.PLAYING` | State | `scripts/gameplay/match_manager.gd:57` | `scripts/gameplay/match_manager.gd:80`, `scripts/gameplay/match_manager.gd:93`, `scripts/gameplay/match_manager.gd:95` |  |
| `_last_touch_time_by_actor` | `{}` | Dictionary | `scripts/gameplay/match_manager.gd:58` | `scripts/gameplay/match_manager.gd:263`, `scripts/gameplay/match_manager.gd:281` |  |
| `_last_scoring_team` | `0` | int | `scripts/gameplay/match_manager.gd:166` | `scripts/gameplay/match_manager.gd:162`, `scripts/gameplay/match_manager.gd:284` |  |
<!-- /AUTO -->

<!-- AUTO:params:MatchScene -->
| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |
|---|---|---|---|---|---|
| `duration_seconds` | `-1.0` | float | `scripts/gameplay/match_scene.gd:9` | `scripts/gameplay/match_scene.gd:58`, `scripts/gameplay/match_scene.gd:59`, `scripts/gameplay/match_scene.gd:62`, `scripts/gameplay/match_scene.gd:92` | Duracion del partido (s). Negativo = la que eligio la persona (3, 5, 7 o 10 minutos, ver Tuning.match_minutes). |
| `home_field_players` | `4` | int | `scripts/gameplay/match_scene.gd:11` | `scripts/gameplay/match_scene.gd:133` | Cantidad de futbolistas de campo por equipo en esta etapa (1 = etapa inicial). |
| `away_field_players` | `4` | int | `scripts/gameplay/match_scene.gd:12` | `scripts/gameplay/match_scene.gd:61`, `scripts/gameplay/match_scene.gd:140` |  |
| `auto_switch` | `true` | bool | `scripts/gameplay/match_scene.gd:14` | `scripts/gameplay/match_scene.gd:568` | Cambia solo al jugador del humano mas cercano a la pelota cuando el actual queda lejos. |
| `ai_skill` | `0.6` | float | `scripts/gameplay/match_scene.gd:16` | `scripts/gameplay/match_scene.gd:135`, `scripts/gameplay/match_scene.gd:142`, `scripts/gameplay/match_scene.gd:601`, `scripts/gameplay/match_scene.gd:623` (+1) | Calidad de decision de la IA (0..1). |
| `intro_seconds` | `4.5` | float | `scripts/gameplay/match_scene.gd:18` | `scripts/gameplay/match_scene.gd:63`, `scripts/gameplay/match_scene.gd:94` | Presentacion antes del primer saque (s): calentamiento de los jugadores y arbitro contando. 0 = sin presentacion. |
| `with_referee` | `true` | bool | `scripts/gameplay/match_scene.gd:19` | `scripts/gameplay/match_scene.gd:84` |  |
| `out_of_bounds` | `true` | bool | `scripts/gameplay/match_scene.gd:22` | `scripts/gameplay/match_scene.gd:69`, `scripts/gameplay/match_scene.gd:89` | Reglas de futbol con bandas: la pelota sale y se repone (saque de banda, corner, saque de arco). Con false, cancha cerrada con paredes (la pelota rebota y nunca sale). |
| `referee` | `null` | Referee | `scripts/gameplay/match_scene.gd:23` | `scripts/gameplay/match_scene.gd:85`, `scripts/gameplay/match_scene.gd:86`, `scripts/gameplay/match_scene.gd:87`, `scripts/gameplay/match_scene.gd:89` (+2) |  |
| `replay` | `null` | GoalReplay | `scripts/gameplay/match_scene.gd:25` | `scripts/gameplay/match_scene.gd:221`, `scripts/gameplay/match_scene.gd:222`, `scripts/gameplay/match_scene.gd:223`, `scripts/gameplay/match_scene.gd:231` (+7) | Repeticion de los goles (graba siempre; se muestra tras cada gol). |
| `goal_replays` | `true` | bool | `scripts/gameplay/match_scene.gd:26` | `scripts/gameplay/match_scene.gd:232`, `scripts/gameplay/match_scene.gd:251` |  |
| `training_mode` | `false` | bool | `scripts/gameplay/match_scene.gd:29` | `scripts/gameplay/match_scene.gd:29`, `scripts/gameplay/match_scene.gd:60`, `scripts/gameplay/match_scene.gd:93`, `scripts/gameplay/match_scene.gd:109` (+1) | Entrenamiento: tu equipo (con su arquero) contra el arquero rival SOLO, sin rivales de campo ni reloj, para probar conduccion, pases y tiros al arco. Se elige en el menu de pausa y se mantiene al reiniciar la escena. |
| `ctx` | `—` | MatchContext | `scripts/gameplay/match_scene.gd:31` | `scripts/gameplay/match_scene.gd:64`, `scripts/gameplay/match_scene.gd:75`, `scripts/gameplay/match_scene.gd:76`, `scripts/gameplay/match_scene.gd:81` (+23) |  |
| `pitch` | `—` | Pitch | `scripts/gameplay/match_scene.gd:32` | `scripts/gameplay/match_scene.gd:65`, `scripts/gameplay/match_scene.gd:66`, `scripts/gameplay/match_scene.gd:67`, `scripts/gameplay/match_scene.gd:70` (+10) |  |
| `ball` | `—` | Ball | `scripts/gameplay/match_scene.gd:33` | `scripts/gameplay/match_scene.gd:54`, `scripts/gameplay/match_scene.gd:71`, `scripts/gameplay/match_scene.gd:72`, `scripts/gameplay/match_scene.gd:73` (+18) |  |
| `camera` | `—` | MatchCamera | `scripts/gameplay/match_scene.gd:34` | `scripts/gameplay/match_scene.gd:78`, `scripts/gameplay/match_scene.gd:79`, `scripts/gameplay/match_scene.gd:80`, `scripts/gameplay/match_scene.gd:81` (+14) |  |
| `manager` | `—` | MatchManager | `scripts/gameplay/match_scene.gd:35` | `scripts/gameplay/match_scene.gd:90`, `scripts/gameplay/match_scene.gd:91`, `scripts/gameplay/match_scene.gd:92`, `scripts/gameplay/match_scene.gd:93` (+16) |  |
| `hud` | `—` | Hud | `scripts/gameplay/match_scene.gd:36` | `scripts/gameplay/match_scene.gd:99`, `scripts/gameplay/match_scene.gd:100`, `scripts/gameplay/match_scene.gd:101`, `scripts/gameplay/match_scene.gd:102` (+16) |  |
| `controlled` | `null` | Footballer | `scripts/gameplay/match_scene.gd:37` | `scripts/gameplay/match_scene.gd:119`, `scripts/gameplay/match_scene.gd:148`, `scripts/gameplay/match_scene.gd:149`, `scripts/gameplay/match_scene.gd:312` (+40) |  |
| `home` | `[]` | Array[Footballer] | `scripts/gameplay/match_scene.gd:38` | `scripts/gameplay/match_scene.gd:138`, `scripts/gameplay/match_scene.gd:147`, `scripts/gameplay/match_scene.gd:148`, `scripts/gameplay/match_scene.gd:206` (+18) |  |
| `away` | `[]` | Array[Footballer] | `scripts/gameplay/match_scene.gd:39` | `scripts/gameplay/match_scene.gd:145`, `scripts/gameplay/match_scene.gd:206`, `scripts/gameplay/match_scene.gd:209`, `scripts/gameplay/match_scene.gd:225` (+5) |  |
| `keepers` | `[]` | Array[Goalkeeper] | `scripts/gameplay/match_scene.gd:40` | `scripts/gameplay/match_scene.gd:159`, `scripts/gameplay/match_scene.gd:227`, `scripts/gameplay/match_scene.gd:272`, `scripts/gameplay/match_scene.gd:381` |  |
| `marker` | `null` | PlayerMarker | `scripts/gameplay/match_scene.gd:42` | `scripts/gameplay/match_scene.gd:111`, `scripts/gameplay/match_scene.gd:112`, `scripts/gameplay/match_scene.gd:535`, `scripts/gameplay/match_scene.gd:536` | Indicadores sobre el jugador controlado y sobre el que recibiria el control con CAMBIO. |
| `next_marker` | `null` | PlayerMarker | `scripts/gameplay/match_scene.gd:43` | `scripts/gameplay/match_scene.gd:113`, `scripts/gameplay/match_scene.gd:114`, `scripts/gameplay/match_scene.gd:537` |  |
| `possession_ring` | `null` | GroundRing | `scripts/gameplay/match_scene.gd:45` | `scripts/gameplay/match_scene.gd:115`, `scripts/gameplay/match_scene.gd:116`, `scripts/gameplay/match_scene.gd:516`, `scripts/gameplay/match_scene.gd:520` (+1) | Aro de posesion (bajo el unico jugador con la pelota) y aro del companero que recibiria el pase ahora. |
| `pass_ring` | `null` | GroundRing | `scripts/gameplay/match_scene.gd:46` | `scripts/gameplay/match_scene.gd:117`, `scripts/gameplay/match_scene.gd:118`, `scripts/gameplay/match_scene.gd:532` |  |
| `controlled_keeper` | `null` | Goalkeeper | `scripts/gameplay/match_scene.gd:50` | `scripts/gameplay/match_scene.gd:312`, `scripts/gameplay/match_scene.gd:377`, `scripts/gameplay/match_scene.gd:387`, `scripts/gameplay/match_scene.gd:401` (+13) | Arquero propio bajo control de la persona (null = lo lleva la IA). Mientras lo maneja, el jugador de campo `controlled` queda en manos de la IA pero se recuerda para devolverle el control. |
| `with_keepers` | `true` | bool | `scripts/gameplay/match_scene.gd:52` | `scripts/gameplay/match_scene.gd:150` | Con false no se crean arqueros (algunas pruebas y la practica los omiten). |
| `_last_kick_actor` | `-1` | int | `scripts/gameplay/match_scene.gd:476` | `scripts/gameplay/match_scene.gd:399`, `scripts/gameplay/match_scene.gd:489` |  |
| `_last_kick_frame` | `-1000` | int | `scripts/gameplay/match_scene.gd:477` | `scripts/gameplay/match_scene.gd:400`, `scripts/gameplay/match_scene.gd:489` |  |
| `_switch_cooldown` | `0.0` | float | `scripts/gameplay/match_scene.gd:500` | `scripts/gameplay/match_scene.gd:418`, `scripts/gameplay/match_scene.gd:542`, `scripts/gameplay/match_scene.gd:568`, `scripts/gameplay/match_scene.gd:606` (+2) |  |
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
| `MatchManager.setup(context: MatchContext)` | 60 |  |
| `MatchManager.start_match()` | 67 |  |
| `MatchManager.restart_play()` | 78 | Reinicia la jugada actual (sin tocar el marcador): saque de centro del mismo equipo. |
| `MatchManager.restart_match()` | 84 |  |
| `MatchManager.toggle_pause()` | 88 |  |
| `MatchManager.is_playing()` | 99 |  |
| `MatchManager._begin_kickoff(team: int, intro: bool = false)` | 102 |  |
| `MatchManager._physics_process(delta: float)` | 117 |  |
| `MatchManager._check_out_of_play()` | 173 | Con bandas (OUT_OF_BOUNDS): la pelota que cruza COMPLETAMENTE una linea queda fuera. Banda -> saque de banda para el rival del ultimo que la |
| `MatchManager._on_event(e: GameEvent)` | 200 | Falta: tiro libre para el equipo del jugador derribado, o penal si fue dentro del area del equipo infractor. |
| `MatchManager.in_penalty_area(p: Vector3, goal_x: float, cfg: PitchConfig)` | 214 | Area de penal de futsal: a menos de penalty_area_radius de la linea entre postes, del lado de la cancha. |
| `MatchManager._begin_set_piece(kind: String, team: int, pos: Vector3)` | 220 |  |
| `MatchManager._set_piece_taken()` | 240 |  |
| `MatchManager._end_set_piece()` | 248 |  |
| `MatchManager.is_set_piece()` | 257 |  |
| `MatchManager._on_ball_touched(actor: Node)` | 260 |  |
| `MatchManager._on_goal(goal: Goal, _ball_pos: Vector3)` | 265 |  |
| `MatchManager._set_state(s: State)` | 295 |  |
| `MatchManager.format_clock(seconds: float)` | 299 |  |
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
| `MatchManager.set_piece_requested(kind: String, team: int, pos: Vector3)` | 16 | Balon parado: la escena coloca al ejecutor y a los demas. kind: "throw_in", "corner", "goal_kick", "free_kick", "penalty"; team: equipo que saca; pos: punto del saque. |
| `MatchManager.replay_requested` | 18 | La escena muestra la repeticion del gol (pausa la simulacion mientras dura). |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/gameplay/match_scene.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchScene._ready()` | 57 |  |
| `MatchScene._spawn_teams()` | 131 |  |
| `MatchScene._seed_ai(f: Footballer, id: int)` | 161 |  |
| `MatchScene._make_footballer(team: int, id: int, source: InputSource)` | 165 |  |
| `MatchScene._on_quit_requested()` | 175 | Con el partido como escena actual, «Salir» cierra el juego; si lo aloja otro nodo (pruebas) solo avisa. |
| `MatchScene._on_training_toggle()` | 181 | Cambia entre partido normal y entrenamiento y vuelve a montar la escena. |
| `MatchScene._on_practice_requested()` | 188 | Abre la sala de practica (galeria de animaciones y malabares) y vuelve aqui con «Volver». |
| `MatchScene.kickoff_positions(team: int, kicking: bool = true)` | 196 | Formacion de saque: 4 jugadores de campo por equipo (cierre, alas, pivote); los arqueros van a su arco. El equipo que saca coloca a su pivot |
| `MatchScene._on_kickoff_requested(kicking_team: int)` | 205 |  |
| `MatchScene._setup_replay()` | 220 |  |
| `MatchScene.score_total_consistent()` | 247 | Comprobacion de coherencia (pruebas): el marcador suma los goles del partido. |
| `MatchScene._on_replay_requested()` | 250 |  |
| `MatchScene._on_set_piece_requested(kind: String, team: int, pos: Vector3)` | 262 | Prepara un balon parado: ejecutor (el mas cercano del equipo que saca; el arquero en el saque de arco), pelota en su sitio y rivales a dista |
| `MatchScene._focus_after_set_piece(taker: Footballer)` | 316 |  |
| `MatchScene._clear_zone(pos: Vector3, team: int, radius: float)` | 323 | Aleja a los rivales del equipo que saca a `radius` metros de la pelota (direccion radial, dentro de la cancha). |
| `MatchScene._arrange_box(kind: String, team: int, pos: Vector3, taker: Footballer)` | 336 | Jugada ensayada en el area rival: atacantes a primer palo, segundo palo, punto de penal y borde del area; cada defensor marca a uno por el l |
| `MatchScene.human_actor()` | 376 | Nodo que maneja la persona ahora mismo: el arquero si lo ha tomado, si no el jugador de campo. Lo usan la camara y los indicadores. |
| `MatchScene.own_keeper()` | 380 | Arquero propio (el que defiende el arco de este equipo). |
| `MatchScene._charge_state()` | 386 |  |
| `MatchScene._on_match_event(e: GameEvent)` | 397 | Con un pase de la persona el control pasa al RECEPTOR en el momento del pase (como en los juegos de futbol de consola): la persona maneja a  |
| `MatchScene.pass_receiver(passer: Footballer)` | 433 | Receptor de un pase propio sin destinatario: el companero (no el pasador) que llega antes a algun punto de la trayectoria predicha de la pel |
| `MatchScene._teammate_with_ball()` | 479 |  |
| `MatchScene.touch_context()` | 504 | Situacion para la botonera tactil: ataque (la pelota es del equipo de la persona o le llega un pase propio), defensa (la tiene el rival) o s |
| `MatchScene._update_rings()` | 515 | Aro de posesion bajo el poseedor (color de su equipo; sin aro = pelota suelta) y, con la pelota en los pies de la persona, aro bajo el compa |
| `MatchScene._physics_process(delta: float)` | 534 |  |
| `MatchScene._person_plays()` | 573 | true si una persona maneja al equipo 0 (jugador de campo o arquero). Las pruebas que dejan al equipo 0 en manos de la IA le ponen un AIInput |
| `MatchScene._ball_in_own_third()` | 579 | true si la pelota esta en el tercio defensivo propio (zona donde tiene sentido manejar al arquero). |
| `MatchScene._keeper_is_best_candidate()` | 584 | true si al pulsar CAMBIO conviene pasar al arquero: la jugada esta en el area propia y el arquero es quien mejor puede intervenir (mas cerca |
| `MatchScene.take_keeper_control()` | 596 | Pasa el control de la persona al arquero propio: el jugador de campo que llevaba vuelve a la IA. |
| `MatchScene.release_keeper_control()` | 612 | Devuelve el control a un jugador de campo (el mas cercano a la pelota) y el arquero vuelve a la IA. |
| `MatchScene.switch_candidate()` | 634 | Companero que recibiria el control al pulsar CAMBIO: el mas cercano a la pelota, sin contar al actual. Lo usan tanto el cambio como el indic |
| `MatchScene.switch_to_nearest_to_ball()` | 647 | Pasa el control humano al companero mas cercano a la pelota (distinto del actual). |
| `MatchScene._auto_switch()` | 652 |  |
| `MatchScene._give_control(target: Footballer)` | 670 |  |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/gameplay/match_context.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `MatchContext.update_possession()` | 37 | Actualiza el dueno de la pelota (una vez por paso de fisica, la llame quien la llame). |
| `MatchContext.ball_is_loose()` | 66 | Pelota sin dueno (rodando, en el aire, rebote): cualquiera puede ir a buscarla y tocarla. |
| `MatchContext.ball_locked_for(who: Node)` | 75 | true si `who` no puede tocar la pelota ahora (balon parado de otro). |
| `MatchContext.update_ball_stall(delta: float)` | 79 | Actualiza el contador de pelota muerta (lo llama MatchManager cada paso de fisica mientras se juega). |
| `MatchContext.emit_event(e: GameEvent)` | 85 |  |
| `MatchContext.register_footballer(f: Footballer)` | 90 |  |
| `MatchContext.unregister_footballer(f: Footballer)` | 94 |  |
| `MatchContext.teammates_of(p: Footballer)` | 97 |  |
| `MatchContext.opponents_of(p: Footballer)` | 104 |  |
| `MatchContext.opponents_of_team(team: int)` | 111 |  |
| `MatchContext.attacking_goal(team: int)` | 119 | Arco que ataca un equipo: el equipo 0 ataca +X. |
| `MatchContext.defending_goal(team: int)` | 122 |  |
| `MatchContext.register_keeper(k: Node)` | 125 |  |
| `MatchContext.unregister_keeper(k: Node)` | 129 |  |
| `MatchContext.keeper_defending(team: int)` | 132 |  |
| `MatchContext.nearest_footballer(pos: Vector3, team: int = -1, exclude: Footballer = null)` | 139 | Jugador (no arquero) del equipo dado mas cercano a un punto. |
| `MatchContext.screen_to_world(v: Vector2)` | 152 | Convierte un vector 2D de pantalla en direccion de mundo usando la camara si existe. |
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
| `test_match_starts_with_kickoff_then_plays` | 18 |
| `test_goal_updates_score_stats_and_restarts_kickoff` | 29 |
| `test_ball_on_the_line_without_crossing_is_no_goal` | 59 |
| `test_own_goal_is_credited_to_the_opponent` | 68 |
| `test_restart_play_keeps_score_and_restart_match_resets_it` | 81 |
| `test_pause_and_full_time` | 99 |
| `test_full_scene_has_a_keeper_per_team_and_a_goal_still_counts_when_the_keeper_is_beaten` | 113 |
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
- **La persona controla todo con la pelota (2026-10-27, pedido del usuario):**
  - Todo pase propio (raso, elevado, filtrado, centro, saque de banda) pasa el control al **receptor en el momento
    del pase** (`MatchScene._on_match_event`). Sin destinatario asignado (pase al espacio), recibe el compañero que
    llega antes a la trayectoria predicha (`MatchScene.pass_receiver`, `BallPredictor`), y se le marca el pase entrante
    (`Footballer.expect_pass(..., from)`).
  - Mientras el pase va hacia el controlado no hay cambio automático (`_auto_switch` respeta `has_incoming_pass()`):
    antes, en un pase largo, el control volvía al pasador o a otro compañero más cerca de la pelota durante el vuelo y
    el receptor quedaba en manos de la IA (medido: 60 pasos de física con el control en otro jugador en un pase de 18 m;
    ahora 0).
  - Si un compañero se queda con la pelota (control, rebote, intercepción, pase del arquero) el control pasa a él en
    el acto (`_teammate_with_ball`, también con `auto_switch` apagado; no al pasador en los 45 pasos tras su propio
    golpeo ni con la pelota pasando rápido, `HANDOVER_MAX_REL_SPEED`).
  - La IA del equipo de la persona nunca pasa ni patea: `MatchContext.human_team` (0 si la persona maneja un
    jugador o al arquero, −1 si no; `MatchScene._person_plays` mira la entrada real, no `is_human_controlled`, porque
    las pruebas que dejan el equipo 0 a la IA ponen un `AIInput` al controlado y los saques lo pasan de jugador en
    jugador marcándolo como controlado: con la primera versión la pelota quedó quieta 311 s en el partido de 7 min de
    la CI) y `AIInput._decide` no decide con la pelota para ese equipo; `_give_control` cancela cualquier carga que la
    IA hubiera empezado en el receptor.
  - Pruebas: `tests/test_pass_receiver_control.gd` (las tres primeras fallan con el código anterior).

## Limitaciones conocidas

- **«Salir» no hace nada:** `Hud.quit_requested` → `MatchScene.quit_requested`, pero **nadie conecta esa señal** ni llama a `get_tree().quit()`. En un móvil no hay salida desde el menú.
- **Tras `FULL_TIME` no hay salida de la pantalla:** `toggle_pause` ignora el estado `FULL_TIME` (no se puede abrir el menú de pausa para «Reiniciar partido») y no existe pantalla de resultado. Verificado leyendo el código; la prueba `test_pause_and_full_time` solo comprueba que el partido termina y la entrada se bloquea.
- Sin reglas de saque de banda, córner, tiro libre, falta, tarjetas ni sustituciones: la pelota rebota en las paredes (ver [PITCH](PITCH.md)).
- La IA (`AIInput`) es simple: decide cada 0.12 s con reglas (tiro solo con ángulo de arco ≥ 16° y sin rival a menos de 0.95 m de la pelota, pase por presión o a un compañero libre, barullo resuelto tras 0.9 s despejando, un único portador por equipo) y no se ha calibrado contra jugadores humanos. Medido con 3 partidos de 120 s: la pelota nunca queda quieta más de ~2 s en juego y ~29 % de sus patadas se pierden por un toque rival o de un compañero (`test_ai_match`). Sin estadísticas por jugador: los eventos se emiten pero nadie los agrega.
- `MatchContext.keepers` nunca se rellena (no hay arquero; ver [GOALKEEPER](GOALKEEPER.md)).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Partido jugable».

## Bandas, balón parado y repetición (2026-10-27)

- **Bandas:** `MatchScene.out_of_bounds` (por defecto `true`) construye la cancha con `PitchConfig.BoundaryMode.OUT_OF_BOUNDS`: las paredes se retiran `run_off` m y `MatchManager._check_out_of_play` detecta la pelota que cruza COMPLETAMENTE una línea (un gol nunca cuenta como fuera). Banda → saque de banda para el rival del último que la tocó; fondo → córner si la tocó el defensor, saque de arco si fue el atacante.
- **Faltas:** el evento `FOUL` (barrida al cuerpo, entrada por detrás) da tiro libre o penal (`MatchManager.in_penalty_area`).
- **Balón parado:** estado `SET_PIECE`; la escena elige ejecutor, aleja a los rivales 5 m (`_clear_zone`) y ordena el área en córner, penal y tiro libre cercano (`_arrange_box`). `SetPiece` ejecuta con clips de raíz real y el juego se reanuda cuando la pelota sale del pie o de las manos. Salvaguardas: al segundo golpe fallido se saca sin carrera y, si en 20 s no se sacó, `SetPiece.force`.
- **Pelota muerta:** `MatchContext.dead_ball` / `restart_taker`: solo el ejecutor puede tocarla; la IA se ofrece o marca a distancia (`AIInput._decide_dead_ball`).
- **Repetición:** `GoalReplay` graba 7 s a 30 Hz (pelota, jugadores, arqueros, árbitro y la pose de cada hueso). `MatchManager.replay_requested` se emite `replay_after_seconds` tras el gol; la escena pausa el árbol, reproduce 4.5 s antes del gol + 0.7 s después a 0.6x con su cámara y restaura el estado exacto. Cualquier botón o toque la salta.
- **Duración:** `MatchScene.duration_seconds < 0` usa `Tuning.match_minutes` (3, 5, 7 o 10; menú de pausa).
- Pruebas: `test_set_pieces`, `test_goal_replay`, `test_full_match` (partidos completos de 3, 5, 7 y 10 minutos).

## Posesión única y organización colectiva (2026-10-27)

- **`MatchContext.possessor`** (`update_possession`, una vez por paso de física): el último que la tocó la conserva
  mientras nadie más la toque y siga a ≤1.45 × su radio de posesión; si no, es suya solo si la tiene al pie y va con
  ella. `BallHandler.ball_owned_by_other` impide conducir o controlar la pelota de otro (solo disputarla o cortar un
  toque largo); `PressController` presiona al poseedor.
- **`TeamBrain`** (`scripts/ai/team_brain.gd`): una decisión por equipo cada 0.2 s. Ataque: apoyo (6.5 m, línea de pase
  libre), amplitud (banda contraria, lado con histéresis), profundidad (altura del último rival) y seguridad; en zona de
  centro, primer palo / segundo palo / penal. Defensa: un presionador (si es el de la persona, la IA no manda otro),
  una cobertura (el que llega antes al punto entre la pelota y el arco, a 6.5 m) y el bloque a ≥5 m de la pelota con la
  línea que retrocede. Pelota suelta: va uno por equipo. Reparto de puestos por coste mínimo con ventaja para conservar
  el puesto anterior (`KEEP_ROLE_BONUS`). La fase de ataque se mantiene durante un toque largo propio
  (`TEAM_POSSESSION_GRACE`). `AIInput._follow_order` ejecuta la orden (los desmarques de ruptura y las llegadas al
  área siguen siendo individuales); `AIInput.use_team_brain = false` vuelve a la lógica individual.
- **Decisiones de la IA:** el defensor contiene y entra cuando la pelota queda expuesta (toque largo) o con
  probabilidad `Footballer.AI_TACKLE_COMMIT`; el portador presionado pasa con el cuerpo a medio orientar (≤75°);
  la IA no sale de la cancha (`Footballer._keep_inside`) y rodea el arco si queda detrás de la línea
  (`AIInput._around_goal`).
- **Medido** (`test_team_shape_metrics`, `tests/match_metrics.gd`): con la fase asentada (>2 s) cada jugador está a
  2.7–4.6 m de su puesto, pero la posesión cambia cada ~1.9 s y el amontonamiento (≥4 jugadores a <4 m de la pelota)
  no bajó de forma clara (headless 41–49 %; versión anterior con render 33–55 %). Pendiente: reducir las pérdidas.

## Modo entrenamiento (2026-10-27)

Menú de pausa → «Entrenamiento sin rivales» (`MatchScene.training_mode`, se mantiene al reiniciar la escena; «Volver
al partido» lo quita). Tu equipo (4 + arquero) contra el arquero rival solo: sin rivales de campo, sin reloj que
termine, saques siempre para tu equipo salvo el saque de arco del arquero rival (`MatchManager.training`), y tras un
gol vuelve a sacar tu equipo. Sirve para probar conducción, pases y tiros al arco/arquero. Prueba:
`test_training_mode` (150 s con la IA: pases, llegadas al arco, atajadas, sin atascos).

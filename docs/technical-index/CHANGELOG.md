# CHANGELOG técnico — Fútbol 5

Historial de cambios **funcionales y estructurales**, el más reciente primero. Reglas de esta bitácora:

1. Cada entrada nombra los archivos tocados y qué se verificó **de verdad**. Una prueba que no se ejecutó se anota como «no ejecutada», nunca como aprobada.
2. Las cifras de pruebas son `pruebas / comprobaciones / fallos` de `tools/run_tests.sh` (suite headless propia).
3. El gasto de Tripo3D sale de `docs/tripo/ledger.jsonl` (no se estima).
4. Todo cambio de código debe actualizar la ficha del sistema (`python3 tools/docs_index.py sync` + `check`) y añadir aquí una línea si es funcional o estructural.

Formato de entrada: **fecha — título** · commit · qué cambió · archivos · verificación · pendiente.

---

## 2026-10-30 — Jugabilidad del modo 4: pases al compañero y tensos, golpeo que le da al balón, presión con disputa, cancha despejada

Pedido (vídeo de la 0.1.34): conducción insegura, pases débiles que no buscan compañero, presión sin animación, pase con animación
pero sin tocar la pelota; quitar público y lo de alrededor de la cancha; estudiar First Touch (xapk) y Dream League Soccer.
Detalle y medidas: [JSON_MODE](SYSTEMS/JSON_MODE.md#segunda-tanda-2026-10-30-pases-golpeo-que-no-le-daba-al-balón-presión-y-cancha-despejada).

- **Pases** (`PassAssist`, `AssistTuning`, `BallTuning`): con asistencia media o alta el pase va al compañero elegido (antes ~65 % del
  ángulo, tope 11.7°); cono 52 → 60° y cono de respaldo de 85°; llegada 4.5 → 6 m/s, mínimo 4 → 7 m/s; pase al espacio más largo y vivo.
- **Receptor** (`Footballer._recv_stick_lock`): el joystick que se traía del pase no lo aleja de la pelota.
- **Golpeo** (`BallHandler._json_kick_ik`, `kick_reach`, `PlayerTuning.json_kick_reach` = 0.55): pie llevado a la pelota (IK) al final
  del balanceo y golpeo válido hasta 0.55 m en el modo 4; golpeos en falso por partido de IA 5–6 → 0–1.
- **Giros con pelota** (`JsonBallMove.MAX_LEAD` = 0.4 s): menos primeros toques errados por interferencia; `history` para diagnóstico.
- **Presión** (`PlayerActions.press_gesture`, `JsonCatalog` «press_duel»): forcejeo al presionar pegado sin entrar (IA y persona);
  `Footballer.AI_TACKLE_COMMIT` 0.3 → 0.45.
- **Cancha** (`Pitch._build_ambient`, `MatchScene`): en el modo 4 sin gradas, bancos ni torres; borrado json_sideline.gd (JsonSideline).
- Pruebas nuevas: `test_passing::test_medium_assist_pass_goes_to_the_chosen_teammate_firmly`; `test_json_mode::test_ai_match_in_json_mode`
  comprueba ≤ 2 golpeos en falso.
- Verificación: suite completa headless 216 / 1 425 / 0 fallos (16 omitidas); con render `json_mode` 10/10 y
  `LIVE_KICKS_MODE=4 live_kicks` 4/4. Sin prueba en Android.

## 2026-10-30 — Modo 4 «Json»: las 2 022 animaciones conectadas, giros con pelota, vuelta pisando la pelota, golpeo girando y toques con el pie

Pedido: conducción con toques visibles al avanzar y en diagonal, giro con la pelota, pisar la pelota y volver atrás sin errarla, no
patear de espaldas (girarse y patear), conectar todas las animaciones del zip; y descartar el GLB de Tripo adaptado (se deformaba).
Detalle: [JSON_MODE](SYSTEMS/JSON_MODE.md).

- **Modelo**: solo el humanoide propio. Quitados json_tripo.scn, la herramienta build_json_tripo, el botón «Modelo Json» del
  menú (`Hud`) y `json_model` de `Tuning` (y de `settings.cfg`).
- **Todas las animaciones**: `make_selection.py` clasifica los 2 022 clips (listas curadas + reglas por categoría, nombre y geometría
  medida); `build_json_library.gd` genera `json_clips.res` (2 125 clips), `json_keeper.res` (476) y `json_scenes.res` (622, nueva),
  con rumbo «turn» (el juego gira al jugador con el clip), `ball_touches`, giro del golpeo (`kick_turn`), golpeo limpio (`clean`) y
  postura tendida (`lie`). ~39 MB en total.
- **Movimientos con pelota** (`scripts/player/json_ball_move.gd`, nuevo): giros con pelota, vuelta pisando la pelota (REGATE + atrás),
  regates (REGATE), frenadas y giro previo a un golpeo hacia atrás, con el clip moviendo y girando al cuerpo y la pelota yendo de un toque
  del clip al siguiente (impulsos), con IK del pie al toque.
- **Golpeo girando** (`BallHandler.plan_turn_kick`, `estimated_kick_dir`, `kick_body_yaw`; `Footballer`): con el destino a ≥ 50° del
  frente, clip de girar y patear con el cuerpo siguiendo su raíz y rumbo; a ≥ 100° sin clip que llegue, giro con pelota y después el golpeo.
- **Conducción**: IK del pie hasta la pelota en cada toque (`_json_touch_ik_*`), pie más cercano estirado en lugar del toque de rescate,
  toque de rumbo en diagonal/zigzag (`_steer_touch_ready`, `STEER_TOUCH_DEG`).
- **Acciones con rumbo** (`ActionMotion.heading_rel`, `PlayerActions.start_move`): giros sin pelota con clip (`Footballer._json_turn_move`).
- **Resto conectado**: festejos/lamentos/gestos/calentamiento/barrera/espera por rol (`JsonCatalog.situation_clip`, `AnimationCatalog`),
  reparto de alias en cada balón parado y saque inicial (`PackLibrary.vary_aliases`, `SetPiece`, `MatchManager`), caídas por carrera con
  levantarse de la misma postura (`PlayerActions._json_fall/_json_getup`), gesto de entrada de pie, levantarse y gestos del arquero
  (`Goalkeeper._json_getup`), técnicos/mascota/público (json_sideline.gd, nuevo, borrado en la entrada siguiente; `MatchScene`), nombres de rol en la
  galería (`PracticeScene.ROLE_NAMES`).
- **Rendimiento**: planificar un golpeo evalúa los 24 candidatos que mejor encajan (2.4 ms con cientos de clips); cajas de trayectoria en
  el planificador aéreo (15–18 ms). La IA usa los giros de clip con límites (con pelota ≥ 110° cada 3 s; sin pelota solo desde parado):
  sin límites pasaba de 14–17 a 6–12 pases en 90 s.
- **Verificación**: suite headless 215 / 1 416 / 0 fallos (16 omitidas, render); con render como en CI `live_feet` 7/7, `live_kicks`
  4/4, `pack_motion` 2/2, `json_mode` 10/10; en modo 4 `live_kicks` 4/4 (48–49 de 50 golpeos con contacto) y `live_feet` 6/7 (el fallo,
  «encima de la pelota al acelerar» 5 %, ya existía). Detalle en la tabla de JSON_MODE. `test_json_mode.gd` ajustado a un solo modelo.
  Sin prueba en Android.

## 2026-10-29 — Modo 4 «Json»: las animaciones JSON sobre un esqueleto canónico, con dos modelos (Tripo adaptado y humanoide realista)

Detalle: [JSON_MODE](SYSTEMS/JSON_MODE.md) · herramientas: `tools/json_anim/README.md`.

- **Datos**: `animaciones_futbol5_JSON_limpios.zip` (2 022 clips; solo posiciones de 19 articulaciones, fotogramas clave irregulares,
  raíz y metadatos de golpeo/toques/apoyos). No se versiona el zip; se versiona el resultado.
- **Retarget** (`JsonRig`, `JsonRetarget`): esqueleto canónico de 23 huesos con los nombres del futbolista y las longitudes medidas de los
  datos; cada hueso toma un marco (dirección + eje de bisagra / lateral / arriba) calculado igual en el reposo de cada modelo y en cada
  instante, e IK de dos huesos para brazos y piernas porque en los datos rodilla–tobillo (0.31–0.42 m) y codo–muñeca (0.18–0.35 m) no
  son rígidos. Tobillos, muñecas y puntas quedan a **0.0 cm** del dato; pecho 1–3 cm, cabeza 4–5 cm.
- **Conversor** (`tools/json_anim/build_json_library.gd`, selección `make_selection.py`): `json_clips.res` (263 clips de campo) y
  `json_keeper.res` (155 del arquero), 5.5 MB (`Animation.compress`; manos y puntas sin pista). Quita el rumbo del clip, recorta ciclos de
  marcha y conducción entre dos apoyos del mismo pie (empiezan en el izquierdo), mide el contacto de cada patada a 120 Hz, las
  trayectorias del pie/cabeza/manos, la suelta de los lanzamientos y la velocidad natural; cada clip declara los nombres del pack de
  Mixamo que sustituye (`alias`).
- **Modelos**: `json_tripo.scn` (la malla, UV y pesos de `player_base.glb` sin cambios sobre el esqueleto canónico en pose T) y
  `json_human.scn` (humanoide de ~7 200 triángulos con zonas de kit en `COLOR.r`, oclusión en `COLOR.g`, cara, manos y botines;
  `json_kit.gdshader`). Selector en el menú de pausa («Modelo Json», json_model; quitados el 2026-10-30 con el modelo de Tripo).
- **Juego**: `Tuning.gameplay_mode = 4`; `PackLibrary` (librerías JSON, `resolve` por alias, `by_role`, recarga al cambiar de modo);
  `JsonCatalog` (escalones de marcha, direcciones, candidatos de patada por potencia); `FootballerVisual` (ciclos con línea de
  tiempo común, sin clips de Tripo, menos inclinación propia); `BallHandler` (variedad entre patadas que encajan igual, coste de
  deslizamiento del pie de apoyo y de ajuste de zancada propios del modo, cabezazos/voleas por rol); `KeeperPlanner` (candidatos por
  rol); `SetPiece` (suelta del saque medida), `Referee` (marcha JSON), `PlayerActions` (el cuerpo no sale del área con la raíz de una
  caída), `Hud`.
- Archivos nuevos: `scripts/animation/json_{rig,retarget,catalog}.gd`, `assets/characters/json/*`, `assets/animations/json_*.res`,
  `tools/json_anim/*`, `tests/test_json_mode.gd`; modificados: ver la ficha. CI: `android.yml` verifica las librerías JSON dentro de la
  APK y corre `json_mode` con render. `tests/run_tests.gd`: `TEST_GAMEPLAY_MODE` ejecuta cualquier prueba en otro modo.
- Verificación (real, no estimada): `test_json_mode` 10/192/0 (headless; el de render 24 comprobaciones más); con render
  `LIVE_KICKS_MODE=4 test_live_kicks` **49 de 50 golpeos con contacto**, punta del pie a 0.01–0.06 m de la pelota, pie de apoyo
  ≤ 0.7 m/s; conducción con el esqueleto animado (los dos modelos) pelota a 0.41–0.64 m del cuerpo de mediana y ≤ 0.96 m de
  máximo en trote, carrera, sprint y zigzag; `TEST_GAMEPLAY_MODE=4 test_live_feet` 6 de 7 (el séptimo: «pisa la pelota» 5 % frente a
  un límite de 5 % calibrado para el modo 1). Atajada con estirada, barrida, caída, levantarse, festejo y partido completo revisados en
  imágenes. Suite headless completa (modos 1–3 sin cambios de comportamiento): 215 pruebas, 1342 comprobaciones, 0 fallos (16 omitidas, las de render).
- Pendiente: nada se probó en Android ni en un dispositivo; los toques de conducción no usan los eventos `touches` del JSON; sin clips
  de giro, de regate ni de arranque en este modo.

---

## 2026-10-29 — Modelo propio del modo 2 (Newton), saque y tarjeta de la captura, modo 3 «Tripo» y rodilla en la pisada

Detalle: [ANIMATION_PACK](SYSTEMS/ANIMATION_PACK.md#modo-2-de-jugabilidad-mocap-pack-05-soccer-2026-10-29) ·
[ANIMATIONS](SYSTEMS/ANIMATIONS.md).

- **Modelo del modo 2**: Newton, el personaje del pack, a 6 778 triángulos con su esqueleto Rokoko y los colores del
  equipo (`tools/animation_pack/build_mocap_character.tscn` → `assets/characters/mocap/mocap_player.scn`,
  `mocap_kit.gdshader`). `MocapRig` copia la pose final del futbolista (retarget inverso + IK de dos huesos en piernas y
  brazos) en jugadores, arqueros y árbitro; el esqueleto del futbolista sigue midiendo el contacto y no se dibuja.
- **Modo 2**: saque de banda con `mc_throw_in` (`SetPiece.MOCAP_THROW_*`), tarjeta amarilla del árbitro en las faltas
  (`referee_foul`). Conducciones, malabares, atajadas, defensa y tarjeta roja siguen en la galería sin disparador
  (motivo en la ficha).
- **Modo 3 · Tripo** (`Tuning.GAMEPLAY_MODES` 1–3): modelo y presets de Tripo con la patada procedural. Tripo no crea
  animaciones a medida (su API solo ofrece rigging y presets); cambiar de modo recarga el partido.
- **Rodilla en la pisada**: `TouchFootIK.ik_toe` inclina el polo de la rodilla hacia el frente del cuerpo en el modo de
  objetivo absoluto; antes la pierna se doblaba en Z al pisar la pelota en el giro.
- Archivos: `scripts/animation/mocap_rig.gd` (nuevo), `touch_foot_ik.gd`, `animation_catalog.gd`,
  `scripts/player/footballer_visual.gd`, `scripts/gameplay/set_piece.gd`, `referee.gd`, `tuning.gd`, `match_scene.gd`,
  `scripts/ui/hud.gd`, `tools/animation_pack/build_mocap_character.gd`/`.tscn` (nuevos), `tools/drag_back_view.gd`
  (`DRAG_MODE`), `tests/test_mocap_mode.gd` (+3 pruebas).
- Verificación: `test_mocap_mode` 7/79/0 headless y con render (pies y manos de Newton a ≤ 0.066 m de los del
  futbolista, saque sale a 1.55 m, árbitro con `mc_yellow_card`); con render `test_drag_back` 4/52/0 y
  `test_ball_turn` 4/53/0; `LIVE_KICKS_MODE=2 test_live_kicks` 3 de 4: **sigue fallando** el pase de primera (pie de
  apoyo 1.67 m/s, límite 1.6). Imágenes del giro con Newton revisadas (sin pliegue de rodilla). Suite headless completa:
  205 pruebas, 1149 comprobaciones, 0 fallos (15 omitidas, las de render).
- Sin gasto de Tripo.

## 2026-10-29 — Modo 2 de jugabilidad con el «Mocap Pack 05 Soccer» y evaluación de presets de Tripo

Detalle: [ANIMATION_PACK](SYSTEMS/ANIMATION_PACK.md#modo-2-de-jugabilidad-mocap-pack-05-soccer-2026-10-29) ·
[TOOLS_AND_ASSETS](SYSTEMS/TOOLS_AND_ASSETS.md) (gasto de Tripo).

- **Modo 2** (botón «Modo de juego» del menú de pausa, `Tuning.gameplay_mode`): pase, pase filtrado, tiro, vaselina,
  centro, penal y festejos con el pack de captura de movimiento de fútbol que aportó la persona (con su autorización),
  convertido al futbolista (`tools/animation_pack/build_mocap_library.tscn` → `assets/animations/mocap_clips.res`, 24
  clips `mc_*`). Los 20 clips restantes (conducción, malabares, saque de banda, atajadas, defensa, tarjetas) están en la
  galería de la sala de práctica, todavía sin disparador en partido. El modo 1 no cambia.
- **Tripo3D** (autorizado por la persona, 50 créditos, saldo 770 → 720, anotado en `docs/tripo/ledger.jsonl`): los
  presets `dribble`, `crossover_dribble`, `front_kick_01`, `front_kick_02` y `shoot` resultaron de básquet, artes
  marciales y disparo con arma (medido sobre el futbolista); quedan guardados sin usar en
  `assets/animations/source/v1_ball.glb`. Después la persona pidió no usar ninguna animación de Tripo.
- Archivos: `tools/animation_pack/build_mocap_library.gd`/`.tscn` (nuevos), `pack_retarget.gd` (`bone_map`),
  `build_pack_library.gd` (`paths_root`), `scripts/animation/animation_catalog.gd` (`mocap_mode`, `MOCAP_KICKS`,
  `MOCAP_FIELD`), `pack_library.gd` (`MOCAP_PATH`), `scripts/player/ball_handler.gd` (`MOCAP_EXTRA_LATENCY`),
  `scripts/gameplay/set_piece.gd`, `tuning.gd`, `practice_scene.gd`, `scripts/ui/hud.gd`; prueba nueva
  `tests/test_mocap_mode.gd`; `tests/test_live_kicks.gd` admite `LIVE_KICKS_MODE=2`.
- La primera imagen de cada toma de Rokoko es la pose de referencia de la captura: se descarta al convertir (los clips
  saltaban 80–177° entre la imagen 0 y la 1; `test_pack_retarget` lo detectó en `mc_celebration_1`).
- Verificación: suite headless 202 pruebas / 1129 comprobaciones: 2 fallos, ambos revisados (el salto de la imagen de
  referencia, corregido: `test_pack_retarget` 6/100/0; y `test_full_match` con 1 tiro en el partido de 3 min, que al
  repetirlo tuvo 12 — en las cuatro últimas ejecuciones 9, 5, 1 y 12 tiros: el partido simulado no es determinista y el
  umbral de 2 tiros puede fallar por azar). `test_mocap_mode` 4/58/0 (12 de 12 pases y tiros con el clip de la captura,
  pie a 0.008–0.057 m). Con render, modo 1: `test_live_kicks` 4/46/0, `test_pack_kick` 8/107/0, `test_practice` 4/39/0;
  modo 2 (`LIVE_KICKS_MODE=2`): `test_live_kicks` 3 de 4, 48 de 50 golpeos con contacto; **falla** el pase de primera
  por el pie de apoyo (patina 1.69 m/s, límite 1.6): pendiente.


## 2026-10-29 — Giro con toques, tiro con potencia, sonido, zoom de cámara y pelota suelta (respuesta a prueba03)

Detalle: [PLAYER](SYSTEMS/PLAYER.md#giro-con-toques-ballturn-2026-10-29) ·
[ASSISTANCE](SYSTEMS/ASSISTANCE.md) (potencia del tiro) · [CAMERA](SYSTEMS/CAMERA.md#zoom-de-la-persona-y-golpe-de-cámara-2026-10-29) ·
[AUDIO](SYSTEMS/AUDIO.md) (nuevo) · [BALL](SYSTEMS/BALL.md#tiro-con-más-potencia-estela-más-ancha-y-señales-de-golpe-2026-10-29).

- **Giro con toques** (`BallTurn`, nuevo; prueba03: «volver hacia atrás no me gusta… en Dream League gira mientras da
  toques al balón»): con el joystick atrás conduciendo, el jugador frena, se encorva y rodea la pelota con toques cortos
  del interior del pie de fuera (cada toque la manda adonde estará el pie en el siguiente, con el cuerpo predicho por el
  mismo mando) y sale con un toque hacia el rumbo nuevo. 180° en 0.87–0.90 s con 4 toques, de caminando a sprint, sin
  perder la pelota; con render el pie queda a 0.05–0.14 m de la superficie de la pelota en cada toque. Persona e IA.
- **La pisada (`DragBack`) pasa a ser regate**: REGATE + joystick atrás (`DragBack.request`); REGATE solo sigue siendo la
  ruleta. `DragBack.reachable` (antes privada) la usa también `BallTurn`.
- **Tiro**: preparación visible (`shot_windup` 0.12 s + 0.06 s × carga, clip casi a velocidad natural: se ve la pierna
  atrás; antes ~0.17 s en pantalla); potencia 12–30 m/s con `carga^1.5` (antes 9–27 lineal); con un rival encima pierde
  potencia (`SHOT_PRESSURE_POWER`); golpe de cámara (`MatchCamera.punch`) y estela más ancha en los tiros fuertes.
- **Golpe que rebotaba en el propio jugador**: tras un golpeo con clip el cuerpo volvía a chocar con la pelota en el paso
  siguiente (con el ajuste de zancada quedaba encima): un tiro de 18.5 m/s salía a 4.5 m/s desviado 75°. Ahora la pelota
  golpeada atraviesa al que la golpeó `KICK_GHOST_SECONDS` 0.15 s (pases, tiros, centros, voleas y cabezazos).
- **Pelota suelta**: el jugador de la persona va a buscarla solo con el joystick suelto, o ajusta el rumbo si apunta más
  o menos hacia ella (`BallHandler.loose_ball_chase`); un pase pedido antes de llegar a una pelota suelta ya no se pierde
  (`kick_approach_steer` también para ella).
- **Sonido** (nuevo, no había ninguno): autoload `Sfx` con efectos sintetizados por `tools/audio/make_sfx.py` (golpes por
  el impulso real, botes, poste, red, silbatos, festejo, «ooh», público en bucle); señales `Ball.impulse` y
  `Ball.net_hit`; interruptor «Sonido» en el menú de pausa (`Tuning.sound_on`).
- **Zoom de cámara** en el menú de pausa (`Tuning.camera_zoom`: Muy cerca / Cerca —por defecto, 0.7— / Media / Lejos).
- Archivos: `scripts/player/ball_turn.gd` (nuevo), `drag_back.gd`, `ball_handler.gd`, `footballer.gd`,
  `footballer_visual.gd`, `player_tuning.gd`, `scripts/assistance/shot_assist.gd`, `scripts/ball/ball.gd`,
  `ball_tuning.gd`, `scripts/camera/match_camera.gd`, `scripts/audio/sfx.gd` (nuevo), `scripts/gameplay/tuning.gd`,
  `match_scene.gd`, `scripts/ui/hud.gd`, `project.godot` (autoload `Sfx`), `assets/audio/*.wav` (nuevos),
  `tools/audio/make_sfx.py` (nuevo), `tools/drag_back_view.gd` (acciones `shot`, `pass`, `skill`); pruebas nuevas
  `tests/test_ball_turn.gd`, `test_loose_ball_chase.gd`, `test_audio.gd`; ajustadas `test_drag_back` (con REGATE; a la
  carrera mira al rumbo nuevo en < 0.9 s), `test_live_feet` (giros de 135°/180° medidos en 2 s: el giro con toques dura
  ~0.9 s), `test_shot_keeper` (80 tiros por caso; al palo hacia el que el empeine la cierra, colocarla no le gana al
  arquero).
- Verificación: ver el final de esta entrada.
- Tripo3D: **sin gasto**. Solo ofrece animaciones prefijadas por retarget (10 créditos cada una, consultado en el historial
  de la cuenta: tareas de 3 y 5 animaciones a 30 y 50 créditos); no crea una animación nueva ni combinada de 19 s.
- Pendiente: probar en el teléfono (sonido, zoom y golpe de cámara solo se vieron en PC); centros y cabezazos no se
  rehicieron (solo les alcanza el arreglo del rebote).

## 2026-10-28 — Rodadura de First Touch Soccer, vuelta atrás pisando la pelota y giros con la pelota que se escapa

Detalle: [DRIBBLE_DIAGNOSIS](DRIBBLE_DIAGNOSIS.md#octava-ronda-2026-10-28-first-touch-soccer-27-apk-y-videos-diferenciasfutbol) ·
[BALL](SYSTEMS/BALL.md#rodadura-tipo-first-touch-soccer-2026-10-28) ·
[PLAYER](SYSTEMS/PLAYER.md#vuelta-atrás-pisando-la-pelota-giros-y-rodadura-tipo-fts-2026-10-28-octava-ronda) ·
[ANIMATIONS](SYSTEMS/ANIMATIONS.md#control-cerrado-encorvado-y-suela-sobre-la-pelota-2026-10-28).

- **Estudio de First Touch Soccer 27** (APK: motor nativo `libFTS15.so`, no Unity; se leyó el código de máquina sin
  ejecutarlo) y de los videos `diferenciasfutbol`. La «pelota atada a una cuerda» venía de la rodadura: constante en el
  nuestro, proporcional a la velocidad en FTS (1006/1024 por imagen). La circunferencia no es la diferencia (misma
  proporción pelota/jugador). Se replicó el comportamiento, no se copió código ni recursos de FTS.
- **Rodadura** `rolling_decel` 0.55 → 0.3 + `rolling_viscous` 1.0 /s · `min(v, rolling_viscous_knee` 7 m/s`)`, con
  paso exacto y un único modelo (`Ball.roll_*`) para la física, la predicción, los pases, la presión, la conducción, los
  golpeos sobre pelota en movimiento y la pelota que llega. `pass_speed_max` 21 → 28 m/s.
- **Vuelta atrás pisando la pelota** (`DragBack`, nuevo): llegar, pisar con la suela (IK sobre la pelota), frenar con el
  cuerpo plantado, arrastrar y pivotar 180°; persona e IA. `Locomotion.step_scripted`, `TouchFootIK.set_target`.
- **Giros cerrados con la pelota que se escapa**: se sigue tras ella hasta poder tocarla (`carry_steer`,
  `ESCAPE_STEER_SPEED`). **Parada**: el toque de parada la deja quieta donde se para el cuerpo
  (`Ball.roll_speed_to_stop`). **Control cerrado** por debajo de 3.2 m/s (cualquier pie, variante `_Close`) con el
  tronco encorvado (`CARRY_CROUCH`). **Pelota encajada** entre dos cuerpos desde 0.45 m: se saca de lado.
- Archivos: `scripts/ball/ball.gd`, `ball_tuning.gd`, `ball_predictor.gd`, `scripts/assistance/kick_model.gd`,
  `pass_assist.gd`, `press_controller.gd`, `scripts/player/ball_handler.gd`, `drag_back.gd` (nuevo), `footballer.gd`,
  `footballer_visual.gd`, `locomotion.gd`, `scripts/animation/touch_foot_ik.gd`; pruebas `tests/test_drag_back.gd`
  (nueva) y ajustes de `test_ball_physics` (rodadura nueva), `test_goalkeeper` (tiro suave de 13 m/s), `test_kick_reach`
  (pelota que se escapa a 3.5×), `test_live_kicks` (las pelotas que llegan salen a la velocidad que las trae a la
  nominal), `test_pes_mechanics` (velocidad máxima del receptor); herramienta `tools/drag_back_view.tscn`.
- **Partidos**: la pelota encajada a la altura de la cadera entre dos rivales trababa un partido de 5 min (169 s); ahora
  se saca de lado (`RESTING_BALL_MIN_Y`, `_body_partner`). `MatchManager` cuenta la pelota muerta
  (`ball_stall_seconds`) solo con la pelota en juego (tras un gol la pelota quieta en la red sumaba hasta 3 s).
- Verificación (ejecutada): suite headless **187 pruebas / 1003 comprobaciones / 0 fallos** (15 omitidas: necesitan
  render). Con render (xvfb): `drag_back` 4/4, `live_feet` 7/7, `dribble_reference` 2/2, `live_kicks` 4/4 (batería de 50
  acciones: 49 con contacto, antes 44), `pack_motion` 2/2, `gameplay_feel` **10/10** (antes 8/10), `dribbling` 7/7,
  `kick_reach` 2/2, `kick_timing` 3/3, `animation_contact_audit` 1/1, `shot_keeper` 1/1. Partidos de 3/5/7/10 min:
  pelota quieta como mucho 0.8–1.3 s, 113 pases y 39 tiros en 10 min; 13 partidos de 5 min con semillas distintas:
  0.7–3.2 s. Conducción (pelota delante p5/media/p95, antes → ahora): carrera 0.54/0.57/0.63 → 0.48/0.72/0.82 m, trote
  0.40/0.48/0.51 → 0.27/0.42/0.50 m. Vuelta atrás vista en imágenes renderizadas (`tools/drag_back_view.tscn`).
- Archivos (además): `scripts/gameplay/match_manager.gd`.
- Pendiente: el límite de 22.5° del rumbo del toque de FTS, el control orientado y la vuelta pisando a sprint (hoy, la
  media vuelta por el costado).

## 2026-10-28 — Red de tela, cámara de transmisión como PES e inclinación del tronco (videos `videoplayback` y `referencia_conduccion`)

Detalle: [PITCH](SYSTEMS/PITCH.md#red-de-tela-2026-10-28) · [CAMERA](SYSTEMS/CAMERA.md#encuadre-de-transmisión-como-pes-2026-10-28) ·
[ANIMATIONS](SYSTEMS/ANIMATIONS.md#inclinación-del-tronco-en-curvas-y-cambios-de-ritmo-2026-10-28) ·
[DRIBBLE_DIAGNOSIS](DRIBBLE_DIAGNOSIS.md#séptima-ronda-2026-10-28-videos-videoplayback-y-referencia_conduccion_recortada).

- **Red de tela** (`GoalNet`, nuevo): cuatro paños atados al marco que la pelota abomba (hasta ~0.6 m con un tiro de
  25–30 m/s), la tela la frena y casi no la devuelve (8–11 % de la velocidad), y vuelve con ondas; por fuera la red
  lateral se hunde y el techo sostiene la pelota. Sustituye la red rígida (88 % de la velocidad perdida de golpe al tocar
  una caja y amortiguación en todo el volumen del arco). BallTuning.net_damping/net_restitution (eliminados) → `net_stiffness`,
  `net_damp_in`, `net_damp_out`, `net_return`, `net_grip`, `net_max_bulge`. Gol: la pelota entera bajo el travesaño.
- **Cámara de transmisión** como la del video de PES: 30° de inclinación, lente de 28°, 30–38 m (antes 52°, 42°,
  16–27 m).
- **Inclinación del tronco** hacia dentro de las curvas (física × 0.75, hasta 22°) y hacia delante/atrás al
  acelerar/frenar, en la columna (`ProceduralPose`), sin mover los pies.
- Archivos: `scripts/pitch/goal_net.gd` (nuevo), `scripts/pitch/goal.gd`, `scripts/ball/ball.gd`,
  `scripts/ball/ball_tuning.gd`, `scripts/camera/match_camera.gd`, `scripts/animation/procedural_pose.gd`,
  `scripts/player/footballer_visual.gd`; prueba `tests/test_goal_net.gd` (nueva); herramienta `tools/net_view.tscn`.
- Verificación (ejecutada): suite headless 183 pruebas / 951 comprobaciones / 0 fallos (15 omitidas: necesitan render).
  Con render: `live_feet` 7/7, `live_kicks` 4/4, `pack_motion` 2/2, `kick_reach` 2/2, `dribbling` 7/7, `kick_timing`
  3/3, `animation_contact_audit` 1/1, `dribble_reference` 2/2, `shot_keeper` 1/1; `gameplay_feel` 8/10 con los mismos
  dos fallos de antes. Curvas a velocidad con la inclinación (5 semillas): sin cambios (0.33 / 0.38 / 0.09 / 0.13 /
  0.63 m). Red vista en imágenes renderizadas de frente y de costado; cámara comparada con el video en tres encuadres.
- Pendiente: giros cerrados con la pelota pegada (interior/suela), control orientado y cuerpo agachado al frenar.

## 2026-10-28 — Tiros dirigidos al arco (PES/FIFA), efecto natural de cada golpeo, flotado y giro visible del balón

Detalle: [ASSISTANCE](SYSTEMS/ASSISTANCE.md#tiros-dirigidos-al-arco-efecto-natural-del-golpeo-y-arquero-2026-10-28) ·
[BALL](SYSTEMS/BALL.md#efecto-natural-flotado-y-giro-dibujado-2026-10-28).

- **Tiro asistido rehecho** (`ShotAssist.compute`): el punto de mira está siempre dentro del arco; el joystick elige el
  punto (donde cruza la línea de gol; fuera del arco, el palo de ese lado) a `ShotAssist.aim_edge` del ancho útil
  (0.85–1.0 según precisión y definición); sin lado pedido, lejos del arquero (colocado: palo lejano). Con asistencia
  ≥ `ASSIST_FULL` 0.4 la dirección va del todo al punto; 0 = manual. La calidad la decide la ejecución: carga,
  equilibrio, desalineación del cuerpo, velocidad, presión rival (`SHOT_PRESSURE_ERROR`, ×1.8 con un rival encima),
  pierna débil, compostura y definición.
- **Efecto natural del golpeo**: empeine con rosca hacia el lado del pie (8–16 rad/s según cuánto cruza el tiro por
  delante del cuerpo), colocado con 26 rad/s, ambos con la salida abierta para cerrar en el punto de mira cuando van por
  el aire; potente casi sin giro con **flotado** (`KickResult.knuckle_*`, `Ball.set_knuckle`: aceleración lateral
  oscilante en el aire, 0.1–0.3 m en 18 m); vaselina con contragiro 20 rad/s. `KickModel.kicks_with_right`: con la
  pelota justo delante golpea el pie bueno (antes el ruido numérico podía elegir la pierna débil).
- **Giro dibujado** (`Ball._process`, `ball.gdshader`): el patrón se repite cada ~63° y a 6 m/s el giro real de 55° por
  imagen hacía que la pelota se viera quieta (a 10 m/s, al revés). Ahora la malla gira con el eje real hasta 20° por
  imagen y el shader desenfoca el patrón a lo largo del giro real de medio fotograma (obturador). Herramienta de revisión
  `tools/ball_spin_view.tscn`.
- Archivos: `scripts/assistance/shot_assist.gd`, `scripts/assistance/kick_model.gd`, `scripts/ball/ball.gd`,
  `assets/ball/ball.gdshader`, `scripts/player/ball_handler.gd`; pruebas `tests/test_shot_keeper.gd` (nueva),
  `tests/test_ball_curl.gd` (efecto natural por tipo de tiro, giro dibujado), `tests/test_shooting.gd` (la prueba de
  «la asistencia se desvanece apuntando fuera» se sustituye por «el tiro asistido siempre va al arco y el joystick elige
  el lado»).
- Verificación (ejecutada): suite headless 180 pruebas / 928 comprobaciones / 0 fallos (15 omitidas: necesitan render).
  Con render: `shot_keeper` 1/1 (40 tiros físicos por caso: al arquero ataja 89 %, al palo hacia el que rosca el empeine
  79 %, al palo del que la aleja 41 %, con rival encima 100 % y 0 goles, potente de 18 m 70 % con 9 goles por el
  flotado; el tirador de 85 marca 8 frente a 6 del de 60 en el palo difícil), `ball_curl` 4/4, `live_kicks` 4/4,
  `kick_reach` 2/2. Revisión visual de imágenes consecutivas del balón (pase lento, pase rápido, chanfle, potente).
- Pendiente: el arquero no lee el efecto (`BallPredictor` sin Magnus; replanifica cada 0.08 s); al palo del que el
  empeine la aleja entra la mitad de los tiros de 11 m sin oposición (similar a un doble penal de futsal).

## 2026-10-28 — Conducción con toques de clip, curvas a velocidad e IK del pie

Detalle: [PLAYER](SYSTEMS/PLAYER.md#toques-de-clip-conducción-con-animación-de-toque-e-ik-del-pie-2026-10-28-quinta-ronda) ·
[DRIBBLE_DIAGNOSIS](DRIBBLE_DIAGNOSIS.md#sexta-ronda-2026-10-28-toques-de-clip-curvas-a-velocidad-e-ik-del-pie).

- Toques de conducción con animación (0 créditos): 33 clips de toque por balanceo (`TouchClipBuilder`,
  `assets/animations/touch_clips.res`), disparo en fase con el ciclo de marcha, plan sobre la punta medida y el cuerpo
  previsto, contacto por evento con el pie vivo, IK del pie en tiempo real (`TouchFootIK`), impulso con llegada a
  velocidad relativa ~0. Arrancada con los toques largos de siempre; giros de más de 50° con la conducción de giro.
- Curvas a velocidad: el cuerpo no se adelanta más de 8° al rumbo de la pelota hasta el siguiente toque (antes giraba
  hasta 360°/s y la dejaba a 0.8 m al costado). Pelota al costado p95: arco 0.64 → 0.09 m, cambio de carril 0.76 →
  0.13 m, eslalon 0.49 → 0.33 m (carrera) y 0.74 → 0.38 m (sprint).
- Archivos: `scripts/player/ball_handler.gd`, `scripts/animation/touch_foot_ik.gd` (nuevo),
  `scripts/player/footballer_visual.gd`, `scripts/player/footballer.gd`, `tools/animation_pack/*touch*`; pruebas
  `test_dribble_reference` (casos de ritmo, arrancada, curvas, varias semillas) y `test_live_feet` (zigzag en 4 pasadas,
  arrancada hasta 0.75 m, justificado en la prueba).
- Verificación (ejecutada, versión final): suite headless 180 / 928 / 0 fallos; con render `live_feet` 7/7,
  `live_kicks` 4/4, `pack_motion` 2/2, `kick_reach` 2/2, `dribbling` 7/7, `kick_timing` 3/3,
  `animation_contact_audit` 1/1, `dribble_reference` 2/2; `gameplay_feel` 8/10: fallan «recibir corriendo sin frenar»
  (mínimo 0.65 m/s, se pide > 1.1) y «a sprint el toque es más largo» (0.64 frente a 0.50 m, se piden +0.25), que ya
  fallaban en el commit anterior a esta ronda.
- Pendiente: zigzag cerrado sin animación de toque (conducción de giro); las dos pruebas de sensación de arriba.

## 2026-10-28 — Acceso a Tripo3D y fuentes de animación de conducción (sin gasto)

- Comprobado: sin conector/MCP de Tripo; la API oficial responde desde el entorno (401 sin clave); la sesión no tiene clave
  (no se accedió a la cuenta, 0 créditos gastados). Capacidades reales según la documentación oficial: presets, rig,
  retarget, importación y conversión; **sin animación a medida**. Herramienta `tools/tripo/tripo_api.py` preparada (clave
  solo por variable de entorno, simulación por defecto, tope y reserva de créditos, registro en el ledger; no probada
  contra la cuenta).
- Fuente gratuita verificada: «Free mocap pack 05: Soccer» (3 `Dribble` de captura real, golpeos, defensa; FBX 60 fps;
  uso comercial gratuito). Pendiente de que la persona la descargue.
- Pases y tiros existentes medidos en el contacto (interior, empeine, por debajo): no falta ninguno básico.
- Detalle: [DRIBBLE_DIAGNOSIS.md](DRIBBLE_DIAGNOSIS.md#quinta-ronda-2026-10-28-acceso-a-tripo3d-y-fuentes-de-animación-verificadas).

## 2026-10-28 — Conducción y golpeos frente a los videos A/B: diagnóstico medido, inventario de animaciones, golpeo con la pelota fuera del alcance

Detalle y evidencia: [DRIBBLE_DIAGNOSIS.md](DRIBBLE_DIAGNOSIS.md) · inventario: [ANIMATION_INVENTORY.md](ANIMATION_INVENTORY.md).

- **Fase A (medida):** video B (FTS27) con seguimiento automático: un toque cada 0.60–0.66 s, pelota 0.3–1.2 m por
  delante, deriva lateral ±0.2 m. Nuestro juego con render (`test_dribble_reference`): trote 0.67 s; carrera un toque
  por paso alternando pies (0.27 s, 83 % de alternancia, ±0.17 m de deriva); sprint 3 de 8 toques sin pie cerca. En el
  video A la pelota viaja bajo el cuerpo (25.6–26.8 s) y un tiro cargado no sale (57.6–59.5 s).
- **Fase B:** `FootTrajectory` (nuevo) mide la trayectoria real de los pies de las 171 animaciones (133 FBX + 38
  espejos) sobre el esqueleto del jugador; 171/171 con todas sus pistas enlazadas. **No hay animación de carrera con
  toques integrados**: `Dribble_2` mueve los pies como un trote (pie bajo a 0.16–0.26 m; un trote 0.17–0.24 m) y ningún
  clip cumple `FootTrajectory.dribble_verdict`.
- **Fase C: detenida** (sin cambios en distancias, cadencias ni toques de conducción). Propuesta y procedimiento para
  crear el clip (Tripo3D solo aplica presets; `preset:biped:dribble` sin verificar; alternativas Mixamo / texto a
  movimiento) y validación automática con `DRIBBLE_CANDIDATE`. No se accedió a Tripo ni se gastaron créditos.
- **Fase D:** golpeo pedido con la pelota propia por delante fuera del alcance: el jugador ajusta la carrera
  (`BallHandler.kick_approach_steer`, sin tope de conducción), la orden espera mientras se acerca (hasta 1.4 s) o se
  cancela con `KICK_WHIFF out_of_reach`; sin toques sin pie yendo a golpear; toque de preparación mientras se carga en
  carrera. Diagnóstico `BallHandler.last_touch_foot`.
- **Una misma base persona/IA:** comprobado (`test_shared_ball_mechanics`): la IA no toca la pelota fuera de su
  `BallHandler`.
- Archivos: `scripts/animation/foot_trajectory.gd` (nuevo), `scripts/player/ball_handler.gd`,
  `scripts/player/footballer.gd`; pruebas nuevas `test_animation_inventory`, `test_kick_reach`,
  `test_shared_ball_mechanics`, `test_dribble_reference`; herramientas `tools/animation_pack/pack_clip_sheet.tscn` y
  `tools/dribble_demo/dribble_demo.tscn` (demo grabable).
- Verificación (ejecutada, versión final): suite headless 176 pruebas / 893 comprobaciones / 0 fallos (14 omitidas:
  necesitan render); con render `live_feet` 7/7, `live_kicks` 4/4 (48/50 golpeos con contacto, 2 anulados porque el
  rival tocó antes, 0 inválidos), `pack_motion` 2/2, `dribble_reference` 1/1, `kick_reach` 2/2 (7/7 golpeos con el pie a
  0.02–0.17 m, 0 toques sin pie antes del golpe; antes del cambio 3 de esas situaciones terminaban sin golpeo).
  Grabación de la prueba controlada: 26.7 s (801 fotogramas a 30 fps).
- Pendiente: el clip de conducción en carrera (con su espejo); al integrarlo, toques en los instantes del clip,
  impulso a partir del pie y eliminación de los rescates sin pie.

## 2026-10-27 — Corrección: el equipo 0 manejado por la IA no se queda quieto con la pelota

- La CI (run 16) falló en `test_full_match::test_seven_minute_match`: pelota quieta 311 s. Con el equipo 0 en manos de
  la IA, un saque pasaba el control (un `AIInput`) al ejecutor marcándolo como controlado; `human_team` lo tomaba por
  la persona y la IA no jugaba la pelota. Ahora `MatchScene._person_plays` exige una entrada que no sea `AIInput`.
- Reproducido en `test_pass_receiver_control::test_ai_teams_still_play_without_a_human` (con la regla anterior:
  pelota quieta 26.6 s, nadie del equipo 0 con la pelota; con la corrección: 1.8 s, 3 jugadores con la pelota).
- Verificación (ejecutada): `test_pass_receiver_control` 4/4 (16 comprobaciones); suite headless 169 pruebas / 871
  comprobaciones / 1 fallo: `test_ai_match` «hay tiros (0)» en el partido IA contra IA de 120 s, que no es
  determinista. Medido 5 veces con cada versión: tiros 1, 5, 2, 5, 6 con el código anterior y 2, 1, 4, 3, 8 con el
  actual (misma distribución); en una de las 5 corridas actuales falló «nadie se sale de la cancha» por 1 muestra.
  Pendiente: hacer determinista ese partido (las semillas de la IA no bastan). Partido de 7 min: pelota quieta máx.
  0.7 s.

## 2026-10-27 — La persona controla todo: el receptor de cada pase pasa a ser suyo

Pedido del usuario: «al realizar un pase el jugador receptor automáticamente pasa a ser controlado por mí; no quiero
que la IA decida si pasa o tira». Detalle en [SYSTEMS/MATCH.md](SYSTEMS/MATCH.md#saque-inicial-y-cambio-de-jugador).

- **Fallos reproducidos** (con `tests/test_pass_receiver_control.gd` sobre el código anterior): en un pase de 18 m el
  control volvía a otro jugador durante 60 pasos de física del vuelo (el cambio automático elegía al más cercano a la
  pelota, que era el pasador) y el receptor recibía con la IA; un pase al espacio sin destinatario no cambiaba el
  control; un compañero con la pelota al pie seguía con la IA. Además el pase entrante se cancelaba en los primeros
  pasos porque el pasador aún contaba como poseedor (fallaba `test_pes_mechanics` en la suite anterior).
- **Corrección:** cambio al receptor en todo pase propio, con destinatario o el que llega antes a la trayectoria
  predicha (`MatchScene.pass_receiver`); sin cambio automático con un pase en camino al controlado; control inmediato
  al compañero que se queda con la pelota; la IA del equipo de la persona no pasa ni patea (`MatchContext.human_team`,
  `AIInput._decide`); `_give_control` cancela una carga de la IA; `Footballer.expect_pass(..., from)` no cancela el pase
  por el propio pasador.
- **Reloj de simulación:** las reglas «no tocar/perseguir el propio envío» (0.7 s) y «no controlar la pelota recién
  tocada» (450 ms) usaban el reloj del sistema; ahora pasos de física (`BallHandler.seconds_since_kick`). Era la causa
  del fallo de `test_pack_kick` (el jugador perseguía su propio pase a 0.96 m/s con el joystick suelto). Las pruebas
  simulan a ~2× tiempo real (medido: 602 pasos en 5.0 s con render): los 450 ms valían 0.9 s de juego en las pruebas y
  0.45 s en el móvil. Con 0.45 s la curva con render bajó a 10/18 toques con el pie; se fija
  `OWN_TOUCH_NO_CONTROL_SECONDS` = 0.9 s (el valor medido) y vuelve a 11/18 (zigzag 10/14).
- Archivos: `match_scene.gd`, `match_context.gd`, `ai_input.gd`, `footballer.gd`, `ball_handler.gd`, `set_piece.gd`,
  `tests/test_pass_receiver_control.gd` (nuevo).
- Verificación (ejecutada, versión final): `test_pass_receiver_control` 4/4 (14 comprobaciones; 3 de las 4 fallan sin
  el cambio); suite headless completa 169 pruebas / 869 comprobaciones / 0 fallos (13 omitidas: necesitan render); con
  render `live_feet` 7/7 (curva 11/18 con el pie, zigzag 10/14) y `live_kicks` 4/4 (batería: 49/50 con contacto, 1
  anulada porque el rival tocó antes, 0 inválidos, 0 bloqueos).

## 2026-10-27 — Conducción tras el video `videofutbol` (tercera ronda)

Detalle y cifras en [SYSTEMS/PLAYER.md](SYSTEMS/PLAYER.md#conducción-tras-el-video-videofutbol-2026-10-27-tercera-ronda)
y [ANIMATION_CONTACT_AUDIT.md](ANIMATION_CONTACT_AUDIT.md).

- Soltar el joystick: el jugador acompaña y para la pelota (`settle_steer`); giros que avanzan con la pelota
  (`carry_turn_scale`); media vuelta por el costado; el cuerpo no frena su propia pelota; `lateral_max_stick` 0.5;
  contacto con todo el pie; compañeros que no se pegan al portador (`TeamBrain` pasillo, `AIInput._make_way`).
- Verificación (ejecutada, render): `live_feet` 7/7, `live_kicks` 4/4 (48/50 golpes con contacto, 2 anulados por
  toque rival, 0 inválidos). Suite headless de esa ronda: 164 pruebas, 2 fallos (`test_pack_kick` ajuste de zancada y
  `test_pes_mechanics` receptor), corregidos en la entrada de arriba.
- Limitación: en curvas cerradas continuas 39 % de toques de rescate; el pack no tiene clips de pisada ni de empuje.

## 2026-10-27 — Modo entrenamiento: tu equipo contra el arquero rival solo

- Menú de pausa → «Entrenamiento sin rivales» / «Volver al partido» (`match_scene.gd`, `match_manager.gd`, `hud.gd`).
- Sin rivales de campo ni reloj; los saques son de tu equipo salvo el saque de arco del arquero rival; tras un gol
  saca tu equipo.
- Verificación (ejecutada): `test_training_mode` 1/1 (12 comprobaciones; 150 s con la IA: 9 pases, 3 goles, 8
  atajadas, el arquero devuelve la pelota, pelota quieta como máximo 1.5 s); `touch_controls`, `match_flow`,
  `control_and_keeper`, `set_pieces` sin fallos; captura con render del modo y del menú.

## 2026-10-27 — Auditoría de jugabilidad: golpe sincronizado con el pie, pie de apoyo, conducción en giros, posesión única, organización colectiva, cámara y botonera contextual

Diagnóstico con el esqueleto animado (render) y el video del usuario `prueba01` (fotograma a fotograma). Detalle en
[SYSTEMS/PLAYER.md](SYSTEMS/PLAYER.md#patadas-sincronizadas-pie-de-apoyo-y-conducción-en-giros-2026-10-27-segunda-ronda).

- **Fallos hallados en el video:** (8.0–9.9 s) con TIRO cargando el jugador gira hacia el arco y deja la pelota, que sale
  por la banda; pelota diminuta con la cámara lejana; los botones tapan el arco de la derecha; PASE pulsado sin tener la
  pelota (35 s); amontonamientos (22–25 s).
- **Golpeo** (`ball_handler.gd`): latencia cuantizada a pasos de física con la pose de contacto en el paso del impulso;
  pie de apoyo plantado con la velocidad que pide el clip; joystick sin efecto durante el balanceo; ajuste de paso en
  lazo cerrado; golpeo de primera que espera la pelota que llega. Sin contacto no hay impulso (ya existía; verificado).
- **Conducción:** recuperar la pelota propia tras un giro (`carry_steer`), toque de media vuelta, toque sobre el arco en
  curva, toque de arrancada con SPRINT; `has_possession()` = pelota al pie y no es de otro.
- **Posesión única** (`match_context.gd`): `MatchContext.possessor` arbitra; nadie conduce ni controla la pelota de
  otro (solo disputa o corta un toque largo). La presión busca al poseedor.
- **IA colectiva** (`scripts/ai/team_brain.gd`, nuevo): una decisión por equipo con puestos (apoyo, amplitud,
  profundidad, seguridad / presión única, cobertura, bloque, repliegue), histéresis de puestos y de lado, fase de ataque
  estable durante toques largos; la IA contiene y entra cuando la pelota queda expuesta (`AI_TACKLE_COMMIT`) y pasa
  medio orientada bajo presión.
- **Cámara** (`match_camera.gd`): 16 m (antes 20), adelantada hacia el ataque, se abre para mantener en cuadro las dos
  opciones de pase del poseedor, imagen desplazada lejos de los botones (`button_bias`).
- **Interfaz:** aro de posesión bajo el poseedor y aro del compañero que recibiría el pase (`ground_ring.gd`,
  `PassAssist.pick_target`, la misma elección que el pase real); botonera contextual (ataque: TIRO/PASE/FILTRADO/CENTRO;
  defensa: ENTRADA/PRESIÓN en los mismos huecos; suelta: TIRO/PASE/PRESIÓN), más baja.
- **Pruebas nuevas:** `test_live_kicks` (pie de apoyo, golpeo de primera, batería de 50 golpeos variados),
  `test_live_feet::test_curved_dribble_acceleration_and_turns_with_the_ball`, `test_team_shape_metrics` (informe).
- **Verificación con render (ejecutada, xvfb):** `test_live_kicks` 4/4 — 49 de 50 golpeos con la punta del pie a ≤0.30 m
  de la pelota en la imagen del golpe, 1 cancelado porque el rival tocó antes, 0 impulsos sin contacto, 0 bloqueos; pie de
  apoyo 0.4–1.3 m/s (antes 1.4–7.4). `test_live_feet` 4/4 — curva 100 % con la pelota cerca (antes 83 %), medias vueltas
  100 % (antes 44 %), zigzag 18/21 toques con el pie (una versión intermedia de esta ronda había bajado a 8/16; corregido).
- **Organización colectiva, medida con render (xvfb, 2 partidos de 90 s, misma prueba en la versión anterior y en
  esta, `test_team_shape_metrics`):** cambios de posesión/min 44 / 22 → 12.7 / 18.7; disputas/min 19.3 / 20.7 → 11.3 /
  11.3; pases/min 9.3 / 6.7 → 6.0 / 10.7. **No mejora** el amontonamiento (≥4 jugadores a <4 m de la pelota: 55.1 /
  32.6 % → 51.1 / 40.8 %) y **empeoran** la separación entre compañeros (5.3 / 5.8 → 3.8 / 4.0 m) y la profundidad del
  equipo con la pelota (12.1 / 12.7 → 6.9 / 7.3 m): el reparto de puestos deja al equipo demasiado corto. Diagnóstico
  (headless): con la fase asentada (>2 s) cada jugador está a 2.7–4.6 m de su puesto; la posesión cambia cada ~1.9 s.
  **Pendiente**: profundidad y separación del TeamBrain.
- **Regresiones encontradas por la suite y corregidas en esta misma ronda:** a sprint 7 de 8 pases fallaban el golpe
  (ajuste de zancada que no cabía antes de plantar el pie); un jugador parado salía desplazado tras patear (velocidad
  del pie plantado en la locomoción; clip al trote elegido parado); el toque de arrancada perdía la pelota en giros a
  sprint (6/20) y alargaba más al jugador hábil; **partido de 10 min trabado 436.8 s**: la pelota quedó quieta a 1.6 m
  encajada entre las cabezas de dos jugadores (ahora se la quitan con un toque, `_shrug_resting_ball`); un defensor
  reculando cruzaba la línea de fondo y otro quedaba detrás del arco (IA dentro de la cancha, rodeo del arco).
- **Pruebas ajustadas (con motivo escrito en cada una):** `test_touch_controls` prueba cada botón en su contexto (más
  una prueba nueva de contexto); `test_pes_mechanics::test_referee…` congela a los jugadores para medir solo al
  árbitro; `test_gameplay_feel::test_receiving…` umbral 1.2 → 1.1 m/s (el pase sale un paso antes con la latencia
  cuantizada; la curva de velocidad del receptor es la misma: mínimo 1.25 → 1.14 m/s medido en ambas versiones).
  `test_dribbling::test_better_ball_carrying…` pasa con poco margen (novato 1.24 m, hábil 1.23 m; antes 1.33 / 1.23).
- **Suite headless (ejecutada):** `tools/run_tests.sh` → **159 pruebas, 0 fallidas, 10 omitidas (necesitan render),
  824 comprobaciones**; partidos de 3/5/7/10 min hasta el pitazo final, pelota quieta como máximo 2.4 s, 42/57/74/112
  pases. **Con render (xvfb, ejecutadas):** `test_live_kicks` 4/4, `test_live_feet` 4/4, `test_pack_motion` 2/2.

## 2026-10-27 — Jugabilidad inspirada en PES 2021: pies en la pelota, pases filtrados, centros, chanfle, entradas, reglas con bandas, balón parado, repetición y los 133 clips en juego

Análisis de los videos, tabla de mecánicas, diagnóstico, archivos y limitaciones: [GAMEPLAY_PES.md](GAMEPLAY_PES.md).

- **Conducción y recepción con el pie real** (`ball_handler.gd`): con el esqueleto animado cada toque lo da una punta de
  pie que llega a la pelota. Medido con render: antes el pie estaba a 0.81 / 1.15 / 1.07 m de la pelota en el toque
  (trote / carrera / sprint); ahora la mediana punta–centro de pelota es 0.27 / 0.23 / 0.23 m (radio de la pelota 0.11),
  con la pelota controlada el 100 % del tiempo y 18 de 21 toques con el pie en zigzag. La recepción ocurre a ~0.5 m del
  cuerpo (antes 1.05 m). En headless se mantiene la cadencia de la marcha.
- **Pases:** filtrado al espacio (`PassAssist.compute_through`), centros elevado / tenso / raso con zonas y llegada de
  compañeros (`cross_assist.gd`), presión rival en el error, control al receptor al pasar, receptor que sale al punto de
  encuentro, pared.
- **Tiro:** colocado (palo lejano, más preciso), potente y **chanfle** (giro lateral con el Magnus real, 1.3 m de curva en
  ~17 m; gesto: girar el joystick al soltar TIRO). Estela en tiros rápidos o con efecto.
- **Defensa:** botón ENTRADA (de pie, carga con el hombro, barrida, entrada al aire); mantener PRESIÓN ya no roba (la IA
  sí disputa); faltas sancionadas; bloqueo de tiro; IA con cobertura del cierre y corte de líneas de pase.
- **Reglas con bandas:** saque de banda, córner, saque de arco, tiro libre y penal con clips de raíz real; salvaguardas
  para que ningún saque trabe el partido (hallado por el partido de 7 min: el ejecutor del penal chocaba con jugadores
  colocados en su carrera).
- **Arquero:** saque de arco colocando la pelota, achique en el mano a mano, salida a centros (ajusta los pasos para que
  las manos lleguen), estirada desesperada, pelota en las manos de su clip de reposo, indicaciones al equipo.
- **Animaciones:** los 40 clips que solo estaban en la galería tienen disparador (marcha, transiciones, balón parado,
  arquero, defensa, caídas, recepción, árbitro con gemelos con raíz). Estado 133/133 integrado.
- **Repetición de goles** (`goal_replay.gd`) en cámara lenta con su cámara, saltable. **Duración** del partido 3/5/7/10 min.
- **Controles:** FILTRADO, CENTRO y ENTRADA táctiles; mando configurado; tamaño de botones y sensibilidad del joystick.
- **Verificación (ejecutada):** `tools/run_tests.sh` → **151 pruebas, 0 fallidas, 5 omitidas (necesitan render), 814
  comprobaciones**. Con render (`xvfb-run`): `test_live_feet` 3/3 y `test_pack_motion` 2/2 (pie a 0.008 m de la pelota en
  el pase y 0.026 m en el tiro). Partidos completos de IA (`test_full_match`): 3 min 1-0, 5 min 1-2, 7 min 4-1, 10 min 7-1,
  todos hasta el pitazo final, una repetición por gol (15 de 15), pelota nunca trabada más de 1.3 s.
- **No verificado:** rendimiento y controles en un teléfono real (no hay dispositivo en el entorno).

---

## 2026-10-26 — Proyecto listo para un repositorio público

- Las animaciones van dentro del juego ya convertidas (`pack_clips.res`, `pack_keeper.res`); los FBX originales (`pack/`) salen del repositorio (`/pack/` en `.gitignore`) y solo se usan en local para reconvertir. Los tests no los necesitan.
- Workflow: se eliminó el aviso por repositorio no privado y se añadió la entrada `publish_release`: crea una pre-release de prueba (`apk-prueba-N`) con el APK adjunto y descarga pública sin cuenta de GitHub; no usa la cuota de artefactos y, si la subida del artefacto falla, la ejecución no se marca como fallida. Por defecto el APK sigue siendo solo un artefacto.
- `README.md` nuevo (cómo probar el juego, controles, desarrollo). `ANDROID.md` reescrito (la versión anterior describía secretos de firma que ya no se usan).
- Corregido: en PC la acción regate compartía la tecla K con el tiro; ahora es U.

---

## 2026-10-26 — Control cercano del balón, arquero manejable e indicadores (jugabilidad tipo simulador)

**Qué cambió, con medidas antes → después.** El problema de fondo era que la pelota vivía lejos del pie y el
jugador la perseguía: parado o caminando no la tocaba nunca (la conducción solo se activaba con el joystick a
fondo), y al soltar el mando la pelota seguía rodando sola.

**Conducción (`scripts/player/ball_handler.gd`, `player_tuning.gd`)**
- Una sola ley: la pelota se coloca a `carry_gap(velocidad)` del pie (0.38 m parado, 0.70 trote, 1.20 sprint) y el
  toque es siempre un impulso calculado para que llegue allí cuando llegue el jugador.
- Modos de toque `settle` / `lateral` / `redirect` / `setup` / `carry` (ver [PLAYER](SYSTEMS/PLAYER.md)): parar la
  pelota al soltar el joystick (también frenando desde sprint), control lateral sin girar el cuerpo, giro cerrado
  con la pelota pegada, toque de preparación cuando hay un pase o tiro pulsado.
- Protección: con un rival cerca el portador le da la espalda y coloca la pelota del lado protegido.
- Un jugador ya no vuelve a tocar su propio pase recién ejecutado, ni "conduce" un balón que le llega rápido (eso
  es primer toque).
- Medidas: conducción lenta 0.58–0.65 m (antes no había toques a esa velocidad); frenar desde sprint deja la pelota
  a 0.35 m (antes se iba a 11 m); giro de 180° parado 0.39 m; pase pulsado a sprint 12/12 (antes 4/12).

**Animación (`footballer_visual.gd`)**
- Capa de marcha CON balón (`Soccer_Idle`, `Dribble_2`) mezclada sobre la normal según la posesión, con su propia
  escala de tiempo. El control lateral y la protección usan la mezcla direccional existente.

**Arquero (`goalkeeper.gd`, `keeper_tuning.gd`)**
- `input_source`: el arquero propio se puede manejar. Obedece el joystick, no se lanza solo mientras la persona lo
  mueve, atrapa o despeja con el botón y saca cuando se le ordena.
- Una cedida de un compañero (< 11 m/s) ya no se trata como disparo: sale a su encuentro, la para con el pie y la
  juega con un pase de pie. Un disparo rival a 16 m/s desde la misma zona sí provoca la estirada.

**Partido (`match_scene.gd`, `ui/player_marker.gd`, `ai/ai_input.gd`, `press_controller.gd`)**
- Indicadores 3D: cono cian sobre el jugador controlado y cono ámbar sobre el siguiente; siguen la posición real y
  cambian con el jugador.
- CAMBIO pasa al arquero cuando la jugada está en el área propia; vuelve al campo al alejarse.
- Saque inicial: el equipo que saca pone a su pivote a 0.62 m de la pelota y el rival respeta el círculo central
  (antes ambos estaban a 1.4 m y el saque quedaba vacío).
- IA de toque: pasa por presión, por progreso o por paciencia (2.2 s con la pelota); cono de tiro que se abre con la
  distancia (antes un tiro centrado a 11 m quedaba prohibido); marca por zona en el área propia; no cuenta con el
  jugador humano para ir a por la pelota; detector de jugada muerta (`MatchContext.ball_stall_seconds`).
- Presión: el defensor rodea al portador para atacar la pelota por el lado libre, y proteger el balón parado deja de
  ser indefinido. Medidas por partido de 120 s: 9–16 pases (antes 1–6), 3–7 tiros (antes 0–2), pelota nunca quieta
  más de ~2 s (antes hasta 167 s).

**Verificación:** headless 121 pruebas / 686 comprobaciones / 0 fallos / 2 omitidas (render). Con render por filtro:
`gameplay_feel`, `control_and_keeper`, `goalkeeper`, `pack_motion`, `player_actions`, `practice`, todas sin fallos.
Capturas con Xvfb revisadas a mano (conducción, saque, indicadores). **No probado:** ningún teléfono real, ni la IA
contra personas.

---

## 2026-10-26 — Pasada de calidad de jugabilidad (medida con partidos y escenarios reales)

**Qué se encontró al medir, no al suponer:** (1) un giro de 90°–180° con la pelota, incluso al trote, la perdía 1–3 s (hasta 6 m); (2) la IA se atascaba disparando contra la esquina del arco (ángulo casi nulo) y un partido llegó a tener la pelota quieta 167 s; (3) más de la mitad de las patadas de la IA se perdían (toque de un rival o de un compañero durante el balanceo); (4) casi no había pases; (5) el visitante vestía la camiseta del local; (6) el arquero casi no atajaba en partido.

**Cambios:**
- `scripts/player/ball_handler.gd`: toque de redirección hacia el rumbo nuevo con el recorrido real del jugador en un giro cerrado (frena antes de acelerar), tope del error del toque (`touch_error_max_deg`), toque de recuperación (`touch_escape_factor`), sin recuperación inmediata tras una redirección, la cápsula propia ignora la pelota durante el balanceo de una patada con clip, espera de hasta 0.5 s a que un pie llegue, y datos de interferencia en el registro de patadas.
- `scripts/ai/ai_input.gd`: tiro solo con ángulo de arco ≥ 16° (se cancela si se cierra durante la carga), no patea con un rival a punto de llegar a la pelota, un único portador por equipo, más pases, casi se detiene al cargar, conduce hasta el borde del área chica (no dentro de la red) y rompe el barullo tras 0.9 s despejando.
- `scripts/goalkeeper/goalkeeper.gd`: lee el cuerpo del rival (reacción hasta 0.22 s antes) y recoge la pelota parada en el área aunque haya rivales cerca (barullo).
- `scripts/player/footballer.gd`: el equipo visitante usa su camiseta. `scripts/player/player_actions.gd`: dolor en el suelo tras una zancadilla, empujones, barrida 3.
- Pruebas nuevas: `tests/test_gameplay_feel.gd` (giros, pase pulsado en carrera, control de un pase) y una prueba de partidos completos sin bloqueos ni tiros imposibles en `test_ai_match.gd`.

**Medidas antes → después:** giros con pelota que la pierden (60/90/135/−90°): trote ~60 % → 0/20, carrera ~50 % → 0/20, sprint ~70 % → 1/20. Pelota quieta en juego: hasta 167 s → máx. ~2 s. Patadas de la IA al aire: 73 % → ~30 %. Tiros desde ángulo cerrado: frecuentes → 0. Pases por partido de 2 min: ~5 → ~12. Pase pulsado a ritmo de carrera: 12/12 (sprint 12/12).

**Verificación:** headless 106 pruebas / 631 comprobaciones / 0 fallos / 2 omitidas (render); con render por filtro: `gameplay_feel`, `goalkeeper`, `player_actions`, `pack_kick` sin fallos. **No probado:** la IA contra humanos, un teléfono real.

---

## 2026-10-26 — Juego completo con las 133 animaciones: arquero, IA 4v4, acciones, sala de práctica

**Commits:** ver `git log` de la rama (varios). **Cambio funcional y estructural grande; nada se probó en un dispositivo Android.**

- **Pack completo:** el conversor (`build_pack_library.gd`, `make_selection.py`) convierte los 133 clips (134 en `pack_clips.res` con espejos, 37 en `pack_keeper.res`) con raíz separada, trayectorias de punta de pie, rodilla, cabeza y manos y un `role` por clip. FBX (`pack/`; la exportación los excluye de la APK) y librerías **se versionan** (uso personal; la licencia es responsabilidad del propietario). `export_presets.cfg` ya incluye `pack_keeper.res`; el workflow solo avisa si el repositorio no es privado y verifica ambas librerías dentro de la APK.
- **Arquero** (`scripts/goalkeeper/goalkeeper.gd`, `keeper_planner.gd`, `scripts/ball/ball_predictor.gd`): posicionamiento, predicción, atajada elegida por la trayectoria de manos de cada clip, bloqueo/desvío por impulso, recogida y saque. Ver [GOALKEEPER](SYSTEMS/GOALKEEPER.md).
- **IA 4+arquero contra 4+arquero** (`scripts/ai/ai_input.gd`), cambio de jugador, árbitro y presentación (`referee.gd`, `intro_seconds`), botón REGATE / tecla K.
- **Acciones de cuerpo completo** (`player_actions.gd`, `action_motion.gd`): barrida planificada (3 clips), caídas por contacto, empujones, dolor y levantarse, ruleta, tropiezo; voleas y cabezazos con planificador aéreo en `BallHandler`; jockey de marcaje con mezcla direccional de 8 sentidos.
- **Sala de práctica** (`practice_scene.gd`, `scenes/practice/practice.tscn`, botón «Práctica de animaciones» de la pausa) con los 133 clips por grupo y **malabares** (`juggle_controller.gd`).
- **Corregido:** los jugadores del equipo visitante vestían la camiseta del local (el kit se aplicaba antes de conocer el equipo); el menú de pausa se salía de la pantalla (ahora 2 columnas).
- **Verificación (real):** headless 102 pruebas / 620 comprobaciones / 0 fallos / 2 omitidas (render); con render por filtro: `pack_motion`, `goalkeeper`, `practice`, `player_actions`, `pack_reactions`, `aerial_kicks` sin fallos. La suite completa con render **no se terminó** (`test_ai_match` es demasiado lenta con `llvmpipe`). Capturas con Xvfb de la sala de práctica y del menú de pausa revisadas a mano.
- **Estado de los clips:** 93 con disparador en partido, 40 solo en la galería (lista en [ANIMATION_PACK_CLIPS](ANIMATION_PACK_CLIPS.md)). Tasa de atajadas medida: 75 % / 67 % / 42 % a 9 / 15 / 24 m/s.
- **Pendiente / límites:** prueba en un teléfono físico; calibrar la IA contra humanos; los 40 clips de galería no tienen disparador en partido; el run de GitHub Actions nº 4 pasó pruebas, exportación y firma pero no pudo subir el artefacto por la cuota de almacenamiento de la cuenta.

---

## 2026-10-26 — APK firmada con el pack: workflow y estado real

**Commits:** `26857a6` (preset y workflow), `a610139` (pack dentro de la APK, publicación segura). **No hay APK publicada todavía.**

- Repositorio comprobado como **privado** (API de GitHub). `assets/animations/pack_clips.res` (1.9 MB) se versiona por ello; el workflow se detiene si el repositorio deja de ser privado o si falta la librería.
- Run nº 1 (`26857a6`, flujo anterior): Godot, SDK, importación, pruebas headless, exportación y verificación de firma **pasaron en el runner**; se detuvo por falta de secretos.
- Run nº 2 (`a610139`, run 40325812455): **falló en el primer paso a propósito: faltan los tres secretos** `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` y `ANDROID_KEY_ALIAS`. No se firmó ni publicó nada. Los pasos de pruebas con el pack, exportación con el pack, verificación de contenido y publicación **no se han ejecutado en el runner**; se probaron en local (APK de 29.5 MB, librería idéntica, 16 clips presentes, sin FBX).
- Pendiente: crear los secretos con `tools/android/make_keystore.sh` y relanzar; prueba en un teléfono físico.

---

## 2026-10-26 — Integración del pack de animaciones y contacto pie–pelota con clips

**Commit:** el de este cambio (ver `git log`). **Integra 14 clips del pack con disparador real y prueba; corrige la conducción a carrera y sprint; no gasta créditos de Tripo (saldo 770); no elimina ningún clip de Tripo ni archivo del pack. Nada se probó en Android.**

**Añadido**
- `tools/animation_pack/build_pack_library.gd`, `build_pack_library.tscn` y `selection.json`: conversor offline (38 clips de campo y 23 de arquero) a `assets/animations/pack_clips.res` y `pack_keeper.res` con metadatos medidos (velocidad natural, raíz separada, contacto y trayectoria de la punta del pie). **Las librerías y los FBX no se versionan** (`.gitignore`; licencia de Mixamo).
- `scripts/animation/pack_library.gd` (`PackLibrary`) y `animation_catalog.gd` (`AnimationCatalog`): catálogo único situación → clip (pack, y Tripo de respaldo).
- `FootballerVisual`: marcha del pack por mezcla de velocidad natural medida (sin patinar), una sola acción a la vez, `play_pack_clip`/`play_situation` recortables, `step_interval_for`.
- `BallHandler`: patada con clip (`plan_clip_kick`, `_start_clip_kick`, `_finish_clip_kick`): contacto cuando el **pie del clip** llega a la pelota; instante elegido sobre la trayectoria del pie; ajuste de zancada (`Footballer.nudge_velocity`, `Locomotion.turn_scale`); **sin pie que llegue no hay patada; patada en falso sin impulso ni teletransporte**; `kick_stats`/`kick_log`; eventos `KICK_WHIFF` con `reason`.
- `Footballer`: celebrar/lamentarse al `GOAL` y gesto de recepción al `FIRST_TOUCH` lento.
- `PlayerTuning`: grupo «Patada con animacion del pack» (`kick_*`).
- Pruebas: `test_pack_retarget`, `test_pack_locomotion`, `test_pack_kick`, `test_pack_dribble_metrics`, `test_pack_reactions`, `test_pack_motion` (render); soporte de `skip` en `TestCase`/`run_tests.gd`.

**Cambiado**
- Conducción (`BallHandler._try_dribble_touch`): error del toque sobre la velocidad **relativa** al jugador; hueco planificado acotado al alcance del siguiente toque; umbral de re-toque según ese hueco; con el pack, cadencia = apoyos de la animación. Valores de `PlayerTuning` de conducción **sin tocar**.
- `tests/test_kick_timing.gd` cubre solo el camino procedural (fuerza `prefer_pack = false`).
- Docs: `ANIMATION_PACK.md` (estado integrado, antes/después, límites), `PLAYER.md`, `ANIMATIONS.md`, `TESTING.md`, `TOOLS_AND_ASSETS.md`, `INDEX.md`, `CODE_MAP.json` (`anim.pack_integration`, `player.clip_kick`), `ANIMATION_PACK_CLIPS.md` (columna «Estado»: 14 integrados, 47 preparados, 72 sin convertir).

**Medido (mismo protocolo, `test_pack_dribble_metrics`; 4 semillas)**
- Conducción ANTES → DESPUÉS, pelota a 0.35–1.5 m: carrera 36 % → 100 %, sprint 31 % → 94 % (trote 100 %); lejos (> 1.5 m): 64 % → 0 % y 69 % → 6 %; nunca detrás ni pegada.
- Pase/tiro ejecutado ANTES (patada procedural) → DESPUÉS (clip, golpeo válido): trote 100 % → 100 %, carrera 50 % → 100 %, sprint 25 % → 88 %. Pie–pelota al golpear (máx): 0.061 / 0.119 / 0.160 m (radio permitido 0.30 m); latencia 0.20 s (antes 0.10–0.18 s).
- Esqueleto vivo (Xvfb): en el fotograma del impulso la punta del pie queda a 0.008 m (pase) y 0.026 m (tiro) del centro de la pelota; el pie de apoyo desliza menos con el pack que con Tripo a trote alto, carrera y sprint (0.92 / 0.55 / 0.66 frente a 1.76 / 2.92 / 3.67 m/s).

**Verificado (Godot 4.7.2, Linux)**
- Suite headless con la librería local: 85 pruebas / 529 comprobaciones / 0 fallos / 2 omitidas (render). Con render (Xvfb): 85 / 553 / 0 / 0 omitidas. Sin la librería local (clon limpio): 85 / 221 / 0 / 26 omitidas. 0 `SCRIPT ERROR`.
- `python3 tools/docs_index.py check`: 35 entradas, 0 errores, 0 avisos.

**Pendiente / límites**
- Sin validar en un teléfono Android (rendimiento, carga, consumo); verificación en movimiento solo numérica con el esqueleto vivo, no revisión visual en vídeo.
- Sin disparador (convertidos): `Dribble_2`, `Idle_To_Sprint`, `Sprint_Turn`, laterales, `soccer_penalty_kick`/`Chip` (carrera de 2.5 / 4.4 m), entrada, zancadilla, caídas, saltos, arquero (no hay entidad). Caídas/entrada/saltos no se conectaron porque el juego no tiene ese estado.
- El ajuste de zancada (media 0.26–0.47 m, sobre todo lateral) mueve el cuerpo sin pasos animados; la cadencia de toques no está fijada en fase al pie que pisa.
- Decisión del propietario: versionar o no la librería derivada si el repositorio es público.

---

## 2026-10-26 — Evaluación del pack de animaciones

**Commit:** el de este cambio (ver `git log`). **No integra ningún clip, no cambia animaciones, mecánicas ni la física de la pelota, y no gasta créditos de Tripo (saldo 770).**

**Añadido**
- `tools/animation_pack/`: herramientas de evaluación de solo lectura (compatibilidad de esqueleto, métricas por clip, duración real leída del FBX en bruto, hojas de contacto, alcance del pie, tamaño de librería) y `PackRetarget`, un retarget **experimental** Y Bot → Tripo respecto al reposo (no lo usa el juego). Ver `tools/animation_pack/README.md`.
- [SYSTEMS/ANIMATION_PACK.md](SYSTEMS/ANIMATION_PACK.md): comparativa de los 13 clips de Tripo con el pack, cobertura de necesidades, incompatibilidades, línea base de la conducción y plan de migración en fases.
- [ANIMATION_PACK_CLIPS.md](ANIMATION_PACK_CLIPS.md): una fila por cada uno de los 133 clips (duración real, raíz, ciclo, verificación visual, recomendación). Generada con `tools/animation_pack/make_report.py` y `evaluation_notes.json`.
- `.gitignore`: `/pack/` (los FBX de Mixamo no se pueden redistribuir sueltos).
- Entrada `anim.pack_eval` en `CODE_MAP.json`, fila en `INDEX.md`.

**Corregido en la documentación:** `defensive_stance` (origen `football_pass`) **no es una postura defensiva** sino un gesto de pase lento (ver [ANIMATIONS](SYSTEMS/ANIMATIONS.md)).

**Verificado (2026-10-26, Godot 4.7.2 en Linux; nada en Android)**
- Los 134 FBX importan; los 133 clips comparten el reposo del Y Bot (≤ 0.04°); 22 de los 23 huesos de Tripo tienen equivalente; 129 clips animan los 22 huesos.
- Retarget experimental: 60 clips vistos sobre nuestro futbolista en hojas de contacto, sin torsiones; tobillos 1.4–6 cm bajo su reposo (compensable).
- El índice del pack falla en 17 duraciones (comprobado con el FBX en bruto) y marca como «in place» dos clips que traen raíz (`Sprint_inplace`, `jog_backward_diagonal_2_inplace`).
- Librería retargeteada de 68 clips del núcleo: 3.3 MB (2.85 MB optimizada) frente a 0.84 MB de los 13 de Tripo.
- Línea base del juego (pruebas temporales, no incluidas): pase/tiro pulsado en conducción se ejecuta 100 % / 85 % / 19 % (trote / carrera / sprint); al sprint la pelota queda a más de 1.5 m el 63 % del tiempo.
- Las herramientas se ejecutaron desde su ubicación en el repositorio y reproducen las cifras.

**Pendiente / no verificado:** 73 clips solo por métricas; ninguna integración en el `AnimationTree`; ningún dispositivo Android; decisión de licencia (¿repositorio público?) antes de versionar una librería derivada; el contacto real de cada patada hay que marcarlo clip a clip.

---

## 2026-10-26 — Índice técnico y navegación rápida del proyecto

**Commit:** el de este cambio (ver `git log`). **No cambia ninguna mecánica de juego.**

**Añadido**
- `docs/technical-index/`: `INDEX.md` (tabla maestra y procedimiento de 10 pasos), `ARCHITECTURE.md`, `CODE_MAP.json` (32 entradas legibles por máquina, con palabras clave en español e inglés) y 17 fichas en `SYSTEMS/`: `BALL`, `PITCH`, `PLAYER`, `ASSISTANCE`, `ANIMATIONS`, `CAMERA`, `INPUTS`, `NETWORK`, `MATCH`, `UI_HUD`, `PERFORMANCE`, `TUNING`, `PROGRESSION`, `GOALKEEPER` (parcial), `ANDROID` (parcial), `TESTING`, `TOOLS_AND_ASSETS`.
- `tools/docs_index.py` (`sync`, `check`, `find`, `where`, `stats`): regenera desde el código los bloques `<!-- AUTO:... -->` y los campos derivados del mapa (líneas, valores por defecto, funciones, señales, pruebas, acciones de entrada, capas), y valida rutas, símbolos, parámetros, JSON, **nombres de pruebas citados** y **miembros `Clase.miembro` citados**.
- `CLAUDE.md` (raíz): obliga a consultar el índice primero y a actualizarlo con cada cambio.

**Corregido (solo pruebas y script de pruebas; sin efecto en el juego)**
- `tests/test_player_model.gd`: `test_animation_tree_responds_to_speed` leía `parameters/TimeScale/scale`, un nodo que no existe (se llama `LocoScale`). Lanzaba un `SCRIPT ERROR` a mitad de la prueba y el ejecutor la daba por buena con 1 comprobación. Ahora lee `parameters/LocoScale/scale` y hace 4 comprobaciones.
- `tools/run_tests.sh`: ahora termina con error si la salida contiene `SCRIPT ERROR` (el ejecutor `tests/run_tests.gd` por sí solo no lo detecta si la prueba ya había hecho alguna comprobación).

**Verificación real (2026-10-26)**
- Suite completa tras los cambios: **57 / 212 / 0 fallos, 0 `SCRIPT ERROR`**, ~10 s.
- El «57 / 209» anotado en el commit `cf0c250` incluía el `SCRIPT ERROR` anterior (reproducido: ese commit da 57 / 209 / 0 fallos **con 1 `SCRIPT ERROR`**).
- `python3 tools/docs_index.py check`: 32 entradas, 0 errores, 0 avisos tras `sync`.
- Reproducción de la suite en cada commit anterior (árboles de trabajo temporales, con el ejecutor de cada commit): `a17c8a7` 9 / 24; `ff1b394` 40 / 113; `b5e1dac` 44 / 140; `803688b` 54 / 188; `cf0c250` 57 / 209; todos con 0 fallos.

**Hallazgos documentados y NO corregidos aquí** (por no ser el alcance; ver cada ficha)
- «Salir» en el menú de pausa no hace nada y el estado `FULL_TIME` no tiene salida ([MATCH](SYSTEMS/MATCH.md), [UI_HUD](SYSTEMS/UI_HUD.md)).
- Las 9 acciones de animación (celebración, derrota, salto, caída, estirada, atajadas…) existen pero nada las dispara ([ANIMATIONS](SYSTEMS/ANIMATIONS.md)); no existe el arquero ([GOALKEEPER](SYSTEMS/GOALKEEPER.md)).
- Sin cobertura de pruebas: cámara, gráficos/diagnóstico, menú de pausa, persistencia en `user://`, serialización de `GameEvent`/`InputFrame`/`PlayerAttributes` ([TESTING](SYSTEMS/TESTING.md)).
- `PitchConfig.boundary_mode` y varios parámetros/atributos/señales sin consumidor; constantes de balance fuera de `Tuning` (listadas en [ARCHITECTURE](ARCHITECTURE.md)).
- Android: sin `export_presets.cfg`, sin flujo de GitHub Actions, sin SDK en la sesión, sin APK ([ANDROID](SYSTEMS/ANDROID.md)).
- Tripo3D: **sin gasto en este cambio**; saldo 770 de 1000.

---

## 2026-10-26 — Esqueleto único v1.0 y patada sincronizada

**Commit:** `cf0c250` · «Esqueleto unico v1.0, libreria de animaciones de Tripo y patada procedural sincronizada».

- Todos los personajes usan el rig v1.0 (23 huesos `mixamorig_*`); `player_base.glb` sin animaciones ni texturas. El rig v3.0 inicial se descartó por incompatible.
- `assets/animations/footballer_clips.res`: 13 clips de Tripo con la cadera centrada, construida por `tools/build_animation_library.gd` desde `assets/animations/source/*.glb`.
- `FootballerVisual`: `AnimationTree` con locomoción por velocidad (`BlendSpace1D`) + acciones `OneShot`.
- `ProceduralPose` (`SkeletonModifier3D`): patada con balanceo, golpeo, continuación y recuperación.
- `BallHandler.request_kick`: el impulso se aplica en el instante de contacto; patada en falso si la pelota se aleja.
- Pruebas de temporizado de patada; pruebas del modelo adaptadas al esqueleto v1.0.
- **Verificado:** 57 / 209 / 0 fallos (reproducido; incluía 1 `SCRIPT ERROR` corregido después, ver arriba).
- **Tripo:** +155 créditos (auto-rig v1.0 25 + retargets 30 + 50 + 50). Saldo 770.
- **Fichas:** [ANIMATIONS](SYSTEMS/ANIMATIONS.md), [PLAYER](SYSTEMS/PLAYER.md).
- **Pendiente:** disparar las acciones; arquero; IK de pies; la fase de golpeo (~46 ms con contacto a 0.12 s) es muy rápida (49.9 rad/s medidos).

## 2026-10-26 — Partido jugable

**Commit:** `803688b` · «Partido jugable: escena, reglas, HUD tactil, diagnostico y herramientas de captura».

- `MatchManager`: saque, gol por cruce completo de la línea, gol en contra, reinicios, pausa, fin de tiempo.
- `MatchScene` (composición), `Hud` (marcador, mensajes, pausa con ajustes de asistencia y gráficos), `TouchControls` (joystick flotante analógico y botones sobre `InputMap`, multitoque).
- `DiagnosticsOverlay` con `Logger` de errores; `GraphicsSettings` con 4 perfiles; `tools/shot_runner.gd` (capturas con entradas programadas).
- **Verificado:** 54 / 188 / 0 fallos (reproducido). No probado en dispositivo Android ni medido el rendimiento de los perfiles gráficos.
- **Tripo:** sin gasto. **Fichas:** [MATCH](SYSTEMS/MATCH.md), [UI_HUD](SYSTEMS/UI_HUD.md), [INPUTS](SYSTEMS/INPUTS.md), [PERFORMANCE](SYSTEMS/PERFORMANCE.md).
- **Pendiente:** salida del menú, pantalla de fin, IA/rivales.

## 2026-10-26 — Futbolista con Tripo3D

**Commit:** `b5e1dac` · «Futbolista de Tripo3D integrado: modelo, kit recoloreable y animaciones base».

- `player_base.glb` (7640 triángulos; en este commit con esqueleto de 65 huesos, reemplazado después por el de 23), texturas a 1024 y máscaras por región, shader de equipamiento (`player_kit.gdshader`) que conserva el sombreado original.
- `FootballerVisual` con mezcla por velocidad, cadencia ajustada para no patinar e inclinación del cuerpo; cadera de cada clip centrada (los clips traían hasta 0.95 m de desfase).
- Herramientas: `glb_inspect.py`, `inspect_model.gd`, `render_pose_sheet.gd`, `measure_hips.gd`/`measure_gait.gd`, `strip_glb_textures.py`, `make_player_textures.py`.
- **Verificado:** 44 / 140 / 0 fallos (reproducido).
- **Tripo:** +30 (retarget v3.0 idle/walk/run). Saldo 925.
- **Fichas:** [ANIMATIONS](SYSTEMS/ANIMATIONS.md), [TOOLS_AND_ASSETS](SYSTEMS/TOOLS_AND_ASSETS.md).

## 2026-10-26 — Control asistido

**Commit:** `ff1b394` · «Control asistido: locomocion, conduccion fisica, pase, tiro y presion con pruebas».

- `Locomotion`: aceleración progresiva, giro dependiente de la velocidad, agarre lateral (sin deslizamiento tipo hielo).
- `BallHandler`: toques de colocación por impulso, primer toque, pase/tiro con buffer, disputa.
- `PassAssist` / `ShotAssist` / `PressController` configurables y **no garantizados**; `KickModel` (error por atributos, equilibrio, pierna débil).
- Física de la pelota: modo `REPLACE` de amortiguamiento y límite angular de Jolt (`jolt_physics_3d/limits/max_angular_velocity=200`) corregidos.
- **Verificado:** 40 / 113 / 0 fallos (reproducido).
- **Tripo:** sin gasto. **Fichas:** [PLAYER](SYSTEMS/PLAYER.md), [ASSISTANCE](SYSTEMS/ASSISTANCE.md), [BALL](SYSTEMS/BALL.md).

## 2026-10-26 — Base del juego

**Commit:** `a17c8a7` · «Base del proyecto Godot 4.7.2: cancha, pelota fisica y pruebas».

- `project.godot` (GL Compatibility, Jolt, orientación horizontal); parámetros centralizados (`BallTuning`, `PlayerTuning`, `AssistTuning`, `KeeperTuning`, `PitchConfig`, autoload `Tuning`).
- Pelota `RigidBody3D` con arrastre, Magnus, rodadura y red absorbente; cancha de 40×20 m con líneas, arcos de 3×2 m, redes y paredes; cámara deportiva con suavizado exponencial.
- Suite de pruebas headless (`tests/run_tests.tscn`); libro de gasto de Tripo3D e inspector de GLB.
- **Verificado:** 9 / 24 / 0 fallos (reproducido).
- **Tripo:** 45 créditos (modelo 20, rig de comprobación 0, auto-rig v3.0 25). Saldo 955.
- **Fichas:** [BALL](SYSTEMS/BALL.md), [PITCH](SYSTEMS/PITCH.md), [CAMERA](SYSTEMS/CAMERA.md), [TUNING](SYSTEMS/TUNING.md), [TESTING](SYSTEMS/TESTING.md).

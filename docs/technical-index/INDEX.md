# Índice técnico maestro — Fútbol 5

> **Primer archivo a consultar** ante cualquier tarea de mantenimiento o mejora.
> El índice documenta el código **real**: lo que cambia con el código (líneas, valores por defecto, listas de
> funciones, pruebas, acciones de entrada) lo regenera `tools/docs_index.py`; nunca se escribe a mano.
> Última sincronización: <!-- AUTO:verified -->
2026-10-26
<!-- /AUTO -->

## Cómo ir de una petición al código (3 pasos)

1. **Buscar** (sin leer el repositorio): `python3 tools/docs_index.py find <palabras de la petición>`
   → devuelve el sistema, la ficha, los archivos, los símbolos con línea y los parámetros con su valor actual.
2. **Abrir solo la ficha indicada** (`docs/technical-index/SYSTEMS/<SISTEMA>.md`) y confirmar en el código real
   que el símbolo/parámetro sigue donde dice (`python3 tools/docs_index.py where Clase.miembro`).
3. **Cambiar lo mínimo**, ejecutar la prueba del sistema (`tools/run_tests.sh <filtro>`), y cerrar con
   `python3 tools/docs_index.py sync` + `python3 tools/docs_index.py check` + una entrada en `CHANGELOG.md`.

Procedimiento completo y reglas: sección «Procedimiento de trabajo» al final de este archivo.

## Tabla de sistemas

| Sistema | Qué controla | Archivo principal | Archivos secundarios | Símbolos / nodos clave | Parámetros importantes | Ficha | Depende de |
|---|---|---|---|---|---|---|---|
| **Pelota** | Física: rebote, fricción, rodadura, arrastre, Magnus, red, golpes por impulso | `scripts/ball/ball.gd` | `scripts/ball/ball_tuning.gd`, `scenes/ball/ball.tscn`, `assets/ball/ball.gdshader`, `project.godot` (Jolt) | `Ball._integrate_forces`, `Ball.apply_tuning`, `Ball.kick`, `Ball.rolling_spin` | `BallTuning.bounce`, `friction`, `mass`, `radius`, `drag_coefficient`, `rolling_decel`, `magnus_k`, `net_damping` | [BALL](SYSTEMS/BALL.md) | PITCH, PLAYER, TUNING |
| **Cancha y arcos** | Medidas 40×20, líneas, paredes, luces, arco 3×2, red, detección de gol | `scripts/pitch/pitch.gd` | `scripts/pitch/goal.gd`, `scripts/pitch/pitch_config.gd`, `scripts/pitch/mesh_util.gd`, `assets/pitch/court.gdshader`, `assets/pitch/net.gdshader` | `Pitch.build`, `Goal.is_ball_in_goal`, `Goal._physics_process` | `PitchConfig.length`, `width`, `goal_width`, `goal_height`, `wall_height` | [PITCH](SYSTEMS/PITCH.md) | BALL, MATCH, PERFORMANCE |
| **Jugador** | Movimiento, giro, conducción, primer toque, robo, patada con contacto sincronizado | `scripts/player/footballer.gd` | `scripts/player/locomotion.gd`, `scripts/player/ball_handler.gd`, `scripts/player/player_tuning.gd`, `scenes/player/footballer.tscn`, `scripts/player/human_input.gd` | `Footballer._physics_process`, `Locomotion.step`, `BallHandler._try_dribble_touch`, `BallHandler.request_kick` | `PlayerTuning.accel`, `turn_rate_standing`, `turn_rate_sprint`, `lateral_grip`, `touch_*`, `sprint_speed` | [PLAYER](SYSTEMS/PLAYER.md) | BALL, ASSISTANCE, INPUTS, ANIMATIONS |
| **Asistencias** | Pase, tiro y presión asistidos; error por atributos | `scripts/assistance/pass_assist.gd` | `scripts/assistance/shot_assist.gd`, `scripts/assistance/press_controller.gd`, `scripts/assistance/kick_model.gd`, `scripts/assistance/assist_tuning.gd` | `PassAssist.compute`, `ShotAssist.compute`, `PressController.update`, `KickModel.ground_speed_for_distance` | `AssistTuning.pass_assist`, `shot_assist`, `press_assist`, `*_max_correction_deg`, `pass_error_deg`, `shot_error_deg` | [ASSISTANCE](SYSTEMS/ASSISTANCE.md) | BALL, PLAYER, PROGRESSION |
| **Animaciones** | Modelo de Tripo, AnimationTree, kit recoloreable, patada procedural, librería de clips | `scripts/player/footballer_visual.gd` | `scripts/animation/procedural_pose.gd`, `scripts/animation/pose_sampler.gd`, `assets/animations/footballer_clips.res`, `assets/characters/player/player_base.glb`, `assets/characters/player/player_kit.gdshader` | `FootballerVisual.build`, `FootballerVisual.play_action`, `ProceduralPose.kick_angles` | `FootballerVisual.NATURAL_SPEED`, `ACTION_CLIPS`, `ProceduralPose.FOLLOW_THROUGH`, `RECOVERY` | [ANIMATIONS](SYSTEMS/ANIMATIONS.md) | PLAYER, TOOLS |
| **Pack de animaciones** (integrado) | 133 clips de Mixamo/Y Bot convertidos (campo + arquero), 93 con disparador en partido y los 40 restantes en la galería de la sala de práctica; librerías versionadas, respaldo de Tripo | `scripts/animation/animation_catalog.gd` | `scripts/animation/pack_library.gd`, `tools/animation_pack/build_pack_library.gd`, `tools/animation_pack/selection.json`, `tools/animation_pack/pack_retarget.gd` | `AnimationCatalog.resolve`, `PackLibrary.meta`, `FootballerVisual.play_pack_clip` | — | [ANIMATION_PACK](SYSTEMS/ANIMATION_PACK.md) | ANIMATIONS, PLAYER, TOOLS |
| **Patada con clip (contacto pie–pelota)** | El impulso se aplica cuando el pie medido del clip llega a la pelota; ajuste de zancada; fuera de alcance = sin patada | `scripts/player/ball_handler.gd` | `scripts/player/footballer.gd`, `scripts/player/locomotion.gd`, `tests/test_pack_kick.gd` | `BallHandler.plan_clip_kick`, `BallHandler._finish_clip_kick` | `PlayerTuning.kick_*` | [PLAYER](SYSTEMS/PLAYER.md) | ANIMATION_PACK, ASSISTANCE, BALL |
| **Cámara** | Encuadre, seguimiento suave, zoom, conversión pantalla→mundo | `scripts/camera/match_camera.gd` | — | `MatchCamera._target_focus`, `MatchCamera.screen_to_world_dir` | `MatchCamera.pitch_deg`, `base_distance`, `follow_halflife` | [CAMERA](SYSTEMS/CAMERA.md) | MATCH, PITCH |
| **Entradas** | InputFrame, fuentes de entrada, acciones, joystick y botones táctiles | `scripts/network/input_frame.gd` | `scripts/network/input_source.gd`, `scripts/network/scripted_input.gd`, `scripts/player/human_input.gd`, `scripts/ui/touch_controls.gd`, `project.godot` | `InputFrame`, `HumanInput.poll`, `TouchControls._input` | `TouchControls.JOY_RADIUS`, `JOY_DEADZONE`, acciones de `project.godot` | [INPUTS](SYSTEMS/INPUTS.md) | PLAYER, UI_HUD |
| **Partido** | Saque, gol, marcador, reloj, reinicios, pausa, composición de la escena | `scripts/gameplay/match_manager.gd` | `scripts/gameplay/match_scene.gd`, `scripts/gameplay/match_context.gd`, `scenes/main/match.tscn` | `MatchManager._on_goal`, `MatchScene._ready`, `MatchContext.attacking_goal` | `MatchManager.duration_seconds`, `goal_celebration_seconds`, `MatchScene.home_field_players` | [MATCH](SYSTEMS/MATCH.md) | PITCH, BALL, PLAYER, UI_HUD |
| **HUD** | Marcador, mensajes, menú de pausa, tema | `scripts/ui/hud.gd` | `scripts/ui/ui_theme.gd`, `scripts/ui/touch_controls.gd` | `Hud.bind`, `Hud._build_pause_menu` | niveles de asistencia, perfil gráfico | [UI_HUD](SYSTEMS/UI_HUD.md) | MATCH, INPUTS, PERFORMANCE |
| **Rendimiento** | Perfiles gráficos, escala 3D, sombras, diagnóstico (FPS, errores) | `scripts/diagnostics/graphics_settings.gd` | `scripts/diagnostics/diagnostics_overlay.gd`, `project.godot` | `GraphicsSettings.apply`, `GraphicsSettings.PROFILES`, `DiagnosticsOverlay.build_report` | `scale_3d`, `msaa`, `shadows` por perfil | [PERFORMANCE](SYSTEMS/PERFORMANCE.md) | PITCH, UI_HUD |
| **Parámetros** | Autoload `Tuning`: acceso único a todos los parámetros y preferencias | `scripts/gameplay/tuning.gd` | los 5 recursos de parámetros | `Tuning.reload`, `Tuning.save_user_settings` | rutas `resources/tuning/*.tres` (no existen: se usan valores por defecto) | [TUNING](SYSTEMS/TUNING.md) | todos |
| **Red (contratos)** | Datos serializables: `BallState`, `GameEvent`, `InputFrame` (sin servidor ni red real) | `scripts/network/game_event.gd` | `scripts/network/ball_state.gd`, `scripts/network/input_frame.gd` | `GameEvent.Type`, `BallState.to_dict` | — | [NETWORK](SYSTEMS/NETWORK.md) | MATCH, BALL, INPUTS |
| **Atributos** (parcial) | 31 atributos 1–100 con factores acotados; sin progresión aún | `scripts/progression/player_attributes.gd` | — | `PlayerAttributes.factor`, `PlayerAttributes.norm` | `PlayerAttributes.DEFAULT_ROOKIE` | [PROGRESSION](SYSTEMS/PROGRESSION.md) | PLAYER, ASSISTANCE |
| **Arquero** | Un arquero por equipo: posicionamiento, atajadas planificadas con la trayectoria de manos de cada clip, recogida y saque | `scripts/goalkeeper/goalkeeper.gd` | `scripts/goalkeeper/keeper_planner.gd`, `scripts/goalkeeper/keeper_tuning.gd`, `scripts/ball/ball_predictor.gd`, `scripts/gameplay/match_context.gd` | `Goalkeeper.setup`, `KeeperPlanner.plan_save`, `BallPredictor.trajectory` | `KeeperTuning.*` | [GOALKEEPER](SYSTEMS/GOALKEEPER.md) | BALL, ANIMATIONS, MATCH |
| **IA de equipos y acciones** | Roles (cierre, alas, pivote), pases, tiros, presión, barridas; caídas, regate, árbitro | `scripts/ai/ai_input.gd` | `scripts/player/player_actions.gd`, `scripts/animation/action_motion.gd`, `scripts/gameplay/referee.gd` | `AIInput`, `PlayerActions.try_slide_tackle`, `PlayerActions.suffer_contact` | `PlayerTuning.*` | [MATCH](SYSTEMS/MATCH.md), [PLAYER](SYSTEMS/PLAYER.md) | PLAYER, BALL, ANIMATIONS |
| **Sala de práctica** | Galería de los 133 clips por funciones y malabares | `scripts/gameplay/practice_scene.gd` | `scripts/gameplay/juggle_controller.gd`, `scenes/practice/practice.tscn` | `PracticeScene.play`, `JuggleController.tick` | — | [ANIMATIONS](SYSTEMS/ANIMATIONS.md) | ANIMATIONS, BALL |
| **Android** (APK firmada, CI sin ejecutar en runner al escribirlo) | APK liviana (arm64, 28 MB) con firma estable por secretos; workflow de GitHub Actions y release `apk-latest` | `export_presets.cfg` | `.github/workflows/android.yml`, `tools/android/make_keystore.sh`, `project.godot` | — | `display/window/handheld/orientation`, `rendering/*` | [ANDROID](SYSTEMS/ANDROID.md) | PERFORMANCE |
| **Pruebas** | Marco headless propio y suites por sistema | `tests/run_tests.gd` | `tests/test_case.gd`, `tools/run_tests.sh`, `tests/run_tests.tscn` | `TestCase.make_match`, `TestCase.add_player` | — | [TESTING](SYSTEMS/TESTING.md) | todos |
| **Herramientas y assets** | Pipeline de Tripo3D, GLB, capturas, mediciones, libro de gasto | `tools/docs_index.py` | `tools/*`, `docs/tripo/ledger.jsonl`, `assets/animations/source/` | `tools/build_animation_library.gd` | saldo de créditos Tripo | [TOOLS_AND_ASSETS](SYSTEMS/TOOLS_AND_ASSETS.md) | — |

### Sistemas que todavía **no existen** (no hay ficha porque no hay código)

- **Audio:** no hay ningún uso de `AudioStream*` en `scripts/` ni `scenes/`; `assets/audio/` existe pero está vacío.
- **Editor de jugadores, progresión por experiencia, estadísticas por jugador, menús y multijugador:** no implementados.
- **Exportación Android / GitHub Actions:** ver [ANDROID](SYSTEMS/ANDROID.md): preset `export_presets.cfg`, workflow `.github/workflows/android.yml` y `tools/android/make_keystore.sh`.

## Otros documentos

- [ARCHITECTURE.md](ARCHITECTURE.md): capas, convenciones (ejes, equipos, capas de física), flujo de datos y preparación online.
- [CHANGELOG.md](CHANGELOG.md): historial técnico con pruebas ejecutadas y pendientes.
- [ANIMATION_PACK_CLIPS.md](ANIMATION_PACK_CLIPS.md): tabla de los 133 clips del pack de animaciones (duración real, raíz, ciclo, verificación visual, recomendación).
- [CODE_MAP.json](CODE_MAP.json): mapa legible por máquina (alias en español/inglés → archivos, símbolos, parámetros, ficha).
- `docs/tripo/ledger.jsonl`: libro de gasto de créditos de Tripo3D (cada operación de pago, con saldo).
- `CLAUDE.md` (raíz): instrucciones breves para que cada sesión consulte primero este índice.

## Procedimiento de trabajo (para cualquier petición futura)

1. **Interpretar** la petición e identificar el sistema y los parámetros (p. ej. «el balón rebota demasiado» → Pelota → `BallTuning.bounce`).
2. **Consultar este `INDEX.md`** y, si hace falta, `python3 tools/docs_index.py find <términos>`.
3. **Abrir únicamente la ficha** del sistema. No cargar otras fichas por defecto.
4. **Localizar** archivo, clase/función y parámetro exactos. La identidad de un elemento es: *ruta → clase/función/nodo → nombre del parámetro → bloque de código → línea (solo orientativa)*.
5. **Verificar en el código real** que la referencia sigue vigente: `python3 tools/docs_index.py where Clase.miembro`. Si la ficha miente, corregir la ficha (`sync`) antes de seguir.
6. **Leer solo el contexto inmediato** de lo que se va a modificar.
7. **Revisar otros sistemas únicamente** si la columna «Depende de» o la sección «Dependencias» de la ficha lo exige.
8. **Hacer el cambio mínimo** que resuelva el problema.
9. **Ejecutar la prueba pertinente** (`tools/run_tests.sh <filtro>`; ver «Pruebas» de la ficha). No registrar como aprobada una prueba que no se ejecutó.
10. **Actualizar la documentación**: `python3 tools/docs_index.py sync` (líneas, valores y listas), ajustar a mano texto/curación si cambió una responsabilidad o dependencia, `python3 tools/docs_index.py check` (debe terminar sin errores) y una entrada en `CHANGELOG.md` si el cambio es funcional o estructural.

Reglas de contexto: no se lee el repositorio completo por defecto; se amplía la búsqueda solo si el índice está desactualizado, faltan referencias o hay una dependencia externa real. Las operaciones de pago de Tripo3D (generación, rig, retarget) **nunca** forman parte de tareas de documentación.

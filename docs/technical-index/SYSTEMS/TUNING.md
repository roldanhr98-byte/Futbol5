# TUNING — Registro central de parámetros

## Identificación

- **Responsabilidad exacta:** el autoload `Tuning` es el **único punto de acceso** a los parámetros de balance (`Tuning.ball`, `Tuning.player`, `Tuning.assist`, `Tuning.keeper`, `Tuning.pitch`) y a las preferencias del usuario (niveles de asistencia, diagnóstico, duración, botones táctiles, zoom de cámara `camera_zoom`, sonido `sound_on` y modo de jugabilidad `gameplay_mode`: 1 pack actual, 2 mocap de fútbol con el modelo Newton, 3 solo Tripo). Intenta cargar un `.tres` por clase desde `resources/tuning/`; **si no existe, usa los valores por defecto escritos en la propia clase**.
- **Estado:** implementado. **`resources/tuning/` existe pero está vacío**: hoy el balance vive en los valores por defecto de las clases.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-29
<!-- /AUTO -->

## Archivos responsables

| Clase | Archivo | Contiene | Ficha |
|---|---|---|---|
| `Tuning` (autoload) | `scripts/gameplay/tuning.gd` | carga, `reload`, preferencias de usuario | este documento |
| `BallTuning` | `scripts/ball/ball_tuning.gd` | física de la pelota, pase y tiro | [BALL](BALL.md) |
| `PlayerTuning` | `scripts/player/player_tuning.gd` | locomoción y conducción | [PLAYER](PLAYER.md) |
| `AssistTuning` | `scripts/assistance/assist_tuning.gd` | asistencias y niveles | [ASSISTANCE](ASSISTANCE.md) |
| `KeeperTuning` | `scripts/goalkeeper/keeper_tuning.gd` | arquero (sin consumidor) | [GOALKEEPER](GOALKEEPER.md) |
| `PitchConfig` | `scripts/pitch/pitch_config.gd` | cancha y arcos | [PITCH](PITCH.md) |

**Parámetros que NO están aquí:** los valores fijos del código (carga del pase 0.8 s, retardo de contacto, márgenes, etc.; ver «Valores fijos» en [ARCHITECTURE](../ARCHITECTURE.md)), los de animación ([ANIMATIONS](ANIMATIONS.md)), cámara ([CAMERA](CAMERA.md)), perfiles gráficos ([PERFORMANCE](PERFORMANCE.md)), reglas de partido ([MATCH](MATCH.md)) y la fricción/rebote de materiales (`pitch.gd`, `goal.gd`).

## Mapa de parámetros

<!-- AUTO:consts:scripts/gameplay/tuning.gd -->
| Constante / enum / uniform | Valor | Línea | Descripción |
|---|---|---|---|
| `Tuning.BALL_PATH` | `"res://resources/tuning/ball_tuning.tres"` | 5 | Autoload "Tuning": punto unico de acceso a los parametros centralizados del juego. Carga los .tres de resources/tuning/ y, si faltan, usa los valores por defecto de cada clase. |
| `Tuning.PLAYER_PATH` | `"res://resources/tuning/player_tuning.tres"` | 6 |  |
| `Tuning.ASSIST_PATH` | `"res://resources/tuning/assist_tuning.tres"` | 7 |  |
| `Tuning.KEEPER_PATH` | `"res://resources/tuning/keeper_tuning.tres"` | 8 |  |
| `Tuning.PITCH_PATH` | `"res://resources/tuning/pitch_config.tres"` | 9 |  |
| `Tuning.USER_SETTINGS_PATH` | `"user://settings.cfg"` | 17 |  |
| `Tuning.MATCH_MINUTES` | `[3, 5, 7, 10]` | 24 | Duracion del partido elegida (minutos): 3, 5, 7 o 10. |
| `Tuning.CAMERA_ZOOMS` | `[0.55, 0.7, 0.85, 1.0]` | 29 | Zoom de la camara del partido: factor sobre la distancia de MatchCamera (menor = mas cerca). Niveles del menu: muy cerca, cerca (por defecto: la camara a 0.7 de la distancia de la transmision lejana), media y lejos (la transmision de antes). |
| `Tuning.CAMERA_ZOOM_NAMES` | `["Muy cerca", "Cerca", "Media", "Lejos"]` | 30 |  |
| `Tuning.GAMEPLAY_MODES` | `[1, 2, 3]` | 37 | Modo de jugabilidad: 1 = animaciones del pack actual; 2 = «Mocap Pack 05 Soccer» (capturas de movimiento de futbol: pase de interior, tiro potente, penal y festejos; ver AnimationCatalog.mocap_mode); 3 = solo Tripo3D (el modelo y sus animaciones prefijadas, patada procedural; FootballerVisual.build). Se elige en el menu de pausa (reinicia el partido). |
| `Tuning.GAMEPLAY_MODE_NAMES` | `{1: "1 · Pack actual", 2: "2 · Mocap fútbol", 3: "3 · Tripo"}` | 38 |  |
<!-- /AUTO -->

Rutas esperadas de los `.tres` (**ninguna existe hoy**): las constantes `BALL_PATH`, `PLAYER_PATH`, `ASSIST_PATH`, `KEEPER_PATH` y `PITCH_PATH` de arriba, todas dentro de `resources/tuning/`. Un `.tres` cuyo script no coincide con la clase se ignora con un aviso.

Preferencias del usuario (`user://settings.cfg`, `Tuning.save_user_settings`): sección `assist` (`pass`, `shot`, `press`, 0–1) y `ui/diagnostics`. Los perfiles gráficos van aparte en `user://graphics.cfg` ([PERFORMANCE](PERFORMANCE.md)).

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| Valor por defecto de una clase `*Tuning` | Cambia el juego **y** lo que esperan las pruebas (rangos de aceptación en `tests/`). Cada ficha lista, junto a cada parámetro, las pruebas que lo vigilan. |
| Crear un `.tres` | Sustituye por completo a los valores por defecto de esa clase: los parámetros que se añadan después a la clase tomarán el valor por defecto del recurso guardado. |
| `Tuning.reload()` | Solo se llama en `Tuning._init`. Cambiar valores en caliente no actualiza lo ya aplicado: p. ej. `Ball.apply_tuning` se ejecuta una vez al crear la pelota. |
| Preferencias de usuario | Se aplican **sobre** los valores del recurso al cargar; una asistencia guardada en `user://settings.cfg` pisa el valor por defecto. |

## Mapa de funciones

<!-- AUTO:funcs:scripts/gameplay/tuning.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `Tuning._init()` | 41 |  |
| `Tuning._ready()` | 44 |  |
| `Tuning.reload()` | 48 | Recarga todos los parametros desde disco (util al ajustar valores en el laboratorio). |
| `Tuning.load_user_settings()` | 57 | Aplica las preferencias del usuario (niveles de asistencia, diagnostico) sobre los parametros. |
| `Tuning.save_user_settings()` | 74 |  |
| `Tuning._load_or_default(path: String, script: GDScript)` | 90 |  |
<!-- /AUTO -->

## Recorrido de ejecución

1. `Tuning._init` → `reload` → carga cada recurso (o `script.new()`) → `load_user_settings`.
2. El resto del código lee `Tuning.<grupo>.<parámetro>` en el momento de uso, salvo `Ball.apply_tuning` (copia a propiedades físicas al crear la pelota).
3. `Hud._cycle_assist`, `Hud._toggle_diagnostics`, `Hud._cycle_camera_zoom`, `Hud._toggle_sound` y `Hud._cycle_gameplay_mode` modifican `Tuning.assist`/`show_diagnostics`/`camera_zoom`/`sound_on`/`gameplay_mode` y llaman `save_user_settings`.

## Pruebas

- **Ejecutar:** no hay prueba directa de `Tuning`; la suite completa lo usa en todas partes (`tools/run_tests.sh`).
- **Alcance real:** la carga de `.tres`, `reload` y la persistencia de preferencias **no tienen pruebas**.

## Limitaciones conocidas

- Sin ningún `.tres`, no hay forma de ajustar el balance sin editar código; es un paso pendiente si se quiere un modo laboratorio.
- Las pruebas fijan `assist_override_*` por jugador para no depender de `user://settings.cfg`.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base del juego».

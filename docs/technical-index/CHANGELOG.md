# CHANGELOG técnico — Fútbol 5

Historial de cambios **funcionales y estructurales**, el más reciente primero. Reglas de esta bitácora:

1. Cada entrada nombra los archivos tocados y qué se verificó **de verdad**. Una prueba que no se ejecutó se anota como «no ejecutada», nunca como aprobada.
2. Las cifras de pruebas son `pruebas / comprobaciones / fallos` de `tools/run_tests.sh` (suite headless propia).
3. El gasto de Tripo3D sale de `docs/tripo/ledger.jsonl` (no se estima).
4. Todo cambio de código debe actualizar la ficha del sistema (`python3 tools/docs_index.py sync` + `check`) y añadir aquí una línea si es funcional o estructural.

Formato de entrada: **fecha — título** · commit · qué cambió · archivos · verificación · pendiente.

---

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
- **Organización colectiva (medida headless, 2×150 s, `MatchMetrics`):** sin mejora clara en el amontonamiento
  (41–49 % de muestras con ≥4 jugadores a <4 m de la pelota; línea base 30–44 %); pases/min 9–14 (antes 5–8),
  disputas/min 9–14 (antes 21–22). Diagnóstico: con la fase asentada (>2 s) cada jugador ocupa su puesto (2.7–4.6 m),
  pero la posesión cambia cada ~1.9 s. Headless no anima el esqueleto ni usa las patadas reales; la medida con render
  es demasiado lenta en este entorno (no terminó). **Pendiente.**
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

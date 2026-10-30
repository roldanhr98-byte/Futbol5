# JSON_MODE — Modo 4 «Json»: las 2 022 animaciones JSON sobre un esqueleto canónico y el humanoide propio

## Identificación

- **Qué es:** el cuarto modo de jugabilidad (`Tuning.gameplay_mode = 4`, menú de pausa → «Modo de juego: 4 · Json»). Usa las
  animaciones de `animaciones_futbol5_JSON_limpios.zip` (2 022 clips; por clip **solo posiciones** de 19 articulaciones: `pelvis, chest,
  head, l/r_clavicle, l/r_shoulder, l/r_elbow, l/r_wrist, l/r_hip, l/r_knee, l/r_ankle, l/r_toe`, fotogramas clave irregulares a 60 fps,
  trayectoria de la pelvis `root` y meta con golpeo, toques, apoyos, dirección y velocidad) convertidas a **rotaciones** sobre un esqueleto
  canónico de 23 huesos con los nombres del futbolista (`mixamorig_*`).
- **Modelo:** el humanoide propio (`assets/characters/json/json_human.scn`, ~7 000 triángulos): tubos elípticos que siguen cada
  miembro, pose A, zonas del kit (camiseta, short, medias, botines, piel, pelo, ojos, suela, ribete, labios) en `COLOR.r` y oclusión en
  `COLOR.g` (`json_kit.gdshader`). El GLB de Tripo adaptado se **descartó** el 2026-10-30 (se deformaba con estas animaciones; pedido
  del usuario): ya no hay selector de modelo.
- **Estado (2026-10-30):** las **2 022** animaciones convertidas (3 223 clips contando los espejos) y conectadas por rol; ver «Qué usa
  cada grupo». Conducción con toques dados con el pie, giros con pelota / vuelta pisando la pelota / regates con los clips y sus
  toques, golpeo girando hacia un destino al costado o detrás.

## Datos de origen y esqueleto canónico

- Las articulaciones vienen centradas en la pelvis (la trayectoria va aparte en `root`: adelante −Z del juego) y giran con el
  cuerpo (yaw). `JsonClipData` las pasa al espacio del modelo (X adelante, Y arriba, Z derecha), en metros, e interpola con una
  cúbica de Hermite entre claves.
- **Lado de los giros:** los nombres del zip («…_R_90», «…_L_135») no siempre coinciden con el lado real de los datos (p. ej.
  `STAND_TO_90_R` gira a la izquierda en las articulaciones). Todo se clasifica por lo **medido** (giro del cuerpo, hacia dónde sale la
  pelota), nunca por el nombre.
- **Longitudes** (`JsonRig`): muslo 0.339, pierna 0.420, pie 0.180, brazo 0.258, antebrazo 0.325, clavícula 0.160, cadera
  ±0.1075, pelvis a 0.853 m. En los datos la pierna y el antebrazo **no son rígidos** (la distancia rodilla–tobillo varía
  0.31–0.42 m, codo–muñeca 0.18–0.35): por eso el retarget **no copia posiciones de rodilla/codo**, resuelve una IK de dos
  huesos con las longitudes del esqueleto desde cadera/hombro hasta el tobillo/la muñeca de los datos.

## Retarget por marcos (`JsonRetarget`)

La orientación global de cada hueso es un **marco** (dirección del hueso + un vector secundario) calculado con la misma función
para el **reposo** del modelo y para cada instante de la animación. Medido (`retarget_check.gd`, 4 clips): tobillos, muñecas y puntas a
**0.0 cm** del dato (la IK los alcanza), pecho 1–3 cm, cabeza 4–5 cm.

| Hueso | Marco |
|---|---|
| Cadera | lateral = `l_hip→r_hip`; arriba = columna (`pelvis→chest`) |
| Columna, cuello | mezcla (slerp 0.34 / 0.67 / 0.45) entre los marcos de cadera y pecho / pecho y cabeza |
| Pecho | lateral = `l_clavicle→r_clavicle`; arriba = columna |
| Cabeza | arriba = `chest→head` (centro de la cabeza); lateral del pecho |
| Clavícula | hacia el hombro de los datos |
| Brazo, antebrazo / muslo, pierna | dirección del hueso + **eje de la bisagra** del codo / la rodilla (`u × polo`) |
| Pie | tobillo→punta; «arriba» de la pierna en el aire y vertical con la punta cerca del suelo |
| Mano, punta del pie | siguen a su padre (sin pista de animación) |

## Selección y conversión (`tools/json_anim/make_selection.py`, `build_json_library.gd`)

- `make_selection.py` deja las listas curadas (marcha, conducción, patadas medidas, festejos con alias, arquero...) y clasifica **todo lo
  demás** por categoría del zip, palabras del nombre y geometría medida en las articulaciones: giro total del cuerpo, hacia dónde sale la
  pelota en el golpeo (`kick_dir` del meta, relativo al frente del inicio), velocidad de entrada y salida, postura tendida al final de una
  caída y al principio de un levantarse (`lie`: boca arriba, boca abajo, de costado). 2 024 entradas (dos clips del árbitro valen también
  para el arquero).
- Tres librerías: `json_clips.res` (juego, 2 125 clips, 25 MB), `json_keeper.res` (arquero, 476 clips, 6.6 MB) y `json_scenes.res`
  (festejos, lamentos, gestos, esperas, barrera, escenas; 622 clips, 7.4 MB, se suma a la de campo al cargar). Una animación comprimida
  pesa ~10 KB casi sin importar su duración (sobrecarga fija por pista): por eso los espejos solo se generan donde hacen falta (patadas,
  giros, movimientos con pelota, arquero, caídas, barridas).
- **Rumbo**: bucles → se quita el rumbo medio; clips sueltos → media móvil de 0.25 s; clips que mueven el cuerpo con su raíz (caídas,
  barridas, saques) → solo el rumbo inicial; **clips «turn»** (giros, giros con pelota, regates, golpeos girando) → se quita un rumbo poco
  suavizado (σ 0.1 s) que el **juego aplica al jugador** (`heading_path`), y la raíz queda en el marco del inicio del clip.
- **Meta** (`Animation.get_meta("pack")`): duration, loop, natural_speed, root_total, `root_path` y `heading_path` a 30 Hz, `role`,
  `alias`, `touches`, `strides`, `release`, `natural_dir`, `heading_mode`, `move`, `lie`; trayectorias `paths` solo donde las usan los
  planificadores (patadas, cabezazos, voleas, barridas, saques, arquero); `ball_touches` (cada toque de pelota del clip: instante, pie,
  **dónde está la punta del pie** respecto al cuerpo al inicio del clip con su raíz y su giro, y hacia dónde va); en el `contact` de cada
  golpeo: `kick_turn` (hacia dónde sale la pelota respecto al frente inicial, + izquierda), `body_turn`, `root`, y `clean` (punta baja por
  delante, pie de apoyo en el suelo desde 0.1 s antes, sin patinar, pelota hacia delante).
- **Alias**: cada clip declara los nombres del pack de Mixamo que sustituye; `PackLibrary.resolve` los traduce (y los `_mirror`).
  `PackLibrary.vary_aliases` (en cada saque inicial y cada balón parado) reparte los alias de barridas, saques de banda, balones parados,
  tropiezos, empujones y saques del arquero entre **todos** los clips de su rol.

## Qué usa cada grupo de animaciones

| Grupo del zip (clips) | Rol(es) | Dónde se usa en el juego |
|---|---|---|
| CONTROL (269) | `ball_turn`, `ball_turn_stop`, `ball_skill`, `ball_stop`, `ball_sole`, `ball_start`, `ball_dribble`, `receive`, `receive_turn`, `control_stand`, `jostle_ball`, ciclos `dribble_*` | `JsonBallMove`: giros con pelota (joystick a ≥ 50° del frente), vuelta pisando la pelota (REGATE + atrás), regates (REGATE), frenada con pelota (soltar el joystick a 2.6–4.6 m/s), giro antes de golpear hacia atrás; ciclos de conducción en la marcha con pelota |
| TURN (123) | `turn_start`, `turn_run`, `turn_stand`, `turn_stop`, `start`, `stop`, `ball_turn` (con pelota) | `Footballer._json_turn_move`: giros sin pelota de ≥ 100° lejos de la pelota (la IA, solo desde parado) |
| KICK (494) | `kick_pass_soft`, `kick_pass`, `kick_shot`, `kick_shot_hard`, `kick_lob`, `kick_cross`, `kick_flick`, `kick_turn`, `kick_back`, `header`, `volley` | planificador de golpeos (`plan_clip_kick`, solo golpeos `clean`), golpeo girando (`plan_turn_kick`), planificador aéreo |
| KICKSETPIECE (36), THROW (12) | `setpiece_*`, `throw_in` | `SetPiece` (alias repartidos en cada balón parado) |
| LOCO (45), SIDESTEP (6) | `walk/jog/run/sprint`, `loco_*`, `dir_*`, `sidestep`, `jostle` | marcha y mezcla direccional (los escalones curados); el resto en la galería |
| TACKLESLIDE (18), TACKLE (16) | `slide`, `tackle_stand` | barridas (alias repartidos); gesto de la entrada de pie (`PlayerActions.tackle_gesture`) |
| FALL (29), STUMBLE (28), GETUP (60) | `fall`, `stumble`, `avoid`, `getup`, `gk_getup` | caídas por carrera y sitio libre; levantarse **desde la misma postura** (`lie`); el arquero se levanta tras una estirada (`Goalkeeper._json_getup`) |
| STAND (86) | `idle_fidget`, `idle_ready`, `idle_ball_var`, `wall`, `jostle`, `gk_idle_var` | gestos de espera tras 3.5 s quieto lejos de la pelota; barrera en un tiro libre en contra; gestos del arquero |
| NIS (601) | `celebrate*`, `clap`, `dejected`, `angry`, `warmup`, `gesture`, `nis_*`, `manager`, `mascot`, `crowd`, `referee`, `gk_gesture` | festejos, lamentos, calentamiento, fin del partido (`JsonCatalog.situation_clip`: todos los clips del rol que se pueden reproducir en el sitio); técnicos, mascota y público (`JsonSideline`) |
| GKSAVE (181), GKTHROW (6), GKKICK (12) | `gk_dive`, `gk_catch`, `gk_scoop`, `gk_block`, `gk_throw`, `gk_roll`, `gk_kick` | planificador de atajadas por rol (`KeeperPlanner`), saques del arquero |

Todo clip aparece además en la galería de la sala de práctica, agrupado por rol con su nombre en español
(`PracticeScene.ROLE_NAMES`). No tienen disparador propio en el juego (solo galería) los `nis_misc`, `nis_walk`, `nis_sit` (escenas que
caminan o se sientan), las variantes de marcha `loco_*` (los escalones de la marcha son los curados, con fases alineadas) y los
`control_stand` / `receive` de recepción con giro grande (la recepción en el juego es la de siempre, `Receive`/`receive_soccerball`).

## Mecánica del modo (qué cambia en el juego)

### Movimientos con pelota (`JsonBallMove`)

El clip mueve y gira al cuerpo (raíz + rumbo; `PlayerActions.start_move`, `ActionMotion.heading_rel`) y la pelota va **de un toque del
clip al siguiente**: en cada toque (instante y pie de `ball_touches`) recibe el impulso (`Ball.kick`) que la lleva hasta donde estará la
punta del pie en el toque siguiente; el último la deja delante del rumbo de salida (o quieta delante del pie si el giro es para golpear).
Solo empieza si la pelota llega al primer toque: se prueban clips, inicio (0–0.3 s) y un ajuste de paso de hasta 0.4 m; el resto lo cubre
el pie (`TouchFootIK`, hasta 0.32 m). La velocidad de entrada del clip debe estar a ≤ 1.5 m/s de la del jugador (≤ 3 m/s con el botón
REGATE): a más velocidad manda el giro con toques de siempre (`BallTurn`), que no se interrumpe. La IA gira con clip solo en giros de
≥ 110° y como mucho cada 3 s (mientras dura el clip no puede pasar).

### Golpeo girando (`BallHandler.plan_turn_kick`)

`estimated_kick_dir` calcula, con la misma asistencia que el golpeo real (`PassAssist`, `ShotAssist`, `CrossAssist`, azar fijo), hacia
dónde saldrá la pelota. Si queda a ≥ 50° del frente se busca un clip `kick_turn` / `kick_back` cuya pelota sale hacia allí (±40°), con el
cuerpo siguiendo la raíz y el rumbo del clip hasta el contacto (`kick_body_velocity`, `kick_body_yaw`) y ajuste de paso en lazo cerrado.
Hasta 0.6 s de balanceo (0.4 s con un rival a menos de 2.2 m). Si ninguno llega y el destino queda a ≥ 100°, primero un giro con pelota
(`JsonBallMove.turn_for_kick`) y la orden de golpeo espera. Los datos no tienen tiros fuertes que salgan a más de ~110° del frente: los
tiros hacia atrás usan siempre giro y después golpeo.

### Conducción

- **El pie toca la pelota:** al darse el toque, el pie que toca se lleva hasta la superficie de la pelota y la acompaña 0.05 s
  (`_json_touch_ik_start/_step`, hasta 0.34 m de estiramiento). Sin pie justo en la pelota, el pie bajo más cercano a ≤ 0.48 m se estira.
- **Toque de rumbo:** en diagonal o zigzag (camino de la pelota a ≥ 18° del rumbo pedido) y con un pie junto a la pelota, el toque se da
  ya y empuja la pelota casi del todo hacia el rumbo nuevo (`_steer_touch_ready`), en vez de esperar al paso siguiente.
- Planificación de golpeos con cientos de clips: se evalúan a fondo los 24 cuyo contacto y carrera de entrada (`v_in`) encajan mejor
  (`JSON_KICK_EVAL`); listas de candidatos y cajas de trayectorias del planificador aéreo guardadas por clip.

### Resto

| Dónde | Cambio |
|---|---|
| `PackLibrary` | tres librerías, alias, `by_role`, `vary_aliases`, recarga al cambiar de modo |
| `JsonCatalog` | modelo, escalones de la marcha, candidatos de patada limpios, `situation_clip` (festejos, gestos, espera, barrera, entrada) |
| `PlayerActions` | `start_move` (clips con rumbo), caídas por carrera y sitio libre (`_json_fall`) con levantarse de la misma postura (`_json_getup`) |
| `Footballer` | giros sin pelota con clip, gestos de espera, barrera en tiros libres en contra, giro del cuerpo en golpeos girando |
| `Goalkeeper` | levantarse tras una estirada (con la pelota si la atrapó), gestos con la jugada lejos, estiradas JSON cuentan como estirada |
| `JsonSideline` | dos técnicos, mascota y seis espectadores detrás de la valla del fondo, con librerías propias pequeñas |
| `SetPiece`, `MatchManager` | reparto de alias en cada balón parado y saque inicial |

## Pruebas y qué se midió (2026-10-30, Godot 4.7.2, Linux, Xvfb/llvmpipe)

| Qué | Resultado |
|---|---|
| Suite completa headless (`tools/run_tests.sh`) | 215 pruebas, 16 omitidas (render); 1 fallo en la primera pasada: el partido de IA del modo 4 sin tiros en 90 s (azar); repetido 6 veces después: 1–4 tiros, todo OK |
| `json_mode` con render | 10/10: conducción trote 20/20 toques con el pie, carrera 24/24, sprint 16/23, zigzag 32/34 |
| `LIVE_KICKS_MODE=4 live_kicks` (esqueleto animado) | 4/4 pruebas en dos pasadas; 48–49 de 50 golpeos con contacto |
| `TEST_GAMEPLAY_MODE=4 live_feet` | 6/7 (el séptimo, «encima de la pelota al acelerar» 5 % con límite < 5 %, ya fallaba antes y está calibrado para el modo 1) |
| Partido de IA 90 s | 10–14 pases, 16–19 golpeos, ~20 % en falso con rivales encima (en el modo 1 el partido de IA da 6 de 27); 12–14 movimientos con pelota y 21–28 giros sin pelota con clip |
| `play_view` (diagonal ±25°) | 26 de 27 toques con el pie; los del clip de giro a 0–6 cm del punto de toque |
| Vuelta pisando la pelota (REGATE + atrás) al paso, trote, carrera y sprint | siempre con clip (giro de 155–175°), toques a 0–5 cm |
| Tiro con el arco a 96° del frente | clip de girar y patear, punta del pie a 1.3 cm de la pelota en el impulso |
| Planificar un golpeo / un golpeo aéreo | 2.4 ms / 15–18 ms (la librería se carga una vez, ~0.6 s, al montar el partido) |

Revisión a ojo con `tools/json_anim/play_view.gd` (escenarios `diag`, `turn`, `turn90`, `dragback`, `turnshot`, `sideshot`, capturas en el
instante de cada toque con `ON_TOUCH=1`) y `tools/json_anim/match_shot.gd` (técnicos, mascota y público en la imagen de transmisión).

## Qué NO se verificó

- Nada en Android ni en un dispositivo físico. En especial el tiempo de carga (~39 MB de animaciones) y la memoria en el teléfono.
- No se vio cada uno de los 3 223 clips en movimiento: se revisaron por imágenes los giros con pelota, la vuelta pisando la pelota, el
  golpeo girando, la conducción en diagonal y el partido; la clasificación del resto es por reglas y medidas.
- Los zigzag muy bruscos (joystick que se invierte a ±48°) todavía dejan algún toque de rescate sin pie con la pelota a 0.5–0.7 m al costado.
- Los técnicos, la mascota y el público solo reproducen sus clips en el sitio (no caminan ni reaccionan a la jugada).

# Conducción, animaciones de contacto, pases y tiros — diagnóstico (2026-10-27, cuarta ronda)

Encargo: «MISIÓN PRIORITARIA: conducción real de la pelota, animaciones de contacto y pases», con dos videos:
**A** = el juego (`Screenrecorder-20261027-190714.mp4`, 136 s, partido con cámara lejana) y **B** = juego comercial de
referencia (FTS27, `Screenrecorder-20261027-191658.mp4`, 146 s, entrenamiento libre con repeticiones de cámara cercana).
Orden de trabajo pedido: A (inspeccionar) → B (¿falta la animación?) → C (integrar o detenerse) → D (pases y tiros) → E
(pruebas). Este documento es la evidencia de cada fase. Inventario medido completo:
[ANIMATION_INVENTORY.md](ANIMATION_INVENTORY.md).

## Respuesta directa

**No existe en el proyecto una animación de carrera con toques de conducción integrados.** Hay locomoción de carrera
(con y sin postura de pelota) y animaciones de contacto separadas (pase, tiro, volea, cabezazo, recepción). El único
clip «con pelota» que avanza, `Dribble_2` (trote a 2.32 m/s), **mueve los pies igual que un trote**: medido sobre el
esqueleto del jugador, su pie bajo llega a 0.16–0.26 m por delante del cuerpo (un trote normal: 0.17–0.24 m), el talón
sube 0.33–0.38 m (carrera: 0.31–0.32 m) y sus tres «empujes» por ciclo son sus propias pisadas (4 apoyos por ciclo de
1.73 s); lo único distinto es la punta del pie algo más abierta (+27°/+31° frente a +15°/+22°). Para la carrera y el
sprint con pelota el juego usa `Running_inplace` y `Two_Cycle_Sprint_inplace`, que son carreras normales. Por eso
**la Fase C quedó detenida** (no se añadió lógica de conducción) y abajo está la propuesta para crear el recurso.

## Fase A — Comparación de los videos (medida, no a ojo)

Herramientas: seguimiento por color (`track_b.py`: triángulo azul del jugador + pelota celeste; `track_a.py`: marcador
cian + aro de posesión) y hojas de fotogramas al ritmo real del video (24–30 fps variables). En A la pelota mide ~9 px y
el seguimiento automático la confunde con medias y botines, así que **las cifras de A salen del motor** (misma
conducción, esqueleto animado con render) y del video solo se usan observaciones fotograma a fotograma con su instante.

| Medida | Video B (referencia) | Nuestro juego (prueba con render, `test_dribble_reference`) |
|---|---|---|
| Intervalo entre toques | mediana 0.60–0.66 s (tramos rectos 4.4–7.8 s y 40–48 s) | trote 0.67 s · **carrera 0.27 s** · sprint 0.43 s |
| Pelota por delante del cuerpo | 0.3–1.2 m (media 0.56–0.76 m); se acerca entre toques y cada toque la devuelve a ~1 m | trote 0.31/0.44/0.66 m (p5/media/p95) · carrera 0.42/0.66/1.11 · **sprint 0.07**/0.68/0.95 |
| Deriva lateral | ±0.2 m (incluye ruido de medición y pequeños giros) | trote ±0.04 · **carrera ±0.17** · **sprint ±0.27** m |
| Pie de cada toque | un toque por ciclo de zancada (cada ~2 pasos) | carrera: un toque por paso alternando pies (83 % de alternancia) · sprint: **3 de 8 toques sin pie cerca** |

Observaciones fotograma a fotograma:

- **B, repetición 76.4–77.7 s (cámara cercana):** la pelota rueda ~1 m por delante; el jugador la alcanza, estira la
  pierna derecha y la toca con el interior/empeine (77.25–77.53 s: pie y pelota juntos), y la pelota vuelve a salir por
  delante. El cuerpo nunca pasa por encima de la pelota y la pelota no cambia de lado.
- **A, 25.0–28.0 s:** tras recibir, la pelota viaja **debajo del cuerpo**, dentro del aro (radio 0.62 m), pasando de un
  pie al otro (25.6 izquierdo, 25.7 debajo, 25.8 izquierdo, 26.3 debajo…).
- **A, 57.6–59.5 s:** conducción con la pelota 1.3–1.5 m por delante; TIRO cargado a 58.375 y otra vez a 59.375; la
  pelota sigue a la misma distancia más de un segundo y **ningún tiro sale** (ver Fase D).
- **A, 13.4–13.9 s y 29.3–30.0 s:** tiro y pase con el pie en la pelota en la imagen del golpe (correctos).

## Causas en el código (conducción)

1. **No hay movimiento de toque en la animación** (Fase B): los toques se colocan en las pisadas de un ciclo de carrera.
2. **Un toque por pisada alternando pies** (`BallHandler._touch_interval`: con pies vivos «uno por apoyo hasta la
   carrera»): cada pie empuja desde su lado → la pelota oscila entre los pies (±0.17 m a la carrera).
3. **La pelota se deja donde llegará el pie en la zancada** (`_foot_reach + FOOT_BALL_LEAD`, 0.10 m): a velocidad baja
   queda entre los pies; en B va un paso entero por delante.
4. **La velocidad del toque la decide un planificador, no el pie**: el impulso se calcula para que la pelota llegue a
   «posición futura del jugador + gap»; el pie solo pone el instante y la cercanía.
5. **Toques de rescate sin pie** (`_foot_wait` > `FOOT_WAIT_MAX`, toques de preparación «setup»): a sprint 3 de 8; en
   curvas cerradas el 39 % (ronda anterior). Son impulsos sin contacto visible.

Ninguna de estas causas se «arregló» cambiando distancias o cadencias: el encargo prohíbe resolver la falta de animación
con valores o lógica encima de una carrera que no puede representar el toque.

## Fase B — Inventario de las animaciones (resumen por necesidad)

Medido con `FootTrajectory` sobre el esqueleto del jugador (coordenadas comprobadas: el contacto de `Soccer_Pass`
medido coincide con el del conversor a 0.000 m). Las 171 animaciones (133 FBX + 38 espejos) enlazan sus 24 pistas con el
esqueleto de 23 huesos (`mixamorig_*`). Archivo de todas: `assets/animations/pack_clips.res` (campo) y
`pack_keeper.res` (arquero), nombre `pack/<clip>`; FBX de origen en la segunda columna.

| Acción necesaria | Animación encontrada | Archivo y nombre exactos | Compatibilidad con el jugador | Contacto con la pelota (medido) | Estado |
|---|---|---|---|---|---|
| Carrera sin pelota | trote, carrera, sprint | `Jogging_inplace.fbx`, `jog_forward_inplace.fbx`, `Running_inplace.fbx`, `Sprint_inplace.fbx` (trae 3.16 m de raíz, se quita por código), `Two_Cycle_Sprint_inplace.fbx` | 24/24 pistas; bucles sin costura (0–10°); 1.64 / 2.15 / 2.14 / 5.13 / 5.29 m/s | no aplica | **utilizable** (en uso: `PACK_GAIT_POINTS`) |
| Carrera con conducción | `Dribble_2` (trote con pelota) | `Dribble_2.fbx` → `pack/Dribble_2` | 24/24; bucle 0.2°/2°; 2.32 m/s; sin espejo | sus «empujes» son sus 4 pisadas por ciclo; pie bajo a 0.16–0.26 m (como un trote); **ningún toque pasa de la zancada** (criterio ≥ 0.40 m) | **falta** (sirve como postura de trote con pelota; no hay toques; a carrera/sprint no hay nada) |
| Toques con empeine / exterior | — | — | — | ningún clip aislado de toque | **falta** |
| Toques cortos hacia delante | — | — | — | solo las pisadas de la marcha | **falta** |
| Conducción al acelerar | `Idle_To_Sprint` (arranque **sin** pelota) | `Idle_To_Sprint.fbx` | 24/24; no cierra con el reposo (37°) | 1 empuje a 0.32 m (zancada) | **falta** (con pelota) |
| Conducción al girar | `Soccer_Spin` (ruleta 360°), `Sprint_Turn` (giro corriendo sin pelota) | `Soccer_Spin.fbx`, `Sprint_Turn.fbx` | 24/24 | ruleta: 1 empuje 0.25 m; giro: pisadas a 0.34–0.54 m con 0.36 m de costado | ruleta **utilizable** como regate (en uso); giro con pelota **falta** |
| Frenado con pelota | ninguno (`Sprint_To_Backslide` es una caída al suelo) | `Sprint_To_Backslide.fbx` | — | — | **falta** |
| Pisada y control | ninguno de suela; `stall_soccerball` (+_2/_3/_4) son malabares con la pelota en el aire | `stall_soccerball*.fbx` | 24/24 | 0 empujes | **falta** |
| Recepción y amortiguación | `Receive` (pecho), `receive_soccerball` (pie, 5.13 s, raíz 2.36 m, no cierra) | `Receive.fbx`, `receive_soccerball.fbx` | 24/24 | `Receive`: 0 empujes (pecho); `receive_soccerball`: 8 toques a 0.24–0.45 m | `Receive` **utilizable** (en uso); `receive_soccerball` **necesita adaptación** (solo su primer tramo) |
| Pase corto y largo | `Soccer_Pass`, `strike_foward_jog_inplace`, `Chip` (+ espejos) | `Soccer_Pass.fbx`, `strike_foward_jog_inplace.fbx`, `Chip.fbx` | 24/24; contacto medido al convertir (instante, pie, posición, trayectoria) | con render: 49 de 50 golpeos con el pie a la pelota en la imagen del golpe (`test_live_kicks`) | **utilizable** (en uso) |
| Preparación y ejecución de tiros | `strike_foward_jog_inplace` (pie a 12.4 m/s), voleas `scissor_kick`, `kick_soccerball`(_2), `soccer_penalty_kick` (penal, raíz 2.59 m) | mismos nombres `.fbx` | 24/24 | contacto medido; validado con render | **utilizable** (en uso) |
| Contacto con ambas piernas | espejos `_mirror` de pase, tiro, Chip, penal, tijera, cabezazos | `<clip>_mirror` (generados al convertir) | 24/24 | contacto medido por pierna | **utilizable** para golpeos; para conducción **falta** (`Dribble_2` no tiene espejo ni toques) |

## Fase C — Detenida: qué no se hizo y por qué

No se integró ninguna «conducción con animación» porque el recurso no existe. En concreto **no** se hizo: reproducir la
carrera en bucle como si fuera conducción, mover la pelota delante del jugador, acercarla o alejarla cambiando
distancias/cadencias, ni añadir toques automáticos nuevos. Queda documentado que el sistema actual **ya tiene** toques
sin contacto visible (rescates, ver causas 4–5); se quitarán al integrar el clip de conducción, no antes (sin el clip,
exigir un pie cerca para esos toques rompía el frenado y los giros: probado y revertido en la ronda anterior).

## Crear el recurso que falta (propuesta concreta)

**Qué falta:** ciclos de carrera con conducción, en el sitio (sin raíz), en bucle, para el esqueleto del jugador:
trote con pelota (~2.5–3 m/s) y carrera con pelota (~4.5–5.5 m/s), con un toque visible por ciclo (cada ~0.6 s) del
pie derecho con el empeine/interior que lleva la pelota hacia delante, y su espejo (pie izquierdo). Deseables después:
giro con el exterior a cada lado, frenada con la suela, arrancada con pelota.

**Tripo3D (comprobado en su documentación oficial, sin acceder a la cuenta):** Tripo **no crea animaciones a partir de
texto ni de video**: aplica *presets* a un modelo riggeado (endpoint `animations/retarget`). Para el rig v1.0 (el de
nuestro jugador) la lista incluye `preset:biped:dribble` y `preset:biped:crossover_dribble`, pero la documentación no
dice de qué deporte son (*crossover* es un movimiento de baloncesto) y nuestra experiencia con `football_pass` (resultó
un gesto lento que no servía como pase, ver [ANIMATIONS](SYSTEMS/ANIMATIONS.md)) aconseja **no pagar sin verlo**. Coste
según el registro del proyecto: 10 créditos por animación retargeteada (`docs/tripo/ledger.jsonl`; último saldo
anotado: 770). Esta sesión **no tiene credenciales ni integración de Tripo**: no se consultó ni se gastó nada.

Si quiere probarlo en Tripo:

1. Abrir Tripo Studio: <https://www.tripo3d.ai> (documentación del retarget:
   <https://developers.tripo3d.com/en/docs/animations-retarget>).
2. Elegir el modelo del jugador ya riggeado en su cuenta (rig v1.0, el «player_v1» del 2026-10-26, para no volver a
   pagar el rig) o, si no está, subir `assets/characters/player/player_base.glb` (23 huesos `mixamorig_*`).
3. En la sección de animación, mirar el preset **dribble** antes de exportar. Si muestra un jugador de fútbol
   conduciendo con el pie, exportarlo; si es baloncesto (bote con la mano), descartarlo sin exportar.
4. Exportar en **GLB** con la animación horneada (o FBX), «en el sitio» (*in place*), y dejar el archivo en el chat o en
   `assets/animations/source/`. No hace falta escribir ninguna clave: el archivo basta.

**Alternativas (sin Tripo, no comprobadas por mí en sus sitios):** el pack de 133 clips viene de Mixamo (Y Bot,
`mixamorig`): `Dribble_2.fbx` estaba en su carpeta `02_balon_pases_tiros`; conviene buscar en Mixamo «dribble» /
«soccer» con el Y Bot y descargar FBX *Without Skin*, 30 fps, *In Place* (el conversor del proyecto ya acepta ese
esqueleto). También existen herramientas de texto a movimiento que retargetean a un personaje subido (p. ej. Uthana,
Cartwheel, Rokoko) o animación a mano (Cascadeur/Blender). Texto sugerido para esas herramientas:

> Soccer player dribbling a ball while running forward, seen in place (no root motion). Every second step the right
> foot reaches forward low and pushes the ball ahead with the laces/inside of the foot; between touches the ball rolls
> about one stride in front. Upright torso slightly leaning forward, arms relaxed and swinging, head glancing down at the
> touch and up between touches. Seamless loop, 1.2 s cycle (2 strides), 30 fps.

(y la misma frase con «jogging, 2 s cycle» para el trote, y «left foot» para el espejo).

**Cómo se valida al llegar (sin gastar más):**
`DRIBBLE_CANDIDATE=<clip> INVENTORY_OUT=docs/technical-index/ANIMATION_INVENTORY.md tools/run_tests.sh animation_inventory`
aplica los criterios medibles de `FootTrajectory.dribble_verdict` (punta baja a ≥ 0.40 m por delante, ≥ 1.5 m/s más
rápida que el cuerpo, un toque cada 0.35–1.0 s, ≤ 0.20 m al costado, bucle, cuerpo que avanza) y
`tools/animation_pack/pack_clip_sheet.tscn` dibuja el clip sobre nuestro jugador con la trayectoria de los pies. Si
cumple, la integración usa los instantes de toque medidos del propio clip (en vez de las pisadas) y el impulso sale de la
velocidad del pie en ese instante; los rescates sin pie se eliminan entonces.

## Fase D — Pases y tiros

Secuencia actual (verificada en el código y con render, `test_live_kicks`, `test_pack_kick`): evaluar la pelota
predicha → elegir clip, pierna e instante de contacto de la trayectoria real del pie (`plan_clip_kick`) → ajuste de
zancada acotado antes de plantar el pie de apoyo (`_steer_clip_kick`) → latencia cuantizada para que la pose de contacto y
el impulso caigan en el mismo paso → validar la distancia pie-pelota en ese paso (`_finish_clip_kick`; si no, patada al
aire sin impulso) → **un solo impulso** (`perform_action`) → bloqueo corto y vuelta al control.

Fallo encontrado en A (57.6–59.5 s) y **reproducido en condiciones equivalentes** (los mandos exactos del video no se
conocen): con el joystick a media velocidad (3.6–4.2 m/s) y la pelota propia
1.7–2.6 m por delante, el tiro pedido esperaba 0.5 s a que un pie llegara, el cuerpo no iba a por la pelota y la orden
caducaba sin golpeo (`out_of_reach`). Corrección:

- `BallHandler.kick_approach_steer()`: con un golpeo cargándose o pedido y la pelota propia por delante fuera del
  alcance del pie (hasta 4 m), el cuerpo corre hacia ella (sin el tope de velocidad de conducción); la dirección del
  golpeo sigue siendo la del joystick. La orden espera mientras el jugador se acerca de verdad (hasta 1.4 s) y, si no
  llega, se cancela con `KICK_WHIFF out_of_reach`. Igual para la persona y la IA.
- Mientras se carga en carrera, el toque es de preparación (no manda la pelota lejos); parado y cargando no se toca.
- Yendo a golpear, sin toques de preparación sin pie: el único contacto es el del golpeo.

`test_kick_reach` (con render): 7 de 7 golpeos con el pie a 0.02–0.17 m de la pelota y 0 toques sin pie antes del
golpe (antes de la corrección, 3 de esas situaciones terminaban sin golpeo); una pelota que se escapa al doble de
velocidad se cancela con aviso y sin impulso.

## Una misma base para la persona y la IA

La IA solo produce entradas (`InputFrame`, como el joystick y los botones) que van al mismo `Footballer` →
`BallHandler`; ningún script de `scripts/ai` toca la pelota. Comprobado en `test_shared_ball_mechanics`: el código de IA no
contiene `kick`/`push`/impulsos/teletransportes, y en 6 s de un jugador de IA con la pelota sus 11 toques salen todos de
su `BallHandler`. Cuando llegue el clip de conducción, compañeros y rivales lo usarán sin cambios.

## Fase E — Pruebas (ejecutadas con la versión final)

| Prueba | Resultado |
|---|---|
| Suite headless completa (`tools/run_tests.sh`) | 176 pruebas, 893 comprobaciones, 0 fallos, 14 omitidas (necesitan render) |
| `live_feet` (render): recta, frenar y reacelerar, giros 45/90/135/180, zigzag, curva | 7/7; curva 11 de 18 toques con el pie, pelota cerca 100 % |
| `live_kicks` (render): 50 golpeos variados, pases con cada pie, tiros | 4/4; 48/50 con contacto, 2 anulados porque el rival tocó antes, 0 contactos inválidos |
| `dribble_reference` (render): conducción recta contra el video B | medida (tabla de la Fase A) |
| `kick_reach` (render y headless): golpeo con la pelota fuera del alcance | 7/7 golpeos con contacto, 0 toques sin pie; cancelación con aviso si no se llega |
| `shared_ball_mechanics`: IA = misma mecánica | 11/11 toques desde su `BallHandler` (corrida final) |
| `animation_inventory`: 171 animaciones medidas | todas enlazadas; ningún clip de conducción con toques |

Grabación de la prueba controlada con el jugador actual: `tools/dribble_demo/dribble_demo.tscn` (26.7 s: recta al
trote, carrera, sprint, parada, giros a ambos lados, pase corto, pase largo y tiro; en pantalla la distancia de la pelota
y el pie de cada toque). Comparada con A y B en una misma hoja de fotogramas: en B la pelota va un paso por delante y se
ve la pierna estirarse al toque; en la prueba la pelota va 0.3–0.7 m por delante y los toques coinciden con las pisadas
(sin gesto de toque, por falta de animación).

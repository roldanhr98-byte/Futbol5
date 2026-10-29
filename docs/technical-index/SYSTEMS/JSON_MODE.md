# JSON_MODE — Modo 4 «Json»: animaciones JSON sobre un esqueleto canónico, con dos modelos

## Identificación

- **Qué es:** el cuarto modo de jugabilidad (`Tuning.gameplay_mode = 4`, menú de pausa → «Modo de juego: 4 · Json»; el botón
  «Modelo del modo Json» elige el modelo). Usa las animaciones de `animaciones_futbol5_JSON_limpios.zip` (2 022 clips; por
  clip **solo posiciones** de 19 articulaciones: `pelvis, chest, head, l/r_clavicle, l/r_shoulder, l/r_elbow, l/r_wrist,
  l/r_hip, l/r_knee, l/r_ankle, l/r_toe`, fotogramas clave irregulares a 60 fps, trayectoria de la pelvis `root` y meta
  con golpeo, toques, apoyos, dirección y velocidad) convertidas a **rotaciones** sobre un esqueleto canónico de 23 huesos
  con los nombres del futbolista (`mixamorig_*`).
- **Dos modelos elegibles** (los dos cuelgan del mismo esqueleto, así una sola librería de clips sirve para ambos):
  1. **Tripo adaptado** (`assets/characters/json/json_tripo.scn`): la malla, los UV y los pesos de `player_base.glb` sin
     cambios, con el esqueleto canónico en pose T en vez de los huesos propios de Tripo (mismo kit: textura y máscaras).
  2. **Humanoide realista** (`json_human.scn`, ~7 000 triángulos): tubos elípticos que siguen cada miembro, pose A, zonas del
     kit (camiseta, short, medias, botines, piel, pelo, ojos, suela, ribete, labios) en `COLOR.r` y oclusión en `COLOR.g`
     (`json_kit.gdshader`). Cuello, cabeza con cara (nariz, orejas, ojos), manos con pulgar, botines.
- **Estado (2026-10-29):** integrado de punta a punta: marcha mezclada por velocidad (con y sin pelota), conducción con los
  ciclos de conducción del JSON, pases/tiros/vaselinas con 108 patadas de contacto medido (las dos piernas), cabezazos (16) y
  voleas (14), barridas, caídas, levantarse, festejos, saque de banda y balón parado, arquero (60 estiradas, 40 atajadas altas,
  18 recogidas, bloqueos, saques; 155 clips) y árbitro. 263 clips de campo + 155 del arquero.

## Datos de origen y esqueleto canónico

- Las articulaciones vienen centradas en la pelvis (la trayectoria va aparte en `root`: adelante −Z del juego) y giran con el
  cuerpo (yaw). `JsonClipData` las pasa al espacio del modelo (X adelante, Y arriba, Z derecha), en metros, e interpola con una
  cúbica de Hermite entre claves.
- **Longitudes** (`JsonRig`): muslo 0.339, pierna 0.420, pie 0.180, brazo 0.258, antebrazo 0.325, clavícula 0.160, cadera
  ±0.1075, pelvis a 0.853 m. En los datos la pierna y el antebrazo **no son rígidos** (la distancia rodilla–tobillo varía
  0.31–0.42 m, codo–muñeca 0.18–0.35): por eso el retarget **no copia posiciones de rodilla/codo**, resuelve una IK de dos
  huesos con las longitudes del esqueleto desde cadera/hombro hasta el tobillo/la muñeca de los datos.
- Posiciones de reposo en pose A y T (`JsonRig.rest_positions`); el humanoide se modela en pose A y el Tripo en pose T.

## Retarget por marcos (`JsonRetarget`)

La orientación global de cada hueso es un **marco** (dirección del hueso + un vector secundario) calculado con la misma función
para el **reposo** de cada modelo y para cada instante de la animación; el hueso queda en reposo con su marco de reposo, y la
pose del clip es el marco absoluto de los datos. Resultado: el mismo clip sirve en pose A y pose T.

| Hueso | Marco |
|---|---|
| Cadera | lateral = `l_hip→r_hip`; arriba = columna (`pelvis→chest`) |
| Columna, cuello | mezcla (slerp 0.34 / 0.67 / 0.45) entre los marcos de cadera y pecho / pecho y cabeza |
| Pecho | lateral = `l_clavicle→r_clavicle`; arriba = columna |
| Cabeza | arriba = `chest→head` (centro de la cabeza); lateral del pecho |
| Clavícula | hacia el hombro de los datos |
| Brazo, antebrazo / muslo, pierna | dirección del hueso + **eje de la bisagra** del codo / la rodilla (`u × polo`); con la extremidad casi estirada el polo es el de reposo llevado por la rotación del padre sin torsión extra |
| Pie | tobillo→punta; «arriba» de la pierna en el aire y vertical con la punta cerca del suelo |
| Mano, punta del pie | siguen a su padre (sin pista de animación) |

Medido (`retarget_check.gd`, 4 clips): tobillos, muñecas y puntas a **0.0 cm** del dato (la IK los alcanza), pecho 1–3 cm,
cabeza 4–5 cm.

## Conversión (`tools/json_anim/build_json_library.gd`)

- Entrada: `selection.json` (lo genera `make_selection.py`: listas curadas + reglas sobre el índice del zip). Salida:
  `assets/animations/json_clips.res` (campo, 3.4 MB) y `json_keeper.res` (arquero, 2.1 MB) gracias a `Animation.compress`
  y a que las manos y las puntas no llevan pista (lo que más pesa son los metadatos: trayectorias y contactos).
- **Rumbo**: el clip puede terminar girado 40°; el juego mueve y gira al jugador. Bucles: se quita el rumbo medio; clips sueltos:
  media móvil de 0.5 s (queda la torsión rápida de cadera y pecho); clips que mueven el cuerpo con su raíz (caídas, barridas,
  saques, arquero): solo se quita el rumbo inicial.
- **Ciclos de marcha**: cada bucle empieza en un apoyo del pie izquierdo (`phase`), y los de conducción se recortan entre dos
  apoyos del mismo pie (`cycle`, con costura de 8 fotogramas); si el primero es el derecho se usa la versión espejo. Así todos se
  reproducen con una **línea de tiempo común de un ciclo** (`AnimationNodeAnimation.use_custom_timeline`) y las fases coinciden
  al mezclar; el TimeScale va en ciclos por segundo (`JsonCatalog.cycles_per_second`: velocidad / zancada interpolada).
- **Metadatos** (`Animation.get_meta("pack")`): los mismos campos que el pack de Mixamo (duration, loop, natural_speed,
  root_total, root_path a 30 Hz, foot_floor_cm, `contact` con trayectoria de la punta a 120 Hz, `paths` toe/knee/head/hands/hand a
  30 Hz — con la raíz solo en los clips `root_driven`, `paths_root`) más `role`, `alias`, `touches`, `strides`, `release`
  (lanzamientos), `natural_dir` (dirección medida del paso).
- **Alias**: cada clip declara los nombres del pack de Mixamo que sustituye; `PackLibrary.resolve` los traduce (y los `_mirror`),
  de modo que PlayerActions, Goalkeeper, SetPiece, Referee y AnimationCatalog siguen pidiendo «Soccer_Pass», «soccer_tackle»,
  «goalkeeper_diving_save»... y reciben el clip JSON. Lo que no tiene sustituto no existe y el juego lo omite.

## Qué cambia en el juego

| Dónde | Cambio |
|---|---|
| `Tuning` | modo 4, `json_model` (0 Tripo adaptado, 1 humanoide), persistencia |
| `PackLibrary` | librerías JSON, alias, `by_role`, recarga al cambiar de modo (y `reset_caches`) |
| `JsonCatalog` | modelo, escalones de la marcha (`GAIT`, `CARRY`), direcciones, candidatos de patada por potencia |
| `FootballerVisual` | escena del modelo, kit del humanoide, árbol con ciclos de tiempo común, sin clips de Tripo, menos inclinación propia |
| `AnimationCatalog` | `kick_candidates(kind, charge)`; sin respaldo de Tripo |
| `BallHandler` | elige al azar entre las patadas que encajan casi igual (`JSON_KICK_VARIETY`); cabezazos/voleas por rol |
| `KeeperPlanner` | candidatos por rol (`gk_dive`, `gk_catch`, `gk_scoop`, `gk_sidestep`, `gk_block`) |
| `SetPiece`, `Referee`, `Hud` | suelta del saque medida, árbitro con marcha JSON, botón del modelo |

## Pruebas y qué se midió

`tests/test_json_mode.gd` (10 pruebas: 9 headless + 1 con render) y, con `TEST_GAMEPLAY_MODE=4`, las pruebas con esqueleto
animado de siempre. Resultados medidos el 2026-10-29 (Godot 4.7.2, Linux, Xvfb/llvmpipe):

| Qué | Resultado |
|---|---|
| Retarget | tobillos, muñecas y puntas a 0.0 cm del dato; pecho 1–3 cm, cabeza 4–5 cm |
| Pases y tiros desde parado a sprint (`test_passes_and_shots_connect…`) | 12 de 12 con clip JSON, pie a 0.006–0.16 m de la pelota |
| `LIVE_KICKS_MODE=4 test_live_kicks` (esqueleto animado, 50 golpeos variados) | 49 de 50 con contacto, punta del pie a 0.01–0.06 m de la pelota en el impulso (a 0.18–0.26 m en los golpeos de primera), pie de apoyo ≤ 0.7 m/s (límite 1.6) |
| Conducción con el esqueleto animado, los dos modelos (`test_live_dribble…`) | trote 0.41 m / carrera 0.44 m / sprint 0.6 m / zigzag 0.5 m de mediana pelota–cuerpo, máximo 0.96 m; el 100 % de los toques de trote y carrera los da el pie, 67 % a sprint |
| `TEST_GAMEPLAY_MODE=4 test_live_feet` | 6 de 7 (el séptimo mide «pisa la pelota» al arrancar: 5 % frente a un límite de 5 %, calibrado para el modo 1) |
| Partido de IA 90 s con los dos modelos | pases, tiros, atajadas, barridas y caídas con clips JSON; nadie se sale; árbitro recorre ~100 m |
| Coste de planificar un golpeo | ~3 ms (de 15.5 ms sin el prefiltro de clips ni el cálculo común de la pelota prevista) |

Revisión a ojo con `tools/json_anim/{model_preview,play_view,keeper_view,match_shot}`: carrera, conducción, pase, tiro,
barrida, caída, levantarse, festejo, estirada del arquero y partido completo con la cámara de transmisión.

## Qué NO se verificó

- Nada en Android ni en un dispositivo físico (solo Godot 4.7.2 en Linux con Xvfb/llvmpipe).
- Los clips se eligieron por reglas y por metadatos, y se revisaron por imágenes de una muestra (marcha, conducción, patadas,
  tiros, barrida, caída, levantarse, festejo, estirada); no se vio cada uno de los ~420 clips en movimiento.
- Conducción: el toque lo da el pie vivo (la lógica de siempre, con los ciclos de conducción del JSON como animación base); los
  `touches` del JSON se guardan en la meta pero **no** se usan para disparar los toques. A sprint ~1/3 de los toques son de rescate
  sin pie.
- Sin clips de giro, de arranque (`Idle_To_Sprint`), de regate (`Soccer_Spin`) ni de cansancio en este modo (no hay sustituto
  elegido: el juego los omite).
- El planificador de golpes aéreos cuesta ~15 ms por llamada (dominado por la trayectoria predicha de la pelota, igual que antes).

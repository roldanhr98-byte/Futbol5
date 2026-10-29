# tools/json_anim — animaciones JSON → modo 4 «Json»

Convierte las animaciones de `animaciones_futbol5_JSON_limpios.zip` (2 022 clips; por clip: 19 articulaciones en posiciones,
fotogramas clave irregulares a 60 fps, raíz y metadatos de patada/toques/apoyos) a clips con rotaciones sobre un esqueleto
canónico, y construye los dos modelos del modo. Detalle del sistema: [`docs/technical-index/SYSTEMS/JSON_MODE.md`](../../docs/technical-index/SYSTEMS/JSON_MODE.md).

Los JSON originales **no se versionan** (26 MB; descomprimir el zip en una carpeta cualquiera y pasarla en `JSON_SRC`). Lo que se
versiona es el resultado: `assets/animations/json_clips.res`, `json_keeper.res` y `assets/characters/json/*.scn`.

| Paso | Comando |
|---|---|
| Elegir clips (reglas + listas curadas) | `python3 tools/json_anim/make_selection.py <carpeta_JSON>` → `selection.json` |
| Convertir (campo y arquero) | `JSON_SRC=<carpeta_JSON> godot --headless --path . res://tools/json_anim/build_json_library.tscn` |
| Humanoide realista | `godot --headless --path . res://tools/json_anim/build_json_human.tscn` |
| Tripo adaptado | `godot --headless --path . res://tools/json_anim/build_json_tripo.tscn` |
| Error del retarget frente a los datos | `JSON_SRC=<carpeta_JSON> godot --headless --path . --script res://tools/json_anim/retarget_check.gd -- 0072_ 1582_` |
| Ver un modelo / clip | `MODEL=res://assets/characters/json/json_human.scn CLIP=jn_sprint_3022 TIMES=0,0.1,0.2 VIEWS=side OUT=/tmp/x.png xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/json_anim/model_preview.tscn` |
| Ver conducción / pase / tiro en juego | `SCENARIO=dribble MODEL=1 OUT=/tmp/x.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/play_view.tscn` |
| Capturas del partido completo (cámara de transmisión) | `MODEL=1 SHOTS=14,22 OUT=/tmp/m xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/match_shot.tscn` |
| Ver una atajada | `TARGET=1.0,0.6 SPEED=15 OUT=/tmp/k.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/keeper_view.tscn` |

Después de convertir o cambiar un modelo: `godot --headless --path . --import` y `tools/run_tests.sh json_mode`.

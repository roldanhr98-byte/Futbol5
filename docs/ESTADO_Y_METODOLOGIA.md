# Estado del proyecto y metodología de trabajo (traspaso entre chats)

> Leer esto ANTES de tocar nada, junto con [`START_HERE.md`](START_HERE.md) y el índice técnico. Última actualización: F3
> cerrada para revisión (2026-10-30).

## 1. Ramas

| Rama | Uso |
|---|---|
| `respaldo-f3` | **Rama de trabajo actual.** Todo se desarrolla y se guarda aquí (commits y push en esta rama). |
| `ccr-a6c53cd2-uoxpk0` | **Rama principal** (la rama por defecto del repositorio en GitHub; no existe `main`). **No se toca** hasta que el usuario dé por terminado el trabajo; entonces se sube todo de una vez. |
| `ccr-7a7dba29-jfbum5` | Rama de una sesión anterior (F0–F3); su contenido ya está en `respaldo-f3`. No se usa más. |

Historial de `respaldo-f3` (de más nuevo a más viejo): F3 corregido (`ff6124b`), F3 en curso (`895b3f8`), F2 árbitro de acciones
(`3e035b4`), F0 cambios preservados (`9980f2b`), base `a86f623`.

## 2. Metodología (reglas acordadas con el usuario)

1. **Por fases** (F0…F8, ver §4). Cada fase empieza con una autorización escrita del usuario que dice qué se puede tocar y qué
   no; al terminar se entrega un **informe** y **se detiene**: no se avanza a la fase siguiente sin aprobación expresa.
2. **Commits, push, APK:** solo cuando el usuario lo autoriza en esa fase. El usuario pidió guardar el trabajo en `respaldo-f3`
   para que otros chats continúen; los APK se generan solo si el usuario lo pide (workflow de GitHub Actions, ver START_HERE).
3. **Solo existe el modo de juego 4 (JSON).** Los modos 1, 2 y 3 están descartados: no se recuperan, no se reintroducen ni se usan
   como respaldo. (El código antiguo sigue ahí: no se borra por suposición sin autorización.)
4. **No inventar resultados.** No declarar aprobada una prueba que no se ejecutó; informar fallos con la salida real. Clasificar
   cada fallo: nuevo de la fase / preexistente (F0/F2) / modos descartados / prueba mal diseñada / no determinista. No modificar
   pruebas para ocultar fallos (si una prueba propia estaba mal planteada, corregirla y decirlo).
5. **Verificación visual obligatoria** para animación y contacto (render con Xvfb): tiras de imágenes antes, durante y después
   del contacto. Una prueba numérica no basta. Decir siempre qué se vio y qué no (no se prueba en Android).
6. **Distinguir verificado / medido / estimado / supuesto.** Una estimación cinemática no es una certeza.
7. **Archivos auxiliares** de análisis fuera del repositorio (directorio temporal); al repositorio solo lo que el usuario necesita.
8. **Documentación en el mismo cambio:** `python3 tools/docs_index.py sync`, ajustar a mano, `check` sin errores, entrada en
   `docs/technical-index/CHANGELOG.md`.
9. **Respetar F2:** `ActionArbiter` es la única autoridad sobre cuerpo y pose (niveles, testigos, interrupción). No crear
   mecanismos paralelos ni cambiar su contrato sin proponerlo antes.
10. Informes en español, con tablas y ejemplos; sin conclusiones sin evidencia.

## 3. Estado por fase

| Fase | Estado | Documento |
|---|---|---|
| Auditoría inicial modo JSON + Ultimate Clash | hecha | [`fases/00_auditoria_modo_json.md`](fases/00_auditoria_modo_json.md) |
| F0 protección y diagnóstico | hecha (commit `9980f2b`) | resumen en el CHANGELOG |
| F1 cobertura del catálogo JSON (2 024 clips) | hecha (solo análisis) | [`fases/F1_informe_cobertura.md`](fases/F1_informe_cobertura.md) |
| F2 árbitro de acciones | hecha (commit `3e035b4`) | [`technical-index/SYSTEMS/PLAYER.md`](technical-index/SYSTEMS/PLAYER.md) (sección «Árbitro de acciones») |
| F3 recepción y control | **implementada, pendiente de aprobación del usuario** | [`fases/F3_auditoria_124_clips.md`](fases/F3_auditoria_124_clips.md) (manda), [`fases/F3_clasificacion_124_v1_antecedente.md`](fases/F3_clasificacion_124_v1_antecedente.md) (antecedente), PLAYER.md (sección «Recepción y control con clips») |
| F4–F8 | sin empezar | ver §4 |

## 4. Plan de fases restante (del plan maestro del usuario)

- **F4 / F7:** transiciones de locomoción (alias de transición que faltan; F3 detectó que no hay clips de recepción a ras de piso
  para trote o carrera).
- **F5:** selección de clips de golpeo y contacto temprano (golpeos con contacto en cámara lenta, filtro `clean` de
  `plan_turn_kick`, colas congeladas).
- **F6:** dirección de las caídas.
- **F8:** cierre (limpieza autorizada, subida a la rama principal `ccr-a6c53cd2-uoxpk0`).
Hallazgos sueltos aún sin fase: el arquero ataja casi el 100 %; `Soccer_Spin` no existe (el regate no hace nada); clips del pack
que el código pide y no hacen nada (`Idle_To_Sprint`, `Sprint_Turn`, `Running_Tired`, `Defender_2`).

## 5. F3: lo que queda abierto (para el próximo chat)

- **Pruebas en rojo propias de F3** (`tests/test_receive.gd`): `test_lob_received_while_running` (un globo en carrera sin clip
  compatible: el control físico no controla pelotas a más de 0.7 m y se pierde) y `test_turn_reception_follows_the_stick` (con
  el joystick a 120° el cuerpo queda orientado pero la pelota apenas sale hacia allí).
- **70 clips pendientes de verificación visual** (estado `pending` en `scripts/player/receive_profiles.gd`): verlos con la pelota
  en `tools/json_anim/receive_view.tscn` y, si el contacto se confirma, añadirlos a `VERIFIED` del generador y regenerar.
- Poca variedad (domina `control_stand_1330`); rodilla y cabeza sin clip elegido/verificado; valores de
  `PlayerTuning.receive_contact` iniciales, sin contrastar en partido.
- **Regenerar perfiles** necesita los JSON originales (zip «animaciones_futbol5_nombres_originales» que aportó el usuario; no
  está en el repositorio): `python3 tools/json_anim/make_receive_profiles.py <carpeta_json>`.

## 6. Resultados de pruebas de referencia (para comparar)

| Suite | Resultado al cerrar F3 |
|---|---|
| `tools/run_tests.sh` (modo por defecto) | 255 pruebas, 3 fallos: `test_tripo_fallback…` (modo descartado) y los 2 de F3; 0 SCRIPT ERROR |
| `TEST_GAMEPLAY_MODE=4 tools/run_tests.sh` | 255 pruebas, 37 fallos, 24 omitidas, 25 SCRIPT ERROR: 35 preexistentes (F0/F2; SCRIPT ERROR de `juggle_controller.gd` y pruebas del pack) + los 2 de F3 |
| No deterministas conocidas | `test_player_actions::test_fall_moves_the_body…` (caída al azar), `test_pack_reactions::test_reaction_waits…`, `test_training_mode::test_teammates_do_not_crowd_the_dribbler` |
| Con render (Xvfb) | `json_mode` y `live_feet` con 1 fallo preexistente cada una; `live_kicks` 4/4; `test_receive` 21/21 al cierre de la primera versión de F3 |

Comandos: ver [`START_HERE.md`](START_HERE.md). Render: `TEST_GAMEPLAY_MODE=4 xvfb-run -a godot --rendering-driver opengl3
--fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <archivo>`; visor de recepción: `ANGLE=0 SPEED=12 [ARRIVE_Y=0.6]
[PASS=1] OUT=/ruta.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn`.

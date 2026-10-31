# Estado del proyecto y metodología de trabajo (traspaso entre chats)

> Leer esto ANTES de tocar nada, junto con [`START_HERE.md`](START_HERE.md) y el índice técnico. Última actualización:
> continuación de F3 (verificación visual de los 70 pendientes, fallos de F3 y F2, modo 4 predeterminado), 2026-10-30, sin
> commit: pendiente de revisión y autorización del usuario.

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
   como respaldo. (El código antiguo sigue ahí: no se borra por suposición sin autorización.) Desde el 2026-10-30 el juego
   arranca siempre en el 4 (`Tuning.DEFAULT_GAMEPLAY_MODE`, `PLAYABLE_MODES = [4]`) y el menú no ofrece los otros.
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
| F3 recepción y control | **implementada + verificación visual de los 70 pendientes (45 confirmados), pendiente de aprobación del usuario** | [`fases/F3_auditoria_124_clips.md`](fases/F3_auditoria_124_clips.md) (manda), [`fases/F3_verificacion_visual_70.md`](fases/F3_verificacion_visual_70.md) (manda para los 70), [`fases/F3_clasificacion_124_v1_antecedente.md`](fases/F3_clasificacion_124_v1_antecedente.md) (antecedente), PLAYER.md (sección «Recepción y control con clips») |
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

Hecho en la continuación del 2026-10-30 (detalle en el CHANGELOG): herramienta `CLIP=<id>` en
`tools/json_anim/receive_view.tscn`; verificación visual de los 70 `pending` (45 confirmados, 25 siguen pendientes); perfiles
regenerados con el zip (50 / 45 / 25 / 4); regresión de F2 en `test_tripo_fallback` corregida en `ActionArbiter.play_situation`;
los dos fallos de F3 (`test_lob_received_while_running`, `test_turn_reception_follows_the_stick`) pasan; anticipación que
conserva la orientación; modo 4 predeterminado.

Queda abierto:
- **3 pruebas de `test_receive` en rojo por decisión de diseño** (qué parte usar a cada altura): a 1.06 m se elige el muslo de
  3162 (verificado, muslo horizontal) en vez del pecho; a 0.91 m la rodilla de 0204 en vez del muslo. La pelota queda
  controlada en los tres casos. Opciones: aceptar las dos partes en la franja donde se solapan (pecho agachado ~1.0 m, muslo
  horizontal ~0.96–1.07 m) o preferir una parte en el plan. Necesita decisión del usuario.
- **25 clips siguen `pending`** (tabla en `fases/F3_verificacion_visual_70.md`): 11 con el instante al final del clip (habría
  que buscar el contacto real dentro del clip), el resto sin gesto claro. Rodilla y cabeza siguen sin clip verificado.
- El globo en carrera se resuelve frenando hasta un control de pecho casi parado: sigue sin haber recepción aérea en carrera
  con un clip de carrera (los de 1830/1834 en carrera están verificados pero la prueba eligió otro).
- `BallPredictor` usa la mitad del arrastre también en el aire (`DRAG_SCALE`): en vuelos de ~1 s la pelota real llega unos
  10–20 cm más baja y más tarde que la prevista (medido con el visor). Afecta a la recepción aérea con mucha anticipación, al
  arquero y a la IA: cambio transversal, sin tocar.
- La suite por defecto (`tools/run_tests.sh` sin `TEST_GAMEPLAY_MODE`) y el paso de pruebas del workflow siguen ejecutando la
  mayoría de las pruebas en el modo 1 (muchas pruebas vuelven al 1 al terminar): alinear la suite y el CI con el modo 4 es una
  decisión pendiente (F8).
- Valores de `PlayerTuning.receive_contact` iniciales, sin contrastar en partido; sin prueba en Android.
- **Regenerar perfiles** necesita los JSON originales (zip «animaciones_futbol5_nombres_originales», fuera del repositorio):
  `python3 tools/json_anim/make_receive_profiles.py <carpeta_json>` (veredictos visuales en `VISUAL` / `VISUAL_NOT`).

## 6. Resultados de pruebas de referencia (para comparar)

Medidos el 2026-10-30 con Godot 4.7.2 oficial al cerrar la continuación de F3 (sin commit). Entre paréntesis, la misma suite
sobre la base `a977fb3` ejecutada en la misma sesión.

| Suite | Resultado | Fallos y clasificación |
|---|---|---|
| `tools/run_tests.sh` (modo por defecto) | **258 pruebas, 4 fallos**, 18 omitidas, 0 SCRIPT ERROR (base: 255 / 3) | 3 de `test_receive` (parte del cuerpo distinta de la que la prueba asocia a la altura: decisión de diseño pendiente); `test_ai_match` (1 tiro de 19 desde un ángulo imposible): no determinista, pasó 2 de 2 al repetirla. Ya pasan `test_tripo_fallback` (regresión de F2) y los 2 de F3 |
| `TEST_GAMEPLAY_MODE=4 tools/run_tests.sh` | **258 pruebas, 39 fallos**, 24 omitidas, 25 SCRIPT ERROR (base hoy: 255 / 38 / 24 / 25) | Iguales a la base salvo: −2 de F3 (pasan), +3 de `test_receive` (diseño), `test_player_actions::test_fall…` (no determinista conocida: pasó 2 de 2 al repetirla) y `test_set_pieces::…throw_in…` (falló solo en la base: no determinista). El resto: preexistentes de F0/F2 (SCRIPT ERROR de `juggle_controller.gd`, pruebas del pack/Tripo en el modo 4) |
| Con render, modo 4 | `test_receive` 30 / 3 fallos (los mismos 3); `live_feet` 7 / 1 y `json_mode` 10 / 1 (preexistentes); `pack_motion` 2 / 0; `live_kicks` 4 / 1 → al repetir 1 fallo con otro motivo y luego 0 (no determinista) | |
| Con render, modo por defecto | `live_kicks` 4 / 0, `pack_motion` 2 / 0, `live_feet` 7 / 1 y `json_mode` 10 / 1 (preexistentes) | |
| Nuevas | `test_gameplay_mode_default` 3 / 0; arranque real con Xvfb (instalación limpia y preferencias antiguas con modo 1) → modo 4 | |
| No deterministas conocidas | `test_player_actions::test_fall_moves_the_body…`, `test_pack_reactions::test_reaction_waits…`, `test_training_mode::test_teammates_do_not_crowd_the_dribbler`, `test_ai_match`, `live_kicks` (modo 4), `test_set_pieces::…throw_in…` | |

Comandos: ver [`START_HERE.md`](START_HERE.md). Render: `TEST_GAMEPLAY_MODE=4 xvfb-run -a godot --rendering-driver opengl3
--fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <archivo>`; visor de recepción: `ANGLE=0 SPEED=12 [ARRIVE_Y=0.6]
[PASS=1] OUT=/ruta.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn`;
auditar un clip: `CLIP=<id> [PART=…] [T=…]` con el mismo visor (ver `tools/json_anim/README.md`).

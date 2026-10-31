# Estado del proyecto y metodología de trabajo (traspaso entre chats)

> Leer esto ANTES de tocar nada, junto con [`START_HERE.md`](START_HERE.md) y el índice técnico. Última actualización:
> programa maestro E1-E6 (estabilización, auditoría del banco completo, conducción, golpeo, defensa y arquero, predicción
> aérea, APK por GitHub Actions), 2026-10-31. Informe: [`fases/E_programa_maestro_informe.md`](fases/E_programa_maestro_informe.md).

## 1. Ramas

| Rama | Uso |
|---|---|
| `respaldo-f3` | **Rama de trabajo actual.** Todo se desarrolla y se guarda aquí (commits y push en esta rama). |
| `ccr-a6c53cd2-uoxpk0` | **Rama principal** (la rama por defecto del repositorio en GitHub; no existe `main`). **No se toca** hasta que el usuario dé por terminado el trabajo; entonces se sube todo de una vez. |
| `ccr-7a7dba29-jfbum5` | Rama de una sesión anterior (F0–F3); su contenido ya está en `respaldo-f3`. No se usa más. |

Historial de `respaldo-f3` (de más nuevo a más viejo): programa maestro E1-E6 (ver el informe), continuación de F3 (`7c3a622`),
traspaso (`a977fb3`), F3 corregido (`ff6124b`), F3 en curso (`895b3f8`), F2 árbitro de acciones
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
| F3 recepción y control | hecha (`7c3a622`; franjas de altura decididas en E1) | [`fases/F3_auditoria_124_clips.md`](fases/F3_auditoria_124_clips.md), [`fases/F3_verificacion_visual_70.md`](fases/F3_verificacion_visual_70.md) |
| Programa maestro E1-E6 (sustituye a F4-F8, autorizado en un solo mensaje del usuario) | hecho | [`fases/E_programa_maestro_informe.md`](fases/E_programa_maestro_informe.md), [`fases/E2_auditoria_banco.md`](fases/E2_auditoria_banco.md), inventario [`fases/E2_inventario_banco.csv`](fases/E2_inventario_banco.csv) |

## 4. Lo que queda abierto

- 25 clips de recepción siguen `pending` (sin verificación visual); rodilla y cabeza sin clip verificado.
- Sin clips en el banco: ruleta (`Soccer_Spin`), `Sprint_Turn`, malabares (el botón de la práctica se oculta).
- Curva de los tiros pequeña (0.05-0.17 m en 11 m): el palo «del que el empeine la aleja» ya no es más difícil para el
  arquero (antes lo era por un error de predicción). Cambiar el efecto del tiro es mecánica: decisión del usuario.
- Pruebas estadísticas sin semilla fija que a veces fallan (ver §6).
- Sin prueba en Android real: la APK se genera y verifica en GitHub Actions.
- Subida a la rama principal `ccr-a6c53cd2-uoxpk0`: pendiente de la orden del usuario.

## 5. Cómo regenerar los datos del banco

- Perfiles de recepción: `python3 tools/json_anim/make_receive_profiles.py <carpeta_json>` (veredictos en `VISUAL` /
  `VISUAL_NOT`).
- Auditoría del banco: `python3 tools/json_anim/analyze_bank.py <carpeta_json>` → `docs/fases/E2_inventario_banco.csv` y
  `scripts/animation/clip_roles_overlay.gd`.
- Los JSON originales (zip «animaciones_futbol5_nombres_originales») están fuera del repositorio; no se modifican.

## 6. Resultados de pruebas de referencia (para comparar)

Medidos el 2026-10-31 con Godot 4.7.2 oficial al cerrar el programa maestro. La suite por defecto corre en el modo 4 (cada
prueba elige su modo con `TestCase.gameplay_mode()`; las del pack heredado fijan el 1).

| Suite | Resultado | Fallos y clasificación |
|---|---|---|
| `tools/run_tests.sh` | **277 pruebas, 1 fallo**, 25 omitidas, 1 622 comprobaciones, 0 SCRIPT ERROR | `test_training_mode::test_training_has_only…` «hay pases (4)»: no determinista (partido sin semilla; al repetirla 11 y 12 pases, pasa 2 de 2) |
| Con render (xvfb), modo 4 | `live_kicks` 4 / 0 (batería de 50 golpeos: 49 con contacto, 0 inválidos), `live_feet` 7 / 0, `pack_motion` 2 / 0, `json_mode` 9 / 0 (1 omitida) | |
| `test_shot_keeper` (80 tiros por caso) | 1 / 0 | palo derecho ataja 69 %, izquierdo 76 %, al arquero 84 %, rival encima 0 goles, tirador de 85 ataja 32-36 % |
| No deterministas conocidas | `test_training_mode` (pases y compañeros), `test_ai_match`, `test_player_actions::test_fall…`, `test_shot_keeper` (comparaciones entre casos), `test_set_pieces::…throw_in…` | |

Comandos: ver [`START_HERE.md`](START_HERE.md). Render: `TEST_GAMEPLAY_MODE=4 xvfb-run -a godot --rendering-driver opengl3
--fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <archivo>`; visor de recepción: `ANGLE=0 SPEED=12 [ARRIVE_Y=0.6]
[PASS=1] OUT=/ruta.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn`;
auditar un clip: `CLIP=<id> [PART=…] [T=…]` con el mismo visor (ver `tools/json_anim/README.md`).

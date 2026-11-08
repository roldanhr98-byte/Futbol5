# Cómo continuar la reforma (tiros libres y penales) en un chat nuevo

Última actualización: 2026-11-08. Último commit al escribir esto: `70513bc` en `reforma-tiros-penales`.

## 1. Prompt para pegar en el chat nuevo

```
Trabajá sobre el repositorio roldanhr98-byte/Futbol5, rama `reforma-tiros-penales` (no toques `integracion-openai`
ni `respaldo-f3`, no abras PR ni hagas merges). Estamos reformando el juego (Godot 4.7.2, Android) para que tenga
SOLO dos modos: tiros libres y penales, en orientación HORIZONTAL 16:9 (otras proporciones sin deformar el campo; nunca
vertical). El modo de fútbol 5 ya se quitó de esta rama; se conserva todo lo reutilizable (animaciones, física, golpeos,
arquero, árbitro de acciones).

Antes de tocar nada, leé en este orden:
1. docs/reforma/CONTINUAR_REFORMA.md (este documento: estado y siguientes pasos)
2. docs/reforma/INSTRUCCION_REFORMA.md (mi instrucción completa de la reforma y mis decisiones posteriores; manda sobre todo)
3. docs/reforma/ESTADO_REFORMA.md, FASE0_AUDITORIA_Y_PLAN.md, FASE1_INFORME.md, FUTBOL5_QUITADO.md
4. CLAUDE.md y docs/technical-index/INDEX.md (índice técnico; ficha docs/technical-index/SYSTEMS/REFORMA.md)

Reglas: trabajar por fases; al terminar cada una entregar informe, archivos, pruebas y APK y ESPERAR mi autorización
antes de la siguiente. No elegir por mí el banco de animación (JSON / Mixamo / Mocap), no mezclarlos y no rellenar huecos
con clips de otro banco. No modificar los originales. No inventar resultados: informar fallos con la salida real. No
conectar Supabase. No relajar ni desactivar pruebas para que pase la CI. Commits con las líneas de atribución de la sesión.

Estado: Fase 0 y Fase 1 entregadas (banco de pruebas con selector de bancos; APK de la compilación 68). Espero mi decisión
sobre cómo comparar Mixamo y Mocap (opciones A/B/C del §6 de docs/reforma/FASE1_INFORME.md) y sobre qué banco(s) me
convencen tras probar la APK. NO avances a la Fase 2 ni a otra sin que te lo autorice. Primero verificá el estado real
del repositorio (git status, último commit, última compilación de GitHub Actions), resumime en pocas líneas dónde estamos
y preguntame lo que necesites de las decisiones pendientes.
```

## 2. Dónde estamos

| Fase | Estado |
|---|---|
| 0 Auditoría y plan | entregada |
| 1 Bancos: selector y comparación | entregada; **esperando decisión del usuario** |
| 2 Comparación visual con escenas equivalentes | no empezada (el banco de pruebas ya cubre parte) |
| 3 Nueva estructura (menú, modos, cámaras, cancha de fútbol 11) | no empezada |
| 4 Tiros libres | no empezada (requisitos en `INSTRUCCION_REFORMA.md`, decisión 6) |
| 5 Penales · 6 Integración de animaciones · 7 Red · 8 IA · 9 Progresión · 10 Online · 11 Optimización | no empezadas |

Hecho hasta ahora en la rama (resumen; detalle en los informes):

- Rama creada desde `integracion-openai` (`9c6f82a`); `respaldo-f3` sin cambios (`3d47a07`).
- Banco de pruebas horizontal 16:9 (`scenes/dev/anim_bank_bench.tscn`) con selector JSON / Mixamo / Mocap, cuerpo común
  (humano JSON) o cuerpo original del banco, 25 acciones de tirador, barrera y arquero, «sin clip en este banco», golpe de
  referencia en el contacto del clip y mediciones en vivo. Menú de desarrollo como escena principal.
- Catálogo por procedencia (`resources/animation/catalogo_bancos.json`) y medición de compatibilidad
  (`tools/reforma/bank_compat.gd`, resultados en `docs/reforma/fase1/`).
- Fútbol 5 quitado de la rama (escenas, acceso, 35 archivos de pruebas más 4 pruebas sueltas, baterías de CI). Su código queda
  sin escena porque sistemas reutilizados lo nombran (`MatchScene`, `MatchManager`); se desacopla en la Fase 3.
- Pruebas: suite headless 132 pruebas, 0 fallidas, 13 omitidas (necesitan render); 5 baterías con render 0 fallidas;
  GitHub Actions en verde (compilación 68, APK `futbol5-apk`).

## 3. Hallazgo clave de la Fase 1 (no corregido)

Los tres bancos animan los mismos 23 huesos, pero **Mixamo y Mocap se convirtieron para el futbolista (`player_base.glb`) y
sus reposos de hueso difieren hasta 177° del humano JSON**. Sobre el humano JSON los pies flotan ~27 cm y el contacto del
golpeo queda a ~1,2 m de la pelota; sobre su cuerpo original quedan bien (contacto a 0,00 m, pies apoyados). El banco JSON
cubre las 25 acciones; Mixamo, 20; Mocap, 8 (sin barrera ni casi nada del arquero). Cifras y tabla completa en
`docs/reforma/FASE1_INFORME.md`.

## 4. Decisiones pendientes del usuario (no avanzar sin ellas)

1. **Cómo comparar Mixamo y Mocap:** **A** retarget en memoria al humano JSON (sin tocar archivos; es una corrección, requiere
   autorización); **B** compararlos sobre su cuerpo original (ya disponible con el botón de diagnóstico del banco); **C** otra.
2. **Qué banco o bancos usar**, después de probar la APK (no se elige por el usuario).
3. **Autorización de la fase siguiente** (la 2, o saltar a la 3 si el usuario lo prefiere).

## 5. Siguientes pasos probables (una vez decididas las tres cosas de arriba)

1. **Fase 2 / decisión de bancos:** si la respuesta es A, implementar el retarget en memoria como opción separada del banco
   de pruebas, con prueba (pies apoyados, contacto a ≤ 0,25 m) y APK; si es B, cerrar la comparación con el informe actual.
2. **Fase 3:** desacoplar el código del partido (quitar `MatchScene`/`MatchManager` de los sistemas reutilizables), menú
   principal horizontal (Tiros libres, Penales, Entrenamiento, Estadísticas, Progreso), estado de partida por turnos,
   cámaras (detrás del tirador con zoom; fija en penales), **cancha de fútbol 11 nueva** (no estirar la actual), pruebas de
   encuadre en 4:3, 16:10, 16:9, 19,5:9 y 21:9.
3. **Fase 4:** posición libre del balón, barrera real con colisión y salto sincronizado, trazo del dedo → velocidad y giro
   con `Ball.kick` (sin teletransportar), carrera y golpeo con el banco elegido, arquero que lee la trayectoria. Requisitos
   del modo en `INSTRUCCION_REFORMA.md` (decisión 6).

## 6. Cómo trabajar (comandos y trampas)

- Godot 4.7.2 en `/usr/local/bin/godot`. Antes de la primera ejecución en un árbol nuevo: `godot --headless --path . --import`.
- Suite: `tools/run_tests.sh` (≈ 2 min) o `tools/run_tests.sh <filtro>`. Con render (esqueleto animado), ver
  `docs/START_HERE.md`: `xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn -- --filter <nombre>`.
- Los scripts del juego usan el autoload `Tuning`: las herramientas que los cargan deben ser **escenas**, no `--script`
  (ver `tools/reforma/bench_captures.tscn`).
- Tras cambiar código: `python3 tools/docs_index.py sync` y `check` (0 errores) y una entrada en
  `docs/technical-index/CHANGELOG.md`.
- **Cada push de código dispara la APK en GitHub Actions** (artefacto `futbol5-apk`, ~25 min con render); un push nuevo
  **cancela** la compilación en curso. Los pushes que solo tocan `docs/**` o `*.md` no la disparan. Si la CI falla por una
  prueba, no se desactiva: se investiga o se relanza el mismo commit y se informa.
- Los `*.log` están ignorados por git: la evidencia de pruebas va en carpetas con su propio `.gitignore` de excepción
  (ejemplo: `docs/reforma/pruebas_sin_futbol5/`).
- El proxy de la sesión bloquea el push de tags; los push de ramas funcionan.
- No hay dispositivo Android en la sesión: la medición de rendimiento y tacto en el teléfono la hace el usuario.
- Los 2.022 JSON originales **no están en el repositorio** (solo en el ZIP del usuario, `animaciones_futbol5_nombres_originales1.zip`,
  sha256 `3fa72c92ae35fe58540dd130d841534e0c73a2308a131f71a503ecd8ad8b374f`); los hashes están en
  `docs/integration/fase0/hashes_json_originales.sha256`. Las bibliotecas convertidas sí están en `assets/animations/`.
- Los videos e imágenes de referencia del usuario tampoco están en el repositorio; si hacen falta, pedirlos de nuevo.
- Trabajo anterior en pausa (en `integracion-openai`): guía maestra de animaciones del partido, ver
  `docs/integration/CONTINUAR_GUIA_ANIMACIONES.md`. No es parte de esta reforma.

# Seguimiento de la guía maestra del sistema de animaciones

Documento único de seguimiento por etapa (formato de la sección 17 de la guía). Cada etapa: estado inicial, problema
confirmado, archivos, cambio, sistemas reutilizados, pruebas, comparación, criterios de aborto, pendientes, integridad y
commit. Niveles de evidencia que no se mezclan: registrado · importado · seleccionable · invocado · completado · contacto
validado · visualmente correcto en render · probado en Android.

Línea base: tag local `pre-audit-phase-0` = `04ed110`. Métricas base: [`fase0/linea_base/`](fase0/linea_base/).
Pruebas de bloqueo y umbrales: [`AUDITORIA_PRE_IMPLEMENTACION.md`](AUDITORIA_PRE_IMPLEMENTACION.md) §9 y §10.

---

## Etapa 0 — Auditoría del repositorio y línea base

1. **Estado inicial:** `integracion-openai` en `04ed110`, árbol limpio; código idéntico a `5fb4f27`.
2. **Problema confirmado:** ver la auditoría del 2026-11-07 (`AUDITORIA_SISTEMA_ANIMACIONES.md`); cifras re-medidas.
3. **Archivos involucrados:** ninguno de juego.
4. **Cambio realizado:** documentación, herramienta de medición, línea base, hashes, ticket F9-001.
5. **Sistemas reutilizados:** todos sin cambios.
6. **Pruebas:** suite headless 310/0 (28 omitidas, 2.992 comprobaciones); 8 baterías con render 0 fallidas; 0 fugas;
   6 partidos de 10 min + 1 de 3 min con render (`fase0/linea_base/`).
7. **Comparación:** es la base.
8. **Criterios de aborto:** definidos en `AUDITORIA_PRE_IMPLEMENTACION.md` §10.
9. **Pendientes:** subir el tag (bloqueado por el proxy de la sesión); determinismo (F9-001, Fase 9).
10. **Integridad:** 2.023/2.023 hashes de los JSON originales (ZIP subido, sha256 `3fa72c92…d8b374f`); 47/47 hashes
    de recursos; `respaldo-f3` = `3d47a07`.
11. **Commit:** `7c1e9da` (Fase 0) y el commit que agrega este documento y los hashes de los originales.

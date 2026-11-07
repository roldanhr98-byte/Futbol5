# Continuación de integración — 2026-11-07

Estado parcial: de los 338 tramos pendientes históricos, 262 tienen consumidor y prueba de invocación; 76 siguen pendientes. No se declara completa la integración. Los 2.022 originales y la rama respaldo-f3 se conservan.

## Evidencia individual

- `estado_338.csv`: comparación histórica y actual por tramo, consumidor, acción, condición y evidencia.
- `pendientes_actuales.csv`: 76 conexiones que todavía requieren implementación o validación física.
- `visual/`: 14 páginas de cuatro poses por clip NIS; inspección para clasificar su contenido, no certificación de interacción completa.
- `pruebas/` y `evidencia_sha256.json`: resultados ejecutados y sumas. El generador `tools/integration/reconcile_connections.py` exige resultados sin fallos para registrar evidencia.
- `resources/animation/connection_routes.json`: consulta central de estado actual; `environment_routes.json`: actores y eventos de presentación, consultables mediante AnimDB.

## Conexiones

204 rutas de presentación ambiental, 25 variantes de marcha, 11 giros de arquero, 13 transiciones de locomoción, 5 tiros libres, 2 centros laterales, 1 preparación de saque lateral y 1 reacción a pelotazo en la cara. Se verifican en consumidores reales y no sólo en AnimationPlayer. Los espejos ambientales también se prueban. La presentación crea actores bajo demanda y comparte las bibliotecas; cada actor mantiene una sola acción. Los eventos de gol, falta, inicio y reinicio seleccionan contextos apropiados sin alterar la pelota.

Las patadas recuperadas conservan la tolerancia física de contacto: se mide el segmento recorrido por el pie entre cuadros, dentro de la ventana existente. La selección conserva restricciones de cancha. Los centros laterales pasan los filtros físicos habituales. El saque mantiene la pelota sostenida durante la preparación; el pelotazo exige una colisión real a la altura de la cara.

## Arquero y render

El arquero recibe avisos SHOT sólo cuando coinciden con el último golpeador real y la dirección física del balón. La predicción existente decide si hay amenaza al arco. El contador shots_seen distingue lectura de disparos de shots_faced (trayectoria peligrosa). La prueba aleatoria anterior exigía shots_faced aunque el disparo podía ir afuera; se corrige esa afirmación y se agrega una prueba independiente con tiro real al arco y atajada/despeje.

Los dos fallos anteriores de live_feet se reprodujeron en la base: exceso de solapamiento en giros y poco avance al girar en sprint. Se ajustaron frenado y velocidad radial con distancia de frenada, también en el predictor. La nueva mezcla Carry usa los mismos nodos y cadencias del catálogo JSON. Una regresión intermedia queda documentada en regresion_mezcla_detectada.log y fue corregida antes del resultado pies_render.log: 7 pruebas, 0 fallidas, 66 comprobaciones.

El diagnóstico de punta distingue pose base y pose final: Skeleton3D fuera del modificador entrega la pose base. TouchFootIK captura la punta final durante el modificador, y la prueba espera al render para medirla. En sprint, 0,31 m corresponde a pose base y 0,13 m a pose visible final. La tolerancia visible sigue en 0,30 m; ambos valores se conservan en el log.

## GitHub Actions

Se revisó el único workflow, android.yml. Mantiene Godot 4.7.2, plantilla oficial Android verificada por SHA-512, suite headless completa, auditoría individual y pruebas con render antes de exportar. La APK arm64 se firma con una clave efímera de depuración y se verifica dentro del trabajo. Las dos rutas JSON nuevas se incluyen en export_presets.cfg.

Después de habilitar Read and write permissions en Settings, el despacho manual desde la credencial de esta sesión sigue devolviendo HTTP 403 Resource not accessible by integration. Ese ajuste controla el token de los trabajos, no concede el permiso actions:write a la integración que hace la solicitud externa. No se accedió ni sustituyó ningún secreto.

Se habilitó push para integracion-openai y se eliminaron la opción y el paso de publicación de Releases. El workflow sólo necesita contents:read y produce el artefacto futbol5-apk con retención de 14 días. El push del commit 66bb987 inició realmente https://github.com/roldanhr98-byte/Futbol5/actions/runs/42328612668. El estado de esa ejecución no certifica las correcciones locales aún no subidas; la siguiente ejecución debe compilar su commit exacto. No hay APK exitoso certificado todavía.

## Validación pendiente

La suite completa local se está ejecutando nuevamente. Los resultados parciales no se presentan como aprobación completa. Las 76 filas restantes incluyen recepciones y contactos sin sincronización validada, acciones con objetos o participantes secundarios y poses de referencia. Son trabajo pendiente; no se consideran imposibles sólo por faltar JSON fuente. No se eliminan ni se declaran conectadas por el mero registro en el banco.

## Revisión posterior al commit 7cc6d0a

El render adicional detectó una regresión de pase de primera: la prueba pasó en el checkout independiente 0b46c10 y falló con las transiciones nuevas. La transición podía cancelar una carga antes de que BallHandler registrara la orden. Footballer ahora respeta botones pulsados, mantenidos y liberados; PlayerActions excluye la aproximación física de una pelota. Revalidación con render: 1 prueba, 0 fallidas, 4 comprobaciones. Las 14 transiciones siguen invocándose en sus estados propios y la prueba negativa nueva comprueba que no interrumpan una pelota entrante: 2 pruebas, 0 fallidas, 46 comprobaciones.

La suite parcial encontró un partido de 120 s sin tiros; la serie de tres partidos produjo 8. La exigencia de producir tiros se trasladó a esa serie; cada partido comprueba la lectura si realmente hubo SHOT. La prueba de atajada física independiente conserva su exigencia. Esta revisión de la afirmación estadística está pendiente de resultado completo; no certifica aún la suite.

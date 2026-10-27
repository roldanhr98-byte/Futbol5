# Fútbol 5

Juego de fútbol 5 / futsal para Android hecho con **Godot 4.7.2** (GDScript, renderer GL Compatibility, física Jolt a 60 Hz).
4 contra 4 con arquero en cada equipo, IA, pases y tiros asistidos, conducción con pelota física, barridas, caídas,
árbitro y una sala de práctica con las 133 animaciones.

## Probar el juego (APK de Android)

1. En este repositorio: **Actions → Android APK → Run workflow**, activando **publish_release**.
2. Al terminar (unos 10 minutos) aparece una *pre-release* `apk-prueba-N` en **Releases** con el APK adjunto: cualquiera puede
   descargarlo desde ahí, sin cuenta de GitHub.
3. En el teléfono, permitir «instalar apps desconocidas» para el navegador e instalar el `.apk`. Si había una versión anterior,
   desinstalarla primero (cada APK de prueba se firma con una clave de depuración distinta).

El APK es de **prueba** (arm64, firma de depuración, sin permisos). Sin `publish_release`, el APK queda como artefacto de la ejecución.

## Cómo se juega

El control es cercano: la pelota vive junto al pie y se aleja solo cuando tú la empujas. Al soltar el joystick el
jugador **para la pelota**; con un rival encima **la protege** con el cuerpo; un empuje de costado a poca velocidad
la **desplaza de lado** sin girar el cuerpo; a sprint el toque es más largo y un defensor bien colocado puede
robártela. El arquero propio se puede **manejar** (CAMBIO con la jugada en tu área): obedece el joystick, no se
lanza solo, atrapa o despeja con el botón y saca cuando se lo pides; una cedida tuya la recibe con el pie, no se
tira como si fuera un disparo. Un cono cian marca a quien controlas y uno ámbar a quien pasarías con CAMBIO.

## Controles

Joystick flotante a la izquierda; a la derecha: **PASE**, **TIRO**, **SPRINT**, **PRESIÓN**, **ALTO** (pase/tiro elevado),
**REGATE** (ruleta) y **CAMBIO** (cambia al compañero más cercano a la pelota). En PC: WASD mover, J pase, K tiro, I elevado, U regate, L presión, Q cambio, Shift sprint, Esc pausa; desde la pausa se
abre la **sala de práctica**.

## Desarrollo

- Abrir la carpeta con Godot 4.7.2; la escena principal es `scenes/main/match.tscn`.
- Pruebas: `tools/run_tests.sh` (suite headless; `tools/run_tests.sh <filtro>` para una parte).
- Documentación técnica: [`docs/technical-index/INDEX.md`](docs/technical-index/INDEX.md) (sistemas, archivos, parámetros, historial).
- Las animaciones (Mixamo) están convertidas dentro del juego en `assets/animations/pack_clips.res` y `pack_keeper.res`.
  Para reconvertirlas hace falta el pack original en `pack/` (no se sube), ver
  [`tools/animation_pack/README.md`](tools/animation_pack/README.md).

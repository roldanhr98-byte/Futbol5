# PERFORMANCE — Perfiles gráficos y diagnóstico

## Identificación

- **Responsabilidad exacta:** controlar el coste de renderizado según el dispositivo (escala 3D, MSAA, sombras, elementos ambientales) y mostrar en pantalla lo que **realmente se mide** (FPS, tiempos de fotograma/proceso/física, llamadas de dibujo, nodos, memoria, errores).
- **Estado:** implementado a nivel de código. **No hay ninguna medición en un dispositivo Android real**: los valores por perfil son heurísticos y no están validados contra FPS reales.
- **Última verificación:** <!-- AUTO:verified -->
2026-10-26
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/diagnostics/graphics_settings.gd` | Autoload `GraphicsSettings`: perfiles, detección inicial, aplicación y persistencia (`user://graphics.cfg`) | `GraphicsSettings.PROFILES`, `GraphicsSettings.apply`, `GraphicsSettings.set_profile`, `GraphicsSettings.detect_default_profile` | `Viewport`, `RenderingServer`, grupo `sun_light` |
| `scripts/diagnostics/diagnostics_overlay.gd` | `DiagnosticsOverlay` (`Label`): informe cada 0.4 s y `Logger` propio que cuenta errores/avisos del motor | `DiagnosticsOverlay.build_report`, `DiagnosticsOverlay.frame_stats` | `Performance`, `OS.add_logger` |
| `scripts/pitch/pitch.gd` | Crea `Sun` (grupo `sun_light`), el entorno y los elementos ambientales (bancos, gradas, torres de luz) | `Pitch._build_lighting`, `Pitch._build_ambient` | `GraphicsSettings` |
| `project.godot` | Renderer `gl_compatibility` (también para móvil), MSAA 0, atlas de sombra direccional 2048, compresión de texturas ETC2/ASTC, física 60 Hz | `[rendering]`, `[physics]` | — |

## Mapa de parámetros

### Perfiles (`GraphicsSettings.PROFILES`, valores exactos del código)

<!-- AUTO:constdef:scripts/diagnostics/graphics_settings.gd#PROFILES -->
`scripts/diagnostics/graphics_settings.gd:19`

```gdscript
const PROFILES: Dictionary = {
	Profile.VERY_LOW: {
		"scale_3d": 0.6, "msaa": Viewport.MSAA_DISABLED, "shadows": false,
		"shadow_size": 1024, "ambient_props": false, "target_fps": 30,
	},
	Profile.LOW: {
		"scale_3d": 0.75, "msaa": Viewport.MSAA_DISABLED, "shadows": false,
		"shadow_size": 1024, "ambient_props": true, "target_fps": 30,
	},
	Profile.MEDIUM: {
		"scale_3d": 0.9, "msaa": Viewport.MSAA_DISABLED, "shadows": true,
		"shadow_size": 1024, "ambient_props": true, "target_fps": 60,
	},
	Profile.HIGH: {
		"scale_3d": 1.0, "msaa": Viewport.MSAA_2X, "shadows": true,
		"shadow_size": 2048, "ambient_props": true, "target_fps": 60,
	},
}
```
<!-- /AUTO -->

| Perfil | Quién lo elige |
|---|---|
| Valor por defecto | `detect_default_profile`: en `android`/`ios` según núcleos (`≤ 4` → Muy bajo, `≤ 6` → Bajo, resto → Medio); en escritorio, Alto. Solo si no hay `user://graphics.cfg`. |
| Cambio manual | Menú de pausa → «Gráficos» (cicla los 4 perfiles y guarda). |

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| `scale_3d` × `resolution_override` | `root.scaling_3d_scale = clamp(scale_3d · override, 0.4, 1.0)`. Principal palanca de coste en GPU móvil. `resolution_override` no tiene interfaz (solo `set_resolution_override`, sin llamadores). |
| `msaa` | Solo `HIGH` usa 2×. |
| `shadows` / `shadow_size` | Se aplican al grupo `sun_light` y al atlas direccional. Con sombras apagadas el jugador no proyecta sombra. |
| `ambient_props` | Se evalúa **al construir la cancha** (`Pitch._build_ambient`); cambiar el perfil en la pausa **no** muestra/oculta las gradas hasta el siguiente arranque. |
| `target_fps` | **Sin efecto:** `apply` fuerza `Engine.max_fps = 0` y `project.godot` tiene `run/max_fps=0`. |
| Física a 60 Hz (`physics_ticks_per_second`) | Los parámetros de la pelota (`Ball`, Jolt) están ajustados a 60 Hz; cambiarlo exige revisar [BALL](BALL.md). |

## Mapa de funciones

<!-- AUTO:funcs:scripts/diagnostics/graphics_settings.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `GraphicsSettings._ready()` | 42 |  |
| `GraphicsSettings.detect_default_profile()` | 49 | Heuristica de perfil inicial segun la plataforma y el hardware. No sustituye a medir. |
| `GraphicsSettings.set_profile(new_profile: int)` | 59 |  |
| `GraphicsSettings.set_resolution_override(value: float)` | 65 |  |
| `GraphicsSettings.get_params()` | 70 |  |
| `GraphicsSettings.profile_name()` | 73 |  |
| `GraphicsSettings.shadows_enabled()` | 76 |  |
| `GraphicsSettings.ambient_props_enabled()` | 79 |  |
| `GraphicsSettings.apply()` | 83 | Aplica el perfil al viewport principal y a las luces registradas en el grupo "sun_light". |
| `GraphicsSettings.save_settings()` | 95 |  |
| `GraphicsSettings.load_settings()` | 103 |  |
| `GraphicsSettings._has_saved_settings()` | 110 |  |
<!-- /AUTO -->

<!-- AUTO:signals:scripts/diagnostics/graphics_settings.gd -->
| Señal | Línea | Descripción |
|---|---|---|
| `GraphicsSettings.profile_changed(profile: int)` | 5 | Autoload "GraphicsSettings": perfiles graficos (muy bajo, bajo, medio, alto) y persistencia. Los perfiles controlan resolucion 3D, MSAA, sombras y detalle de redes/ambiente. |
<!-- /AUTO -->

<!-- AUTO:funcs:scripts/diagnostics/diagnostics_overlay.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `DiagnosticsOverlay.CaptureLogger._log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace])` | 15 |  |
| `DiagnosticsOverlay.CaptureLogger.snapshot()` | 28 |  |
| `DiagnosticsOverlay._ready()` | 39 |  |
| `DiagnosticsOverlay._process(delta: float)` | 50 |  |
| `DiagnosticsOverlay.build_report()` | 60 |  |
| `DiagnosticsOverlay.frame_stats()` | 80 | Estadisticas de fotograma para informes de rendimiento (usado por la herramienta de benchmark). |
<!-- /AUTO -->

## Recorrido de ejecución

1. Arranque: `GraphicsSettings._ready` → carga `user://graphics.cfg` (o `detect_default_profile`) → `apply()`.
2. `MatchScene._ready` vuelve a llamar `GraphicsSettings.apply()` tras crear la cancha; `Pitch._build_lighting` también lo llama si está en el árbol.
3. `Hud` crea `DiagnosticsOverlay`; se muestra si `Tuning.show_diagnostics` (menú de pausa → «Diagnóstico», persistido en `user://settings.cfg`).
4. El informe incluye: FPS y ms (media y pico de los últimos 120 fotogramas), `TIME_PROCESS`/`TIME_PHYSICS_PROCESS`, llamadas y primitivas de dibujo, nodos, memoria estática, perfil, resolución 3D, y errores/avisos capturados con el `Logger` (últimos 3 mensajes).

## Pruebas

- **Ejecutar:** no hay ninguna.
- **Alcance real:** `grep -rn GraphicsSettings tests` no encuentra nada. Ni los perfiles, ni la persistencia, ni el informe del diagnóstico están cubiertos. Lo único medido es el coste de la simulación en las pruebas (la suite completa corre en ~10 s headless), que **no** es una medición de rendimiento gráfico.
- **Qué podría romperse:** `OS.add_logger` solo existe en versiones recientes de Godot (usado con 4.7.2); un perfil con clave faltante rompe `get_params()["…"]`.

## Limitaciones conocidas (pendientes)

- **Sin mediciones en Android:** no hay números de FPS reales en ningún dispositivo ni en el emulador. El objetivo de gama baja (30 FPS en perfil Muy bajo) es una intención, no un resultado.
- `DiagnosticsOverlay.frame_stats` (media, p95, máximo) está pensada para una herramienta de benchmark que **no existe**; `GraphicsSettings.profile_changed`, `shadows_enabled` y `set_resolution_override` no tienen consumidores.
- Sin pool de objetos, LOD ni oclusión: la cancha son pocas mallas, pero la cantidad de nodos y llamadas de dibujo no se ha perfilado.
- El jugador usa 7640 triángulos (límite impuesto por la prueba: 10 000); con 10 jugadores el presupuesto de geometría no se ha medido.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Partido jugable».

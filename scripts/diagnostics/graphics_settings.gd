extends Node
## Autoload "GraphicsSettings": perfiles graficos (muy bajo, bajo, medio, alto) y persistencia.
## Los perfiles controlan resolucion 3D, MSAA, sombras y detalle de redes/ambiente.

signal profile_changed(profile: int)

enum Profile { VERY_LOW, LOW, MEDIUM, HIGH }

const SETTINGS_PATH := "user://graphics.cfg"

const PROFILE_NAMES: Dictionary = {
	Profile.VERY_LOW: "Muy bajo",
	Profile.LOW: "Bajo",
	Profile.MEDIUM: "Medio",
	Profile.HIGH: "Alto",
}

## Parametros por perfil.
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

var profile: int = Profile.MEDIUM
## Multiplicador manual de resolucion 3D (0.5 - 1.0) aplicado encima del perfil.
var resolution_override: float = 1.0

func _ready() -> void:
	load_settings()
	if not _has_saved_settings():
		profile = detect_default_profile()
	apply()

## Heuristica de perfil inicial segun la plataforma y el hardware. No sustituye a medir.
func detect_default_profile() -> int:
	if OS.has_feature("android") or OS.has_feature("ios"):
		var cores: int = OS.get_processor_count()
		if cores <= 4:
			return Profile.VERY_LOW
		if cores <= 6:
			return Profile.LOW
		return Profile.MEDIUM
	return Profile.HIGH

func set_profile(new_profile: int) -> void:
	profile = clampi(new_profile, Profile.VERY_LOW, Profile.HIGH)
	apply()
	save_settings()
	profile_changed.emit(profile)

func set_resolution_override(value: float) -> void:
	resolution_override = clampf(value, 0.5, 1.0)
	apply()
	save_settings()

func get_params() -> Dictionary:
	return PROFILES[profile]

func profile_name() -> String:
	return PROFILE_NAMES[profile]

func shadows_enabled() -> bool:
	return get_params()["shadows"]

func ambient_props_enabled() -> bool:
	return get_params()["ambient_props"]

## Aplica el perfil al viewport principal y a las luces registradas en el grupo "sun_light".
func apply() -> void:
	var params: Dictionary = get_params()
	var root: Window = get_tree().root if is_inside_tree() else null
	if root != null:
		root.scaling_3d_scale = clampf(params["scale_3d"] * resolution_override, 0.4, 1.0)
		root.msaa_3d = params["msaa"]
		RenderingServer.directional_shadow_atlas_set_size(params["shadow_size"], false)
		Engine.max_fps = 0
		for light in get_tree().get_nodes_in_group("sun_light"):
			if light is Light3D:
				light.shadow_enabled = params["shadows"]

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "profile", profile)
	cfg.set_value("graphics", "resolution_override", resolution_override)
	var err: int = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("No se pudo guardar %s (error %d)" % [SETTINGS_PATH, err])

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	profile = clampi(int(cfg.get_value("graphics", "profile", profile)), Profile.VERY_LOW, Profile.HIGH)
	resolution_override = clampf(float(cfg.get_value("graphics", "resolution_override", 1.0)), 0.5, 1.0)

func _has_saved_settings() -> bool:
	return FileAccess.file_exists(SETTINGS_PATH)

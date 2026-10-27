extends Node
## Autoload "Tuning": punto unico de acceso a los parametros centralizados del juego.
## Carga los .tres de resources/tuning/ y, si faltan, usa los valores por defecto de cada clase.

const BALL_PATH := "res://resources/tuning/ball_tuning.tres"
const PLAYER_PATH := "res://resources/tuning/player_tuning.tres"
const ASSIST_PATH := "res://resources/tuning/assist_tuning.tres"
const KEEPER_PATH := "res://resources/tuning/keeper_tuning.tres"
const PITCH_PATH := "res://resources/tuning/pitch_config.tres"

var ball: BallTuning
var player: PlayerTuning
var assist: AssistTuning
var keeper: KeeperTuning
var pitch: PitchConfig

const USER_SETTINGS_PATH := "user://settings.cfg"
## Preferencias del usuario (persisten entre sesiones, no forman parte del balance del juego).
var show_diagnostics: bool = false

func _init() -> void:
	reload()

## Recarga todos los parametros desde disco (util al ajustar valores en el laboratorio).
func reload() -> void:
	ball = _load_or_default(BALL_PATH, BallTuning) as BallTuning
	player = _load_or_default(PLAYER_PATH, PlayerTuning) as PlayerTuning
	assist = _load_or_default(ASSIST_PATH, AssistTuning) as AssistTuning
	keeper = _load_or_default(KEEPER_PATH, KeeperTuning) as KeeperTuning
	pitch = _load_or_default(PITCH_PATH, PitchConfig) as PitchConfig
	load_user_settings()

## Aplica las preferencias del usuario (niveles de asistencia, diagnostico) sobre los parametros.
func load_user_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(USER_SETTINGS_PATH) != OK:
		return
	assist.pass_assist = clampf(float(cfg.get_value("assist", "pass", assist.pass_assist)), 0.0, 1.0)
	assist.shot_assist = clampf(float(cfg.get_value("assist", "shot", assist.shot_assist)), 0.0, 1.0)
	assist.press_assist = clampf(float(cfg.get_value("assist", "press", assist.press_assist)), 0.0, 1.0)
	show_diagnostics = bool(cfg.get_value("ui", "diagnostics", false))

func save_user_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("assist", "pass", assist.pass_assist)
	cfg.set_value("assist", "shot", assist.shot_assist)
	cfg.set_value("assist", "press", assist.press_assist)
	cfg.set_value("ui", "diagnostics", show_diagnostics)
	var err: int = cfg.save(USER_SETTINGS_PATH)
	if err != OK:
		push_warning("No se pudieron guardar las preferencias (error %d)" % err)

func _load_or_default(path: String, script: GDScript) -> Resource:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res != null and res.get_script() == script:
			return res
		push_warning("Tuning: %s no es del tipo esperado; se usan valores por defecto." % path)
	return script.new()

extends TestCase
## Modo 4 (Json) como unico modo de la version final: una instalacion nueva arranca en el 4, las preferencias guardadas por
## versiones anteriores con un modo descartado pasan al 4 sin perder el resto de la configuracion, y el menu de pausa no
## ofrece los modos descartados.

const OLD_SETTINGS := "user://test_old_settings.cfg"

func test_new_install_starts_in_mode_4() -> void:
	check(Tuning.DEFAULT_GAMEPLAY_MODE == 4, "modo predeterminado 4 (%d)" % Tuning.DEFAULT_GAMEPLAY_MODE)
	check(Tuning.PLAYABLE_MODES == [4], "solo el 4 es jugable (%s)" % str(Tuning.PLAYABLE_MODES))
	var fresh: Node = (load("res://scripts/gameplay/tuning.gd") as GDScript).new()
	fresh.load_user_settings("user://no_existe_test.cfg")
	note("instalacion nueva (sin preferencias): modo %d" % fresh.gameplay_mode)
	check(fresh.gameplay_mode == 4, "sin preferencias guardadas arranca en el modo 4")
	fresh.free()

func test_saved_discarded_mode_migrates_to_4_and_keeps_the_rest() -> void:
	var prev_mode: int = Tuning.gameplay_mode
	var prev_minutes: int = Tuning.match_minutes
	var prev_sound: bool = Tuning.sound_on
	for old in [1, 2, 3, 4]:
		var cfg := ConfigFile.new()
		cfg.set_value("match", "gameplay_mode", old)
		cfg.set_value("match", "minutes", 7)
		cfg.set_value("ui", "sound_on", false)
		cfg.save(OLD_SETTINGS)
		Tuning.load_user_settings(OLD_SETTINGS)
		note("preferencias con modo %d -> modo %d, minutos %d, sonido %s" % [old, Tuning.gameplay_mode, Tuning.match_minutes, str(Tuning.sound_on)])
		check(Tuning.gameplay_mode == 4, "modo guardado %d -> 4" % old)
		check(Tuning.match_minutes == 7 and not Tuning.sound_on, "el resto de la configuracion se conserva (modo guardado %d)" % old)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_SETTINGS))
	Tuning.gameplay_mode = prev_mode
	Tuning.match_minutes = prev_minutes
	Tuning.sound_on = prev_sound

func test_pause_menu_does_not_offer_discarded_modes() -> void:
	var hud := Hud.new()
	spawn(hud)
	await physics_frames(2)
	hud._refresh_menu_labels()
	var b: Button = hud._pause_buttons.get("gameplay_mode")
	check(b != null and not b.visible, "sin boton de modo de juego con un solo modo jugable")
	# (_cycle_gameplay_mode guarda las preferencias en disco: no se llama aqui; recorre Tuning.PLAYABLE_MODES.)
	check(not Tuning.PLAYABLE_MODES.has(1) and not Tuning.PLAYABLE_MODES.has(2) and not Tuning.PLAYABLE_MODES.has(3), "los modos 1-3 no se ofrecen")

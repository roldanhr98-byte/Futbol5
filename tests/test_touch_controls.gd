extends TestCase
## Controles tactiles: eventos tactiles reales (multitoque) -> acciones de InputMap -> intencion del jugador.

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)

func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)

func _make_hud() -> Hud:
	var hud := Hud.new()
	spawn(hud)
	await physics_frames(3)
	hud.touch.visible = true
	return hud

func test_floating_joystick_drives_move_actions_with_analog_strength() -> void:
	var hud: Hud = await _make_hud()
	_touch(0, Vector2(150, 500), true)
	_drag(0, Vector2(150 + 95, 500))
	await physics_frames(2)
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	note("joystick a la derecha al maximo -> vector de entrada %s" % v)
	check(v.x > 0.9 and absf(v.y) < 0.05, "empujar a la derecha produce movimiento a la derecha")
	_drag(0, Vector2(150 + 45, 500 - 45))
	await physics_frames(2)
	var diag: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	note("joystick diagonal parcial -> %s (longitud %.2f)" % [diag, diag.length()])
	check(diag.x > 0.1 and diag.y < -0.1, "diagonal arriba-derecha")
	check(diag.length() < 0.95, "la intensidad es analogica (no todo o nada)")
	_touch(0, Vector2(150 + 45, 500 - 45), false)
	await physics_frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").length() < 0.01, "soltar el joystick detiene el movimiento")
	hud.touch.release_all()

func test_buttons_fire_real_actions_and_support_multitouch() -> void:
	var hud: Hud = await _make_hud()
	var shoot_pos: Vector2 = hud.touch.get_button_center(&"shoot")
	var sprint_pos: Vector2 = hud.touch.get_button_center(&"sprint")
	_touch(3, Vector2(150, 520), true)           # joystick
	_drag(3, Vector2(150, 520 + 80))             # abajo
	_touch(4, shoot_pos, true)                   # TIRO a la vez
	_touch(5, sprint_pos, true)                  # SPRINT a la vez
	await physics_frames(2)
	check(Input.is_action_pressed("shoot"), "TIRO activa la accion shoot")
	check(Input.is_action_pressed("sprint"), "SPRINT activa la accion sprint")
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").y > 0.5, "el joystick sigue activo en multitoque")
	_touch(4, shoot_pos, false)
	await physics_frames(2)
	check(not Input.is_action_pressed("shoot"), "soltar TIRO libera la accion")
	check(Input.is_action_pressed("sprint"), "SPRINT sigue mantenido")
	_touch(5, sprint_pos, false)
	_touch(3, Vector2(150, 600), false)
	await physics_frames(2)
	check(not Input.is_action_pressed("sprint"), "soltar SPRINT libera la accion")
	for id in [&"pass", &"press", &"lob"]:
		var pos: Vector2 = hud.touch.get_button_center(id)
		_touch(7, pos, true)
		await physics_frames(1)
		check(Input.is_action_pressed(String(id)), "el boton %s activa su accion" % id)
		_touch(7, pos, false)
		await physics_frames(1)
		check(not Input.is_action_pressed(String(id)), "soltar %s libera la accion" % id)
	hud.touch.release_all()

func test_pause_button_emits_signal_and_switch_button_only_when_needed() -> void:
	var hud: Hud = await _make_hud()
	var fired: Array = []
	hud.touch.pause_pressed.connect(func() -> void: fired.append(1))
	var p: Vector2 = hud.touch.get_button_center(&"pause")
	_touch(1, p, true)
	_touch(1, p, false)
	await physics_frames(1)
	check(fired.size() == 1, "el boton de pausa emite la senal")
	var sw: Vector2 = hud.touch.get_button_center(&"switch")
	hud.touch.show_switch = false
	_touch(2, sw, true)
	await physics_frames(1)
	check(not Input.is_action_pressed("switch_player"), "CAMBIO oculto no responde con un solo jugador")
	_touch(2, sw, false)
	hud.touch.show_switch = true
	_touch(2, sw, true)
	await physics_frames(1)
	check(Input.is_action_pressed("switch_player"), "CAMBIO responde cuando hay varios jugadores")
	_touch(2, sw, false)
	hud.touch.release_all()

func test_touch_joystick_moves_a_real_footballer_end_to_end() -> void:
	var ctx: MatchContext = await make_match(Vector3(30.0, 0.11, 5.0))
	var f: Footballer = add_player(ctx, 0, Vector3(-10, 0, 0), 50, HumanInput.new())
	var hud: Hud = await _make_hud()
	_touch(0, Vector2(150, 500), true)
	_drag(0, Vector2(150 + 95, 500))
	await wait_seconds(1.5)
	check(f.global_position.x > -10.0 + 2.0, "el jugador avanza hacia +X al empujar el joystick (x=%.2f)" % f.global_position.x)
	_touch(0, Vector2(245, 500), false)
	hud.touch.release_all()

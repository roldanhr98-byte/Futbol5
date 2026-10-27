class_name ScriptedInput
extends InputSource
## Entrada programable para pruebas y demostraciones. Los flancos (pressed/released) duran un solo poll.

var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var press_held: bool = false
var lob_held: bool = false
var _pass_held: bool = false
var _shoot_held: bool = false
var _pass_pressed: bool = false
var _pass_released: bool = false
var _shoot_pressed: bool = false
var _shoot_released: bool = false
var _switch: bool = false
var _skill: bool = false
var _tick: int = 0

func hold_pass() -> void:
	_pass_pressed = true
	_pass_held = true

func release_pass() -> void:
	_pass_held = false
	_pass_released = true

func hold_shoot() -> void:
	_shoot_pressed = true
	_shoot_held = true

func release_shoot() -> void:
	_shoot_held = false
	_shoot_released = true

func skill() -> void:
	_skill = true

func request_switch() -> void:
	_switch = true

func poll(_footballer: Footballer) -> InputFrame:
	var f := InputFrame.new()
	_tick += 1
	f.tick = _tick
	f.move = move
	f.sprint = sprint
	f.press_held = press_held
	f.lob_held = lob_held
	f.pass_pressed = _pass_pressed
	f.pass_held = _pass_held
	f.pass_released = _pass_released
	f.shoot_pressed = _shoot_pressed
	f.shoot_held = _shoot_held
	f.shoot_released = _shoot_released
	f.switch_pressed = _switch
	f.skill_pressed = _skill
	_pass_pressed = false
	_pass_released = false
	_shoot_pressed = false
	_shoot_released = false
	_switch = false
	_skill = false
	return f

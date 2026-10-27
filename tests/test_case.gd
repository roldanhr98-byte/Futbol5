class_name TestCase
extends RefCounted
## Base minima para las pruebas headless. Cada metodo "test_*" de una subclase es una prueba.
## Se ejecutan con tests/run_tests.gd. Sin dependencias externas.

var tree: SceneTree
var failures: Array[String] = []
var checks: int = 0
var _spawned: Array[Node] = []
## Una prueba omitida (p. ej. falta un recurso restringido que no se versiona) no cuenta como fallo ni como comprobacion.
var skipped: bool = false
var skip_reason: String = ""

func skip(reason: String) -> void:
	skipped = true
	skip_reason = reason

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		failures.append("%s (esperado %.4f +- %.4f, obtenido %.4f)" % [message, expected, tolerance, actual])

func check_range(actual: float, low: float, high: float, message: String) -> void:
	checks += 1
	if actual < low or actual > high:
		failures.append("%s (esperado en [%.4f, %.4f], obtenido %.4f)" % [message, low, high, actual])

## Imprime una medida real (aparece en el log de la ejecucion como evidencia).
func note(message: String) -> void:
	print("       · %s" % message)

func fail(message: String) -> void:
	checks += 1
	failures.append(message)

## Espera n pasos de fisica.
func physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame

## Espera n segundos simulados (60 Hz).
func wait_seconds(seconds: float) -> void:
	await physics_frames(int(round(seconds * Engine.physics_ticks_per_second)))

func spawn(node: Node) -> Node:
	tree.root.add_child(node)
	_spawned.append(node)
	return node

func cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	# Interruptores globales que algunas pruebas cambian: cada prueba empieza con los valores por defecto.
	FootballerVisual.prefer_pack = true
	BallHandler.clip_kicks_enabled = true
	Input.flush_buffered_events()
	for action in InputMap.get_actions():
		Input.action_release(action)

## Crea cancha + pelota listas para simular.
func make_world(ball_pos: Vector3 = Vector3(0, 0.5, 0)) -> Dictionary:
	var pitch := Pitch.new()
	pitch.name = "TestPitch"
	spawn(pitch)
	var ball_scene: PackedScene = load("res://scenes/ball/ball.tscn")
	var ball: Ball = ball_scene.instantiate()
	spawn(ball)
	ball.global_position = ball_pos
	pitch.set_ball(ball)
	await physics_frames(2)
	return {"pitch": pitch, "ball": ball}

var _next_id: int = 1

## Cancha + pelota + contexto de partido.
func make_match(ball_pos: Vector3 = Vector3(0, 0.12, 0)) -> MatchContext:
	var w: Dictionary = await make_world(ball_pos)
	var ctx := MatchContext.new()
	ctx.ball = w["ball"]
	ctx.pitch = w["pitch"]
	return ctx

## Agrega un futbolista con entrada programable. Por defecto atributos neutros (50).
func add_player(ctx: MatchContext, team: int, pos: Vector3, base_attr: int = 50, source: InputSource = null, with_visual: bool = false) -> Footballer:
	var scene: PackedScene = load("res://scenes/player/footballer.tscn")
	var f: Footballer = scene.instantiate()
	f.build_visual = with_visual
	spawn(f)
	f.global_position = pos
	var attrs := PlayerAttributes.new()
	attrs.reset_to(base_attr)
	var src: InputSource = source if source != null else ScriptedInput.new()
	f.setup(ctx, team, _next_id, attrs, src)
	_next_id += 1
	f.ball_handler.rng.seed = 12345 + _next_id
	return f

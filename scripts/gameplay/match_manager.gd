class_name MatchManager
extends Node
## Reglas y flujo del partido: saque, juego, gol (la pelota cruza COMPLETAMENTE la linea), celebracion,
## reinicio de jugada / partido, pausa y fin de tiempo. No crea ni mueve entidades por si mismo:
## pide a la escena que las reposicione mediante la senal kickoff_requested.
## Pensado para que un servidor autoritativo pueda ejecutar este mismo codigo.

signal state_changed(new_state: int)
signal score_changed(home: int, away: int)
signal goal_scored(team: int, scorer_id: int, assist_id: int, own_goal: bool)
signal kickoff_requested(kicking_team: int)
signal message(text: String, seconds: float)
signal clock_changed(seconds: float)

enum State { PRE_KICKOFF, PLAYING, GOAL, PAUSED, FULL_TIME }

## Duracion en segundos (0 = sin limite, util en el laboratorio).
@export var duration_seconds: float = 300.0
@export var goal_celebration_seconds: float = 3.0
@export var pre_kickoff_seconds: float = 1.2
## Presentacion antes del primer saque (calentamiento y arbitro). 0 = sin presentacion.
@export var intro_seconds: float = 0.0
## Ventana para considerar asistencia el pase previo al gol.
@export var assist_window_seconds: float = 6.0

var ctx: MatchContext
var state: State = State.PRE_KICKOFF
var score: Array[int] = [0, 0]
var kickoff_team: int = 0

var _state_timer: float = 0.0
var _state_before_pause: State = State.PLAYING
var _last_touch_time_by_actor: Dictionary = {}

func setup(context: MatchContext) -> void:
	ctx = context
	ctx.pitch.goal_scored.connect(_on_goal)
	ctx.ball.touched.connect(_on_ball_touched)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func start_match() -> void:
	score = [0, 0]
	ctx.match_time = 0.0
	ctx.tick = 0
	kickoff_team = 0
	score_changed.emit(0, 0)
	clock_changed.emit(0.0)
	ctx.emit_event(GameEvent.make(GameEvent.Type.MATCH_START, -1, -1))
	_begin_kickoff(0, true)

## Reinicia la jugada actual (sin tocar el marcador): saque de centro del mismo equipo.
func restart_play() -> void:
	if state == State.PAUSED:
		_set_state(_state_before_pause)
	_begin_kickoff(kickoff_team)
	ctx.emit_event(GameEvent.make(GameEvent.Type.RESTART, -1, -1))

func restart_match() -> void:
	get_tree().paused = false
	start_match()

func toggle_pause() -> void:
	if state == State.PAUSED:
		get_tree().paused = false
		_set_state(_state_before_pause)
	elif state != State.FULL_TIME:
		_state_before_pause = state
		get_tree().paused = true
		_set_state(State.PAUSED)

func is_playing() -> bool:
	return state == State.PLAYING

func _begin_kickoff(team: int, intro: bool = false) -> void:
	kickoff_team = team
	ctx.input_enabled = false
	ctx.pitch.reset_goal_latches()
	var with_intro: bool = intro and intro_seconds > 0.0
	_state_timer = intro_seconds if with_intro else pre_kickoff_seconds
	_set_state(State.PRE_KICKOFF)
	kickoff_requested.emit(team)
	message.emit("¡Saque!", _state_timer)
	ctx.emit_event(GameEvent.make(GameEvent.Type.KICKOFF, -1, team, {"intro": with_intro, "seconds": _state_timer}))

func _physics_process(delta: float) -> void:
	if state == State.PAUSED:
		return
	ctx.tick += 1
	ctx.update_ball_stall(delta)
	match state:
		State.PRE_KICKOFF:
			_state_timer -= delta
			if _state_timer <= 0.0:
				ctx.input_enabled = true
				_set_state(State.PLAYING)
		State.PLAYING:
			ctx.match_time += delta
			clock_changed.emit(ctx.match_time)
			if duration_seconds > 0.0 and ctx.match_time >= duration_seconds:
				ctx.input_enabled = false
				_set_state(State.FULL_TIME)
				message.emit("Fin del partido  %d - %d" % [score[0], score[1]], 6.0)
				ctx.emit_event(GameEvent.make(GameEvent.Type.MATCH_END, -1, -1, {"score": score.duplicate()}))
		State.GOAL:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_begin_kickoff(1 - _last_scoring_team)
		State.FULL_TIME:
			pass

var _last_scoring_team: int = 0

func _on_ball_touched(actor: Node) -> void:
	var id_value: Variant = actor.get("actor_id")
	if id_value != null:
		_last_touch_time_by_actor[int(id_value)] = ctx.match_time

func _on_goal(goal: Goal, _ball_pos: Vector3) -> void:
	if state != State.PLAYING:
		return
	# El arco +X recibe el gol de quien ataca +X: el equipo 0.
	var scoring_team: int = 0 if goal.side > 0 else 1
	var ball: Ball = ctx.ball
	var scorer_id: int = -1
	var assist_id: int = -1
	var own_goal: bool = false
	if ball.last_toucher != null:
		var sid: Variant = ball.last_toucher.get("actor_id")
		scorer_id = int(sid) if sid != null else -1
		if ball.last_touch_team != scoring_team and ball.last_touch_team != -1:
			own_goal = true
		elif ball.previous_toucher != null and ball.previous_touch_team == scoring_team and ball.previous_toucher != ball.last_toucher:
			var aid: Variant = ball.previous_toucher.get("actor_id")
			if aid != null and ctx.match_time - float(_last_touch_time_by_actor.get(int(aid), -999.0)) <= assist_window_seconds:
				assist_id = int(aid)
	score[scoring_team] += 1
	_last_scoring_team = scoring_team
	ctx.input_enabled = false
	_state_timer = goal_celebration_seconds
	_set_state(State.GOAL)
	score_changed.emit(score[0], score[1])
	goal_scored.emit(scoring_team, scorer_id, assist_id, own_goal)
	message.emit("¡GOL!" + (" (en contra)" if own_goal else ""), goal_celebration_seconds)
	ctx.emit_event(GameEvent.make(GameEvent.Type.GOAL, scorer_id, scoring_team,
		{"assist": assist_id, "own_goal": own_goal, "score": score.duplicate()}))

func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)

static func format_clock(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]

class_name Referee
extends Node3D
## Arbitro: figura de presentacion junto a la linea de banda (no participa en el juego). Usa los clips de arbitro del
## pack: cuenta durante la presentacion, senala el centro tras un gol y al reanudar, y saluda al final.

var visual: FootballerVisual = null
var ctx: MatchContext = null
var _pending: StringName = &""
var _delay: float = 0.0
var _cut: float = 2.5

func setup(context: MatchContext, at: Vector3) -> void:
	ctx = context
	visual = FootballerVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.build(FootballerVisual.referee_kit())
	position = at
	rotation.y = 0.0   # yaw 0 mira a -Z: hacia el centro de la cancha desde la banda +Z
	ctx.event_emitted.connect(_on_event)

func _exit_tree() -> void:
	if ctx != null and ctx.event_emitted.is_connected(_on_event):
		ctx.event_emitted.disconnect(_on_event)

func _on_event(e: GameEvent) -> void:
	if visual == null or visual.is_placeholder:
		return
	match e.type:
		GameEvent.Type.KICKOFF:
			if bool(e.data.get("intro", false)):
				_queue(&"referee_count", 0.3, maxf(float(e.data.get("seconds", 3.0)) - 0.5, 1.0))
			else:
				_queue(&"referee_point", 0.1, 1.6)
		GameEvent.Type.GOAL:
			_queue(&"referee_point", 0.6, 2.2)
		GameEvent.Type.MATCH_END:
			_queue(&"referee_wave", 0.5, 4.0)

func _queue(situation: StringName, delay: float, cut: float) -> void:
	_pending = situation
	_delay = delay
	_cut = cut
	visual.stop_current_action()

func _physics_process(delta: float) -> void:
	if visual == null:
		return
	if _pending != &"":
		_delay -= delta
		if _delay <= 0.0:
			visual.play_situation(_pending, int(ctx.match_time) if ctx != null else 0, 1.0, _cut)
			_pending = &""
	visual.drive_motion(0.0, 0.0, delta)

class_name Footballer
extends CharacterBody3D
## Futbolista de campo. Orquesta: entrada (InputFrame) -> intencion -> locomocion -> contacto con la
## pelota. No importa si lo controla una persona, la IA o la red: todos pasan por InputFrame.
##
## Estado replicable separado de la presentacion: la presentacion es FootballerVisual (hijo "Visual").

signal kicked(action: StringName, result: KickModel.KickResult)
signal tackled(won: bool)

@export var team: int = 0
@export var display_name: String = "Jugador"
@export var shirt_number: int = 10
@export var dominant_right: bool = true
## Las pruebas de logica desactivan el modelo 3D para ir mas rapido.
@export var build_visual: bool = true

var actor_id: int = 0
var attributes: PlayerAttributes = PlayerAttributes.new()
var ctx: MatchContext = null
var input_source: InputSource = null
var locomotion: Locomotion
var ball_handler: BallHandler
var press: PressController
var visual: FootballerVisual = null
var last_frame: InputFrame = InputFrame.new()
var is_pressing: bool = false
var press_info: PressController.PressOutput = null
## Acciones de cuerpo completo con clips (barrida, caidas, levantarse).
var actions: PlayerActions = null
## Sobrescritura de asistencia por jugador (-1 = usar la configuracion global).
var assist_override_pass: float = -1.0
var assist_override_shot: float = -1.0
## Marcado por el gestor de partido: este futbolista es el que maneja la persona.
var is_human_controlled: bool = false
## Velocidad extra (m/s) de un ajuste de zancada para llegar a la pelota al patear. Mueve el cuerpo pero NO entra en
## Locomotion (no cambia la velocidad ni la inercia del jugador).
var nudge_velocity: Vector3 = Vector3.ZERO

## Reaccion pendiente a un evento de partido (situacion del AnimationCatalog) y segundos que faltan para empezarla.
## Solo presentacion: no bloquea la entrada ni cambia el movimiento.
## Distancia (m) al portador rival a la que el defensor pasa a marcar de frente (jockey).
const JOCKEY_RANGE := 4.5
const REACTION_MAX_SECONDS := 2.4
const REACTION_MAX_WAIT := 1.0
const REACTION_START_SPEED := 1.5
const RECEIVE_MAX_SPEED := 2.0
const RECEIVE_MAX_SECONDS := 0.9
var _reaction: StringName = &""
var _reaction_cut: float = REACTION_MAX_SECONDS
var _reaction_wait: float = 0.0

func _ready() -> void:
	add_to_group("footballers")
	collision_layer = Ball.LAYER_PLAYERS
	collision_mask = Ball.LAYER_WORLD | Ball.LAYER_PLAYERS | Ball.LAYER_KEEPERS
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.4
	floor_stop_on_slope = true
	var t: PlayerTuning = Tuning.player
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = t.capsule_radius
		cap.height = t.capsule_height
		cs.shape = cap
		cs.position = Vector3(0.0, t.capsule_height * 0.5, 0.0)
		add_child(cs)
	locomotion = Locomotion.new(t, attributes)
	ball_handler = BallHandler.new(self)
	ball_handler.kicked.connect(func(a: StringName, r: KickModel.KickResult) -> void: kicked.emit(a, r))
	press = PressController.new()
	actions = PlayerActions.new(self)
	if build_visual:
		visual = get_node_or_null("Visual") as FootballerVisual
		if visual == null:
			visual = FootballerVisual.new()
			visual.name = "Visual"
			add_child(visual)
			visual.build(FootballerVisual.default_kit(team))

## Configura el jugador dentro de un partido.
func setup(context: MatchContext, team_index: int, id: int, attrs: PlayerAttributes, source: InputSource) -> void:
	ctx = context
	team = team_index
	actor_id = id
	set_attributes(attrs)
	input_source = source
	ctx.register_footballer(self)
	if not ctx.event_emitted.is_connected(_on_match_event):
		ctx.event_emitted.connect(_on_match_event)
	# El equipo 0 ataca +X; el equipo 1 ataca -X. Mirar hacia el arco rival al inicio.
	if locomotion != null:
		locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1.0 if team == 0 else -1.0, 0.0, 0.0))
		rotation.y = locomotion.yaw
	# El visual se construye en _ready con el equipo por defecto: al conocer el equipo real se aplican sus colores.
	if visual != null and not visual.is_placeholder and team != 0:
		visual.set_kit(FootballerVisual.default_kit(team))

func set_attributes(attrs: PlayerAttributes) -> void:
	attributes = attrs
	if locomotion != null:
		locomotion.attributes = attrs

func _exit_tree() -> void:
	if ctx != null:
		ctx.unregister_footballer(self)
		if ctx.event_emitted.is_connected(_on_match_event):
			ctx.event_emitted.disconnect(_on_match_event)

## Durante un golpeo en el aire (cabezazo, volea) la pelota atraviesa el cuerpo hasta el contacto del clip: si no, rebota
## contra la capsula antes de que la cabeza o el pie lleguen. Un golpeo fallido deja pasar la pelota.
func set_ball_ghost(on: bool) -> void:
	collision_layer = 0 if on else Ball.LAYER_PLAYERS

func has_ball() -> bool:
	return ball_handler != null and ball_handler.has_possession()

func reset_motion() -> void:
	_cancel_reaction()
	if actions != null:
		actions.reset()
	velocity = Vector3.ZERO
	if locomotion != null:
		locomotion.stop()

func place_at(pos: Vector3, yaw: float) -> void:
	_cancel_reaction()
	if actions != null:
		actions.reset()
		if visual != null:
			visual.stop_current_action()
	global_position = pos
	if locomotion != null:
		locomotion.yaw = yaw
		locomotion.stop()
	rotation.y = yaw
	velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if ctx == null or locomotion == null:
		return
	var frame: InputFrame = input_source.poll(self) if (input_source != null and ctx.input_enabled) else InputFrame.new()
	last_frame = frame
	# Una accion de cuerpo completo (barrida, caida, levantarse) mueve al jugador con la raiz del clip.
	if actions.tick(delta):
		if visual != null:
			visual.update_motion(self, delta)
		return
	if frame.skill_pressed:
		actions.try_skill()
		if actions.tick(0.0):
			if visual != null:
				visual.update_motion(self, delta)
			return
	var stick_mag: float = clampf(frame.move_length(), 0.0, 1.0)
	var stick_world: Vector3 = frame.move_world if frame.use_world else ctx.screen_to_world(frame.move)
	if stick_world.length() > 1.0:
		stick_world = stick_world.normalized()
	var desired_dir: Vector3 = stick_world.normalized() if stick_mag > 0.05 else Vector3.ZERO
	var desired_mag: float = stick_mag
	var want_sprint: bool = frame.sprint

	# Presion defensiva: el boton fija la INTENCION de disputar; el joystick solo ajusta el angulo.
	is_pressing = false
	press_info = null
	if frame.press_held and ctx.ball != null and not ball_handler.controls_ball():
		press_info = press.update(self, ctx, stick_world, stick_mag, delta)
		if press_info.active:
			is_pressing = true
			desired_dir = press_info.dir
			desired_mag = press_info.magnitude
			want_sprint = want_sprint or press_info.sprint
			# Barrida de recuperacion: se decide al acercarse (1.3-2.7 m), antes del alcance del robo normal.
			if press_info.carrier != null and actions.try_slide_tackle(press_info.carrier):
				pass
			elif press_info.attempt_tackle:
				var won: bool = ball_handler.attempt_tackle(press_info.carrier)
				tackled.emit(won)
	else:
		press.reset()

	# Marcaje en jockey: cerca del portador rival mira hacia el y se mueve en cualquier direccion.
	# Con la pelota, el mismo mecanismo sirve para el control lateral y para proteger el balon de espaldas al rival.
	locomotion.face_override = Vector3.ZERO
	if is_pressing and press_info.carrier != null:
		var to_c: Vector3 = KickModel.flat(press_info.carrier.global_position - global_position)
		if to_c.length() < JOCKEY_RANGE and to_c.length() > 0.5:
			locomotion.face_override = to_c.normalized()
	else:
		var carry_face: Vector3 = ball_handler.plan_carry(desired_dir, desired_mag, delta)
		if carry_face.length_squared() > 0.01:
			locomotion.face_override = carry_face

	# Conduciendo la pelota se corre algo mas lento (y menos con peor conduccion).
	var cap: float = -1.0
	if ball_handler.has_possession():
		cap = locomotion.max_sprint_speed() * lerpf(0.86, 0.97, attributes.norm("ball_carrying"))
	locomotion.step(desired_dir, desired_mag, want_sprint, delta, cap)

	velocity.x = locomotion.velocity.x + nudge_velocity.x
	velocity.z = locomotion.velocity.z + nudge_velocity.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.81 * delta
	move_and_slide()
	_check_player_collisions()
	# Las colisiones (paredes, otros jugadores) corrigen la velocidad real.
	locomotion.velocity = Vector3(velocity.x - nudge_velocity.x, 0.0, velocity.z - nudge_velocity.z)
	rotation.y = locomotion.yaw

	ball_handler.update(frame, stick_world, stick_mag, desired_dir, delta)
	if visual != null:
		_update_reaction(delta)
		visual.directional = locomotion.jockeying
		visual.carrying = ball_handler.has_possession()
		visual.dir_velocity = Vector2(locomotion.forward_speed, locomotion.lateral_speed)
		visual.update_motion(self, delta)

# --- Reacciones de presentacion a eventos del partido --------------------------------------------

func _cancel_reaction() -> void:
	_reaction = &""
	if visual != null and visual.is_action_playing():
		visual.stop_current_action()

## Reacciones de presentacion a eventos del partido:
##  - Gol: el goleador, el asistente, el resto del equipo y el rival reaccionan distinto (un autor de gol en contra
##    es del equipo que recibe: se lamenta). Cada uno elige un clip distinto del catalogo segun su id.
##  - Primer toque lento: gesto de recepcion. Saque: corta reacciones; el primero de la presentacion, calentamiento.
##  - Fin del partido: ganadores, perdedores o empate.
func _on_match_event(e: GameEvent) -> void:
	if visual == null or visual.is_placeholder:
		return
	match e.type:
		GameEvent.Type.GOAL:
			var own: bool = bool(e.data.get("own_goal", false))
			if e.team != team:
				_set_reaction(&"dejected", 0.4, REACTION_MAX_SECONDS)
			elif e.actor_id == actor_id and not own:
				_set_reaction(&"celebrate_scorer", 0.3, REACTION_MAX_SECONDS)
			elif int(e.data.get("assist", -1)) == actor_id:
				_set_reaction(&"thumbs_up", 0.5, REACTION_MAX_SECONDS)
			else:
				_set_reaction(&"celebrate_team", 0.4, REACTION_MAX_SECONDS)
		GameEvent.Type.MATCH_END:
			var sc: Array = e.data.get("score", [0, 0])
			var mine: int = int(sc[team]) if sc.size() == 2 else 0
			var theirs: int = int(sc[1 - team]) if sc.size() == 2 else 0
			_set_reaction(&"victory_end" if mine > theirs else (&"defeat_end" if mine < theirs else &"draw_end"), 0.4, 6.0)
		GameEvent.Type.KICKOFF:
			_cancel_reaction()
			if bool(e.data.get("intro", false)):
				_set_reaction(&"warmup", rng_delay(), maxf(float(e.data.get("seconds", 3.0)) - 0.6, 1.0))
		GameEvent.Type.RESTART, GameEvent.Type.MATCH_START:
			_cancel_reaction()
		GameEvent.Type.FIRST_TOUCH:
			if e.actor_id == actor_id and locomotion.speed <= RECEIVE_MAX_SPEED and not ball_handler.is_kick_in_progress() and not visual.is_action_playing() and not actions.active():
				visual.play_situation(&"receive", 0, 1.0, RECEIVE_MAX_SECONDS)

func rng_delay() -> float:
	return float(actor_id % 5) * 0.12

func _set_reaction(situation: StringName, wait: float, cut: float) -> void:
	_reaction = situation
	_reaction_wait = wait
	_reaction_cut = cut

## La reaccion a un gol arranca cuando el jugador casi se ha detenido (o tras REACTION_MAX_WAIT) para no animar un
## clip en el sitio sobre un cuerpo que aun corre.
func _update_reaction(delta: float) -> void:
	if _reaction == &"":
		return
	_reaction_wait -= delta
	if _reaction_wait > 0.0 or (locomotion.speed > REACTION_START_SPEED and _reaction_wait > -REACTION_MAX_WAIT) or actions.active():
		return
	var sit: StringName = _reaction
	_reaction = &""
	if not ball_handler.is_kick_in_progress():
		visual.play_situation(sit, actor_id + int(ctx.match_time), 1.0, _reaction_cut)

var _collision_cd: float = 0.0

## Un choque a velocidad con otro jugador provoca un tropiezo (presentacion) o, si es fuerte, un golpe de hombro y caida.
func _check_player_collisions() -> void:
	_collision_cd = maxf(_collision_cd - get_physics_process_delta_time(), 0.0)
	if _collision_cd > 0.0 or actions.active():
		return
	for i in get_slide_collision_count():
		var other: Footballer = get_slide_collision(i).get_collider() as Footballer
		if other == null:
			continue
		var rel: float = (velocity - other.velocity).length()
		if rel < 3.2:
			continue
		_collision_cd = 3.0
		# Solo reacciona el mas lento (el que recibe el golpe).
		if locomotion.speed > other.locomotion.speed + 0.3:
			return
		if rel > 5.5 and actions.rng.randf() < 0.3:
			actions.suffer_contact(&"hit", KickModel.flat(global_position - other.global_position))
		else:
			actions.stumble()
		return

## Datos replicables del jugador (para snapshots de red / pruebas).
func capture_state() -> Dictionary:
	return {
		"id": actor_id, "team": team,
		"pos": [global_position.x, global_position.y, global_position.z],
		"vel": [velocity.x, velocity.y, velocity.z],
		"yaw": locomotion.yaw if locomotion != null else 0.0,
		"stamina": locomotion.stamina if locomotion != null else 1.0,
	}

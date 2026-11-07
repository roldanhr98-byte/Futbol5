extends TestCase
## Cada transicion tiene una condicion geometrica realizable y pasa por el arbitro normal del jugador.

func test_all_previously_unrouted_transitions_can_start_in_their_own_state() -> void:
	var ctx: MatchContext = await make_match(Vector3(12, 0.11, 6))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new(), true)
	p.set_physics_process(false)
	var count: int = 0
	for role in PlayerActions.LOCOMOTION_TRANSITIONS:
		for id in AnimDB.candidates(role, {"mirrors": false}):
			var m: Dictionary = PackLibrary.meta(id)
			p.actions.reset()
			p.global_position = Vector3.ZERO
			p.locomotion.yaw = 0.0
			var root: Vector2 = m.get("root_total", Vector2.ZERO)
			var direction: Vector3 = (p.locomotion.forward() * root.x + p.locomotion.right() * root.y).normalized()
			if direction.length() < 0.1:
				direction = p.locomotion.forward()
			var turn: float = ActionMotion.heading_rel(m["heading_path"], m["duration"])
			p.locomotion.face_override = Locomotion.dir_from_yaw(turn)
			p.locomotion.speed = float(m["v_in"])
			p.locomotion.velocity = direction * p.locomotion.speed
			var magnitude: float = 0.0 if role == &"step_stand" else (0.3 if role == &"turn_stop" else 1.0)
			check(p.actions.request_locomotion_transition(id, direction, magnitude), "%s entra en su estado de movimiento" % id)
			check(p.visual.current_action == id and p.arbiter.level == ActionArbiter.Level.BODY, "%s se invoca por el arbitro real" % id)
			p.actions.tick(1.0 / 60.0)
			check(p.global_position.is_finite(), "%s aplica su raiz sin valores invalidos" % id)
			count += 1
	check(count == 14, "14 transiciones del selector (13 pendientes historicas y una existente)")

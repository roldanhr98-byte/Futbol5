class_name Goal
extends Node3D
## Arco: postes y travesano con colision fisica (rebotes reales), red visible de una sola malla,
## colisiones simples para la red y deteccion de gol cuando la pelota cruza COMPLETAMENTE la linea.
##
## Marco local: +X apunta hacia afuera del campo (detras del arco), +Y arriba, Z lateral.

signal goal_scored(goal: Goal, ball_position: Vector3)

const NET_SHADER := preload("res://assets/pitch/net.gdshader")

var config: PitchConfig
## +1: arco en x = +length/2; -1: arco en x = -length/2.
var side: int = 1
var ball: Ball = null
var _latched: bool = false
var _frame_material: StandardMaterial3D

func setup(cfg: PitchConfig, goal_side: int) -> void:
	config = cfg
	side = goal_side
	name = "Goal_%s" % ("Pos" if side > 0 else "Neg")
	position = Vector3(side * cfg.half_length(), 0.0, 0.0)
	rotation.y = 0.0 if side > 0 else PI
	_frame_material = MeshUtil.flat_material(Color(0.97, 0.97, 0.97), 0.4)
	_build_frame()
	_build_net()

func set_ball(b: Ball) -> void:
	ball = b

func reset_latch() -> void:
	_latched = false

# --- Construccion ----------------------------------------------------------

func _build_frame() -> void:
	var r: float = config.post_radius
	var gh: float = config.goal_height
	var hz: float = config.half_goal() + r
	for z in [-hz, hz]:
		_add_frame_piece(Vector3(0, (gh + 2.0 * r) * 0.5, z), CylinderShape3D.new(), r, gh + 2.0 * r, false)
	# Travesano: cilindro horizontal a lo largo de Z.
	_add_frame_piece(Vector3(0, gh + r, 0), CylinderShape3D.new(), r, config.goal_width + 4.0 * r, true)

func _add_frame_piece(pos: Vector3, shape: CylinderShape3D, r: float, h: float, horizontal: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Ball.LAYER_GOAL_FRAME
	body.collision_mask = 0
	body.add_to_group("goal_frame")
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.45
	pm.friction = 0.3
	body.physics_material_override = pm
	shape.radius = r
	shape.height = h
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _frame_material
	body.add_child(mi)
	body.position = pos
	if horizontal:
		body.rotation.x = PI * 0.5
	add_child(body)

func _build_net() -> void:
	var d: float = config.goal_depth
	var h: float = config.goal_height
	var hw: float = config.half_goal()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# Fondo, techo y laterales (caja abierta por delante).
	MeshUtil.add_quad(verts, normals, uvs, idx,
		Vector3(d, 0, -hw), Vector3(d, 0, hw), Vector3(d, h, hw), Vector3(d, h, -hw))
	MeshUtil.add_quad(verts, normals, uvs, idx,
		Vector3(0, h, -hw), Vector3(d, h, -hw), Vector3(d, h, hw), Vector3(0, h, hw))
	MeshUtil.add_quad(verts, normals, uvs, idx,
		Vector3(0, 0, -hw), Vector3(d, 0, -hw), Vector3(d, h, -hw), Vector3(0, h, -hw))
	MeshUtil.add_quad(verts, normals, uvs, idx,
		Vector3(0, 0, hw), Vector3(d, 0, hw), Vector3(d, h, hw), Vector3(0, h, hw))
	var mi := MeshInstance3D.new()
	mi.name = "Net"
	mi.mesh = MeshUtil.build_mesh(verts, normals, uvs, idx)
	var mat := ShaderMaterial.new()
	mat.shader = NET_SHADER
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	# Colisiones simples para contener la pelota dentro de la red.
	var t: float = 0.06
	# Grupo "net_surface": la pelota pierde casi toda su energia al tocarlas (ver Ball._on_body_entered).
	MeshUtil.add_box_body(self, Vector3(t, h, config.goal_width), Vector3(d + t * 0.5, h * 0.5, 0), Ball.LAYER_WORLD, &"net_surface")
	MeshUtil.add_box_body(self, Vector3(d, h, t), Vector3(d * 0.5, h * 0.5, -hw - t * 0.5), Ball.LAYER_WORLD, &"net_surface")
	MeshUtil.add_box_body(self, Vector3(d, h, t), Vector3(d * 0.5, h * 0.5, hw + t * 0.5), Ball.LAYER_WORLD, &"net_surface")
	MeshUtil.add_box_body(self, Vector3(d, t, config.goal_width + 2.0 * t), Vector3(d * 0.5, h + t * 0.5, 0), Ball.LAYER_WORLD, &"net_surface")

	# Volumen de red: amortigua la pelota que entra (la red absorbe energia).
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Ball.LAYER_BALL
	area.monitorable = false
	var acs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(d, h, config.goal_width)
	acs.shape = box
	area.add_child(acs)
	area.position = Vector3(d * 0.5, h * 0.5, 0)
	area.body_entered.connect(_on_net_entered)
	area.body_exited.connect(_on_net_exited)
	add_child(area)

func _on_net_entered(body: Node3D) -> void:
	if body is Ball:
		(body as Ball).enter_net()

func _on_net_exited(body: Node3D) -> void:
	if body is Ball:
		(body as Ball).exit_net()

# --- Deteccion de gol ------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	var lp: Vector3 = to_local(ball.global_position)
	if _latched:
		if lp.x < -0.5:
			_latched = false
		return
	if is_ball_in_goal(lp):
		_latched = true
		goal_scored.emit(self, ball.global_position)

## La pelota cuenta como gol cuando su centro esta al menos un radio detras de la linea
## (cruzo completamente) y dentro del marco (entre postes y bajo el travesano).
func is_ball_in_goal(local_ball_pos: Vector3) -> bool:
	var r: float = ball.radius if ball != null else 0.1
	return local_ball_pos.x >= r \
		and absf(local_ball_pos.z) <= config.half_goal() \
		and local_ball_pos.y <= config.goal_height

# --- Datos para la IA y las asistencias ------------------------------------

func goal_center_world() -> Vector3:
	return global_position

## Punto objetivo dentro del arco. lateral: -1..1 (a lo largo de la linea, en el eje mundial Z),
## height: 0..1 de la altura util.
func aim_point(lateral: float, height_ratio: float, margin: float) -> Vector3:
	var usable: float = maxf(config.half_goal() - margin, 0.05)
	var z: float = clampf(lateral, -1.0, 1.0) * usable
	var y: float = lerpf(0.18, config.goal_height - margin, clampf(height_ratio, 0.0, 1.0))
	return Vector3(global_position.x, y, z)

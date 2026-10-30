class_name JsonSideline
extends Node3D
## Modo 4 (Json): personajes alrededor de la cancha que usan las escenas del JSON que no son de jugadores: un tecnico por
## equipo detras de la valla del fondo (clips de tecnico), la mascota en la mitad de la cancha (clips de mascota) y algunos
## espectadores mas atras (clips de publico). Solo presentacion: el humanoide del modo con otra ropa, una libreria propia
## pequena con los clips de su rol (no la de 3 000 clips) y un clip tras otro al azar, en el sitio (raiz corta).

## Recorrido maximo (m) de la raiz de un clip para usarlo en el sitio.
const ROOT_MAX := 1.0

var _figures: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

## Monta los personajes (solo en el modo 4 y con el humanoide disponible).
func setup(cfg: PitchConfig) -> void:
	if not PackLibrary.json_mode() or JsonCatalog.model_path() == "":
		return
	_rng.randomize()
	var edge: float = cfg.half_width() + (cfg.run_off if cfg.boundary_mode == PitchConfig.BoundaryMode.OUT_OF_BOUNDS else 0.0)
	var hl: float = cfg.half_length()
	var home: Dictionary = FootballerVisual.default_kit(0)
	var away: Dictionary = FootballerVisual.default_kit(1)
	# La camara de transmision mira desde +Z: todos van del lado -Z (al fondo de la imagen), mirando a la cancha (yaw PI).
	_add(&"manager", Vector3(-hl * 0.3, 0.0, -edge - 1.1), _coach_kit(home), 0)
	_add(&"manager", Vector3(hl * 0.3, 0.0, -edge - 1.1), _coach_kit(away), 1)
	_add(&"mascot", Vector3(0.0, 0.0, -edge - 1.6), {"jersey": Color(1.0, 0.45, 0.05), "shorts": Color(1.0, 0.45, 0.05), "socks": Color(0.95, 0.95, 0.95),
		"boots": Color(0.95, 0.95, 0.95), "skin": Color(0.95, 0.75, 0.55), "hair": Color(0.9, 0.35, 0.05)}, 2)
	var shirts: Array[Color] = [home["jersey"], away["jersey"], Color(0.2, 0.3, 0.8), Color(0.9, 0.9, 0.9), home["jersey"], away["jersey"]]
	for i in shirts.size():
		var x: float = lerpf(-hl * 0.75, hl * 0.75, float(i) / float(shirts.size() - 1))
		_add(&"crowd", Vector3(x, 0.0, -edge - 2.6 - 0.4 * float(i % 2)), {"jersey": shirts[i], "shorts": Color(0.15, 0.15, 0.2), "socks": Color(0.1, 0.1, 0.12),
			"boots": Color(0.2, 0.15, 0.1), "skin": Color(0.62 + 0.05 * float(i % 3), 0.42, 0.3), "hair": Color(0.1, 0.07, 0.04)}, 3 + i)

func _coach_kit(team_kit: Dictionary) -> Dictionary:
	return {"jersey": team_kit["jersey"], "shorts": Color(0.08, 0.08, 0.1), "socks": Color(0.08, 0.08, 0.1), "boots": Color(0.05, 0.05, 0.05),
		"skin": Color(0.62, 0.40, 0.29), "hair": Color(0.25, 0.25, 0.25)}

## Clips del rol que se pueden reproducir en el sitio.
static func clips_for(role: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in PackLibrary.by_role(role):
		if String(id).ends_with("_mirror"):
			continue
		var m: Dictionary = PackLibrary.meta(id)
		if (m.get("root_total", Vector2.ZERO) as Vector2).length() <= ROOT_MAX and float(m.get("duration", 0.0)) >= 0.8:
			out.append(id)
	return out

func _add(role: StringName, pos: Vector3, kit: Dictionary, idx: int) -> void:
	var clips: Array[StringName] = clips_for(role)
	if clips.is_empty():
		return
	var scene: PackedScene = load(JsonCatalog.model_path()) as PackedScene
	if scene == null:
		return
	var holder := Node3D.new()
	holder.name = "%s_%d" % [role, idx]
	add_child(holder)
	holder.position = pos
	holder.rotation.y = PI
	var rig := Node3D.new()
	rig.rotation.y = FootballerVisual.MODEL_YAW
	rig.scale = Vector3.ONE * FootballerVisual.MODEL_HEIGHT_SCALE
	holder.add_child(rig)
	var model: Node3D = scene.instantiate() as Node3D
	rig.add_child(model)
	var mat := ShaderMaterial.new()
	mat.shader = load(JsonCatalog.KIT_SHADER_PATH) as Shader
	for key in ["jersey", "shorts", "socks", "boots", "skin", "hair"]:
		mat.set_shader_parameter("%s_color" % key, kit[key])
	mat.set_shader_parameter("trim_color", kit["shorts"])
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	var lib := AnimationLibrary.new()
	for id in clips:
		lib.add_animation(id, PackLibrary.clip(id))
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.add_animation_library(&"s", lib)
	var fig := {"player": ap, "clips": clips, "role": role, "left": 0.0}
	_figures.append(fig)
	_next(fig)

func _process(delta: float) -> void:
	for fig in _figures:
		fig["left"] = float(fig["left"]) - delta
		if float(fig["left"]) <= 0.0:
			_next(fig)

## Siguiente clip al azar (los bucles tambien se cambian al terminar su duracion).
func _next(fig: Dictionary) -> void:
	var clips: Array = fig["clips"]
	var ap: AnimationPlayer = fig["player"]
	if clips.is_empty() or not is_instance_valid(ap):
		return
	var id: StringName = clips[_rng.randi() % clips.size()]
	ap.play(StringName("s/" + String(id)), 0.3)
	fig["left"] = maxf(PackLibrary.clip(id).length, 1.5)

## Cuantos personajes y clips distintos tiene cada rol (diagnostico y pruebas).
func summary() -> Dictionary:
	var out := {}
	for f in _figures:
		out[f["role"]] = int(out.get(f["role"], 0)) + 1
	return out

extends Node
## Constructor OFFLINE del modelo «Tripo adaptado» del modo Json: la malla del futbolista de Tripo (player_base.glb, sin
## cambios de forma ni de UV) con el esqueleto CANONICO JsonRig en pose T (las mismas articulaciones y proporciones que las
## animaciones JSON), en vez de los 23 huesos propios de Tripo. Los pesos de piel se pasan por nombre de hueso; solo cambian
## las articulaciones de sitio (rodilla 2 cm mas arriba, tobillo 5 cm mas arriba...) y los huesos sin extremo en los datos
## (manos, puntas) siguen a su padre.
## Salida: assets/characters/json/json_tripo.scn (versionada). Uso: godot --headless --path . res://tools/json_anim/build_json_tripo.tscn

const SRC := "res://assets/characters/player/player_base.glb"
const OUT := "res://assets/characters/json/json_tripo.scn"

func _ready() -> void:
	var inst: Node3D = (load(SRC) as PackedScene).instantiate()
	add_child(inst)
	var old_sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var mi_old: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var old_mesh: ArrayMesh = mi_old.mesh as ArrayMesh
	var old_skin: Skin = mi_old.skin
	var arrays: Array = old_mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var remap := {}
	for i in old_skin.get_bind_count():
		var n: String = old_skin.get_bind_name(i)
		if n == "":
			n = old_sk.get_bone_name(old_skin.get_bind_bone(i))
		remap[i] = JsonRig.BONES.find(n)
	var missing := 0
	for i in bones.size():
		var ni: int = remap.get(bones[i], -1)
		if ni < 0:
			missing += 1
			ni = 1
		bones[i] = ni
	arrays[Mesh.ARRAY_BONES] = bones
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, old_mesh.surface_get_material(0))
	var root := Node3D.new()
	root.name = "JsonTripo"
	var arm := Node3D.new()
	arm.name = "Armature"
	root.add_child(arm)
	var sk: Skeleton3D = JsonRig.build_skeleton(JsonRig.Pose.T)
	arm.add_child(sk)
	var skin := Skin.new()
	for i in JsonRig.BONES.size():
		skin.add_named_bind(JsonRig.BONES[i], _global_rest(sk, i).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.name = "JsonTripoMesh"
	mi.mesh = mesh
	mi.skin = skin
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	_own(root, root)
	var ps := PackedScene.new()
	var err: int = ps.pack(root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
		err = ResourceSaver.save(ps, OUT)
	print("JSON_TRIPO guardado %s (error=%d): %d vertices, huesos sin equivalente: %d" % [OUT, err, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), missing])
	get_tree().quit(0 if err == OK else 1)

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)

static func _global_rest(sk: Skeleton3D, bone: int) -> Transform3D:
	var chain: Array[int] = []
	var b: int = bone
	while b >= 0:
		chain.append(b)
		b = sk.get_bone_parent(b)
	var t := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		t = t * sk.get_bone_rest(chain[i])
	return t

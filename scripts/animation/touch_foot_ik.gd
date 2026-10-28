class_name TouchFootIK
extends SkeletonModifier3D
## Correccion del pie en los toques de conduccion: IK de dos huesos (cadera-rodilla-tobillo) en tiempo real, encima de
## la animacion. El clip de toque (TouchClipBuilder) da el gesto y este modificador lleva la punta del pie unos
## centimetros hasta el punto real de la pelota (algo mas adelante o atras, por dentro o por fuera), con la correccion
## y el peso que le da BallHandler en cada paso. Con peso 0 no toca la pose.
## Tambien lo usa TouchClipBuilder (herramienta) para construir los clips: ik_toe es el mismo calculo.

## Correccion maxima (m) de la punta del pie.
const MAX_SHIFT := 0.16
const LEG := {
	0: [&"mixamorig_LeftUpLeg", &"mixamorig_LeftLeg", &"mixamorig_LeftFoot", &"mixamorig_LeftToeBase"],
	1: [&"mixamorig_RightUpLeg", &"mixamorig_RightLeg", &"mixamorig_RightFoot", &"mixamorig_RightToeBase"],
}

var _shift: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _weight: Array[float] = [0.0, 0.0]
## Imagenes desde la ultima correccion recibida: si nadie la refresca (accion a mitad de toque) se suelta sola.
var _age: Array[int] = [0, 0]
var _bones: Array = []

## Correccion de la punta del pie `foot` (0 izquierdo, 1 derecho): desplazamiento en el mundo (se limita a MAX_SHIFT) y
## peso 0-1. Se mantiene hasta la siguiente llamada.
func set_correction(foot: int, shift_world: Vector3, weight: float) -> void:
	if foot < 0 or foot > 1:
		return
	_shift[foot] = shift_world.limit_length(MAX_SHIFT)
	_weight[foot] = clampf(weight, 0.0, 1.0)
	_age[foot] = 0

func weight(foot: int) -> float:
	return _weight[foot] if foot >= 0 and foot <= 1 else 0.0

## Desplazamiento (mundo) que se aplica ahora a la punta del pie. Las lecturas de huesos fuera del modificador
## (Skeleton3D.get_bone_global_pose) devuelven la pose ANTES de los modificadores: hay que sumarselo.
func applied_shift(foot: int) -> Vector3:
	return _shift[foot] * _weight[foot] if foot >= 0 and foot <= 1 else Vector3.ZERO

func _process_modification_with_delta(_delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or (_weight[0] < 0.001 and _weight[1] < 0.001):
		return
	if _bones.is_empty():
		for f in 2:
			var ids: Array = []
			for n in LEG[f]:
				ids.append(sk.find_bone(n))
			_bones.append(ids)
	var to_skel: Basis = sk.global_transform.basis.inverse()
	var up: Vector3 = (to_skel * Vector3.UP).normalized()
	for f in 2:
		_age[f] += 1
		if _age[f] > 4:
			_weight[f] *= 0.7
		if _weight[f] < 0.001 or (_bones[f] as Array).has(-1):
			continue
		var toe: Vector3 = PoseSampler.bone_in_skeleton(sk, _bones[f][3]).origin
		ik_toe(sk, _bones[f], toe + to_skel * (_shift[f] * _weight[f]), up, 0.0)

static func _set_global_basis(sk: Skeleton3D, bone: int, global_basis: Basis) -> void:
	var parent: int = sk.get_bone_parent(bone)
	var pb: Basis = PoseSampler.bone_in_skeleton(sk, parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (pb.inverse() * global_basis.orthonormalized()).get_rotation_quaternion())

## Lleva la punta del pie de la pierna `bones` [muslo, pierna, pie, punta] a want_toe (espacio del esqueleto) y gira el
## pie `pitch` radianes alrededor de su eje lateral (negativo = punta hacia abajo). up: arriba del mundo en el espacio
## del esqueleto. IK analitico de dos huesos con el polo de la rodilla actual (la rodilla sigue mirando adonde miraba).
static func ik_toe(sk: Skeleton3D, bones: Array, want_toe: Vector3, up: Vector3, pitch: float) -> void:
	var u: int = bones[0]
	var l: int = bones[1]
	var f: int = bones[2]
	var t: int = bones[3]
	var g_u: Transform3D = PoseSampler.bone_in_skeleton(sk, u)
	var g_l: Transform3D = PoseSampler.bone_in_skeleton(sk, l)
	var g_f: Transform3D = PoseSampler.bone_in_skeleton(sk, f)
	var g_t: Transform3D = PoseSampler.bone_in_skeleton(sk, t)
	var foot_vec: Vector3 = g_t.origin - g_f.origin
	var axis: Vector3 = foot_vec.cross(up)
	var extra := Basis.IDENTITY
	if axis.length() > 1e-5 and absf(pitch) > 1e-5:
		extra = Basis(axis.normalized(), pitch)
	var want_ankle: Vector3 = want_toe - extra * foot_vec
	var h: Vector3 = g_u.origin
	var k: Vector3 = g_l.origin
	var l1: float = (k - h).length()
	var l2: float = (g_f.origin - k).length()
	var dv: Vector3 = want_ankle - h
	var d: float = clampf(dv.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir: Vector3 = dv.normalized()
	var ax: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var hh: float = sqrt(maxf(l1 * l1 - ax * ax, 0.0))
	var pole: Vector3 = (k - h) - dir * (k - h).dot(dir)
	if pole.length() < 1e-5:
		pole = up.cross(dir)
	pole = pole.normalized()
	var k2: Vector3 = h + dir * ax + pole * hh
	_set_global_basis(sk, u, Basis(Quaternion((k - h).normalized(), (k2 - h).normalized())) * g_u.basis.orthonormalized())
	var g_l2: Transform3D = PoseSampler.bone_in_skeleton(sk, l)
	var g_f2: Transform3D = PoseSampler.bone_in_skeleton(sk, f)
	var a2: Vector3 = h + dir * d
	_set_global_basis(sk, l, Basis(Quaternion((g_f2.origin - g_l2.origin).normalized(), (a2 - g_l2.origin).normalized())) * g_l2.basis.orthonormalized())
	_set_global_basis(sk, f, extra * g_f.basis.orthonormalized())

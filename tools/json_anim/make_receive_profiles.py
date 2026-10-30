#!/usr/bin/env python3
"""Perfiles de contacto de los 124 clips de recepcion y control del modo 4 (F3).

Lee los JSON ORIGINALES de las animaciones (carpeta con los nombres originales, p. ej. `0564_CONTROL_EXE189_...json`) y
escribe `scripts/player/receive_profiles.gd` (una constante GDScript: se exporta con el juego sin filtros de exportacion).

Por clip (id del juego `jn_<rol>_<indice>`), con la evidencia de la auditoria de F3:
  - part: parte del cuerpo del PRIMER contacto real (foot, foot_air, thigh, knee, chest, head; leg = pierna levantada sin
    parte distinguible; nada se inventa: si la cinematica y el nombre no lo resuelven, el clip queda pendiente).
  - t: instante estimado del primer contacto (pico de la pierna o inclinacion del tronco), -1 si desconocido. NO es el
    primer `ball_touches` (toques de pie registrados, que pueden ser posteriores a un control con otra parte) ni `key_frame`.
  - status: usable | conditional | pending | not_reception (clasificacion de la auditoria: 23 / 27 / 70 / 4).
  - confidence: estimated (cinematica) | verified (contacto observado con la pelota en tools/json_anim/receive_view) |
    pending.
  - conds: condiciones de uso (stick_turn: giro >= 45 grados, stick_out: sale a >= 1.5 m/s, post_action: pase o golpeo
    posterior, rival: control protegiendo la pelota, jump: salto).
  - post_t: instante del pase o golpeo posterior (toque registrado a >= 6.5 m/s; en los clips «PASS», su primer toque
    posterior), -1 si no hay, -2 si el nombre dice pase pero no hay toque registrado (se corta 0.25 s tras el contacto).
  - from_deg: direccion de LLEGADA de la pelota respecto al frente (+ izquierda) en NUESTROS datos, o null. Los nombres
    tienen el lado invertido respecto de los datos (verificado en el modelo del juego: los clips «R_THIGH», «R_FOOT» y
    «FROM_R_…» suben la pierna izquierda del modelo), asi que «FROM_R_45» -> +45 (por la izquierda).
  - v_in, v_out, turn (grados), root (m), height (altura de la pelota que indica el nombre, solo informativa).
Los espejos (`_mirror`) usan el mismo perfil con from_deg y turn cambiados de signo (JsonReceive.profile).

Uso: python3 tools/json_anim/make_receive_profiles.py <carpeta_json_originales> [--out scripts/player/receive_profiles.gd]
"""
import json, math, os, re, sys


# Diferencias de medida con la auditoria de F3 (que manda): indice -> (estado, motivo).
AUDIT_OVERRIDES = {
	1824: ("usable", "la auditoria midio el toque posterior con la velocidad convertida (ball_touches, 5.6 m/s < 6.5): no es un pase; el JSON original da 6.55 m/s"),
}

# Contactos observados con la pelota en el visor (tools/json_anim/receive_view.tscn) durante F3: indice -> nota.
VERIFIED = {
	1330: "visor: pelota rasante de frente y de costado, punta del pie animado a -0.02 m de la pelota en el contacto",
	3068: "visor: pelota rasante con joystick, punta del pie a 0.05 m en el contacto",
	584: "visor: pelota con bote a 0.52-0.56 m, pie en el aire a 0.05-0.07 m de la pelota en el contacto",
	580: "visor: pelota a 0.88 m, la pelota toca el muslo levantado y cae delante (tira de imagenes)",
	588: "visor: pelota a 1.02 m, la pelota toca el pecho y cae delante (tira de imagenes)",
	574: "visor: pelota rasante, punta del pie a 0.00 m en el contacto; el pase posterior lo da el sistema de pase",
}

def samp(d, j, f):
	ts = d["times"]; J = d["joints"]; k = 0
	while k < len(ts) - 2 and ts[k + 1] < f:
		k += 1
	t0, t1 = ts[k], ts[k + 1]
	u = 0 if t1 == t0 else max(0, min(1, (f - t0) / (t1 - t0)))
	return [J[k][j][i] + (J[k + 1][j][i] - J[k][j][i]) * u for i in range(3)]

def kinematics(d):
	jn = d["joint_names"]; fps = d["fps"]; tend = d["times"][-1]
	J = lambda n: jn.index(n)
	rows = []
	for f in range(0, tend + 1, 2):
		g = lambda n: samp(d, J(n), f)
		P = g("pelvis"); C = g("chest"); H = g("head"); hl = g("l_hip"); hr = g("r_hip")
		rx, rz = hr[0] - hl[0], hr[2] - hl[2]; n = math.hypot(rx, rz) or 1; rx, rz = rx / n, rz / n
		fx, fz = -rz, rx
		tr = g("r_toe"); ar = g("r_ankle"); tl = g("l_toe"); al = g("l_ankle")
		if (tr[0] - ar[0] + tl[0] - al[0]) * fx + (tr[2] - ar[2] + tl[2] - al[2]) * fz < 0:
			fx, fz = -fx, -fz
		kl = g("l_knee"); kr = g("r_knee")
		rows.append(dict(t=f / fps, P=P[1], lean=(C[0] - P[0]) * fx + (C[2] - P[2]) * fz, kL=kl[1], kR=kr[1],
			toeL=tl[1], toeR=tr[1], ankL=al[1], ankR=ar[1]))
	return rows

def classify(idx, d, role):
	name = d["name"].replace("ANM_", ""); up = name.upper(); meta = d["meta"]
	rows = kinematics(d)
	pk = lambda key: max(rows, key=lambda x: x[key])
	kL, kR, tL, tR = pk("kL"), pk("kR"), pk("toeL"), pk("toeR")
	knee, kt = (kL["kL"], kL["t"]) if kL["kL"] >= kR["kR"] else (kR["kR"], kR["t"])
	toe, tt = (tL["toeL"], tL["t"]) if tL["toeL"] >= tR["toeR"] else (tR["toeR"], tR["t"])
	lean0 = rows[0]["lean"]; lmin = min(rows, key=lambda x: x["lean"]); lb = lean0 - lmin["lean"]; lbt = lmin["t"]
	air = [x["t"] for x in rows if min(x["toeL"], x["ankL"]) > 0.12 and min(x["toeR"], x["ankR"]) > 0.12]
	jump = bool(air) or max(x["P"] for x in rows) - rows[0]["P"] >= 0.15
	part_name = None
	if "CHEST" in up: part_name = "chest"
	elif "THIGH" in up: part_name = "thigh"
	elif re.search(r"(^|_)KNEE(_CONTROL|_STAND|_FORWARD|$)", up) and "KNEE_HIGH" not in up: part_name = "knee"
	elif "RECEIVE_HEAD" in up: part_name = "head"
	elif "FOOT" in up: part_name = "foot"
	leg_lift = knee >= 0.58 or toe >= 0.08
	high_foot = toe >= 0.45 and knee >= 0.85
	chest_sig = lb >= 0.12
	part = None; t_c = None; pend = []
	if part_name == "chest":
		part = "chest"; t_c = lbt if chest_sig else None
		if not chest_sig: pend.append("CHEST sin inclinacion del tronco")
		if leg_lift and (not chest_sig or kt > lbt + 0.05):
			pend.append("sube tambien la pierna"); t_c = t_c if t_c is not None else kt
	elif part_name == "thigh": part = "thigh"; t_c = kt
	elif part_name == "knee": part = "knee"; t_c = kt
	elif part_name == "head": part = "head"; pend.append("cabeza sin senal medible")
	elif part_name == "foot": part = "foot_air" if toe >= 0.30 else "foot"; t_c = tt if toe >= 0.08 else kt
	elif high_foot: part = "foot_air"; t_c = tt
	elif toe < 0.20 and knee < 0.62 and toe >= 0.08: part = "foot"; t_c = tt
	elif leg_lift:
		part = "leg"; t_c = kt; pend.append("pie, muslo o rodilla no se distinguen")
	elif chest_sig: part = "chest"; t_c = lbt; pend.append("solo inclina el tronco")
	else: part = "foot"; pend.append("ningun pie se levanta")
	leg_based = part in ("foot", "foot_air", "thigh", "knee", "leg")
	if t_c is not None and t_c > 0.75 and leg_based:
		pend.append("pico tardio (zancada)")
	fps = d["fps"]
	touches = sorted([[float(t[0]) / fps, t[1], float(t[2]), float(t[3])] for t in meta.get("touches", [])])
	after = [t for t in touches if t_c is None or t[0] > t_c + 0.05]
	strong = [t for t in after if t[3] >= 6.5]
	turn = float(meta.get("yaw_end", 0.0)) - float(meta.get("yaw_start", 0.0))
	v_in = float(meta.get("v_in", 0.0)); v_out = float(meta.get("v_out", 0.0))
	root = math.hypot(*meta.get("root_end", [0.0, 0.0]))
	conds = []
	if abs(turn) >= 45: conds.append("stick_turn")
	if v_out >= 1.5: conds.append("stick_out")
	if "PASS" in up or strong: conds.append("post_action")
	if jump: conds.append("jump")
	if role == "jostle_ball": conds.append("rival")
	if re.search(r"STAND_TO_(WALKING|JOGGING)_DRIBBLE|STAND_TO_45_R_FORWARDS_JOGGING_DRIBBLE", up):
		status = "not_reception"
	elif role == "jostle_ball":
		status = "conditional"
	elif pend:
		status = "pending"
	elif "post_action" in conds or "stick_turn" in conds or "stick_out" in conds or "jump" in conds:
		status = "conditional"
	else:
		status = "usable"
	note_extra = ""
	if idx in AUDIT_OVERRIDES:
		status, note_extra = AUDIT_OVERRIDES[idx]
		conds = [c for c in conds if c != "post_action"]; strong = []
	from_deg = None
	m = re.search(r"FROM_(R|L)_(\d+)", up)
	if m: from_deg = float(m.group(2)) * (1.0 if m.group(1) == "R" else -1.0)
	elif "FROM_FORWARD" in up: from_deg = 0.0
	elif "OVER_L_SHOULDER" in up: from_deg = -150.0
	elif "FROM_R_SHOULDER" in up: from_deg = 90.0
	elif "FWD" in up: from_deg = 0.0
	height = None
	for tok in ("KNEE_HIGH", "WAIST_HIGH", "SHOULDER_HEIGHT", "LOW_HEIGHT", "_LOW", "_HIGH_", "MEDIUM", "_AIR_", "OVERHEAD"):
		if tok in up:
			height = tok.strip("_").lower(); break
	return dict(name=name, part=part, t=round(t_c, 3) if t_c is not None else -1.0, status=status,
		confidence=("verified" if idx in VERIFIED else ("pending" if status == "pending" else "estimated")),
		conds=conds, post_t=round(strong[0][0], 3) if strong else ((round(after[0][0], 3) if after else -2.0) if "PASS" in up else -1.0),
		from_deg=from_deg, v_in=round(v_in, 2), v_out=round(v_out, 2), turn=round(turn, 1), root=round(root, 2),
		height=height, touches_after=[round(t[0], 3) for t in after], note="; ".join(pend + ([note_extra] if note_extra else [])))

def gd_value(v):
	if v is None: return "null"
	if isinstance(v, bool): return "true" if v else "false"
	if isinstance(v, (int, float)): return repr(float(v))
	if isinstance(v, str): return '"%s"' % v.replace('"', "'")
	if isinstance(v, list): return "[" + ", ".join(gd_value(x) for x in v) + "]"
	raise TypeError(v)

def main():
	if len(sys.argv) < 2:
		print(__doc__); sys.exit(1)
	src = sys.argv[1]
	out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "scripts/player/receive_profiles.gd"
	here = os.path.dirname(os.path.abspath(__file__))
	sel = json.load(open(os.path.join(here, "selection.json")))["clips"]
	roles = ("receive", "receive_turn", "control_stand", "ball_start", "jostle_ball", "receive_foot")
	files = {int(f[:4]): f for f in os.listdir(src) if f[:4].isdigit() and f.endswith(".json")}
	prof = {}
	for e in sel:
		cid = e["id"]; role = cid[3:].rsplit("_", 1)[0]
		if role not in roles or cid.endswith("_mirror"):
			continue
		idx = int(e["file"])
		d = json.load(open(os.path.join(src, files[idx])))
		prof[cid] = classify(idx, d, role)
	counts = {}
	for p in prof.values():
		counts[p["status"]] = counts.get(p["status"], 0) + 1
	lines = ["class_name ReceiveProfiles", "extends RefCounted",
		"## GENERADO por tools/json_anim/make_receive_profiles.py (no editar a mano): perfiles de contacto de los %d clips de" % len(prof),
		"## recepcion y control del modo 4 (auditoria de F3). Estados: %s." % ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts)),
		"## Campos y criterios: ver la cabecera del generador.", "", "const PROFILES := {"]
	for cid in sorted(prof):
		p = prof[cid]
		lines.append("\t&\"%s\": {%s}," % (cid, ", ".join('"%s": %s' % (k, gd_value(v)) for k, v in p.items())))
	lines.append("}")
	open(out, "w").write("\n".join(lines) + "\n")
	print("%d perfiles -> %s %s" % (len(prof), out, counts))

if __name__ == "__main__":
	main()

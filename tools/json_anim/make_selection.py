#!/usr/bin/env python3
"""Genera tools/json_anim/selection.json: que clips de animaciones_futbol5_JSON se convierten al modo Json, con su rol.

Uso: python3 tools/json_anim/make_selection.py <carpeta_de_los_JSON>
La seleccion mezcla listas curadas a mano (marcha, conduccion, celebraciones, arquero...) con reglas sobre el indice del zip
(patadas: bajas, hacia delante, con el contacto medido). Cada entrada:
  file    prefijo numerico del archivo (0000-4043)         id      nombre en la libreria (jn_<rol>_<indice>)
  role    para que lo usa el juego (AnimationCatalog)       alias   nombres de clips del pack de Mixamo a los que sustituye en el modo Json
  loop / phase (bucle girado hasta un apoyo izquierdo) / cycle (ciclo recortado entre dos apoyos del mismo pie, 60 Hz)
  mirror  tambien la version espejo (<id>_mirror)           only_mirror  solo el espejo (el ciclo empieza con el pie izquierdo)
  kick    mide el contacto del golpeo                        root_driven  el juego mueve al cuerpo con la raiz del clip (caidas, barridas, saques)
  hi      claves a 60 Hz en vez de 30                        library  field | keeper
"""
import json, math, os, re, sys

src = sys.argv[1]
idx = json.load(open(os.path.join(src, "index.json")))
by_prefix = {c["file"][:4]: c for c in idx["clips"]}
clips = []
ids = set()


def add(prefix, role, **kw):
    c = by_prefix.get(prefix)
    if c is None:
        print("falta", prefix)
        return None
    cid = kw.pop("id", None) or "jn_%s_%s" % (role, prefix)
    if cid in ids:
        cid = cid + "b"
    ids.add(cid)
    e = {"file": prefix, "id": cid, "role": role}
    e.update(kw)
    clips.append(e)
    return e


def first_stride(c, foot):
    for fr, f in c["meta"]["strides"]:
        if f == foot:
            return fr
    return None


# --- Marcha en bucle (todos empiezan en un apoyo del pie izquierdo; el espejo, del derecho original) -------------------------
for p in ["0520", "1138", "1140", "1142"]:
    add(p, "idle", loop=True)
add("0524", "idle_ball", loop=True)
for role, plist in [("walk", ["0460", "1474", "2024", "3498"]), ("jog", ["1144", "2390"]), ("run", ["2392", "0190"]),
                    ("sprint", ["3022", "0072", "0074", "2036", "2034"])]:
    for p in plist:
        c = by_prefix[p]
        add(p, role, loop=True, phase=first_stride(c, "L"))

# Direcciones (BlendSpace2D del marcaje): la direccion de cada clip se mide en los datos; el espejo da el lado contrario.
for p, role in [("0486", "dir_back"), ("0480", "dir_back_diag"), ("0470", "dir_fwd_diag"), ("0186", "dir_side"), ("1482", "dir_back_walk"), ("1476", "dir_fwd_diag_walk")]:
    c = by_prefix[p]
    fl = first_stride(c, "L")
    fr_ = first_stride(c, "R")
    add(p, role, loop=True, mirror=True, phase=fl if fl is not None else 0, phase_mirror=fr_ if fr_ is not None else 0)


# --- Conduccion: ciclos entre dos apoyos del mismo pie (con el pie izquierdo primero) -----------------------------------------
def dribble_cycle(prefix, role):
    c = by_prefix[prefix]
    st = c["meta"]["strides"]
    if len(st) < 3 or st[0][1] != st[2][1]:
        print("sin ciclo", prefix, st)
        return
    kw = {"cycle": [st[0][0], st[2][0]], "dribble": True, "hi": True}
    if st[0][1] == "R":
        kw["only_mirror"] = True
    add(prefix, role, **kw)


c = by_prefix["0234"]
st = c["meta"]["strides"]
add("0234", "dribble_walk", cycle=[st[0][0], st[2][0]], dribble=True, hi=True, only_mirror=(st[0][1] == "R"))
for p in ["1574", "2106"]:
    dribble_cycle(p, "dribble_jog")
for p in ["1288", "3186", "3184"]:
    dribble_cycle(p, "dribble_run")
for p in ["0194", "2092", "0548"]:
    dribble_cycle(p, "dribble_fast")
for p in ["1582", "3190", "1584"]:
    dribble_cycle(p, "dribble_sprint")

# --- Patadas: pase / tiro / vaselina / centro (pierna que patea la de los datos; mirror da la otra) --------------------------
KICK_PASS_SOFT = ["0626", "1608", "1616", "2462", "3052", "1600", "2458"]
KICK_PASS = ["0636", "3056", "3086", "2194", "3652", "3654", "3660", "1204", "1208", "0672", "0668", "3238"]
# Tiros: con la carrera de entrada de cada clip (v_in) desde parado (0.0-1.2 m/s) hasta sprint (4 m/s), para que el pie de apoyo no patine.
KICK_SHOT = ["0656", "2520", "2524", "2988", "3246", "3598", "3588", "3580", "3666", "2202", "2200", "2204", "0694", "0748", "1752", "1754", "1756", "1758", "2528", "2522", "3584"]
KICK_SHOT_HARD = ["2548", "2550", "2544", "3254", "3256", "3260", "3264", "3780", "3610", "3618"]
KICK_LOB = ["0646", "0666", "0654", "0652"]
KICK_CROSS = ["0666"]
for p in KICK_PASS_SOFT:
    add(p, "kick_pass_soft", kick=True, hi=True, mirror=True)
for p in KICK_PASS:
    add(p, "kick_pass", kick=True, hi=True, mirror=True, alias=["Soccer_Pass"] if p == "0636" else [])
for p in KICK_SHOT:
    add(p, "kick_shot", kick=True, hi=True, mirror=True)
for p in KICK_SHOT_HARD:
    add(p, "kick_shot_hard", kick=True, hi=True, mirror=True)
for p in KICK_LOB:
    add(p, "kick_lob", kick=True, hi=True, mirror=True)

# Pelota en el aire: cabezazos y voleas (el planificador aereo busca el instante en que la cabeza / el pie coincide con la pelota).
for p in ["1844", "1846", "2232", "0832", "1858", "2628", "2652", "1848"]:
    add(p, "header", hi=True, mirror=True)
for p in ["0732", "0734", "2562", "2570", "2572", "3284", "3294"]:
    add(p, "volley", kick=True, hi=True, mirror=True)

# --- Control de balon / recepcion -------------------------------------------------------------------------------------------
add("0582", "receive_chest", alias=["Receive"])
add("0564", "receive_foot", alias=["receive_soccerball"], mirror=True)
add("0576", "receive_foot", mirror=True)
add("0578", "receive_foot")

# --- Entradas, caidas, levantarse (el juego mueve al cuerpo con la raiz) -------------------------------------------------------
add("0220", "slide", root_driven=True, mirror=True, hi=True, alias=["soccer_tackle"])
add("0086", "slide", root_driven=True, mirror=True, hi=True, alias=["soccer_tackle_2"])
add("3542", "slide", root_driven=True, mirror=True, hi=True, alias=["soccer_tackle_3"])
add("2746", "slide", root_driven=True, mirror=True, hi=True)
add("0860", "trip", root_driven=True, mirror=True, alias=["soccer_trip"])
add("2352", "fall_hit", root_driven=True, mirror=True, alias=["Shoulder_Hit_And_Fall", "Sprint_To_Backslide"])
add("3514", "fall", root_driven=True, mirror=True, alias=["Falling_Down"])
add("3512", "fall", root_driven=True, mirror=True, alias=["Sweep_Fall"])
add("0980", "fall", root_driven=True, mirror=True)
add("0856", "lie", loop=True, root_driven=True, alias=["fallen_idle"])
add("0810", "getup", root_driven=True, alias=["standing_up"])
add("0806", "getup", root_driven=True, alias=["Getting_Up_3"])
add("0808", "getup", root_driven=True)
add("2238", "getup", root_driven=True)
add("2418", "shove", root_driven=True, alias=["Shove_Reaction"])
add("2420", "shove", root_driven=True, alias=["Shove_Reaction_2"])
add("1440", "stumble", root_driven=True, mirror=True, alias=["Jogging_Stumble"])
add("1260", "stumble_light", alias=["Jogging_Stumble_inplace"])
add("0336", "jump", alias=["Jumping_Up", "Jump_4", "Jump_2"])

# --- Celebraciones y gestos (NIS) -----------------------------------------------------------------------------------------------
add("0090", "celebrate", alias=["Fist_Pump_3"])
add("0092", "celebrate", alias=["Cheering_2"])
add("0338", "celebrate", alias=["Fist_Pump"])
add("1954", "celebrate", alias=["Standing_Fist_Pump"])
add("0874", "celebrate_scorer", alias=["Excited"])
add("0942", "celebrate_scorer", alias=["Victory"])
add("1950", "celebrate_scorer", alias=["Taunt"])
add("1952", "celebrate_scorer", alias=["Cheering"])
add("0298", "celebrate_team", alias=["Clapping"])
add("2014", "celebrate_team", alias=["Waving_3", "Waving"])
add("2020", "celebrate_team", alias=["Pointing_2"])
add("1462", "thumbs_up", alias=["Standing_Thumbs_Up"])
add("1968", "dejected", alias=["Defeat_Idle_2"])
add("1974", "dejected", alias=["Disappointed"])
add("0102", "dejected", alias=["Sad_Idle_3"])
add("0104", "dejected", alias=["Crying"])
add("0112", "dejected", alias=["Defeated"])
add("1418", "dejected", alias=["Loser"])
add("0956", "defeat_end", alias=["Defeat"])
add("0356", "angry", alias=["Angry_Gesture_2", "Angry"])
add("0366", "angry", alias=["Standing_Yell_2"])
add("0368", "angry", alias=["Yelling_While_Standing"])
add("0320", "warmup", alias=["Arm_Stretching"])
add("0322", "warmup", alias=["Neck_Stretching"])
add("0360", "referee", alias=["Counting"])
add("0362", "referee", alias=["Pointing_Forward"])
add("0364", "referee")

# --- Saques: banda y balon parado ---------------------------------------------------------------------------------------------------
add("2508", "throw_in", throw=True, root_driven=True, alias=["throw_in"])
add("2506", "throw_in", throw=True, root_driven=True)
add("3446", "throw_in", throw=True, root_driven=True)
for p, al in [("3744", ["strike_foward_jog"]), ("3738", []), ("3732", [])]:
    add(p, "setpiece_pass", kick=True, root_driven=True, hi=True, mirror=True, alias=al)
for p, al in [("3856", ["soccer_penalty_kick"]), ("3850", []), ("3846", []), ("3840", [])]:
    add(p, "setpiece_shot", kick=True, root_driven=True, hi=True, mirror=True, alias=al)
for p, al in [("3742", ["Chip"]), ("3746", [])]:
    add(p, "setpiece_lob", kick=True, root_driven=True, hi=True, mirror=True, alias=al)

# --- Arquero (libreria aparte) ----------------------------------------------------------------------------------------------------------
K = {"library": "keeper"}
add("0884", "gk_idle", loop=True, alias=["goalkeeper_idle"], **K)
add("3548", "gk_idle", loop=True, **K)
add("3552", "gk_idle", loop=True, **K)
add("0496", "gk_idle_ball", loop=True, alias=["goalkeeper_idle_2"], **K)
# Estiradas (laterales: el espejo da el otro lado), con la raiz del clip.
for p, al in [("0000", ["goalkeeper_diving_save"]), ("0002", []), ("0010", ["goalkeeper_diving_save_2"]), ("0012", []), ("0014", []),
              ("0006", []), ("0008", []), ("0028", []), ("0030", []), ("0034", []), ("0038", []), ("0020", []), ("0024", []),
              ("3796", []), ("3798", []), ("3804", []), ("2632", []), ("2634", []), ("3928", []), ("3930", []), ("1688", []), ("1690", []),
              ("1694", []), ("1698", []), ("0910", []), ("0912", []), ("0914", []), ("0920", []), ("0924", []), ("0926", [])]:
    add(p, "gk_dive", mirror=True, root_driven=True, hi=True, alias=al, **K)
for p, al in [("0888", ["goalkeeper_catch_2"]), ("0892", []), ("0894", []), ("0900", []), ("0896", ["goalkeeper_catch_4"]), ("1742", ["goalkeeper_catch_3"]),
              ("1746", []), ("1748", []), ("1750", []), ("2678", []), ("2680", []), ("2682", []), ("2684", []), ("2686", []), ("2690", []),
              ("2692", []), ("2698", []), ("2704", []), ("0930", []), ("0932", [])]:
    add(p, "gk_catch", mirror=True, root_driven=True, hi=True, alias=al, **K)
for p, al in [("0898", ["goalkeeper_scoop"]), ("1722", []), ("1726", []), ("1728", []), ("1732", []), ("1736", []), ("1740", ["goalkeeper_catch"]), ("2658", []), ("2660", [])]:
    add(p, "gk_scoop", mirror=True, root_driven=True, hi=True, alias=al, **K)
add("0184", "gk_sidestep", mirror=True, loop=True, root_driven=True, alias=["goalkeeper_sidestep", "goalkeeper_sidestep_2"], **K)
for p, al in [("0054", ["goalkeeper_body_block"]), ("0928", ["goalkeeper_body_block_2"]), ("0044", ["goalkeeper_body_block_3"]), ("0052", [])]:
    add(p, "gk_block", mirror=True, root_driven=True, alias=al, **K)
add("0046", "gk_miss", mirror=True, root_driven=True, alias=["goalkeeper_miss"], **K)
add("0068", "gk_throw", throw=True, root_driven=True, alias=["goalkeeper_overhand_throw", "Goalie_Throw"], **K)
add("1874", "gk_throw", throw=True, root_driven=True, **K)
add("1878", "gk_throw", throw=True, root_driven=True, **K)
add("0066", "gk_roll", throw=True, root_driven=True, alias=["goalkeeper_pass"], **K)
add("1876", "gk_roll", throw=True, root_driven=True, **K)
for p, al in [("1884", ["goalkeeper_drop_kick"]), ("2706", []), ("2708", []), ("2710", []), ("3412", []), ("3410", [])]:
    add(p, "gk_kick", kick=True, root_driven=True, mirror=True, hi=True, alias=al, **K)
add("0178", "gk_place", root_driven=True, alias=["goalkeeper_placing_ball"], **K)
add("0312", "gk_place", root_driven=True, alias=["goalkeeper_placing_ball_2"], **K)
add("0362", "gk_direct", alias=["goalkeeper_directing"], id="jn_gk_direct_0362", **K)
add("0364", "gk_direct", alias=["goalkeeper_directing_2"], id="jn_gk_direct_0364", **K)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "selection.json")
json.dump({"clips": clips}, open(out, "w"), indent=1)
roles = {}
for e in clips:
    roles[e["role"]] = roles.get(e["role"], 0) + (2 if e.get("mirror") else 1)
print(len(clips), "entradas,", sum(roles.values()), "clips con espejos")
print(roles)

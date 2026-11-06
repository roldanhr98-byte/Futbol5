"""Genera docs/transferencia_integracion_completa/INVENTARIO_ANIMACIONES.csv: UNA fila por animacion del banco (2 024 tramos
de los 2 022 JSON), con lo que usa el juego (metadata de la libreria convertida) y lo que dice UCS (animdb.adb).

Entradas (rutas por argumento; el banco JSON y el animdb.adb de UCS no estan en el repositorio):
  1. index.json del banco (animaciones_futbol5_conectadas_y_sin_conectar/index.json o el del pack original)
  2. animdb.adb de UCS (paquete_recursos_analisis_movimiento/animaciones/animdb.adb)
  3. library_meta.json: lo escribe tools/transfer/dump_library_meta.tscn (OUT=...)
Ademas lee docs/fases/E2_inventario_banco.csv y assets/animations/animdb.json del repositorio.

Uso: python3 tools/transfer/make_inventory.py <index.json> <animdb.adb> <library_meta.json> [salida.csv]
"""
import csv
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "transferencia_integracion_completa", "INVENTARIO_ANIMACIONES.csv")

# Sistema que elige y ejecuta cada accion (rol) y sus condiciones de entrada/salida, segun el codigo (ver MAPA_ANIMACIONES.md).
ROLE_RULES = {
    "kick_pass": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates (scripts/animation/json_catalog.gd)", "golpeo pass: carga < 0.35 (con kick_pass_soft), 0.35-0.8 (solo kick_pass), >= 0.8 (con kick_shot); centro (cross, con kick_cross y kick_lob); solo contactos limpios (contact.clean)", "BallHandler._finish_clip_kick: la marcha sigue con la velocidad previa"),
    "kick_pass_soft": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo pass con carga < 0.35; contacto limpio", "idem kick_pass"),
    "kick_shot": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo shot (cualquier carga) y pass con carga >= 0.8; contacto limpio", "idem kick_pass"),
    "kick_shot_hard": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo shot con carga >= 0.45; contacto limpio", "idem kick_pass"),
    "kick_lob": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo lob, y cross; contacto limpio", "idem kick_pass"),
    "kick_cross": ("BallHandler.plan_clip_kick con JsonCatalog.kick_candidates", "golpeo cross (unico rol admitido sin contacto limpio)", "idem kick_pass"),
    "kick_turn": ("BallHandler.plan_turn_kick (golpeo girando)", "destino del golpe a >= 50 grados del frente; pelota sale hacia alli (+-40)", "cuerpo con raiz y rumbo del clip hasta el contacto"),
    "kick_back": ("BallHandler.plan_turn_kick (golpeo girando)", "destino del golpe detras", "idem"),
    "header": ("BallHandler golpeo aereo (plan aereo, header/volley)", "pelota alta que llega; orden de golpeo", "segun clip"),
    "volley": ("BallHandler golpeo aereo (plan aereo, header/volley)", "pelota a media altura que llega; orden de golpeo", "segun clip"),
    "ball_turn": ("JsonBallMove (intencion turn; y steer si es de control con dribble)", "joystick a >= 50 grados del frente (IA >= 110); |v_in - v| <= 1.5 m/s; la pelota llega al primer toque", "ultima salida: pelota delante del rumbo de salida; marcha con v_out"),
    "ball_turn_stop": ("JsonBallMove (turn_for_kick, drag)", "giro antes de golpear hacia atras; REGATE + atras", "pelota quieta delante del pie"),
    "ball_skill": ("JsonBallMove (intencion skill; y steer si es de control con dribble)", "boton REGATE", "idem ball_turn"),
    "ball_stop": ("JsonBallMove (intencion stop)", "soltar el joystick a 2.6-4.6 m/s conduciendo", "pelota quieta delante"),
    "ball_start": ("JsonBallMove (intencion start, si v_out >= 1)", "jugador de la persona casi quieto (< 0.6 m/s), joystick >= 0.6 a < 50 grados, sin sprint", "clip entero; marcha con v_out"),
    "receive": ("JsonReceive (recepcion con clip)", "pelota que llega; perfil ReceiveProfiles con contacto verificado", "pelota con la respuesta de la parte del cuerpo"),
    "receive_turn": ("JsonReceive (recepcion con clip)", "idem con giro", "idem"),
    "receive_foot": ("JsonReceive (recepcion con clip)", "idem pie", "idem"),
    "control_stand": ("JsonReceive (recepcion con clip)", "idem parado", "idem"),
    "jostle_ball": ("JsonReceive (recepcion con clip)", "idem protegiendo", "idem"),
    "dribble_walk": ("Marcha con pelota (JsonCatalog.CARRY, FootballerVisual)", "escalon de velocidad del BlendSpace Carry", "ciclo"),
    "dribble_jog": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "dribble_run": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "dribble_fast": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "dribble_sprint": ("Marcha con pelota (JsonCatalog.CARRY)", "idem", "ciclo"),
    "idle_ball": ("Marcha con pelota (JsonCatalog.CARRY, reposo)", "velocidad 0 con pelota", "ciclo"),
    "walk": ("Marcha (JsonCatalog.GAIT)", "escalon del BlendSpace", "ciclo"),
    "jog": ("Marcha (JsonCatalog.GAIT)", "idem", "ciclo"),
    "run": ("Marcha (JsonCatalog.GAIT)", "idem", "ciclo"),
    "sprint": ("Marcha (JsonCatalog.GAIT)", "idem", "ciclo"),
    "idle": ("Marcha (JsonCatalog.GAIT, reposo)", "velocidad 0", "ciclo"),
    "turn_start": ("Footballer._json_turn_move (giro sin pelota)", "sin pelota, < 1.3 m/s, joystick a >= 100 grados, pelota a >= 6 m", "raiz y rumbo del clip; marcha"),
    "turn_run": ("Footballer._json_turn_move (giro sin pelota, solo persona)", "sin pelota, 2.2-5.6 m/s, joystick a >= 100 grados", "idem"),
    "slide": ("PlayerActions.try_slide_tackle (barrida)", "planificador de barrida: pie llega a la pelota", "caida/levantarse segun resultado"),
    "tackle_stand": ("PlayerActions (entrada de pie)", "entrada con boton o IA", "segun clip"),
    "shove": ("PlayerActions.shoulder_charge (carga)", "carga junto al portador", "segun clip"),
    "fall": ("PlayerActions._json_fall (caida)", "choque/entrada sufrida", "levantarse (_json_getup)"),
    "getup": ("PlayerActions._json_getup", "tras caida, misma postura (lie)", "marcha"),
    "gk_dive": ("Goalkeeper + KeeperPlanner.plan_save", "tiro a puerta; plan de atajada", "levantarse del arquero"),
    "gk_catch": ("Goalkeeper + KeeperPlanner", "idem blocaje", "arquero con pelota"),
}


def adb(path):
    d = open(path, "rb").read()
    n = struct.unpack_from("<I", d, 0)[0]
    return [struct.unpack_from("<52h", d, 4 + i * 104) for i in range(n)]


def fmt_v(v):
    return "(%s)" % ", ".join("%.3f" % float(x) for x in v) if isinstance(v, list) else ""


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    bank = json.load(open(sys.argv[1], encoding="utf-8"))["clips"]
    recs = adb(sys.argv[2])
    lib = json.load(open(sys.argv[3], encoding="utf-8"))
    out_path = sys.argv[4] if len(sys.argv) > 4 else OUT
    e2 = {}
    for r in csv.DictReader(open(os.path.join(ROOT, "docs", "fases", "E2_inventario_banco.csv"), encoding="utf-8")):
        e2.setdefault(r["archivo"][:4], []).append(r)
    adb_json = json.load(open(os.path.join(ROOT, "assets", "animations", "animdb.json"), encoding="utf-8"))
    rows = []
    for c in bank:
        key = c["file"][:4]
        i = int(key)
        h = recs[i] if i < len(recs) else None
        tramos = adb_json["clips"].get(key, {}).get("tramos", [])
        for k, r in enumerate(e2.get(key, [{}])):
            cid = r.get("id", "")
            t = tramos[k] if k < len(tramos) else {}
            m = lib.get(cid, {})
            mirror = cid + "_mirror" if (cid + "_mirror") in lib else ""
            role = r.get("nueva", "")
            rule = ROLE_RULES.get(role, ("ver MAPA_ANIMACIONES.md (rol %s)" % role, "", ""))
            bt = m.get("ball_touches", [])
            touches = "; ".join("t=%.3f pie=%s punta=%s" % (float(x[0]), "der" if int(x[1]) > 0 else "izq", fmt_v(x[2])) for x in bt)
            ct = m.get("contact", {}) if isinstance(m.get("contact", {}), dict) else {}
            ucs = {}
            if h is not None:
                ucs = {
                    "ucs_cuadro_toque": h[3],
                    "ucs_t_toque_s": round(h[3] / 60.0, 3),
                    "ucs_pie_toque": "izq" if h[4] & 128 else ("der" if h[4] & 256 else ""),
                    "ucs_giro_sector_grados": h[9],
                    "ucs_giro_medido_grados": h[47],
                    "ucs_ventana_joystick_min": h[7],
                    "ucs_ventana_joystick_max": h[8],
                    "ucs_v_in_x10": h[5],
                    "ucs_v_out_x10": h[6],
                    "ucs_destino_adelante_m": round(-h[25] / 1000.0, 3),
                    "ucs_destino_izquierda_m": round(h[27] / 1000.0, 3),
                    "ucs_cuadros": h[2],
                }
            meta = c.get("meta", {})
            row = {
                "indice": key,
                "archivo_json_banco": c["file"],
                "nombre_ucs": c["name"],
                "categoria": c.get("category", ""),
                "cuadros_60fps": c.get("frames", ""),
                "duracion_s": c.get("duration", ""),
                "tramo": k,
                "id_juego": cid,
                "id_espejo": mirror,
                "libreria": m.get("library", ""),
                "fuente_libreria": m.get("source", ""),
                "accion_rol": role,
                "rol_antes_de_E2": r.get("anterior", ""),
                "estado_conexion": t.get("conectada", r.get("util", "")),
                "sistemas": " | ".join(t.get("sistemas", [])) or r.get("sistema", ""),
                "motivo_estado": t.get("motivo", r.get("motivo", "")),
                "sistema_que_selecciona": rule[0],
                "condicion_entrada": rule[1],
                "condicion_salida": rule[2],
                "movimiento_heading_mode": m.get("heading_mode", ""),
                "bucle": m.get("loop", ""),
                "giro_cuerpo_juego_grados": round(float(m.get("turn_deg", 0.0)), 1) if m else "",
                "raiz_total_m_adelante_derecha": fmt_v(m.get("root_total")) if m else "",
                "v_in_juego_m_s": m.get("v_in", ""),
                "v_out_juego_m_s": m.get("v_out", ""),
                "toques_pelota_juego": touches,
                "contacto_golpe_t_s": ct.get("time", ""),
                "contacto_golpe_pie": ("der" if int(ct["foot"]) > 0 else "izq") if "foot" in ct else "",
                "contacto_golpe_punta_m_adelante_arriba_derecha": fmt_v(ct.get("pos")),
                "contacto_golpe_vel_pie_m_s": ct.get("speed", ""),
                "contacto_golpe_limpio": ct.get("clean", ""),
                "contacto_golpe_giro_salida_grados": ct.get("kick_turn", ""),
                "json_toques_cuadro_pie": " ".join("%s%s" % (x[0], x[1]) for x in meta.get("touches", [])),
                "json_dir_out_grados": meta.get("dir_out", ""),
                "json_yaw_end_grados": meta.get("yaw_end", ""),
            }
            row.update(ucs)
            rows.append(row)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    keys = list(rows[0].keys())
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    w = csv.DictWriter(open(out_path, "w", newline="", encoding="utf-8"), fieldnames=keys)
    w.writeheader()
    w.writerows(rows)
    print("inventario:", out_path, len(rows), "filas,", len(keys), "columnas")


if __name__ == "__main__":
    main()

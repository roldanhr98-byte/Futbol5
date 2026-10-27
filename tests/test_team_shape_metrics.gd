extends TestCase
## Medidas objetivas del juego colectivo en un partido de IA contra IA (MatchMetrics): amontonamiento alrededor de la
## pelota, separacion entre companeros, ancho y profundidad del equipo con la pelota, pases, faltas y cambios de
## posesion. Es un INFORME (diagnostico para comparar versiones): solo comprueba que el partido se juega y se mide.
## Duracion por defecto 90 s; PROBE_SECONDS y PROBE_SEEDS la cambian.

func test_team_shape_report() -> void:
	PackLibrary.reload()
	var secs: float = float(OS.get_environment("PROBE_SECONDS")) if OS.get_environment("PROBE_SECONDS") != "" else 90.0
	var seeds: int = int(OS.get_environment("PROBE_SEEDS")) if OS.get_environment("PROBE_SEEDS") != "" else 1
	for seed_i in seeds:
		var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
		m.duration_seconds = 0.0
		m.intro_seconds = 0.0
		m.auto_switch = false
		m.goal_replays = false
		spawn(m)
		await physics_frames(3)
		m.home[0].input_source = AIInput.new(3, 0.6)
		m.home[0].is_human_controlled = false
		m.controlled = null
		for f in m.home + m.away:
			(f.input_source as AIInput).rng.seed = 500 + seed_i * 31 + f.actor_id
		var mm := MatchMetrics.new()
		mm.attach(m.ctx)
		for i in int(secs * 60.0):
			await tree.physics_frame
			if i % 15 == 0 and m.manager.state == MatchManager.State.PLAYING:
				mm.sample(m.ctx)
		note("semilla %d (%.0f s): %s" % [seed_i, secs, MatchMetrics.fmt(mm.report(secs))])
		check(mm.samples > 0, "el partido se juega y se mide (%d muestras)" % mm.samples)
		cleanup()

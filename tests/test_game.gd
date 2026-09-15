extends SceneTree
## Pruebas automáticas sin visor:
##   godot --headless -s tests/test_game.gd
## Verifica física del carro, reglas de puntuación, reciclaje de tramos
## (memoria constante) y recorridos completos con piloto automático.

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  [ok]    ", label)
	else:
		failures += 1
		print("  [FALLA] ", label)


func _run() -> void:
	if "--only=juego" in OS.get_cmdline_user_args():
		await _test_full_game()
		print("\nResultado: %d verificaciones, %d fallas" % [checks, failures])
		quit(1 if failures > 0 else 0)
		return
	print("\n== Física del vehículo ==")
	_test_vehicle()
	print("\n== Reglas de puntuación ==")
	_test_score()
	print("\n== Juego completo (piloto automático) ==")
	await _test_full_game()
	print("\nResultado: %d verificaciones, %d fallas" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_vehicle() -> void:
	var v := PlayerVehicle.new()
	root.add_child(v)
	var dt := 1.0 / 72.0
	var t := 0.0
	while v.speed_kmh() < 50.0 and t < 60.0:
		v.step(dt, 1.0, 0.0, 0.0, false)
		t += dt
	print("    0→50 km/h en %.1f s" % t)
	check(t > 5.0 and t < 14.0, "aceleración progresiva (0→50 km/h entre 5 y 14 s)")
	var z0 := v.position.z
	var bt := 0.0
	while v.speed > 0.01 and bt < 30.0:
		v.step(dt, 0.0, 1.0, 0.0, false)
		bt += dt
	var dist := absf(v.position.z - z0)
	print("    frenado desde 50 km/h: %.1f m en %.1f s" % [dist, bt])
	check(dist > 11.0 and dist < 25.0, "frenado con distancia realista (11–25 m desde 50 km/h)")

	# Respuesta de dirección a baja y alta velocidad
	var low := _yaw_at(v, 20.0)
	var high := _yaw_at(v, 90.0)
	print("    guiñada con volante a tope: %.1f °/s a 20 km/h, %.1f °/s a 90 km/h" % [rad_to_deg(low), rad_to_deg(high)])
	check(absf(high) < absf(low) * 0.8, "el giro pierde respuesta a mayor velocidad")
	var rv := PlayerVehicle.new()
	root.add_child(rv)
	rv.speed = 10.0
	for i in 72:
		rv.step(dt, 0.3, 0.0, 1.0, false)
	check(rv.position.x > 0.0 and rv.rotation.x == 0.0 and rv.rotation.z == 0.0, "dirigir a la derecha mueve a la derecha sin inclinar la cabina")
	v.queue_free()
	rv.queue_free()


func _yaw_at(v: PlayerVehicle, kmh: float) -> float:
	v.reset_to(Vector3.ZERO)
	v.speed = kmh / 3.6
	var dt := 1.0 / 72.0
	for i in 216:
		v.step(dt, 0.25, 0.0, 1.0, false)
		v.speed = kmh / 3.6
	return v.yaw_rate


func _test_score() -> void:
	var s := DriveScore.new()
	check(s.score == 1000.0, "empieza con 1000 puntos")
	s.moto_pass(1.7, 80.0)
	check(s.score == 1025.0 and s.safe_moto_passes == 1, "rebase a 1.7 m y 80 km/h suma 25")
	s.moto_pass(1.6, 60.0)
	check(s.score == 985.0 and s.close_moto_passes == 1, "rebase a 1.6 m resta 40 (pegao)")
	s.moto_pass(2.5, 88.0)
	check(s.score == 985.0 and s.fast_moto_passes == 1, "rebase con espacio pero a 88 km/h no suma")
	var before := s.score
	for i in 720:
		s.update(1.0 / 72.0, 100.0, 0.3, false, false, 99.0)
	check(s.score < before - 4.0 and s.risk_seconds > 9.9, "exceso de velocidad resta y acumula segundos de riesgo")
	before = s.score
	for i in 72:
		s.update(1.0 / 72.0, 50.0, 0.2, true, false, 99.0)
	check(s.score <= before - 17.0, "contravía resta al entrar y por segundo")
	before = s.score
	for i in 72:
		s.update(1.0 / 72.0, 50.0, 0.2, false, true, 99.0)
	check(s.score <= before - 22.0, "salirse de la calzada resta")
	before = s.score
	s.crash(false)
	check(s.score == before - 150.0 and s.crashes == 1, "chocar resta 150")
	var s2 := DriveScore.new()
	for i in 72 * 21:
		s2.update(1.0 / 72.0, 60.0, 0.2, false, false, 99.0)
	check(s2.score == 1005.0, "20 s bajo 80 km/h suma 5")
	s2.tramo_complete("Av. Independencia")
	check(s2.score == 1055.0, "completar tramo suma 50")
	s2.early_brake()
	check(s2.score == 1070.0, "frenar antes de ser obligado suma 15")
	var sum := s2.summary()
	check(sum.has("km_recorridos") and sum.has("rebases_seguros_motoconchos") and sum.has("velocidad_maxima_kmh") and sum.has("segundos_conducta_riesgo"), "resumen con cifras citables")


func _test_full_game() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: Node3D = scene.instantiate()
	game.args = {"test": true}
	root.add_child(game)
	var frames := 0
	while (game.state != 1 or not game.road.is_loaded) and frames < 2000:
		await process_frame
		frames += 1
	check(game.state == 1, "carga la ciudad y llega al menú (%d frames)" % frames)
	# Evitar que el _ready arranque solo: tomamos el control
	game.autopilot = Autopilot.new()
	game.menu.route = 1
	game._start_run()
	check(game.state == 2, "arranca el recorrido")

	var dt := 1.0 / 72.0
	var node_counts := []
	var max_agents := 0
	var max_active_segments := 0
	var passes := 0
	var km_marks := [1.0, 3.0, 6.0]
	game.score.event.connect(func(t, _k, _p): if t.begins_with("Rebase seguro"): passes += 1)
	var steps := 0
	var start_nodes := 0
	while game.state == 2 and steps < 72 * 60 * 9:
		game.sim_step(dt)
		steps += 1
		max_agents = maxi(max_agents, game.traffic.agents.size())
		max_active_segments = maxi(max_active_segments, game.road.active_segment_count())
		if steps == 72 * 30:
			start_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		if steps % (72 * 60) == 0:
			node_counts.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			print("    minuto %d: %.2f km, %d pts, agentes=%d, nodos=%d, z=%.1f, shift=%.0f" % [steps / (72 * 60), game.score.distance_m / 1000.0, game.score.score, game.traffic.agents.size(), node_counts[-1], game.vehicle.position.z, game.road.shift_total])
	var sm: Dictionary = game.score.summary()
	print("    resumen prudente: ", JSON.stringify(sm))
	check(game.score.distance_m > 4000.0, "recorre más de 4 km en 9 minutos simulados")
	check(max_active_segments <= RoadManager.POOL_SIZE, "tramos activos nunca pasan del pool (%d ≤ %d)" % [max_active_segments, RoadManager.POOL_SIZE])
	check(node_counts.size() > 2 and node_counts.max() == node_counts.min() and node_counts[0] == start_nodes, "cantidad de nodos constante (sin fugas): %s" % str(node_counts))
	check(absf(game.vehicle.position.z) <= RoadManager.REBASE + 1.0, "rebase mantiene coordenadas pequeñas (z=%.1f)" % game.vehicle.position.z)
	check(max_agents >= 12 and max_agents <= 36, "tráfico vivo y acotado (máx %d agentes)" % max_agents)
	check(game.score.safe_moto_passes + game.score.close_moto_passes + game.score.fast_moto_passes > 0, "se miden rebases a motoconchos")
	check(game.score.score > 700.0, "el piloto prudente conserva sus puntos (%d)" % roundi(game.score.score))

	# Conductor agresivo: las penalizaciones deben dispararse
	game._end_run("prueba")
	game.autopilot = Autopilot.new()
	game.autopilot.aggressive = true
	game._start_run()
	steps = 0
	while game.state == 2 and steps < 72 * 150:
		game.sim_step(dt)
		steps += 1
	var sa: Dictionary = game.score.summary()
	print("    resumen agresivo: ", JSON.stringify(sa))
	check(float(sa["segundos_exceso_velocidad"]) > 3.0, "el agresivo acumula exceso de velocidad (%.1f s)" % float(sa["segundos_exceso_velocidad"]))
	check(game.score.score < 1000.0, "el agresivo pierde puntos (%d)" % roundi(game.score.score))
	check(int(sa["velocidad_maxima_kmh"]) > 90, "velocidad máxima registrada (%d km/h)" % int(sa["velocidad_maxima_kmh"]))

	# Ruta corta: 4 tramos terminan el recorrido
	if game.state == 2:
		game._end_run("prueba")
	game.autopilot = Autopilot.new()
	game.menu.route = 0
	game._start_run()
	steps = 0
	while game.state == 2 and steps < 72 * 60 * 6:
		game.sim_step(dt)
		steps += 1
	check(game.state == 4 and game.score.tramos == 4, "la ruta corta termina tras 4 tramos (%d tramos, %.2f km)" % [game.score.tramos, game.score.distance_m / 1000.0])
	game.queue_free()
	await process_frame

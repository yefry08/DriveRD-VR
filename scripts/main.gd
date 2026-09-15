extends Node3D
## DriveRD VR — orquestador del juego.
##
## Estados: CARGANDO → MENÚ → MANEJANDO ⇄ PAUSA → RESUMEN → (MENÚ | MANEJANDO)
##
## Argumentos de línea de comando (después de `--`), para pruebas sin visor:
##   --autopilot            maneja solo al terminar de cargar
##   --aggressive           el piloto automático maneja mal a propósito
##   --duration=SEGUNDOS    termina el recorrido tras ese tiempo simulado
##   --quit                 cierra el juego al mostrar el resumen
##   --shots=CARPETA        guarda capturas de pantalla (no funciona en --headless)
##   --scheme=volante       arranca con el volante virtual

enum State { LOADING, MENU, DRIVING, PAUSED, SUMMARY }

const L = preload("res://scripts/road_layout.gd")
const ROUTE_TRAMOS := 4

var state: int = State.LOADING
var road: RoadManager
var traffic: TrafficManager
var vehicle: PlayerVehicle
var cabin: Cabin
var rig: XRRig
var vignette: ComfortVignette
var panel: UIPanel3D
var menu: MenuUI
var score: DriveScore
var governor: PerformanceGovernor
var env: Environment
var sun: DirectionalLight3D
var autopilot: Autopilot

var engine_player: AudioStreamPlayer
var sfx_good: AudioStreamPlayer
var sfx_bad: AudioStreamPlayer
var sfx_crash: AudioStreamPlayer

var args := {}
var sim_time := 0.0
var run_start_s := 0.0
var _last_s := 0.0
var _crash_timer := 0.0
var _crash_reposition := false
var _stick_cooldown := 0.0
var _speeding_light := false
var _forced_timer := 0.0
var _event_log: Array = []
var _shots_taken := {}
var _time := 0.0


func _ready() -> void:
	_parse_args()
	if args.has("shots") and DisplayServer.get_name() != "headless":
		# Windows no dibuja ventanas tapadas: para las capturas de prueba, siempre al frente
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_build_environment()

	road = RoadManager.new()
	road.name = "Avenida"
	add_child(road)

	vehicle = PlayerVehicle.new()
	vehicle.name = "CarroJugador"
	add_child(vehicle)
	cabin = Cabin.new()
	vehicle.add_child(cabin)
	cabin.build(vehicle)

	rig = XRRig.new()
	vehicle.add_child(rig)
	rig.setup(cabin)
	vignette = ComfortVignette.new()
	vignette.name = "Vineta"
	rig.camera.add_child(vignette)

	traffic = TrafficManager.new()
	traffic.name = "Trafico"
	add_child(traffic)
	traffic.setup(road, vehicle, AudioKit.moto_loop())

	score = DriveScore.new()
	score.event.connect(_on_score_event)
	traffic.moto_pass.connect(score.moto_pass)
	traffic.collided.connect(_on_collision)
	traffic.pedestrian_yielded.connect(score.pedestrian_yield)
	traffic.pedestrian_near_miss.connect(score.pedestrian_near_miss)
	traffic.lead_braked_early.connect(score.early_brake)
	traffic.lead_forced_brake.connect(_on_forced_brake)

	menu = MenuUI.new()
	panel = UIPanel3D.new()
	panel.name = "PanelFlotante"
	vehicle.add_child(panel)
	panel.setup(Vector2(1.6, 1.0), Vector2i(MenuUI.W, MenuUI.H), menu)
	panel.position = Cabin.EYE + Vector3(0.0, 0.08, -1.9)

	menu.start_pressed.connect(_start_run)
	menu.resume_pressed.connect(_resume)
	menu.recenter_pressed.connect(_recenter)
	menu.end_pressed.connect(func(): _end_run("Terminado por el conductor"))
	menu.menu_pressed.connect(_enter_menu)
	rig.recenter_requested.connect(_recenter)
	rig.menu_pressed.connect(_toggle_pause)
	rig.select_pressed.connect(_on_select)

	governor = PerformanceGovernor.new()
	governor.level_changed.connect(_apply_quality)
	if not rig.xr_active:
		# En escritorio el objetivo es 60 fps; en el visor, la tasa del visor (72 Hz)
		governor.budget = 1.0 / 60.0
	_apply_quality(0)

	_build_audio()

	if args.has("scheme") and args["scheme"] == "volante":
		menu.scheme = 1
	# Arranca parado justo antes del pórtico de la Av. Independencia
	_place_vehicle_at(L.SEG_LEN * L.TRAMO_SEGMENTS * 4 - 60.0, L.LANE_RIGHT)
	vignette.set_fade_now(1.0)

	await road.generate()
	road.update_visible(road.road_s(vehicle.position.z))
	traffic.populate_initial()
	_enter_menu()
	if args.has("autopilot"):
		autopilot = Autopilot.new()
		autopilot.aggressive = args.has("aggressive")
		await get_tree().create_timer(1.5).timeout
		await _shot("01_menu")
		_start_run()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var parts := s.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.47, 0.85)
	sky_mat.sky_horizon_color = Color(0.72, 0.82, 0.92)
	sky_mat.ground_horizon_color = Color(0.72, 0.82, 0.92)
	sky_mat.ground_bottom_color = Color(0.35, 0.33, 0.3)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.68, 0.72)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.72, 0.8, 0.88)
	env.fog_depth_begin = 160.0
	env.fog_depth_end = 480.0
	env.fog_depth_curve = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(35), 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)


func _build_audio() -> void:
	engine_player = AudioStreamPlayer.new()
	engine_player.stream = AudioKit.engine_loop()
	engine_player.volume_db = -14.0
	add_child(engine_player)
	sfx_good = AudioStreamPlayer.new()
	sfx_good.stream = AudioKit.chime_good()
	sfx_good.volume_db = -8.0
	add_child(sfx_good)
	sfx_bad = AudioStreamPlayer.new()
	sfx_bad.stream = AudioKit.buzz_bad()
	sfx_bad.volume_db = -8.0
	add_child(sfx_bad)
	sfx_crash = AudioStreamPlayer.new()
	sfx_crash.stream = AudioKit.crash_sound()
	sfx_crash.volume_db = -3.0
	add_child(sfx_crash)


# ------------------------------------------------------------------ estados

func _enter_menu() -> void:
	state = State.MENU
	menu.show_page("menu")
	panel.visible = true
	vehicle.speed = 0.0
	vignette.fade_to(0.0, 1.5)
	engine_player.play()


func _start_run() -> void:
	vignette.fade_to(1.0, 6.0)
	if not (args.has("autopilot") or args.has("test")):
		await get_tree().create_timer(0.2).timeout
	rig.scheme = menu.scheme
	vignette.strength = [0.6, 1.0, 1.45][menu.vignette]
	score.reset()
	_event_log.clear()
	sim_time = 0.0
	# Siempre se empieza 60 m antes del inicio de un tramo, frente al pórtico.
	var tramo_len := L.SEG_LEN * L.TRAMO_SEGMENTS
	var s := road.road_s(vehicle.position.z)
	var next_start := ceilf((s + 80.0) / tramo_len) * tramo_len
	# Que la ruta corta empiece en la Av. Independencia
	while L.avenue_for_segment(roundi(next_start / L.SEG_LEN)) != 0:
		next_start += tramo_len
	_place_vehicle_at(next_start - 60.0, L.LANE_RIGHT)
	run_start_s = next_start
	_last_s = road.road_s(vehicle.position.z)
	road.update_visible(_last_s)
	traffic.populate_initial()
	panel.visible = false
	rig.show_laser(Vector3.ZERO, Vector3.ZERO, false)
	cabin.dashboard.show_message("¡Dale! Maneja con cuidado", "info")
	state = State.DRIVING
	governor.warmup()
	vignette.fade_to(0.0, 2.5)
	print("[Juego] recorrido iniciado · control=%s · ruta=%s" % [["mandos", "volante"][rig.scheme], ["4 tramos", "libre"][menu.route]])


func _toggle_pause() -> void:
	if state == State.DRIVING:
		state = State.PAUSED
		menu.show_page("pausa")
		panel.visible = true
		vignette.fade_to(0.55, 5.0)
	elif state == State.PAUSED:
		_resume()


func _resume() -> void:
	if state != State.PAUSED:
		return
	panel.visible = false
	rig.show_laser(Vector3.ZERO, Vector3.ZERO, false)
	vignette.fade_to(0.0, 4.0)
	state = State.DRIVING


func _end_run(reason: String) -> void:
	if state != State.DRIVING and state != State.PAUSED:
		return
	state = State.SUMMARY
	var data := score.summary()
	data["motivo"] = reason
	data["control"] = ["mandos", "volante"][rig.scheme]
	data["nivel_calidad_max"] = governor.max_level_reached
	data["xr"] = rig.xr_active
	menu.fill_summary(data, score.rating(), reason)
	menu.show_page("resumen")
	panel.visible = true
	vignette.fade_to(0.35, 3.0)
	_save_summary(data)
	print("[Resumen] ", JSON.stringify(data))
	if args.has("quit"):
		await get_tree().create_timer(0.6).timeout
		_shot("09_resumen")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


func _save_summary(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://resumenes")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open("user://resumenes/recorrido_%s.json" % stamp, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"resumen": data, "eventos": _event_log}, "  "))


func _recenter() -> void:
	vignette.set_fade_now(0.9)
	rig.recenter()
	vignette.fade_to(0.0 if state == State.DRIVING or state == State.MENU else 0.35, 3.0)


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	_time += delta
	if state == State.DRIVING:
		governor.sample(delta)
	match state:
		State.DRIVING:
			var t0 := Time.get_ticks_usec()
			sim_step(dt)
			_perf_sim_us += Time.get_ticks_usec() - t0
		State.MENU, State.SUMMARY:
			_idle_world(dt)
			_update_pointer(dt)
		State.PAUSED:
			_update_pointer(dt)
			vignette.update_motion(dt, 0.0, 0.0, false)
		State.LOADING:
			vignette.update_motion(dt, 0.0, 0.0, false)
	_update_audio()
	if args.has("perf"):
		_perf_log(delta)


var _perf_sim_us := 0
var _perf_frames := 0
var _perf_time := 0.0
var _perf_proc := 0.0

func _perf_log(delta: float) -> void:
	_perf_frames += 1
	_perf_time += delta
	_perf_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	if _perf_time >= 5.0:
		print("[Perf] fps=%.1f proceso=%.2f ms sim=%.2f ms draw_calls=%d primitivas=%d agentes=%d nivel=%d" % [
			_perf_frames / _perf_time, _perf_proc / _perf_frames * 1000.0, _perf_sim_us / 1000.0 / _perf_frames,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			traffic.agents.size(), governor.level])
		_perf_frames = 0
		_perf_time = 0.0
		_perf_proc = 0.0
		_perf_sim_us = 0


## Un paso de simulación mientras se maneja.
func sim_step(dt: float) -> void:
	sim_time += dt
	var inp: Array
	if autopilot:
		inp = autopilot.compute(dt, vehicle, traffic)
	else:
		inp = rig.drive_input(dt, vehicle.speed)
	if _crash_timer > 0.0:
		_crash_timer -= dt
		inp = [0.0, 1.0, 0.0, false]
		if _crash_timer <= 0.4 and _crash_reposition:
			_crash_reposition = false
			vehicle.position.x = L.LANE_RIGHT
			vehicle.heading = 0.0
			vehicle.rotation.y = 0.0
			traffic.clear_around(vehicle.position, 14.0)
		if _crash_timer <= 0.0:
			vignette.fade_to(0.0, 2.5)

	vehicle.step(dt, inp[0], inp[1], inp[2], inp[3])
	_rebase_if_needed()
	var s := road.road_s(vehicle.position.z)
	var ds := maxf(0.0, s - _last_s)
	_last_s = s
	road.update_visible(s)
	traffic.step(dt, _crash_timer <= 0.0)
	if _crash_timer <= 0.0 and traffic.check_parked_collision():
		_on_collision(TrafficAgent.Kind.CAR, false)

	var x := vehicle.position.x
	var in_opposite := x - PlayerVehicle.HALF_WIDTH < -0.3
	var offroad := x + PlayerVehicle.HALF_WIDTH > L.EDGE + 0.5 or x - PlayerVehicle.HALF_WIDTH < -L.EDGE - 0.5
	if absf(x) > L.CURB_OUT - 0.3 and _crash_timer <= 0.0:
		_on_collision(-1, false)
	var kmh := vehicle.speed_kmh()
	score.update(dt, kmh, ds, in_opposite, offroad, traffic.headway_seconds())
	_forced_timer = maxf(0.0, _forced_timer - dt)

	# Tramos completados
	var done := floori(maxf(0.0, s - run_start_s) / (L.SEG_LEN * L.TRAMO_SEGMENTS))
	if s >= run_start_s and done > score.tramos:
		score.tramo_complete(road.avenue_name_at(s - 1.0))
		if menu.route == 0 and score.tramos >= ROUTE_TRAMOS:
			_end_run("Ruta completada")
			return
	if score.score <= 0.0:
		_end_run("Te quedaste sin puntos")
		return
	if args.has("duration") and sim_time >= float(args["duration"]):
		_end_run("Fin de la prueba automática")
		return

	# Tablero
	var d := cabin.dashboard
	d.speed_kmh = kmh
	d.rpm = vehicle.rpm
	d.gear = vehicle.gear
	d.defense = score.defense
	d.score = roundi(score.score)
	d.avenue = road.avenue_name_at(s)
	d.lights = {
		"velocidad": kmh > DriveScore.SPEEDING_KMH,
		"distancia": traffic.headway_seconds() < DriveScore.TAILGATE_HEADWAY_S and kmh > 20.0 or _forced_timer > 0.0,
		"contravia": in_opposite,
		"via": offroad,
		"moto": traffic.blind_spot_right or traffic.blind_spot_left,
		"peaton": traffic.pedestrian_in_path,
	}
	cabin.update_dashboard(dt)
	cabin.set_wheel_angle(vehicle.steer * XRRig.WHEEL_MAX if rig.scheme == XRRig.Scheme.MANDOS or autopilot else rig.wheel_angle)
	cabin.update_mirrors(vehicle, traffic.blind_spot_left, traffic.blind_spot_right, _time)
	vignette.update_motion(dt, vehicle.accel, vehicle.yaw_rate, true)

	if args.has("shots"):
		for t in [8.0, 25.0, 45.0, 70.0]:
			if sim_time >= t and not _shots_taken.has(t):
				_shots_taken[t] = true
				_shot("%02d_manejando_%ds" % [2 + [8.0, 25.0, 45.0, 70.0].find(t), int(t)])


## El mundo sigue vivo detrás del menú: tráfico en movimiento, carro detenido.
func _idle_world(dt: float) -> void:
	if not road.is_loaded:
		return
	if vehicle.speed > 0.0:
		vehicle.step(dt, 0.0, 0.5, 0.0, false)
	road.update_visible(road.road_s(vehicle.position.z))
	traffic.step(dt, false)
	cabin.update_mirrors(vehicle, false, false, _time)
	cabin.update_dashboard(dt)
	vignette.update_motion(dt, vehicle.accel, vehicle.yaw_rate, vehicle.speed > 0.1)


func _update_pointer(dt: float) -> void:
	var ray := rig.pointer_ray()
	var hit = panel.pointer_move(ray[0], ray[1])
	if rig.xr_active:
		rig.show_laser(ray[0], hit if hit != null else ray[0] + ray[1] * 2.5, true)
		# Navegación alternativa con joystick
		_stick_cooldown = maxf(0.0, _stick_cooldown - dt)
		var y := rig.left.get_vector2("primary").y + rig.right.get_vector2("primary").y
		if absf(y) > 0.6 and _stick_cooldown <= 0.0:
			menu.move_focus(-1 if y > 0.0 else 1)
			_stick_cooldown = 0.3
	else:
		rig.show_laser(ray[0], hit if hit != null else ray[0], hit != null)


func _on_select() -> void:
	if state == State.DRIVING:
		return
	if not panel.pointer_click():
		menu.press_focused()


func _update_audio() -> void:
	if engine_player.playing:
		engine_player.pitch_scale = 0.55 + vehicle.rpm / 7000.0 * 1.35


func _rebase_if_needed() -> void:
	while vehicle.position.z < -RoadManager.REBASE:
		vehicle.position.z += RoadManager.REBASE
		traffic.apply_rebase(RoadManager.REBASE)
		road.apply_rebase(RoadManager.REBASE)


func _place_vehicle_at(s: float, x: float) -> void:
	vehicle.reset_to(Vector3(x, 0, road.world_z(s)))
	_rebase_if_needed()


# ------------------------------------------------------------------ eventos

func _on_score_event(text: String, kind: String, points: int) -> void:
	var shown := text if points == 0 else "%s  %+d" % [text, points]
	cabin.dashboard.show_message(shown, kind)
	_event_log.append({"t": snappedf(sim_time, 0.1), "km": snappedf(score.distance_m / 1000.0, 0.01), "evento": text, "puntos": points})
	print("[Evento %.1fs] %s" % [sim_time, shown])
	if kind == "bien":
		sfx_good.play()
	elif kind == "mal":
		sfx_bad.play()
		rig.haptic(0.5, 0.15)


func _on_forced_brake() -> void:
	_forced_timer = 2.0
	score.forced_brake()


## kind = TrafficAgent.Kind o -1 para la acera.
func _on_collision(kind: int, oncoming: bool) -> void:
	if _crash_timer > 0.0:
		return
	score.crash(kind == TrafficAgent.Kind.PEDESTRIAN)
	sfx_crash.play()
	rig.haptic(1.0, 0.4)
	# Fundido inmediato: el cuerpo no debe "ver" la parada en seco
	vignette.fade_to(0.85, 12.0)
	vehicle.crash_stop()
	_crash_timer = 1.4
	_crash_reposition = kind == -1 or oncoming or vehicle.position.x < 0.5
	var what: String = "acera" if kind == -1 else ["carro", "guagua", "motoconcho", "peatón"][kind]
	print("[Choque] contra %s%s · %s" % [what, " (sentido contrario)" if oncoming else "", traffic.last_collision_info])


func _apply_quality(level: int) -> void:
	var q := PerformanceGovernor.settings(level)
	cabin.mirror_update_every = q["mirror_every"]
	road.segments_ahead = q["segments_ahead"]
	traffic.density = q["traffic"]
	env.fog_depth_end = q["fog_end"]
	env.fog_depth_begin = q["fog_end"] * 0.35
	rig.camera.far = q["far"]


func _shot(file_name: String) -> void:
	if not args.has("shots") or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var dir: String = args["shots"]
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, file_name])
	print("[Captura] %s/%s.png" % [dir, file_name])

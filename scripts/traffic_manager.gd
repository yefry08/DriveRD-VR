class_name TrafficManager
extends Node3D
## Tráfico de la avenida y los riesgos que enseña el juego.
##
## Motoconchos: no respetan carril, cambian de trayectoria cada 0.7–2 s sin
##   señalizar y aparecen por el punto ciego derecho. Se mide la separación
##   lateral real (borde a borde) cuando el jugador los rebasa.
## Guaguas: frenan sin aviso para recoger pasajeros; la luz de freno se enciende
##   apenas un instante antes.
## Peatones: cruzan fuera del paso peatonal saliendo de entre carros estacionados.
## Sentido contrario: castiga invadir el carril opuesto.

signal moto_pass(gap_m: float, player_kmh: float)
signal collided(kind: int, oncoming: bool)
signal pedestrian_yielded
signal pedestrian_near_miss(gap_m: float)
signal lead_braked_early
signal lead_forced_brake

const Kind = preload("res://scripts/traffic_agent.gd").Kind
const L = preload("res://scripts/road_layout.gd")
const PV = preload("res://scripts/player_vehicle.gd")

var road: RoadManager
var vehicle: PlayerVehicle
var agents: Array[TrafficAgent] = []
var density := 1.0
var rng := RandomNumberGenerator.new()
var moto_stream: AudioStream

var _pools := {}
var _car_meshes: Array[ArrayMesh] = []
var _guagua_meshes: Array[ArrayMesh] = []
var _moto_meshes: Array[ArrayMesh] = []
var _ped_meshes: Array[ArrayMesh] = []
var _leg_mesh: ArrayMesh
var _brake_car: ArrayMesh
var _brake_guagua: ArrayMesh
var _spawn_timer := 0.0
var _ped_timer := 14.0
var _collision_cooldown := 0.0
var _inv := Transform3D.IDENTITY

# Resultados por frame que consulta el juego
var blind_spot_right := false
var blind_spot_left := false
var lead_agent: TrafficAgent = null
var lead_gap := 999.0
var lead_closing := 0.0
var pedestrian_in_path := false
var last_collision_info := ""


func setup(p_road: RoadManager, p_vehicle: PlayerVehicle, p_moto_stream: AudioStream) -> void:
	road = p_road
	vehicle = p_vehicle
	moto_stream = p_moto_stream
	rng.randomize()
	_build_meshes()
	_pools[Kind.CAR] = _make_pool(Kind.CAR, 18)
	_pools[Kind.GUAGUA] = _make_pool(Kind.GUAGUA, 6)
	_pools[Kind.MOTO] = _make_pool(Kind.MOTO, 9)
	_pools[Kind.PEDESTRIAN] = _make_pool(Kind.PEDESTRIAN, 3)


func _build_meshes() -> void:
	var mat := MeshKit.vertex_color_material()
	for c in VehicleMeshes.CAR_COLORS:
		var k := MeshKit.new()
		VehicleMeshes.add_car(k, Transform3D.IDENTITY, c)
		_car_meshes.append(k.commit(mat))
	for i in VehicleMeshes.GUAGUA_SCHEMES.size():
		var k := MeshKit.new()
		VehicleMeshes.add_guagua(k, Transform3D.IDENTITY, i)
		_guagua_meshes.append(k.commit(mat))
	for i in 4:
		var k := MeshKit.new()
		VehicleMeshes.add_moto(k, Transform3D.IDENTITY, i)
		_moto_meshes.append(k.commit(mat))
	for i in 4:
		var k := MeshKit.new()
		VehicleMeshes.add_pedestrian_body(k, i)
		_ped_meshes.append(k.commit(mat))
	var lk := MeshKit.new()
	VehicleMeshes.add_pedestrian_leg(lk)
	_leg_mesh = lk.commit(mat)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.08, 0.05)
	var bk := MeshKit.new()
	for sx in [-0.62, 0.62]:
		bk.box(Transform3D(Basis.IDENTITY, Vector3(sx, 0.8, VehicleMeshes.CAR_LEN * 0.5 + 0.035)), Vector3(0.4, 0.17, 0.02), Color.WHITE, MeshKit.F_POS_Z)
	bk.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.43, 1.1)), Vector3(0.5, 0.05, 0.02), Color.WHITE, MeshKit.F_POS_Z)
	_brake_car = bk.commit(glow)
	var gk := MeshKit.new()
	for sx in [-0.8, 0.8]:
		gk.box(Transform3D(Basis.IDENTITY, Vector3(sx, 0.85, VehicleMeshes.GUAGUA_LEN * 0.5 + 0.035)), Vector3(0.36, 0.36, 0.02), Color.WHITE, MeshKit.F_POS_Z)
	gk.box(Transform3D(Basis.IDENTITY, Vector3(0, 2.55, VehicleMeshes.GUAGUA_LEN * 0.5 - 0.1)), Vector3(1.4, 0.1, 0.02), Color.WHITE, MeshKit.F_POS_Z)
	_brake_guagua = gk.commit(glow)


func _make_pool(kind: int, count: int) -> Array:
	var arr := []
	for i in count:
		var a := TrafficAgent.new()
		a.kind = kind
		a.name = "%s%d" % [["Carro", "Guagua", "Moto", "Peaton"][kind], i]
		a.mesh_instance = MeshInstance3D.new()
		a.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(a.mesh_instance)
		match kind:
			TrafficAgent.Kind.CAR:
				a.half_len = VehicleMeshes.CAR_LEN * 0.5
				a.half_w = VehicleMeshes.CAR_WIDTH * 0.5
				a.mesh_instance.mesh = _car_meshes[i % _car_meshes.size()]
				a.brake_light = MeshInstance3D.new()
				a.brake_light.mesh = _brake_car
				a.add_child(a.brake_light)
			TrafficAgent.Kind.GUAGUA:
				a.half_len = VehicleMeshes.GUAGUA_LEN * 0.5
				a.half_w = VehicleMeshes.GUAGUA_WIDTH * 0.5
				a.mesh_instance.mesh = _guagua_meshes[i % _guagua_meshes.size()]
				a.brake_light = MeshInstance3D.new()
				a.brake_light.mesh = _brake_guagua
				a.add_child(a.brake_light)
			TrafficAgent.Kind.MOTO:
				a.half_len = VehicleMeshes.MOTO_LEN * 0.5
				a.half_w = VehicleMeshes.MOTO_WIDTH * 0.5
				a.mesh_instance.mesh = _moto_meshes[i % _moto_meshes.size()]
				if moto_stream:
					a.audio = AudioStreamPlayer3D.new()
					a.audio.stream = moto_stream
					a.audio.unit_size = 5.0
					a.audio.max_distance = 70.0
					a.audio.volume_db = -4.0
					a.add_child(a.audio)
			TrafficAgent.Kind.PEDESTRIAN:
				a.half_len = 0.3
				a.half_w = 0.3
				a.mesh_instance.mesh = _ped_meshes[i % _ped_meshes.size()]
				a.leg_l = MeshInstance3D.new()
				(a.leg_l as MeshInstance3D).mesh = _leg_mesh
				a.leg_l.position = Vector3(-0.1, 0.86, 0)
				a.add_child(a.leg_l)
				a.leg_r = MeshInstance3D.new()
				(a.leg_r as MeshInstance3D).mesh = _leg_mesh
				a.leg_r.position = Vector3(0.1, 0.86, 0)
				a.add_child(a.leg_r)
		if a.brake_light:
			a.brake_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.visible = false
		add_child(a)
		arr.append(a)
	return arr


# ---------------------------------------------------------------- aparición

func clear_all() -> void:
	for a: TrafficAgent in agents.duplicate():
		_despawn(a)
	_ped_timer = 12.0
	_spawn_timer = 0.0


## Llena la avenida al empezar el recorrido.
func populate_initial() -> void:
	clear_all()
	var pz := vehicle.position.z
	for i in 5:
		_spawn(Kind.CAR, 1, pz - rng.randf_range(40.0, 320.0), [L.LANE_LEFT, L.LANE_RIGHT][i % 2], rng.randf_range(11.0, 14.5))
	_spawn(Kind.GUAGUA, 1, pz - rng.randf_range(90.0, 140.0), L.LANE_RIGHT, rng.randf_range(10.0, 12.5))
	for i in 3:
		_spawn(Kind.MOTO, 1, pz - rng.randf_range(35.0, 200.0), rng.randf_range(1.0, 6.0), rng.randf_range(8.5, 11.5))
	for i in 6:
		var kind := Kind.GUAGUA if i % 4 == 3 else Kind.CAR
		_spawn(kind, -1, pz - rng.randf_range(20.0, 380.0), [L.ONCOMING_INNER, L.ONCOMING_OUTER][i % 2], rng.randf_range(11.0, 15.0))


func _count(kind: int, dir: int) -> int:
	var n := 0
	for a: TrafficAgent in agents:
		if a.kind == kind and a.dir == dir:
			n += 1
	return n


func _lane_clear(dir: int, x: float, z: float, margin: float) -> bool:
	for a: TrafficAgent in agents:
		if a.dir == dir and a.kind != Kind.PEDESTRIAN and absf(a.position.x - x) < 2.2 and absf(a.position.z - z) < margin:
			return false
	if absf(vehicle.position.x - x) < 2.4 and absf(vehicle.position.z - z) < margin:
		return false
	return true


func _spawn(kind: int, dir: int, z: float, x: float, spd: float) -> TrafficAgent:
	var pool: Array = _pools[kind]
	var a: TrafficAgent = null
	for candidate: TrafficAgent in pool:
		if not candidate.active:
			a = candidate
			break
	if a == null:
		return null
	if kind != Kind.PEDESTRIAN and not _lane_clear(dir, x, z, 10.0 + a.half_len):
		return null
	a.active = true
	a.dir = dir
	a.reset_state()
	a.position = Vector3(x, 0, z)
	a.rotation.y = 0.0 if dir == 1 else PI
	a.speed = spd
	a.desired_speed = spd
	a.target_x = x
	a.lat_speed = rng.randf_range(1.2, 2.4)
	a.visible = true
	if a.audio:
		a.audio.pitch_scale = 0.9 + spd / 30.0
		a.audio.play(rng.randf() * 0.2)
	agents.append(a)
	return a


func _despawn(a: TrafficAgent) -> void:
	a.active = false
	a.visible = false
	a.set_braking(false)
	if a.audio:
		a.audio.stop()
	agents.erase(a)


func _manage_spawns() -> void:
	var pz := vehicle.position.z
	var psp := vehicle.speed
	if _count(Kind.CAR, 1) < roundi(6 * density):
		if rng.randf() < 0.75:
			_spawn(Kind.CAR, 1, pz - rng.randf_range(200.0, 330.0), [L.LANE_LEFT, L.LANE_RIGHT][rng.randi() % 2], rng.randf_range(10.5, 14.5))
		elif psp < 16.0:
			_spawn(Kind.CAR, 1, pz + rng.randf_range(70.0, 90.0), L.LANE_LEFT, rng.randf_range(16.0, 18.5))
	if _count(Kind.GUAGUA, 1) < roundi(2 * density + 0.4):
		_spawn(Kind.GUAGUA, 1, pz - rng.randf_range(180.0, 300.0), L.LANE_RIGHT, rng.randf_range(10.0, 12.5))
	if _count(Kind.MOTO, 1) < roundi(6 * density):
		if rng.randf() < 0.55:
			# Moto lenta adelante: el jugador tendrá que rebasarla
			_spawn(Kind.MOTO, 1, pz - rng.randf_range(120.0, 260.0), rng.randf_range(1.0, 6.0), rng.randf_range(8.0, 11.5))
		else:
			# Moto rápida desde atrás por el punto ciego derecho
			_spawn(Kind.MOTO, 1, pz + rng.randf_range(40.0, 60.0), rng.randf_range(5.7, 6.2), maxf(psp + rng.randf_range(3.5, 6.0), 13.0))
	if _count(Kind.CAR, -1) + _count(Kind.GUAGUA, -1) < roundi(7 * density):
		var kind := Kind.GUAGUA if rng.randf() < 0.25 else Kind.CAR
		_spawn(kind, -1, pz - rng.randf_range(330.0, 420.0), [L.ONCOMING_INNER, L.ONCOMING_OUTER][rng.randi() % 2], rng.randf_range(11.0, 15.5))


func _try_spawn_pedestrian() -> void:
	var ps := road.road_s(vehicle.position.z)
	var t_arrive := rng.randf_range(3.2, 4.8)
	var d := clampf(vehicle.speed * t_arrive, 32.0, 95.0)
	var gaps := road.ped_gaps_between(ps + d - 12.0, ps + d + 12.0)
	if gaps.is_empty():
		return
	# Preferir el lado derecho (el peatón sale justo delante del carril del jugador)
	var right := gaps.filter(func(g: Vector3): return g.x > 0)
	var pick: Vector3 = right[rng.randi() % right.size()] if not right.is_empty() and rng.randf() < 0.75 else gaps[rng.randi() % gaps.size()]
	var a := _spawn(Kind.PEDESTRIAN, 1, pick.z, pick.x, 0.0)
	if a:
		a.ped_dir = -signf(pick.x)
		a.speed = rng.randf_range(1.25, 1.6)
		a.rotation.y = -PI * 0.5 * a.ped_dir
		_ped_timer = rng.randf_range(16.0, 30.0)


# ---------------------------------------------------------------- simulación

func step(dt: float, allow_events := true) -> void:
	_inv = vehicle.global_transform.affine_inverse()
	_collision_cooldown = maxf(0.0, _collision_cooldown - dt)
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.3
		_manage_spawns()
	_ped_timer -= dt
	if _ped_timer <= 0.0 and allow_events:
		_ped_timer = 3.0
		_try_spawn_pedestrian()

	for a: TrafficAgent in agents.duplicate():
		match a.kind:
			TrafficAgent.Kind.PEDESTRIAN:
				_step_pedestrian(a, dt)
			TrafficAgent.Kind.MOTO:
				_step_moto(a, dt)
			_:
				_step_vehicle(a, dt)

	_keep_behind_player()
	_despawn_far()
	_player_relations(dt, allow_events)


## Los vehículos que vienen detrás frenan a tiempo: el juego no castiga al
## jugador por un choque que no provocó.
func _keep_behind_player() -> void:
	for a: TrafficAgent in agents:
		if a.dir != 1 or a.kind == Kind.PEDESTRIAN:
			continue
		var lp := _inv * a.position
		if lp.z <= 0.0 or absf(lp.x) > PV.HALF_WIDTH + a.half_w + 0.6:
			continue
		var min_behind := PV.HALF_LENGTH + a.half_len + 0.8
		if lp.z < min_behind:
			a.position.z += min_behind - lp.z
			a.speed = minf(a.speed, vehicle.speed)
			a.set_braking(true)


func _idm(v: float, v0: float, gap: float, dv: float, a_max := 1.6, headway := 1.3) -> float:
	var b := 2.5
	var s_star := 2.0 + maxf(0.0, v * headway + v * dv / (2.0 * sqrt(a_max * b)))
	var acc := a_max * (1.0 - pow(v / maxf(v0, 0.1), 4.0) - pow(s_star / maxf(gap, 0.1), 2.0))
	return clampf(acc, -8.0, a_max)


## Busca el obstáculo más cercano delante de `a` en su franja lateral.
## Devuelve [gap, velocidad_del_obstáculo_en_el_sentido_de_a].
func _leader(a: TrafficAgent, band_extra := 0.35, at_x := NAN) -> Array:
	var ax: float = a.position.x if is_nan(at_x) else at_x
	var best_gap := 1.0e6
	var best_speed := 0.0
	for b: TrafficAgent in agents:
		if b == a:
			continue
		var ahead_quick := (a.position.z - b.position.z) * a.dir
		if ahead_quick <= 0.0 or ahead_quick - a.half_len - b.half_len > best_gap:
			continue
		var lat := absf(b.position.x - ax)
		if lat > a.half_w + b.half_w + band_extra:
			continue
		var ahead := (a.position.z - b.position.z) * a.dir
		if ahead <= 0.0:
			continue
		var gap := ahead - a.half_len - b.half_len
		if gap < best_gap:
			best_gap = gap
			best_speed = 0.0 if b.kind == Kind.PEDESTRIAN else b.speed * float(b.dir * a.dir)
	# El jugador también es un obstáculo
	var plat := absf(vehicle.position.x - ax)
	if plat < a.half_w + PV.HALF_WIDTH + band_extra:
		var ahead_p := (a.position.z - vehicle.position.z) * a.dir
		if ahead_p > 0.0:
			var gap_p := ahead_p - a.half_len - PV.HALF_LENGTH
			if gap_p < best_gap:
				best_gap = gap_p
				best_speed = vehicle.speed * (1.0 if a.dir == 1 else -1.0)
	return [best_gap, best_speed]


func _step_vehicle(a: TrafficAgent, dt: float) -> void:
	var lead := _leader(a)
	var acc := _idm(a.speed, a.desired_speed, lead[0], a.speed - lead[1])
	var signal_brake := false
	if a.kind == Kind.GUAGUA and a.dir == 1:
		acc = _guagua_stops(a, dt, acc)
		signal_brake = a.stop_state in [TrafficAgent.Stop.SIGNAL, TrafficAgent.Stop.BRAKING, TrafficAgent.Stop.STOPPED]
	a.speed = maxf(0.0, a.speed + acc * dt)
	a.last_accel = acc
	a.set_braking(signal_brake or acc < -1.2 or (a.speed < 0.3 and lead[0] < 8.0))
	a.position.z -= a.dir * a.speed * dt


## Guagua: frena sin aviso para recoger pasajeros.
func _guagua_stops(a: TrafficAgent, dt: float, idm_acc: float) -> float:
	var S := TrafficAgent.Stop
	a.stop_timer -= dt
	match a.stop_state:
		TrafficAgent.Stop.CRUISE:
			var behind := a.position.z - vehicle.position.z   # negativo si la guagua va delante
			var player_close := behind < -8.0 and behind > -60.0 and absf(vehicle.position.x - a.position.x) < 2.2
			if a.stop_timer <= 0.0 and (player_close or rng.randf() < 0.002):
				a.stop_state = S.SIGNAL
				a.stop_timer = rng.randf_range(0.45, 0.8)   # la luz de freno se enciende apenas un instante antes
			return idm_acc
		TrafficAgent.Stop.SIGNAL:
			if a.stop_timer <= 0.0:
				a.stop_state = S.BRAKING
			return minf(idm_acc, -0.3)
		TrafficAgent.Stop.BRAKING:
			a.position.x = move_toward(a.position.x, L.LANE_RIGHT + 0.9, dt * 0.6)
			if a.speed <= 0.05:
				a.stop_state = S.STOPPED
				a.stop_timer = rng.randf_range(3.0, 6.0)
			return minf(idm_acc, -4.5)
		TrafficAgent.Stop.STOPPED:
			if a.stop_timer <= 0.0:
				a.stop_state = S.GO
				a.stop_timer = 2.5
			return -a.speed / maxf(dt, 0.001)
		TrafficAgent.Stop.GO:
			a.position.x = move_toward(a.position.x, L.LANE_RIGHT, dt * 0.5)
			if a.stop_timer <= 0.0:
				a.stop_state = S.CRUISE
				a.stop_timer = rng.randf_range(14.0, 28.0)
			return minf(idm_acc, 1.0)
	return idm_acc


const MOTO_LANE_POSITIONS := [0.75, 1.65, 2.5, 3.3, 4.1, 4.95, 5.9]

## Motoconcho: zigzaguea entre carriles y vehículos sin señalizar.
func _step_moto(a: TrafficAgent, dt: float) -> void:
	var lead := _leader(a, 0.15)
	a.retarget_timer -= dt
	var blocked: bool = lead[0] < 12.0 and lead[1] < a.speed
	if a.retarget_timer <= 0.0 or (blocked and a.retarget_timer < 0.5):
		a.retarget_timer = rng.randf_range(0.7, 2.0)
		a.target_x = _pick_moto_x(a)
	var acc := _idm(a.speed, a.desired_speed, lead[0], a.speed - lead[1], 2.4, 0.8)
	a.speed = maxf(0.0, a.speed + acc * dt)

	var old_x := a.position.x
	var new_x := move_toward(old_x, a.target_x, a.lat_speed * dt)
	# Evita chocar al jugador por su cuenta: si el jugador lo encierra, la culpa es del jugador.
	var long := absf(a.position.z - vehicle.position.z)
	if long < PV.HALF_LENGTH + a.half_len + 0.8:
		var old_gap := absf(old_x - vehicle.position.x) - PV.HALF_WIDTH - a.half_w
		var new_gap := absf(new_x - vehicle.position.x) - PV.HALF_WIDTH - a.half_w
		if new_gap < 0.35 and new_gap < old_gap:
			new_x = old_x
			a.target_x = old_x + signf(old_x - vehicle.position.x) * 0.8
	a.lat_vel = (new_x - old_x) / maxf(dt, 0.0001)
	a.position.x = clampf(new_x, 0.5, 6.3)
	a.position.z -= a.speed * dt
	a.rotation = Vector3(0, atan2(-a.lat_vel, maxf(a.speed, 1.0)) * 0.8, clampf(-a.lat_vel * 0.08, -0.25, 0.25))
	if a.audio:
		a.audio.pitch_scale = 0.8 + a.speed / 25.0


func _pick_moto_x(a: TrafficAgent) -> float:
	var best_x: float = a.position.x
	var best_score := -1.0e9
	for x: float in MOTO_LANE_POSITIONS:
		var lead := _leader(a, 0.1, x)
		var score: float = minf(lead[0], 60.0) + rng.randf_range(0.0, 25.0) - absf(x - a.position.x) * 1.5
		if score > best_score:
			best_score = score
			best_x = x
	return best_x + rng.randf_range(-0.25, 0.25)


func _step_pedestrian(a: TrafficAgent, dt: float) -> void:
	var P := TrafficAgent.Ped
	var lp := _inv * a.position
	match a.ped_state:
		TrafficAgent.Ped.WAITING:
			a.ped_timer -= dt
			if a.ped_timer <= 0.0:
				a.ped_state = P.WALKING
		TrafficAgent.Ped.WALKING, TrafficAgent.Ped.HESITATING:
			var next_x := a.position.x + a.ped_dir * a.speed * dt
			# Duda solo si todavía no ha entrado al carril del jugador y el carro ya está encima
			var t_arrive := (-lp.z - PV.HALF_LENGTH) / maxf(vehicle.speed, 0.1)
			var entering := absf(next_x - vehicle.position.x) < PV.HALF_WIDTH + 1.2 and absf(a.position.x - vehicle.position.x) >= PV.HALF_WIDTH + 1.0
			if entering and lp.z < 0.0 and t_arrive < 1.1 and vehicle.speed > 3.0:
				a.ped_state = P.HESITATING
			elif a.ped_state == P.HESITATING and (lp.z > 1.0 or vehicle.speed < 1.0):
				a.ped_state = P.WALKING
			# Nunca camina contra la carrocería del jugador (si el carro está ahí, espera)
			var next_lp := _inv * Vector3(next_x, 0.0, a.position.z)
			var blocked_by_car := absf(next_lp.x) < PV.HALF_WIDTH + a.half_w + 0.25 and absf(next_lp.z) < PV.HALF_LENGTH + a.half_len + 0.25
			if a.ped_state == P.WALKING and not blocked_by_car:
				a.position.x = next_x
				a.walk_phase += dt * a.speed * 4.2
			if absf(a.position.x) > L.SIDEWALK_OUT - 0.5 and signf(a.position.x) == a.ped_dir:
				a.ped_state = P.DONE
		TrafficAgent.Ped.DONE:
			_despawn(a)
			return
	var swing := sin(a.walk_phase) * 0.5 if a.ped_state == P.WALKING else 0.0
	a.leg_l.rotation.x = swing
	a.leg_r.rotation.x = -swing


func _despawn_far() -> void:
	var pz := vehicle.position.z
	for a: TrafficAgent in agents.duplicate():
		var rel := a.position.z - pz      # positivo = detrás del jugador
		if rel > 110.0 or rel < -470.0:
			_despawn(a)


# ---------------------------------------------------------------- relación con el jugador

func _player_relations(dt: float, allow_events: bool) -> void:
	blind_spot_right = false
	blind_spot_left = false
	lead_agent = null
	lead_gap = 999.0
	lead_closing = 0.0
	pedestrian_in_path = false
	var pkmh := vehicle.speed_kmh()

	for a: TrafficAgent in agents.duplicate():
		var lp := _inv * a.position
		var lat_gap := absf(lp.x) - PV.HALF_WIDTH - a.half_w

		# Choque
		if absf(lp.x) < PV.HALF_WIDTH + a.half_w - 0.05 and absf(lp.z) < PV.HALF_LENGTH + a.half_len - 0.05:
			# Con el carro detenido el choque lo provoca el otro: no se castiga al jugador.
			if vehicle.speed < 1.0:
				if a.kind != Kind.PEDESTRIAN:
					_despawn(a)
				continue
			if _collision_cooldown <= 0.0 and allow_events:
				_collision_cooldown = 2.0
				last_collision_info = "tipo=%d dir=%d local=(%.2f, %.2f) v_agente=%.1f v_jugador=%.1f x_jugador=%.2f rumbo=%.1f°" % [a.kind, a.dir, lp.x, lp.z, a.speed, vehicle.speed, vehicle.position.x, rad_to_deg(vehicle.heading)]
				collided.emit(a.kind, a.dir == -1)
				_despawn(a)
			continue

		if a.dir == 1 and a.kind != Kind.PEDESTRIAN:
			# Punto ciego: al lado o un poco detrás, fuera del campo de visión frontal
			if lp.z > -1.5 and lp.z < 7.0 and lat_gap > -0.2 and lat_gap < 3.2:
				if lp.x > 0:
					blind_spot_right = true
				else:
					blind_spot_left = true
			# Vehículo de adelante en el mismo carril
			if lp.z < 0.0 and absf(lp.x) < PV.HALF_WIDTH + a.half_w + 0.15:
				var gap := -lp.z - PV.HALF_LENGTH - a.half_len
				if gap < lead_gap:
					lead_gap = gap
					lead_agent = a
					lead_closing = vehicle.speed - a.speed

		if a.kind == Kind.MOTO and allow_events:
			_measure_moto_pass(a, lp, lat_gap, pkmh)

		if a.kind == Kind.PEDESTRIAN and allow_events:
			var in_road := absf(a.position.x) < L.EDGE + 0.2
			if in_road and lp.z < 0.0 and -lp.z < 40.0 and absf(lp.x) < 4.0:
				pedestrian_in_path = true
			if in_road and not a.ped_yield_scored and lp.z < 0.0 and -lp.z < 22.0 and vehicle.speed < 2.8:
				a.ped_yield_scored = true
				pedestrian_yielded.emit()
			if a.ped_last_long < 0.0 and lp.z >= 0.0 and in_road and not a.ped_yield_scored:
				if lat_gap < 1.5:
					pedestrian_near_miss.emit(maxf(lat_gap, 0.0))
				a.ped_yield_scored = true
			a.ped_last_long = lp.z

	if allow_events:
		_anticipation(dt)


## Mide el rebase a un motoconcho: separación lateral mínima (borde a borde)
## mientras van lado a lado, y la velocidad máxima del jugador en ese momento.
func _measure_moto_pass(a: TrafficAgent, lp: Vector3, lat_gap: float, pkmh: float) -> void:
	var overlap := PV.HALF_LENGTH + a.half_len
	var long := lp.z
	if long < -overlap - 8.0:
		if not a.pass_armed:
			a.pass_armed = true
			a.pass_overlap = false
			a.pass_min_gap = 99.0
			a.pass_max_kmh = 0.0
		return
	if not a.pass_armed:
		return
	if long > -overlap - 1.0 and long < overlap:
		a.pass_overlap = true
		a.pass_min_gap = minf(a.pass_min_gap, lat_gap)
		a.pass_max_kmh = maxf(a.pass_max_kmh, pkmh)
	elif long >= overlap:
		a.pass_armed = false
		if a.pass_overlap and a.pass_min_gap <= 4.5 and vehicle.speed > a.speed - 0.3:
			moto_pass.emit(maxf(a.pass_min_gap, 0.0), a.pass_max_kmh)
		a.pass_overlap = false


## Frenado anticipado: el vehículo de adelante frena o se acerca rápido.
## Premia si el jugador frena mientras el tiempo a colisión aún es cómodo.
func _anticipation(_dt: float) -> void:
	var a := lead_agent
	if a == null or lead_gap > 45.0:
		return
	var closing := lead_closing
	var ttc := lead_gap / closing if closing > 0.3 else 99.0
	var hazard := a.braking or (closing > 2.0 and lead_gap < 30.0)
	if hazard and not a.lead_event_open:
		a.lead_event_open = true
		a.lead_event_rewarded = false
		a.lead_event_forced = false
	if not a.lead_event_open:
		return
	if not hazard and closing < 0.5:
		a.lead_event_open = false
		return
	if not a.lead_event_rewarded and not a.lead_event_forced and vehicle.brake > 0.2 and ttc > 2.5 and vehicle.speed > 3.0:
		a.lead_event_rewarded = true
		lead_braked_early.emit()
	elif not a.lead_event_rewarded and not a.lead_event_forced and ttc < 1.5 and vehicle.speed > 3.0:
		a.lead_event_forced = true
		lead_forced_brake.emit()


## Choque contra carros estacionados.
func check_parked_collision() -> bool:
	if _collision_cooldown > 0.0:
		return false
	var ps := road.road_s(vehicle.position.z)
	for p: Vector3 in road.parked_near(ps, 8.0):
		var lp := _inv * p
		if absf(lp.x) < PV.HALF_WIDTH + VehicleMeshes.CAR_WIDTH * 0.5 - 0.05 and absf(lp.z) < PV.HALF_LENGTH + VehicleMeshes.CAR_LEN * 0.5 - 0.05:
			_collision_cooldown = 2.0
			last_collision_info = "estacionado local=(%.2f, %.2f) x_jugador=%.2f" % [lp.x, lp.z, vehicle.position.x]
			return true
	return false


func apply_rebase(amount: float) -> void:
	for a: TrafficAgent in agents:
		a.position.z += amount


func headway_seconds() -> float:
	if lead_agent == null or vehicle.speed < 1.0:
		return 99.0
	return lead_gap / vehicle.speed


## Retira vehículos cercanos a un punto (para reubicar al jugador tras un choque).
func clear_around(pos: Vector3, radius_z: float) -> void:
	for a: TrafficAgent in agents.duplicate():
		if absf(a.position.z - pos.z) < radius_z and absf(a.position.x - pos.x) < 3.0:
			_despawn(a)

class_name XRRig
extends Node3D
## Rig del jugador sentado: XROrigin3D en la posición de los ojos del conductor.
##
## Esquemas de control:
##   MANDOS  gatillo derecho acelera, gatillo izquierdo frena, joystick izquierdo dirige.
##   VOLANTE se agarra el volante con el botón de agarre de ambos mandos y se gira
##           físicamente; los gatillos siguen siendo acelerador y freno.
## B o Y recentran la vista en cualquier momento. El botón de menú pausa.
##
## Sin visor (escritorio) funciona como simulador: W/S o flechas para pedales,
## A/D para dirigir, clic derecho + ratón para mirar, R recentrar, Esc pausa.

signal recenter_requested
signal menu_pressed
signal select_pressed

enum Scheme { MANDOS, VOLANTE }

var xr_interface: OpenXRInterface
var xr_active := false
var origin: XROrigin3D
var camera: XRCamera3D
var left: XRController3D
var right: XRController3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D
var laser: MeshInstance3D
var laser_dot: MeshInstance3D
var cabin: Cabin

var scheme: int = Scheme.MANDOS
var wheel_angle := 0.0                 # rad, + = derecha
const WHEEL_MAX := deg_to_rad(135.0)

var _grab := {"left": false, "right": false}
var _grab_prev_angle := {"left": 0.0, "right": 0.0}
var _mouse_look := Vector2.ZERO
var _pointer_hand := "right"
var _desktop_steer := 0.0


func setup(p_cabin: Cabin) -> void:
	cabin = p_cabin
	name = "RigJugador"
	origin = XROrigin3D.new()
	origin.name = "XROrigin3D"
	origin.position = Cabin.EYE
	add_child(origin)
	camera = XRCamera3D.new()
	camera.name = "XRCamera3D"
	camera.near = 0.05
	camera.far = 620.0
	camera.current = true
	origin.add_child(camera)

	left = _controller("left_hand", "ManoIzquierda")
	right = _controller("right_hand", "ManoDerecha")
	left_hand = _hand_mesh(left)
	right_hand = _hand_mesh(right)
	left.button_pressed.connect(_on_button.bind("left"))
	right.button_pressed.connect(_on_button.bind("right"))

	laser = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.004, 0.004, 1.0)
	laser.mesh = lm
	laser.material_override = _unshaded(Color(0.55, 0.8, 1.0))
	laser.layers = 1 << 2
	laser.visible = false
	add_child(laser)
	laser_dot = MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.012
	dm.height = 0.024
	laser_dot.mesh = dm
	laser_dot.material_override = _unshaded(Color(1, 1, 1))
	laser_dot.layers = 1 << 2
	laser_dot.visible = false
	add_child(laser_dot)

	_init_xr()
	_init_desktop_input()


func _controller(tracker: String, node_name: String) -> XRController3D:
	var c := XRController3D.new()
	c.name = node_name
	c.tracker = tracker
	c.pose = &"aim"
	origin.add_child(c)
	return c


func _hand_mesh(c: XRController3D) -> MeshInstance3D:
	var k := MeshKit.new()
	var glove := Color(0.12, 0.12, 0.13)
	k.box(Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0.06)), Vector3(0.075, 0.035, 0.1), glove, MeshKit.F_ALL)
	k.box(Transform3D(Basis.IDENTITY, Vector3(0, -0.005, -0.01)), Vector3(0.08, 0.03, 0.06), glove.lightened(0.05), MeshKit.F_ALL)
	k.box(Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0.14)), Vector3(0.06, 0.05, 0.08), Color(0.2, 0.3, 0.55), MeshKit.F_ALL)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(MeshKit.vertex_color_material())
	mi.layers = 1 << (Cabin.CABIN_LAYER - 1)
	mi.visible = false
	c.add_child(mi)
	return mi


func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 126
	return m


func _init_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr_interface and xr_interface.is_initialized():
		xr_active = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr_interface.session_begun.connect(_on_session_begun)
		xr_interface.pose_recentered.connect(_on_pose_recentered)
		print("[XRRig] OpenXR activo")
	else:
		xr_active = false
		camera.fov = 80.0
		print("[XRRig] OpenXR no disponible: modo escritorio (simulador)")


func _on_session_begun() -> void:
	# 72 Hz es el piso de comodidad; en Quest 2/3 es la tasa nativa más estable.
	var rates := xr_interface.get_available_display_refresh_rates()
	if rates.has(72.0):
		xr_interface.display_refresh_rate = 72.0
	Engine.physics_ticks_per_second = 72
	Engine.max_fps = 0
	recenter()


func _on_pose_recentered() -> void:
	recenter()


## Pone la cabeza del jugador en el asiento del conductor, mirando al frente.
func recenter() -> void:
	if xr_active:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, false)
	else:
		_mouse_look = Vector2.ZERO
		camera.rotation = Vector3.ZERO
		camera.position = Vector3.ZERO


func _on_button(action: String, hand: String) -> void:
	match action:
		"by_button":
			recenter_requested.emit()
		"menu_button":
			menu_pressed.emit()
		"trigger_click", "ax_button":
			_pointer_hand = hand
			select_pressed.emit()


func _init_desktop_input() -> void:
	var binds := {
		"dr_acelerar": [KEY_W, KEY_UP],
		"dr_frenar": [KEY_S, KEY_DOWN, KEY_SPACE],
		"dr_izquierda": [KEY_A, KEY_LEFT],
		"dr_derecha": [KEY_D, KEY_RIGHT],
		"dr_recentrar": [KEY_R],
		"dr_menu": [KEY_ESCAPE, KEY_M],
		"dr_aceptar": [KEY_ENTER, KEY_KP_ENTER],
	}
	for action: String in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key: int in binds[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if xr_active:
		return
	if event.is_action_pressed("dr_recentrar"):
		recenter_requested.emit()
	elif event.is_action_pressed("dr_menu"):
		menu_pressed.emit()
	elif event.is_action_pressed("dr_aceptar"):
		select_pressed.emit()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_mouse_look += (event as InputEventMouseMotion).relative * 0.004
		_mouse_look.x = clampf(_mouse_look.x, -1.6, 1.6)
		_mouse_look.y = clampf(_mouse_look.y, -1.0, 1.0)
		camera.rotation = Vector3(-_mouse_look.y, -_mouse_look.x, 0)
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		select_pressed.emit()


# ------------------------------------------------------------------ manejo

## Devuelve [acelerador 0–1, freno 0–1, dirección −1–1, dirección_directa].
func drive_input(dt: float, vehicle_speed: float) -> Array:
	var throttle := 0.0
	var brake := 0.0
	var steer := 0.0
	var direct := false
	if xr_active:
		throttle = right.get_float("trigger")
		brake = left.get_float("trigger")
		if scheme == Scheme.VOLANTE:
			_update_wheel_grab(dt, vehicle_speed)
			steer = wheel_angle / WHEEL_MAX
			direct = true
		else:
			var stick := left.get_vector2("primary")
			steer = stick.x if absf(stick.x) > 0.12 else 0.0
			wheel_angle = move_toward(wheel_angle, steer * WHEEL_MAX, dt * 6.0)
		left_hand.visible = left.get_has_tracking_data()
		right_hand.visible = right.get_has_tracking_data()
	else:
		throttle = 1.0 if Input.is_action_pressed("dr_acelerar") else 0.0
		brake = 1.0 if Input.is_action_pressed("dr_frenar") else 0.0
		var target := Input.get_axis("dr_izquierda", "dr_derecha")
		_desktop_steer = move_toward(_desktop_steer, target, dt * 2.5)
		steer = _desktop_steer
		wheel_angle = steer * WHEEL_MAX
	return [throttle, brake, steer, direct]


## Volante virtual: se agarra el aro con el botón de agarre y se gira.
## El ángulo se acumula por frame, así se puede dar más de media vuelta.
func _update_wheel_grab(dt: float, vehicle_speed: float) -> void:
	var frame := cabin.wheel_base.global_transform
	var inv := frame.affine_inverse()
	var deltas := []
	for hand in ["left", "right"]:
		var c: XRController3D = left if hand == "left" else right
		var gripping := c.get_float("grip") > 0.6
		var local := inv * c.global_position
		var r := Vector2(local.x, local.y).length()
		var ang := atan2(local.y, local.x)
		if not _grab[hand]:
			if gripping and absf(r - Cabin.WHEEL_RADIUS) < 0.1 and absf(local.z) < 0.14:
				_grab[hand] = true
				_grab_prev_angle[hand] = ang
				c.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.06, 0.0)
		elif not gripping:
			_grab[hand] = false
		else:
			var d := wrapf(ang - float(_grab_prev_angle[hand]), -PI, PI)
			_grab_prev_angle[hand] = ang
			deltas.append(d)
	if deltas.size() > 0:
		var sum := 0.0
		for d: float in deltas:
			sum += d
		# Ángulo antihorario en el marco del volante = giro a la izquierda
		wheel_angle = clampf(wheel_angle - sum / deltas.size(), -WHEEL_MAX, WHEEL_MAX)
	else:
		# Sin manos el volante vuelve solo al centro (autoalineación del carro)
		wheel_angle = move_toward(wheel_angle, 0.0, dt * (0.8 + vehicle_speed * 0.08))


func is_grabbing_wheel() -> bool:
	return _grab["left"] or _grab["right"]


func haptic(strength: float, duration: float) -> void:
	if xr_active:
		for c in [left, right]:
			c.trigger_haptic_pulse("haptic", 0.0, strength, duration, 0.0)


# ------------------------------------------------------------------ puntero para menús

## Rayo desde el mando activo (o desde el ratón en escritorio): [origen, dirección].
func pointer_ray() -> Array:
	if xr_active:
		var c: XRController3D = right if _pointer_hand == "right" else left
		if not c.get_has_tracking_data():
			c = left if c == right else right
		var t := c.global_transform
		return [t.origin, -t.basis.z.normalized()]
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	return [camera.project_ray_origin(mouse), camera.project_ray_normal(mouse)]


func show_laser(from: Vector3, to: Vector3, visible_on: bool) -> void:
	laser.visible = visible_on and xr_active
	laser_dot.visible = visible_on
	if not visible_on:
		return
	var length := from.distance_to(to)
	if xr_active:
		var b := Basis.looking_at(to - from, Vector3.UP)
		b.z = b.z * length
		laser.global_transform = Transform3D(b, (from + to) * 0.5)
	laser_dot.global_position = to


func set_hands_visible(v: bool) -> void:
	if not v:
		left_hand.visible = false
		right_hand.visible = false

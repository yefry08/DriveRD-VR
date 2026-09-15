class_name Cabin
extends Node3D
## Cabina completa alrededor del conductor: tablero, volante, palanca, puertas,
## pilares, techo, capó, espejos laterales y retrovisor central funcional.
##
## En VR la cabina es el marco de referencia fijo que evita el mareo: es hija
## del carro, nunca se inclina y ocupa toda la periferia visual.
##
## Espejos: una sola cámara trasera de ángulo amplio renderiza a una textura; el
## retrovisor central muestra la franja del medio y cada espejo lateral su
## franja correspondiente (volteadas como un espejo). Un solo render extra en
## lugar de tres mantiene el presupuesto de 72 fps.

const CABIN_LAYER := 2               # capa visual que la cámara trasera no ve
const EYE := Vector3(-0.37, 1.17, 0.3)
const WHEEL_CENTER := Vector3(-0.37, 0.8, -0.12)
const WHEEL_TILT := -28.0
const WHEEL_RADIUS := 0.18
const BODY_COLOR := Color(0.72, 0.07, 0.09)

var wheel_base: Node3D               # marco fijo del volante (inclinado)
var wheel: Node3D                    # parte que gira
var dashboard: DashboardDisplay
var dashboard_viewport: SubViewport
var mirror_viewport: SubViewport
var mirror_camera: Camera3D
var blind_lamp_left: MeshInstance3D
var blind_lamp_right: MeshInstance3D
var mirror_update_every := 2
var _frame := 0
var _dash_accum := 0.0


func build(vehicle: Node3D) -> void:
	name = "Cabina"
	var kit := MeshKit.new()
	_shell(kit)
	var mat := MeshKit.vertex_color_material()
	var mi := MeshInstance3D.new()
	mi.name = "Carroceria"
	mi.mesh = kit.commit(mat)
	mi.layers = 1 << (CABIN_LAYER - 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_steering_wheel(mat)
	_dashboard()
	_mirrors(vehicle)
	_blind_spot_lamps()


func _shell(k: MeshKit) -> void:
	var dash := Color(0.13, 0.13, 0.14)
	var dash_top := Color(0.17, 0.16, 0.15)
	var trim := Color(0.28, 0.27, 0.26)
	var headliner := Color(0.72, 0.69, 0.63)
	var seat := Color(0.2, 0.2, 0.22)
	var A := MeshKit.F_ALL
	# Piso
	k.aabb(Vector3(-0.86, 0.28, -1.0), Vector3(0.86, 0.3, 1.35), Color(0.1, 0.1, 0.1), MeshKit.F_POS_Y)
	# Tablero principal y panel superior
	k.aabb(Vector3(-0.88, 0.52, -1.02), Vector3(0.88, 0.84, -0.52), dash, MeshKit.F_POS_Y | MeshKit.F_POS_Z)
	k.quad(Vector3(-0.88, 0.84, -0.52), Vector3(0.88, 0.84, -0.52), Vector3(0.88, 0.8, -0.3), Vector3(-0.88, 0.8, -0.3), dash_top)
	k.quad(Vector3(-0.88, 0.8, -0.3), Vector3(0.88, 0.8, -0.3), Vector3(0.88, 0.72, -0.28), Vector3(-0.88, 0.72, -0.28), dash)
	# Capucha del cuadro de instrumentos
	k.aabb(Vector3(-0.68, 0.84, -0.64), Vector3(-0.06, 1.1, -0.58), dash, A)
	k.aabb(Vector3(-0.7, 1.08, -0.64), Vector3(-0.04, 1.11, -0.42), dash_top, A)
	k.aabb(Vector3(-0.71, 0.84, -0.64), Vector3(-0.68, 1.11, -0.42), dash, A)
	k.aabb(Vector3(-0.06, 0.84, -0.64), Vector3(-0.03, 1.11, -0.42), dash, A)
	# Consola central, radio y guantera
	k.aabb(Vector3(-0.06, 0.4, -0.52), Vector3(0.2, 0.8, -0.34), dash.lightened(0.04), MeshKit.F_POS_Z | MeshKit.F_POS_Y | MeshKit.F_NEG_X | MeshKit.F_POS_X)
	k.face(Vector3(0.07, 0.68, -0.335), Vector3(0.1, 0, 0), Vector3(0, 0.06, 0), Vector3.BACK, Color(0.05, 0.12, 0.16))
	for i in 3:
		k.face(Vector3(0.0 + i * 0.07, 0.52, -0.335), Vector3(0.02, 0, 0), Vector3(0, 0.02, 0), Vector3.BACK, Color(0.6, 0.6, 0.6))
	k.aabb(Vector3(-0.02, 0.3, -0.34), Vector3(0.16, 0.5, 0.55), trim, MeshKit.F_POS_Y | MeshKit.F_NEG_X | MeshKit.F_POS_X)
	k.face(Vector3(0.52, 0.66, -0.515), Vector3(0.24, 0, 0), Vector3(0, 0.07, 0), Vector3.BACK, dash.lightened(0.05))
	# Palanca de cambios
	k.cylinder(Transform3D(Basis.IDENTITY, Vector3(0.07, 0.5, -0.05)), 0.018, 0.014, 0.2, 6, Color(0.55, 0.55, 0.57))
	k.box(Transform3D(Basis.IDENTITY, Vector3(0.07, 0.72, -0.05)), Vector3(0.05, 0.06, 0.07), Color(0.07, 0.07, 0.07), A)
	k.aabb(Vector3(0.02, 0.495, -0.1), Vector3(0.12, 0.505, 0.0), Color(0.05, 0.05, 0.05), MeshKit.F_POS_Y)
	# Freno de mano
	k.beam(Vector3(0.07, 0.52, 0.12), Vector3(0.07, 0.56, 0.36), 0.03, Color(0.08, 0.08, 0.08))
	# Puertas (panel interior, apoyabrazos, manija)
	for s in [-1.0, 1.0]:
		var xi: float = s * 0.84
		var xo: float = s * 0.9
		k.aabb(Vector3(minf(xi, xo), 0.3, -0.85), Vector3(maxf(xi, xo), 0.98, 1.2), trim, MeshKit.F_POS_Y | (MeshKit.F_POS_X if s < 0 else MeshKit.F_NEG_X))
		k.aabb(Vector3(minf(xi, xi - s * 0.08), 0.68, -0.2), Vector3(maxf(xi, xi - s * 0.08), 0.73, 0.5), trim.darkened(0.3), A)
		k.aabb(Vector3(minf(xi, xi - s * 0.02), 0.78, -0.45), Vector3(maxf(xi, xi - s * 0.02), 0.82, -0.3), Color(0.6, 0.6, 0.6), A)
		# Pilares A, B y C
		k.beam(Vector3(s * 0.85, 0.9, -0.95), Vector3(s * 0.73, 1.44, -0.2), 0.08, trim.darkened(0.2))
		k.beam(Vector3(s * 0.87, 0.98, 0.78), Vector3(s * 0.79, 1.44, 0.72), 0.1, trim)
		k.beam(Vector3(s * 0.86, 0.98, 1.3), Vector3(s * 0.74, 1.44, 1.2), 0.14, trim)
		# Guardafangos y costados exteriores visibles por la ventana
		var fo: float = s * 0.92
		k.aabb(Vector3(minf(fo, xo), 0.3, -2.25), Vector3(maxf(fo, xo), 0.92, 2.2), BODY_COLOR, MeshKit.F_POS_Y | (MeshKit.F_NEG_X if s < 0 else MeshKit.F_POS_X))
		k.aabb(Vector3(minf(fo, s * 0.7), 0.3, -2.25), Vector3(maxf(fo, s * 0.7), 0.9, -0.95), BODY_COLOR, MeshKit.F_POS_Y | (MeshKit.F_NEG_X if s < 0 else MeshKit.F_POS_X))
	# Techo interior y marco del parabrisas
	k.aabb(Vector3(-0.8, 1.44, -0.22), Vector3(0.8, 1.48, 1.32), headliner, MeshKit.F_NEG_Y)
	k.beam(Vector3(-0.74, 1.42, -0.2), Vector3(0.74, 1.42, -0.2), 0.09, headliner.darkened(0.1))
	k.beam(Vector3(-0.78, 1.42, 1.25), Vector3(0.78, 1.42, 1.25), 0.09, headliner.darkened(0.1))
	# Parasoles
	k.aabb(Vector3(-0.68, 1.38, -0.17), Vector3(-0.1, 1.41, 0.05), headliner.darkened(0.05), A)
	k.aabb(Vector3(0.1, 1.38, -0.17), Vector3(0.68, 1.41, 0.05), headliner.darkened(0.05), A)
	# Asientos
	for sx in [-0.37, 0.4]:
		k.aabb(Vector3(sx - 0.25, 0.4, 0.15), Vector3(sx + 0.25, 0.55, 0.7), seat, A)
		k.box(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12)), Vector3(sx, 0.9, 0.78)), Vector3(0.5, 0.7, 0.12), seat, A)
		k.aabb(Vector3(sx - 0.13, 1.28, 0.78), Vector3(sx + 0.13, 1.45, 0.9), seat, A)
	k.aabb(Vector3(-0.8, 0.35, 1.25), Vector3(0.8, 0.95, 1.4), seat.darkened(0.1), MeshKit.F_POS_Z | MeshKit.F_NEG_Z | MeshKit.F_POS_Y)
	# Capó exterior (ayuda a sentir la posición en el carril)
	k.quad(Vector3(-0.82, 0.86, -2.25), Vector3(0.82, 0.86, -2.25), Vector3(0.84, 0.92, -1.02), Vector3(-0.84, 0.92, -1.02), BODY_COLOR)
	k.aabb(Vector3(-0.86, 0.3, -2.3), Vector3(0.86, 0.86, -2.25), BODY_COLOR.darkened(0.3), MeshKit.F_NEG_Z)
	# Limpiaparabrisas
	k.beam(Vector3(-0.6, 0.93, -1.0), Vector3(-0.1, 0.93, -1.08), 0.015, Color(0.05, 0.05, 0.05))
	k.beam(Vector3(0.05, 0.93, -1.0), Vector3(0.55, 0.93, -1.08), 0.015, Color(0.05, 0.05, 0.05))
	# Brazo del retrovisor
	k.beam(Vector3(0.0, 1.46, -0.3), Vector3(0.0, 1.36, -0.38), 0.02, Color(0.1, 0.1, 0.1))


func _steering_wheel(mat: Material) -> void:
	wheel_base = Node3D.new()
	wheel_base.name = "BaseVolante"
	wheel_base.position = WHEEL_CENTER
	wheel_base.rotation = Vector3(deg_to_rad(WHEEL_TILT), 0, 0)
	add_child(wheel_base)
	# Columna
	var ck := MeshKit.new()
	ck.beam(Vector3(0, 0, -0.02), Vector3(0, 0, -0.42), 0.06, Color(0.1, 0.1, 0.11))
	var column := MeshInstance3D.new()
	column.mesh = ck.commit(mat)
	column.layers = 1 << (CABIN_LAYER - 1)
	wheel_base.add_child(column)

	wheel = Node3D.new()
	wheel.name = "Volante"
	wheel_base.add_child(wheel)
	var k := MeshKit.new()
	var rim := Color(0.09, 0.09, 0.1)
	var segs := 24
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		k.beam(Vector3(cos(a0), sin(a0), 0) * WHEEL_RADIUS, Vector3(cos(a1), sin(a1), 0) * WHEEL_RADIUS, 0.032, rim)
	for a in [0.0, PI, -PI * 0.5]:
		k.beam(Vector3.ZERO, Vector3(cos(a), sin(a), 0) * WHEEL_RADIUS, 0.028, Color(0.16, 0.16, 0.17))
	k.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.01)), Vector3(0.1, 0.08, 0.04), Color(0.14, 0.14, 0.15), MeshKit.F_ALL)
	# Emblema con los colores de la bandera en el centro
	k.face(Vector3(-0.012, 0.009, 0.032), Vector3(0.01, 0, 0), Vector3(0, 0.008, 0), Vector3.BACK, RoadLayout.DOMINICAN_BLUE)
	k.face(Vector3(0.012, 0.009, 0.032), Vector3(0.01, 0, 0), Vector3(0, 0.008, 0), Vector3.BACK, RoadLayout.DOMINICAN_RED)
	k.face(Vector3(-0.012, -0.011, 0.032), Vector3(0.01, 0, 0), Vector3(0, 0.008, 0), Vector3.BACK, RoadLayout.DOMINICAN_RED)
	k.face(Vector3(0.012, -0.011, 0.032), Vector3(0.01, 0, 0), Vector3(0, 0.008, 0), Vector3.BACK, RoadLayout.DOMINICAN_BLUE)
	# Marca de centro arriba (para ver cuánto se giró)
	k.box(Transform3D(Basis.IDENTITY, Vector3(0, WHEEL_RADIUS, 0.005)), Vector3(0.03, 0.02, 0.036), Color(0.85, 0.85, 0.85), MeshKit.F_ALL)
	var wm := MeshInstance3D.new()
	wm.mesh = k.commit(mat)
	wm.layers = 1 << (CABIN_LAYER - 1)
	wheel.add_child(wm)


## Rotación visual del volante: positivo = girado a la derecha.
func set_wheel_angle(radians: float) -> void:
	wheel.rotation = Vector3(0, 0, -radians)


func _dashboard() -> void:
	dashboard_viewport = SubViewport.new()
	dashboard_viewport.name = "PantallaTablero"
	dashboard_viewport.size = Vector2i(DashboardDisplay.SIZE)
	dashboard_viewport.disable_3d = true
	dashboard_viewport.transparent_bg = false
	dashboard_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(dashboard_viewport)
	dashboard = DashboardDisplay.new()
	dashboard_viewport.add_child(dashboard)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6 * DashboardDisplay.SIZE.y / DashboardDisplay.SIZE.x)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = dashboard_viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mi := MeshInstance3D.new()
	mi.name = "Instrumentos"
	mi.mesh = quad
	mi.material_override = mat
	mi.layers = 1 << (CABIN_LAYER - 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var pos := Vector3(-0.37, 0.965, -0.565)
	mi.position = pos
	_face_toward(mi, EYE)


## Actualiza la textura del tablero a ~30 Hz.
func update_dashboard(dt: float) -> void:
	_dash_accum += dt
	if _dash_accum >= 1.0 / 30.0:
		dashboard.tick(_dash_accum)
		_dash_accum = 0.0
		dashboard_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _mirrors(vehicle: Node3D) -> void:
	mirror_viewport = SubViewport.new()
	mirror_viewport.name = "VistaTrasera"
	mirror_viewport.size = Vector2i(640, 200)
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	mirror_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(mirror_viewport)
	mirror_camera = Camera3D.new()
	mirror_camera.keep_aspect = Camera3D.KEEP_WIDTH
	mirror_camera.fov = 100.0
	mirror_camera.far = 160.0
	mirror_camera.near = 0.3
	mirror_camera.cull_mask = 0xFFFFF & ~(1 << (CABIN_LAYER - 1)) & ~(1 << 2)
	mirror_viewport.add_child(mirror_camera)

	var tex := mirror_viewport.get_texture()
	# Retrovisor central
	_mirror(tex, Vector3(0.0, 1.33, -0.4), Vector2(0.28, 0.08), 0.3, 0.7, 0.3, 0.66, Vector3(0.3, 0.1, 0.06))
	# Espejo lateral izquierdo (lado del conductor)
	_mirror(tex, Vector3(-1.0, 1.02, -0.45), Vector2(0.2, 0.13), 0.7, 1.0, 0.2, 0.85, Vector3(0.24, 0.17, 0.1))
	# Espejo lateral derecho
	_mirror(tex, Vector3(1.0, 1.02, -0.45), Vector2(0.2, 0.13), 0.0, 0.3, 0.2, 0.85, Vector3(0.24, 0.17, 0.1))


func _mirror(tex: Texture2D, pos: Vector3, size: Vector2, u0: float, u1: float, v0: float, v1: float, housing: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	_face_toward(holder, EYE)
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	# Volteo horizontal: así se ve como un espejo y no como una cámara
	mat.uv1_scale = Vector3(-(u1 - u0), v1 - v0, 1)
	mat.uv1_offset = Vector3(u1, v0, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.layers = 1 << (CABIN_LAYER - 1)
	mi.position = Vector3(0, 0, 0.012)
	holder.add_child(mi)
	var hk := MeshKit.new()
	hk.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, -housing.z * 0.5 + 0.008)), housing, Color(0.08, 0.08, 0.09), MeshKit.F_ALL)
	var hm := MeshInstance3D.new()
	hm.mesh = hk.commit(MeshKit.vertex_color_material())
	hm.layers = 1 << (CABIN_LAYER - 1)
	holder.add_child(hm)


func _blind_spot_lamps() -> void:
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1.0, 0.55, 0.05)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.01)
	blind_lamp_left = MeshInstance3D.new()
	blind_lamp_left.mesh = mesh
	blind_lamp_left.material_override = lamp_mat
	blind_lamp_left.layers = 1 << (CABIN_LAYER - 1)
	blind_lamp_left.position = Vector3(-0.8, 0.97, -0.72)
	blind_lamp_left.visible = false
	add_child(blind_lamp_left)
	blind_lamp_right = blind_lamp_left.duplicate()
	blind_lamp_right.position = Vector3(0.8, 0.97, -0.72)
	add_child(blind_lamp_right)
	_face_toward(blind_lamp_left, EYE)
	_face_toward(blind_lamp_right, EYE)


## Orienta un nodo para que su +Z mire hacia `target` (coordenadas de la cabina).
func _face_toward(node: Node3D, target: Vector3) -> void:
	var dir := (target - node.position).normalized()
	var z := dir
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x).normalized()
	node.basis = Basis(x, y, z)


## Cámara trasera: sigue al carro y se renderiza solo cada N frames.
func update_mirrors(vehicle: Node3D, blink_left: bool, blink_right: bool, time: float) -> void:
	_frame += 1
	mirror_camera.global_transform = vehicle.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.3, 2.5))
	if _frame % maxi(mirror_update_every, 1) == 0:
		mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var on := fmod(time, 0.4) < 0.25
	blind_lamp_left.visible = blink_left and on
	blind_lamp_right.visible = blink_right and on

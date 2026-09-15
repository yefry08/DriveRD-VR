class_name VehicleMeshes
extends RefCounted
## Geometría de vehículos y personas. Todos miran hacia -Z y apoyan en y = 0.

const CAR_LEN := 4.4
const CAR_WIDTH := 1.8
const GUAGUA_LEN := 7.6
const GUAGUA_WIDTH := 2.35
const MOTO_LEN := 2.0
const MOTO_WIDTH := 0.8

const GLASS := Color(0.12, 0.15, 0.19)
const TIRE := Color(0.08, 0.08, 0.08)
const CHROME := Color(0.7, 0.7, 0.72)
const TAIL := Color(0.45, 0.05, 0.05)
const HEAD := Color(0.95, 0.93, 0.8)

const CAR_COLORS := [
	Color(0.85, 0.85, 0.87), Color(0.12, 0.13, 0.15), Color(0.62, 0.08, 0.1),
	Color(0.2, 0.3, 0.55), Color(0.55, 0.57, 0.6), Color(0.9, 0.9, 0.9), Color(0.75, 0.62, 0.2),
]
const GUAGUA_SCHEMES := [
	[Color(0.95, 0.95, 0.93), Color(0.1, 0.35, 0.75)],
	[Color(0.98, 0.78, 0.12), Color(0.8, 0.1, 0.1)],
	[Color(0.9, 0.9, 0.9), Color(0.1, 0.55, 0.3)],
]
const SHIRTS := [
	Color(0.9, 0.45, 0.1), Color(0.15, 0.55, 0.25), Color(0.2, 0.35, 0.75),
	Color(0.85, 0.85, 0.2), Color(0.8, 0.2, 0.25), Color(0.95, 0.95, 0.95),
]
const SKINS := [Color(0.55, 0.36, 0.24), Color(0.42, 0.27, 0.17), Color(0.68, 0.48, 0.34), Color(0.33, 0.21, 0.14)]


static func _t(pos: Vector3, basis := Basis.IDENTITY) -> Transform3D:
	return Transform3D(basis, pos)


static func add_car(kit: MeshKit, xf: Transform3D, body: Color) -> void:
	# Carrocería baja
	kit.box(xf * _t(Vector3(0, 0.62, 0)), Vector3(CAR_WIDTH, 0.62, CAR_LEN), body)
	# Capó y maletero ligeramente más bajos para la silueta
	kit.box(xf * _t(Vector3(0, 0.95, -1.55)), Vector3(CAR_WIDTH - 0.08, 0.06, 1.2), body.darkened(0.05))
	# Habitáculo del color de la carrocería con ventanas insertadas
	var cab := xf * _t(Vector3(0, 1.18, 0.25))
	kit.box(cab, Vector3(CAR_WIDTH - 0.16, 0.5, 2.1), body.lightened(0.05))
	for sx in [-1.0, 1.0]:
		var side := xf.basis * Vector3(sx, 0, 0)
		kit.face(xf * Vector3(sx * (CAR_WIDTH * 0.5 - 0.07), 1.2, 0.25), xf.basis * Vector3(0, 0, -0.85 * sx), xf.basis * Vector3(0, 0.17, 0), side.normalized(), GLASS)
	kit.face(xf * Vector3(0, 1.2, 0.25 - 1.06), xf.basis * Vector3(-0.7, 0, 0), xf.basis * Vector3(0, 0.2, 0), (xf.basis * Vector3(0, 0, -1)).normalized(), GLASS)
	kit.face(xf * Vector3(0, 1.2, 0.25 + 1.06), xf.basis * Vector3(0.7, 0, 0), xf.basis * Vector3(0, 0.19, 0), (xf.basis * Vector3(0, 0, 1)).normalized(), GLASS)
	# Ruedas
	for sx in [-1.0, 1.0]:
		for sz in [-1.35, 1.35]:
			kit.box(xf * _t(Vector3(sx * (CAR_WIDTH * 0.5 - 0.05), 0.32, sz)), Vector3(0.24, 0.64, 0.64), TIRE)
	# Luces
	for sx in [-0.62, 0.62]:
		kit.box(xf * _t(Vector3(sx, 0.78, -CAR_LEN * 0.5 - 0.01)), Vector3(0.36, 0.14, 0.04), HEAD, MeshKit.F_NEG_Z)
		kit.box(xf * _t(Vector3(sx, 0.8, CAR_LEN * 0.5 + 0.01)), Vector3(0.36, 0.14, 0.04), TAIL, MeshKit.F_POS_Z)
	# Parachoques
	kit.box(xf * _t(Vector3(0, 0.42, -CAR_LEN * 0.5 - 0.04)), Vector3(CAR_WIDTH, 0.16, 0.1), body.darkened(0.4))
	kit.box(xf * _t(Vector3(0, 0.42, CAR_LEN * 0.5 + 0.04)), Vector3(CAR_WIDTH, 0.16, 0.1), body.darkened(0.4))


static func add_guagua(kit: MeshKit, xf: Transform3D, scheme: int) -> void:
	var s: Array = GUAGUA_SCHEMES[scheme % GUAGUA_SCHEMES.size()]
	var body: Color = s[0]
	var stripe: Color = s[1]
	var hl := GUAGUA_LEN * 0.5
	kit.box(xf * _t(Vector3(0, 1.0, 0)), Vector3(GUAGUA_WIDTH, 1.2, GUAGUA_LEN), body)
	# Franja de ventanas
	kit.box(xf * _t(Vector3(0, 2.0, 0.1)), Vector3(GUAGUA_WIDTH + 0.02, 0.8, GUAGUA_LEN - 0.5), GLASS, MeshKit.F_POS_X | MeshKit.F_NEG_X | MeshKit.F_POS_Z)
	kit.box(xf * _t(Vector3(0, 2.0, 0.1)), Vector3(GUAGUA_WIDTH - 0.02, 0.8, GUAGUA_LEN - 0.5), body, MeshKit.F_POS_Y)
	# Parabrisas inclinado
	kit.box(xf * _t(Vector3(0, 2.0, -hl + 0.2), Basis(Vector3.RIGHT, deg_to_rad(-12))), Vector3(GUAGUA_WIDTH - 0.1, 0.85, 0.08), GLASS)
	# Techo y franja de color
	kit.box(xf * _t(Vector3(0, 2.45, 0.05)), Vector3(GUAGUA_WIDTH, 0.12, GUAGUA_LEN - 0.3), body.darkened(0.08))
	kit.box(xf * _t(Vector3(0, 1.25, 0)), Vector3(GUAGUA_WIDTH + 0.03, 0.22, GUAGUA_LEN + 0.02), stripe, MeshKit.F_POS_X | MeshKit.F_NEG_X | MeshKit.F_NEG_Z | MeshKit.F_POS_Z)
	# Letrero de ruta
	kit.box(xf * _t(Vector3(0, 2.62, -hl + 0.5)), Vector3(1.2, 0.25, 0.08), stripe)
	# Ruedas
	for sx in [-1.0, 1.0]:
		for sz in [-2.5, 2.4]:
			kit.box(xf * _t(Vector3(sx * (GUAGUA_WIDTH * 0.5 - 0.1), 0.42, sz)), Vector3(0.3, 0.84, 0.84), TIRE)
	for sx in [-0.8, 0.8]:
		kit.box(xf * _t(Vector3(sx, 0.75, -hl - 0.01)), Vector3(0.35, 0.18, 0.04), HEAD, MeshKit.F_NEG_Z)
		kit.box(xf * _t(Vector3(sx, 0.85, hl + 0.01)), Vector3(0.3, 0.3, 0.04), TAIL, MeshKit.F_POS_Z)


static func add_rider(kit: MeshKit, xf: Transform3D, shirt: Color, skin: Color, helmet: bool) -> void:
	kit.box(xf * _t(Vector3(0, 1.15, 0.05), Basis(Vector3.RIGHT, deg_to_rad(12))), Vector3(0.44, 0.58, 0.28), shirt)
	kit.box(xf * _t(Vector3(0, 1.58, -0.02)), Vector3(0.22, 0.24, 0.24), skin)
	if helmet:
		kit.box(xf * _t(Vector3(0, 1.66, -0.02)), Vector3(0.28, 0.18, 0.3), Color(0.1, 0.1, 0.12))
	# Brazos hacia el manubrio
	for sx in [-1.0, 1.0]:
		kit.beam(xf * Vector3(sx * 0.22, 1.35, 0.0), xf * Vector3(sx * 0.3, 1.05, -0.45), 0.09, shirt)
	# Piernas
	for sx in [-1.0, 1.0]:
		kit.beam(xf * Vector3(sx * 0.14, 0.88, 0.1), xf * Vector3(sx * 0.2, 0.75, -0.3), 0.13, Color(0.18, 0.2, 0.28))
		kit.beam(xf * Vector3(sx * 0.2, 0.75, -0.3), xf * Vector3(sx * 0.2, 0.3, -0.2), 0.11, Color(0.18, 0.2, 0.28))


static func add_moto(kit: MeshKit, xf: Transform3D, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + 13
	var frame_color: Color = [Color(0.7, 0.05, 0.08), Color(0.1, 0.1, 0.1), Color(0.15, 0.25, 0.6), Color(0.85, 0.85, 0.85)][variant % 4]
	# Ruedas
	kit.box(xf * _t(Vector3(0, 0.32, -0.72)), Vector3(0.12, 0.64, 0.64), TIRE)
	kit.box(xf * _t(Vector3(0, 0.32, 0.7)), Vector3(0.14, 0.64, 0.64), TIRE)
	# Chasis, tanque, asiento
	kit.box(xf * _t(Vector3(0, 0.62, 0.0)), Vector3(0.28, 0.3, 1.2), frame_color)
	kit.box(xf * _t(Vector3(0, 0.85, -0.25)), Vector3(0.32, 0.22, 0.45), frame_color)
	kit.box(xf * _t(Vector3(0, 0.86, 0.35)), Vector3(0.3, 0.1, 0.8), Color(0.08, 0.08, 0.08))
	# Horquilla y manubrio
	kit.beam(xf * Vector3(0, 0.35, -0.72), xf * Vector3(0, 1.08, -0.52), 0.06, CHROME)
	kit.box(xf * _t(Vector3(0, 1.08, -0.5)), Vector3(0.72, 0.04, 0.04), CHROME)
	kit.box(xf * _t(Vector3(0, 0.95, -0.66)), Vector3(0.14, 0.12, 0.06), HEAD, MeshKit.F_NEG_Z | MeshKit.F_POS_Y)
	kit.box(xf * _t(Vector3(0, 0.8, 0.83)), Vector3(0.12, 0.06, 0.04), TAIL, MeshKit.F_POS_Z)
	var shirt: Color = SHIRTS[rng.randi() % SHIRTS.size()]
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	add_rider(kit, xf * _t(Vector3(0, 0, 0.12)), shirt, skin, rng.randf() < 0.45)
	# Motoconcho con pasajero en la mitad de las variantes
	if variant % 2 == 1:
		add_rider(kit, xf * _t(Vector3(0, 0.05, 0.62)), SHIRTS[rng.randi() % SHIRTS.size()], SKINS[rng.randi() % SKINS.size()], false)


## Cuerpo del peatón sin piernas (las piernas se animan aparte).
static func add_pedestrian_body(kit: MeshKit, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 104729 + 5
	var shirt: Color = SHIRTS[rng.randi() % SHIRTS.size()]
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	kit.box(_t(Vector3(0, 1.22, 0)), Vector3(0.42, 0.6, 0.24), shirt)
	kit.box(_t(Vector3(0, 1.66, 0)), Vector3(0.21, 0.25, 0.23), skin)
	kit.box(_t(Vector3(0, 1.8, 0.01)), Vector3(0.23, 0.07, 0.25), Color(0.08, 0.06, 0.05))
	for sx in [-1.0, 1.0]:
		kit.box(_t(Vector3(sx * 0.27, 1.2, 0)), Vector3(0.1, 0.56, 0.12), shirt.darkened(0.1))
	kit.box(_t(Vector3(0, 0.88, 0)), Vector3(0.38, 0.12, 0.22), Color(0.2, 0.22, 0.35))


static func add_pedestrian_leg(kit: MeshKit) -> void:
	# Pivote en la cadera (y = 0), la pierna cuelga hacia abajo
	kit.box(_t(Vector3(0, -0.42, 0)), Vector3(0.14, 0.84, 0.16), Color(0.2, 0.22, 0.35))
	kit.box(_t(Vector3(0, -0.84, -0.05)), Vector3(0.14, 0.08, 0.26), Color(0.1, 0.1, 0.1))

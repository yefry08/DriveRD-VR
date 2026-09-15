class_name SegmentBuilder
extends RefCounted
## Genera un tramo de 50 m de avenida dominicana: calzada de cuatro carriles,
## estacionamiento, aceras, edificios bajos, colmados, palmas, postes del
## tendido eléctrico y astas con la bandera dominicana.
##
## Devuelve un Dictionary con:
##   mesh      ArrayMesh (superficie 0 estática, superficie 1 banderas)
##   colmados  Array de {pos, rot_y, text}
##   parked    Array de Vector3 (centro de carros estacionados, local al tramo)
##   ped_gaps  Array de Vector3 (huecos entre estacionados por donde sale un peatón)
##   crosswalk bool

const L = preload("res://scripts/road_layout.gd")

const ASPHALT := Color(0.2, 0.2, 0.21)
const MARK_WHITE := Color(0.88, 0.88, 0.86)
const MARK_YELLOW := Color(0.93, 0.74, 0.12)
const SIDEWALK := Color(0.66, 0.64, 0.6)
const CURB_A := Color(0.95, 0.8, 0.15)
const CURB_B := Color(0.92, 0.92, 0.9)
const POLE := Color(0.55, 0.55, 0.52)
const WIRE := Color(0.05, 0.05, 0.05)
const TRUNK := Color(0.52, 0.43, 0.32)
const FROND := Color(0.2, 0.45, 0.16)

const EARTH := [
	Color(0.72, 0.42, 0.3), Color(0.8, 0.62, 0.35), Color(0.85, 0.76, 0.6),
	Color(0.88, 0.58, 0.47), Color(0.93, 0.84, 0.55), Color(0.76, 0.55, 0.42),
	Color(0.9, 0.8, 0.7), Color(0.62, 0.72, 0.62), Color(0.95, 0.9, 0.8),
]
const COLMADO_WALLS := [Color(0.98, 0.82, 0.1), Color(0.2, 0.6, 0.3), Color(0.15, 0.45, 0.8), Color(0.9, 0.3, 0.2)]
const COLMADO_NAMES := [
	"COLMADO LA ESQUINA", "COLMADO DON PEDRO", "COLMADO EL PRIMO", "COLMADO MI BARRIO",
	"COLMADO LOS HERMANOS", "COLMADO DOÑA ROSA", "COLMADO EL TÍGUERE", "COLMADO LA BENDICIÓN",
]

## Estilo por avenida: pisos mín/máx, probabilidad de colmado, densidad de palmas y banderas.
const STYLES := [
	{"floors": Vector2i(1, 3), "colmado": 0.35, "palm": 0.7, "flag": 0.55, "tone": 0.0},
	{"floors": Vector2i(2, 4), "colmado": 0.15, "palm": 0.55, "flag": 0.8, "tone": 0.05},
	{"floors": Vector2i(1, 4), "colmado": 0.12, "palm": 0.6, "flag": 0.5, "tone": -0.04},
	{"floors": Vector2i(1, 2), "colmado": 0.55, "palm": 0.4, "flag": 0.5, "tone": 0.02},
]

var rng := RandomNumberGenerator.new()
var kit: MeshKit
var flag_kit: MeshKit
var style: Dictionary
var result: Dictionary


func build(avenue: int, variant: int, static_mat: Material, flag_mat: Material) -> Dictionary:
	rng.seed = hash([avenue, variant, "driverd"])
	kit = MeshKit.new()
	flag_kit = MeshKit.new()
	style = STYLES[avenue % STYLES.size()]
	result = {"colmados": [], "parked": [], "ped_gaps": [], "crosswalk": false}

	_road()
	for side in [1.0, -1.0]:
		_parking(side)
		_sidewalk(side)
		_buildings(side)
		_poles_and_wires(side)
		_palms_and_flags(side)

	var mesh := ArrayMesh.new()
	kit.commit_to(mesh, static_mat)
	flag_kit.commit_to(mesh, flag_mat)
	result["mesh"] = mesh
	result["vertices"] = kit.vertex_count + flag_kit.vertex_count
	return result


func _road() -> void:
	var len := L.SEG_LEN
	var tint: float = style["tone"]
	kit.aabb(Vector3(-L.PARK_OUT, -0.1, -len), Vector3(L.PARK_OUT, 0.0, 0.0), ASPHALT.lightened(0.03 + tint), MeshKit.F_POS_Y)
	var y := 0.012
	# Doble línea amarilla central
	for x in [-0.14, 0.14]:
		_mark(x, 0.12, 0.0, -len, MARK_YELLOW)
	# Líneas de borde
	for x in [-L.EDGE, L.EDGE]:
		_mark(x, 0.15, 0.0, -len, MARK_WHITE)
	# Líneas discontinuas entre carriles del mismo sentido (3 m pintados cada 10 m)
	for x in [-L.LANE_W, L.LANE_W]:
		var z := -1.0
		while z > -len:
			_mark(x, 0.12, z, z - 3.0, MARK_WHITE)
			z -= 10.0
	# Paso peatonal ocasional (los peatones del juego cruzan fuera de él)
	if rng.randf() < 0.18:
		result["crosswalk"] = true
		var x := -L.EDGE + 0.4
		while x < L.EDGE - 0.4:
			kit.face(Vector3(x + 0.25, y, -25.0), Vector3(0.25, 0, 0), Vector3(0, 0, -1.6), Vector3.UP, MARK_WHITE)
			x += 1.0


func _mark(x: float, width: float, z0: float, z1: float, color: Color) -> void:
	var zc := (z0 + z1) * 0.5
	var hl := absf(z0 - z1) * 0.5
	kit.face(Vector3(x, 0.012, zc), Vector3(width * 0.5, 0, 0), Vector3(0, 0, -hl), Vector3.UP, color)


func _parking(side: float) -> void:
	var z := -rng.randf_range(1.0, 5.0)
	var last_car_end := 1.0e9
	while z > -L.SEG_LEN + 5.0:
		if rng.randf() < 0.55:
			var zc := z - VehicleMeshes.CAR_LEN * 0.5
			if zc - VehicleMeshes.CAR_LEN * 0.5 < -L.SEG_LEN + 0.5:
				break
			var basis := Basis.IDENTITY if side > 0 else Basis(Vector3.UP, PI)
			var pos := Vector3(side * L.PARK_CENTER, 0.0, zc)
			VehicleMeshes.add_car(kit, Transform3D(basis, pos), VehicleMeshes.CAR_COLORS[rng.randi() % VehicleMeshes.CAR_COLORS.size()])
			result["parked"].append(pos)
			# Hueco estrecho justo antes de este carro: por ahí sale el peatón escondido
			if last_car_end - z > 0.8 and last_car_end - z < 3.5:
				result["ped_gaps"].append(Vector3(side * (L.PARK_CENTER + 0.4), 0.0, (last_car_end + z) * 0.5))
			z -= VehicleMeshes.CAR_LEN
			last_car_end = z
			z -= rng.randf_range(1.0, 2.6)
		else:
			z -= rng.randf_range(5.0, 11.0)


func _sidewalk(side: float) -> void:
	var s := side
	var x0 := minf(s * L.PARK_OUT, s * L.CURB_OUT)
	var x1 := maxf(s * L.PARK_OUT, s * L.CURB_OUT)
	var z := 0.0
	var alt := false
	while z > -L.SEG_LEN:
		kit.aabb(Vector3(x0, 0.0, z - 2.5), Vector3(x1, 0.17, z), CURB_A if alt else CURB_B, MeshKit.F_POS_Y | (MeshKit.F_NEG_X if s > 0 else MeshKit.F_POS_X))
		alt = not alt
		z -= 2.5
	var sx0 := minf(s * L.CURB_OUT, s * (L.SIDEWALK_OUT + 0.5))
	var sx1 := maxf(s * L.CURB_OUT, s * (L.SIDEWALK_OUT + 0.5))
	kit.aabb(Vector3(sx0, 0.0, -L.SEG_LEN), Vector3(sx1, 0.16, 0.0), SIDEWALK.lightened(rng.randf_range(-0.02, 0.02)), MeshKit.F_POS_Y)


func _buildings(side: float) -> void:
	var s := side
	var fl: Vector2i = style["floors"]
	var z := 0.0
	while z > -L.SEG_LEN + 0.5:
		var w := rng.randf_range(6.0, 13.0)
		w = minf(w, z + L.SEG_LEN)
		if w < 2.5:
			break
		var is_colmado := rng.randf() < float(style["colmado"]) and w > 6.0
		var floors := 1 if is_colmado and rng.randf() < 0.6 else rng.randi_range(fl.x, fl.y)
		_building(s, z, z - w, floors, is_colmado)
		z -= w
		if rng.randf() < 0.15:
			z -= rng.randf_range(1.2, 2.5)  # callejón
	# Segunda fila de edificios para rellenar el horizonte
	var z2 := 0.0
	while z2 > -L.SEG_LEN + 0.5:
		var w2 := minf(rng.randf_range(10.0, 20.0), z2 + L.SEG_LEN)
		var h2 := rng.randf_range(5.0, 14.0)
		var c: Color = EARTH[rng.randi() % EARTH.size()].darkened(0.12)
		var xa := s * 26.0
		var xb := s * 34.0
		kit.aabb(Vector3(minf(xa, xb), 0.0, z2 - w2), Vector3(maxf(xa, xb), h2, z2), c, MeshKit.F_POS_Y | (MeshKit.F_NEG_X if s > 0 else MeshKit.F_POS_X) | MeshKit.F_POS_Z | MeshKit.F_NEG_Z)
		z2 -= w2


func _building(s: float, z0: float, z1: float, floors: int, colmado: bool) -> void:
	var depth := rng.randf_range(8.0, 12.0)
	var floor_h := 3.1
	var h := floors * floor_h + 0.4
	var fx := s * L.SIDEWALK_OUT            # plano de fachada
	var bx := s * (L.SIDEWALK_OUT + depth)
	var wall: Color
	if colmado:
		wall = COLMADO_WALLS[rng.randi() % COLMADO_WALLS.size()]
	else:
		wall = EARTH[rng.randi() % EARTH.size()].lightened(rng.randf_range(-0.05, 0.05))
	var faces := MeshKit.F_POS_Y | MeshKit.F_POS_Z | MeshKit.F_NEG_Z | (MeshKit.F_NEG_X if s > 0 else MeshKit.F_POS_X)
	kit.aabb(Vector3(minf(fx, bx), 0.0, z1), Vector3(maxf(fx, bx), h, z0), wall, faces)
	# Pretil del techo
	kit.aabb(Vector3(minf(fx, fx + s * 0.3) , h, z1), Vector3(maxf(fx, fx + s * 0.3), h + 0.35, z0), wall.lightened(0.15), MeshKit.F_POS_Y | (MeshKit.F_NEG_X if s > 0 else MeshKit.F_POS_X) | MeshKit.F_POS_Z | MeshKit.F_NEG_Z)

	var n := Vector3(-s, 0, 0)
	var u := Vector3(0, 0, s)           # u × Y = n
	var fwx := fx - s * 0.02            # detalles apenas delante de la fachada
	var width := z0 - z1
	var zc := (z0 + z1) * 0.5
	var window_color: Color = [Color(0.15, 0.2, 0.26), Color(0.35, 0.22, 0.12), Color(0.2, 0.35, 0.25), Color(0.92, 0.92, 0.9)][rng.randi() % 4]

	# Planta baja: puerta + ventanas con rejas, o local comercial
	kit.face(Vector3(fwx, 1.15, zc), u * 0.65, Vector3(0, 1.15, 0), n, Color(0.12, 0.1, 0.09))
	var n_win := int((width - 2.0) / 2.8)
	for i in n_win:
		var wz := z0 - 1.4 - i * 2.8
		if absf(wz - zc) < 1.4:
			continue
		for fl in floors:
			var wy := 1.7 + fl * floor_h
			kit.face(Vector3(fwx, wy, wz), u * 0.6, Vector3(0, 0.62, 0), n, window_color)
			if window_color != Color(0.92, 0.92, 0.9):
				kit.face(Vector3(fwx - s * 0.01, wy, wz), u * 0.62, Vector3(0, 0.03, 0), n, Color(0.9, 0.9, 0.88))
	# Balcones en pisos altos
	for fl in range(1, floors):
		if rng.randf() < 0.55:
			var by := fl * floor_h
			var x_out := fx - s * 1.0
			kit.aabb(Vector3(minf(fx, x_out), by - 0.12, z1 + 0.5), Vector3(maxf(fx, x_out), by, z0 - 0.5), wall.darkened(0.1), MeshKit.F_ALL)
			kit.aabb(Vector3(minf(x_out, x_out + s * 0.05), by, z1 + 0.5), Vector3(maxf(x_out, x_out + s * 0.05), by + 1.0, z0 - 0.5), Color(0.15, 0.15, 0.15), MeshKit.F_NEG_X if s > 0 else MeshKit.F_POS_X)
	# Tinaco en el techo
	if rng.randf() < 0.6:
		var tx := s * (L.SIDEWALK_OUT + depth * rng.randf_range(0.3, 0.7))
		kit.cylinder(Transform3D(Basis.IDENTITY, Vector3(tx, h, zc + rng.randf_range(-1.5, 1.5))), 0.6, 0.55, 1.1, 8, Color(0.08, 0.08, 0.09))

	if colmado:
		_colmado_front(s, z0, z1, h, wall)


func _colmado_front(s: float, z0: float, z1: float, h: float, wall: Color) -> void:
	var fx := s * L.SIDEWALK_OUT
	var n := Vector3(-s, 0, 0)
	var u := Vector3(0, 0, s)
	var zc := (z0 + z1) * 0.5
	var width := z0 - z1
	var sign_color: Color = [Color(0.8, 0.08, 0.1), Color(0.98, 0.85, 0.1), RoadLayout.DOMINICAN_BLUE][rng.randi() % 3]
	# Letrero
	kit.aabb(Vector3(minf(fx, fx - s * 0.15), 2.55, z1 + 0.4), Vector3(maxf(fx, fx - s * 0.15), 3.35, z0 - 0.4), sign_color, MeshKit.F_ALL)
	# Toldo inclinado
	var a_in := Vector3(fx, 2.45, 0)
	var a_out := Vector3(fx - s * 1.8, 2.0, 0)
	var tl := Vector3(a_in.x, a_in.y, z1 + 0.3)
	var tr := Vector3(a_in.x, a_in.y, z0 - 0.3)
	var br := Vector3(a_out.x, a_out.y, z0 - 0.3)
	var bl := Vector3(a_out.x, a_out.y, z1 + 0.3)
	var awning := Color(0.9, 0.9, 0.88) if sign_color != Color(0.98, 0.85, 0.1) else Color(0.8, 0.1, 0.12)
	if s > 0:
		kit.quad(tl, tr, br, bl, awning)
	else:
		kit.quad(tr, tl, bl, br, awning)
	# Puerta ancha abierta
	kit.face(Vector3(fx - s * 0.03, 1.2, zc), u * minf(1.8, width * 0.3), Vector3(0, 1.2, 0), n, Color(0.3, 0.22, 0.14))
	# Cajas de refrescos y sillas plásticas en la acera
	var cx := s * (L.SIDEWALK_OUT - 0.6)
	for i in rng.randi_range(2, 4):
		var cz := z1 + 0.8 + i * 0.55
		var crate: Color = [Color(0.8, 0.1, 0.1), Color(0.95, 0.8, 0.1), Color(0.1, 0.3, 0.7)][i % 3]
		for k in rng.randi_range(1, 4):
			kit.aabb(Vector3(cx - 0.25, 0.16 + k * 0.3, cz - 0.22), Vector3(cx + 0.25, 0.46 + k * 0.3, cz + 0.22), crate, MeshKit.F_NO_BOTTOM)
	for i in 2:
		var chx := s * (L.SIDEWALK_OUT - 1.4)
		var chz := z0 - 1.2 - i * 0.9
		kit.aabb(Vector3(chx - 0.22, 0.56, chz - 0.22), Vector3(chx + 0.22, 0.62, chz + 0.22), Color(0.95, 0.95, 0.95))
		kit.aabb(Vector3(chx + s * 0.2 - 0.03, 0.62, chz - 0.22), Vector3(chx + s * 0.2 + 0.03, 1.05, chz + 0.22), Color(0.95, 0.95, 0.95))
		kit.aabb(Vector3(chx - 0.2, 0.16, chz - 0.2), Vector3(chx + 0.2, 0.56, chz + 0.2), Color(0.9, 0.9, 0.9), MeshKit.F_POS_X | MeshKit.F_NEG_X)
	var name: String = COLMADO_NAMES[rng.randi() % COLMADO_NAMES.size()]
	result["colmados"].append({
		"pos": Vector3(fx - s * 0.17, 2.95, zc),
		"rot_y": -s * PI * 0.5,
		"text": name,
		"dark_text": sign_color == Color(0.98, 0.85, 0.1),
	})


func _poles_and_wires(side: float) -> void:
	var s := side
	var px := s * 9.6
	var zs := [-2.0, -27.0] if s > 0 else [-14.5, -39.5]
	for pz in zs:
		kit.cylinder(Transform3D(Basis.IDENTITY, Vector3(px, 0.16, pz)), 0.16, 0.11, 9.2, 6, POLE)
		kit.box(Transform3D(Basis.IDENTITY, Vector3(px - s * 0.4, 8.4, pz)), Vector3(1.9, 0.12, 0.12), POLE.darkened(0.2), MeshKit.F_ALL)
		if rng.randf() < 0.5:
			kit.cylinder(Transform3D(Basis.IDENTITY, Vector3(px + s * 0.35, 7.0, pz)), 0.28, 0.28, 0.9, 6, Color(0.35, 0.37, 0.36))
	# Cables hacia el siguiente poste (25 m), con comba. Continúan entre tramos.
	for pz in zs:
		var za: float = pz
		var zb: float = pz - 25.0
		var zm := (za + zb) * 0.5
		var offs := [Vector2(-1.2, 8.45), Vector2(-0.6, 8.45), Vector2(0.2, 8.45), Vector2(0.0, 7.4), Vector2(-0.3, 6.9)]
		for i in offs.size():
			var o: Vector2 = offs[i]
			var x := px + s * o.x
			var sag := 0.45 + i * 0.18
			var a := Vector3(x, o.y, za)
			var m1 := Vector3(x, o.y - sag * 0.75, lerpf(za, zb, 0.25))
			var m := Vector3(x, o.y - sag, zm)
			var m2 := Vector3(x, o.y - sag * 0.75, lerpf(za, zb, 0.75))
			var b := Vector3(x, o.y, zb)
			kit.beam(a, m1, 0.03, WIRE)
			kit.beam(m1, m, 0.03, WIRE)
			kit.beam(m, m2, 0.03, WIRE)
			kit.beam(m2, b, 0.03, WIRE)


func _palms_and_flags(side: float) -> void:
	var s := side
	var z := -rng.randf_range(4.0, 10.0)
	while z > -L.SEG_LEN + 3.0:
		var r := rng.randf()
		if r < float(style["palm"]) * 0.5:
			_palm(Vector3(s * 10.7, 0.16, z))
		elif r < float(style["palm"]) * 0.5 + float(style["flag"]) * 0.25:
			_flagpole(s, Vector3(s * 10.3, 0.16, z))
		z -= rng.randf_range(9.0, 17.0)


func _palm(base: Vector3) -> void:
	var height := rng.randf_range(6.0, 8.5)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var segs := 5
	var prev := base
	for i in segs:
		var t := float(i + 1) / segs
		var p := base + Vector3(0, height * t, 0) + lean * t * t
		var dir := (p - prev).normalized()
		var ref := Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var bx := ref.cross(dir).normalized()
		var bz := bx.cross(dir).normalized()
		kit.cylinder(Transform3D(Basis(bx, dir, bz), prev), 0.2 - 0.02 * i, 0.18 - 0.02 * i, (p - prev).length() + 0.05, 6, TRUNK.darkened(0.04 * (i % 2)), false)
		prev = p
	var top := prev
	var fronds := rng.randi_range(7, 9)
	for i in fronds:
		var ang := TAU * i / fronds + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var length := rng.randf_range(2.6, 3.4)
		var mid := top + dir * length * 0.5 + Vector3(0, 0.35, 0)
		var tip := top + dir * length + Vector3(0, -1.1, 0)
		var side_v := dir.cross(Vector3.UP).normalized() * 0.35
		var c := FROND.lightened(rng.randf_range(-0.05, 0.08))
		# Dos planchas por fronda (base→medio, medio→punta), visibles por arriba y por abajo
		kit.quad(top - side_v * 0.3, top + side_v * 0.3, mid + side_v, mid - side_v, c)
		kit.quad(top + side_v * 0.3, top - side_v * 0.3, mid - side_v, mid + side_v, c.darkened(0.15))
		kit.quad(mid - side_v, mid + side_v, tip + side_v * 0.1, tip - side_v * 0.1, c)
		kit.quad(mid + side_v, mid - side_v, tip - side_v * 0.1, tip + side_v * 0.1, c.darkened(0.15))
	for i in 3:
		var a := TAU * i / 3.0
		kit.box(Transform3D(Basis.IDENTITY, top + Vector3(cos(a) * 0.22, -0.25, sin(a) * 0.22)), Vector3(0.22, 0.22, 0.22), Color(0.4, 0.33, 0.12), MeshKit.F_ALL)


func _flagpole(s: float, base: Vector3) -> void:
	kit.cylinder(Transform3D(Basis.IDENTITY, base), 0.06, 0.045, 7.2, 6, Color(0.93, 0.93, 0.93))
	kit.box(Transform3D(Basis.IDENTITY, base + Vector3(0, 7.28, 0)), Vector3(0.14, 0.14, 0.14), Color(0.85, 0.7, 0.2), MeshKit.F_ALL)
	add_flag(flag_kit, base + Vector3(0, 7.05, 0), -s, 1.9, 1.2)


## Bandera dominicana simplificada (cuarteles azul y rojo con cruz blanca).
## `toward` = dirección en X hacia donde se extiende la tela desde el asta (+1 / -1).
static func add_flag(fk: MeshKit, top: Vector3, toward: float, length: float, height: float) -> void:
	var us := [0.0, 0.22, 0.44, 0.56, 0.78, 1.0]
	var vs := [0.0, 0.21, 0.42, 0.58, 0.79, 1.0]
	for i in us.size() - 1:
		for j in vs.size() - 1:
			var u0: float = us[i]
			var u1: float = us[i + 1]
			var v0: float = vs[j]
			var v1: float = vs[j + 1]
			var uc := (u0 + u1) * 0.5
			var vc := (v0 + v1) * 0.5
			var color := Color.WHITE
			var in_cross := (uc > 0.44 and uc < 0.56) or (vc > 0.42 and vc < 0.58)
			if not in_cross:
				var hoist := uc < 0.5
				var upper := vc < 0.5
				color = RoadLayout.DOMINICAN_BLUE if hoist == upper else RoadLayout.DOMINICAN_RED
			var xa := top.x + toward * u0 * length
			var xb := top.x + toward * u1 * length
			var y_top := top.y - v0 * height
			var y_bot := top.y - v1 * height
			var c := Vector3((xa + xb) * 0.5, (y_top + y_bot) * 0.5, top.z)
			var hu := Vector3(absf(xb - xa) * 0.5, 0, 0)
			var hv := Vector3(0, (y_top - y_bot) * 0.5, 0)
			# u de la cara crece hacia +X; mapear UV.x = distancia al asta
			var left_u := u1 if toward < 0 else u0
			var right_u := u0 if toward < 0 else u1
			fk.face(c, hu, hv, Vector3.BACK, color, Vector2(left_u, v0), Vector2(right_u, v1))

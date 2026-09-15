class_name RoadManager
extends Node3D
## Avenida infinita con memoria constante.
##
## - Al cargar se generan 3 variantes de tramo por avenida (12 mallas en total).
## - En juego solo existen POOL_SIZE nodos de tramo; cuando uno queda atrás se
##   recicla delante con la malla de la variante que le toque. No se crea ni se
##   destruye geometría mientras se maneja, así que no hay tirones de frame.
## - Coordenada de vía: s = metros recorridos = -z + shift_total. Cada
##   REBASE metros todo el mundo se desplaza hacia atrás para mantener la
##   precisión de punto flotante (evita temblores en VR a varios km).

signal loaded

const L = preload("res://scripts/road_layout.gd")
const VARIANTS_PER_AVENUE := 3
const POOL_SIZE := 13
const REBASE := 500.0

var segments_ahead := 10
var segments_behind := 2
var shift_total := 0.0

var static_material: StandardMaterial3D
var flag_material: ShaderMaterial
var variants: Array = []          # [avenue][variant] -> Dictionary de SegmentBuilder
var _pool: Array[Node3D] = []
var _active := {}                 # k -> nodo
var gantry: Node3D
var _gantry_label: Label3D
var _gantry_k := -99999
var is_loaded := false


func _ready() -> void:
	static_material = MeshKit.vertex_color_material()
	flag_material = ShaderMaterial.new()
	flag_material.shader = load("res://shaders/flag.gdshader")


## Genera las variantes repartidas en varios frames para no congelar el visor.
func generate(yield_between := true) -> void:
	var builder := SegmentBuilder.new()
	variants.clear()
	var total_vertices := 0
	for a in L.AVENIDAS.size():
		var list := []
		for v in VARIANTS_PER_AVENUE:
			var data := builder.build(a, v, static_material, flag_material)
			total_vertices += int(data["vertices"])
			list.append(data)
			if yield_between and is_inside_tree():
				await get_tree().process_frame
		variants.append(list)
	print("[RoadManager] variantes generadas: %d, vértices totales: %d" % [L.AVENIDAS.size() * VARIANTS_PER_AVENUE, total_vertices])
	_build_pool()
	_build_gantry()
	is_loaded = true
	loaded.emit()


func _build_pool() -> void:
	for i in POOL_SIZE:
		var node := Node3D.new()
		node.name = "Tramo%d" % i
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		for j in 3:
			var lbl := Label3D.new()
			lbl.name = "Letrero%d" % j
			lbl.font_size = 96
			lbl.pixel_size = 0.0042
			lbl.outline_size = 0
			lbl.modulate = Color.WHITE
			lbl.double_sided = false
			lbl.visible = false
			node.add_child(lbl)
		node.visible = false
		add_child(node)
		_pool.append(node)


func _build_gantry() -> void:
	gantry = Node3D.new()
	gantry.name = "PorticoAvenida"
	var kit := MeshKit.new()
	var green := Color(0.02, 0.38, 0.2)
	for x in [-9.4, 9.4]:
		kit.cylinder(Transform3D(Basis.IDENTITY, Vector3(x, 0.16, 0)), 0.22, 0.2, 7.0, 8, Color(0.6, 0.6, 0.6))
	kit.box(Transform3D(Basis.IDENTITY, Vector3(0, 6.9, 0)), Vector3(19.2, 0.35, 0.35), Color(0.55, 0.55, 0.55), MeshKit.F_ALL)
	kit.box(Transform3D(Basis.IDENTITY, Vector3(3.3, 6.2, 0.2)), Vector3(7.6, 1.6, 0.12), green, MeshKit.F_ALL)
	kit.box(Transform3D(Basis.IDENTITY, Vector3(3.3, 6.2, 0.27)), Vector3(7.4, 1.45, 0.02), Color(0.95, 0.95, 0.95), MeshKit.F_POS_Z)
	kit.box(Transform3D(Basis.IDENTITY, Vector3(3.3, 6.2, 0.29)), Vector3(7.25, 1.3, 0.02), green, MeshKit.F_POS_Z)
	var fk := MeshKit.new()
	SegmentBuilder.add_flag(fk, Vector3(-9.2, 7.6, 0.4), 1.0, 1.6, 1.0)
	SegmentBuilder.add_flag(fk, Vector3(9.2, 7.6, 0.4), -1.0, 1.6, 1.0)
	var mesh := kit.commit(static_material)
	fk.commit_to(mesh, flag_material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gantry.add_child(mi)
	_gantry_label = Label3D.new()
	_gantry_label.font_size = 128
	_gantry_label.pixel_size = 0.0075
	_gantry_label.position = Vector3(3.3, 6.2, 0.31)
	_gantry_label.modulate = Color.WHITE
	_gantry_label.outline_size = 0
	gantry.add_child(_gantry_label)
	gantry.visible = false
	add_child(gantry)


func segment_index_at(s: float) -> int:
	return floori(s / L.SEG_LEN)


func avenue_name_at(s: float) -> String:
	return L.AVENIDAS[L.avenue_for_segment(segment_index_at(s))]


func tramo_index_at(s: float) -> int:
	return floori(s / (L.SEG_LEN * L.TRAMO_SEGMENTS))


func road_s(z: float) -> float:
	return -z + shift_total


func world_z(s: float) -> float:
	return shift_total - s


## Mantiene visibles los tramos alrededor de la posición s del jugador.
func update_visible(player_s: float) -> void:
	if not is_loaded:
		return
	var kp := segment_index_at(player_s)
	var k_min := kp - segments_behind
	var k_max := kp + segments_ahead
	# Liberar tramos fuera de rango
	for k in _active.keys():
		if k < k_min or k > k_max:
			var node: Node3D = _active[k]
			node.visible = false
			_active.erase(k)
	# Asignar nodos libres a tramos que faltan
	for k in range(k_min, k_max + 1):
		if _active.has(k):
			continue
		var node := _free_node()
		if node == null:
			break
		_assign(node, k)
		_active[k] = node
	# Reposicionar (cambia shift_total con cada rebase)
	for k in _active:
		(_active[k] as Node3D).position = Vector3(0, 0, world_z(k * L.SEG_LEN))
	# Pórtico con el nombre de la avenida al inicio de cada tramo visible
	var next_tramo_k := ceili(float(kp) / L.TRAMO_SEGMENTS) * L.TRAMO_SEGMENTS
	if next_tramo_k - kp > segments_ahead:
		next_tramo_k = floori(float(kp) / L.TRAMO_SEGMENTS) * L.TRAMO_SEGMENTS
	if next_tramo_k != _gantry_k:
		_gantry_k = next_tramo_k
		_gantry_label.text = L.AVENIDAS[L.avenue_for_segment(next_tramo_k)]
	gantry.visible = next_tramo_k >= k_min
	gantry.position = Vector3(0, 0, world_z(next_tramo_k * L.SEG_LEN) - 0.5)


func _free_node() -> Node3D:
	for n in _pool:
		if not n.visible:
			return n
	return null


func variant_for(k: int) -> Dictionary:
	var a := L.avenue_for_segment(k)
	var v := posmod(hash(k * 31 + 7), VARIANTS_PER_AVENUE)
	return variants[a][v]


func _assign(node: Node3D, k: int) -> void:
	var data := variant_for(k)
	(node.get_node("Mesh") as MeshInstance3D).mesh = data["mesh"]
	var colmados: Array = data["colmados"]
	for j in 3:
		var lbl: Label3D = node.get_node("Letrero%d" % j)
		if j < colmados.size():
			var c: Dictionary = colmados[j]
			lbl.text = c["text"]
			lbl.position = c["pos"]
			lbl.rotation = Vector3(0, c["rot_y"], 0)
			lbl.modulate = Color(0.1, 0.1, 0.1) if c["dark_text"] else Color.WHITE
			lbl.visible = true
		else:
			lbl.visible = false
	node.set_meta("k", k)
	node.visible = true


func active_segment_count() -> int:
	return _active.size()


func pool_size() -> int:
	return _pool.size()


## Carros estacionados (posición mundial) cerca de la coordenada s.
func parked_near(s: float, radius: float) -> Array:
	var out := []
	var k0 := segment_index_at(s - radius)
	var k1 := segment_index_at(s + radius)
	for k in range(k0, k1 + 1):
		if not variants.size():
			break
		var data := variant_for(k)
		var base_z := world_z(k * L.SEG_LEN)
		for p: Vector3 in data["parked"]:
			out.append(Vector3(p.x, 0, base_z + p.z))
	return out


## Huecos entre carros estacionados en el rango [s_min, s_max] (posición mundial).
func ped_gaps_between(s_min: float, s_max: float) -> Array:
	var out := []
	var k0 := segment_index_at(s_min)
	var k1 := segment_index_at(s_max)
	for k in range(k0, k1 + 1):
		var data := variant_for(k)
		var base_z := world_z(k * L.SEG_LEN)
		for g: Vector3 in data["ped_gaps"]:
			var wz := base_z + g.z
			var gs := road_s(wz)
			if gs >= s_min and gs <= s_max:
				out.append(Vector3(g.x, 0, wz))
	return out


## Aplica el rebase: el llamador mueve jugador y tráfico; aquí solo se registra.
func apply_rebase(amount: float) -> void:
	shift_total += amount

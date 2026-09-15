class_name MeshKit
extends RefCounted
## Constructor de geometría low-poly con color por vértice.
## Todo lo que se agrega termina en UNA superficie (un draw call), que es lo que
## permite sostener 72 fps en Quest con una ciudad entera generada por código.
##
## Convención de caras: Godot usa orden horario para las caras frontales.
## Cada cara se define por centro, normal y dos ejes (u a la derecha, v arriba)
## con u × v = normal.

var st := SurfaceTool.new()
var vertex_count := 0

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Cara rectangular. c = centro, hu/hv = medio eje u/v (ya escalados), n = normal.
func face(c: Vector3, hu: Vector3, hv: Vector3, n: Vector3, color: Color,
		uv_min := Vector2.ZERO, uv_max := Vector2.ONE) -> void:
	var tl := c - hu + hv
	var tr := c + hu + hv
	var br := c + hu - hv
	var bl := c - hu - hv
	var uv_tl := Vector2(uv_min.x, uv_min.y)
	var uv_tr := Vector2(uv_max.x, uv_min.y)
	var uv_br := Vector2(uv_max.x, uv_max.y)
	var uv_bl := Vector2(uv_min.x, uv_max.y)
	_vtx(tl, n, color, uv_tl)
	_vtx(tr, n, color, uv_tr)
	_vtx(br, n, color, uv_br)
	_vtx(tl, n, color, uv_tl)
	_vtx(br, n, color, uv_br)
	_vtx(bl, n, color, uv_bl)


## Cuadrilátero libre con cuatro esquinas en orden horario visto desde el frente.
func quad(tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3, color: Color) -> void:
	var n := (br - tl).cross(tr - tl).normalized()
	_vtx(tl, n, color, Vector2(0, 0))
	_vtx(tr, n, color, Vector2(1, 0))
	_vtx(br, n, color, Vector2(1, 1))
	_vtx(tl, n, color, Vector2(0, 0))
	_vtx(br, n, color, Vector2(1, 1))
	_vtx(bl, n, color, Vector2(0, 1))


const F_POS_X := 1
const F_NEG_X := 2
const F_POS_Y := 4
const F_NEG_Y := 8
const F_POS_Z := 16
const F_NEG_Z := 32
const F_ALL := 63
const F_NO_BOTTOM := 63 & ~8


## Caja transformada. xf.origin es el centro de la caja.
func box(xf: Transform3D, size: Vector3, color: Color, faces := F_NO_BOTTOM) -> void:
	var b := xf.basis
	var o := xf.origin
	var hx := b.x * (size.x * 0.5)
	var hy := b.y * (size.y * 0.5)
	var hz := b.z * (size.z * 0.5)
	var nx := b.x.normalized()
	var ny := b.y.normalized()
	var nz := b.z.normalized()
	if faces & F_POS_X:
		face(o + hx, -hz, hy, nx, color)
	if faces & F_NEG_X:
		face(o - hx, hz, hy, -nx, color)
	if faces & F_POS_Y:
		face(o + hy, hx, -hz, ny, color.lightened(0.04))
	if faces & F_NEG_Y:
		face(o - hy, hx, hz, -ny, color.darkened(0.2))
	if faces & F_POS_Z:
		face(o + hz, hx, hy, nz, color)
	if faces & F_NEG_Z:
		face(o - hz, -hx, hy, -nz, color)


## Caja alineada a ejes a partir de esquinas mínima y máxima.
func aabb(mn: Vector3, mx: Vector3, color: Color, faces := F_NO_BOTTOM) -> void:
	box(Transform3D(Basis.IDENTITY, (mn + mx) * 0.5), mx - mn, color, faces)


## Cilindro (o cono truncado) con eje Y local; xf.origin es la base.
func cylinder(xf: Transform3D, r_bottom: float, r_top: float, height: float,
		sides: int, color: Color, cap_top := true) -> void:
	var b := xf.basis
	var o := xf.origin
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0b := o + b * (d0 * r_bottom)
		var p1b := o + b * (d1 * r_bottom)
		var p0t := o + b * (d0 * r_top + Vector3(0, height, 0))
		var p1t := o + b * (d1 * r_top + Vector3(0, height, 0))
		# Visto desde fuera: p1 queda a la izquierda de p0 (ángulo crece hacia +Z).
		var n0 := (b * d0).normalized()
		var n1 := (b * d1).normalized()
		_vtx(p1t, n1, color, Vector2.ZERO)
		_vtx(p0t, n0, color, Vector2.ZERO)
		_vtx(p0b, n0, color, Vector2.ZERO)
		_vtx(p1t, n1, color, Vector2.ZERO)
		_vtx(p0b, n0, color, Vector2.ZERO)
		_vtx(p1b, n1, color, Vector2.ZERO)
		if cap_top and r_top > 0.001:
			var up := b.y.normalized()
			var ct := o + b * Vector3(0, height, 0)
			_vtx(ct, up, color, Vector2.ZERO)
			_vtx(p0t, up, color, Vector2.ZERO)
			_vtx(p1t, up, color, Vector2.ZERO)


## Barra delgada entre dos puntos (cables, postes inclinados, marcos).
func beam(a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		return
	var z := dir / length
	var ref := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	var y := z.cross(x).normalized()
	box(Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(thickness, thickness, length), color, F_ALL & ~(F_POS_Z | F_NEG_Z))


func _vtx(p: Vector3, n: Vector3, c: Color, uv: Vector2) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)
	vertex_count += 1


## Añade la geometría acumulada como una superficie nueva en `mesh`.
func commit_to(mesh: ArrayMesh, material: Material) -> ArrayMesh:
	if vertex_count == 0:
		return mesh
	st.set_material(material)
	st.commit(mesh)
	return mesh


func commit(material: Material) -> ArrayMesh:
	return commit_to(ArrayMesh.new(), material)


## Material común: color por vértice, sombreado por vértice (barato en Quest).
static func vertex_color_material(unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

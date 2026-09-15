class_name UIPanel3D
extends Node3D
## Panel de interfaz flotante en el espacio: una SubViewport con controles 2D
## proyectada sobre un rectángulo 3D. El rayo del mando (o el ratón) se
## intersecta matemáticamente con el plano y se convierte en eventos de ratón.

var viewport: SubViewport
var quad_size := Vector2(1.6, 1.0)
var pixel_size := Vector2i(1280, 800)
var _mesh: MeshInstance3D
var _hover := false
var _last_pixel := Vector2(-1, -1)


func setup(p_quad_size: Vector2, p_pixels: Vector2i, content: Control) -> void:
	quad_size = p_quad_size
	pixel_size = p_pixels
	viewport = SubViewport.new()
	viewport.name = "Interfaz"
	viewport.size = pixel_size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	content.size = Vector2(pixel_size)
	viewport.add_child(content)

	var quad := QuadMesh.new()
	quad.size = quad_size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 125
	mat.albedo_texture = viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	_mesh.material_override = mat
	_mesh.layers = 1 << 2
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## Intersección del rayo con el panel. Devuelve el punto mundial o null.
func intersect(from: Vector3, dir: Vector3) -> Variant:
	if not visible:
		return null
	var t := global_transform
	var n := t.basis.z.normalized()
	var denom := n.dot(dir)
	if absf(denom) < 0.0001:
		return null
	var d := n.dot(t.origin - from) / denom
	if d <= 0.0:
		return null
	var hit := from + dir * d
	var local := t.affine_inverse() * hit
	if absf(local.x) > quad_size.x * 0.5 or absf(local.y) > quad_size.y * 0.5:
		return null
	return hit


func _to_pixel(hit: Vector3) -> Vector2:
	var local := global_transform.affine_inverse() * hit
	return Vector2((local.x / quad_size.x + 0.5) * pixel_size.x, (0.5 - local.y / quad_size.y) * pixel_size.y)


## Mueve el puntero sobre el panel. Devuelve true si el rayo toca el panel.
func pointer_move(from: Vector3, dir: Vector3) -> Variant:
	var hit = intersect(from, dir)
	if hit == null:
		if _hover:
			_hover = false
			var away := InputEventMouseMotion.new()
			away.position = Vector2(-100, -100)
			away.global_position = away.position
			viewport.push_input(away)
		return null
	_hover = true
	var px := _to_pixel(hit)
	if px.distance_to(_last_pixel) > 0.5:
		var ev := InputEventMouseMotion.new()
		ev.position = px
		ev.global_position = px
		ev.relative = px - _last_pixel
		viewport.push_input(ev)
		_last_pixel = px
	return hit


func pointer_click() -> bool:
	if not _hover:
		return false
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = _last_pixel
		ev.global_position = _last_pixel
		viewport.push_input(ev)
	return true

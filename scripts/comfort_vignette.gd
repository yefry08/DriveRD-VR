class_name ComfortVignette
extends MeshInstance3D
## Viñeta dinámica: oscurece el campo periférico cuando el carro acelera, frena
## o gira, que es cuando el oído interno y la vista se contradicen.
## También hace los fundidos a negro (choque, recentrado, cambio de pantalla)
## para que el cuerpo nunca vea un salto de cámara.

var strength := 1.0           # ajuste del menú: 0.5 baja, 1.0 media, 1.4 alta
var _intensity := 0.0
var _fade := 0.0
var _fade_target := 0.0
var _fade_speed := 3.0
var _mat: ShaderMaterial


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mesh = quad
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/vignette.gdshader")
	_mat.render_priority = 120
	material_override = _mat
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = 1 << 2
	position = Vector3(0, 0, -0.2)


## accel en m/s², yaw_rate en rad/s.
func update_motion(dt: float, accel: float, yaw_rate: float, active: bool) -> void:
	var target := 0.0
	if active:
		target = absf(yaw_rate) * 1.5 + maxf(accel, 0.0) * 0.12 + maxf(-accel - 1.0, 0.0) * 0.07
		target = clampf(target * strength, 0.0, 1.0)
	# Sube rápido, baja despacio: evita parpadeos
	var rate := 4.0 if target > _intensity else 1.2
	_intensity = move_toward(_intensity, target, dt * rate)
	_fade = move_toward(_fade, _fade_target, dt * _fade_speed)
	_mat.set_shader_parameter("intensity", _intensity)
	_mat.set_shader_parameter("fade", _fade)
	visible = _intensity > 0.002 or _fade > 0.002


func fade_to(value: float, speed := 3.0) -> void:
	_fade_target = value
	_fade_speed = speed


func set_fade_now(value: float) -> void:
	_fade = value
	_fade_target = value


func is_fade_done() -> bool:
	return is_equal_approx(_fade, _fade_target)


func current_intensity() -> float:
	return _intensity

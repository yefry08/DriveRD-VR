class_name DashboardDisplay
extends Control
## Cuadro de instrumentos que se dibuja en una textura sobre el tablero del carro.
## Velocímetro, tacómetro, indicador de DEFENSA, puntos, avenida,
## luces de alerta y un aviso corto.

const SIZE := Vector2(1024, 400)
const BG := Color(0.03, 0.035, 0.045)
const DIM := Color(0.28, 0.3, 0.33)
const TEXT := Color(0.92, 0.94, 0.96)
const GOOD := Color(0.2, 0.85, 0.35)
const BAD := Color(0.95, 0.2, 0.18)
const WARN := Color(1.0, 0.68, 0.1)
const INFO := Color(0.45, 0.72, 1.0)

## Luces de alerta, en el orden en que aparecen en el tablero.
const LIGHTS := [
	["velocidad", "VELOCIDAD"],
	["distancia", "DISTANCIA"],
	["contravia", "CONTRAVÍA"],
	["via", "FUERA DE VÍA"],
	["moto", "MOTO LADO"],
	["peaton", "PEATÓN"],
]

var speed_kmh := 0.0
var rpm := 800.0
var defense := 60.0
var score := 1000
var avenue := ""
var gear := 1
var lights := {}
var message := ""
var message_kind := "info"
var message_time := 0.0
var _blink := 0.0
var font: Font


func _ready() -> void:
	size = SIZE
	font = ThemeDB.fallback_font


func show_message(text: String, kind: String) -> void:
	message = text
	message_kind = kind
	message_time = 3.0


func tick(dt: float) -> void:
	_blink += dt
	message_time = maxf(0.0, message_time - dt)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	draw_rect(Rect2(Vector2(4, 4), SIZE - Vector2(8, 8)), Color(0.12, 0.13, 0.15), false, 3.0)
	_gauge(Vector2(175, 185), 150.0, speed_kmh / 160.0, "%d" % roundi(speed_kmh), "km/h", 160, 20,
		WARN if speed_kmh > 80.0 else TEXT, 80.0 / 160.0, 90.0 / 160.0)
	_gauge(Vector2(849, 185), 150.0, rpm / 7000.0, "%d" % gear, "cambio · rpm x1000", 7, 1, TEXT, 5.5 / 7.0, 1.0)
	_defense(Vector2(512, 175))
	_lights_row(Vector2(512, 338))
	if message_time > 0.0:
		var c := GOOD if message_kind == "bien" else (BAD if message_kind == "mal" else INFO)
		c.a = clampf(message_time * 2.0, 0.0, 1.0)
		_text_center(message, Vector2(512, 392), 30, c)


func _gauge(center: Vector2, radius: float, t: float, big: String, unit: String, max_label: int,
		step: int, big_color: Color, warn_from: float, red_from: float) -> void:
	var a0 := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	draw_arc(center, radius, a0, a0 + sweep, 64, DIM, 6.0, true)
	draw_arc(center, radius, a0 + sweep * warn_from, a0 + sweep * red_from, 24, WARN, 8.0, true)
	if red_from < 1.0:
		draw_arc(center, radius, a0 + sweep * red_from, a0 + sweep, 24, BAD, 8.0, true)
	var n := max_label / step
	for i in n + 1:
		var a := a0 + sweep * float(i) / n
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (radius - 18), center + dir * (radius - 2), TEXT, 3.0, true)
		_text_center(str(i * step), center + dir * (radius - 40) + Vector2(0, 8), 20, Color(0.75, 0.78, 0.8))
	var needle_a := a0 + sweep * clampf(t, 0.0, 1.0)
	var nd := Vector2(cos(needle_a), sin(needle_a))
	draw_line(center - nd * 12, center + nd * (radius - 10), BAD, 5.0, true)
	draw_circle(center, 10, Color(0.8, 0.8, 0.82))
	_text_center(big, center + Vector2(0, 62), 48, big_color)
	_text_center(unit, center + Vector2(0, 92), 18, Color(0.65, 0.68, 0.7))


func _defense(center: Vector2) -> void:
	var radius := 105.0
	var a0 := deg_to_rad(180.0)
	draw_arc(center, radius, a0, a0 + PI, 48, DIM, 22.0, true)
	var t := defense / 100.0
	var c := BAD.lerp(WARN, clampf(t * 2.0, 0, 1)) if t < 0.5 else WARN.lerp(GOOD, clampf((t - 0.5) * 2.0, 0, 1))
	if t > 0.005:
		draw_arc(center, radius, a0, a0 + PI * t, 48, c, 22.0, true)
	_text_center("DEFENSA", center + Vector2(0, -34), 24, Color(0.75, 0.78, 0.8))
	_text_center("%d%%" % roundi(defense), center + Vector2(0, 12), 44, c)
	_text_center("PUNTOS  %d" % score, center + Vector2(0, 62), 32, TEXT)
	_text_center(avenue, center + Vector2(0, 100), 24, INFO)


func _lights_row(center: Vector2) -> void:
	var w := 150.0
	var start := center.x - w * (LIGHTS.size() - 1) * 0.5
	var blink_on := fmod(_blink, 0.5) < 0.3
	for i in LIGHTS.size():
		var key: String = LIGHTS[i][0]
		var label: String = LIGHTS[i][1]
		var on: bool = lights.get(key, false)
		var p := Vector2(start + i * w, center.y)
		var col := DIM
		if on:
			col = (WARN if key in ["moto", "distancia"] else BAD) if blink_on else Color(0.35, 0.12, 0.08)
		draw_rect(Rect2(p - Vector2(68, 18), Vector2(136, 34)), col if on else Color(0.08, 0.09, 0.1))
		draw_rect(Rect2(p - Vector2(68, 18), Vector2(136, 34)), col, false, 2.0)
		_text_center(label, p + Vector2(0, 7), 17, Color(0.05, 0.05, 0.05) if on and blink_on else Color(0.55, 0.58, 0.6))


func _text_center(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(pos.x - w * 0.5, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

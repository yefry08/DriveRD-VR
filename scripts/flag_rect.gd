class_name FlagRect
extends Control
## Bandera dominicana dibujada con primitivas (cuarteles y cruz blanca, con un
## escudo simplificado en el centro).

func _draw() -> void:
	var w := size.x
	var h := size.y
	var cross_w := w * 0.14
	var cross_h := h * 0.18
	var cx := (w - cross_w) * 0.5
	var cy := (h - cross_h) * 0.5
	draw_rect(Rect2(0, 0, w, h), Color.WHITE)
	draw_rect(Rect2(0, 0, cx, cy), RoadLayout.DOMINICAN_BLUE)
	draw_rect(Rect2(cx + cross_w, 0, w - cx - cross_w, cy), RoadLayout.DOMINICAN_RED)
	draw_rect(Rect2(0, cy + cross_h, cx, h - cy - cross_h), RoadLayout.DOMINICAN_RED)
	draw_rect(Rect2(cx + cross_w, cy + cross_h, w - cx - cross_w, h - cy - cross_h), RoadLayout.DOMINICAN_BLUE)
	# Escudo simplificado
	var c := Vector2(w * 0.5, h * 0.5)
	var s := minf(cross_w, cross_h) * 0.42
	draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s)), RoadLayout.DOMINICAN_BLUE)
	draw_rect(Rect2(c - Vector2(0, s), Vector2(s, s)), RoadLayout.DOMINICAN_RED)
	draw_rect(Rect2(c - Vector2(s, 0), Vector2(s, s)), RoadLayout.DOMINICAN_RED)
	draw_rect(Rect2(c, Vector2(s, s)), RoadLayout.DOMINICAN_BLUE)
	draw_arc(c, s * 1.5, PI * 0.15, PI * 0.85, 12, Color(0.1, 0.5, 0.2), 2.5)
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35), false, 2.0)

class_name MenuUI
extends Control
## Contenido 2D del panel flotante: carga, menú principal, instrucciones,
## pausa y resumen del recorrido. Todo el texto en español dominicano.

signal start_pressed
signal resume_pressed
signal recenter_pressed
signal end_pressed
signal menu_pressed
signal settings_changed

const W := 1280
const H := 800
const BLUE := Color(0.0, 0.176, 0.384)
const RED := Color(0.808, 0.067, 0.149)
const PANEL := Color(0.035, 0.06, 0.1, 0.94)

var scheme := 0          # 0 mandos, 1 volante
var route := 0           # 0 corto (4 tramos), 1 libre
var vignette := 1        # 0 baja, 1 media, 2 alta

var pages := {}
var _scheme_btn: Button
var _route_btn: Button
var _vignette_btn: Button
var _loading_label: Label
var _summary_box: VBoxContainer
var _summary_title: Label
var _summary_score: Label
var _summary_rating: Label
var _theme: Theme


func _ready() -> void:
	size = Vector2(W, H)
	_theme = _make_theme()
	theme = _theme
	_build_loading()
	_build_main()
	_build_help()
	_build_pause()
	_build_summary()
	show_page("carga")


func show_page(page: String) -> void:
	for k in pages:
		(pages[k] as Control).visible = k == page
	var first := _first_button(pages[page])
	if first:
		first.grab_focus()


func current_page() -> String:
	for k in pages:
		if (pages[k] as Control).visible:
			return k
	return ""


func set_loading_text(t: String) -> void:
	_loading_label.text = t


# ------------------------------------------------------------------ construcción

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 34
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.16, 0.26)
	normal.border_color = Color(0.3, 0.45, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BLUE.lightened(0.15)
	hover.border_color = Color.WHITE
	hover.set_border_width_all(4)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = RED
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("focus", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_font_size("font_size", "Button", 36)
	th.set_color("font_color", "Label", Color(0.93, 0.95, 0.97))
	return th


func _page(page_name: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = page_name
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(28)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_border_width_all(3)
	sb.content_margin_left = 60
	sb.content_margin_right = 60
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2.ZERO
	p.size = Vector2(W, H)
	add_child(p)
	pages[page_name] = p
	return p


func _header(parent: Container, subtitle: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)
	parent.add_child(row)
	var flag := FlagRect.new()
	flag.custom_minimum_size = Vector2(186, 120)
	row.add_child(flag)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -8)
	row.add_child(words)
	var mark := Label.new()
	mark.text = "DRIVE RD"
	mark.add_theme_font_size_override("font_size", 104)
	mark.add_theme_color_override("font_color", Color.WHITE)
	mark.add_theme_color_override("font_outline_color", BLUE)
	mark.add_theme_constant_override("outline_size", 10)
	words.add_child(mark)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	words.add_child(sub)
	# Franja tricolor
	var stripe := HBoxContainer.new()
	stripe.add_theme_constant_override("separation", 0)
	stripe.custom_minimum_size = Vector2(0, 8)
	parent.add_child(stripe)
	for c in [BLUE, Color.WHITE, RED]:
		var r := ColorRect.new()
		r.color = c
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.custom_minimum_size = Vector2(0, 8)
		stripe.add_child(r)


func _button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(620, 74)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _label(parent: Container, text: String, font_size := 30, color := Color(0.9, 0.92, 0.95), align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _vbox(parent: Control, sep := 18) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func _build_loading() -> void:
	var v := _vbox(_page("carga"), 40)
	_header(v, "Simulador de conducción defensiva · Santo Domingo")
	_loading_label = _label(v, "Levantando la ciudad…", 40)


func _build_main() -> void:
	var v := _vbox(_page("menu"), 16)
	_header(v, "Simulador de conducción defensiva · Santo Domingo")
	_label(v, "Empiezas con 1000 puntos. Tu trabajo es defenderlos.", 30, Color(1.0, 0.85, 0.4))
	_button(v, "▶  Arrancar", func(): start_pressed.emit())
	_scheme_btn = _button(v, "", _toggle_scheme)
	_route_btn = _button(v, "", _toggle_route)
	_vignette_btn = _button(v, "", _toggle_vignette)
	_button(v, "¿Cómo se maneja?", func(): show_page("ayuda"))
	_label(v, "Apunta con el mando y aprieta el gatillo · B o Y recentra la vista", 24, Color(0.65, 0.72, 0.8))
	_refresh_settings()


func _build_help() -> void:
	var v := _vbox(_page("ayuda"), 12)
	_label(v, "¿Cómo se maneja?", 54, Color.WHITE)
	var text := """[b]Mandos:[/b] gatillo derecho acelera, gatillo izquierdo frena, joystick izquierdo dirige.
[b]Volante:[/b] agarra el aro con los botones laterales de ambos mandos y gíralo; los gatillos siguen siendo acelerador y freno.
[b]B o Y:[/b] recentra la vista.  [b]Menú:[/b] pausa.

[color=#ffd166]Motoconchos:[/color] se meten sin avisar. Al rebasarlos déjales [b]más de 1.6 m[/b] y ve a menos de 85 km/h.
[color=#ffd166]Guaguas:[/color] frenan de golpe para recoger pasajeros. Guarda distancia.
[color=#ffd166]Peatones:[/color] salen de entre los carros estacionados. Si ves uno, frena y cede el paso.
[color=#ffd166]Contravía:[/color] nunca invadas el carril contrario para rebasar.

Suma: rebases con espacio, velocidad bajo 80, frenar a tiempo, completar tramos.
Resta: pasar de 90, rebasar pegao, contravía, salirte de la calzada, chocar."""
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.text = text
	rt.custom_minimum_size = Vector2(1140, 520)
	rt.add_theme_font_size_override("normal_font_size", 28)
	rt.add_theme_font_size_override("bold_font_size", 28)
	v.add_child(rt)
	_button(v, "Volver", func(): show_page("menu"))


func _build_pause() -> void:
	var v := _vbox(_page("pausa"), 26)
	_header(v, "Pausa")
	_button(v, "Seguir manejando", func(): resume_pressed.emit())
	_button(v, "Recentrar la vista", func(): recenter_pressed.emit())
	_button(v, "Terminar el recorrido", func(): end_pressed.emit())
	_button(v, "Menú principal", func(): menu_pressed.emit())


func _build_summary() -> void:
	var v := _vbox(_page("resumen"), 6)
	_summary_title = _label(v, "Resumen del recorrido", 44, Color.WHITE)
	_summary_score = _label(v, "", 64, Color(1.0, 0.85, 0.35))
	_summary_rating = _label(v, "", 28, Color(0.6, 0.9, 0.65))
	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 2)
	v.add_child(_summary_box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	var again := Button.new()
	again.text = "Manejar otra vez"
	again.custom_minimum_size = Vector2(440, 70)
	again.pressed.connect(func(): start_pressed.emit())
	row.add_child(again)
	var menu := Button.new()
	menu.text = "Menú principal"
	menu.custom_minimum_size = Vector2(440, 70)
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)


func fill_summary(data: Dictionary, rating: String, reason: String) -> void:
	_summary_title.text = "Resumen del recorrido"
	_summary_score.text = "%d puntos" % int(data["puntos"])
	_summary_rating.text = rating + ("" if reason == "" else "  ·  " + reason)
	for c in _summary_box.get_children():
		c.queue_free()
	var min_gap = data["separacion_minima_moto_m"]
	var rows := [
		["Kilómetros recorridos", "%.2f km" % float(data["km_recorridos"])],
		["Rebases seguros a motoconchos", "%d" % int(data["rebases_seguros_motoconchos"])],
		["Rebases pegaos a motoconchos", "%d" % int(data["rebases_pegados_motoconchos"])],
		["Velocidad máxima alcanzada", "%d km/h" % int(data["velocidad_maxima_kmh"])],
		["Segundos en conducta de riesgo", "%.1f s" % float(data["segundos_conducta_riesgo"])],
		["Choques", "%d" % int(data["choques"])],
		["Peatones a los que cediste el paso", "%d" % int(data["peatones_cedido_paso"])],
		["Frenadas anticipadas", "%d" % int(data["frenadas_anticipadas"])],
		["Menor separación con una moto", "—" if min_gap == null else "%.1f m" % float(min_gap)],
	]
	for r in rows:
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(980, 0)
		h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var k := Label.new()
		k.text = r[0]
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k.add_theme_font_size_override("font_size", 30)
		k.add_theme_color_override("font_color", Color(0.78, 0.83, 0.9))
		var val := Label.new()
		val.text = r[1]
		val.add_theme_font_size_override("font_size", 30)
		val.add_theme_color_override("font_color", Color.WHITE)
		h.add_child(k)
		h.add_child(val)
		_summary_box.add_child(h)


# ------------------------------------------------------------------ ajustes

func _toggle_scheme() -> void:
	scheme = (scheme + 1) % 2
	_refresh_settings()


func _toggle_route() -> void:
	route = (route + 1) % 2
	_refresh_settings()


func _toggle_vignette() -> void:
	vignette = (vignette + 1) % 3
	_refresh_settings()


func _refresh_settings() -> void:
	_scheme_btn.text = "Control: " + ["Mandos", "Volante virtual"][scheme]
	_route_btn.text = "Recorrido: " + ["4 tramos (2.4 km)", "Libre"][route]
	_vignette_btn.text = "Viñeta de confort: " + ["Baja", "Media", "Alta"][vignette]
	settings_changed.emit()


func _first_button(node: Node) -> Button:
	for c in node.get_children():
		if c is Button:
			return c
		var inner := _first_button(c)
		if inner:
			return inner
	return null


## Navegación con joystick: mueve el foco al botón anterior/siguiente.
func move_focus(step: int) -> void:
	var buttons: Array[Button] = []
	_collect_buttons(pages[current_page()], buttons)
	if buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var idx := buttons.find(focused)
	idx = clampi(idx + step, 0, buttons.size() - 1) if idx >= 0 else 0
	buttons[idx].grab_focus()


func press_focused() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and focused.is_visible_in_tree():
		(focused as Button).pressed.emit()


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	for c in node.get_children():
		if c is Button and (c as Button).is_visible_in_tree():
			out.append(c)
		_collect_buttons(c, out)

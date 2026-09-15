extends SceneTree
## Vista previa 2D de las pantallas del panel (menú, ayuda, pausa, resumen).
##   godot --path . -s tests/ui_preview.gd -- --out=CARPETA
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "user://ui_preview"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(MenuUI.W, MenuUI.H)
	var bg := ColorRect.new()
	bg.color = Color(0.3, 0.45, 0.6)
	bg.size = Vector2(MenuUI.W, MenuUI.H)
	root.add_child(bg)
	var menu := MenuUI.new()
	root.add_child(menu)
	var s := DriveScore.new()
	s.distance_m = 2412.0
	s.safe_moto_passes = 7
	s.close_moto_passes = 2
	s.max_kmh = 84.0
	s.risk_seconds = 23.4
	s.pedestrians_yielded = 3
	s.early_brakes = 5
	s.min_moto_gap = 1.1
	s.score = 1185.0
	for page in ["menu", "ayuda", "pausa", "resumen"]:
		if page == "resumen":
			menu.fill_summary(s.summary(), s.rating(), "Ruta completada")
		menu.show_page(page)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, page])
		print("guardado ", page)
	quit()

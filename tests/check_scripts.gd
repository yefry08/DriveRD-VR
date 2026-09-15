extends SceneTree
## Carga cada script del proyecto para detectar errores de parseo.
func _init() -> void:
	var failed := 0
	var dir := DirAccess.open("res://scripts")
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var s = load("res://scripts/" + f)
			if s == null or not (s as GDScript).can_instantiate():
				print("FALLA: ", f)
				failed += 1
	print("scripts con error: ", failed)
	quit(failed)

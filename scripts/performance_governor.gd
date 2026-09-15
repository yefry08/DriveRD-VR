class_name PerformanceGovernor
extends RefCounted
## Mantiene 72 fps como piso: si el tiempo de frame se pasa del presupuesto,
## baja calidad (espejos, distancia de dibujo, densidad de tráfico) antes que
## perder cuadros. Si hay margen durante un rato, intenta subir un nivel.
##
## Nivel 0: máxima calidad · Nivel 3: mínimo.

signal level_changed(level: int)

const WINDOW := 1.5
const UP_AFTER := 25.0

## Presupuesto de frame: 1/72 s en el visor; en escritorio se ajusta al monitor.
var budget := 1.0 / 72.0

var level := 0
var max_level_reached := 0
var _accum := 0.0
var _frames := 0
var _slow_frames := 0
var _warmup := 3.0
var _good_time := 0.0
var _cooldown := 3.0
var _failed_up_at := -1


## Llamar cada frame mientras se maneja con el delta real del frame.
func sample(frame_dt: float) -> void:
	if _warmup > 0.0:
		_warmup -= frame_dt
		return
	# Un tirón aislado (carga, recentrado del sistema) no es falta de rendimiento
	if frame_dt > 0.25:
		return
	_accum += frame_dt
	_frames += 1
	if frame_dt > budget * 1.5:
		_slow_frames += 1
	_cooldown = maxf(0.0, _cooldown - frame_dt)
	if _accum < WINDOW:
		return
	var avg := _accum / _frames
	var slow_ratio := float(_slow_frames) / _frames
	_accum = 0.0
	_frames = 0
	_slow_frames = 0
	# En VR el delta queda amarrado a la tasa del visor: si se sale, perdimos cuadros.
	var over := avg > budget * 1.08 or slow_ratio > 0.1
	if over and _cooldown <= 0.0 and level < 3:
		_failed_up_at = level
		_apply_level(level + 1)
		_good_time = 0.0
		_cooldown = 4.0
		return
	if not over and avg < budget * 1.02 and slow_ratio < 0.01:
		_good_time += WINDOW
		if _good_time >= UP_AFTER and level > 0 and _failed_up_at != level - 1:
			_apply_level(level - 1)
			_good_time = 0.0
			_cooldown = 6.0
	else:
		_good_time = 0.0


## Ignora los primeros segundos de un recorrido (carga de tráfico, fundido).
func warmup() -> void:
	_warmup = 3.0
	_accum = 0.0
	_frames = 0
	_slow_frames = 0


func _apply_level(l: int) -> void:
	level = clampi(l, 0, 3)
	max_level_reached = maxi(max_level_reached, level)
	print("[Rendimiento] nivel de calidad -> %d" % level)
	level_changed.emit(level)


## Parámetros para cada nivel.
static func settings(l: int) -> Dictionary:
	return [
		{"mirror_every": 2, "segments_ahead": 10, "traffic": 1.0, "fog_end": 480.0, "far": 520.0},
		{"mirror_every": 3, "segments_ahead": 8, "traffic": 0.9, "fog_end": 380.0, "far": 420.0},
		{"mirror_every": 4, "segments_ahead": 7, "traffic": 0.8, "fog_end": 320.0, "far": 360.0},
		{"mirror_every": 6, "segments_ahead": 6, "traffic": 0.7, "fog_end": 270.0, "far": 310.0},
	][clampi(l, 0, 3)]

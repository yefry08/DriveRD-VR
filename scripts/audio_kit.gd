class_name AudioKit
extends RefCounted
## Sonidos generados por código (sin archivos de audio de terceros).

const RATE := 22050


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Motor de cuatro cilindros: ciclos enteros en 0.5 s para que el bucle no tenga costura.
static func engine_loop() -> AudioStreamWAV:
	var n := RATE / 2
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var noise := 0.0
	for i in n:
		var t := float(i) / RATE
		noise = lerpf(noise, rng.randf_range(-1, 1), 0.08)
		var v := 0.42 * sin(TAU * 56.0 * t) + 0.25 * sin(TAU * 112.0 * t + 0.5) + 0.12 * sin(TAU * 168.0 * t) + 0.08 * signf(sin(TAU * 28.0 * t))
		s[i] = (v + noise * 0.15) * 0.55
	return _wav(s, true)


## Zumbido de motor de moto de baja cilindrada.
static func moto_loop() -> AudioStreamWAV:
	var n := RATE / 4
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var saw := fmod(t * 128.0, 1.0) * 2.0 - 1.0
		var v := 0.5 * saw + 0.3 * signf(sin(TAU * 64.0 * t)) + 0.2 * sin(TAU * 256.0 * t)
		s[i] = v * 0.4
	return _wav(s, true)


static func chime_good() -> AudioStreamWAV:
	var n := int(RATE * 0.38)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 if t < 0.13 else 1318.5
		var env := exp(-t * 7.0) * minf(1.0, t * 200.0)
		s[i] = sin(TAU * f * t) * env * 0.5
	return _wav(s, false)


static func buzz_bad() -> AudioStreamWAV:
	var n := int(RATE * 0.4)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 100.0) * clampf((0.4 - t) * 12.0, 0.0, 1.0)
		s[i] = (signf(sin(TAU * 196.0 * t)) * 0.5 + sin(TAU * 233.0 * t) * 0.3) * env * 0.35
	return _wav(s, false)


static func crash_sound() -> AudioStreamWAV:
	var n := int(RATE * 0.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.3)
		s[i] = (lp * 0.9 + sin(TAU * 60.0 * t) * 0.4) * exp(-t * 5.0)
	return _wav(s, false)

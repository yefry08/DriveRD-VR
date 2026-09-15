class_name DriveScore
extends RefCounted
## Puntuación defensiva. El jugador empieza con 1000 puntos y los defiende:
## no se gana por llegar rápido, se gana por no exponerse.
##
## Todas las reglas y umbrales están aquí como constantes para poder
## explicarlas (y ajustarlas) sin tocar el resto del juego.

signal event(text: String, kind: String, points: int)   # kind: "bien", "mal", "info"

const START_POINTS := 1000.0

# --- Suma
const SAFE_PASS_MIN_GAP := 1.6          # m de separación lateral, borde a borde
const SAFE_PASS_MAX_KMH := 85.0
const PTS_SAFE_PASS := 25
const PRUDENT_KMH := 80.0
const PRUDENT_INTERVAL := 20.0          # s continuos bajo 80 km/h (en movimiento)
const PTS_PRUDENT := 5
const PTS_EARLY_BRAKE := 15
const PTS_TRAMO := 50
const PTS_PED_YIELD := 20

# --- Resta
const SPEEDING_KMH := 90.0
const PTS_SPEEDING_PER_S := 5.0
const PTS_CLOSE_PASS := 40
const PTS_OPPOSITE_ENTRY := 10
const PTS_OPPOSITE_PER_S := 8.0
const PTS_OFFROAD_ENTRY := 15
const PTS_OFFROAD_PER_S := 8.0
const PTS_CRASH_VEHICLE := 150
const PTS_CRASH_PEDESTRIAN := 300

# --- Conducta de riesgo (segundos acumulados)
const TAILGATE_HEADWAY_S := 1.0

var score := START_POINTS
var defense := 60.0                     # 0–100, indicador del tablero

# Estadísticas citables
var distance_m := 0.0
var time_s := 0.0
var max_kmh := 0.0
var risk_seconds := 0.0
var safe_moto_passes := 0
var close_moto_passes := 0
var fast_moto_passes := 0
var min_moto_gap := 99.0
var crashes := 0
var pedestrians_hit := 0
var pedestrians_yielded := 0
var pedestrian_near_misses := 0
var early_brakes := 0
var forced_brakes := 0
var tramos := 0
var speeding_seconds := 0.0
var opposite_seconds := 0.0
var offroad_seconds := 0.0
var tailgate_seconds := 0.0

var _prudent_timer := 0.0
var _was_speeding := false
var _was_opposite := false
var _was_offroad := false
var _speed_msg_cooldown := 0.0


func reset() -> void:
	var fresh := DriveScore.new()
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			set(p.name, fresh.get(p.name))


## Llamar cada frame mientras se maneja.
func update(dt: float, kmh: float, meters: float, in_opposite: bool, offroad: bool, headway_s: float) -> void:
	time_s += dt
	distance_m += meters
	max_kmh = maxf(max_kmh, kmh)
	_speed_msg_cooldown = maxf(0.0, _speed_msg_cooldown - dt)

	var speeding := kmh > SPEEDING_KMH
	var tailgating := headway_s < TAILGATE_HEADWAY_S and kmh > 20.0
	var at_risk := speeding or in_opposite or offroad or tailgating

	if speeding:
		speeding_seconds += dt
		_add(-PTS_SPEEDING_PER_S * dt)
		if not _was_speeding and _speed_msg_cooldown <= 0.0:
			_emit("¡Bájale! Vas a más de 90 km/h", "mal", 0)
			_speed_msg_cooldown = 6.0
	_was_speeding = speeding

	if in_opposite:
		opposite_seconds += dt
		if not _was_opposite:
			_add(-PTS_OPPOSITE_ENTRY)
			_emit("¡Contravía! Vuelve a tu carril", "mal", -PTS_OPPOSITE_ENTRY)
			defense -= 10.0
		_add(-PTS_OPPOSITE_PER_S * dt)
	_was_opposite = in_opposite

	if offroad:
		offroad_seconds += dt
		if not _was_offroad:
			_add(-PTS_OFFROAD_ENTRY)
			_emit("Te saliste de la calzada", "mal", -PTS_OFFROAD_ENTRY)
			defense -= 10.0
		_add(-PTS_OFFROAD_PER_S * dt)
	_was_offroad = offroad

	if tailgating:
		tailgate_seconds += dt

	if at_risk:
		risk_seconds += dt
		defense -= 14.0 * dt
	elif kmh > 5.0 and kmh <= PRUDENT_KMH:
		defense += 2.5 * dt

	if kmh > 15.0 and kmh < PRUDENT_KMH and not at_risk:
		_prudent_timer += dt
		if _prudent_timer >= PRUDENT_INTERVAL:
			_prudent_timer = 0.0
			_add(PTS_PRUDENT)
			_emit("Velocidad prudente", "bien", PTS_PRUDENT)
	elif kmh >= PRUDENT_KMH or at_risk:
		_prudent_timer = 0.0

	defense = clampf(defense, 0.0, 100.0)


## Rebase a un motoconcho con la separación lateral medida.
func moto_pass(gap_m: float, kmh: float) -> void:
	min_moto_gap = minf(min_moto_gap, gap_m)
	if gap_m > SAFE_PASS_MIN_GAP and kmh < SAFE_PASS_MAX_KMH:
		safe_moto_passes += 1
		_add(PTS_SAFE_PASS)
		defense += 8.0
		_emit("Rebase seguro al motoconcho: %.1f m" % gap_m, "bien", PTS_SAFE_PASS)
	elif gap_m <= SAFE_PASS_MIN_GAP:
		close_moto_passes += 1
		_add(-PTS_CLOSE_PASS)
		defense -= 18.0
		_emit("¡Pasaste pegao al motoconcho! %.1f m" % gap_m, "mal", -PTS_CLOSE_PASS)
	else:
		fast_moto_passes += 1
		_emit("Buen espacio (%.1f m), pero ibas muy rápido" % gap_m, "info", 0)
	defense = clampf(defense, 0.0, 100.0)


func early_brake() -> void:
	early_brakes += 1
	_add(PTS_EARLY_BRAKE)
	defense = clampf(defense + 6.0, 0.0, 100.0)
	_emit("Frenaste a tiempo", "bien", PTS_EARLY_BRAKE)


func forced_brake() -> void:
	forced_brakes += 1
	risk_seconds += 1.0
	defense = clampf(defense - 12.0, 0.0, 100.0)
	_emit("¡Muy pegao! Guarda distancia", "mal", 0)


func pedestrian_yield() -> void:
	pedestrians_yielded += 1
	_add(PTS_PED_YIELD)
	defense = clampf(defense + 6.0, 0.0, 100.0)
	_emit("Le cediste el paso al peatón", "bien", PTS_PED_YIELD)


func pedestrian_near_miss(gap_m: float) -> void:
	pedestrian_near_misses += 1
	risk_seconds += 2.0
	defense = clampf(defense - 20.0, 0.0, 100.0)
	_emit("¡Casi atropellas a un peatón! (%.1f m)" % gap_m, "mal", 0)


func tramo_complete(avenue: String) -> void:
	tramos += 1
	_add(PTS_TRAMO)
	_emit("Tramo completado: %s" % avenue, "bien", PTS_TRAMO)


func crash(pedestrian: bool) -> void:
	crashes += 1
	var pts := PTS_CRASH_PEDESTRIAN if pedestrian else PTS_CRASH_VEHICLE
	if pedestrian:
		pedestrians_hit += 1
	_add(-pts)
	defense = clampf(defense - 40.0, 0.0, 100.0)
	_emit("¡Atropellaste a un peatón!" if pedestrian else "¡Choque!", "mal", -pts)


func summary() -> Dictionary:
	return {
		"puntos": roundi(score),
		"km_recorridos": snappedf(distance_m / 1000.0, 0.01),
		"rebases_seguros_motoconchos": safe_moto_passes,
		"rebases_pegados_motoconchos": close_moto_passes,
		"rebases_rapidos_motoconchos": fast_moto_passes,
		"separacion_minima_moto_m": snappedf(min_moto_gap, 0.1) if min_moto_gap < 90.0 else null,
		"velocidad_maxima_kmh": roundi(max_kmh),
		"segundos_conducta_riesgo": snappedf(risk_seconds, 0.1),
		"segundos_exceso_velocidad": snappedf(speeding_seconds, 0.1),
		"segundos_contravia": snappedf(opposite_seconds, 0.1),
		"segundos_fuera_calzada": snappedf(offroad_seconds, 0.1),
		"segundos_distancia_corta": snappedf(tailgate_seconds, 0.1),
		"choques": crashes,
		"peatones_atropellados": pedestrians_hit,
		"peatones_cedido_paso": pedestrians_yielded,
		"casi_atropellos": pedestrian_near_misses,
		"frenadas_anticipadas": early_brakes,
		"frenadas_forzadas": forced_brakes,
		"tramos_completados": tramos,
		"duracion_s": snappedf(time_s, 0.1),
		"defensa_final": roundi(defense),
	}


func rating() -> String:
	if crashes == 0 and close_moto_passes == 0 and score >= 1100:
		return "Conductor defensivo ejemplar"
	if crashes == 0 and score >= 950:
		return "Buen conductor defensivo"
	if score >= 700:
		return "Vas bien, pero te expusiste de más"
	return "Manejo de alto riesgo: a practicar"


func _add(points: float) -> void:
	score = maxf(0.0, score + points)


func _emit(text: String, kind: String, points: int) -> void:
	event.emit(text, kind, points)

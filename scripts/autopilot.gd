class_name Autopilot
extends RefCounted
## Conductor automático para pruebas sin visor. No forma parte del juego: sirve
## para recorrer kilómetros en el editor y comprobar tráfico, reglas y memoria.
## `aggressive` = true maneja mal a propósito (rápido, pegado, contravía) para
## verificar que las penalizaciones se disparan.

var aggressive := false
var target_kmh := 55.0
var _lane_x := RoadLayout.LANE_RIGHT
var _lane_timer := 0.0
var _t := 0.0


func compute(dt: float, vehicle: PlayerVehicle, traffic: TrafficManager) -> Array:
	_t += dt
	_lane_timer -= dt
	var v := vehicle.speed_kmh()
	var target := target_kmh
	if aggressive:
		target = 98.0 if fmod(_t, 40.0) < 22.0 else 70.0
	var throttle := clampf((target - v) * 0.08, 0.0, 1.0)
	var brake := 0.0

	# Frenar ante el vehículo de adelante / peatones
	var gap := traffic.lead_gap
	if traffic.lead_agent != null:
		var closing := traffic.lead_closing
		var ttc := gap / closing if closing > 0.2 else 99.0
		if not aggressive and (ttc < 4.0 or gap < 10.0 + vehicle.speed * 0.9):
			throttle = 0.0
			brake = clampf(1.4 - ttc * 0.3, 0.25, 1.0)
		elif aggressive and ttc < 1.3:
			throttle = 0.0
			brake = 1.0
	if traffic.pedestrian_in_path and not aggressive:
		throttle = 0.0
		brake = 0.8

	# Elegir carril: el que tenga más espacio; alejarse de las motos
	if _lane_timer <= 0.0:
		_lane_timer = 3.0
		if traffic.lead_agent != null and gap < 35.0:
			_lane_x = RoadLayout.LANE_LEFT if _lane_x == RoadLayout.LANE_RIGHT else RoadLayout.LANE_RIGHT
		if aggressive and fmod(_t, 60.0) > 50.0:
			_lane_x = -1.2   # invade el carril contrario a propósito
	var want_x := _lane_x
	if not aggressive:
		for a: TrafficAgent in traffic.agents:
			if a.kind == TrafficAgent.Kind.MOTO:
				var lp := vehicle.to_local_point(a.position)
				if lp.z > -12.0 and lp.z < 4.0 and absf(lp.x) < 3.2:
					want_x = vehicle.position.x - signf(lp.x) * 1.2
					want_x = clampf(want_x, 1.1, 5.6)
	var lateral_err := want_x - vehicle.position.x
	var heading_target := clampf(-lateral_err * 0.12, -0.25, 0.25)
	var steer := clampf((vehicle.heading - heading_target) * 3.0, -1.0, 1.0)
	return [throttle, brake, steer, false]

class_name PlayerVehicle
extends Node3D
## Modelo de manejo del carro del jugador (cinemático, sin motor de física).
##
## - Acelera de forma progresiva: el pedal tiene recorrido y el motor pierde
##   empuje con la velocidad.
## - Frena con distancia real: ~8 m/s² a fondo (asfalto seco, carro compacto).
## - Dirección tipo bicicleta (Ackermann simplificado); el ángulo máximo de las
##   ruedas se reduce con la velocidad, así el giro pierde respuesta a alta velocidad.
## - La cabina es hija de este nodo y nunca se inclina: solo existe guiñada (yaw).

const WHEELBASE := 2.6
const HALF_WIDTH := 0.9
const HALF_LENGTH := 2.2
const MAX_ENGINE_ACCEL := 3.3      # m/s² en primera
const MAX_BRAKE_DECEL := 8.0       # m/s²
const DRAG := 0.00045              # resistencia aerodinámica
const ROLLING := 0.12              # rodadura
const MAX_WHEEL_ANGLE := deg_to_rad(30.0)
const MAX_HEADING := deg_to_rad(70.0)
const MAX_LATERAL_ACCEL := 5.0      # m/s², agarre de un carro compacto en asfalto

const GEAR_TOP_SPEEDS := [0.0, 5.5, 11.0, 17.0, 24.0, 32.0, 60.0]   # m/s por cambio

var speed := 0.0                   # m/s, solo hacia adelante
var heading := 0.0                 # rad, 0 = mirando hacia -Z
var steer := 0.0                   # -1 izquierda … 1 derecha (posición del volante)
var throttle := 0.0
var brake := 0.0
var accel := 0.0                   # m/s² del último paso (para la viñeta)
var yaw_rate := 0.0                # rad/s del último paso (para la viñeta)
var rpm := 800.0
var gear := 1
var frozen := false


func reset_to(pos: Vector3) -> void:
	position = pos
	heading = 0.0
	rotation = Vector3.ZERO
	speed = 0.0
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	accel = 0.0
	yaw_rate = 0.0


## throttle_in / brake_in en [0,1]. steer_in en [-1,1].
## steer_direct = true cuando el volante virtual fija la posición exacta.
func step(dt: float, throttle_in: float, brake_in: float, steer_in: float, steer_direct: bool) -> void:
	if frozen:
		accel = 0.0
		yaw_rate = 0.0
		return
	# Inercia de pedales: el pie tarda en llegar al fondo
	throttle = move_toward(throttle, clampf(throttle_in, 0, 1), dt * 2.2)
	brake = move_toward(brake, clampf(brake_in, 0, 1), dt * 5.0)

	var engine := throttle * MAX_ENGINE_ACCEL * clampf(1.0 - speed / 48.0, 0.12, 1.0)
	var resist := DRAG * speed * speed + (ROLLING if speed > 0.05 else 0.0)
	var braking := brake * MAX_BRAKE_DECEL
	var a := engine - resist - braking
	var new_speed := maxf(0.0, speed + a * dt)
	accel = (new_speed - speed) / dt if dt > 0 else 0.0
	speed = new_speed

	if steer_direct:
		steer = move_toward(steer, clampf(steer_in, -1, 1), dt * 6.0)
	else:
		# Con joystick la dirección tiene recorrido: no salta de un tope al otro
		steer = move_toward(steer, clampf(steer_in, -1, 1), dt * 1.6)

	var speed_factor := lerpf(1.0, 0.2, clampf(speed / 30.0, 0.0, 1.0))
	var wheel_angle := steer * MAX_WHEEL_ANGLE * speed_factor
	yaw_rate = -speed / WHEELBASE * tan(wheel_angle)
	# Límite de agarre lateral: a más velocidad, menos giro por el mismo volante
	var max_yaw := MAX_LATERAL_ACCEL / maxf(speed, 1.0)
	yaw_rate = clampf(yaw_rate, -max_yaw, max_yaw)
	heading = clampf(heading + yaw_rate * dt, -MAX_HEADING, MAX_HEADING)
	rotation = Vector3(0, heading, 0)
	position += forward() * speed * dt
	_update_engine(dt)


func forward() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


func speed_kmh() -> float:
	return speed * 3.6


func _update_engine(dt: float) -> void:
	while gear < GEAR_TOP_SPEEDS.size() - 1 and speed > GEAR_TOP_SPEEDS[gear] * 0.96:
		gear += 1
	while gear > 1 and speed < GEAR_TOP_SPEEDS[gear - 1] * 0.7:
		gear -= 1
	var lo: float = GEAR_TOP_SPEEDS[gear - 1] * 0.7 if gear > 1 else 0.0
	var hi: float = GEAR_TOP_SPEEDS[gear]
	var t := clampf((speed - lo) / maxf(hi - lo, 0.1), 0.0, 1.0)
	var target := 850.0 + t * 4600.0 + throttle * 450.0
	rpm = lerpf(rpm, target, clampf(dt * 6.0, 0, 1))


## Convierte un punto mundial a coordenadas del carro: x lateral (derecha +),
## z longitudinal (delante negativo).
func to_local_point(world_point: Vector3) -> Vector3:
	return global_transform.affine_inverse() * world_point


## Frena de golpe tras un choque (la pantalla se funde para que no maree).
func crash_stop() -> void:
	speed = 0.0
	throttle = 0.0
	accel = 0.0

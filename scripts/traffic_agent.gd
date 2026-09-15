class_name TrafficAgent
extends Node3D
## Un participante de la vía. La lógica vive en TrafficManager; aquí solo
## estado y apariencia, para poder reciclar nodos sin crear objetos en juego.

enum Kind { CAR, GUAGUA, MOTO, PEDESTRIAN }

var kind: int = Kind.CAR
var dir := 1                 # 1 = mismo sentido que el jugador (hacia -Z), -1 = contrario
var speed := 0.0
var desired_speed := 12.0
var half_len := 2.2
var half_w := 0.9
var active := false
var braking := false
var last_accel := 0.0

var mesh_instance: MeshInstance3D
var brake_light: MeshInstance3D
var audio: AudioStreamPlayer3D

# Motoconcho
var target_x := 0.0
var lat_speed := 1.5
var lat_vel := 0.0
var retarget_timer := 1.0
var pass_armed := false
var pass_overlap := false
var pass_min_gap := 99.0
var pass_max_kmh := 0.0

# Guagua
enum Stop { CRUISE, SIGNAL, BRAKING, STOPPED, GO }
var stop_state: int = Stop.CRUISE
var stop_timer := 0.0

# Peatón
enum Ped { WAITING, WALKING, HESITATING, DONE }
var ped_state: int = Ped.WAITING
var ped_dir := 1.0
var ped_timer := 0.0
var ped_yield_scored := false
var ped_last_long := -100.0
var walk_phase := 0.0
var leg_l: Node3D
var leg_r: Node3D

# Frenado anticipado del jugador (cuando este agente es el vehículo de adelante)
var lead_event_open := false
var lead_event_rewarded := false
var lead_event_forced := false


func reset_state() -> void:
	braking = false
	last_accel = 0.0
	lat_vel = 0.0
	retarget_timer = randf_range(0.7, 2.0)
	pass_armed = false
	pass_overlap = false
	pass_min_gap = 99.0
	pass_max_kmh = 0.0
	stop_state = Stop.CRUISE
	stop_timer = randf_range(6.0, 16.0)
	ped_state = Ped.WAITING
	ped_timer = randf_range(0.2, 0.6)
	ped_yield_scored = false
	ped_last_long = -100.0
	walk_phase = 0.0
	lead_event_open = false
	lead_event_rewarded = false
	lead_event_forced = false
	rotation = Vector3.ZERO
	if brake_light:
		brake_light.visible = false


func set_braking(on: bool) -> void:
	braking = on
	if brake_light and brake_light.visible != on:
		brake_light.visible = on

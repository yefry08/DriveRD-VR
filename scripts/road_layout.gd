class_name RoadLayout
extends RefCounted
## Medidas de la avenida (metros). La vía corre a lo largo de -Z.
## Se conduce por la derecha: los carriles propios están en x > 0.

const SEG_LEN := 50.0
const TRAMO_SEGMENTS := 12          # 600 m por tramo
const LANE_W := 3.3
const LANE_RIGHT := 4.95            # carril derecho propio
const LANE_LEFT := 1.65             # carril izquierdo propio
const ONCOMING_INNER := -1.65
const ONCOMING_OUTER := -4.95
const EDGE := 6.6                   # línea de borde de calzada
const PARK_CENTER := 7.7            # franja de estacionamiento
const PARK_OUT := 8.8
const CURB_OUT := 9.1
const SIDEWALK_OUT := 12.0

const AVENIDAS := [
	"Av. Independencia",
	"Av. 27 de Febrero",
	"Av. John F. Kennedy",
	"Av. Máximo Gómez",
]

const DOMINICAN_BLUE := Color(0.0, 0.176, 0.384)
const DOMINICAN_RED := Color(0.808, 0.067, 0.149)


static func avenue_for_segment(k: int) -> int:
	return posmod(floori(float(k) / TRAMO_SEGMENTS), AVENIDAS.size())

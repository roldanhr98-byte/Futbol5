class_name PitchConfig
extends Resource
## Configuracion de la cancha. Por defecto, futsal internacional de 40 x 20 m
## con arcos de 3 x 2 m (ver docs/CANCHA.md). Todas las medidas estan en metros.
## El eje X es el largo (los arcos estan en x = +-length/2) y el eje Z el ancho.

enum BoundaryMode { WALLS, OUT_OF_BOUNDS }

@export_group("Dimensiones")
@export var length: float = 40.0
@export var width: float = 20.0

@export_group("Arco")
@export var goal_width: float = 3.0
@export var goal_height: float = 2.0
@export var goal_depth: float = 1.0
@export var post_radius: float = 0.04

@export_group("Marcas")
@export var line_width: float = 0.08
@export var center_circle_radius: float = 3.0
## Radio de los cuartos de circulo del area de penal (desde cada poste).
@export var penalty_area_radius: float = 6.0
@export var penalty_mark_distance: float = 6.0
## Segundo punto penal (reglamento futsal, falta acumulada).
@export var second_penalty_mark_distance: float = 10.0
@export var corner_arc_radius: float = 0.25
@export var substitution_zone_length: float = 5.0

@export_group("Entorno")
@export var boundary_mode: BoundaryMode = BoundaryMode.WALLS
## Altura de las paredes que mantienen la pelota en juego.
@export var wall_height: float = 3.0
## Altura visible de la valla/baranda (el resto es colision invisible).
@export var barrier_visible_height: float = 1.0
@export var run_off: float = 2.5

func half_length() -> float:
	return length * 0.5

func half_width() -> float:
	return width * 0.5

func half_goal() -> float:
	return goal_width * 0.5

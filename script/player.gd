
extends CharacterBody2D

const TILE_SIZE: int = 16
const MAP_SIZE: int = 256
const WORLD_SIZE: int = TILE_SIZE * MAP_SIZE

const DEEP_WATER: int = 0
const WATER: int = 1
const SAND: int = 2
const GRASS: int = 3
const DIRT: int = 4
const ROCK: int = 5

@export var walk_speed: float = 100.0
@export var acceleration: float = 600.0
@export var deceleration: float = 800.0

var current_terrain: int = GRASS
var terrain_speed: float = 1.0
var world: Node2D


func _ready() -> void:
	world = get_parent()


func _physics_process(delta: float) -> void:
	move_and_slide()
	update_depth()
	wrap_position()
	update_terrain()

	var direction: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
        "ui_down"
	)

	var target_velocity: Vector2 = direction * walk_speed * terrain_speed

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(
			target_velocity,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)

	move_and_slide()
	wrap_position()


func update_terrain() -> void:
	if not world.has_method("get_terrain"):
		terrain_speed = 1.0
		return

	var tile_x: int = posmod(
		floori(global_position.x / TILE_SIZE),
		MAP_SIZE
	)

	var tile_y: int = posmod(
		floori(global_position.y / TILE_SIZE),
		MAP_SIZE
	)

	current_terrain = world.get_terrain(tile_x, tile_y)

	match current_terrain:
		DEEP_WATER:
			terrain_speed = 0.0
		WATER:
			terrain_speed = 0.55
		SAND:
			terrain_speed = 0.80
		GRASS:
			terrain_speed = 1.0
		DIRT:
			terrain_speed = 0.90
		ROCK:
			terrain_speed = 0.50
		_:
			terrain_speed = 1.0


func update_depth() -> void:
	z_as_relative = false
	z_index = roundi(global_position.y)


func wrap_position() -> void:
	global_position.x = fposmod(global_position.x, WORLD_SIZE)
	global_position.y = fposmod(global_position.y, WORLD_SIZE)

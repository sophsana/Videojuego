
extends CharacterBody2D

const Dimensiones = preload("res://script/sistemas/dimensiones_mundo.gd")
const TILE_SIZE: int = Dimensiones.TILE_SIZE
const MAP_SIZE: int = Dimensiones.MAP_SIZE
const WORLD_SIZE: int = Dimensiones.WORLD_SIZE

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
var ultima_direccion := "down"
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	world = get_parent()
	_actualizar_animacion(Vector2.ZERO)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interactuar") and world.has_method("recolectar_cercano"):
		world.recolectar_cercano(global_position)
	move_and_slide()
	wrap_position()
	update_terrain()

	var direction: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	var target_velocity: Vector2 = direction * walk_speed * terrain_speed
	_actualizar_animacion(direction if terrain_speed > 0.0 else Vector2.ZERO)

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
	# La profundidad se ordena por Y en el mundo, usando la posición de los pies.
	z_index = 0


func wrap_position() -> void:
	var posicion_anterior := global_position
	global_position.x = fposmod(global_position.x, WORLD_SIZE)
	global_position.y = fposmod(global_position.y, WORLD_SIZE)
	if posicion_anterior != global_position:
		var camara := get_node_or_null("WorldCamera") as Camera2D
		if camara != null:
			camara.reset_smoothing()


func _actualizar_animacion(direccion: Vector2) -> void:
	if direccion != Vector2.ZERO:
		if absf(direccion.x) > absf(direccion.y):
			ultima_direccion = "right" if direccion.x > 0 else "left"
		elif absf(direccion.y) > absf(direccion.x):
			ultima_direccion = "down" if direccion.y > 0 else "up"
		elif ultima_direccion not in ["left" if direccion.x < 0 else "right", "up" if direccion.y < 0 else "down"]:
			ultima_direccion = "down" if direccion.y > 0 else "up"
	sprite.flip_h = ultima_direccion == "right"
	var animacion := ("walk_" if direccion != Vector2.ZERO else "idle_") + ultima_direccion
	# La hoja de reposo tiene celdas 270×360; las de caminata, 180×240.
	sprite.scale = Vector2(0.133333, 0.133333) if animacion in ["idle_left", "idle_right"] else Vector2(0.2, 0.2)
	# Alinear los píxeles inferiores de ambas hojas sobre el mismo punto de apoyo.
	sprite.position.y = -3.2 if animacion in ["idle_left", "idle_right"] else -7.0
	if sprite.animation != animacion or not sprite.is_playing():
		sprite.play(animacion)

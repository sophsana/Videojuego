
extends Node2D

const MAP_SIZE: int = 256
const TILE_SIZE: int = 16
const WORLD_SIZE: float = MAP_SIZE * TILE_SIZE
const TERRAIN_COUNT: int = 6

const DEEP_WATER: int = 0
const WATER: int = 1
const SAND: int = 2
const GRASS: int = 3
const DIRT: int = 4
const ROCK: int = 5

@export var world_seed: int = 12345
@export var camera_speed: float = 500.0

var terrain_layer: TileMapLayer
var world_camera: Camera2D

var elevation_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var moisture_noise: FastNoiseLite


#las de los recursos :v
var resources_layer: Node2D
var resource_rng := RandomNumberGenerator.new()
var occupied_positions: Array[Vector2] = []
#lo mismo pero para bosques
var forest_noise: FastNoiseLite
var forest_detail_noise: FastNoiseLite


func _ready() -> void:
	setup_noise()
	setup_terrain()
	generate_world()
	create_world_copies()
	generate_resources()
	create_resource_copies()
	create_player()
	setup_camera()





func create_resource_copies() -> void:
	if resources_layer == null:
		return

	var original_resources: Array[Node2D] = []

	for child in resources_layer.get_children():
		if child is Node2D and not child.name.ends_with("_VisualCopy"):
			original_resources.append(child as Node2D)

	for offset_y in [-1, 0, 1]:
		for offset_x in [-1, 0, 1]:
			if offset_x == 0 and offset_y == 0:
				continue

			var offset := Vector2(
				offset_x * WORLD_SIZE,
				offset_y * WORLD_SIZE
			)

			for original in original_resources:
				var copy := original.duplicate() as Node2D

				if copy == null:
					continue

				copy.position = original.position + offset
				copy.name = original.name + "_VisualCopy"
				resources_layer.add_child(copy)

				var animated := copy.get_node_or_null("SpriteNode2D") as AnimatedSprite2D
				if animated != null:
					animated.play("viento")

func generate_resources() -> void:
	resources_layer = Node2D.new()
	resources_layer.name = "Recursos"
	add_child(resources_layer)

	resource_rng.seed = world_seed + 500

	occupied_positions.clear()

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var terrain_id: int = get_terrain(x, y)
			var chance: float = resource_rng.randf()

			var tile_center := Vector2(
				x * TILE_SIZE + TILE_SIZE / 2.0,
				y * TILE_SIZE + TILE_SIZE / 2.0
			)

			if terrain_id == GRASS:
				var in_forest := is_forest_zone(x, y)
				var detail: float = forest_detail_noise.get_noise_2d(x, y)
				var tree_chance: float

				if in_forest:
					tree_chance = 0.12
				else:
					tree_chance = 0.008

				if detail > -0.2 and resource_rng.randf() < tree_chance:
					place_resource(
						"arbol_1",
						"res://assets/recursos/arbol_1.png",
						tile_center,
						Vector2i(192, 48),
						1.0
					)
				elif resource_rng.randf() < 0.10:
					place_resource(
						"arbusto_1",
						"res://assets/recursos/arbusto_1.png",
						tile_center,
						Vector2i(32, 16),
						0.5
					)
				elif resource_rng.randf() < 0.04:
					place_rock(tile_center)

			elif terrain_id == DIRT:
				if resource_rng.randf() < 0.035:
					place_rock(tile_center)

			elif terrain_id == ROCK:
				if resource_rng.randf() < 0.08:
					place_rock(tile_center)

func place_rock(tile_center: Vector2) -> void:
	var chance := resource_rng.randf()

	if chance < 0.55:
		place_resource(
			"roca_1",
			"res://assets/recursos/roca_1.png",
			tile_center,
			Vector2i(16, 16),
			0
		)
	else:
		place_resource(
			"roca_2",
			"res://assets/recursos/roca_2.png",
			tile_center,
			Vector2i(32, 32),
			1
		)




func place_resource(
	resource_name: String,
	texture_path: String,
	tile_center: Vector2,
	expected_size: Vector2i,
	clearance: float
) -> void:
	var texture := load(texture_path) as Texture2D

	if texture == null:
		push_warning("No se pudo cargar el recurso: " + texture_path)
		return

	if resource_name == "arbol_1":
		if texture.get_width() != 192 or texture.get_height() != 48:
			push_warning("La spritesheet del árbol debe medir 192 x 48.")
			return
	else:
		if texture.get_width() != expected_size.x or texture.get_height() != expected_size.y:
			push_warning("Tamaño incorrecto para: " + texture_path)
			return
	var sprite_position := tile_center

	if resource_name == "arbol_1" or resource_name == "arbusto_1":
		sprite_position.y -= expected_size.y / 2.0 - TILE_SIZE / 2.0

	# Comprobar que el recurso no se superponga con otro.
	var new_rect := Rect2(
		sprite_position - Vector2(expected_size) / 2.0,
		Vector2(expected_size)
	)

	for existing in resources_layer.get_children():
		if existing.name.ends_with("_VisualCopy"):
			continue

		var existing_sprite: Sprite2D = null

		if existing is Sprite2D:
			existing_sprite = existing as Sprite2D
		elif existing is Node2D:
			existing_sprite = existing.get_node_or_null("SpriteNode2D") as Sprite2D

		var existing_texture: Texture2D = null

		if existing_sprite != null:
			existing_texture = existing_sprite.texture
		elif existing is Node2D:
			var animated := existing.get_node_or_null("SpriteNode2D") as AnimatedSprite2D
			if animated != null and animated.sprite_frames != null:
				existing_texture = animated.sprite_frames.get_frame_texture("viento", animated.frame)

		if existing_texture == null:
			continue

		var existing_size := existing_texture.get_size()
		var existing_rect := Rect2(
			existing.position - existing_size / 2.0,
			existing_size
		).grow(clearance * TILE_SIZE / 2.0)

		if existing_rect.intersects(new_rect):
			return

	var sprite: Node2D

	if resource_name == "arbol_1":
		var tree_scene := load("res://escenas/arbol_animado.tscn") as PackedScene

		if tree_scene == null:
			push_warning("No se pudo cargar res://escenas/arbol_animado.tscn")
			return

		sprite = tree_scene.instantiate() as Node2D

		if sprite == null:
			return

		var animated_sprite := sprite.get_node_or_null("SpriteNode2D") as AnimatedSprite2D

		if animated_sprite == null:
			push_warning("No se encontró SpriteNode2D de tipo AnimatedSprite2D")
			sprite.free()
			return

		animated_sprite.play("viento")
	else:
		var static_sprite := Sprite2D.new()
		static_sprite.texture = texture
		static_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite = static_sprite

	sprite.name = resource_name
	sprite.position = sprite_position
	sprite.z_as_relative = false
	sprite.z_index = roundi(sprite_position.y)

	resources_layer.add_child(sprite)
	occupied_positions.append(tile_center)


func setup_noise() -> void:
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = world_seed
	elevation_noise.frequency = 0.025
	elevation_noise.fractal_octaves = 4

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = world_seed + 100
	detail_noise.frequency = 0.07
	detail_noise.fractal_octaves = 2

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = world_seed + 200
	moisture_noise.frequency = 0.035
	moisture_noise.fractal_octaves = 3
	#para los bosques
	forest_noise = FastNoiseLite.new()
	forest_noise.seed = world_seed + 300
	forest_noise.frequency = 0.025
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	forest_detail_noise = FastNoiseLite.new()
	forest_detail_noise.seed = world_seed + 400
	forest_detail_noise.frequency = 0.09
	forest_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX


func smooth_blend(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)




func periodic_noise(
	noise: FastNoiseLite,
	x: float,
	y: float
) -> float:
	var tx: float = smooth_blend(x / float(MAP_SIZE))
	var ty: float = smooth_blend(y / float(MAP_SIZE))

	var top_left: float = noise.get_noise_2d(x, y)
	var top_right: float = noise.get_noise_2d(x - MAP_SIZE, y)
	var bottom_left: float = noise.get_noise_2d(x, y - MAP_SIZE)
	var bottom_right: float = noise.get_noise_2d(
		x - MAP_SIZE,
		y - MAP_SIZE
	)

	var top: float = lerp(top_left, top_right, tx)
	var bottom: float = lerp(bottom_left, bottom_right, tx)

	return lerp(top, bottom, ty)


func get_terrain(x: int, y: int) -> int:
	var elevation := periodic_noise(elevation_noise, x, y)
	var detail := periodic_noise(detail_noise, x, y)
	var moisture := periodic_noise(moisture_noise, x, y)

	elevation += detail * 0.12

	if elevation < -0.28:
		return DEEP_WATER
	if elevation < -0.12:
		return WATER
	if elevation < -0.04:
		return SAND
	if elevation > 0.48:
		return ROCK
	if moisture < -0.35:
		return DIRT

	return GRASS


func setup_terrain() -> void:
	var tile_paths: Array[String] = [
		"res://assets/terreno/agua_nivel_2.png",
		"res://assets/terreno/agua_nivel_1.png",
		"res://assets/terreno/arena_1.png",
		"res://assets/terreno/tierra_1.png",
		"res://assets/terreno/tierra_1.png",
		"res://assets/terreno/roca_1.png"
	]

	var atlas_image := Image.create(
		TILE_SIZE * TERRAIN_COUNT,
		TILE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)

	for tile_id in range(TERRAIN_COUNT):
		var texture := load(tile_paths[tile_id]) as Texture2D

		if texture == null:
			push_error("No se pudo cargar: " + tile_paths[tile_id])
			return

		var tile_image := texture.get_image()

		if tile_image.get_width() != TILE_SIZE or tile_image.get_height() != TILE_SIZE:
			push_error("La textura debe medir 16 x 16: " + tile_paths[tile_id])
			return

		atlas_image.blit_rect(
			tile_image,
			Rect2i(0, 0, TILE_SIZE, TILE_SIZE),
			Vector2i(tile_id * TILE_SIZE, 0)
		)

	var atlas_texture := ImageTexture.create_from_image(atlas_image)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = atlas_texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for tile_id in range(TERRAIN_COUNT):
		atlas_source.create_tile(Vector2i(tile_id, 0))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(atlas_source, 0)

	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = tile_set
	terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	add_child(terrain_layer)


func generate_world() -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var terrain_id := get_terrain(x, y)

			terrain_layer.set_cell(
				Vector2i(x, y),
				0,
				Vector2i(terrain_id, 0)
			)


func create_world_copies() -> void:
	for offset_y in [-1, 0, 1]:
		for offset_x in [-1, 0, 1]:
			if offset_x == 0 and offset_y == 0:
				continue

			var copy := terrain_layer.duplicate() as TileMapLayer
			copy.name = "TerrainCopy_%d_%d" % [offset_x, offset_y]
			copy.position = Vector2(
				offset_x * WORLD_SIZE,
				offset_y * WORLD_SIZE
			)
			add_child(copy)



func setup_camera() -> void:
	var player: Node2D = get_node("Player")

	world_camera = Camera2D.new()
	world_camera.name = "WorldCamera"
	world_camera.position_smoothing_enabled = true
	world_camera.position_smoothing_speed = 5.0
	world_camera.zoom = Vector2(3.0, 3.0)

	player.add_child(world_camera)
	world_camera.make_current()


func wrap_camera_position() -> void:
	var player: Node2D = get_node_or_null("Player")

	if player == null:
		return

	player.position.x = fposmod(player.position.x, WORLD_SIZE)
	player.position.y = fposmod(player.position.y, WORLD_SIZE)

func create_player() -> void:
	var player_scene: PackedScene = load("res://escenas/player.tscn")

	if player_scene == null:
		push_error("No se pudo cargar la escena del personaje.")
		return

	var player: CharacterBody2D = player_scene.instantiate()
	player.name = "Player"
	player.position = Vector2(WORLD_SIZE / 2.0, WORLD_SIZE / 2.0)

	add_child(player)

#para bosques pt2
func is_forest_zone(x: int, y: int) -> bool:
	var forest_value: float = forest_noise.get_noise_2d(x, y)
	return forest_value > 0.25

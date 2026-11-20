
extends Node2D

signal avance_generacion(fase: String, completado: int, total: int)
signal generacion_terminada
signal generacion_fallida(mensaje: String)

const Dimensiones = preload("res://script/sistemas/dimensiones_mundo.gd")
const Catalogo = preload("res://script/sistemas/catalogo_recursos.gd")
const Inventario = preload("res://script/sistemas/inventario.gd")
const TilesNaturaleza = preload("res://script/sistemas/tiles_naturaleza.gd")
const MAP_SIZE: int = Dimensiones.MAP_SIZE
const TILE_SIZE: int = Dimensiones.TILE_SIZE
const WORLD_SIZE: float = Dimensiones.WORLD_SIZE
const TERRAIN_COUNT: int = 6
const GRASS_GRID: int = 4
const GRASS_VARIANTS: int = GRASS_GRID * GRASS_GRID
const ATLAS_CANTIDAD := 35
const ATLAS_AGUA := 0
const ATLAS_ARENA := 6
const ATLAS_PASTO := 8
const ATLAS_TIERRA := 11
const ATLAS_ROCA := 12
const ATLAS_ORILLA := 13
const ATLAS_TRANSICION := 17

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
#lo mismo pero para bosques
var forest_noise: FastNoiseLite
var forest_detail_noise: FastNoiseLite
var generacion_lista := false
var inventario = Inventario.new()
var arbustos_recolectados: Dictionary = {}
var visuales_arbustos: Dictionary = {}
var sprites_recursos: Dictionary = {}
var celdas_ocupadas: Dictionary = {}
var texturas_rocas: Array[AtlasTexture] = []
var reloj_oleaje := 0.0
var fotograma_oleaje := 0
var atlas_oleaje: ImageTexture
var imagen_oleaje: Image
var mar_frames: Array[Image] = []
var orilla_frames: Array[Image] = []


func _ready() -> void:
	# La configuración se selecciona antes del cambio de escena; al abrir mundo.tscn
	# directamente se conserva la semilla exportada de la escena.
	if not GestorMundos.mundo_actual.is_empty():
		world_seed = GestorMundos.mundo_actual.semilla
		var progreso: Dictionary = GestorMundos.mundo_actual.get("progreso", {})
		inventario.cargar(progreso.get("inventario", {}))
		arbustos_recolectados = progreso.get("cambios_mundo", {}).get("arbustos_recolectados", {}).duplicate(true)
	y_sort_enabled = true
	setup_noise()
	setup_terrain()
	if terrain_layer == null:
		push_error("No se pudo preparar el terreno.")
		generacion_fallida.emit("No se pudo preparar el terreno.")
		return
	await generate_world()
	await create_world_copies()
	await generate_resources()
	await create_resource_copies()
	create_player()
	if get_node_or_null("Player") == null:
		push_error("No se pudo preparar el jugador.")
		generacion_fallida.emit("No se pudo preparar el jugador.")
		return
	setup_camera()
	_crear_interfaz_mundo()
	generacion_lista = true
	avance_generacion.emit("jugador", 1, 1)
	generacion_terminada.emit()
	if get_parent() == get_tree().root:
		activar_juego()





func create_resource_copies() -> void:
	if resources_layer == null:
		return

	var original_resources: Array[Node2D] = []
	# Incluye el área visible y un margen para sprites grandes.
	var margen := maxf(640.0, maxf(get_viewport_rect().size.x, get_viewport_rect().size.y) / 6.0 + 128.0)

	for child in resources_layer.get_children():
		if child is Node2D and not child.name.ends_with("_VisualCopy"):
			var original := child as Node2D
			# Solo los recursos cercanos a un borde pueden ser visibles desde
			# el otro lado con el zoom actual; se evita duplicar todo el bosque.
			if original.position.x < margen or original.position.x > WORLD_SIZE - margen or original.position.y < margen or original.position.y > WORLD_SIZE - margen:
				original_resources.append(original)

	var total := original_resources.size() * 8
	var completado := 0
	for offset_y in [-1, 0, 1]:
		for offset_x in [-1, 0, 1]:
			if offset_x == 0 and offset_y == 0:
				continue

			var offset := Vector2(
				offset_x * WORLD_SIZE,
				offset_y * WORLD_SIZE
			)

			for original in original_resources:
				completado += 1
				if completado % 100 == 0:
					avance_generacion.emit("copias_recursos", completado, maxi(total, 1))
					await get_tree().process_frame
				if (offset_x == -1 and original.position.x < WORLD_SIZE - margen) or (offset_x == 1 and original.position.x > margen) or (offset_y == -1 and original.position.y < WORLD_SIZE - margen) or (offset_y == 1 and original.position.y > margen):
					continue
				var copy := original.duplicate() as Node2D

				if copy == null:
					continue

				copy.position = original.position + offset
				copy.name = original.name + "_VisualCopy"
				resources_layer.add_child(copy)

				if original.has_meta("arbusto_id"):
					var arbusto_id: String = original.get_meta("arbusto_id")
					visuales_arbustos[arbusto_id].append(copy)
				var animated := copy.get_node_or_null("SpriteNode2D") as AnimatedSprite2D
				if animated != null:
					animated.play("viento")
	avance_generacion.emit("copias_recursos", 1, 1)
	await get_tree().process_frame

func generate_resources() -> void:
	resources_layer = Node2D.new()
	resources_layer.name = "Recursos"
	resources_layer.y_sort_enabled = true
	add_child(resources_layer)

	resource_rng.seed = world_seed + 500
	_preparar_recursos()

	celdas_ocupadas.clear()

	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var terrain_id: int = get_terrain(x, y)
			resource_rng.randf() # Conserva el consumo aleatorio anterior.

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
					var tipo := Catalogo.elegir_indice(Catalogo.PESOS_ARBOLES, resource_rng.randf())
					_colocar_animado("arbol_%d" % tipo, tile_center, float(Catalogo.ARBOLES[tipo].ancho), "")
				elif resource_rng.randf() < 0.10:
					var tipo := resource_rng.randi_range(0, 1)
					_colocar_animado("arbusto_%d" % tipo, tile_center, float(Catalogo.ARBUSTOS[tipo].ancho), "%d_%d" % [x, y])
				elif resource_rng.randf() < 0.04:
					place_rock(tile_center)

			elif terrain_id == DIRT:
				if resource_rng.randf() < 0.035:
					place_rock(tile_center)

			elif terrain_id == ROCK:
				if resource_rng.randf() < 0.08:
					place_rock(tile_center)
		if y % 4 == 3:
			avance_generacion.emit("recursos", y + 1, MAP_SIZE)
			await get_tree().process_frame

func place_rock(tile_center: Vector2) -> void:
	var tipo := Catalogo.elegir_indice(Catalogo.PESOS_ROCAS, resource_rng.randf())
	var textura := texturas_rocas[tipo]
	var escala := float(Catalogo.ANCHOS_ROCAS[tipo]) / textura.get_width()
	var tamano := textura.get_size() * escala
	if not _reservar_espacio(tile_center, tamano):
		return
	var recurso := Node2D.new()
	recurso.position = tile_center
	var sprite := Sprite2D.new()
	sprite.name = "SpriteNode2D"
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * escala
	sprite.position.y = -tamano.y / 2.0
	recurso.add_child(sprite)
	resources_layer.add_child(recurso)


func _preparar_recursos() -> void:
	for i in range(Catalogo.ARBOLES.size()):
		sprites_recursos["arbol_%d" % i] = Catalogo.fotogramas(Catalogo.ARBOLES[i].ruta)
	for i in range(Catalogo.ARBUSTOS.size()):
		sprites_recursos["arbusto_%d" % i] = Catalogo.fotogramas(Catalogo.ARBUSTOS[i].ruta)
	var frutos: SpriteFrames = sprites_recursos["arbusto_1"]
	var region: Rect2 = (frutos.get_frame_texture("viento", 0) as AtlasTexture).region
	sprites_recursos["arbusto_vacio"] = Catalogo.fotogramas(Catalogo.ARBUSTOS[1].vacio, Rect2i(region))
	for i in range(Catalogo.PESOS_ROCAS.size()):
		texturas_rocas.append(Catalogo.roca(i))


func _reservar_espacio(posicion: Vector2, tamano: Vector2) -> bool:
	var rect := Rect2(posicion - Vector2(tamano.x / 2.0, tamano.y), tamano).grow(4.0)
	var inicio := Vector2i(floori(rect.position.x / 64.0), floori(rect.position.y / 64.0))
	var fin := Vector2i(floori(rect.end.x / 64.0), floori(rect.end.y / 64.0))
	var celdas_lado := int(WORLD_SIZE / 64.0)
	for y in range(inicio.y, fin.y + 1):
		for x in range(inicio.x, fin.x + 1):
			var clave := Vector2i(posmod(x, celdas_lado), posmod(y, celdas_lado))
			for existente: Rect2 in celdas_ocupadas.get(clave, []):
				for oy in [-1, 0, 1]:
					for ox in [-1, 0, 1]:
						if Rect2(existente.position + Vector2(ox, oy) * WORLD_SIZE, existente.size).intersects(rect):
							return false
	for y in range(inicio.y, fin.y + 1):
		for x in range(inicio.x, fin.x + 1):
			var clave := Vector2i(posmod(x, celdas_lado), posmod(y, celdas_lado))
			if not celdas_ocupadas.has(clave):
				celdas_ocupadas[clave] = []
			celdas_ocupadas[clave].append(rect)
	return true


func _colocar_animado(tipo: String, posicion: Vector2, ancho: float, arbusto_id: String) -> void:
	var frames: SpriteFrames = sprites_recursos[tipo]
	var tamano_original := frames.get_frame_texture("viento", 0).get_size()
	var escala := ancho / tamano_original.x
	var tamano := tamano_original * escala
	if not _reservar_espacio(posicion, tamano):
		return
	var recurso := Node2D.new()
	recurso.position = posicion
	var sprite := AnimatedSprite2D.new()
	sprite.name = "SpriteNode2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = sprites_recursos["arbusto_vacio"] if not arbusto_id.is_empty() and arbustos_recolectados.has(arbusto_id) else frames
	sprite.scale = Vector2.ONE * escala
	sprite.position.y = -tamano.y / 2.0
	recurso.add_child(sprite)
	resources_layer.add_child(recurso)
	sprite.play("viento")
	if not arbusto_id.is_empty():
		recurso.set_meta("arbusto_id", arbusto_id)
		visuales_arbustos[arbusto_id] = [recurso]


func recolectar_cercano(posicion: Vector2, alcance: float = 60.0) -> bool:
	var mas_cercano := ""
	var distancia := alcance
	for id in visuales_arbustos:
		if arbustos_recolectados.has(id):
			continue
		var original: Node2D = visuales_arbustos[id][0]
		var delta := (original.position - posicion).abs()
		delta.x = minf(fposmod(delta.x, WORLD_SIZE), WORLD_SIZE - fposmod(delta.x, WORLD_SIZE))
		delta.y = minf(fposmod(delta.y, WORLD_SIZE), WORLD_SIZE - fposmod(delta.y, WORLD_SIZE))
		if delta.length() <= distancia:
			distancia = delta.length()
			mas_cercano = id
	if mas_cercano.is_empty():
		return false
	arbustos_recolectados[mas_cercano] = true
	inventario.agregar("fruto_alienigena", "Fruto alienígena", 1)
	var interfaz := get_node_or_null("InterfazMundo")
	if interfaz != null:
		interfaz.actualizar_inventario()
	for recurso: Node2D in visuales_arbustos[mas_cercano]:
		var sprite := recurso.get_node("SpriteNode2D") as AnimatedSprite2D
		sprite.sprite_frames = sprites_recursos["arbusto_vacio"]
		sprite.play("viento")
	return true



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
	imagen_oleaje = Image.create(TILE_SIZE * ATLAS_CANTIDAD, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var azul := Color(0.09, 0.01, 0.29)
	var arena := Color(0.87, 0.43, 0.34)
	var verde := Color(0.0, 0.37, 0.48)
	for region in TilesNaturaleza.CELDAS_MAR:
		mar_frames.append(TilesNaturaleza.preparar_imagen(TilesNaturaleza.MAR, region, azul))
	for region in TilesNaturaleza.CELDAS_ORILLA:
		orilla_frames.append(TilesNaturaleza.preparar_imagen(TilesNaturaleza.ORILLA, region, azul))
	for i in range(2):
		_copiar_atlas(TilesNaturaleza.preparar_imagen(TilesNaturaleza.ARENA, TilesNaturaleza.CELDAS_ARENA[i], arena), ATLAS_ARENA + i)
	for i in range(3):
		_copiar_atlas(TilesNaturaleza.preparar_imagen(TilesNaturaleza.PASTO, TilesNaturaleza.CELDAS_PASTO[i], verde), ATLAS_PASTO + i)
	for entrada in [[ATLAS_TIERRA, "res://assets/terreno/tierra_1.png"], [ATLAS_ROCA, "res://assets/terreno/roca_1.png"]]:
		var original := (load(entrada[1]) as Texture2D).get_image()
		original.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		original.convert(Image.FORMAT_RGBA8)
		_copiar_atlas(original, entrada[0])
	for variante in range(3):
		var imagen := TilesNaturaleza.preparar_imagen(TilesNaturaleza.TRANSICION, TilesNaturaleza.CELDAS_TRANSICION[variante], verde, true)
		for direccion in range(4):
			_copiar_atlas(TilesNaturaleza.rotar(imagen, direccion), ATLAS_TRANSICION + variante * 4 + direccion)
	_actualizar_atlas_oleaje(0)
	atlas_oleaje = ImageTexture.create_from_image(imagen_oleaje)
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = atlas_oleaje
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for tile_id in range(ATLAS_CANTIDAD):
		atlas_source.create_tile(Vector2i(tile_id, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(atlas_source, 0)
	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = tile_set
	terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(terrain_layer)


func _copiar_atlas(imagen: Image, indice: int) -> void:
	imagen_oleaje.blit_rect(imagen, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(indice * TILE_SIZE, 0))


func _actualizar_atlas_oleaje(fase: int) -> void:
	# 12 pasos comunes: seis cuadros de mar y cuatro de orilla.
	var mar := mar_frames[floori(float(fase) * 6.0 / 12.0)]
	var orilla := orilla_frames[floori(float(fase) * 4.0 / 12.0)]
	_copiar_atlas(mar, ATLAS_AGUA)
	_copiar_atlas(mar, ATLAS_AGUA + 1)
	for direccion in range(4):
		_copiar_atlas(TilesNaturaleza.rotar(orilla, direccion), ATLAS_ORILLA + direccion)
	if atlas_oleaje != null:
		atlas_oleaje.update(imagen_oleaje)


func _process(delta: float) -> void:
	if atlas_oleaje == null:
		return
	reloj_oleaje += delta
	var fase := posmod(floori(reloj_oleaje * 4.0), 12)
	if fase != fotograma_oleaje:
		fotograma_oleaje = fase
		_actualizar_atlas_oleaje(fase)


func _atlas_para_terreno(x: int, y: int, tipo: int) -> int:
	var variedad := posmod(hash(Vector3i(x, y, world_seed)), 1000)
	var vecinos := []
	if tipo == SAND or tipo == GRASS:
		for direccion: Vector2i in TilesNaturaleza.DIRECCIONES:
			vecinos.append(get_terrain(posmod(x + direccion.x, MAP_SIZE), posmod(y + direccion.y, MAP_SIZE)))
	if tipo == SAND:
		var borde := TilesNaturaleza.elegir_borde(vecinos, [WATER, DEEP_WATER])
		return ATLAS_ORILLA + borde if borde >= 0 else ATLAS_ARENA + variedad % 2
	if tipo == GRASS:
		var borde := TilesNaturaleza.elegir_borde(vecinos, [SAND])
		return ATLAS_TRANSICION + (variedad % 3) * 4 + borde if borde >= 0 else ATLAS_PASTO + variedad % 3
	if tipo == DIRT:
		return ATLAS_TIERRA
	if tipo == ROCK:
		return ATLAS_ROCA
	return ATLAS_AGUA + tipo


func generate_world() -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var terrain_id := get_terrain(x, y)
			terrain_layer.set_cell(Vector2i(x, y), 0, Vector2i(_atlas_para_terreno(x, y, terrain_id), 0))
		if y % 4 == 3:
			avance_generacion.emit("terreno", y + 1, MAP_SIZE)
			await get_tree().process_frame


func create_world_copies() -> void:
	var completado := 0
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
			completado += 1
			avance_generacion.emit("copias_terreno", completado, 8)
			await get_tree().process_frame



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
	var progreso: Dictionary = GestorMundos.mundo_actual.get("progreso", {})
	var datos_jugador: Dictionary = progreso.get("jugador", {})
	if datos_jugador.has("posicion"):
		var posicion: Dictionary = datos_jugador.posicion
		var tamano_anterior: int = int(GestorMundos.mundo_actual.get("tamano_tile", Dimensiones.TILE_SIZE_ANTERIOR))
		player.position = Vector2(posicion.x, posicion.y) * (float(TILE_SIZE) / tamano_anterior)

	add_child(player)
	player.set_physics_process(false)


func activar_juego() -> void:
	if generacion_lista:
		$Player.set_physics_process(true)
		$InterfazMundo.visible = true


func _crear_interfaz_mundo() -> void:
	var interfaz := CanvasLayer.new()
	interfaz.name = "InterfazMundo"
	interfaz.visible = false
	interfaz.set_script(load("res://script/interfaz/interfaz_mundo.gd"))
	add_child(interfaz)

#para bosques pt2
func is_forest_zone(x: int, y: int) -> bool:
	var forest_value: float = forest_noise.get_noise_2d(x, y)
	return forest_value > 0.25


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
const ATLAS_CANTIDAD := 48
const ATLAS_AGUA := 0
const ATLAS_ARENA := 6
const ATLAS_PASTO := 8
const ATLAS_TIERRA := 11
const ATLAS_ROCA := 12
const ATLAS_ORILLA := 13
const ATLAS_ORILLA_ESQUINA := 17
const ATLAS_TRANSICION := 21

const DEEP_WATER: int = 0
const WATER: int = 1
const SAND: int = 2
const GRASS: int = 3
const DIRT: int = 4
const ROCK: int = 5

# Margen pequeño para que el cambio de profundidad ocurra al pasar ligeramente
# por encima de la base visible (escala 32x32). Se aplica al eje de ordenación.
const MARGEN_PROFUNDIDAD_BASE := 3.0

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
var terreno_cache := PackedByteArray()
var terreno_visual := PackedByteArray()
const TAMANO_REGION_ANIMADA := 256.0
const TAMANO_REGION_VISIBILIDAD := 256.0
var regiones_animadas: Dictionary = {}
var animados_visibles: Dictionary = {}
var regiones_recursos_vis: Dictionary = {}
var recursos_visibles: Dictionary = {}
var celdas_visibles_recursos: Dictionary = {}
var celdas_visibles_animadas: Dictionary = {}
var arbustos_por_celda: Dictionary = {}
var temporizador_visibilidad := 0.0
var posicion_revision_animaciones := Vector2(INF, INF)
var tamano_revision_animaciones := Vector2.ZERO
var orillas_rectas: Array[Image] = []
var orillas_esquina: Array[Image] = []
var reloj_viento := RandomNumberGenerator.new()
var espera_viento := 2.0
var viento_activo: Array[AnimatedSprite2D] = []


func _ready() -> void:
	# La configuración se selecciona antes del cambio de escena; al abrir mundo.tscn
	# directamente se conserva la semilla exportada de la escena.
	if not GestorMundos.mundo_actual.is_empty():
		world_seed = GestorMundos.mundo_actual.semilla
		var progreso: Dictionary = GestorMundos.mundo_actual.get("progreso", {})
		inventario.cargar(progreso.get("inventario", {}))
		arbustos_recolectados = progreso.get("cambios_mundo", {}).get("arbustos_recolectados", {}).duplicate(true)
	y_sort_enabled = true
	reloj_viento.randomize()
	setup_noise()
	await _precalcular_terreno()
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
	var jugador := _obtener_jugador()
	if jugador == null:
		push_error("No se pudo preparar el jugador.")
		generacion_fallida.emit("No se pudo preparar el jugador.")
		return
	_colocar_jugador_en_posicion_segura(jugador)
	_colocar_nave_destrozada_cerca(jugador.global_position)
	setup_camera()
	await get_tree().process_frame
	_actualizar_animaciones_visibles()
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
	var margen := _margen_copias()

	for child in resources_layer.get_children():
		if child is Node2D and not child.name.ends_with("_VisualCopy") and not child.name.ends_with("_Emision"):
			var original := child as Node2D
			if not _es_recurso_visual(original):
				continue
			var pos_base := _posicion_base_recurso(original)
			# Solo los recursos cercanos a un borde pueden ser visibles desde
			# el otro lado con el zoom actual; se evita duplicar todo el bosque.
			if pos_base.x < margen or pos_base.x > WORLD_SIZE - margen or pos_base.y < margen or pos_base.y > WORLD_SIZE - margen:
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
				var pos_base := _posicion_base_recurso(original)
				if (offset_x == -1 and pos_base.x < WORLD_SIZE - margen) or (offset_x == 1 and pos_base.x > margen) or (offset_y == -1 and pos_base.y < WORLD_SIZE - margen) or (offset_y == 1 and pos_base.y > margen):
					continue
				var copy := _copiar_recurso(original)

				if copy == null:
					continue

				copy.position = original.position + offset
				copy.name = original.name + "_VisualCopy"
				resources_layer.add_child(copy)
				_indexar_recurso_visual(copy)
				_registrar_animaciones_recurso(copy)

				var arbusto_id := _id_arbusto_recurso(original)
				if not arbusto_id.is_empty():
					if not visuales_arbustos.has(arbusto_id):
						visuales_arbustos[arbusto_id] = []
					visuales_arbustos[arbusto_id].append(copy)
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
					tree_chance = 0.26
				else:
					tree_chance = 0.035

				if (in_forest or detail > -0.3) and resource_rng.randf() < tree_chance:
					var tipo := Catalogo.elegir_indice(Catalogo.PESOS_ARBOLES, resource_rng.randf())
					_colocar_animado("arbol_%d" % tipo, tile_center, float(Catalogo.ARBOLES[tipo].ancho), "")

				elif resource_rng.randf() < 0.10:
					var tipo := resource_rng.randi_range(0, Catalogo.ARBUSTOS.size() - 1)
					var datos_arbusto: Dictionary = Catalogo.ARBUSTOS[tipo]
					var id_arbusto := "%d_%d" % [x, y] if datos_arbusto.get("cosechable", false) else ""
					_colocar_animado("arbusto_%d" % tipo, tile_center, float(datos_arbusto.ancho), id_arbusto)
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
	if not _reservar_espacio(tile_center, tamano, true):
		return
	var contenedor := Node2D.new()
	contenedor.name = "Roca"
	contenedor.position = tile_center + Vector2(0, -MARGEN_PROFUNDIDAD_BASE)
	contenedor.set_meta("base_y", tile_center.y)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * escala
	sprite.position = Vector2(0, MARGEN_PROFUNDIDAD_BASE)
	sprite.offset.y = -textura.get_height() / 2.0
	contenedor.add_child(sprite)
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.position = Vector2(0, MARGEN_PROFUNDIDAD_BASE)
	contenedor.add_child(cuerpo)
	var colision := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	# Colisión en la zona sólida de la roca, ajustada al tamaño (más ancha).
	forma.size = Vector2(maxf(10.0, tamano.x * 0.82), maxf(6.0, tamano.y * 0.32))
	colision.shape = forma
	colision.position = Vector2(0, -forma.size.y * 0.5)
	cuerpo.add_child(colision)
	resources_layer.add_child(contenedor)
	_indexar_recurso_visual(contenedor)


func _preparar_recursos() -> void:
	for i in range(Catalogo.ARBOLES.size()):
		sprites_recursos["arbol_%d" % i] = Catalogo.fotogramas(Catalogo.ARBOLES[i].ruta)
	for i in range(Catalogo.ARBUSTOS.size()):
		sprites_recursos["arbusto_%d" % i] = Catalogo.fotogramas(Catalogo.ARBUSTOS[i].ruta)
		var datos: Dictionary = Catalogo.ARBUSTOS[i]
		if datos.has("vacio"):
			# Usar el recorte de contenido real del sprite "sin frutos" para evitar
			# regiones vacías (el recorte (0,0) puede caer fuera del contenido).
			var recorte_vacio := _recorte_union_imagen(String(datos.vacio))
			if recorte_vacio.size == Vector2i.ZERO:
				sprites_recursos["arbusto_%d_vacio" % i] = Catalogo.fotogramas(String(datos.vacio))
			else:
				sprites_recursos["arbusto_%d_vacio" % i] = Catalogo.fotogramas(String(datos.vacio), recorte_vacio)
	for i in range(Catalogo.PESOS_ROCAS.size()):
		texturas_rocas.append(Catalogo.roca(i))


func _recorte_union_imagen(ruta: String) -> Rect2i:
	var textura := load(ruta) as Texture2D
	if textura == null:
		return Rect2i()
	var imagen := textura.get_image()
	var union := Rect2i()
	for i in range(6):
		var celda := imagen.get_region(Rect2i(i * 180, 0, 180, 360))
		var rect := celda.get_used_rect()
		union = rect if union.size == Vector2i.ZERO else union.merge(rect)
	return union


func _reservar_espacio(posicion: Vector2, tamano: Vector2, usar_base := false) -> bool:
	# La huella usa la base del recurso para permitir solapes naturales de copas,
	# pero mantiene separación física suficiente entre troncos/raíces.
	var rect: Rect2
	if usar_base:
		var ancho := maxf(8.0, tamano.x * 0.38)
		var alto := maxf(6.0, tamano.y * 0.22)
		rect = Rect2(posicion - Vector2(ancho / 2.0, alto), Vector2(ancho, alto)).grow(2.0)
	else:
		rect = Rect2(posicion - Vector2(tamano.x / 2.0, tamano.y), tamano).grow(2.0)
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
	if not _reservar_espacio(posicion, tamano, true):
		return
	var contenedor := Node2D.new()
	contenedor.name = tipo
	contenedor.position = posicion + Vector2(0, -MARGEN_PROFUNDIDAD_BASE)
	contenedor.set_meta("base_y", posicion.y)
	contenedor.set_meta("tipo_recurso", tipo)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vacio: SpriteFrames = sprites_recursos.get(tipo + "_vacio", frames)
	sprite.sprite_frames = vacio if not arbusto_id.is_empty() and arbustos_recolectados.has(arbusto_id) else frames
	sprite.scale = Vector2.ONE * escala
	sprite.position = Vector2(0, MARGEN_PROFUNDIDAD_BASE)
	sprite.offset.y = -tamano_original.y / 2.0
	contenedor.add_child(sprite)
	if tipo.begins_with("arbol_"):
		var cuerpo := StaticBody2D.new()
		cuerpo.name = "Cuerpo"
		cuerpo.position = Vector2(0, MARGEN_PROFUNDIDAD_BASE)
		contenedor.add_child(cuerpo)
		var colision := CollisionShape2D.new()
		var forma := RectangleShape2D.new()
		# Colisión en el tronco/base, no en la copa (más ancha).
		forma.size = Vector2(maxf(10.0, tamano.x * 0.34), maxf(6.0, tamano.y * 0.14))
		colision.shape = forma
		colision.position = Vector2(0, -forma.size.y * 0.5)
		cuerpo.add_child(colision)
	elif tipo.begins_with("arbusto_"):
		var cuerpo := StaticBody2D.new()
		cuerpo.name = "Cuerpo"
		cuerpo.position = Vector2(0, MARGEN_PROFUNDIDAD_BASE)
		contenedor.add_child(cuerpo)
		var colision := CollisionShape2D.new()
		var forma := RectangleShape2D.new()
		# Colisión en la base del arbusto.
		forma.size = Vector2(maxf(10.0, tamano.x * 0.55), maxf(6.0, tamano.y * 0.30))
		colision.shape = forma
		colision.position = Vector2(0, -forma.size.y * 0.5)
		cuerpo.add_child(colision)
	resources_layer.add_child(contenedor)
	_indexar_recurso_visual(contenedor)
	_registrar_animacion(sprite)
	if not arbusto_id.is_empty():
		contenedor.set_meta("arbusto_id", arbusto_id)
		contenedor.set_meta("tipo_arbusto", tipo)
		sprite.set_meta("arbusto_id", arbusto_id)
		sprite.set_meta("tipo_arbusto", tipo)
		if not visuales_arbustos.has(arbusto_id):
			visuales_arbustos[arbusto_id] = []
		visuales_arbustos[arbusto_id].append(contenedor)
		var celda := Vector2i(floori(posicion.x / TILE_SIZE), floori(posicion.y / TILE_SIZE))
		arbustos_por_celda[celda] = arbusto_id


func _copiar_recurso(original: Node2D) -> Node2D:
	return original.duplicate() as Node2D


func _es_recurso_visual(nodo: Node) -> bool:
	return nodo is Node2D and (nodo.has_meta("base_y") or nodo.has_meta("tipo_recurso") or nodo.has_meta("arbusto_id") or String(nodo.name).begins_with("Roca") or String(nodo.name).begins_with("arbol_") or String(nodo.name).begins_with("arbusto_"))


func _posicion_base_recurso(recurso: Node2D) -> Vector2:
	if recurso.has_meta("base_y"):
		return Vector2(recurso.position.x, float(recurso.get_meta("base_y")))
	return recurso.position + Vector2(0, MARGEN_PROFUNDIDAD_BASE)


func _id_arbusto_recurso(recurso: Node) -> String:
	if recurso.has_meta("arbusto_id"):
		return String(recurso.get_meta("arbusto_id"))
	var sprite := _sprite_animado_recurso(recurso)
	if sprite != null and sprite.has_meta("arbusto_id"):
		return String(sprite.get_meta("arbusto_id"))
	return ""


func _colocar_nave_destrozada_cerca(posicion_jugador: Vector2) -> void:
	if resources_layer == null:
		return
	var textura := load("res://assets/recursos/nave_destrozada.png") as Texture2D
	if textura == null:
		return
	var ancho_deseado := 96.0
	var escala := ancho_deseado / textura.get_width()
	var tamano := textura.get_size() * escala
	var rng_nave := RandomNumberGenerator.new()
	rng_nave.seed = world_seed + 77777

	var posicion := Vector2.ZERO
	var encontrada := false
	for intento in range(120):
		var angulo := rng_nave.randf() * TAU
		var distancia := rng_nave.randf_range(TILE_SIZE * 3.0, TILE_SIZE * 7.0)
		var candidato := posicion_jugador + Vector2(cos(angulo), sin(angulo)) * distancia
		candidato.x = fposmod(candidato.x, WORLD_SIZE)
		candidato.y = fposmod(candidato.y, WORLD_SIZE)
		if _posicion_valida_nave(candidato) and _reservar_espacio(candidato, tamano, true):
			posicion = candidato
			encontrada = true
			break
	if not encontrada:
		for radio in range(3, 24):
			for paso in range(24):
				var ang := float(paso) / 24.0 * TAU
				var candidato := posicion_jugador + Vector2(cos(ang), sin(ang)) * float(radio) * TILE_SIZE
				candidato.x = fposmod(candidato.x, WORLD_SIZE)
				candidato.y = fposmod(candidato.y, WORLD_SIZE)
				if _posicion_valida_nave(candidato) and _reservar_espacio(candidato, tamano, true):
					posicion = candidato
					encontrada = true
					break
			if encontrada:
				break
	if not encontrada:
		posicion = posicion_jugador + Vector2(TILE_SIZE * 4.0, 0.0)
		posicion.x = fposmod(posicion.x, WORLD_SIZE)
		posicion.y = fposmod(posicion.y, WORLD_SIZE)
		_reservar_espacio(posicion, tamano, true)

	var contenedor := Node2D.new()
	contenedor.name = "NaveDestrozada"
	contenedor.position = posicion + Vector2(0, -MARGEN_PROFUNDIDAD_BASE)
	contenedor.set_meta("base_y", posicion.y)
	contenedor.set_meta("tipo_recurso", "nave_destrozada")

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * escala
	sprite.position = Vector2(0, MARGEN_PROFUNDIDAD_BASE)
	sprite.offset.y = -textura.get_height() / 2.0
	contenedor.add_child(sprite)

	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.position = Vector2(0, MARGEN_PROFUNDIDAD_BASE)
	contenedor.add_child(cuerpo)
	var colision := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(maxf(16.0, tamano.x * 0.70), maxf(8.0, tamano.y * 0.25))
	colision.shape = forma
	colision.position = Vector2(0, -forma.size.y * 0.5)
	cuerpo.add_child(colision)

	resources_layer.add_child(contenedor)
	_indexar_recurso_visual(contenedor)
	_crear_copias_borde_recurso(contenedor)


func _posicion_valida_nave(posicion: Vector2) -> bool:
	var tx := posmod(floori(posicion.x / TILE_SIZE), MAP_SIZE)
	var ty := posmod(floori(posicion.y / TILE_SIZE), MAP_SIZE)
	var t := get_terrain(tx, ty)
	if t == DEEP_WATER or t == WATER:
		return false
	# Evitar colocarla justo encima del jugador.
	if resources_layer != null:
		var jugador := _obtener_jugador()
		if jugador != null and posicion.distance_to(jugador.global_position) < TILE_SIZE * 2.0:
			return false
	return true


func _crear_copias_borde_recurso(original: Node2D) -> void:
	var margen := _margen_copias()
	var pos_base := _posicion_base_recurso(original)
	if not (pos_base.x < margen or pos_base.x > WORLD_SIZE - margen or pos_base.y < margen or pos_base.y > WORLD_SIZE - margen):
		return
	for offset_y in [-1, 0, 1]:
		for offset_x in [-1, 0, 1]:
			if offset_x == 0 and offset_y == 0:
				continue
			var cerca_x: bool = (offset_x == -1 and pos_base.x < margen) or (offset_x == 1 and pos_base.x > WORLD_SIZE - margen) or (offset_x == 0)
			var cerca_y: bool = (offset_y == -1 and pos_base.y < margen) or (offset_y == 1 and pos_base.y > WORLD_SIZE - margen) or (offset_y == 0)
			var necesita: bool = (offset_x == -1 and pos_base.x < margen) or (offset_x == 1 and pos_base.x > WORLD_SIZE - margen) or (offset_y == -1 and pos_base.y < margen) or (offset_y == 1 and pos_base.y > WORLD_SIZE - margen)
			if not necesita or not cerca_x or not cerca_y:
				continue
			var copy := _copiar_recurso(original)
			if copy == null:
				continue
			copy.position = original.position + Vector2(offset_x * WORLD_SIZE, offset_y * WORLD_SIZE)
			copy.name = original.name + "_VisualCopy"
			resources_layer.add_child(copy)
			_indexar_recurso_visual(copy)
			_registrar_animaciones_recurso(copy)


func _sprite_animado_recurso(recurso: Node) -> AnimatedSprite2D:
	if recurso == null:
		return null
	if recurso is AnimatedSprite2D:
		return recurso as AnimatedSprite2D
	if recurso.has_node("Sprite"):
		var n := recurso.get_node("Sprite")
		if n is AnimatedSprite2D:
			return n as AnimatedSprite2D
	for child in recurso.get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D
	return null


func _sprites_animados_recurso(recurso: Node) -> Array[AnimatedSprite2D]:
	var resultado: Array[AnimatedSprite2D] = []
	if recurso == null:
		return resultado
	if recurso is AnimatedSprite2D:
		resultado.append(recurso as AnimatedSprite2D)
		return resultado
	for child in recurso.get_children():
		if child is AnimatedSprite2D:
			resultado.append(child as AnimatedSprite2D)
	return resultado


func _registrar_animaciones_recurso(recurso: Node) -> void:
	for sprite in _sprites_animados_recurso(recurso):
		_registrar_animacion(sprite)




func recolectar_cercano(posicion: Vector2, alcance: float = 60.0) -> bool:
	var mas_cercano := ""
	var distancia := alcance
	var centro := Vector2i(floori(posicion.x / TILE_SIZE), floori(posicion.y / TILE_SIZE))
	var radio := ceili(alcance / TILE_SIZE) + 1
	for y in range(-radio, radio + 1):
		for x in range(-radio, radio + 1):
			var celda := Vector2i(posmod(centro.x + x, MAP_SIZE), posmod(centro.y + y, MAP_SIZE))
			var id: String = arbustos_por_celda.get(celda, "")
			if id.is_empty() or arbustos_recolectados.has(id):
				continue
			var visuales: Array = visuales_arbustos.get(id, [])
			if visuales.is_empty():
				continue
			var original: Node2D = visuales[0] as Node2D
			if original == null:
				continue
			var pos_base := _posicion_base_recurso(original)
			var delta := (pos_base - posicion).abs()
			delta.x = minf(fposmod(delta.x, WORLD_SIZE), WORLD_SIZE - fposmod(delta.x, WORLD_SIZE))
			delta.y = minf(fposmod(delta.y, WORLD_SIZE), WORLD_SIZE - fposmod(delta.y, WORLD_SIZE))
			if delta.length() <= distancia:
				distancia = delta.length()
				mas_cercano = id
	if mas_cercano.is_empty():
		return false
	var visuales_objetivo: Array = visuales_arbustos.get(mas_cercano, [])
	if visuales_objetivo.is_empty():
		return false
	var nodo_ref: Node = visuales_objetivo[0]
	var tipo: String = String(nodo_ref.get_meta("tipo_arbusto", "arbusto_1"))
	var sprite_ref := _sprite_animado_recurso(nodo_ref)
	if sprite_ref != null and sprite_ref.has_meta("tipo_arbusto"):
		tipo = String(sprite_ref.get_meta("tipo_arbusto", tipo))
	var indice := int(tipo.trim_prefix("arbusto_"))
	var datos: Dictionary = Catalogo.ARBUSTOS[clampi(indice, 0, Catalogo.ARBUSTOS.size() - 1)]
	var cantidad := int(datos.get("frutos", 2))
	var item_id := String(datos.get("item_id", "fruto_alienigena"))
	var item_nombre := String(datos.get("item_nombre", "Fruto alienígena"))
	var item_def := {"icono": String(datos.get("item_icono", ""))}
	if inventario.has_method("puede_agregar") and not inventario.puede_agregar(item_id, cantidad):
		var interfaz_llena := get_node_or_null("InterfazMundo")
		if interfaz_llena != null and interfaz_llena.has_method("mostrar_mensaje"):
			interfaz_llena.mostrar_mensaje("Inventario lleno")
		return false
	if not inventario.agregar(item_id, item_nombre, cantidad, item_def):
		var interfaz_llena := get_node_or_null("InterfazMundo")
		if interfaz_llena != null and interfaz_llena.has_method("mostrar_mensaje"):
			interfaz_llena.mostrar_mensaje("Inventario lleno")
		return false
	arbustos_recolectados[mas_cercano] = true
	var interfaz := get_node_or_null("InterfazMundo")
	if interfaz != null and interfaz.has_method("actualizar_inventario"):
		interfaz.actualizar_inventario()
	for recurso in visuales_objetivo:
		if recurso == null or not is_instance_valid(recurso):
			continue
		var sprite := _sprite_animado_recurso(recurso)
		if sprite == null:
			continue
		var tipo_sprite := String(recurso.get_meta("tipo_arbusto", tipo))
		if sprite.has_meta("tipo_arbusto"):
			tipo_sprite = String(sprite.get_meta("tipo_arbusto", tipo_sprite))
		var estaba_activo := sprite.is_playing()
		var vacio: SpriteFrames = sprites_recursos.get(tipo_sprite + "_vacio", sprite.sprite_frames)
		sprite.sprite_frames = vacio
		sprite.frame = 0
		if estaba_activo:
			sprite.play("viento")
		else:
			sprite.stop()
	return true


func _registrar_animacion(sprite: AnimatedSprite2D) -> void:
	sprite.animation = "viento"
	sprite.stop()
	sprite.frame = 0
	_indexar_animacion(sprite)


func _indexar_animacion(sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(sprite):
		return
	var celda := Vector2i(floori(sprite.global_position.x / TAMANO_REGION_ANIMADA), floori(sprite.global_position.y / TAMANO_REGION_ANIMADA))
	if not regiones_animadas.has(celda):
		regiones_animadas[celda] = []
	regiones_animadas[celda].append(sprite)


func _indexar_recurso_visual(recurso: Node2D) -> void:
	if not is_instance_valid(recurso):
		return
	if recurso.name == "Player":
		return
	var base := _posicion_base_recurso(recurso)
	var celda := Vector2i(floori(base.x / TAMANO_REGION_VISIBILIDAD), floori(base.y / TAMANO_REGION_VISIBILIDAD))
	if not regiones_recursos_vis.has(celda):
		regiones_recursos_vis[celda] = []
	regiones_recursos_vis[celda].append(recurso)
	# Oculto por defecto; se mostrará cuando entre en rango visible.
	recurso.visible = false


func _actualizar_animaciones_visibles() -> void:
	if world_camera == null:
		return
	var centro := world_camera.get_screen_center_position()
	var mitad := get_viewport_rect().size / world_camera.zoom / 2.0 + Vector2(192, 192)
	posicion_revision_animaciones = centro
	tamano_revision_animaciones = mitad
	var visible_rect := Rect2(centro - mitad, mitad * 2.0)

	# Visibilidad por celdas: solo se procesan celdas que entran/salen del rango.
	var nuevas_celdas_recursos := {}
	var inicio_r := Vector2i(floori(visible_rect.position.x / TAMANO_REGION_VISIBILIDAD), floori(visible_rect.position.y / TAMANO_REGION_VISIBILIDAD))
	var fin_r := Vector2i(floori(visible_rect.end.x / TAMANO_REGION_VISIBILIDAD), floori(visible_rect.end.y / TAMANO_REGION_VISIBILIDAD))
	for y in range(inicio_r.y, fin_r.y + 1):
		for x in range(inicio_r.x, fin_r.x + 1):
			var celda := Vector2i(x, y)
			nuevas_celdas_recursos[celda] = true
			if not celdas_visibles_recursos.has(celda):
				for recurso: Node2D in regiones_recursos_vis.get(celda, []):
					if is_instance_valid(recurso):
						recurso.visible = true
	for celda: Vector2i in celdas_visibles_recursos.keys():
		if not nuevas_celdas_recursos.has(celda):
			for recurso: Node2D in regiones_recursos_vis.get(celda, []):
				if is_instance_valid(recurso):
					recurso.visible = false
	celdas_visibles_recursos = nuevas_celdas_recursos

	# Sprites animados visibles para ráfagas de viento (también por celdas).
	var nuevas_celdas_animadas := {}
	var inicio_a := Vector2i(floori(visible_rect.position.x / TAMANO_REGION_ANIMADA), floori(visible_rect.position.y / TAMANO_REGION_ANIMADA))
	var fin_a := Vector2i(floori(visible_rect.end.x / TAMANO_REGION_ANIMADA), floori(visible_rect.end.y / TAMANO_REGION_ANIMADA))
	for y in range(inicio_a.y, fin_a.y + 1):
		for x in range(inicio_a.x, fin_a.x + 1):
			var celda := Vector2i(x, y)
			nuevas_celdas_animadas[celda] = true
			if not celdas_visibles_animadas.has(celda):
				for sprite: AnimatedSprite2D in regiones_animadas.get(celda, []):
					if is_instance_valid(sprite):
						animados_visibles[sprite] = true
	for celda: Vector2i in celdas_visibles_animadas.keys():
		if not nuevas_celdas_animadas.has(celda):
			for sprite: AnimatedSprite2D in regiones_animadas.get(celda, []):
				if not is_instance_valid(sprite):
					continue
				if animados_visibles.has(sprite):
					animados_visibles.erase(sprite)
				sprite.stop()
				sprite.frame = 0
				viento_activo.erase(sprite)
	celdas_visibles_animadas = nuevas_celdas_animadas


func _actualizar_viento(delta: float) -> void:
	for i in range(viento_activo.size() - 1, -1, -1):
		var sprite := viento_activo[i]
		if not is_instance_valid(sprite) or not animados_visibles.has(sprite):
			if is_instance_valid(sprite):
				sprite.stop()
				sprite.frame = 0
			viento_activo.remove_at(i)
		elif sprite.frame >= sprite.sprite_frames.get_frame_count("viento") - 1:
			sprite.stop()
			sprite.frame = 0
			viento_activo.remove_at(i)
	espera_viento -= delta
	if espera_viento > 0.0:
		return
	espera_viento = reloj_viento.randf_range(1.5, 4.0)
	var candidatos := animados_visibles.keys()
	if candidatos.is_empty():
		return
	var cantidad := mini(reloj_viento.randi_range(1, 3), candidatos.size())
	for i in range(cantidad):
		var indice := reloj_viento.randi_range(0, candidatos.size() - 1)
		var sprite := candidatos[indice] as AnimatedSprite2D
		candidatos.remove_at(indice)
		if is_instance_valid(sprite) and not viento_activo.has(sprite):
			sprite.frame = 0
			sprite.play("viento")
			viento_activo.append(sprite)



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
	if terreno_cache.size() == MAP_SIZE * MAP_SIZE:
		return terreno_cache[posmod(y, MAP_SIZE) * MAP_SIZE + posmod(x, MAP_SIZE)]
	return _calcular_terreno(x, y)


func _calcular_terreno(x: int, y: int) -> int:
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


func _precalcular_terreno() -> void:
	# Un cálculo por celda; la búsqueda de vecinos y recursos consulta el mismo
	# resultado. Se guarda en bytes y no altera los valores del ruido.
	terreno_cache.resize(0)
	var cache := PackedByteArray()
	cache.resize(MAP_SIZE * MAP_SIZE)
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			cache[y * MAP_SIZE + x] = _calcular_terreno(x, y)
		if y % 8 == 7 and is_inside_tree():
			await get_tree().process_frame
	terreno_cache = cache
	# Suavizar solamente la representación visual. El terreno lógico, recursos,
	# velocidades y guardados conservan exactamente la semilla original.
	var visual := cache.duplicate()
	for pasada in range(2):
		var siguiente := visual.duplicate()
		for y in range(MAP_SIZE):
			for x in range(MAP_SIZE):
				var indice := y * MAP_SIZE + x
				var actual := int(visual[indice])
				var conteo := [0, 0, 0, 0, 0, 0]
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var vecino := int(visual[posmod(y + dy, MAP_SIZE) * MAP_SIZE + posmod(x + dx, MAP_SIZE)])
						conteo[vecino] += 1
				var mayor := actual
				for tipo in range(TERRAIN_COUNT):
					if conteo[tipo] > conteo[mayor]:
						mayor = tipo
				if conteo[actual] <= 2 and conteo[mayor] >= 5:
					siguiente[indice] = mayor
			if y % 16 == 15 and is_inside_tree():
				await get_tree().process_frame
		visual = siguiente
	visual = _limpiar_terreno_visual(visual)
	terreno_visual = visual


func _limpiar_terreno_visual(visual: PackedByteArray) -> PackedByteArray:
	# Corrección puramente visual: quita puntas y puentes de una celda, islas
	# diminutas de arena/césped y asegura una playa entre el césped y el agua.
	# El terreno lógico de colisiones, velocidades y recursos no cambia.
	var candidatos := PackedInt32Array()
	for indice in range(visual.size()):
		var tipo := int(visual[indice])
		if tipo == SAND or tipo == GRASS:
			candidatos.append(indice)
	for pasada in range(3):
		var cambios := 0
		for indice in candidatos:
			var actual := int(visual[indice])
			if actual != SAND and actual != GRASS:
				continue
			var y := indice / MAP_SIZE
			var x := indice - y * MAP_SIZE
			var x_izq := (x + MAP_SIZE - 1) % MAP_SIZE
			var x_der := (x + 1) % MAP_SIZE
			var fila_arr := ((y + MAP_SIZE - 1) % MAP_SIZE) * MAP_SIZE
			var fila_aba := ((y + 1) % MAP_SIZE) * MAP_SIZE
			var fila := y * MAP_SIZE
			var arriba := int(visual[fila_arr + x])
			var abajo := int(visual[fila_aba + x])
			var izquierda := int(visual[fila + x_izq])
			var derecha := int(visual[fila + x_der])
			var agua_izq := izquierda == WATER or izquierda == DEEP_WATER
			var agua_der := derecha == WATER or derecha == DEEP_WATER
			var agua_arr := arriba == WATER or arriba == DEEP_WATER
			var agua_aba := abajo == WATER or abajo == DEEP_WATER
			var agua := int(agua_izq) + int(agua_der) + int(agua_arr) + int(agua_aba)
			var nuevo := actual
			if actual == GRASS:
				# El césped nunca debe tocar el mar directamente: se convierte
				# en playa. Tampoco puede formar puntas o líneas de una celda.
				var arena := int(izquierda == SAND) + int(derecha == SAND) + int(arriba == SAND) + int(abajo == SAND)
				var arena_opuesta := (izquierda == SAND and derecha == SAND) or (arriba == SAND and abajo == SAND)
				if agua > 0:
					nuevo = SAND
				elif arena >= 3 or (arena == 2 and arena_opuesta):
					nuevo = SAND
			else:
				# La arena no puede sobresalir en el agua ni quedar como una
				# mota suelta en medio del césped.
				var cesped := int(izquierda == GRASS) + int(derecha == GRASS) + int(arriba == GRASS) + int(abajo == GRASS)
				var agua_opuesta := (agua_izq and agua_der) or (agua_arr and agua_aba)
				if agua >= 3 or (agua == 2 and agua_opuesta):
					nuevo = WATER
				elif agua == 0 and cesped >= 3:
					nuevo = GRASS
			if nuevo != actual:
				# Actualización en sitio: en un tablero de ajedrez césped/arena las
				# dos celdas se intercambiarían indefinidamente si se aplicaran a la
				# vez. En sitio la primera decisión fija el patrón y termina.
				visual[indice] = nuevo
				cambios += 1
		if cambios == 0:
			break
	return visual


func setup_terrain() -> void:
	imagen_oleaje = Image.create(TILE_SIZE * ATLAS_CANTIDAD, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var azul := Color(0.09, 0.01, 0.29)
	var arena := Color(0.87, 0.43, 0.34)
	var verde := Color(0.0, 0.37, 0.48)
	for region in TilesNaturaleza.CELDAS_MAR:
		mar_frames.append(TilesNaturaleza.preparar_imagen(TilesNaturaleza.MAR, region, azul))
	var orilla_recta := TilesNaturaleza.preparar_imagen(
		TilesNaturaleza.ARENA_AGUA,
		TilesNaturaleza.CELDAS_ARENA_AGUA[0],
		azul
	)
	var orilla_esquina := TilesNaturaleza.preparar_imagen(
		TilesNaturaleza.ARENA_AGUA,
		TilesNaturaleza.CELDAS_ARENA_AGUA[1],
		azul
	)
	orilla_frames.append(orilla_recta)
	orilla_frames.append(orilla_esquina)
	for direccion in range(4):
		orillas_rectas.append(TilesNaturaleza.rotar(orilla_recta, direccion))
		orillas_esquina.append(TilesNaturaleza.rotar(orilla_esquina, direccion))
	for i in range(2):
		_copiar_atlas(TilesNaturaleza.preparar_imagen(TilesNaturaleza.ARENA, TilesNaturaleza.CELDAS_ARENA[i], arena, false, 0.02, true), ATLAS_ARENA + i)
	for i in range(3):
		_copiar_atlas(TilesNaturaleza.preparar_imagen(TilesNaturaleza.PASTO, TilesNaturaleza.CELDAS_PASTO[i], verde, false, 0.02, true), ATLAS_PASTO + i)
	# Tierra y roca de terreno derivadas de recursos existentes (sustituyen tiles antiguos).
	var tierra_base := TilesNaturaleza.preparar_imagen(TilesNaturaleza.ARENA, TilesNaturaleza.CELDAS_ARENA[0], Color(0.55, 0.36, 0.24), false, 0.02, true)
	var tierra := tierra_base.duplicate() as Image
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var c := tierra.get_pixel(x, y)
			tierra.set_pixel(x, y, Color(c.r * 0.78, c.g * 0.62, c.b * 0.50, 1.0))
	_copiar_atlas(tierra, ATLAS_TIERRA)
	var roca_base := TilesNaturaleza.preparar_imagen(TilesNaturaleza.ARENA, TilesNaturaleza.CELDAS_ARENA[1], Color(0.45, 0.45, 0.48), false, 0.02, true)
	var roca_terreno := roca_base.duplicate() as Image
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var c := roca_terreno.get_pixel(x, y)
			var gris := (c.r + c.g + c.b) / 3.0 * 0.72
			roca_terreno.set_pixel(x, y, Color(gris * 0.95, gris, gris * 1.05, 1.0))
	_copiar_atlas(roca_terreno, ATLAS_ROCA)
	for variante in range(3):
		var imagen := TilesNaturaleza.preparar_imagen(TilesNaturaleza.TRANSICION, TilesNaturaleza.CELDAS_TRANSICION[variante], verde, true)
		var rotadas: Array[Image] = []
		for direccion in range(4):
			rotadas.append(TilesNaturaleza.rotar(imagen, direccion))
			_copiar_atlas(rotadas[direccion], ATLAS_TRANSICION + variante * 8 + direccion)
		for par in range(4):
			var esquina := TilesNaturaleza.unir_transiciones(rotadas[par], rotadas[(par + 1) % 4])
			_copiar_atlas(esquina, ATLAS_TRANSICION + variante * 8 + 4 + par)
	_precalcular_atlas_oleaje()
	atlas_oleaje = ImageTexture.create_from_image(_atlas_oleaje_fases[0])
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
	# El terreno queda siempre detrás de recursos y jugador; así el jugador puede
	# ocultarse tras una roca sin desaparecer bajo el mapa.
	terrain_layer.z_index = -2
	add_child(terrain_layer)


var _atlas_oleaje_fases: Array[Image] = []


func _copiar_atlas(imagen: Image, indice: int) -> void:
	imagen_oleaje.blit_rect(imagen, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(indice * TILE_SIZE, 0))


func _precalcular_atlas_oleaje() -> void:
	_atlas_oleaje_fases.clear()
	for fase in range(12):
		var mar := mar_frames[floori(float(fase) * 6.0 / 12.0)]
		_copiar_atlas(mar, ATLAS_AGUA)
		_copiar_atlas(mar, ATLAS_AGUA + 1)
		for direccion in range(4):
			_copiar_atlas(orillas_rectas[direccion], ATLAS_ORILLA + direccion)
			_copiar_atlas(orillas_esquina[direccion], ATLAS_ORILLA_ESQUINA + direccion)
		_atlas_oleaje_fases.append(imagen_oleaje.duplicate() as Image)
	# Restaurar fase 0 en la imagen base.
	imagen_oleaje = (_atlas_oleaje_fases[0].duplicate() as Image)


func _actualizar_atlas_oleaje(fase: int) -> void:
	if atlas_oleaje == null:
		return
	if _atlas_oleaje_fases.size() == 12:
		atlas_oleaje.update(_atlas_oleaje_fases[fase])
	else:
		# Respaldo: comportamiento anterior.
		var mar := mar_frames[floori(float(fase) * 6.0 / 12.0)]
		_copiar_atlas(mar, ATLAS_AGUA)
		_copiar_atlas(mar, ATLAS_AGUA + 1)
		for direccion in range(4):
			_copiar_atlas(orillas_rectas[direccion], ATLAS_ORILLA + direccion)
			_copiar_atlas(orillas_esquina[direccion], ATLAS_ORILLA_ESQUINA + direccion)
		atlas_oleaje.update(imagen_oleaje)


func _process(delta: float) -> void:
	if atlas_oleaje == null:
		return
	reloj_oleaje += delta
	var fase := posmod(floori(reloj_oleaje * 4.0), 12)
	if fase != fotograma_oleaje:
		fotograma_oleaje = fase
		_actualizar_atlas_oleaje(fase)
	if world_camera != null:
		_actualizar_viento(delta)
		temporizador_visibilidad += delta
		if temporizador_visibilidad >= 0.25:
			temporizador_visibilidad = 0.0
			var centro := world_camera.get_screen_center_position()
			var mitad := get_viewport_rect().size / world_camera.zoom / 2.0 + Vector2(192, 192)
			if centro.distance_squared_to(posicion_revision_animaciones) >= 1024.0 or mitad != tamano_revision_animaciones:
				_actualizar_animaciones_visibles()



func _atlas_para_terreno(x: int, y: int, tipo: int) -> int:
	if tipo == SAND:
		var v0 := _terreno_visual(x + 1, y)
		var v1 := _terreno_visual(x, y + 1)
		var v2 := _terreno_visual(x - 1, y)
		var v3 := _terreno_visual(x, y - 1)
		var a0 := v0 == WATER or v0 == DEEP_WATER
		var a1 := v1 == WATER or v1 == DEEP_WATER
		var a2 := v2 == WATER or v2 == DEEP_WATER
		var a3 := v3 == WATER or v3 == DEEP_WATER
		var ca := int(a0) + int(a1) + int(a2) + int(a3)
		if ca == 1:
			if a0: return ATLAS_ORILLA
			if a1: return ATLAS_ORILLA + 1
			if a2: return ATLAS_ORILLA + 2
			return ATLAS_ORILLA + 3
		if ca == 2:
			if a0 and a1: return ATLAS_ORILLA_ESQUINA + 1
			if a1 and a2: return ATLAS_ORILLA_ESQUINA + 2
			if a2 and a3: return ATLAS_ORILLA_ESQUINA + 3
			if a3 and a0: return ATLAS_ORILLA_ESQUINA
		var variedad := posmod(hash(Vector3i(x, y, world_seed)), 1000)
		return ATLAS_ARENA + variedad % 2
	if tipo == GRASS:
		var s0 := _terreno_visual(x + 1, y) == SAND
		var s1 := _terreno_visual(x, y + 1) == SAND
		var s2 := _terreno_visual(x - 1, y) == SAND
		var s3 := _terreno_visual(x, y - 1) == SAND
		var cs := int(s0) + int(s1) + int(s2) + int(s3)
		var variedad := posmod(hash(Vector3i(x, y, world_seed)), 1000)
		var indice := ATLAS_TRANSICION + (variedad % 3) * 8
		if cs == 1:
			if s0: return indice
			if s1: return indice + 1
			if s2: return indice + 2
			return indice + 3
		if cs >= 2:
			if s0 and s1: return indice + 4
			if s1 and s2: return indice + 5
			if s2 and s3: return indice + 6
			if s3 and s0: return indice + 7
		return ATLAS_PASTO + variedad % 3
	if tipo == DIRT:
		return ATLAS_TIERRA
	if tipo == ROCK:
		return ATLAS_ROCA
	return ATLAS_AGUA + tipo


func generate_world() -> void:
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var terrain_id := _terreno_visual(x, y)
			terrain_layer.set_cell(Vector2i(x, y), 0, Vector2i(_atlas_para_terreno(x, y, terrain_id), 0))
		if y % 4 == 3:
			avance_generacion.emit("terreno", y + 1, MAP_SIZE)
			await get_tree().process_frame


func _terreno_visual(x: int, y: int) -> int:
	if terreno_visual.size() == MAP_SIZE * MAP_SIZE:
		return terreno_visual[posmod(y, MAP_SIZE) * MAP_SIZE + posmod(x, MAP_SIZE)]
	return get_terrain(x, y)


func create_world_copies() -> void:
	var completado := 0
	# Solo se necesitan las franjas próximas a los bordes: la cámara nunca se
	# aleja del jugador antes de que este vuelva a la región central por wrap.
	var margen := _margen_copias()
	var margen_celdas := mini(MAP_SIZE, ceili(margen / TILE_SIZE))
	for offset_y in [-1, 0, 1]:
		for offset_x in [-1, 0, 1]:
			if offset_x == 0 and offset_y == 0:
				continue

			var copy := TileMapLayer.new()
			copy.name = "TerrainCopy_%d_%d" % [offset_x, offset_y]
			copy.tile_set = terrain_layer.tile_set
			copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			copy.z_index = -2
			copy.position = Vector2(
				offset_x * WORLD_SIZE,
				offset_y * WORLD_SIZE
			)
			add_child(copy)
			var x_inicio := MAP_SIZE - margen_celdas if offset_x == -1 else 0
			var x_fin := margen_celdas if offset_x == 1 else MAP_SIZE
			var y_inicio := MAP_SIZE - margen_celdas if offset_y == -1 else 0
			var y_fin := margen_celdas if offset_y == 1 else MAP_SIZE
			for y in range(y_inicio, y_fin):
				for x in range(x_inicio, x_fin):
					var celda := Vector2i(x, y)
					copy.set_cell(celda, 0, terrain_layer.get_cell_atlas_coords(celda))
				if (y - y_inicio) % 16 == 15:
					await get_tree().process_frame
			completado += 1
			avance_generacion.emit("copias_terreno", completado, 8)
			await get_tree().process_frame


func _margen_copias() -> float:
	# Considera también una ventana ampliada después de entrar al mundo.
	var pantalla := Vector2(DisplayServer.screen_get_size())
	var viewport := get_viewport_rect().size
	var lado := maxf(maxf(pantalla.x, pantalla.y), maxf(viewport.x, viewport.y))
	return minf(WORLD_SIZE, maxf(640.0, lado / 6.0 + 160.0))



func _obtener_jugador() -> Node2D:
	var jugador := get_node_or_null("Recursos/Player") as Node2D
	if jugador == null:
		jugador = find_child("Player", true, false) as Node2D
	return jugador


func setup_camera() -> void:
	var player := _obtener_jugador()
	if player == null:
		return

	world_camera = Camera2D.new()
	world_camera.name = "WorldCamera"
	world_camera.position_smoothing_enabled = true
	world_camera.position_smoothing_speed = 5.0
	world_camera.zoom = Vector2(3.0, 3.0)

	player.add_child(world_camera)
	world_camera.make_current()


func wrap_camera_position() -> void:
	var player := _obtener_jugador()
	if player == null:
		return

	player.position.x = fposmod(player.position.x, WORLD_SIZE)
	player.position.y = fposmod(player.position.y, WORLD_SIZE)

func create_player() -> CharacterBody2D:
	var player_scene: PackedScene = load("res://escenas/player.tscn")

	if player_scene == null:
		push_error("No se pudo cargar la escena del personaje.")
		return null

	var player: CharacterBody2D = player_scene.instantiate()
	player.name = "Player"
	player.position = Vector2(WORLD_SIZE / 2.0, WORLD_SIZE / 2.0)
	var progreso: Dictionary = GestorMundos.mundo_actual.get("progreso", {})
	var datos_jugador: Dictionary = progreso.get("jugador", {})
	if datos_jugador.has("posicion"):
		var posicion: Dictionary = datos_jugador.posicion
		var tamano_anterior: int = int(GestorMundos.mundo_actual.get("tamano_tile", Dimensiones.TILE_SIZE_ANTERIOR))
		player.position = Vector2(posicion.x, posicion.y) * (float(TILE_SIZE) / tamano_anterior)

	if resources_layer != null:
		resources_layer.add_child(player)
	else:
		add_child(player)
	player.set_physics_process(false)
	return player


func _colocar_jugador_en_posicion_segura(player: Node2D) -> void:
	if player == null or resources_layer == null:
		return
	if not _posicion_jugador_bloqueada(player.global_position):
		return
	var origen := player.global_position
	for radio in range(1, 24):
		for dy in range(-radio, radio + 1):
			for dx in range(-radio, radio + 1):
				if abs(dx) != radio and abs(dy) != radio:
					continue
				var candidato := origen + Vector2(dx, dy) * float(TILE_SIZE)
				candidato.x = fposmod(candidato.x, WORLD_SIZE)
				candidato.y = fposmod(candidato.y, WORLD_SIZE)
				if not _posicion_jugador_bloqueada(candidato):
					player.global_position = candidato
					return
	# Último recurso: centro del mundo si es viable.
	var centro := Vector2(WORLD_SIZE / 2.0, WORLD_SIZE / 2.0)
	if not _posicion_jugador_bloqueada(centro):
		player.global_position = centro


func _posicion_jugador_bloqueada(pos_global: Vector2) -> bool:
	if resources_layer == null:
		return false
	for child in resources_layer.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.name == "Player" or child.is_in_group("player"):
			continue
		if not child.has_node("Cuerpo"):
			continue
		var cuerpo := child.get_node("Cuerpo")
		for c in cuerpo.get_children():
			if not (c is CollisionShape2D):
				continue
			var shape := (c as CollisionShape2D).shape
			if shape is RectangleShape2D:
				var rect_shape := shape as RectangleShape2D
				var half := rect_shape.size * 0.5 + Vector2(4, 4)
				var centro_col := (c as CollisionShape2D).global_position
				if absf(pos_global.x - centro_col.x) <= half.x and absf(pos_global.y - centro_col.y) <= half.y:
					return true
			elif shape is CircleShape2D:
				var radio := (shape as CircleShape2D).radius + 4.0
				if pos_global.distance_to((c as CollisionShape2D).global_position) <= radio:
					return true
	return false


func activar_juego() -> void:
	if generacion_lista:
		var jugador := _obtener_jugador()
		if jugador != null:
			jugador.set_physics_process(true)
		var interfaz := get_node_or_null("InterfazMundo")
		if interfaz != null:
			interfaz.visible = true


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

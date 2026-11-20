extends Control

const FONDO = preload("res://recursos_interfaz/fondos/fondo_de_carga.png")
const BARRAS = preload("res://recursos_interfaz/fondos/barra_de_carga.png")
const REGIONES: Array[Rect2] = [Rect2(270, 10, 540, 70), Rect2(270, 97, 540, 70), Rect2(270, 184, 540, 70), Rect2(270, 271, 540, 70)]
const UMBRALES := [25, 50, 75, 100]

var imagen: TextureRect
var barra: TextureRect
var etiqueta: Label
var porcentaje := 0.0
var indice_barra := 0
var indice_objetivo := 0
var mundo: Node2D
var cargando := true
var capa_carga: CanvasLayer


func _ready() -> void:
	# La interfaz permanece por encima del mundo mientras este se presenta.
	capa_carga = CanvasLayer.new()
	capa_carga.layer = 100
	add_child(capa_carga)
	imagen = TextureRect.new()
	imagen.texture = FONDO
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_carga.add_child(imagen)
	var contenido := VBoxContainer.new()
	contenido.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	contenido.anchor_top = 0.70
	contenido.anchor_bottom = 0.70
	contenido.offset_left = -270
	contenido.offset_right = 270
	contenido.offset_bottom = 120
	contenido.add_theme_constant_override("separation", 4)
	capa_carga.add_child(contenido)
	barra = TextureRect.new()
	barra.custom_minimum_size = Vector2(0, 70)
	barra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	barra.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	barra.texture = _textura_barra(0)
	contenido.add_child(barra)
	etiqueta = Label.new()
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.text = "Preparando recursos…"
	contenido.add_child(etiqueta)
	var error := ResourceLoader.load_threaded_request(GestorMundos.ESCENA_MUNDO, "PackedScene")
	if error != OK:
		_mostrar_error("No se pudo iniciar la carga (error %d)." % error)


func _process(_delta: float) -> void:
	if indice_barra < indice_objetivo:
		indice_barra += 1
		barra.texture = _textura_barra(indice_barra)
	if not cargando:
		return
	var progreso := []
	var estado := ResourceLoader.load_threaded_get_status(GestorMundos.ESCENA_MUNDO, progreso)
	if estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_actualizar(float(progreso[0]) * 10.0, "Cargando recursos")
	elif estado == ResourceLoader.THREAD_LOAD_LOADED:
		cargando = false
		var escena := ResourceLoader.load_threaded_get(GestorMundos.ESCENA_MUNDO) as PackedScene
		if escena == null:
			_mostrar_error("No se pudo abrir la escena del mundo.")
			return
		_actualizar(10.0, "Preparando mundo")
		mundo = escena.instantiate()
		mundo.visible = false
		mundo.avance_generacion.connect(_avance_generacion)
		mundo.generacion_terminada.connect(_terminar)
		mundo.generacion_fallida.connect(_mostrar_error)
		# El hijo se genera en el hilo principal, por lotes entre fotogramas.
		add_child(mundo)
	elif estado == ResourceLoader.THREAD_LOAD_FAILED or estado == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_mostrar_error("No se pudieron cargar los recursos del mundo.")


func _avance_generacion(fase: String, completado: int, total: int) -> void:
	var fraccion := float(completado) / maxi(total, 1)
	match fase:
		"terreno": _actualizar(10.0 + 30.0 * fraccion, "Generando terreno")
		"copias_terreno": _actualizar(40.0 + 5.0 * fraccion, "Preparando terreno")
		"recursos": _actualizar(45.0 + 35.0 * fraccion, "Colocando recursos")
		"copias_recursos": _actualizar(80.0 + 19.0 * fraccion, "Preparando recursos")
		"jugador": _actualizar(100.0, "Mundo preparado")


func _actualizar(valor: float, fase: String) -> void:
	porcentaje = maxf(porcentaje, clampf(valor, 0.0, 100.0))
	for i in range(UMBRALES.size()):
		if porcentaje >= UMBRALES[i]:
			indice_objetivo = maxi(indice_objetivo, i)
	etiqueta.text = "%s · %d%%" % [fase, floori(porcentaje)]


func _textura_barra(indice: int) -> AtlasTexture:
	var textura := AtlasTexture.new()
	textura.atlas = BARRAS
	textura.region = REGIONES[indice]
	return textura


func _terminar() -> void:
	_actualizar(100.0, "Mundo preparado")
	# El último fotograma espera a que la generación haya concluido realmente.
	while indice_barra < indice_objetivo:
		await get_tree().process_frame
	await get_tree().process_frame
	# El mundo no sale del árbol: su cámara y tiles ya preparados se mantienen.
	# La capa de carga tapa la primera presentación del mundo para evitar destellos.
	mundo.reparent(get_tree().root)
	mundo.visible = true
	var camara := mundo.get_node_or_null("Player/WorldCamera") as Camera2D
	if camara == null:
		camara = mundo.get_node_or_null("Recursos/Player/WorldCamera") as Camera2D
	if camara == null and mundo.has_method("_obtener_jugador"):
		var j = mundo._obtener_jugador()
		if j != null:
			camara = j.get_node_or_null("WorldCamera") as Camera2D
	if camara == null:
		camara = mundo.find_child("WorldCamera", true, false) as Camera2D
	if camara != null:
		camara.make_current()
		camara.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = mundo
	GestorFondos._actualizar_visibilidad()
	mundo.activar_juego()
	queue_free()


func _mostrar_error(texto: String) -> void:
	cargando = false
	etiqueta.text = texto
	var volver := Button.new()
	volver.text = "Volver a selección"
	volver.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	volver.pressed.connect(func(): get_tree().change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn"))
	if has_node("/root/GestorAudio"):
		get_node("/root/GestorAudio").conectar_botones(volver)
	capa_carga.add_child(volver)

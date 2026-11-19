extends CanvasLayer

@export var intervalo := 10.0
@export var duracion_transicion := 1.5

const FONDOS: Array[Texture2D] = [
	preload("res://recursos_interfaz/fondos/fondo_interfaz_inicio.jpeg"),
	preload("res://recursos_interfaz/fondos/fondo_interfaz_inicio2.jpeg"),
	preload("res://recursos_interfaz/fondos/fondo_interfaz_inicio3.jpeg"),
	preload("res://recursos_interfaz/fondos/fondo_interfaz_inicio4.jpeg"),
	preload("res://recursos_interfaz/fondos/fondo_interfaz_inicio5.jpeg"),
	preload("res://recursos_interfaz/fondos/fondo_interfaz_inicio6.jpeg"),
]

var anterior: TextureRect
var siguiente: TextureRect
var reloj: Timer
var transicion: Tween
var indice := -1
var indice_anterior := -1


func _ready() -> void:
	layer = -10
	anterior = _crear_capa()
	siguiente = _crear_capa()
	siguiente.modulate.a = 0.0
	reloj = Timer.new()
	reloj.one_shot = true
	reloj.timeout.connect(_cambiar_fondo)
	add_child(reloj)
	indice = randi_range(0, FONDOS.size() - 1)
	anterior.texture = FONDOS[indice]
	get_tree().scene_changed.connect(_actualizar_visibilidad)
	_actualizar_visibilidad()


func _crear_capa() -> TextureRect:
	var capa := TextureRect.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(capa)
	return capa


func _actualizar_visibilidad() -> void:
	var escena := get_tree().current_scene
	var en_interfaz := escena != null and escena.scene_file_path.begins_with("res://escenas/interfaz/") and not escena.scene_file_path.ends_with("/carga_mundo.tscn")
	visible = en_interfaz
	if en_interfaz:
		if reloj.is_stopped() and (transicion == null or not transicion.is_running()):
			reloj.start(maxf(intervalo, 0.01))
	else:
		reloj.stop()
		if transicion != null and transicion.is_running():
			transicion.kill()
			siguiente.modulate.a = 0.0
			indice = indice_anterior


func _cambiar_fondo() -> void:
	indice_anterior = indice
	var nuevo := randi_range(0, FONDOS.size() - 2)
	if nuevo >= indice:
		nuevo += 1
	indice = nuevo
	siguiente.texture = FONDOS[indice]
	siguiente.modulate.a = 0.0
	transicion = create_tween()
	transicion.tween_property(siguiente, "modulate:a", 1.0, maxf(duracion_transicion, 0.01))
	transicion.tween_callback(_terminar_transicion)


func _terminar_transicion() -> void:
	anterior.texture = siguiente.texture
	siguiente.modulate.a = 0.0
	if visible:
		reloj.start(maxf(intervalo, 0.01))

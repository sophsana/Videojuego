extends Control

const Estilo = preload("res://script/interfaz/estilo_interfaz.gd")
const DatosMundo = preload("res://script/sistemas/datos_mundo.gd")
var nombre: LineEdit
var semilla: LineEdit
var dificultad := "Normal"
var mensaje: Label


func _ready() -> void:
	var contenido: VBoxContainer = $Centro/Contenido
	_agregar_etiqueta(contenido, "Nombre del mundo")
	var entrada_nombre := Estilo.entrada(false, "Nombre del mundo")
	contenido.add_child(entrada_nombre)
	nombre = entrada_nombre.get_node("Campo")
	nombre.max_length = DatosMundo.LONGITUD_NOMBRE
	_agregar_etiqueta(contenido, "Semilla del mundo")
	var entrada_semilla := Estilo.entrada(false, "Semilla numérica")
	contenido.add_child(entrada_semilla)
	semilla = entrada_semilla.get_node("Campo")
	semilla.max_length = 11
	_agregar_etiqueta(contenido, "Dificultad")
	var fila := HBoxContainer.new()
	fila.name = "Dificultades"
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.add_child(fila)
	var grupo := ButtonGroup.new()
	for i in range(DatosMundo.DIFICULTADES.size()):
		var boton := Estilo.boton_dificultad(i)
		boton.button_group = grupo
		boton.button_pressed = i == 1
		boton.tooltip_text = DatosMundo.DIFICULTADES[i]
		boton.pressed.connect(_seleccionar_dificultad.bind(DatosMundo.DIFICULTADES[i]))
		fila.add_child(boton)
	mensaje = Label.new()
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensaje.custom_minimum_size.y = 28
	contenido.add_child(mensaje)
	var acciones := HBoxContainer.new()
	acciones.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.add_child(acciones)
	var volver := Estilo.boton_volver()
	volver.pressed.connect(func(): get_tree().change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn"))
	acciones.add_child(volver)
	var crear := Estilo.boton_crear()
	crear.pressed.connect(_crear)
	acciones.add_child(crear)
	if has_node("/root/GestorAudio"):
		get_node("/root/GestorAudio").conectar_botones(self)


func _agregar_etiqueta(contenido: VBoxContainer, texto: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(etiqueta)


func _seleccionar_dificultad(valor: String) -> void:
	dificultad = valor


func _crear() -> void:
	var texto_semilla := semilla.text.strip_edges()
	if texto_semilla.is_empty():
		texto_semilla = str(randi_range(DatosMundo.SEMILLA_MINIMA, DatosMundo.SEMILLA_MAXIMA))
		semilla.text = texto_semilla
	if not DatosMundo.semilla_valida(texto_semilla):
		mensaje.text = "Semilla inválida. Rango: %d a %d." % [DatosMundo.SEMILLA_MINIMA, DatosMundo.SEMILLA_MAXIMA]
		return
	var datos: Dictionary = GestorMundos.crear_mundo(nombre.text, texto_semilla.to_int(), dificultad)
	if datos.is_empty():
		mensaje.text = GestorMundos.ultimo_error
		return
	if GestorMundos.iniciar_mundo(datos) != OK:
		mensaje.text = GestorMundos.ultimo_error + " El mundo se guardó."

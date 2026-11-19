extends Control

const Estilo = preload("res://script/interfaz/estilo_interfaz.gd")
var mundos: Array[Dictionary] = []
var lista: VBoxContainer
var mensaje: Label
var busqueda: LineEdit


func _ready() -> void:
	var contenido: VBoxContainer = $Centro/Contenido
	var crear := Estilo.boton_crear()
	crear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crear.pressed.connect(func(): get_tree().change_scene_to_file("res://escenas/interfaz/crear_mundo.tscn"))
	contenido.add_child(crear)
	var entrada := Estilo.entrada(true, "Buscar mundos")
	entrada.name = "Busqueda"
	contenido.add_child(entrada)
	busqueda = entrada.get_node("Campo")
	busqueda.text_changed.connect(func(_texto: String): _actualizar_lista())
	var panel := Control.new()
	panel.name = "PanelMundos"
	# 1080:720, la misma relación del arte sin escalar sus ejes por separado.
	panel.custom_minimum_size = Vector2(480, 320)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.resized.connect(func(): panel.custom_minimum_size.y = panel.size.x * 2.0 / 3.0)
	contenido.add_child(panel)
	var fondo := TextureRect.new()
	fondo.name = "Marco"
	# El arte incluye margen transparente; se recorta sin alterar el original.
	fondo.texture = Estilo.atlas(Estilo.CONTENEDOR, Rect2(38, 36, 1004, 640))
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fondo)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 35
	scroll.offset_bottom = -35
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	scroll.add_child(lista)
	mensaje = Label.new()
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lista.add_child(mensaje)
	var volver := Estilo.boton_volver()
	volver.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	volver.pressed.connect(func(): get_tree().change_scene_to_file("res://escenas/interfaz/menu_principal.tscn"))
	contenido.add_child(volver)
	mundos = GestorMundos.listar_mundos()
	_actualizar_lista()


func _actualizar_lista() -> void:
	for hijo in lista.get_children():
		if hijo != mensaje:
			lista.remove_child(hijo)
			hijo.queue_free()
	var encontrados := 0
	var filtro := busqueda.text.strip_edges().to_lower()
	for mundo in mundos:
		if not filtro.is_empty() and not mundo.nombre.to_lower().contains(filtro):
			continue
		encontrados += 1
		var boton := Estilo.boton_mundo()
		boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		boton.tooltip_text = "%s · %s · Semilla: %d · %s" % [mundo.nombre, mundo.dificultad, mundo.semilla, mundo.get("fecha_creacion", "").replace("T", " ")]
		boton.pressed.connect(_jugar.bind(mundo))
		lista.add_child(boton)
		var texto := Label.new()
		texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texto.anchor_left = 0.32
		texto.anchor_right = 0.82
		texto.offset_left = 0
		texto.offset_right = 0
		texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.clip_text = true
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texto.add_theme_font_size_override("font_size", 14)
		texto.text = "%s\n%s" % [mundo.nombre, mundo.dificultad]
		boton.add_child(texto)
	if not GestorMundos.ultimo_error.is_empty():
		mensaje.text = GestorMundos.ultimo_error
	elif mundos.is_empty():
		mensaje.text = "Todavía no hay partidas guardadas."
	elif encontrados == 0:
		mensaje.text = "No hay mundos que coincidan con la búsqueda."
	else:
		mensaje.text = ""
	mensaje.visible = not mensaje.text.is_empty()


func _jugar(mundo: Dictionary) -> void:
	if GestorMundos.iniciar_mundo(mundo) != OK:
		mensaje.text = GestorMundos.ultimo_error
		mensaje.visible = true

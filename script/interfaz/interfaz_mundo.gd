extends CanvasLayer

const SLOTS := 10
const TEX_CORAZONES := preload("res://assets/Jugador/corazones_estados.png")
const TEX_SLOTS := preload("res://assets/Jugador/slot_inventario.png")
const RUTA_MUSLITOS := "res://assets/Jugador/muslitos_estados.png"
const TEX_FONDO_PAUSA := preload("res://recursos_interfaz/fondos/fondo_interfaz_inicio.jpeg")
const TEX_BOTON_VOLVER := preload("res://recursos_interfaz/botones/boton_volver.png")
const TEX_BOTON_GUARDAR_SALIR := preload("res://recursos_interfaz/botones/guardar_salir.png")
const TEX_BOTONES_GROUP := preload("res://recursos_interfaz/botones/botones_group.png")

# Coordenadas de recorte corregidas (determinadas por inspección de contenido visible):
# corazones_estados.png (1080x359): 3 estados en segmentos horizontales separados.
const REGION_CORAZON_VACIO := Rect2i(90, 77, 257, 200)
const REGION_CORAZON_LLENO := Rect2i(417, 79, 246, 197)
const REGION_CORAZON_MEDIO := Rect2i(735, 78, 253, 198)
# muslitos_estados.png (1080x360): 3 estados en segmentos horizontales separados.
const REGION_MUSLITO_VACIO := Rect2i(23, 32, 322, 310)
const REGION_MUSLITO_MEDIO := Rect2i(384, 32, 321, 311)
const REGION_MUSLITO_LLENO := Rect2i(744, 32, 321, 311)
# slot_inventario.png (1080x540): 2 diseños individuales (no barra de 10).
# Izquierda = normal, derecha = seleccionado (reutilizados para los 10 slots).
const REGION_SLOT_NORMAL := Rect2i(60, 56, 422, 397)
const REGION_SLOT_SELECCIONADO := Rect2i(599, 50, 426, 405)

const TAMANO_CORAZON := Vector2(24, 24)
const TAMANO_SLOT := Vector2(48, 48)

var mensaje: Label
var etiqueta_inventario: Label
var contenedor_corazones: HBoxContainer
var contenedor_hambre: HBoxContainer
var contenedor_slots: HBoxContainer
var iconos_corazon: Array[TextureRect] = []
var iconos_hambre: Array[TextureRect] = []
var fondos_slot: Array[TextureRect] = []
var iconos_objeto: Array[TextureRect] = []
var cantidades_slot: Array[Label] = []
var nombres_slot: Array[Label] = []

var tex_corazon_vacio: AtlasTexture
var tex_corazon_medio: AtlasTexture
var tex_corazon_lleno: AtlasTexture
var tex_muslito_vacio: Texture2D
var tex_muslito_medio: Texture2D
var tex_muslito_lleno: Texture2D
var tex_slot_normal: AtlasTexture
var tex_slot_seleccionado: AtlasTexture

var mundo: Node
var inventario
var jugador

# Pausa
var en_pausa := false
var capa_pausa: Control
var panel_pausa_principal: VBoxContainer
var panel_pausa_opciones: VBoxContainer
var slider_musica_pausa: HSlider
var slider_sonidos_pausa: HSlider


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	mundo = get_parent()
	inventario = mundo.get("inventario") if mundo != null else null
	jugador = _buscar_jugador()
	_preparar_texturas()
	_construir_ui()
	_conectar()
	_actualizar_todo()


func _buscar_jugador():
	if mundo == null:
		return null
	var j = mundo.get_node_or_null("Recursos/Player")
	if j == null:
		j = mundo.find_child("Player", true, false)
	return j


func _preparar_texturas() -> void:
	tex_corazon_vacio = AtlasTexture.new()
	tex_corazon_vacio.atlas = TEX_CORAZONES
	tex_corazon_vacio.region = Rect2(REGION_CORAZON_VACIO)

	tex_corazon_lleno = AtlasTexture.new()
	tex_corazon_lleno.atlas = TEX_CORAZONES
	tex_corazon_lleno.region = Rect2(REGION_CORAZON_LLENO)

	tex_corazon_medio = AtlasTexture.new()
	tex_corazon_medio.atlas = TEX_CORAZONES
	tex_corazon_medio.region = Rect2(REGION_CORAZON_MEDIO)

	tex_slot_normal = AtlasTexture.new()
	tex_slot_normal.atlas = TEX_SLOTS
	tex_slot_normal.region = Rect2(REGION_SLOT_NORMAL)

	tex_slot_seleccionado = AtlasTexture.new()
	tex_slot_seleccionado.atlas = TEX_SLOTS
	tex_slot_seleccionado.region = Rect2(REGION_SLOT_SELECCIONADO)

	# Muslitos (hambre): carga directa por si no existe .import.
	var img_muslitos := Image.new()
	if img_muslitos.load(ProjectSettings.globalize_path(RUTA_MUSLITOS)) == OK:
		var tex_muslitos_base := ImageTexture.create_from_image(img_muslitos)
		var tmv := AtlasTexture.new()
		tmv.atlas = tex_muslitos_base
		tmv.region = Rect2(REGION_MUSLITO_VACIO)
		tex_muslito_vacio = tmv
		var tmm := AtlasTexture.new()
		tmm.atlas = tex_muslitos_base
		tmm.region = Rect2(REGION_MUSLITO_MEDIO)
		tex_muslito_medio = tmm
		var tml := AtlasTexture.new()
		tml.atlas = tex_muslitos_base
		tml.region = Rect2(REGION_MUSLITO_LLENO)
		tex_muslito_lleno = tml


func _configurar_texturerect(tr: TextureRect, tam: Vector2) -> void:
	tr.custom_minimum_size = tam
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _crear_texture_button(atlas: Texture2D, normal_r: Rect2, hover_r: Rect2, pressed_r: Rect2, tam: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	var n := AtlasTexture.new(); n.atlas = atlas; n.region = normal_r
	var h := AtlasTexture.new(); h.atlas = atlas; h.region = hover_r
	var p := AtlasTexture.new(); p.atlas = atlas; p.region = pressed_r
	btn.texture_normal = n
	btn.texture_hover = h
	btn.texture_pressed = p
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = tam
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return btn


func _construir_ui() -> void:
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Bloque inferior centrado: [corazones | espacio hambre] sobre [10 slots].
	var bottom := MarginContainer.new()
	bottom.name = "BottomHUD"
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 0
	bottom.offset_right = 0
	bottom.offset_top = -170
	bottom.offset_bottom = -8
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(vbox)

	# Barra de 10 slots (define el ancho de referencia para la fila superior).
	contenedor_slots = HBoxContainer.new()
	contenedor_slots.name = "Slots"
	contenedor_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	contenedor_slots.add_theme_constant_override("separation", 4)
	contenedor_slots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	contenedor_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Construimos primero la fila superior para poder igualar su ancho al de slots.
	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 24)
	top_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left_half := HBoxContainer.new()
	left_half.name = "MitadIzquierda"
	left_half.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(left_half)

	contenedor_corazones = HBoxContainer.new()
	contenedor_corazones.name = "Corazones"
	contenedor_corazones.add_theme_constant_override("separation", 2)
	contenedor_corazones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_half.add_child(contenedor_corazones)
	for i in range(10):
		var tr := TextureRect.new()
		tr.name = "Corazon_%d" % i
		_configurar_texturerect(tr, TAMANO_CORAZON)
		contenedor_corazones.add_child(tr)
		iconos_corazon.append(tr)

	var right_half := HBoxContainer.new()
	right_half.name = "MitadDerecha"
	right_half.alignment = BoxContainer.ALIGNMENT_END
	right_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(right_half)

	contenedor_hambre = HBoxContainer.new()
	contenedor_hambre.name = "Hambre"
	contenedor_hambre.add_theme_constant_override("separation", 2)
	contenedor_hambre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_half.add_child(contenedor_hambre)
	# 10 iconos de hambre (muslitos), 20 puntos.
	for i in range(10):
		var tr := TextureRect.new()
		tr.name = "Hambre_%d" % i
		_configurar_texturerect(tr, TAMANO_CORAZON)
		contenedor_hambre.add_child(tr)
		iconos_hambre.append(tr)

	vbox.add_child(top_row)

	# 10 slots centrados horizontalmente.
	for i in range(SLOTS):
		var slotc := Control.new()
		slotc.name = "Slot_%d" % i
		slotc.custom_minimum_size = Vector2(52, 52)
		slotc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slotc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slotc.mouse_filter = Control.MOUSE_FILTER_STOP
		contenedor_slots.add_child(slotc)

		var fondo := TextureRect.new()
		fondo.name = "Fondo"
		fondo.anchor_left = 0.5
		fondo.anchor_right = 0.5
		fondo.anchor_top = 0.5
		fondo.anchor_bottom = 0.5
		fondo.offset_left = -24
		fondo.offset_right = 24
		fondo.offset_top = -24
		fondo.offset_bottom = 24
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slotc.add_child(fondo)
		fondos_slot.append(fondo)

		var icono := TextureRect.new()
		icono.name = "Icono"
		icono.anchor_left = 0.5
		icono.anchor_right = 0.5
		icono.anchor_top = 0.5
		icono.anchor_bottom = 0.5
		icono.offset_left = -20
		icono.offset_right = 20
		icono.offset_top = -20
		icono.offset_bottom = 20
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slotc.add_child(icono)
		iconos_objeto.append(icono)

		var cant := Label.new()
		cant.name = "Cantidad"
		cant.anchor_left = 1.0
		cant.anchor_top = 0.0
		cant.anchor_right = 1.0
		cant.anchor_bottom = 0.0
		cant.offset_left = -30
		cant.offset_top = 2
		cant.offset_right = -4
		cant.offset_bottom = 18
		cant.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		cant.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cant.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		cant.add_theme_font_size_override("font_size", 12)
		cant.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		cant.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		cant.add_theme_constant_override("outline_size", 1)
		cant.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slotc.add_child(cant)
		cantidades_slot.append(cant)

		var nombre := Label.new()
		nombre.name = "Nombre"
		nombre.visible = false
		nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slotc.add_child(nombre)
		nombres_slot.append(nombre)

	vbox.add_child(contenedor_slots)

	# Igualar el ancho de la fila superior al ancho de la barra de slots para que
	# los corazones queden sobre la mitad izquierda y el hambre sobre la derecha.
	top_row.custom_minimum_size = Vector2(contenedor_slots.get_combined_minimum_size().x, 0)

	# Mensajes HUD (no forma parte del HUD de supervivencia).
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margen.offset_left = -300
	margen.offset_bottom = 120
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 12)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margen)
	var contenido := VBoxContainer.new()
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(contenido)
	mensaje = Label.new()
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensaje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(mensaje)
	etiqueta_inventario = Label.new()
	etiqueta_inventario.name = "Inventario"
	etiqueta_inventario.visible = false
	etiqueta_inventario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(etiqueta_inventario)

	_construir_menu_pausa(root)


func _construir_menu_pausa(root: Control) -> void:
	capa_pausa = Control.new()
	capa_pausa.name = "CapaPausa"
	capa_pausa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa_pausa.visible = false
	capa_pausa.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(capa_pausa)

	var fondo := TextureRect.new()
	fondo.texture = TEX_FONDO_PAUSA
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_pausa.add_child(fondo)

	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.25)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_pausa.add_child(velo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_pausa.add_child(centro)

	var contenido := VBoxContainer.new()
	contenido.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.add_theme_constant_override("separation", 14)
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(contenido)

	var titulo := Label.new()
	titulo.text = "PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 38)
	titulo.add_theme_color_override("font_color", Color(1, 1, 1))
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	titulo.add_theme_constant_override("outline_size", 4)
	contenido.add_child(titulo)

	panel_pausa_principal = VBoxContainer.new()
	panel_pausa_principal.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_pausa_principal.add_theme_constant_override("separation", 12)
	contenido.add_child(panel_pausa_principal)

	var tam_boton_pausa := Vector2(280, 95)
	var btn_volver := _crear_texture_button(
		TEX_BOTON_VOLVER,
		Rect2(0, 115, 360, 115), Rect2(360, 115, 360, 115), Rect2(720, 115, 360, 115),
		tam_boton_pausa
	)
	btn_volver.pressed.connect(_reanudar)
	panel_pausa_principal.add_child(btn_volver)

	# guardar_salir.png: 2172x724, 3 estados (normal/hover/pressed). Recorte amplio para mostrar el botón completo.
	var btn_guardar := _crear_texture_button(
		TEX_BOTON_GUARDAR_SALIR,
		Rect2(0, 210, 724, 280), Rect2(724, 210, 724, 280), Rect2(1448, 210, 724, 280),
		tam_boton_pausa
	)
	btn_guardar.pressed.connect(_guardar_y_salir_desde_pausa)
	panel_pausa_principal.add_child(btn_guardar)

	var btn_opciones := _crear_texture_button(
		TEX_BOTONES_GROUP,
		Rect2(360, 109, 360, 137), Rect2(360, 299, 360, 137), Rect2(360, 489, 360, 137),
		tam_boton_pausa
	)
	btn_opciones.pressed.connect(_mostrar_opciones_pausa)
	panel_pausa_principal.add_child(btn_opciones)

	panel_pausa_opciones = VBoxContainer.new()
	panel_pausa_opciones.visible = false
	panel_pausa_opciones.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_pausa_opciones.add_theme_constant_override("separation", 10)
	panel_pausa_opciones.custom_minimum_size = Vector2(320, 0)
	contenido.add_child(panel_pausa_opciones)

	var titulo_op := Label.new()
	titulo_op.text = "OPCIONES"
	titulo_op.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_op.add_theme_font_size_override("font_size", 28)
	panel_pausa_opciones.add_child(titulo_op)

	var lbl_m := Label.new()
	lbl_m.text = "Música"
	panel_pausa_opciones.add_child(lbl_m)
	slider_musica_pausa = HSlider.new()
	slider_musica_pausa.min_value = 0.0
	slider_musica_pausa.max_value = 1.0
	slider_musica_pausa.step = 0.01
	slider_musica_pausa.custom_minimum_size = Vector2(0, 32)
	slider_musica_pausa.value_changed.connect(_cambiar_musica_pausa)
	panel_pausa_opciones.add_child(slider_musica_pausa)

	var lbl_s := Label.new()
	lbl_s.text = "Sonidos"
	panel_pausa_opciones.add_child(lbl_s)
	slider_sonidos_pausa = HSlider.new()
	slider_sonidos_pausa.min_value = 0.0
	slider_sonidos_pausa.max_value = 1.0
	slider_sonidos_pausa.step = 0.01
	slider_sonidos_pausa.custom_minimum_size = Vector2(0, 32)
	slider_sonidos_pausa.value_changed.connect(_cambiar_sonidos_pausa)
	panel_pausa_opciones.add_child(slider_sonidos_pausa)

	var btn_volver_op := _crear_texture_button(
		TEX_BOTON_VOLVER,
		Rect2(0, 115, 360, 115), Rect2(360, 115, 360, 115), Rect2(720, 115, 360, 115),
		Vector2(240, 80)
	)
	btn_volver_op.pressed.connect(_ocultar_opciones_pausa)
	panel_pausa_opciones.add_child(btn_volver_op)

	# Sonidos en botones del menú de pausa (no en sliders de sonido/música).
	if has_node("/root/GestorAudio"):
		var ga = get_node("/root/GestorAudio")
		ga.conectar_botones(btn_volver)
		ga.conectar_botones(btn_guardar)
		ga.conectar_botones(btn_opciones)
		ga.conectar_botones(btn_volver_op)


func _conectar() -> void:
	if inventario != null:
		if inventario.has_signal("cambiado") and not inventario.cambiado.is_connected(_actualizar_inventario):
			inventario.cambiado.connect(_actualizar_inventario)
		if inventario.has_signal("slot_seleccionado_cambiado") and not inventario.slot_seleccionado_cambiado.is_connected(_on_slot_seleccionado):
			inventario.slot_seleccionado_cambiado.connect(_on_slot_seleccionado)
	jugador = _buscar_jugador()
	if jugador != null:
		if jugador.has_signal("vida_cambiada") and not jugador.vida_cambiada.is_connected(_actualizar_vida):
			jugador.vida_cambiada.connect(_actualizar_vida)
		if jugador.has_signal("hambre_cambiada") and not jugador.hambre_cambiada.is_connected(_actualizar_hambre):
			jugador.hambre_cambiada.connect(_actualizar_hambre)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_alternar_pausa()
		get_viewport().set_input_as_handled()
		return
	if en_pausa:
		return
	if inventario == null or not inventario.has_method("seleccionar"):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventario.seleccionar(inventario.seleccionado - 1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventario.seleccionar(inventario.seleccionado + 1)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		match event.keycode:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
			KEY_4: idx = 3
			KEY_5: idx = 4
			KEY_6: idx = 5
			KEY_7: idx = 6
			KEY_8: idx = 7
			KEY_9: idx = 8
			KEY_0: idx = 9
		if idx >= 0:
			inventario.seleccionar(idx)
			get_viewport().set_input_as_handled()


func _alternar_pausa() -> void:
	if en_pausa:
		_reanudar()
	else:
		_pausar()


func _pausar() -> void:
	en_pausa = true
	_actualizar_sliders_pausa()
	panel_pausa_principal.visible = true
	panel_pausa_opciones.visible = false
	capa_pausa.visible = true
	get_tree().paused = true


func _reanudar() -> void:
	en_pausa = false
	capa_pausa.visible = false
	panel_pausa_opciones.visible = false
	panel_pausa_principal.visible = true
	get_tree().paused = false


func _mostrar_opciones_pausa() -> void:
	_actualizar_sliders_pausa()
	panel_pausa_principal.visible = false
	panel_pausa_opciones.visible = true


func _ocultar_opciones_pausa() -> void:
	panel_pausa_opciones.visible = false
	panel_pausa_principal.visible = true


func _actualizar_sliders_pausa() -> void:
	if slider_musica_pausa == null or slider_sonidos_pausa == null:
		return
	if has_node("/root/GestorAudio"):
		var ga = get_node("/root/GestorAudio")
		slider_musica_pausa.set_value_no_signal(float(ga.volumen_musica))
		slider_sonidos_pausa.set_value_no_signal(float(ga.volumen_sonidos))
	else:
		slider_musica_pausa.set_value_no_signal(1.0)
		slider_sonidos_pausa.set_value_no_signal(1.0)


func _cambiar_musica_pausa(valor: float) -> void:
	if has_node("/root/GestorAudio"):
		get_node("/root/GestorAudio").establecer_volumen_musica(valor)


func _cambiar_sonidos_pausa(valor: float) -> void:
	if has_node("/root/GestorAudio"):
		get_node("/root/GestorAudio").establecer_volumen_sonidos(valor)


func _guardar_y_salir_desde_pausa() -> void:
	_guardar_y_salir()


func _actualizar_todo() -> void:
	_actualizar_inventario()
	jugador = _buscar_jugador()
	if jugador != null and jugador.has_method("consultar_vida_actual"):
		_actualizar_vida(jugador.consultar_vida_actual(), jugador.consultar_vida_maxima())
		_actualizar_hambre(jugador.hambre, jugador.hambre_maxima)
	else:
		_actualizar_vida(20, 20)
		_actualizar_hambre(20, 20)


func actualizar_inventario() -> void:
	_actualizar_inventario()


func _actualizar_inventario() -> void:
	if inventario == null:
		return
	for i in range(SLOTS):
		var slot = inventario.slot(i) if inventario.has_method("slot") else null
		var sel: bool = inventario.has_method("seleccionar") and i == int(inventario.seleccionado)
		fondos_slot[i].texture = tex_slot_seleccionado if sel else tex_slot_normal
		var slotc := fondos_slot[i].get_parent() as Control
		if slot == null:
			iconos_objeto[i].texture = null
			iconos_objeto[i].modulate = Color(1, 1, 1, 0)
			cantidades_slot[i].text = ""
			nombres_slot[i].text = ""
			if slotc != null:
				slotc.tooltip_text = ""
		else:
			var icono := _icono_para_item(String(slot.get("id", "")), String(slot.get("icono", "")))
			iconos_objeto[i].texture = icono
			iconos_objeto[i].modulate = Color(1, 1, 1, 1) if icono != null else Color(0.85, 0.75, 0.35, 0.85)
			var cantidad := int(slot.get("cantidad", 0))
			cantidades_slot[i].text = str(cantidad) if cantidad > 1 else ""
			var nombre_item := String(slot.get("nombre", ""))
			nombres_slot[i].text = nombre_item
			if slotc != null:
				slotc.tooltip_text = nombre_item


func _icono_para_item(id: String, ruta: String) -> Texture2D:
	var candidatos: Array[String] = []
	if not ruta.is_empty():
		candidatos.append(ruta)
	candidatos.append("res://assets/objetos/%s.png" % id)
	for candidato in candidatos:
		if ResourceLoader.exists(candidato):
			var tex = load(candidato)
			if tex is Texture2D:
				return tex
		# Fallback: carga directa (útil si falta .import).
		var ruta_abs := ProjectSettings.globalize_path(candidato)
		if FileAccess.file_exists(ruta_abs):
			var img := Image.new()
			if img.load(ruta_abs) == OK:
				return ImageTexture.create_from_image(img)
	return null


func _on_slot_seleccionado(_indice: int) -> void:
	_actualizar_inventario()


func _actualizar_vida(vida: int, vida_maxima: int) -> void:
	for i in range(iconos_corazon.size()):
		var valor := clampi(vida - i * 2, 0, 2)
		if valor >= 2:
			iconos_corazon[i].texture = tex_corazon_lleno
		elif valor == 1:
			iconos_corazon[i].texture = tex_corazon_medio
		else:
			iconos_corazon[i].texture = tex_corazon_vacio


func _actualizar_hambre(hambre: int, _hambre_maxima: int) -> void:
	for i in range(iconos_hambre.size()):
		var valor := clampi(hambre - i * 2, 0, 2)
		var tex: Texture2D = tex_muslito_vacio
		if valor >= 2:
			tex = tex_muslito_lleno
		elif valor == 1:
			tex = tex_muslito_medio
		if tex != null:
			iconos_hambre[i].texture = tex
			iconos_hambre[i].modulate = Color(1, 1, 1, 1)
		else:
			iconos_hambre[i].modulate = Color(1, 1, 1, 0)


func mostrar_mensaje(texto: String) -> void:
	if mensaje == null:
		return
	mensaje.text = texto
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func():
		if is_instance_valid(self) and mensaje != null and mensaje.text == texto:
			mensaje.text = ""
	)


func _guardar_y_salir() -> void:
	if mundo == null:
		return
	var p: CharacterBody2D = _buscar_jugador() as CharacterBody2D
	if p == null:
		return
	p.set_physics_process(false)
	p.velocity = Vector2.ZERO
	var vida_val = p.vida if "vida" in p else 20
	var hambre_val = p.hambre if "hambre" in p else 20
	var rocas_val = mundo.get("rocas_golpeadas") if mundo != null else {}
	var rocas_golpes_val = mundo.get("rocas_golpes") if mundo != null else {}
	var arboles_golpes_val = mundo.get("arboles_golpes") if mundo != null else {}
	var arboles_talados_val = mundo.get("arboles_talados") if mundo != null else {}
	var ok := GestorMundos.guardar_progreso(p.position, inventario, mundo.arbustos_recolectados, vida_val, hambre_val, rocas_val, rocas_golpes_val, arboles_golpes_val, arboles_talados_val)
	if ok:
		get_tree().paused = false
		var error := get_tree().change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn")
		if error == OK:
			return
		mostrar_mensaje("Guardado correcto, pero no se pudo volver al menú. Reintenta.")
	else:
		mostrar_mensaje(GestorMundos.ultimo_error + " Reintenta.")

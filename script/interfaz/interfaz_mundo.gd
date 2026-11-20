extends CanvasLayer

const SLOTS := 10
const TEX_CORAZONES := preload("res://assets/Jugador/corazones_estados.png")
const TEX_SLOTS := preload("res://assets/Jugador/slot_inventario.png")

var boton: Button
var boton_guardar: Button
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

var tex_corazon_vacio: AtlasTexture
var tex_corazon_medio: AtlasTexture
var tex_corazon_lleno: AtlasTexture
var regiones_slot_normal: Array[Texture2D] = []
var regiones_slot_sel: Array[Texture2D] = []

var mundo: Node
var inventario
var jugador


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	mundo = get_parent()
	inventario = mundo.get("inventario")
	jugador = mundo.get_node_or_null("Recursos/Player")
	if jugador == null:
		jugador = mundo.find_child("Player", true, false)
	_preparar_texturas()
	_construir_ui()
	_conectar()
	_actualizar_todo()


func _preparar_texturas() -> void:
	var w := TEX_CORAZONES.get_width()
	var h := TEX_CORAZONES.get_height()
	var cw := int(w / 3)
	# Estados en orden horizontal: vacío, medio, lleno (ajustable si el recurso difiere).
	tex_corazon_vacio = AtlasTexture.new()
	tex_corazon_vacio.atlas = TEX_CORAZONES
	tex_corazon_vacio.region = Rect2(0, 0, cw, h)
	tex_corazon_medio = AtlasTexture.new()
	tex_corazon_medio.atlas = TEX_CORAZONES
	tex_corazon_medio.region = Rect2(cw, 0, cw, h)
	tex_corazon_lleno = AtlasTexture.new()
	tex_corazon_lleno.atlas = TEX_CORAZONES
	tex_corazon_lleno.region = Rect2(cw * 2, 0, cw, h)

	var sw := TEX_SLOTS.get_width()
	var sh := TEX_SLOTS.get_height()
	var rh := int(sh / 2)
	var cell_w := int(sw / SLOTS)
	for i in range(SLOTS):
		var n := AtlasTexture.new()
		n.atlas = TEX_SLOTS
		n.region = Rect2(i * cell_w, 0, cell_w, rh)
		regiones_slot_normal.append(n)
		var s := AtlasTexture.new()
		s.atlas = TEX_SLOTS
		s.region = Rect2(i * cell_w, rh, cell_w, rh)
		regiones_slot_sel.append(s)


func _construir_ui() -> void:
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# HUD inferior centrado: corazones/hambre encima de la barra de slots.
	var bottom := MarginContainer.new()
	bottom.name = "BottomHUD"
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_top = -180
	bottom.add_theme_constant_override("margin_bottom", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 80)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_row)

	contenedor_corazones = HBoxContainer.new()
	contenedor_corazones.name = "Corazones"
	contenedor_corazones.add_theme_constant_override("separation", 1)
	contenedor_corazones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(contenedor_corazones)
	for i in range(10):
		var tr := TextureRect.new()
		tr.name = "Corazon_%d" % i
		tr.custom_minimum_size = Vector2(18, 18)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor_corazones.add_child(tr)
		iconos_corazon.append(tr)

	contenedor_hambre = HBoxContainer.new()
	contenedor_hambre.name = "Hambre"
	contenedor_hambre.add_theme_constant_override("separation", 1)
	contenedor_hambre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(contenedor_hambre)
	# Espacio reservado para 10 iconos de hambre (sprites futuros).
	for i in range(10):
		var tr := TextureRect.new()
		tr.name = "Hambre_%d" % i
		tr.custom_minimum_size = Vector2(18, 18)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.modulate = Color(1, 1, 1, 0)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor_hambre.add_child(tr)
		iconos_hambre.append(tr)

	contenedor_slots = HBoxContainer.new()
	contenedor_slots.name = "Slots"
	contenedor_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	contenedor_slots.add_theme_constant_override("separation", 2)
	contenedor_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(contenedor_slots)
	for i in range(SLOTS):
		var slotc := Control.new()
		slotc.name = "Slot_%d" % i
		slotc.custom_minimum_size = Vector2(40, 40)
		slotc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor_slots.add_child(slotc)

		var fondo := TextureRect.new()
		fondo.name = "Fondo"
		fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo.stretch_mode = TextureRect.STRETCH_SCALE
		fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slotc.add_child(fondo)
		fondos_slot.append(fondo)

		var icono := TextureRect.new()
		icono.name = "Icono"
		icono.set_anchors_preset(Control.PRESET_FULL_RECT)
		icono.offset_left = 6
		icono.offset_top = 6
		icono.offset_right = -6
		icono.offset_bottom = -10
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slotc.add_child(icono)
		iconos_objeto.append(icono)

		var cant := Label.new()
		cant.name = "Cantidad"
		cant.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cant.anchor_left = 1.0
		cant.anchor_top = 1.0
		cant.anchor_right = 1.0
		cant.anchor_bottom = 1.0
		cant.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		cant.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cant.offset_left = -36
		cant.offset_top = -18
		cant.offset_right = -4
		cant.offset_bottom = -2
		cant.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cant.add_theme_font_size_override("font_size", 12)
		cant.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slotc.add_child(cant)
		cantidades_slot.append(cant)

	# Guardar y salir + mensajes (no forma parte del HUD de supervivencia).
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margen.offset_left = -300
	margen.offset_bottom = 120
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 12)
	root.add_child(margen)
	var contenido := VBoxContainer.new()
	margen.add_child(contenido)
	boton = Button.new()
	boton_guardar = boton
	boton.name = "GuardarYSalir"
	boton.text = "Guardar y salir"
	boton.pressed.connect(_guardar_y_salir)
	contenido.add_child(boton)
	mensaje = Label.new()
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(mensaje)
	etiqueta_inventario = Label.new()
	etiqueta_inventario.name = "Inventario"
	etiqueta_inventario.visible = false
	contenido.add_child(etiqueta_inventario)


func _conectar() -> void:
	if inventario != null:
		if inventario.has_signal("cambiado") and not inventario.cambiado.is_connected(_actualizar_inventario):
			inventario.cambiado.connect(_actualizar_inventario)
		if inventario.has_signal("slot_seleccionado_cambiado") and not inventario.slot_seleccionado_cambiado.is_connected(_on_slot_seleccionado):
			inventario.slot_seleccionado_cambiado.connect(_on_slot_seleccionado)
	if jugador == null and mundo != null:
		jugador = mundo.get_node_or_null("Recursos/Player")
	if jugador == null:
		jugador = mundo.find_child("Player", true, false)
	if jugador != null:
		if jugador.has_signal("vida_cambiada") and not jugador.vida_cambiada.is_connected(_actualizar_vida):
			jugador.vida_cambiada.connect(_actualizar_vida)
		if jugador.has_signal("hambre_cambiada") and not jugador.hambre_cambiada.is_connected(_actualizar_hambre):
			jugador.hambre_cambiada.connect(_actualizar_hambre)


func _unhandled_input(event: InputEvent) -> void:
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


func _actualizar_todo() -> void:
	_actualizar_inventario()
	if jugador == null and mundo != null:
		jugador = mundo.get_node_or_null("Recursos/Player")
	if jugador == null:
		jugador = mundo.find_child("Player", true, false)
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
		if i < regiones_slot_sel.size():
			fondos_slot[i].texture = regiones_slot_sel[i] if sel else regiones_slot_normal[i]
		if slot == null:
			iconos_objeto[i].texture = null
			iconos_objeto[i].modulate = Color(1, 1, 1, 0)
			cantidades_slot[i].text = ""
		else:
			var icono := _icono_para_item(String(slot.get("id", "")), String(slot.get("icono", "")))
			iconos_objeto[i].texture = icono
			iconos_objeto[i].modulate = Color(1, 1, 1, 1) if icono != null else Color(0.85, 0.75, 0.35, 0.85)
			var cantidad := int(slot.get("cantidad", 0))
			cantidades_slot[i].text = str(cantidad) if cantidad > 1 else ""


func _icono_para_item(id: String, ruta: String) -> Texture2D:
	if not ruta.is_empty() and ResourceLoader.exists(ruta):
		var tex = load(ruta)
		if tex is Texture2D:
			return tex
	var por_id := "res://assets/objetos/%s.png" % id
	if ResourceLoader.exists(por_id):
		var tex = load(por_id)
		if tex is Texture2D:
			return tex
	return null


func _on_slot_seleccionado(_indice: int) -> void:
	_actualizar_inventario()


func _actualizar_vida(vida: int, vida_maxima: int) -> void:
	var max_puntos := maxi(vida_maxima, 20)
	for i in range(iconos_corazon.size()):
		var valor := clampi(vida - i * 2, 0, 2)
		if valor >= 2:
			iconos_corazon[i].texture = tex_corazon_lleno
		elif valor == 1:
			iconos_corazon[i].texture = tex_corazon_medio
		else:
			iconos_corazon[i].texture = tex_corazon_vacio


func _actualizar_hambre(_hambre: int, _hambre_maxima: int) -> void:
	# Espacio reservado para 10 iconos de comida; se conectará cuando existan sprites.
	for tr in iconos_hambre:
		tr.modulate = Color(1, 1, 1, 0)


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
	var p: CharacterBody2D = mundo.get_node_or_null("Recursos/Player")
	if p == null:
		p = mundo.find_child("Player", true, false) as CharacterBody2D
	if p == null:
		return
	p.set_physics_process(false)
	p.velocity = Vector2.ZERO
	boton.disabled = true
	var vida_val = p.vida if "vida" in p else 20
	var hambre_val = p.hambre if "hambre" in p else 20
	var ok := GestorMundos.guardar_progreso(p.position, inventario, mundo.arbustos_recolectados, vida_val, hambre_val)
	if ok:
		var error := get_tree().change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn")
		if error == OK:
			return
		mostrar_mensaje("Guardado correcto, pero no se pudo volver al menú. Reintenta.")
	else:
		mostrar_mensaje(GestorMundos.ultimo_error + " Reintenta.")
	boton.disabled = false


extends CanvasLayer

var mensaje: Label
var boton: Button
var etiqueta_inventario: Label


func _ready() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margen.offset_left = -300
	margen.offset_bottom = 100
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 12)
	add_child(margen)
	var contenido := VBoxContainer.new()
	margen.add_child(contenido)
	boton = Button.new()
	boton.name = "GuardarYSalir"
	boton.text = "Guardar y salir"
	boton.pressed.connect(_guardar_y_salir)
	contenido.add_child(boton)
	mensaje = Label.new()
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(mensaje)
	etiqueta_inventario = Label.new()
	etiqueta_inventario.name = "Inventario"
	contenido.add_child(etiqueta_inventario)
	actualizar_inventario()


func actualizar_inventario() -> void:
	var objetos: Dictionary = get_parent().inventario.objetos
	var cantidad := int(objetos.get("fruto_alienigena", {}).get("cantidad", 0))
	etiqueta_inventario.text = "Frutos alienígenas: %d" % cantidad


func _guardar_y_salir() -> void:
	var mundo := get_parent()
	var jugador: CharacterBody2D = mundo.get_node("Player")
	jugador.set_physics_process(false)
	jugador.velocity = Vector2.ZERO
	boton.disabled = true
	if GestorMundos.guardar_progreso(jugador.position, mundo.inventario.objetos, mundo.arbustos_recolectados):
		var error := get_tree().change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn")
		if error == OK:
			return
		mensaje.text = "Guardado correcto, pero no se pudo volver al menú. Reintenta."
	else:
		mensaje.text = GestorMundos.ultimo_error + " Reintenta."
	boton.disabled = false

extends CanvasLayer

var mensaje: Label
var boton: Button


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


func _guardar_y_salir() -> void:
	var mundo := get_parent()
	var jugador: CharacterBody2D = mundo.get_node("Player")
	jugador.set_physics_process(false)
	jugador.velocity = Vector2.ZERO
	boton.disabled = true
	if GestorMundos.guardar_progreso(jugador.position):
		var error := get_tree().change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn")
		if error == OK:
			return
		mensaje.text = "Guardado correcto, pero no se pudo volver al menú. Reintenta."
	else:
		mensaje.text = GestorMundos.ultimo_error + " Reintenta."
	boton.disabled = false

extends Control


func _ready() -> void:
	$Centro/Contenido/Jugar.pressed.connect(_jugar)
	$Centro/Contenido/Opciones.pressed.connect(_opciones)
	$Centro/Contenido/Salir.pressed.connect(_salir)


func _jugar() -> void:
	get_tree().change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn")


func _opciones() -> void:
	get_tree().change_scene_to_file("res://escenas/interfaz/opciones.tscn")


func _salir() -> void:
	get_tree().quit()

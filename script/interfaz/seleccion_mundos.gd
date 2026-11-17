extends Control


func _ready() -> void:
	$Centro/Contenido/CrearMundo.pressed.connect(_crear_mundo)
	$Centro/Contenido/Volver.pressed.connect(_volver)


func _crear_mundo() -> void:
	get_tree().change_scene_to_file("res://escenas/mundo.tscn")


func _volver() -> void:
	get_tree().change_scene_to_file("res://escenas/interfaz/menu_principal.tscn")

extends Control


func _ready() -> void:
	var volumen: HSlider = $Centro/Contenido/Volumen
	volumen.value = AudioServer.get_bus_volume_linear(0)
	volumen.value_changed.connect(_cambiar_volumen)
	$Centro/Contenido/Volver.pressed.connect(_volver)


func _cambiar_volumen(valor: float) -> void:
	AudioServer.set_bus_volume_linear(0, valor)


func _volver() -> void:
	get_tree().change_scene_to_file("res://escenas/interfaz/menu_principal.tscn")

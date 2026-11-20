extends Control


func _ready() -> void:
	var musica: HSlider = $Centro/Contenido/Musica
	var sonidos: HSlider = $Centro/Contenido/Sonidos
	if has_node("/root/GestorAudio"):
		var ga = get_node("/root/GestorAudio")
		musica.value = float(ga.volumen_musica)
		sonidos.value = float(ga.volumen_sonidos)
	else:
		musica.value = 1.0
		sonidos.value = 1.0
	musica.value_changed.connect(_cambiar_musica)
	sonidos.value_changed.connect(_cambiar_sonidos)
	$Centro/Contenido/Volver.pressed.connect(_volver)
	if has_node("/root/GestorAudio"):
		get_node("/root/GestorAudio").conectar_botones(self)


func _cambiar_musica(valor: float) -> void:
	if has_node("/root/GestorAudio"):
		get_node("/root/GestorAudio").establecer_volumen_musica(valor)


func _cambiar_sonidos(valor: float) -> void:
	if has_node("/root/GestorAudio"):
		get_node("/root/GestorAudio").establecer_volumen_sonidos(valor)


func _volver() -> void:
	get_tree().change_scene_to_file("res://escenas/interfaz/menu_principal.tscn")

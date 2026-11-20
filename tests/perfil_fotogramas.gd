extends SceneTree


func _initialize() -> void:
	call_deferred("medir")


func medir() -> void:
	root.get_node("GestorMundos").mundo_actual = {"id": "perfil", "nombre": "Perfil", "semilla": 7654321, "dificultad": "Normal", "tamano_tile": 32, "progreso": {}}
	change_scene_to_file("res://escenas/interfaz/carga_mundo.tscn")
	while current_scene == null or current_scene.scene_file_path != "res://escenas/mundo.tscn":
		await process_frame
	var mundo = current_scene
	var max_atlas := 0
	var total_atlas := 0
	var max_visibilidad := 0
	var total_visibilidad := 0
	for i in range(100):
		var inicio := Time.get_ticks_usec()
		mundo._actualizar_atlas_oleaje(i % 12)
		var duracion := Time.get_ticks_usec() - inicio
		max_atlas = maxi(max_atlas, duracion)
		total_atlas += duracion
		inicio = Time.get_ticks_usec()
		mundo._actualizar_animaciones_visibles()
		duracion = Time.get_ticks_usec() - inicio
		max_visibilidad = maxi(max_visibilidad, duracion)
		total_visibilidad += duracion
	print("PERFIL atlas_media_us=%d atlas_max_us=%d visibilidad_media_us=%d visibilidad_max_us=%d" % [total_atlas / 100, max_atlas, total_visibilidad / 100, max_visibilidad])
	quit()

extends SceneTree


func _initialize() -> void:
	call_deferred("probar")


func probar() -> void:
	var gestor = root.get_node("GestorMundos")
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.is_empty():
		printerr("Indica crear o comprobar")
		quit(1)
		return
	if argumentos[0] == "crear":
		var mundo: Dictionary = gestor.crear_mundo("PersistenciaReinicio", 24680, "Normal")
		if mundo.is_empty():
			printerr(gestor.ultimo_error)
			quit(1)
			return
		gestor.mundo_actual = mundo
		if not gestor.guardar_progreso(Vector2(321, 654)):
			printerr(gestor.ultimo_error)
			quit(1)
			return
		print("Mundo guardado para reinicio")
		quit()
	else:
		for mundo in gestor.listar_mundos():
			if mundo.nombre == "PersistenciaReinicio" and mundo.semilla == 24680 and mundo.progreso.jugador.posicion == {"x": 321.0, "y": 654.0}:
				DirAccess.remove_absolute("user://mundos".path_join(mundo.id + ".json"))
				print("Mundo recuperado tras reiniciar Godot")
				quit()
				return
		printerr("Mundo no encontrado después de reiniciar")
		quit(1)

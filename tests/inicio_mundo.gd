extends SceneTree

var fallos := 0


func _initialize() -> void:
	call_deferred("probar")


func comprobar(condicion: bool, descripcion: String) -> void:
	if not condicion:
		fallos += 1
		printerr("FALLO: ", descripcion)


func esperar_escena(ruta: String, limite_segundos := 90.0) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < limite_segundos * 1000:
		if current_scene != null and current_scene.scene_file_path == ruta:
			return true
		await process_frame
	return false


func probar() -> void:
	var gestor = root.get_node("GestorMundos")
	var fondos = root.get_node("GestorFondos")
	change_scene_to_file("res://escenas/interfaz/menu_principal.tscn")
	await process_frame
	await process_frame
	current_scene.get_node("Centro/Contenido/Jugar").pressed.emit()
	await process_frame
	await process_frame
	comprobar(current_scene.scene_file_path.ends_with("seleccion_mundos.tscn"), "menú a selección")
	var contenido: VBoxContainer = current_scene.get_node("Centro/Contenido")
	(contenido.get_child(1) as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	comprobar(current_scene.scene_file_path.ends_with("crear_mundo.tscn"), "selección a creación")
	var nombre := "Flujo_" + str(Time.get_ticks_usec())
	current_scene.nombre.text = nombre
	current_scene.semilla.text = "7654321"
	current_scene._seleccionar_dificultad("Difícil")
	current_scene._crear()
	if await esperar_escena("res://escenas/interfaz/carga_mundo.tscn"):
		var carga = current_scene
		comprobar(carga.imagen.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "fondo de carga cubre la ventana")
		comprobar(carga.capa_carga.layer > 0, "capa de carga por encima del mundo")
	else:
		comprobar(false, "pantalla de carga")
	if not await esperar_escena("res://escenas/mundo.tscn"):
		printerr("FALLO: el mundo no terminó de cargar")
		quit(1)
		return
	var mundo = current_scene
	comprobar(mundo.world_seed == 7654321 and mundo.generacion_lista, "semilla y generación")
	comprobar(not fondos.visible, "fondo oculto")
	var camara_inicio = mundo.get_node_or_null("Player/WorldCamera")
	if camara_inicio == null:
		camara_inicio = mundo.get_node_or_null("Recursos/Player/WorldCamera")
	if camara_inicio == null:
		camara_inicio = mundo.find_child("WorldCamera", true, false)
	comprobar(camara_inicio != null and camara_inicio.is_current(), "cámara activa tras la transición")
	var terreno: int = mundo.get_terrain(45, 27)
	var id: String = gestor.mundo_actual.id
	var jugador: CharacterBody2D = mundo.get_node_or_null("Player")
	if jugador == null:
		jugador = mundo.find_child("Player", true, false) as CharacterBody2D
	jugador.position = Vector2(1234, 2345)
	jugador.set_physics_process(false)
	mundo.get_node("InterfazMundo")._guardar_y_salir()
	comprobar(await esperar_escena("res://escenas/interfaz/seleccion_mundos.tscn"), "salida a selección")
	var recuperado: Dictionary = {}
	for datos in gestor.listar_mundos():
		if datos.id == id:
			recuperado = datos
	comprobar(not recuperado.is_empty(), "partida disponible")
	comprobar(recuperado.get("nombre") == nombre and recuperado.get("semilla") == 7654321 and recuperado.get("dificultad") == "Difícil", "configuración persistida")
	comprobar(not recuperado.get("fecha_ultimo_guardado", "").is_empty(), "fecha de guardado")
	if not recuperado.is_empty():
		current_scene._jugar(recuperado)
		if await esperar_escena("res://escenas/mundo.tscn"):
			mundo = current_scene
			comprobar(mundo.get_terrain(45, 27) == terreno, "terreno reproducido")
			var jugador_rec = mundo.get_node_or_null("Player")
			if jugador_rec == null:
				jugador_rec = mundo.find_child("Player", true, false)
			comprobar(jugador_rec != null and jugador_rec.position.distance_to(Vector2(1234, 2345)) < 0.1, "posición recuperada")
		else:
			comprobar(false, "recargar mundo")
	DirAccess.remove_absolute("user://mundos".path_join(id + ".json"))
	print("Prueba completa: ", "OK" if fallos == 0 else "%d fallos" % fallos)
	quit(0 if fallos == 0 else 1)

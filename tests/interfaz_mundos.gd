extends SceneTree

const Datos = preload("res://script/sistemas/datos_mundo.gd")
var gestor: Node
var fondos: CanvasLayer
var errores := 0


func _initialize() -> void:
	call_deferred("probar")


func comprobar(condicion: bool, detalle: String) -> void:
	if not condicion:
		errores += 1
		printerr("FALLO: " + detalle)


func probar() -> void:
	gestor = root.get_node("GestorMundos")
	fondos = root.get_node("GestorFondos")
	comprobar(Datos.semilla_valida("-2147483648"), "semilla mínima")
	comprobar(Datos.semilla_valida("2147483247"), "semilla máxima")
	comprobar(not Datos.semilla_valida("2147483248"), "semilla fuera de rango")
	comprobar(not Datos.semilla_valida("999999999999999999999999"), "desbordamiento")
	comprobar(gestor.crear_mundo("   ", 1, "Normal").is_empty(), "nombre vacío")
	var nombre := "Prueba_" + str(Time.get_ticks_usec())
	var creado: Dictionary = gestor.crear_mundo("  " + nombre + "  ", -42, "Difícil")
	comprobar(not creado.is_empty(), "crear mundo: " + gestor.ultimo_error)
	if creado.is_empty():
		quit(1)
		return
	comprobar(creado.nombre == nombre and creado.semilla == -42, "datos normalizados")
	comprobar(gestor.crear_mundo(nombre.to_lower(), 1, "Normal").is_empty(), "duplicado sin distinción de mayúsculas")
	gestor.mundo_actual = creado.duplicate(true)
	var archivo_previo := FileAccess.get_file_as_string("user://mundos".path_join(creado.id + ".json"))
	comprobar(not gestor.guardar_progreso(Vector2(-1, 20)), "rechazar posición inválida")
	comprobar(FileAccess.get_file_as_string("user://mundos".path_join(creado.id + ".json")) == archivo_previo, "error de guardado conserva original")
	var guardados: Array[Dictionary] = gestor.listar_mundos()
	var recuperado: Dictionary = {}
	for mundo in guardados:
		if mundo.id == creado.id:
			recuperado = mundo
	comprobar(recuperado == creado, "persistencia de configuración")
	change_scene_to_file("res://escenas/interfaz/seleccion_mundos.tscn")
	await process_frame
	await process_frame
	var seleccion := current_scene
	comprobar(fondos.visible, "fondo visible en interfaz")
	var contenido_seleccion: Control = seleccion.get_node("Centro/Contenido")
	var barra: Control = contenido_seleccion.get_node("Busqueda")
	var panel: Control = contenido_seleccion.get_node("PanelMundos")
	comprobar(is_equal_approx(barra.size.x, panel.size.x) and is_equal_approx(barra.global_position.x, panel.global_position.x), "alineación y ancho iguales")
	seleccion.busqueda.text = nombre.to_lower()
	seleccion.busqueda.text_changed.emit(seleccion.busqueda.text)
	comprobar(not seleccion.mensaje.visible, "buscar sin distinguir mayúsculas")
	seleccion.busqueda.text = "nombre_inexistente_xyz"
	seleccion.busqueda.text_changed.emit(seleccion.busqueda.text)
	comprobar(seleccion.mensaje.visible, "mensaje sin coincidencias")
	seleccion.busqueda.text = ""
	seleccion.busqueda.text_changed.emit("")
	comprobar(not seleccion.mensaje.visible and seleccion.lista.get_child_count() == seleccion.mundos.size() + 1, "al borrar se muestran todos")
	comprobar(not seleccion.busqueda.clear_button_enabled, "búsqueda sin X")
	change_scene_to_file("res://escenas/interfaz/crear_mundo.tscn")
	await process_frame
	await process_frame
	comprobar(fondos.visible, "fondo persistente al cambiar de pantalla")
	comprobar(current_scene.dificultad == "Normal", "dificultad predeterminada")
	comprobar(not current_scene.nombre.clear_button_enabled and not current_scene.semilla.clear_button_enabled, "campos de creación sin X")
	var fila: HBoxContainer = current_scene.get_node("Centro/Contenido/Dificultades")
	var facil: TextureButton = fila.get_child(0)
	var normal: TextureButton = fila.get_child(1)
	var dificil: TextureButton = fila.get_child(2)
	comprobar(normal.button_pressed and not facil.button_pressed and not dificil.button_pressed, "selección exclusiva predeterminada")
	var posiciones := [facil.position, normal.position, dificil.position]
	facil.button_pressed = true
	facil.pressed.emit()
	await process_frame
	comprobar(facil.button_pressed and not normal.button_pressed and not dificil.button_pressed and current_scene.dificultad == "Fácil", "selección exclusiva actualiza valor")
	comprobar(posiciones == [facil.position, normal.position, dificil.position], "dificultades fijas")
	comprobar((facil.texture_normal as AtlasTexture).region.position.y == 0 and (facil.texture_hover as AtlasTexture).region.position.y == 120 and (facil.texture_pressed as AtlasTexture).region.position.y == 120, "estados de la hoja disponible")
	facil.button_down.emit()
	comprobar((facil.texture_pressed as AtlasTexture).region.position.y == 240, "sprite presionado físico")
	facil.button_up.emit()
	comprobar((facil.texture_pressed as AtlasTexture).region.position.y == 120, "sprite seleccionado persistente")
	var indice_fondo: int = fondos.indice
	fondos._cambiar_fondo()
	comprobar(fondos.indice != indice_fondo, "el fondo siguiente no se repite")
	# Prueba el generador sin generar los 65 536 tiles ni alterar su lógica.
	var generador = load("res://script/terrain_generator.gd").new()
	generador.world_seed = recuperado.semilla
	generador.setup_noise()
	var terreno: int = generador.get_terrain(5, 10)
	var generador2 = load("res://script/terrain_generator.gd").new()
	generador2.world_seed = recuperado.semilla
	generador2.setup_noise()
	comprobar(generador2.get_terrain(5, 10) == terreno, "terreno reproducible")
	generador.free()
	generador2.free()
	# La semilla exportada sigue intacta para abrir la escena directamente.
	gestor.mundo_actual = recuperado
	var escena_mundo: PackedScene = load("res://escenas/mundo.tscn")
	var mundo_real = escena_mundo.instantiate()
	comprobar(mundo_real.world_seed == 67, "semilla original de la escena intacta")
	mundo_real.free()
	gestor.mundo_actual = {}
	DirAccess.remove_absolute("user://mundos".path_join(creado.id + ".json"))
	print("Pruebas de interfaz y mundos: ", "OK" if errores == 0 else "%d fallos" % errores)
	quit(0 if errores == 0 else 1)

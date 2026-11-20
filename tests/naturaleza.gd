extends SceneTree

const Catalogo = preload("res://script/sistemas/catalogo_recursos.gd")
const Tiles = preload("res://script/sistemas/tiles_naturaleza.gd")
var errores := 0


func _initialize() -> void:
	call_deferred("probar")


func comprobar(valor: bool, mensaje: String) -> void:
	if not valor:
		errores += 1
		printerr("FALLO: ", mensaje)


func probar() -> void:
	var cuentas := [0, 0, 0]
	for i in range(100):
		cuentas[Catalogo.elegir_indice([15, 70, 15], (i + 0.5) / 100.0)] += 1
	comprobar(cuentas == [15, 70, 15], "proporciones configuradas")
	for tipo in Catalogo.ARBOLES:
		comprobar(Catalogo.fotogramas(tipo.ruta).get_frame_count("viento") == 6, "árbol animado")
	for i in range(6):
		comprobar(Catalogo.roca(i).get_size().x > 0, "roca %d" % i)
	comprobar(Tiles.elegir_borde([1, 2, 2, 2], [1]) == 0, "costa este")
	comprobar(Tiles.elegir_borde([2, 1, 2, 2], [1]) == 1, "costa sur")
	var tecla_f := false
	for evento in InputMap.action_get_events("interactuar"):
		if evento is InputEventKey and evento.physical_keycode == KEY_F:
			tecla_f = true
	comprobar(tecla_f, "acción interactuar con F")
	var gestor = root.get_node("GestorMundos")
	var datos: Dictionary = gestor.crear_mundo("Naturaleza_" + str(Time.get_ticks_usec()), 57, "Normal")
	gestor.mundo_actual = datos
	var mundo = load("res://escenas/mundo.tscn").instantiate()
	mundo.world_seed = 57
	mundo.setup_noise()
	mundo.setup_terrain()
	comprobar(mundo.mar_frames.size() == 6 and mundo.orilla_frames.size() == 4, "fotogramas de oleaje")
	var colores: Array[Color] = []
	for fase in [0, 3, 6, 9]:
		mundo._actualizar_atlas_oleaje(fase)
		colores.append(mundo.imagen_oleaje.get_pixel(mundo.ATLAS_ORILLA * 32 + 16, 16))
	comprobar(mundo.terrain_layer.tile_set.tile_size == Vector2i(32, 32), "cuadrícula intacta")
	var variantes := {}
	for y in range(32):
		for x in range(32):
			var tipo: int = mundo.get_terrain(x, y)
			var id: int = mundo._atlas_para_terreno(x, y, tipo)
			variantes[id] = true
	comprobar(variantes.size() > 3, "variantes distribuidas")
	var capa := Node2D.new()
	mundo.resources_layer = capa
	mundo.add_child(capa)
	mundo._preparar_recursos()
	comprobar(mundo._reservar_espacio(Vector2(1, 500), Vector2(30, 30)), "reservar borde")
	comprobar(not mundo._reservar_espacio(Vector2(8191, 500), Vector2(30, 30)), "separación entre bordes wrap")
	mundo._colocar_animado("arbusto_1", Vector2(100, 100), 40, "3_3")
	var copia: Node2D = mundo.visuales_arbustos["3_3"][0].duplicate()
	mundo.visuales_arbustos["3_3"].append(copia)
	comprobar(mundo.recolectar_cercano(Vector2(110, 100)), "recolección")
	comprobar(not mundo.recolectar_cercano(Vector2(110, 100)), "sin duplicación")
	comprobar(mundo.inventario.objetos.fruto_alienigena.cantidad == 1, "inventario")
	comprobar(mundo.arbustos_recolectados.has("3_3"), "identificador estable")
	comprobar(copia.get_node("SpriteNode2D").sprite_frames == mundo.sprites_recursos.arbusto_vacio, "copia actualizada")
	comprobar(gestor.guardar_progreso(Vector2(100, 100), mundo.inventario.objetos, mundo.arbustos_recolectados), "guardar recursos")
	var ruta: String = "user://mundos".path_join(datos.id + ".json")
	var cargado: Dictionary = gestor._leer_mundo(ruta)
	comprobar(cargado.progreso.inventario.fruto_alienigena.cantidad == 1 and cargado.progreso.cambios_mundo.arbustos_recolectados.has("3_3"), "recuperar recursos")
	var reabierto = load("res://escenas/mundo.tscn").instantiate()
	reabierto.resources_layer = Node2D.new()
	reabierto.add_child(reabierto.resources_layer)
	reabierto._preparar_recursos()
	reabierto.arbustos_recolectados = cargado.progreso.cambios_mundo.arbustos_recolectados
	reabierto._colocar_animado("arbusto_1", Vector2(100, 100), 40, "3_3")
	comprobar(not reabierto.recolectar_cercano(Vector2(100, 100)), "no recolectar tras recarga")
	reabierto.free()
	copia.free()
	mundo.free()
	DirAccess.remove_absolute(ruta)
	print("Naturaleza: ", "OK" if errores == 0 else "%d fallos" % errores)
	quit(0 if errores == 0 else 1)

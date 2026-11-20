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
	await mundo._precalcular_terreno()
	mundo.setup_terrain()
	comprobar(mundo.mar_frames.size() == 6 and mundo.orilla_frames.size() == 2 and mundo.orillas_rectas.size() == 4 and mundo.orillas_esquina.size() == 4, "costas rectas y de esquina")
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
	var puntas := 0
	var puentes := 0
	var puntos := 0
	var cesped_agua := 0
	var transiciones := 0
	var costas := 0
	for y in range(mundo.MAP_SIZE):
		for x in range(mundo.MAP_SIZE):
			var tipo: int = mundo._terreno_visual(x, y)
			if tipo != mundo.SAND and tipo != mundo.GRASS:
				continue
			var vecinos: Array[int] = []
			for d in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
				vecinos.append(mundo._terreno_visual(x + d.x, y + d.y))
			var agua := 0
			var arena := 0
			for v in vecinos:
				if v == mundo.WATER or v == mundo.DEEP_WATER:
					agua += 1
				elif v == mundo.SAND:
					arena += 1
			if tipo == mundo.SAND:
				if agua >= 3:
					puntas += 1
				if agua == 2 and ((vecinos[0] == vecinos[2] and vecinos[0] != vecinos[1]) or (vecinos[1] == vecinos[3] and vecinos[1] != vecinos[0])):
					puentes += 1
				if agua > 0:
					var id: int = mundo._atlas_para_terreno(x, y, tipo)
					if id < mundo.ATLAS_ORILLA or id >= mundo.ATLAS_ORILLA + 8:
						costas += 1
			else:
				if arena >= 3:
					puntos += 1
				if agua > 0:
					cesped_agua += 1
				if arena > 0:
					var id: int = mundo._atlas_para_terreno(x, y, tipo)
					if id < mundo.ATLAS_TRANSICION or id >= mundo.ATLAS_TRANSICION + 24:
						transiciones += 1
	comprobar(puntas == 0, "sin puntas de arena")
	comprobar(puentes == 0, "sin puentes de arena")
	comprobar(puntos == 0, "sin puntas de césped")
	comprobar(cesped_agua == 0, "césped nunca toca el agua")
	comprobar(costas == 0, "toda costa usa transición")
	comprobar(transiciones == 0, "todo borde césped-arena usa transición")
	var capa := Node2D.new()
	mundo.resources_layer = capa
	mundo.add_child(capa)
	mundo._preparar_recursos()
	comprobar(mundo._reservar_espacio(Vector2(1, 500), Vector2(30, 30)), "reservar borde")
	comprobar(not mundo._reservar_espacio(Vector2(8191, 500), Vector2(30, 30)), "separación entre bordes wrap")
	mundo._colocar_animado("arbusto_0", Vector2(16, 784), 44, "0_24")
	comprobar(mundo.recolectar_cercano(Vector2(8190, 784)), "recolección a través del borde")
	mundo.inventario.objetos.clear()
	mundo.arbustos_recolectados.clear()
	mundo._colocar_animado("arbusto_1", Vector2(100, 100), 40, "3_3")
	var copia: Node2D = mundo.visuales_arbustos["3_3"][0].duplicate()
	mundo.visuales_arbustos["3_3"].append(copia)
	var copia_activa := copia as AnimatedSprite2D
	copia_activa.play("viento")
	comprobar(mundo.recolectar_cercano(Vector2(110, 100)), "recolección")
	comprobar(not mundo.recolectar_cercano(Vector2(110, 100)), "sin duplicación")
	comprobar(mundo.inventario.objetos.fruto_alienigena.cantidad == 1, "inventario")
	comprobar(mundo.arbustos_recolectados.has("3_3"), "identificador estable")
	comprobar((copia as AnimatedSprite2D).sprite_frames == mundo.sprites_recursos.arbusto_1_vacio, "copia actualizada")
	comprobar(copia_activa.is_playing(), "animación de copia continúa")
	comprobar(Tiles.elegir_borde([1, 1, 2, 2], [1]) == -1 and Tiles.indice_par([1, 1, 2, 2], [1]) == 0, "transición en esquina")
	comprobar(Tiles.rotacion_esquina([1, 2, 2, 1], [1], 3) == 0, "esquina noreste")
	var imagen_orilla := Tiles.preparar_imagen(Tiles.ARENA_AGUA, Tiles.CELDAS_ARENA_AGUA[0], Color.BLACK)
	comprobar(imagen_orilla.get_pixel(0, 0).a == 1.0 and imagen_orilla.get_pixel(31, 31).a == 1.0, "baldosas sin huecos")
	mundo.animados_visibles = {copia_activa: true}
	mundo.viento_activo.clear()
	copia_activa.stop()
	mundo.espera_viento = 0.0
	mundo._actualizar_viento(0.1)
	comprobar(copia_activa.is_playing() and mundo.viento_activo.size() == 1, "ráfaga aleatoria limitada")
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
	var arbusto_tipo_0 = load("res://escenas/mundo.tscn").instantiate()
	arbusto_tipo_0.resources_layer = Node2D.new()
	arbusto_tipo_0.add_child(arbusto_tipo_0.resources_layer)
	arbusto_tipo_0._preparar_recursos()
	arbusto_tipo_0._colocar_animado("arbusto_0", Vector2(200, 200), 44, "6_6")
	arbusto_tipo_0.recolectar_cercano(Vector2(200, 200))
	comprobar(arbusto_tipo_0.visuales_arbustos["6_6"][0].sprite_frames == arbusto_tipo_0.sprites_recursos.arbusto_0_vacio, "arbusto 0 conserva su tipo")
	comprobar(arbusto_tipo_0.visuales_arbustos["6_6"][0].sprite_frames != arbusto_tipo_0.sprites_recursos.arbusto_1_vacio, "tipos de arbusto distintos")
	arbusto_tipo_0.free()
	reabierto.free()
	copia.free()
	mundo.free()
	DirAccess.remove_absolute(ruta)
	print("Naturaleza: ", "OK" if errores == 0 else "%d fallos" % errores)
	quit(0 if errores == 0 else 1)

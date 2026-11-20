extends SceneTree


func _initialize() -> void:
	call_deferred("generar")


func generar() -> void:
	var salida := OS.get_environment("STRANDED_METRICAS")
	if salida.is_empty():
		salida = "user://metricas"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(salida))
	var mundo = load("res://escenas/mundo.tscn").instantiate()
	mundo.world_seed = 7654321
	mundo.setup_noise()
	await mundo._precalcular_terreno()
	mundo.setup_terrain()
	var atlas: Image = mundo.imagen_oleaje.duplicate() as Image
	var atlas_zoom: Image = atlas.duplicate() as Image
	atlas_zoom.resize(atlas_zoom.get_width() * 8, atlas_zoom.get_height() * 8, Image.INTERPOLATE_NEAREST)
	atlas_zoom.save_png(salida.path_join("atlas.png"))

	var lado := 32
	var mejor := Vector2i(32, 32)
	var mejor_puntaje := -1
	for oy in range(0, mundo.MAP_SIZE - lado + 1, 8):
		for ox in range(0, mundo.MAP_SIZE - lado + 1, 8):
			var tipos := {}
			for y in range(oy, oy + lado):
				for x in range(ox, ox + lado):
					tipos[mundo._terreno_visual(x, y)] = true
			var puntaje := tipos.size() * 100
			if tipos.has(mundo.GRASS) and tipos.has(mundo.SAND):
				puntaje += 20
			if tipos.has(mundo.SAND) and tipos.has(mundo.WATER):
				puntaje += 20
			if puntaje > mejor_puntaje:
				mejor_puntaje = puntaje
				mejor = Vector2i(ox, oy)
	var puntas := 0
	var puentes := 0
	var puntos := 0
	var cesped_agua := 0
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
			else:
				if arena >= 3:
					puntos += 1
				if agua > 0:
					cesped_agua += 1
	print("DIAGNOSTICO puntas_arena=%d puentes_arena=%d puntos_cesped=%d cesped_agua=%d" % [puntas, puentes, puntos, cesped_agua])
	var mapa := Image.create(lado * 32, lado * 32, false, Image.FORMAT_RGBA8)
	var usos := {}
	for y in range(lado):
		for x in range(lado):
			var tipo: int = mundo._terreno_visual(mejor.x + x, mejor.y + y)
			var indice: int = mundo._atlas_para_terreno(mejor.x + x, mejor.y + y, tipo)
			usos[indice] = usos.get(indice, 0) + 1
			mapa.blit_rect(atlas, Rect2i(indice * 32, 0, 32, 32), Vector2i(x * 32, y * 32))
	var vacios: Array[int] = []
	for indice in usos:
		var color: Color = atlas.get_pixel(indice * 32 + 16, 16)
		if color.a < 0.99 or (color.r < 0.03 and color.g < 0.03 and color.b < 0.03):
			vacios.append(indice)
	var negros := {}
	for y in range(lado):
		for x in range(lado):
			var indice: int = mundo._atlas_para_terreno(mejor.x + x, mejor.y + y, mundo._terreno_visual(mejor.x + x, mejor.y + y))
			var cuenta := 0
			for py in range(32):
				for px in range(32):
					var c := mapa.get_pixel(x * 32 + px, y * 32 + py)
					if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
						cuenta += 1
			if cuenta > 0:
				negros[indice] = negros.get(indice, 0) + cuenta
	mapa.save_png(salida.path_join("mapa_base.png"))
	mapa.resize(mapa.get_width() * 6, mapa.get_height() * 6, Image.INTERPOLATE_NEAREST)
	mapa.save_png(salida.path_join("mapa.png"))
	print("PREVIEW origen=%s puntaje=%d usos=%s vacios=%s negros=%s" % [mejor, mejor_puntaje, usos, vacios, negros])
	mundo.free()
	quit(0 if puntas + puentes + puntos + cesped_agua == 0 and vacios.is_empty() else 1)

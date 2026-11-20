extends SceneTree


func _initialize() -> void:
	call_deferred("medir")


func medir() -> void:
	var inicio := Time.get_ticks_msec()
	var gestor = root.get_node("GestorMundos")
	gestor.mundo_actual = {"id": "prueba", "nombre": "Prueba", "semilla": 7654321, "dificultad": "Normal", "tamano_tile": 32, "progreso": {}}
	change_scene_to_file("res://escenas/interfaz/carga_mundo.tscn")
	while current_scene == null or current_scene.scene_file_path != "res://escenas/mundo.tscn":
		if Time.get_ticks_msec() - inicio > 120000:
			printerr("Tiempo agotado")
			quit(1)
			return
		await process_frame
	var mundo = current_scene
	var margen_celdas := mini(mundo.MAP_SIZE, ceili(mundo._margen_copias() / mundo.TILE_SIZE))
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var copia: TileMapLayer = mundo.get_node("TerrainCopy_%d_%d" % [ox, oy])
			var x: int = mundo.MAP_SIZE - 1 if ox == -1 else 0
			var y: int = mundo.MAP_SIZE - 1 if oy == -1 else 0
			var celda := Vector2i(x, y)
			if copia.get_cell_atlas_coords(celda) != mundo.terrain_layer.get_cell_atlas_coords(celda):
				printerr("Copia de borde incorrecta: ", ox, ",", oy)
				quit(1)
				return
			if ox != 0 and margen_celdas < mundo.MAP_SIZE:
				var fuera := Vector2i(0 if ox == -1 else mundo.MAP_SIZE - 1, y)
				if copia.get_cell_source_id(fuera) != -1:
					printerr("Copia contiene celdas lejanas")
					quit(1)
					return
	var cache: PackedByteArray = mundo.terreno_cache
	for celda in [Vector2i.ZERO, Vector2i(17, 41), Vector2i(255, 255)]:
		if cache[celda.y * mundo.MAP_SIZE + celda.x] != mundo._calcular_terreno(celda.x, celda.y):
			printerr("Caché de terreno incorrecta")
			quit(1)
			return
	var animados := 0
	var animados_activos := 0
	for recurso in mundo.resources_layer.get_children():
		if recurso == null or not is_instance_valid(recurso):
			continue
		if recurso.name == "Player" or String(recurso.name).ends_with("_Emision"):
			continue
		var sprite := recurso as AnimatedSprite2D
		if sprite == null and recurso.has_method("_sprite_animado_recurso"):
			sprite = recurso._sprite_animado_recurso(recurso)
		if sprite == null and recurso.has_node("Sprite"):
			var n = recurso.get_node("Sprite")
			if n is AnimatedSprite2D:
				sprite = n
		# Recursos animados (árboles/arbustos) tienen AnimatedSprite2D hijo o son AnimatedSprite2D.
		if sprite == null:
			for child in recurso.get_children():
				if child is AnimatedSprite2D:
					sprite = child
					break
		if sprite != null:
			animados += 1
			if sprite.is_playing():
				animados_activos += 1
	var copias_celdas := 0
	for nodo in mundo.get_children():
		if nodo is TileMapLayer:
			copias_celdas += nodo.get_used_cells().size()
	print("METRICAS tiempo_ms=%d recursos=%d animados=%d activos=%d celdas_terreno=%d nodos=%d" % [Time.get_ticks_msec() - inicio, mundo.resources_layer.get_child_count(), animados, animados_activos, copias_celdas, get_node_count()])
	quit()

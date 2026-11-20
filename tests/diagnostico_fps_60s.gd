extends SceneTree

const DURACION := 60.0

var mundo: Node
var jugador: CharacterBody2D
var fase := "cargando"
var tiempo_fase := 0.0
var muestras_a: Array = []
var muestras_b: Array = []
var dir_b := Vector2.RIGHT
var cambio_dir := 0.0
var iniciado_a := false


func _initialize() -> void:
	call_deferred("_iniciar")


func _iniciar() -> void:
	var gestor = root.get_node_or_null("GestorMundos")
	if gestor != null:
		gestor.mundo_actual = {"id": "diag_fps", "nombre": "Diagnostico FPS", "semilla": 7654321, "dificultad": "Normal", "tamano_tile": 32, "progreso": {}}
	change_scene_to_file("res://escenas/interfaz/carga_mundo.tscn")


func _process(delta: float) -> bool:
	if fase == "cargando":
		if current_scene != null and current_scene.scene_file_path.ends_with("mundo.tscn"):
			mundo = current_scene
			if mundo.get("generacion_lista") == true:
				jugador = _buscar_jugador()
				if jugador != null:
					if not iniciado_a:
						iniciado_a = true
						_preparar_directorio()
					else:
						# un frame extra de estabilidad
						fase = "prueba_a"
						tiempo_fase = 0.0
						print("DIAGNOSTICO_FPS: inicio prueba A")
		return false

	if fase == "prueba_a":
		_registrar(muestras_a, delta)
		tiempo_fase += delta
		if tiempo_fase >= DURACION:
			_guardar_csv("user://diagnosticos/fps_60s_prueba_a.csv", muestras_a)
			jugador = _buscar_jugador()
			fase = "prueba_b"
			tiempo_fase = 0.0
			cambio_dir = 0.0
			dir_b = Vector2.RIGHT
			print("DIAGNOSTICO_FPS: inicio prueba B")
		return false

	if fase == "prueba_b":
		_simular_movimiento(delta)
		_registrar(muestras_b, delta)
		tiempo_fase += delta
		if tiempo_fase >= DURACION:
			_liberar_movimiento()
			_guardar_csv("user://diagnosticos/fps_60s_prueba_b.csv", muestras_b)
			_guardar_csv("user://diagnosticos/fps_60s.csv", muestras_a + muestras_b)
			_guardar_resumen()
			print("DIAGNOSTICO_FPS listo en %s" % ProjectSettings.globalize_path("user://diagnosticos/"))
			quit(0)
		return false

	return false


func _registrar(muestras: Array, delta: float) -> void:
	var ms := delta * 1000.0
	var fps := (1.0 / delta) if delta > 0.000001 else 9999.0
	muestras.append({
		"t": tiempo_fase,
		"fps": fps,
		"ms": ms,
		"nodos": get_node_count(),
	})


func _simular_movimiento(delta: float) -> void:
	cambio_dir -= delta
	if cambio_dir <= 0.0:
		cambio_dir = 3.0
		var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized(), Vector2(1, -1).normalized()]
		dir_b = dirs[randi() % dirs.size()]
	_aplicar_direccion(dir_b)


func _aplicar_direccion(dir: Vector2) -> void:
	_set_accion("ui_left", dir.x < -0.2)
	_set_accion("ui_right", dir.x > 0.2)
	_set_accion("ui_up", dir.y < -0.2)
	_set_accion("ui_down", dir.y > 0.2)


func _set_accion(nombre: String, pressed: bool) -> void:
	if pressed:
		if not Input.is_action_pressed(nombre):
			Input.action_press(nombre)
	else:
		if Input.is_action_pressed(nombre):
			Input.action_release(nombre)


func _liberar_movimiento() -> void:
	for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _buscar_jugador() -> CharacterBody2D:
	if current_scene == null:
		return null
	var j := current_scene.get_node_or_null("Player") as CharacterBody2D
	if j == null:
		j = current_scene.get_node_or_null("Recursos/Player") as CharacterBody2D
	if j == null:
		j = current_scene.find_child("Player", true, false) as CharacterBody2D
	return j


func _preparar_directorio() -> void:
	var abs_dir := ProjectSettings.globalize_path("user://diagnosticos")
	DirAccess.make_dir_recursive_absolute(abs_dir)


func _guardar_csv(ruta: String, muestras: Array) -> void:
	var abs_path := ProjectSettings.globalize_path(ruta)
	var dir_path := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		printerr("No se pudo escribir ", abs_path)
		return
	f.store_line("tiempo_s,fps,frame_ms,nodos")
	for m in muestras:
		f.store_line("%.6f,%.6f,%.6f,%d" % [float(m.t), float(m.fps), float(m.ms), int(m.nodos)])
	f.close()


func _guardar_resumen() -> void:
	var abs_path := ProjectSettings.globalize_path("user://diagnosticos/resumen_fps_60s.txt")
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		printerr("No se pudo escribir resumen ", abs_path)
		return
	f.store_line("Diagnóstico de FPS - 60 segundos por prueba")
	f.store_line("Inicio de medición: tras mundo cargado y listo para jugar (generacion_lista).")
	f.store_line("Prueba A: astronauta quieto, cámara quieta, mundo completamente cargado.")
	f.store_line("Prueba B: astronauta recorriendo el mundo con movimiento simulado (cámara siguiendo).")
	f.store_line("Nota: medición basada en tiempos reales de fotograma (delta de proceso).")
	f.store_line("")
	_escribir_stats(f, "Prueba A (quieto)", muestras_a)
	f.store_line("")
	_escribir_stats(f, "Prueba B (movimiento simulado)", muestras_b)
	f.store_line("")
	_escribir_comparativa(f)
	f.close()


func _escribir_stats(f: FileAccess, titulo: String, muestras: Array) -> void:
	if muestras.is_empty():
		f.store_line(titulo + ": sin datos")
		return
	var suma_fps := 0.0
	var suma_ms := 0.0
	var min_fps := INF
	var max_fps := 0.0
	var max_ms := 0.0
	var st16 := 0
	var st33 := 0
	var st50 := 0
	var st100 := 0
	var nodos_min := 2147483647
	var nodos_max := 0
	var ms_vals: Array[float] = []
	for m in muestras:
		var fps := float(m.fps)
		var ms := float(m.ms)
		ms_vals.append(ms)
		suma_fps += fps
		suma_ms += ms
		if fps < min_fps: min_fps = fps
		if fps > max_fps: max_fps = fps
		if ms > max_ms: max_ms = ms
		if ms > 16.67: st16 += 1
		if ms > 33.33: st33 += 1
		if ms > 50.0: st50 += 1
		if ms > 100.0: st100 += 1
		var n := int(m.nodos)
		if n < nodos_min: nodos_min = n
		if n > nodos_max: nodos_max = n
	var ncount := muestras.size()
	var avg_fps := suma_fps / ncount
	var avg_ms := suma_ms / ncount
	ms_vals.sort()
	var idx99 := clampi(int(ceil(float(ms_vals.size()) * 0.99)) - 1, 0, ms_vals.size() - 1)
	var ms_p99 := ms_vals[idx99]
	var low1 := (1000.0 / ms_p99) if ms_p99 > 0.0 else 0.0
	f.store_line(titulo)
	f.store_line("  Duración registrada: %.3f s" % float(muestras[muestras.size() - 1].t))
	f.store_line("  Muestras: %d" % ncount)
	f.store_line("  FPS instantáneos: registrados por fotograma en CSV")
	f.store_line("  FPS promedio: %.2f" % avg_fps)
	f.store_line("  FPS mínimo: %.2f" % min_fps)
	f.store_line("  FPS máximo: %.2f" % max_fps)
	f.store_line("  1%% low (tiempos de fotograma, p99): %.2f FPS (%.3f ms)" % [low1, ms_p99])
	f.store_line("  Tiempo promedio por fotograma: %.3f ms" % avg_ms)
	f.store_line("  Peor tiempo de fotograma: %.3f ms" % max_ms)
	f.store_line("  Fotogramas lentos >16.67ms: %d" % st16)
	f.store_line("  Fotogramas lentos >33.33ms: %d" % st33)
	f.store_line("  Fotogramas lentos >50ms: %d" % st50)
	f.store_line("  Fotogramas lentos >100ms: %d" % st100)
	f.store_line("  Nodos (min/max): %d / %d" % [nodos_min, nodos_max])
	var mem_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	if mem_bytes != null:
		f.store_line("  Memoria estática: %.2f MB" % (float(mem_bytes) / 1048576.0))
	else:
		f.store_line("  Memoria: no disponible en este entorno")


func _escribir_comparativa(f: FileAccess) -> void:
	f.store_line("Comparativa jugador quieto vs en movimiento")
	if muestras_a.is_empty() or muestras_b.is_empty():
		f.store_line("  Datos insuficientes.")
		return
	var sa = _stats(muestras_a)
	var sb = _stats(muestras_b)
	f.store_line("  FPS promedio: A=%.2f  B=%.2f  (B-A=%.2f)" % [sa.avg_fps, sb.avg_fps, sb.avg_fps - sa.avg_fps])
	f.store_line("  FPS mínimo: A=%.2f  B=%.2f" % [sa.min_fps, sb.min_fps])
	f.store_line("  1%% low: A=%.2f  B=%.2f" % [sa.low1, sb.low1])
	f.store_line("  Tiempo promedio frame: A=%.3f ms  B=%.3f ms" % [sa.avg_ms, sb.avg_ms])
	f.store_line("  Peor frame: A=%.3f ms  B=%.3f ms" % [sa.max_ms, sb.max_ms])
	f.store_line("  Tirones >16.67ms: A=%d  B=%d" % [sa.st16, sb.st16])
	f.store_line("  Tirones >33.33ms: A=%d  B=%d" % [sa.st33, sb.st33])
	f.store_line("  Tirones >50ms: A=%d  B=%d" % [sa.st50, sb.st50])
	f.store_line("  Tirones >100ms: A=%d  B=%d" % [sa.st100, sb.st100])


func _stats(muestras: Array) -> Dictionary:
	if muestras.is_empty():
		return {"avg_fps": 0.0, "min_fps": 0.0, "max_ms": 0.0, "avg_ms": 0.0, "st16": 0, "st33": 0, "st50": 0, "st100": 0, "low1": 0.0}
	var suma_fps := 0.0
	var suma_ms := 0.0
	var min_fps := INF
	var max_ms := 0.0
	var st16 := 0
	var st33 := 0
	var st50 := 0
	var st100 := 0
	var ms_vals: Array[float] = []
	for m in muestras:
		var fps := float(m.fps)
		var ms := float(m.ms)
		suma_fps += fps
		suma_ms += ms
		if fps < min_fps: min_fps = fps
		if ms > max_ms: max_ms = ms
		if ms > 16.67: st16 += 1
		if ms > 33.33: st33 += 1
		if ms > 50.0: st50 += 1
		if ms > 100.0: st100 += 1
		ms_vals.append(ms)
	ms_vals.sort()
	var idx99 := clampi(int(ceil(float(ms_vals.size()) * 0.99)) - 1, 0, ms_vals.size() - 1)
	var ms_p99 := ms_vals[idx99]
	return {
		"avg_fps": suma_fps / muestras.size(),
		"min_fps": min_fps,
		"avg_ms": suma_ms / muestras.size(),
		"max_ms": max_ms,
		"st16": st16,
		"st33": st33,
		"st50": st50,
		"st100": st100,
		"low1": (1000.0 / ms_p99) if ms_p99 > 0.0 else 0.0,
	}

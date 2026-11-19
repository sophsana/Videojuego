extends Node

const DatosMundo = preload("res://script/sistemas/datos_mundo.gd")
const Dimensiones = preload("res://script/sistemas/dimensiones_mundo.gd")
const DIRECTORIO := "user://mundos"
const ESCENA_MUNDO := "res://escenas/mundo.tscn"
const ESCENA_CARGA := "res://escenas/interfaz/carga_mundo.tscn"

var mundo_actual: Dictionary = {}
var ultimo_error := ""


func listar_mundos() -> Array[Dictionary]:
	ultimo_error = ""
	var mundos: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(DIRECTORIO):
		return mundos
	var directorio := DirAccess.open(DIRECTORIO)
	if directorio == null:
		ultimo_error = "No se pueden leer los mundos guardados."
		return mundos
	if directorio.list_dir_begin() != OK:
		ultimo_error = "No se puede listar la carpeta de mundos."
		return mundos
	var archivo := directorio.get_next()
	while not archivo.is_empty():
		if not directorio.current_is_dir() and archivo.ends_with(".json"):
			var datos := _leer_mundo(DIRECTORIO.path_join(archivo))
			if not datos.is_empty():
				mundos.append(datos)
			else:
				ultimo_error = "Algunos mundos no se pudieron leer."
		archivo = directorio.get_next()
	directorio.list_dir_end()
	mundos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.nombre.nocasecmp_to(b.nombre) < 0)
	return mundos


func crear_mundo(nombre: String, semilla: int, dificultad: String) -> Dictionary:
	ultimo_error = ""
	nombre = nombre.strip_edges()
	if nombre.is_empty() or nombre.length() > DatosMundo.LONGITUD_NOMBRE:
		ultimo_error = "Escribe un nombre de entre 1 y 32 caracteres."
		return {}
	if semilla < DatosMundo.SEMILLA_MINIMA or semilla > DatosMundo.SEMILLA_MAXIMA or dificultad not in DatosMundo.DIFICULTADES:
		ultimo_error = "La semilla o la dificultad no son válidas."
		return {}
	var existentes := listar_mundos()
	if not ultimo_error.is_empty():
		ultimo_error = "No se puede comprobar si el nombre ya existe. " + ultimo_error
		return {}
	for mundo in existentes:
		if mundo.nombre.to_lower() == nombre.to_lower():
			ultimo_error = "Ya existe un mundo con ese nombre."
			return {}
	var error := DirAccess.make_dir_recursive_absolute(DIRECTORIO)
	if error != OK:
		ultimo_error = "No se pudo crear la carpeta de mundos (error %d)." % error
		return {}
	# El nombre nunca se usa como ruta. La reserva de directorio impide que
	# dos procesos que obtengan el mismo identificador escriban el mismo archivo.
	var id := ""
	for intento in range(10):
		id = "%d_%08x%08x" % [int(Time.get_unix_time_from_system()), randi(), randi()]
		if FileAccess.file_exists(DIRECTORIO.path_join(id + ".json")):
			id = ""
			continue
		var reserva := DIRECTORIO.path_join(id + ".lock")
		if DirAccess.make_dir_absolute(reserva) == OK:
			if FileAccess.file_exists(DIRECTORIO.path_join(id + ".json")):
				DirAccess.remove_absolute(reserva)
				id = ""
				continue
			break
		id = ""
	if id.is_empty():
		ultimo_error = "No se pudo asignar un identificador único."
		return {}
	var datos := {"id": id, "nombre": nombre, "semilla": semilla, "dificultad": dificultad, "fecha_creacion": Time.get_datetime_string_from_system(), "fecha_ultimo_guardado": "", "tamano_tile": Dimensiones.TILE_SIZE, "progreso": {"jugador": {}, "cambios_mundo": {}}}
	var ruta := DIRECTORIO.path_join(id + ".json")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		ultimo_error = "No se pudo guardar el mundo (error %d)." % FileAccess.get_open_error()
		DirAccess.remove_absolute(DIRECTORIO.path_join(id + ".lock"))
		return {}
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.flush()
	if archivo.get_error() != OK:
		ultimo_error = "No se pudo escribir el mundo (error %d)." % archivo.get_error()
		archivo.close()
		DirAccess.remove_absolute(ruta)
		DirAccess.remove_absolute(DIRECTORIO.path_join(id + ".lock"))
		return {}
	archivo.close()
	DirAccess.remove_absolute(DIRECTORIO.path_join(id + ".lock"))
	return datos


func iniciar_mundo(datos: Dictionary) -> Error:
	if datos.get("tamano_tile", Dimensiones.TILE_SIZE_ANTERIOR) == Dimensiones.TILE_SIZE_ANTERIOR and not datos.get("progreso", {}).get("cambios_mundo", {}).is_empty():
		ultimo_error = "Este mundo antiguo contiene cambios que no se pueden migrar automáticamente."
		return ERR_INVALID_DATA
	mundo_actual = datos.duplicate(true)
	var error := get_tree().change_scene_to_file(ESCENA_CARGA)
	if error != OK:
		mundo_actual = {}
		ultimo_error = "No se pudo iniciar el mundo (error %d)." % error
	return error


func guardar_progreso(posicion: Vector2) -> bool:
	ultimo_error = ""
	if mundo_actual.is_empty() or not mundo_actual.get("id") is String:
		ultimo_error = "No hay un mundo guardado seleccionado."
		return false
	var id: String = mundo_actual.id
	# Nunca aceptar rutas, incluso si los datos en memoria fueron alterados.
	if not _id_valido(id) or not is_finite(posicion.x) or not is_finite(posicion.y) or posicion.x < 0 or posicion.x >= Dimensiones.WORLD_SIZE or posicion.y < 0 or posicion.y >= Dimensiones.WORLD_SIZE:
		ultimo_error = "El identificador o la posición no son válidos."
		return false
	var ruta := DIRECTORIO.path_join(id + ".json")
	var existente := _leer_mundo(ruta)
	if existente.is_empty() or existente.id != id:
		ultimo_error = "No se puede leer el último guardado válido."
		return false
	var datos := existente.duplicate(true)
	var progreso: Dictionary = datos.get("progreso", {}).duplicate(true)
	progreso["jugador"] = {"posicion": {"x": posicion.x, "y": posicion.y}}
	if not progreso.has("cambios_mundo"):
		progreso["cambios_mundo"] = {}
	datos["progreso"] = progreso
	datos["tamano_tile"] = Dimensiones.TILE_SIZE
	datos["fecha_ultimo_guardado"] = Time.get_datetime_string_from_system()
	# Archivo temporal independiente en el mismo directorio; el original no se
	# toca hasta que se han escrito y validado todos los datos.
	var temporal := DIRECTORIO.path_join(".%s_%08x.tmp" % [id, randi()])
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		ultimo_error = "No se pudo abrir el archivo temporal (error %d)." % FileAccess.get_open_error()
		return false
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.flush()
	var error := archivo.get_error()
	archivo.close()
	if error != OK:
		DirAccess.remove_absolute(temporal)
		ultimo_error = "No se pudo escribir el guardado (error %d)." % error
		return false
	# rename reemplaza atómicamente en sistemas compatibles; si falla, el
	# original permanece intacto y se ofrece reintentar.
	error = DirAccess.rename_absolute(temporal, ruta)
	if error != OK:
		DirAccess.remove_absolute(temporal)
		ultimo_error = "No se pudo reemplazar el guardado anterior (error %d)." % error
		return false
	mundo_actual = datos
	return true


func _id_valido(id: String) -> bool:
	return not id.is_empty() and id.length() <= 80 and id.validate_filename() == id and "/" not in id and "\\" not in id and id != "." and id != ".."


func _leer_mundo(ruta: String) -> Dictionary:
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {}
	var json := JSON.new()
	if json.parse(archivo.get_as_text()) != OK or not json.data is Dictionary:
		return {}
	var datos: Dictionary = json.data
	if not datos.get("id") is String or not _id_valido(datos.id) or datos.id != ruta.get_file().get_basename():
		return {}
	if not datos.get("nombre") is String or datos.nombre.strip_edges().is_empty() or datos.nombre.length() > DatosMundo.LONGITUD_NOMBRE:
		return {}
	if not datos.get("dificultad") in DatosMundo.DIFICULTADES:
		return {}
	var semilla = datos.get("semilla")
	if not (semilla is int or semilla is float) or float(semilla) != floor(float(semilla)):
		return {}
	if semilla < DatosMundo.SEMILLA_MINIMA or semilla > DatosMundo.SEMILLA_MAXIMA:
		return {}
	datos.semilla = int(semilla)
	if not datos.get("fecha_creacion", "") is String:
		return {}
	if not datos.get("fecha_ultimo_guardado", "") is String:
		return {}
	var progreso = datos.get("progreso", {})
	if not progreso is Dictionary:
		return {}
	var jugador = progreso.get("jugador", {})
	if not jugador is Dictionary or not progreso.get("cambios_mundo", {}) is Dictionary:
		return {}
	var tamano = datos.get("tamano_tile", Dimensiones.TILE_SIZE_ANTERIOR)
	if not (tamano is int or tamano is float) or (tamano != Dimensiones.TILE_SIZE_ANTERIOR and tamano != Dimensiones.TILE_SIZE):
		return {}
	if datos.has("tamano_tile"):
		datos.tamano_tile = int(tamano)
	if jugador.has("posicion"):
		var posicion = jugador.posicion
		if not posicion is Dictionary or not (posicion.get("x") is int or posicion.get("x") is float) or not (posicion.get("y") is int or posicion.get("y") is float):
			return {}
		var limite: int = Dimensiones.MAP_SIZE * int(tamano)
		if not is_finite(float(posicion.x)) or not is_finite(float(posicion.y)) or float(posicion.x) < 0 or float(posicion.x) >= limite or float(posicion.y) < 0 or float(posicion.y) >= limite:
			return {}
	return datos

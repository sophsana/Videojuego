extends SceneTree

const Dimensiones = preload("res://script/sistemas/dimensiones_mundo.gd")
var fallos := 0


func _initialize() -> void:
	call_deferred("probar")


func comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		fallos += 1
		printerr("FALLO: ", mensaje)


func probar() -> void:
	comprobar(Dimensiones.TILE_SIZE == 32 and Dimensiones.WORLD_SIZE == 8192, "dimensiones")
	var escena: PackedScene = load("res://escenas/player.tscn")
	var player = escena.instantiate()
	var contenedor := Node2D.new()
	root.add_child(contenedor)
	contenedor.add_child(player)
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	for direccion in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		player._actualizar_animacion(direccion)
		var nombre: String = player.ultima_direccion
		comprobar(sprite.animation == "walk_" + nombre, "caminar " + nombre)
		comprobar(sprite.flip_h == (nombre == "right"), "inversión " + nombre)
		player._actualizar_animacion(Vector2.ZERO)
		comprobar(sprite.animation == "idle_" + nombre, "reposo " + nombre)
	player.global_position = Vector2(-1, 8193)
	player.wrap_position()
	comprobar(player.global_position == Vector2(8191, 1), "wrap")
	contenedor.queue_free()
	var gestor = root.get_node("GestorMundos")
	var datos: Dictionary = gestor.crear_mundo("Migracion_" + str(Time.get_ticks_usec()), 123, "Normal")
	var ruta: String = "user://mundos".path_join(datos.id + ".json")
	datos.erase("tamano_tile")
	datos.progreso.jugador = {"posicion": {"x": 123.0, "y": 456.0}}
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(datos))
	archivo.close()
	var antiguo: Dictionary = gestor._leer_mundo(ruta)
	comprobar(not antiguo.is_empty(), "leer guardado antiguo")
	gestor.mundo_actual = antiguo
	var mundo = load("res://escenas/mundo.tscn").instantiate()
	mundo.world_seed = 123
	mundo.setup_noise()
	mundo.setup_terrain()
	comprobar(mundo.terrain_layer.tile_set.tile_size == Vector2i(32, 32), "tileset 32")
	var fuente: TileSetAtlasSource = mundo.terrain_layer.tile_set.get_source(0)
	comprobar(fuente.get_tiles_count() == 9, "variantes del pasto")
	var terreno: int = mundo.get_terrain(42, 20)
	var otro = load("res://escenas/mundo.tscn").instantiate()
	otro.world_seed = 123
	otro.setup_noise()
	comprobar(otro.get_terrain(42, 20) == terreno, "semilla reproducible")
	otro.free()
	mundo.create_player()
	comprobar(mundo.get_node("Player").position == Vector2(246, 912), "posición antigua escalada")
	comprobar(gestor.guardar_progreso(Vector2(6000, 7000)), "guardar coordenadas nuevas")
	var nuevo: Dictionary = gestor._leer_mundo(ruta)
	comprobar(nuevo.get("tamano_tile") == 32 and nuevo.progreso.jugador.posicion.x == 6000, "formato nuevo")
	mundo.free()
	DirAccess.remove_absolute(ruta)
	print("Mundo 32 y astronauta: ", "OK" if fallos == 0 else "%d fallos" % fallos)
	quit(0 if fallos == 0 else 1)

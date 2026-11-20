extends SceneTree

const Dimensiones = preload("res://script/sistemas/dimensiones_mundo.gd")
var fallos := 0


func _initialize() -> void:
	call_deferred("probar")


func mando_juego_x_de_roca(mundo) -> int:
	var rock_x := -1
	for y in range(mundo.MAP_SIZE):
		for x in range(mundo.MAP_SIZE):
			if mundo.get_terrain(x, y) == mundo.ROCK:
				rock_x = x
	if rock_x >= 0:
		return rock_x
	for i in range(10000):
		var rx := randi_range(0, mundo.MAP_SIZE - 1)
		var ry := randi_range(0, mundo.MAP_SIZE - 1)
		if mundo.get_terrain(rx, ry) == mundo.ROCK:
			return rx
	return mundo.MAP_SIZE / 2

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
	player.update_depth()
	comprobar(is_equal_approx(sprite.position.y, -3.2), "apoyo lateral en reposo")
	var mundo_rock = load("res://escenas/mundo.tscn").instantiate()
	mundo_rock.world_seed = 123
	mundo_rock.setup_noise()
	mundo_rock.setup_terrain()
	var rock_x := mando_juego_x_de_roca(mundo_rock)
	mundo_rock.terreno_cache = PackedByteArray()
	mundo_rock.terreno_visual = PackedByteArray()
	for y in range(mundo_rock.MAP_SIZE):
		for x in range(mundo_rock.MAP_SIZE):
			mundo_rock.terreno_cache.append(mundo_rock.ROCK)
			mundo_rock.terreno_visual.append(mundo_rock.ROCK)
	mundo_rock.terrain_layer.set_cell(Vector2i(rock_x, 0), 0, Vector2i(mundo_rock.ATLAS_ROCA, 0))
	root.get_node("GestorMundos").mundo_actual = {"id": "prueba_profundidad", "nombre": "Prueba", "semilla": 123, "dificultad": "Normal", "tamano_tile": 32, "progreso": {"jugador": {"posicion": {"x": rock_x * 32.0 + 16.0, "y": 0.0}}}}
	var mundo_rock_player = mundo_rock.create_player() as CharacterBody2D
	comprobar(mundo_rock_player != null and mundo_rock_player.has_node("AnimatedSprite2D"), "crear jugador")
	if mundo_rock_player != null:
		mundo_rock_player.world = mundo_rock
		mundo_rock_player.sprite = mundo_rock_player.get_node("AnimatedSprite2D") as AnimatedSprite2D
		mundo_rock_player.update_depth()
		var mundo_rock_sprite = mundo_rock_player.get_node("AnimatedSprite2D") as AnimatedSprite2D
		comprobar(mundo_rock_sprite.z_index == -1 and mundo_rock_sprite.position.y == -10.0, "sobrepone al jugador tras roca")
		comprobar(mundo_rock.terrain_layer.z_index == -2, "terreno detrás de recursos y jugador")
	mundo_rock.free()

	player.global_position = Vector2(-1, 8193)
	player.wrap_position()
	comprobar(player.global_position == Vector2(8191, 1), "wrap")
	# El reposo solo se anima de vez en cuando, no de forma continua.
	player.velocity = Vector2.ZERO
	player.reposo_activo = false
	player.espera_reposo = 0.01
	player._actualizar_reposo(0.02, Vector2.ZERO)
	comprobar(player.reposo_activo and sprite.is_playing(), "ráfaga de reposo")
	player._terminar_reposo(sprite.animation)
	comprobar(not player.reposo_activo and not sprite.is_playing() and sprite.frame == 0, "reposo se detiene")
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
	comprobar(fuente.get_tiles_count() == mundo.ATLAS_CANTIDAD, "variantes del terreno")
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

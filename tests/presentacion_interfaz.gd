extends SceneTree

var errores := 0


func _initialize() -> void:
	call_deferred("probar")


func comprobar(condicion: bool, detalle: String) -> void:
	if not condicion:
		errores += 1
		printerr("FALLO: ", detalle)


func probar() -> void:
	change_scene_to_file("res://escenas/interfaz/menu_principal.tscn")
	await process_frame
	await process_frame
	var contenido := current_scene.get_node("Centro/Contenido")
	var jugar: Control = contenido.get_node("Jugar")
	var opciones: Control = contenido.get_node("Opciones")
	var salir: Control = contenido.get_node("Salir")
	comprobar(is_equal_approx(jugar.size.x, opciones.size.x) and is_equal_approx(jugar.size.x, salir.size.x), "ancho uniforme")
	comprobar(is_equal_approx(jugar.position.x, opciones.position.x) and is_equal_approx(jugar.position.x, salir.position.x), "centrado horizontal")
	comprobar(is_equal_approx(opciones.position.y - jugar.position.y - jugar.size.y, salir.position.y - opciones.position.y - opciones.size.y), "separación uniforme")
	var fuente := ThemeDB.get_project_theme().default_font
	comprobar(fuente != null and fuente.has_char(0x00e9) and fuente.has_char(0x00ed), "fuente con caracteres españoles")
	var escena: PackedScene = load("res://escenas/interfaz/carga_mundo.tscn")
	var carga = escena.instantiate()
	# Instanciar sin _ready evita iniciar otra carga asíncrona.
	carga.barra = TextureRect.new()
	carga.etiqueta = Label.new()
	for i in range(4):
		var textura: AtlasTexture = carga._textura_barra(i)
		comprobar(textura.region == carga.REGIONES[i], "región de barra %d" % i)
	carga._actualizar(99.0, "Generando")
	comprobar(carga.indice_objetivo == 2 and carga.porcentaje == 99.0, "sin 100 prematuro")
	carga._actualizar(50.0, "Generando")
	comprobar(carga.indice_objetivo == 2 and carga.porcentaje == 99.0, "sin retroceso")
	carga._actualizar(100.0, "Mundo preparado")
	comprobar(carga.indice_objetivo == 3, "último fotograma")
	carga.barra.free()
	carga.etiqueta.free()
	carga.free()
	print("Presentación de interfaz: ", "OK" if errores == 0 else "%d fallos" % errores)
	quit(0 if errores == 0 else 1)

extends RefCounted

const MUNDOS = preload("res://recursos_interfaz/botones/botones_mundos.png")
const VOLVER = preload("res://recursos_interfaz/botones/boton_volver.png")
const BUSQUEDA = preload("res://recursos_interfaz/botones/barra_de_busqueda.png")
const ENTRADA = preload("res://recursos_interfaz/botones/barra_ingresar datos.png")
const DIFICULTAD = preload("res://recursos_interfaz/botones/botones_dificultad.png")
const CONTENEDOR = preload("res://recursos_interfaz/botones/contenedor.png")


static func atlas(imagen: Texture2D, region: Rect2) -> AtlasTexture:
	var textura := AtlasTexture.new()
	textura.atlas = imagen
	textura.region = region
	return textura


static func boton(imagen: Texture2D, regiones: Array[Rect2], tamano: Vector2) -> TextureButton:
	var resultado := TextureButton.new()
	resultado.texture_normal = atlas(imagen, regiones[0])
	resultado.texture_hover = atlas(imagen, regiones[1])
	resultado.texture_pressed = atlas(imagen, regiones[2])
	resultado.ignore_texture_size = true
	resultado.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	resultado.custom_minimum_size = tamano
	resultado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return resultado


static func boton_crear() -> TextureButton:
	return boton(MUNDOS, [Rect2(0, 150, 360, 110), Rect2(360, 150, 360, 110), Rect2(720, 150, 360, 110)], Vector2(260, 80))


static func boton_volver() -> TextureButton:
	return boton(VOLVER, [Rect2(0, 115, 360, 115), Rect2(360, 115, 360, 115), Rect2(720, 115, 360, 115)], Vector2(250, 80))


static func boton_mundo() -> TextureButton:
	return boton(MUNDOS, [Rect2(0, 300, 360, 110), Rect2(360, 300, 360, 110), Rect2(720, 300, 360, 110)], Vector2(360, 110))


static func boton_dificultad(indice: int) -> TextureButton:
	var x := indice * 360
	var resultado := boton(DIFICULTAD, [Rect2(x, 0, 360, 120), Rect2(x, 120, 360, 120), Rect2(x, 240, 360, 120)], Vector2(160, 54))
	# La hoja disponible tiene tres estados por dificultad, no seis. La fila
	# luminosa identifica la selección persistente; la oscura es el clic físico.
	resultado.texture_pressed = atlas(DIFICULTAD, Rect2(x, 120, 360, 120))
	resultado.button_down.connect(func():
		resultado.texture_pressed = atlas(DIFICULTAD, Rect2(x, 240, 360, 120))
	)
	resultado.button_up.connect(func():
		resultado.texture_pressed = atlas(DIFICULTAD, Rect2(x, 120, 360, 120))
	)
	resultado.toggle_mode = true
	return resultado


static func entrada(busqueda: bool, placeholder: String) -> Control:
	var raiz := Control.new()
	raiz.custom_minimum_size = Vector2(480, 68)
	var imagen := TextureRect.new()
	var recurso: Texture2D = BUSQUEDA if busqueda else ENTRADA
	var x := 165 if busqueda else 190
	var ancho := 690
	var y := 8 if busqueda else 12
	var normal := atlas(recurso, Rect2(x, y, ancho, 102))
	var foco := atlas(recurso, Rect2(x, y + 116, ancho, 102))
	imagen.texture = normal
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(imagen)
	var campo := LineEdit.new()
	campo.name = "Campo"
	campo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	campo.anchor_left = 0.25 if busqueda else 0.28
	campo.anchor_right = 0.84
	campo.anchor_top = 0.21
	campo.anchor_bottom = 0.79
	campo.offset_left = 0
	campo.offset_right = 0
	campo.offset_top = 0
	campo.offset_bottom = 0
	campo.placeholder_text = placeholder
	campo.clear_button_enabled = false
	campo.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	campo.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	campo.add_theme_font_size_override("font_size", 17)
	campo.focus_entered.connect(func(): imagen.texture = foco)
	campo.focus_exited.connect(func(): imagen.texture = normal)
	raiz.add_child(campo)
	return raiz

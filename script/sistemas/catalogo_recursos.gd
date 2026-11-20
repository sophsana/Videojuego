extends RefCounted

# Cada hoja de vegetación contiene 6 celdas de 180×360; el espacio vacío
# de cada celda se recorta usando la caja común de sus seis fotogramas.
# Las imágenes se reducen dos pasos para conservar un aspecto pixel art.
const ARBOLES := [
	{"ruta": "res://assets/recursos/arbol_animado1.png", "peso": 15, "ancho": 96},
	{"ruta": "res://assets/recursos/arbol_animado_2.png", "peso": 70, "ancho": 72},
	{"ruta": "res://assets/recursos/arbol_animado3.png", "peso": 15, "ancho": 48},
]
const ARBUSTOS := [
	{"ruta": "res://assets/recursos/arbusto_animado1.png", "ancho": 44},
	{"ruta": "res://assets/recursos/arbusto_animado2_con_frutos.png", "vacio": "res://assets/recursos/arbusto_animado2_sin_frutos.png", "ancho": 40, "cosechable": true, "frutos": 2, "item_id": "fruto_alienigena", "item_nombre": "Fruto alienígena"},
]
const ROCAS := "res://assets/recursos/roca_grupo.png"
const PESOS_ROCAS := [25, 12, 22, 12, 10, 19]
const PESOS_ARBOLES := [30, 85, 15]
const ANCHOS_ROCAS := [28, 38, 32, 36, 42, 32]
const FACTOR_PIXEL := 3


static func elegir_indice(pesos: Array, valor: float) -> int:
	var total := 0.0
	for peso in pesos:
		total += float(peso)
	var restante := valor * total
	for i in range(pesos.size()):
		restante -= float(pesos[i])
		if restante < 0:
			return i
	return pesos.size() - 1


static func _pixelizar(imagen: Image, tamano: Vector2i) -> Image:
	var resultado := imagen.duplicate() as Image
	resultado.convert(Image.FORMAT_RGBA8)
	var pequeno := Vector2i(
		maxi(1, tamano.x / FACTOR_PIXEL),
		maxi(1, tamano.y / FACTOR_PIXEL)
	)
	resultado.resize(pequeno.x, pequeno.y, Image.INTERPOLATE_NEAREST)
	resultado.resize(tamano.x, tamano.y, Image.INTERPOLATE_NEAREST)
	return resultado


static func fotogramas(ruta: String, recorte: Rect2i = Rect2i()) -> SpriteFrames:
	var textura := load(ruta) as Texture2D
	if textura == null:
		return null
	var imagen := textura.get_image()
	var union := Rect2i()
	for i in range(6):
		var celda := imagen.get_region(Rect2i(i * 180, 0, 180, 360))
		var rect := celda.get_used_rect()
		union = rect if union.size == Vector2i.ZERO else union.merge(rect)
	if recorte.size != Vector2i.ZERO:
		union = recorte
	var frames := SpriteFrames.new()
	frames.add_animation("viento")
	frames.set_animation_speed("viento", 5.0)
	for i in range(6):
		var region := Rect2i(union.position + Vector2i(i * 180, 0), union.size)
		var fotograma := _pixelizar(imagen.get_region(region), union.size)
		frames.add_frame("viento", ImageTexture.create_from_image(fotograma))
	return frames


static func roca(indice: int) -> AtlasTexture:
	var textura := load(ROCAS) as Texture2D
	var imagen := textura.get_image().get_region(Rect2i(indice * 180, 0, 180, 360))
	var rect := imagen.get_used_rect()
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = Rect2(rect.position + Vector2i(indice * 180, 0), rect.size)
	return atlas

extends RefCounted

const TILE := 32
const DIRECCIONES := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const MAR := "res://assets/terreno/mar_animado1.png"
const ORILLA := "res://assets/terreno/arena_orilla_animado.png"
const ARENA := "res://assets/terreno/arena_group1.png"
const PASTO := "res://assets/terreno/pasto_grupo1.png"
const TRANSICION := "res://assets/terreno/cesped_arena_group1.png"
const CELDAS_MAR := [Rect2i(10, 78, 171, 169), Rect2i(188, 78, 171, 169), Rect2i(366, 78, 171, 169), Rect2i(544, 78, 171, 169), Rect2i(722, 78, 171, 169), Rect2i(900, 78, 171, 169)]
const CELDAS_ORILLA := [Rect2i(47, 35, 234, 257), Rect2i(299, 35, 234, 257), Rect2i(551, 35, 234, 257), Rect2i(803, 35, 234, 257)]
const CELDAS_ARENA := [Rect2i(255, 25, 299, 308), Rect2i(598, 25, 299, 308)]
const CELDAS_PASTO := [Rect2i(56, 16, 289, 309), Rect2i(392, 16, 289, 309), Rect2i(736, 16, 289, 309)]
const CELDAS_TRANSICION := [Rect2i(100, 40, 530, 560), Rect2i(715, 40, 530, 560), Rect2i(1340, 40, 530, 560)]


static func preparar_imagen(ruta: String, region: Rect2i, fondo: Color, eliminar_negro := false) -> Image:
	var textura := load(ruta) as Texture2D
	var imagen := textura.get_image().get_region(region)
	imagen.convert(Image.FORMAT_RGBA8)
	if eliminar_negro:
		# El archivo de transición es RGB; el negro exterior no es transparencia.
		for y in range(imagen.get_height()):
			for x in range(imagen.get_width()):
				var color := imagen.get_pixel(x, y)
				if color.r < 0.035 and color.g < 0.035 and color.b < 0.035:
					imagen.set_pixel(x, y, Color.TRANSPARENT)
	imagen.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	var base := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	base.fill(fondo)
	base.blend_rect(imagen, Rect2i(0, 0, TILE, TILE), Vector2i.ZERO)
	return base


static func rotar(imagen: Image, cuartos: int) -> Image:
	var resultado := imagen.duplicate() as Image
	for i in range(cuartos):
		resultado.rotate_90(CLOCKWISE)
	return resultado


static func elegir_borde(vecinos: Array, objetivo: Array) -> int:
	# El mar/arena de las hojas está a la derecha. Se evita usar una transición
	# recta en esquinas o canales sin una dirección inequívoca.
	var encontrado := -1
	for i in range(DIRECCIONES.size()):
		if vecinos[i] in objetivo:
			if encontrado >= 0:
				return -1
			encontrado = i
	return encontrado

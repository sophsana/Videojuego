extends RefCounted

const TILE := 32
const DIRECCIONES := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const MAR := "res://assets/terreno/mar_animado1.png"
const ARENA_AGUA := "res://assets/terreno/arena_agua.png"
const ARENA := "res://assets/terreno/arena_group1.png"
const PASTO := "res://assets/terreno/pasto_grupo1.png"
const TRANSICION := "res://assets/terreno/cesped_arena_group1.png"
const CELDAS_MAR := [Rect2i(10, 78, 171, 169), Rect2i(188, 78, 171, 169), Rect2i(366, 78, 171, 169), Rect2i(544, 78, 171, 169), Rect2i(722, 78, 171, 169), Rect2i(900, 78, 171, 169)]
const CELDAS_ARENA_AGUA := [Rect2i(45, 30, 285, 285), Rect2i(795, 25, 265, 285)]
const CELDAS_ARENA := [Rect2i(255, 25, 299, 308), Rect2i(598, 25, 299, 308)]
const CELDAS_PASTO := [Rect2i(56, 16, 289, 309), Rect2i(392, 16, 289, 309), Rect2i(736, 16, 289, 309)]
const CELDAS_TRANSICION := [Rect2i(0, 0, 724, 724), Rect2i(724, 0, 724, 724), Rect2i(1448, 0, 724, 724)]


static func preparar_imagen(ruta: String, region: Rect2i, fondo: Color, eliminar_negro := false, margen_interno := 0.02) -> Image:
	# Las hojas individuales no son sin costuras y cada dibujo ocupa una zona
	# distinta dentro de su celda. Se detecta el contenido real, se recorta en
	# cuadrado y se amplía para llenar la baldosa sin líneas oscuras repetidas.
	var textura := load(ruta) as Texture2D
	var original := textura.get_image()
	var recorte := original.get_region(region)
	recorte.convert(Image.FORMAT_RGBA8)
	var muestra := recorte.duplicate() as Image
	var factor := maxi(1, maxi(muestra.get_width(), muestra.get_height()) / 64)
	muestra.resize(maxi(1, muestra.get_width() / factor), maxi(1, muestra.get_height() / factor), Image.INTERPOLATE_NEAREST)
	if eliminar_negro:
		_quitar_negro(muestra)
	var usado := muestra.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		usado = Rect2i(0, 0, muestra.get_width(), muestra.get_height())
	var escala_x := float(recorte.get_width()) / muestra.get_width()
	var escala_y := float(recorte.get_height()) / muestra.get_height()
	var usado_original := Rect2i(
		Vector2i(floori(usado.position.x * escala_x), floori(usado.position.y * escala_y)),
		Vector2i(ceili(usado.size.x * escala_x), ceili(usado.size.y * escala_y))
	)
	var lado := mini(usado_original.size.x, usado_original.size.y)
	var margen := maxi(1, int(lado * margen_interno))
	lado = maxi(1, lado - margen * 2)
	var centro := usado_original.position + usado_original.size / 2
	var inicio := centro - Vector2i(lado / 2, lado / 2)
	inicio.x = clampi(inicio.x, 0, recorte.get_width() - lado)
	inicio.y = clampi(inicio.y, 0, recorte.get_height() - lado)
	var imagen := recorte.get_region(Rect2i(inicio, Vector2i(lado, lado)))
	imagen.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	if eliminar_negro:
		_quitar_negro(imagen)
	# Las hojas tienen hendiduras transparentes entre lóbulos; rellenarlas
	# evita huecos negros y líneas vacías entre baldosas.
	_rellenar_bordes(imagen)
	var base := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	base.fill(fondo)
	base.blend_rect(imagen, Rect2i(0, 0, TILE, TILE), Vector2i.ZERO)
	return base


static func _quitar_negro(imagen: Image) -> void:
	for y in range(imagen.get_height()):
		for x in range(imagen.get_width()):
			var color := imagen.get_pixel(x, y)
			if color.r < 0.12 and color.g < 0.12 and color.b < 0.12:
				imagen.set_pixel(x, y, Color.TRANSPARENT)


static func _rellenar_bordes(imagen: Image) -> void:
	var ancho := imagen.get_width()
	var alto := imagen.get_height()
	for y in range(alto):
		for x in range(ancho):
			if imagen.get_pixel(x, y).a <= 0.85:
				imagen.set_pixel(x, y, Color.TRANSPARENT)
	# Reflejar el borde en lugar de estirar una sola columna: conserva la textura
	# y evita tanto las líneas oscuras como las franjas planas entre baldosas.
	for y in range(alto):
		var primero := -1
		var ultimo := -1
		for x in range(ancho):
			if imagen.get_pixel(x, y).a > 0.85:
				if primero < 0:
					primero = x
				ultimo = x
		if primero >= 0:
			for x in range(primero):
				imagen.set_pixel(x, y, imagen.get_pixel(mini(primero + (primero - x), ancho - 1), y))
			for x in range(ultimo + 1, ancho):
				imagen.set_pixel(x, y, imagen.get_pixel(maxi(ultimo - (x - ultimo), 0), y))
	for x in range(ancho):
		var primero := -1
		var ultimo := -1
		for y in range(alto):
			if imagen.get_pixel(x, y).a > 0.85:
				if primero < 0:
					primero = y
				ultimo = y
		if primero >= 0:
			for y in range(primero):
				imagen.set_pixel(x, y, imagen.get_pixel(x, mini(primero + (primero - y), alto - 1)))
			for y in range(ultimo + 1, alto):
				imagen.set_pixel(x, y, imagen.get_pixel(x, maxi(ultimo - (y - ultimo), 0)))
	# Rellenar hendiduras interiores que sigan transparentes.
	for y in range(alto):
		var ultimo := Color.TRANSPARENT
		for x in range(ancho):
			var color := imagen.get_pixel(x, y)
			if color.a > 0.85:
				ultimo = color
			elif ultimo.a > 0.85:
				imagen.set_pixel(x, y, ultimo)
		ultimo = Color.TRANSPARENT
		for x in range(ancho - 1, -1, -1):
			var color := imagen.get_pixel(x, y)
			if color.a > 0.85:
				ultimo = color
			elif ultimo.a > 0.85:
				imagen.set_pixel(x, y, ultimo)


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


static func indice_par(vecinos: Array, objetivo: Array) -> int:
	# pares: derecha+abajo, abajo+izquierda, izquierda+arriba, arriba+derecha.
	var pares: Array[Array] = [[0, 1], [1, 2], [2, 3], [3, 0]]
	for i in range(pares.size()):
		var par: Array = pares[i]
		if vecinos[par[0]] in objetivo and vecinos[par[1]] in objetivo:
			return i
	return -1


static func rotacion_esquina(vecinos: Array, objetivo: Array, base := 0) -> int:
	var par := indice_par(vecinos, objetivo)
	return posmod(par - base, 4) if par >= 0 else elegir_borde(vecinos, objetivo)


static func es_arena(color: Color) -> bool:
	return color.a > 0.1 and color.r > color.g + 0.03


static func unir_transiciones(primera: Image, segunda: Image) -> Image:
	# Une dos transiciones rectas para formar una esquina: la arena de ambos
	# lados se conserva y el resto queda como césped continuo.
	var resultado := primera.duplicate() as Image
	for y in range(TILE):
		for x in range(TILE):
			var a := primera.get_pixel(x, y)
			var b := segunda.get_pixel(x, y)
			if not es_arena(a) and es_arena(b):
				resultado.set_pixel(x, y, b)
	return resultado

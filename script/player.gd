extends CharacterBody2D

const Dimensiones = preload("res://script/sistemas/dimensiones_mundo.gd")
const TILE_SIZE: int = Dimensiones.TILE_SIZE
const MAP_SIZE: int = Dimensiones.MAP_SIZE
const WORLD_SIZE: int = Dimensiones.WORLD_SIZE

const DEEP_WATER: int = 0
const WATER: int = 1
const SAND: int = 2
const GRASS: int = 3
const DIRT: int = 4
const ROCK: int = 5

const RUN_MULT: float = 1.55
const SWIM_MULT: float = 0.45
const SWIM_RUN_MULT: float = 0.72
# Hambre por segundo según actividad (acumulada fraccionalmente).
const HAMBRE_NADO: float = 0.08
const HAMBRE_CORRER: float = 0.18

@export var walk_speed: float = 100.0
@export var acceleration: float = 600.0
@export var deceleration: float = 800.0

signal vida_cambiada(vida: int, vida_maxima: int)
signal hambre_cambiada(hambre: int, hambre_maxima: int)

var current_terrain: int = GRASS
var terrain_speed: float = 1.0
var world: Node2D
var ultima_direccion := "down"
var espera_reposo := 3.0
var reposo_activo := false
var vida_maxima := 20
var vida := 20
var hambre_maxima := 20
var hambre := 20
var hambre_acumulada: float = 0.0
var golpeando: bool = false
var tiempo_golpe: float = 0.0
var enfriamiento_golpe: float = 0.0
var offset_golpe: Vector2 = Vector2.ZERO
var animacion_golpeando: bool = false
var sonido_pasos: AudioStreamPlayer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	world = get_parent()
	if world != null and world.name == "Recursos":
		world = world.get_parent()
	_cargar_supervivencia()
	_asegurar_animaciones_nado()
	_asegurar_animaciones_golpe()
	_configurar_sonido_pasos()
	_actualizar_animacion(Vector2.ZERO, false, false)
	sprite.animation_finished.connect(_terminar_reposo)
	espera_reposo = randf_range(2.5, 6.0)
	# La profundidad se resuelve por Y-sort usando la posición de los pies.
	z_index = 0
	z_as_relative = true


func _physics_process(delta: float) -> void:
	if enfriamiento_golpe > 0.0:
		enfriamiento_golpe = maxf(0.0, enfriamiento_golpe - delta)
	if golpeando:
		tiempo_golpe -= delta
		if tiempo_golpe <= 0.0 and not animacion_golpeando:
			golpeando = false
			offset_golpe = Vector2.ZERO

	if Input.is_action_just_pressed("golpear") and enfriamiento_golpe <= 0.0 and not golpeando and not animacion_golpeando:
		_iniciar_golpe()

	if Input.is_action_just_pressed("interactuar"):
		if not _intentar_comer_seleccionado():
			if world != null and world.has_method("recolectar_cercano"):
				world.recolectar_cercano(global_position)
	update_terrain()

	var direction: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	var moviendose := direction != Vector2.ZERO
	var nadando := _esta_nadando()
	var quiere_correr := Input.is_action_pressed("correr")
	var corriendo := quiere_correr and moviendose

	var velocidad_base := walk_speed
	if nadando:
		velocidad_base = walk_speed * (SWIM_RUN_MULT if corriendo else SWIM_MULT)
		if current_terrain == DEEP_WATER and not corriendo:
			velocidad_base *= 0.85
	else:
		var factor := terrain_speed
		if corriendo:
			factor *= RUN_MULT
		velocidad_base = walk_speed * factor

	var target_velocity: Vector2 = direction * velocidad_base
	_actualizar_animacion(direction, nadando, corriendo)

	if moviendose:
		velocity = velocity.move_toward(
			target_velocity,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)

	move_and_slide()
	wrap_position()
	_actualizar_reposo(delta, direction, nadando)
	_actualizar_consumo_hambre(delta, nadando, corriendo, moviendose)
	_actualizar_sonido_pasos(moviendose, nadando)


func _intentar_comer_seleccionado() -> bool:
	if world == null:
		return false
	var inv = world.get("inventario")
	if inv == null or not inv.has_method("slot"):
		return false
	var sel: int = int(inv.seleccionado) if "seleccionado" in inv else -1
	var s = inv.slot(sel)
	if s == null:
		return false
	var id := String(s.get("id", ""))
	if id == "fruto_alienigena":
		if hambre >= hambre_maxima:
			return true
		var consumido := false
		if inv.has_method("quitar_en_slot"):
			consumido = inv.quitar_en_slot(sel, 1)
		else:
			var cant := int(s.get("cantidad", 0))
			if cant > 1:
				s["cantidad"] = cant - 1
			elif cant == 1:
				if inv.get("slots") is Array:
					inv.slots[sel] = null
			if inv.has_signal("cambiado"):
				inv.cambiado.emit()
			consumido = cant >= 1
		if consumido:
			aumentar_hambre(2)
		return true
	return false


func _configurar_sonido_pasos() -> void:
	sonido_pasos = AudioStreamPlayer.new()
	sonido_pasos.name = "SonidoPasos"
	sonido_pasos.bus = "Sonidos"
	add_child(sonido_pasos)


func _actualizar_sonido_pasos(moviendose: bool, nadando: bool) -> void:
	if sonido_pasos == null:
		return
	var en_pasto := moviendose and not nadando and current_terrain == GRASS
	if en_pasto:
		var stream: AudioStream = null
		var ga = get_node_or_null("/root/GestorAudio")
		if ga != null and ga.has_method("stream_caminata_cesped"):
			stream = ga.stream_caminata_cesped()
		elif ga != null:
			stream = ga.get("sfx_caminata_cesped")
		if stream != null:
			if sonido_pasos.stream != stream:
				sonido_pasos.stream = stream
			if not sonido_pasos.playing:
				sonido_pasos.play()
		else:
			if sonido_pasos.playing:
				sonido_pasos.stop()
	else:
		if sonido_pasos.playing:
			sonido_pasos.stop()


func _direccion_golpe() -> Vector2:
	match ultima_direccion:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN


func _iniciar_golpe() -> void:
	golpeando = true
	tiempo_golpe = 0.45
	enfriamiento_golpe = 0.5
	# Efecto visual de golpe (lunge ligero).
	var dir := _direccion_golpe()
	offset_golpe = dir * 3.0
	var tw := create_tween()
	tw.tween_property(self, "offset_golpe", Vector2.ZERO, 0.2)
	# Animación de golpe (sprite sheet).
	_reproducir_animacion_golpe()
	# Lógica de golpe y sonido según objetivo.
	var resultado := {}
	if world != null and world.has_method("golpear_cercano"):
		var r = world.golpear_cercano(global_position, ultima_direccion)
		if r is Dictionary:
			resultado = r
		elif r is bool and r:
			resultado = {"exito": true, "tipo": "generico"}
		else:
			resultado = {"exito": false, "tipo": ""}
	else:
		resultado = {"exito": false, "tipo": ""}
	var ga = get_node_or_null("/root/GestorAudio")
	if ga != null and ga.has_method("reproducir_golpe"):
		ga.reproducir_golpe(String(resultado.get("tipo", "")))


func _actualizar_reposo(delta: float, direccion: Vector2, nadando: bool) -> void:
	if nadando or direccion != Vector2.ZERO or velocity.length() > 1.0:
		if reposo_activo:
			sprite.stop()
			sprite.frame = 0
			reposo_activo = false
		espera_reposo = randf_range(2.5, 6.0)
		return
	if reposo_activo:
		return
	espera_reposo -= delta
	if espera_reposo > 0.0:
		return
	reposo_activo = true
	sprite.play("idle_" + ultima_direccion)
	espera_reposo = randf_range(3.0, 7.0)


func _terminar_reposo(nombre: StringName) -> void:
	if nombre != sprite.animation:
		return
	if String(nombre).begins_with("hit_"):
		animacion_golpeando = false
		golpeando = false
		offset_golpe = Vector2.ZERO
		sprite.stop()
		sprite.frame = 0
		return
	if not reposo_activo:
		return
	reposo_activo = false
	sprite.stop()
	sprite.frame = 0


func update_terrain() -> void:
	if not world.has_method("get_terrain"):
		terrain_speed = 1.0
		return

	var tile_x: int = posmod(
		floori(global_position.x / TILE_SIZE),
		MAP_SIZE
	)

	var tile_y: int = posmod(
		floori(global_position.y / TILE_SIZE),
		MAP_SIZE
	)

	current_terrain = world.get_terrain(tile_x, tile_y)

	match current_terrain:
		DEEP_WATER:
			terrain_speed = 0.0
		WATER:
			terrain_speed = 0.55
		SAND:
			terrain_speed = 0.80
		GRASS:
			terrain_speed = 1.0
		DIRT:
			terrain_speed = 0.90
		ROCK:
			terrain_speed = 0.50
		_:
			terrain_speed = 1.0


func wrap_position() -> void:
	var posicion_anterior := global_position
	global_position.x = fposmod(global_position.x, WORLD_SIZE)
	global_position.y = fposmod(global_position.y, WORLD_SIZE)
	if posicion_anterior != global_position:
		var camara := get_node_or_null("WorldCamera") as Camera2D
		if camara != null:
			camara.reset_smoothing()


func _actualizar_animacion(direccion: Vector2, nadando: bool, corriendo: bool) -> void:
	_asegurar_animaciones_nado()
	_asegurar_animaciones_golpe()
	var moviendose := direccion != Vector2.ZERO
	if moviendose:
		if absf(direccion.x) > absf(direccion.y):
			ultima_direccion = "right" if direccion.x > 0 else "left"
		elif absf(direccion.y) > absf(direccion.x):
			ultima_direccion = "down" if direccion.y > 0 else "up"
		elif ultima_direccion not in ["left" if direccion.x < 0 else "right", "up" if direccion.y < 0 else "down"]:
			ultima_direccion = "down" if direccion.y > 0 else "up"

	var animacion: String
	if nadando:
		animacion = "swim_" + ultima_direccion
	else:
		animacion = ("walk_" if moviendose else "idle_") + ultima_direccion

	# Durante el golpe se reproduce la animación de golpe, pero se actualiza dirección/offset/base.
	if animacion_golpeando:
		var hit_anim := "hit_" + ultima_direccion
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(hit_anim):
			animacion = hit_anim
	sprite.flip_h = ultima_direccion == "right"

	# Escala y alineación de pies/base. En agua el personaje se hunde para cubrir las botas.
	# Algunas animaciones (golpe, nado_atras) usan frames de mayor tamaño (362x724) y requieren escala reducida.
	var factor_frame := 1.0
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animacion) and sprite.sprite_frames.get_frame_count(animacion) > 0:
		var tex_ref = sprite.sprite_frames.get_frame_texture(animacion, 0)
		if tex_ref != null:
			var sz := tex_ref.get_size()
			if sz.y >= 500.0 or sz.x >= 300.0:
				factor_frame = 0.5
	var base_y := 0.0
	if animacion_golpeando and animacion.begins_with("hit_"):
		sprite.scale = Vector2(0.2, 0.2) * factor_frame
		base_y = -7.0
	elif nadando:
		sprite.scale = Vector2(0.2, 0.2) * factor_frame
		var hundimiento := 11.0 if current_terrain == WATER else 12.0
		base_y = -7.0 + hundimiento
	else:
		var escala_base := Vector2(0.133333, 0.133333) if animacion in ["idle_left", "idle_right"] else Vector2(0.2, 0.2)
		sprite.scale = escala_base * factor_frame
		base_y = -3.2 if animacion in ["idle_left", "idle_right"] else -7.0
	sprite.position = Vector2(offset_golpe.x, base_y + offset_golpe.y)

	# Velocidad de animación: correr/nado rápido acelera la reproducción.
	var velocidad_anim := 1.0
	if animacion_golpeando and animacion.begins_with("hit_"):
		velocidad_anim = 1.0
	elif nadando:
		velocidad_anim = 1.6 if corriendo else 1.0
	elif moviendose and corriendo:
		velocidad_anim = 1.55
	sprite.speed_scale = velocidad_anim

	if sprite.animation != animacion:
		sprite.animation = animacion
		if animacion_golpeando and animacion.begins_with("hit_"):
			sprite.frame = 0
			sprite.play(animacion)

	if animacion_golpeando and animacion.begins_with("hit_"):
		# No reiniciar: animation_finished limpia el estado al terminar.
		pass
	elif moviendose:
		if not sprite.is_playing() or sprite.animation != animacion:
			sprite.play(animacion)
	elif nadando:
		# Quieto flotando en agua: pose de nado en reposo.
		sprite.stop()
		sprite.frame = 0
	elif not reposo_activo:
		sprite.stop()
		sprite.frame = 0


func _esta_nadando() -> bool:
	return current_terrain == WATER or current_terrain == DEEP_WATER


func _actualizar_consumo_hambre(delta: float, nadando: bool, corriendo: bool, moviendose: bool) -> void:
	if not moviendose or hambre <= 0:
		return
	var tasa := 0.0
	if nadando and corriendo:
		tasa = HAMBRE_NADO + HAMBRE_CORRER
	elif nadando:
		tasa = HAMBRE_NADO
	elif corriendo:
		tasa = HAMBRE_CORRER
	else:
		return
	hambre_acumulada += tasa * delta
	while hambre_acumulada >= 1.0 and hambre > 0:
		hambre_acumulada -= 1.0
		reducir_hambre(1)


func _asegurar_animaciones_nado() -> void:
	if sprite == null:
		return
	var sf := sprite.sprite_frames
	if sf == null or sf.has_animation("swim_down"):
		return
	var defs := {
		# Mismo criterio de vistas que las caminatas: abajo=espalda, arriba=frente, lateral=perfil.
		"swim_down": "res://assets/Jugador/jugador_nado_atras.png",
		"swim_up": "res://assets/Jugador/jugador_nado_adelante.png",
		"swim_left": "res://assets/Jugador/jugador_nado_lateral.png",
		"swim_right": "res://assets/Jugador/jugador_nado_lateral.png",
	}
	for anim_name in defs.keys():
		if sf.has_animation(anim_name):
			continue
		var tex := _cargar_textura(defs[anim_name])
		if tex == null:
			continue
		var frame_w := 180
		var frame_h := 360
		if tex.get_width() >= 2172 and tex.get_height() >= 720:
			frame_w = int(tex.get_width() / 6)
			frame_h = tex.get_height()
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, 7.0)
		for i in range(6):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			sf.add_frame(anim_name, at)


func _asegurar_animaciones_golpe() -> void:
	if sprite == null:
		return
	var sf := sprite.sprite_frames
	if sf == null or sf.has_animation("hit_down"):
		return
	var tex := _cargar_textura("res://assets/Jugador/golpear.png")
	if tex == null:
		return
	# Sprite sheet horizontal de 6 fotogramas (2172x724). Duración breve (~0.5s).
	for anim_name in ["hit_down", "hit_up", "hit_left", "hit_right"]:
		if sf.has_animation(anim_name):
			continue
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, false)
		sf.set_animation_speed(anim_name, 12.0)
		for i in range(6):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 362, 0, 362, 724)
			sf.add_frame(anim_name, at)


func _reproducir_animacion_golpe() -> void:
	if sprite == null:
		return
	_asegurar_animaciones_golpe()
	var sf := sprite.sprite_frames
	if sf == null:
		return
	var anim_name := "hit_" + ultima_direccion
	if not sf.has_animation(anim_name):
		animacion_golpeando = false
		return
	animacion_golpeando = true
	reposo_activo = false
	sprite.animation = anim_name
	sprite.frame = 0
	sprite.speed_scale = 1.0
	sprite.play(anim_name)


func _cargar_textura(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		var t = load(ruta)
		if t is Texture2D:
			return t
	var abs_path := ProjectSettings.globalize_path(ruta)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		if img.load(abs_path) == OK:
			return ImageTexture.create_from_image(img)
	return null


func _cargar_supervivencia() -> void:
	vida = vida_maxima
	hambre = hambre_maxima
	var gm = get_node_or_null("/root/GestorMundos")
	if gm == null:
		return
	var mundo_actual: Dictionary = gm.get("mundo_actual") if gm.get("mundo_actual") is Dictionary else {}
	if mundo_actual.is_empty():
		return
	var progreso: Dictionary = mundo_actual.get("progreso", {})
	var jugador: Dictionary = progreso.get("jugador", {})
	var v = jugador.get("vida", vida_maxima)
	var h = jugador.get("hambre", hambre_maxima)
	if v is int or v is float:
		vida = clampi(int(v), 0, vida_maxima)
	if h is int or h is float:
		hambre = clampi(int(h), 0, hambre_maxima)


func recibir_danio(cantidad: int) -> void:
	if cantidad <= 0:
		return
	establecer_vida(vida - cantidad)


func recuperar_vida(cantidad: int) -> void:
	if cantidad <= 0:
		return
	establecer_vida(vida + cantidad)


func establecer_vida(valor: int) -> void:
	var nueva := clampi(valor, 0, vida_maxima)
	if nueva == vida:
		return
	vida = nueva
	vida_cambiada.emit(vida, vida_maxima)


func consultar_vida_actual() -> int:
	return vida


func consultar_vida_maxima() -> int:
	return vida_maxima


func aumentar_hambre(cantidad: int) -> void:
	if cantidad <= 0:
		return
	establecer_hambre(hambre + cantidad)


func reducir_hambre(cantidad: int) -> void:
	if cantidad <= 0:
		return
	establecer_hambre(hambre - cantidad)


func establecer_hambre(valor: int) -> void:
	var nueva := clampi(valor, 0, hambre_maxima)
	if nueva == hambre:
		return
	hambre = nueva
	hambre_cambiada.emit(hambre, hambre_maxima)

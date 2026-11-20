extends Node

const RUTA_AJUSTES := "user://ajustes.cfg"
const BUS_MUSICA := "Musica"
const BUS_SONIDOS := "Sonidos"

var volumen_musica: float = 1.0
var volumen_sonidos: float = 1.0
var reproductor_musica: AudioStreamPlayer
var musica_interfaz: AudioStream
var sfx_caminata_cesped: AudioStream
var sfx_golpe: AudioStream


func _ready() -> void:
	_asegurar_buses()
	_cargar_ajustes()
	_aplicar_volumenes()
	_cargar_streams()
	reproductor_musica = AudioStreamPlayer.new()
	reproductor_musica.name = "MusicaInterfaz"
	reproductor_musica.bus = BUS_MUSICA
	add_child(reproductor_musica)
	if get_tree().has_signal("scene_changed") and not get_tree().scene_changed.is_connected(_al_cambiar_escena):
		get_tree().scene_changed.connect(_al_cambiar_escena)
	call_deferred("_al_cambiar_escena")


func _asegurar_buses() -> void:
	_asegurar_bus(BUS_MUSICA)
	_asegurar_bus(BUS_SONIDOS)


func _asegurar_bus(nombre: String) -> void:
	var idx := AudioServer.get_bus_index(nombre)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, nombre)
		AudioServer.set_bus_send(idx, "Master")


func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_AJUSTES) == OK:
		volumen_musica = clampf(float(cfg.get_value("audio", "musica", 1.0)), 0.0, 1.0)
		volumen_sonidos = clampf(float(cfg.get_value("audio", "sonidos", 1.0)), 0.0, 1.0)


func guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "musica", volumen_musica)
	cfg.set_value("audio", "sonidos", volumen_sonidos)
	cfg.save(RUTA_AJUSTES)


func _aplicar_volumenes() -> void:
	var bus_m := AudioServer.get_bus_index(BUS_MUSICA)
	if bus_m >= 0:
		AudioServer.set_bus_volume_linear(bus_m, volumen_musica)
	var bus_s := AudioServer.get_bus_index(BUS_SONIDOS)
	if bus_s >= 0:
		AudioServer.set_bus_volume_linear(bus_s, volumen_sonidos)


func establecer_volumen_musica(v: float) -> void:
	volumen_musica = clampf(v, 0.0, 1.0)
	var bus_m := AudioServer.get_bus_index(BUS_MUSICA)
	if bus_m >= 0:
		AudioServer.set_bus_volume_linear(bus_m, volumen_musica)
	guardar_ajustes()


func establecer_volumen_sonidos(v: float) -> void:
	volumen_sonidos = clampf(v, 0.0, 1.0)
	var bus_s := AudioServer.get_bus_index(BUS_SONIDOS)
	if bus_s >= 0:
		AudioServer.set_bus_volume_linear(bus_s, volumen_sonidos)
	guardar_ajustes()


func _cargar_streams() -> void:
	musica_interfaz = _cargar_stream("res://assets/sonidos/musica_interfaz.mp3", true)
	sfx_caminata_cesped = _cargar_stream("res://assets/sonidos/caminata_cesped.mp3", true)
	sfx_golpe = _cargar_stream("res://assets/sonidos/golpes.mp3", false)


func _cargar_stream(ruta: String, bucle: bool) -> AudioStream:
	if ResourceLoader.exists(ruta):
		var s = load(ruta)
		if s is AudioStream:
			if bucle and "loop" in s:
				s.loop = true
			return s
	var abs_path := ProjectSettings.globalize_path(ruta)
	if FileAccess.file_exists(abs_path):
		var ext := ruta.get_extension().to_lower()
		if ext == "mp3":
			var f := FileAccess.open(abs_path, FileAccess.READ)
			if f != null:
				var mp3 := AudioStreamMP3.new()
				mp3.data = f.get_buffer(f.get_length())
				mp3.loop = bucle
				return mp3
		elif ext == "ogg":
			var ogg := AudioStreamOggVorbis.load_from_file(abs_path)
			if ogg != null:
				ogg.loop = bucle
				return ogg
		elif ext == "wav":
			var wav := AudioStreamWAV.load_from_file(abs_path)
			if wav != null:
				return wav
	return null


func _es_interfaz() -> bool:
	var escena := get_tree().current_scene
	if escena == null:
		return false
	return escena.scene_file_path.begins_with("res://escenas/interfaz/") and not escena.scene_file_path.ends_with("/carga_mundo.tscn")


func _al_cambiar_escena(_escena = null) -> void:
	if _es_interfaz():
		reproducir_musica_interfaz()
	else:
		detener_musica_interfaz()


func reproducir_musica_interfaz() -> void:
	if musica_interfaz == null:
		musica_interfaz = _cargar_stream("res://assets/sonidos/musica_interfaz.mp3", true)
	if musica_interfaz == null or reproductor_musica == null:
		return
	if reproductor_musica.playing and reproductor_musica.stream == musica_interfaz:
		return
	reproductor_musica.stream = musica_interfaz
	reproductor_musica.play()


func detener_musica_interfaz() -> void:
	if reproductor_musica != null and reproductor_musica.playing:
		reproductor_musica.stop()


func reproducir_sonido(stream: AudioStream, volumen_db: float = 0.0) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = BUS_SONIDOS
	p.volume_db = volumen_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func reproducir_golpe() -> void:
	reproducir_sonido(sfx_golpe)


func stream_caminata_cesped() -> AudioStream:
	return sfx_caminata_cesped

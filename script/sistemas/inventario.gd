extends RefCounted

signal cambiado
signal slot_seleccionado_cambiado(indice: int)

const TAMANO := 10
const MAX_PILA := 64

var slots: Array = []
var seleccionado := 0


func _init() -> void:
	_inicializar_slots()


func _inicializar_slots() -> void:
	slots.clear()
	for i in range(TAMANO):
		slots.append(null)


func cargar(datos) -> void:
	_inicializar_slots()
	seleccionado = 0
	if datos is Array:
		# Compatibilidad con formatos intermedios simples.
		for i in range(mini(datos.size(), TAMANO)):
			_normalizar_slot(i, datos[i])
		cambiado.emit()
		return
	if not datos is Dictionary:
		cambiado.emit()
		return
	if datos.has("slots") and datos.slots is Array:
		for i in range(mini((datos.slots as Array).size(), TAMANO)):
			_normalizar_slot(i, datos.slots[i])
		var sel = datos.get("seleccionado", 0)
		if sel is int or sel is float:
			seleccionado = clampi(int(sel), 0, TAMANO - 1)
		cambiado.emit()
		slot_seleccionado_cambiado.emit(seleccionado)
		return
	# Formato antiguo: {id: {id, nombre, cantidad}}
	var claves: Array = datos.keys()
	claves.sort()
	for clave in claves:
		var objeto = datos[clave]
		if not objeto is Dictionary:
			continue
		var id := String(objeto.get("id", clave))
		var nombre := String(objeto.get("nombre", id))
		var cantidad = objeto.get("cantidad", 0)
		if not (cantidad is int or cantidad is float):
			continue
		agregar(id, nombre, int(cantidad), {}, false)
	seleccionado = 0
	cambiado.emit()
	slot_seleccionado_cambiado.emit(seleccionado)


func serializar() -> Dictionary:
	var datos_slots: Array = []
	for slot in slots:
		if slot == null:
			datos_slots.append(null)
		else:
			datos_slots.append({
				"id": slot.get("id", ""),
				"nombre": slot.get("nombre", ""),
				"cantidad": int(slot.get("cantidad", 0)),
				"max_pila": int(slot.get("max_pila", MAX_PILA)),
				"tipo": slot.get("tipo", "objeto"),
				"icono": slot.get("icono", ""),
			})
	return {
		"version": 2,
		"slots": datos_slots,
		"seleccionado": seleccionado,
	}


func _normalizar_slot(indice: int, valor) -> void:
	if valor == null:
		slots[indice] = null
		return
	if not valor is Dictionary:
		slots[indice] = null
		return
	var id := String(valor.get("id", ""))
	if id.is_empty():
		slots[indice] = null
		return
	var cantidad = valor.get("cantidad", 0)
	if not (cantidad is int or cantidad is float):
		slots[indice] = null
		return
	var max_pila = valor.get("max_pila", MAX_PILA)
	if not (max_pila is int or max_pila is float):
		max_pila = MAX_PILA
	var cant := clampi(int(cantidad), 0, int(max_pila))
	if cant <= 0:
		slots[indice] = null
		return
	slots[indice] = {
		"id": id,
		"nombre": String(valor.get("nombre", id)),
		"cantidad": cant,
		"max_pila": clampi(int(max_pila), 1, MAX_PILA),
		"tipo": String(valor.get("tipo", "objeto")),
		"icono": String(valor.get("icono", "")),
	}


func espacio_para(id: String, max_pila: int = MAX_PILA) -> int:
	if not (max_pila is int or max_pila is float):
		max_pila = MAX_PILA
	max_pila = clampi(int(max_pila), 1, MAX_PILA)
	var espacio := 0
	for slot in slots:
		if slot != null and String(slot.get("id", "")) == id:
			espacio += maxi(0, int(slot.get("max_pila", max_pila)) - int(slot.get("cantidad", 0)))
	for slot in slots:
		if slot == null:
			espacio += max_pila
	return espacio


func puede_agregar(id: String, cantidad: int, max_pila: int = MAX_PILA) -> bool:
	if cantidad <= 0:
		return true
	return espacio_para(id, max_pila) >= cantidad


func agregar_hasta(id: String, nombre: String, cantidad: int, definicion: Dictionary = {}, emitir := true) -> int:
	if cantidad <= 0:
		return 0
	var max_pila = definicion.get("max_pila", MAX_PILA)
	if not (max_pila is int or max_pila is float):
		max_pila = MAX_PILA
	max_pila = clampi(int(max_pila), 1, MAX_PILA)
	var restante := cantidad
	# Completar pilas existentes del mismo objeto.
	for i in range(TAMANO):
		var slot = slots[i]
		if slot == null or String(slot.get("id", "")) != id:
			continue
		var espacio := maxi(0, int(slot.get("max_pila", max_pila)) - int(slot.get("cantidad", 0)))
		if espacio <= 0:
			continue
		var mover := mini(espacio, restante)
		slot["cantidad"] = int(slot.get("cantidad", 0)) + mover
		if definicion.has("icono"):
			slot["icono"] = String(definicion.get("icono", slot.get("icono", "")))
		if definicion.has("tipo"):
			slot["tipo"] = String(definicion.get("tipo", slot.get("tipo", "objeto")))
		slot["nombre"] = nombre
		restante -= mover
		if restante <= 0:
			break
	# Usar slots vacíos.
	if restante > 0:
		for i in range(TAMANO):
			if slots[i] != null:
				continue
			var mover := mini(max_pila, restante)
			slots[i] = {
				"id": id,
				"nombre": nombre,
				"cantidad": mover,
				"max_pila": max_pila,
				"tipo": String(definicion.get("tipo", "objeto")),
				"icono": String(definicion.get("icono", "")),
			}
			restante -= mover
			if restante <= 0:
				break
	var agregado := cantidad - restante
	if emitir and agregado > 0:
		cambiado.emit()
	return agregado


func agregar(id: String, nombre: String, cantidad: int, definicion: Dictionary = {}, emitir := true) -> bool:
	if cantidad <= 0:
		return true
	var max_pila = definicion.get("max_pila", MAX_PILA)
	if not (max_pila is int or max_pila is float):
		max_pila = MAX_PILA
	max_pila = clampi(int(max_pila), 1, MAX_PILA)
	if not puede_agregar(id, cantidad, max_pila):
		return false
	return agregar_hasta(id, nombre, cantidad, definicion, emitir) == cantidad


func contar(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and String(slot.get("id", "")) == id:
			total += int(slot.get("cantidad", 0))
	return total


func seleccionar(indice: int) -> void:
	var nuevo := posmod(indice, TAMANO)
	if nuevo == seleccionado:
		return
	seleccionado = nuevo
	slot_seleccionado_cambiado.emit(seleccionado)


func slot(indice: int):
	if indice < 0 or indice >= TAMANO:
		return null
	return slots[indice]


func quitar_en_slot(indice: int, cantidad: int, emitir := true) -> bool:
	if indice < 0 or indice >= TAMANO or cantidad <= 0:
		return false
	var s = slots[indice]
	if s == null:
		return false
	var actual := int(s.get("cantidad", 0))
	if actual < cantidad:
		return false
	var nueva := actual - cantidad
	if nueva <= 0:
		slots[indice] = null
	else:
		s["cantidad"] = nueva
	if emitir:
		cambiado.emit()
	return true


# Compatibilidad con código antiguo que leía .objetos
var objetos: Dictionary:
	get:
		var resultado := {}
		for s in slots:
			if s == null:
				continue
			var id := String(s.get("id", ""))
			if id.is_empty():
				continue
			if not resultado.has(id):
				resultado[id] = {"id": id, "nombre": String(s.get("nombre", id)), "cantidad": 0}
			resultado[id].cantidad = int(resultado[id].cantidad) + int(s.get("cantidad", 0))
		return resultado
	set(valor):
		cargar(valor)

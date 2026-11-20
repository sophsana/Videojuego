extends RefCounted

var objetos: Dictionary = {}


func cargar(datos: Dictionary) -> void:
	objetos = datos.duplicate(true)


func agregar(id: String, nombre: String, cantidad: int) -> void:
	if cantidad <= 0:
		return
	var entrada: Dictionary = objetos.get(id, {"id": id, "nombre": nombre, "cantidad": 0})
	entrada.cantidad = int(entrada.cantidad) + cantidad
	objetos[id] = entrada

extends RefCounted

# FastNoiseLite usa semillas int32 y el generador suma hasta 400.
const SEMILLA_MINIMA := -2147483648
const SEMILLA_MAXIMA := 2147483247
const LONGITUD_NOMBRE := 32
const DIFICULTADES := ["Fácil", "Normal", "Difícil"]

# Pendiente de balance: no modifica ninguna mecánica existente.
const AJUSTES_DIFICULTAD := {
	"Fácil": {"criaturas": null, "regeneracion": null, "oxigeno": null, "recursos_especiales": null},
	"Normal": {"criaturas": null, "regeneracion": null, "oxigeno": null, "recursos_especiales": null},
	"Difícil": {"criaturas": null, "regeneracion": null, "oxigeno": null, "recursos_especiales": null},
}


static func semilla_valida(texto: String) -> bool:
	if not texto.is_valid_int():
		return false
	# Evita que to_int sature silenciosamente con números demasiado largos.
	var limpio := texto.trim_prefix("-").trim_prefix("+").lstrip("0")
	if limpio.length() > 10:
		return false
	var valor := texto.to_int()
	return valor >= SEMILLA_MINIMA and valor <= SEMILLA_MAXIMA

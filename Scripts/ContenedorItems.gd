class_name ContenedorItems
extends RefCounted
## ContenedorItems.gd
## ══════════════════════════════════════════════════════════════════════════
## Contenedor de ítems genérico y reutilizable (cofres, baúles, puestos de
## intercambio, etc.). Implementa EXACTAMENTE la misma API que usa
## Inventory.gd para sus slots — `slots`, `tomar_slot()`, `colocar_en_slot()`,
## `agregar_item()` y la señal `inventario_cambiado` — así que
## Scripts/ui/slot_ui.gd puede mostrar y operar sobre un cofre exactamente
## igual que sobre el inventario del jugador: solo cambia a qué `fuente` está
## mirando cada SlotUI, ni una línea más.
## ══════════════════════════════════════════════════════════════════════════

signal inventario_cambiado

var slots: Array = []


func _init(num_slots: int = 12) -> void:
	slots.resize(num_slots)


## Levanta el contenido completo de `indice` y lo deja vacío.
func tomar_slot(indice: int) -> Variant:
	if indice < 0 or indice >= slots.size():
		return null
	var contenido = slots[indice]
	if contenido == null:
		return null
	slots[indice] = null
	inventario_cambiado.emit()
	return contenido


## Deposita `contenido` en `indice` (coloca / mezcla / intercambia, igual
## que Inventory.colocar_en_slot). Devuelve lo que queda en la mano.
func colocar_en_slot(indice: int, contenido) -> Variant:
	if indice < 0 or indice >= slots.size() or contenido == null:
		return contenido

	var actual = slots[indice]

	if actual == null:
		slots[indice] = contenido
		inventario_cambiado.emit()
		return null

	if actual["item"].id == contenido["item"].id and actual["cantidad"] < actual["item"].stack_max:
		var espacio: int = actual["item"].stack_max - actual["cantidad"]
		var mover: int = min(espacio, contenido["cantidad"])
		actual["cantidad"]    += mover
		contenido["cantidad"] -= mover
		inventario_cambiado.emit()
		return null if contenido["cantidad"] <= 0 else contenido

	slots[indice] = contenido
	inventario_cambiado.emit()
	return actual


## Igual que Inventory.agregar_item: rellena stacks existentes y después usa
## slots vacíos. Devuelve lo que NO entró (0 si entró todo).
func agregar_item(item: Item, cantidad: int = 1) -> int:
	if item == null or cantidad <= 0:
		return cantidad

	var restante := cantidad

	if item.stack_max > 1:
		for i in range(slots.size()):
			if restante <= 0:
				break
			var slot = slots[i]
			if slot != null and slot["item"].id == item.id and slot["cantidad"] < item.stack_max:
				var espacio: int = item.stack_max - slot["cantidad"]
				var a_meter: int = min(espacio, restante)
				slot["cantidad"] += a_meter
				restante -= a_meter

	while restante > 0:
		var idx := _primer_slot_vacio()
		if idx == -1:
			break
		var a_meter: int = min(item.stack_max, restante)
		slots[idx] = {"item": item, "cantidad": a_meter}
		restante -= a_meter

	if restante != cantidad:
		inventario_cambiado.emit()

	return restante


func esta_vacio() -> bool:
	for s in slots:
		if s != null:
			return false
	return true


func _primer_slot_vacio() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

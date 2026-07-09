extends Node
## Inventory.gd  —  Autoload Singleton (Inventory)
## Gestiona los DATOS y la LÓGICA del inventario. No dibuja nada en pantalla
## — de eso se encarga InventoryUI.gd, que escucha la señal `inventario_cambiado`.
##
## Un slot vacío se representa como `null` dentro de `slots`. Un slot ocupado
## es un Dictionary: { "item": Item, "cantidad": int }.

const RUTA_GUARDADO := "user://inventario.cfg"

## Las primeras HOTBAR_SIZE posiciones de `slots` son la barra rápida (hotbar),
## igual que en Minecraft: son las MISMAS posiciones que se ven abajo en
## pantalla y arriba dentro del inventario completo — no hay duplicado de datos.
const HOTBAR_SIZE : int = 9

@export var num_slots: int = 36   # 9 de hotbar + 27 de mochila (3 filas de 9)

var slots: Array = []   # Array[Variant] → cada elemento es null o {item, cantidad}

## Índice (0..HOTBAR_SIZE-1) del slot de la hotbar actualmente seleccionado,
## es decir, el "ítem en mano" del jugador para usar en el mundo.
var slot_activo: int = 0

signal inventario_cambiado
signal slot_activo_cambiado(indice: int)
## Emitida cuando un ítem no cupo (inventario lleno) para que la UI muestre
## un aviso ("Inventario lleno").
signal item_no_cupo(item: Item, cantidad: int)


func _ready() -> void:
	slots.resize(num_slots)
	cargar_inventario()

func seleccionar_slot_activo(indice: int) -> void:
	if indice < 0 or indice >= HOTBAR_SIZE:
		return
	slot_activo = indice
	slot_activo_cambiado.emit(indice)

## Devuelve el contenido (Item + cantidad) del slot activo, o null si vacío.
func obtener_item_activo() -> Variant:
	return slots[slot_activo]


# ═════════════════════════════════════════════════════════════════════════════
#  AGREGAR / QUITAR
# ═════════════════════════════════════════════════════════════════════════════

## Intenta agregar `cantidad` unidades de `item`. Primero rellena stacks ya
## existentes de ese mismo ítem, y solo abre un slot nuevo si hace falta.
## Devuelve la cantidad que NO pudo entrar (0 si entró todo).
func agregar_item(item: Item, cantidad: int = 1) -> int:
	if item == null or cantidad <= 0:
		return cantidad

	var restante := cantidad

	# 1) Rellenar stacks existentes del mismo ítem.
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

	# 2) Abrir slots nuevos con lo que quede.
	while restante > 0:
		var idx := _primer_slot_vacio()
		if idx == -1:
			break
		var a_meter: int = min(item.stack_max, restante)
		slots[idx] = {"item": item, "cantidad": a_meter}
		restante -= a_meter

	if restante != cantidad:
		inventario_cambiado.emit()
		guardar_inventario()

	if restante > 0:
		item_no_cupo.emit(item, restante)

	return restante

## Quita `cantidad` unidades del ítem con este id, recorriendo los slots que
## lo contengan. Devuelve true si pudo quitar la cantidad completa.
func quitar_item_por_id(item_id: String, cantidad: int = 1) -> bool:
	if cantidad_total(item_id) < cantidad:
		return false

	var restante := cantidad
	for i in range(slots.size()):
		if restante <= 0:
			break
		var slot = slots[i]
		if slot != null and slot["item"].id == item_id:
			var a_quitar: int = min(slot["cantidad"], restante)
			slot["cantidad"] -= a_quitar
			restante -= a_quitar
			if slot["cantidad"] <= 0:
				slots[i] = null

	inventario_cambiado.emit()
	guardar_inventario()
	return true

## Quita todo el contenido de un slot puntual (usado por "Soltar").
func vaciar_slot(indice: int, cantidad: int = -1) -> void:
	if indice < 0 or indice >= slots.size() or slots[indice] == null:
		return
	var slot = slots[indice]
	if cantidad < 0 or cantidad >= slot["cantidad"]:
		slots[indice] = null
	else:
		slot["cantidad"] -= cantidad
	inventario_cambiado.emit()
	guardar_inventario()


# ═════════════════════════════════════════════════════════════════════════════
#  TOMAR / COLOCAR  (sistema de "mano" estilo Minecraft: tocar un slot para
#  levantar su contenido, tocar otro para soltarlo/mezclarlo/intercambiarlo)
# ═════════════════════════════════════════════════════════════════════════════

## Levanta el contenido completo de `indice` y lo deja vacío. Devuelve lo
## levantado (Dictionary {item, cantidad}) o null si el slot ya estaba vacío.
func tomar_slot(indice: int) -> Variant:
	if indice < 0 or indice >= slots.size():
		return null
	var contenido = slots[indice]
	if contenido == null:
		return null
	slots[indice] = null
	inventario_cambiado.emit()
	return contenido

## Intenta depositar `contenido` (lo que el jugador "trae en la mano") en
## `indice`. Reglas, igual que Minecraft:
##   - Slot vacío           → se coloca entero ahí.
##   - Mismo ítem, hay hueco → se apila hasta stack_max, sobra vuelve a la mano.
##   - Ítem distinto         → se intercambian (lo que había pasa a la mano).
## Devuelve lo que queda en la mano (null si se colocó/mezcló todo).
func colocar_en_slot(indice: int, contenido) -> Variant:
	if indice < 0 or indice >= slots.size() or contenido == null:
		return contenido

	var actual = slots[indice]

	if actual == null:
		slots[indice] = contenido
		inventario_cambiado.emit()
		guardar_inventario()
		return null

	if actual["item"].id == contenido["item"].id and actual["cantidad"] < actual["item"].stack_max:
		var espacio: int = actual["item"].stack_max - actual["cantidad"]
		var mover: int = min(espacio, contenido["cantidad"])
		actual["cantidad"]     += mover
		contenido["cantidad"]  -= mover
		inventario_cambiado.emit()
		guardar_inventario()
		return null if contenido["cantidad"] <= 0 else contenido

	# Ítem distinto (o mismo pero sin hueco): intercambio total.
	slots[indice] = contenido
	inventario_cambiado.emit()
	guardar_inventario()
	return actual


# ═════════════════════════════════════════════════════════════════════════════
#  CONSULTAS
# ═════════════════════════════════════════════════════════════════════════════

func cantidad_total(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot["item"].id == item_id:
			total += slot["cantidad"]
	return total

func tiene_item(item_id: String, cantidad: int = 1) -> bool:
	return cantidad_total(item_id) >= cantidad

func esta_lleno() -> bool:
	return _primer_slot_vacio() == -1

func _primer_slot_vacio() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1


# ═════════════════════════════════════════════════════════════════════════════
#  PERSISTENCIA  (mismo patrón que Global.gd → guardar_perfil/cargar_perfil)
# ═════════════════════════════════════════════════════════════════════════════

## Registro de rutas .tres por id, para poder recargar el Resource al cargar
## partida. Complétalo agregando cada ítem que crees, o usa
## `registrar_carpeta_items()` para que se llene solo escaneando una carpeta.
var _registro_rutas: Dictionary = {}

func registrar_item(item: Item) -> void:
	if item != null and item.id != "" and item.resource_path != "":
		_registro_rutas[item.id] = item.resource_path

## Escanea una carpeta (ej. "res://Items/") y registra todos los .tres que
## sean Item, para no tener que registrar cada ítem a mano.
func registrar_carpeta_items(carpeta: String = "res://Items/") -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		push_warning("Inventory: no se pudo abrir la carpeta %s" % carpeta)
		return
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if archivo.ends_with(".tres"):
			var recurso := load(carpeta.path_join(archivo))
			if recurso is Item:
				registrar_item(recurso)
		archivo = dir.get_next()
	dir.list_dir_end()

func guardar_inventario() -> void:
	var cfg := ConfigFile.new()
	var i := 0
	for slot in slots:
		if slot != null:
			cfg.set_value("slots", "id_%d" % i, slot["item"].id)
			cfg.set_value("slots", "cant_%d" % i, slot["cantidad"])
		i += 1
	cfg.set_value("meta", "num_slots", num_slots)
	var err := cfg.save(RUTA_GUARDADO)
	if err != OK:
		push_warning("Inventory: no se pudo guardar — error %d" % err)

func cargar_inventario() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_GUARDADO) != OK:
		return
	if _registro_rutas.is_empty():
		registrar_carpeta_items()

	for i in range(slots.size()):
		var id: String = cfg.get_value("slots", "id_%d" % i, "")
		if id == "":
			continue
		var cantidad: int = cfg.get_value("slots", "cant_%d" % i, 0)
		if not _registro_rutas.has(id):
			push_warning("Inventory: ítem guardado '%s' ya no está registrado, se omite." % id)
			continue
		var item: Item = load(_registro_rutas[id])
		slots[i] = {"item": item, "cantidad": cantidad}

	inventario_cambiado.emit()

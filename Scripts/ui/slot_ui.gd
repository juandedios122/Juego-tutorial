extends Button
## slot_ui.gd  —  Slot visual reutilizable (Scenes/UI/SlotUI.tscn)
## ══════════════════════════════════════════════════════════════════════════
## Usa Assets/Menu/Slot.png como fondo, vía StyleBoxTexture (9-slice), igual
## que BotonPixel.tscn usa Plantilla-boton.png. Cada SlotUI representa UNA
## posición dentro de una `fuente` (ver abajo) — por defecto el inventario
## del jugador (Inventory), pero puede apuntar a cualquier otro contenedor
## con la misma API (ver Scripts/ContenedorItems.gd), como el cofre.
##
## Sigue funcionando con tap-tap (como antes: InventoryUI conecta la señal
## `pressed` heredada de Button) y ADEMÁS soporta arrastrar-y-soltar nativo
## de Godot (funciona con mouse en PC y con el dedo en Android, ya que Godot
## emula mouse desde touch por defecto). Como el arrastre lee/escribe siempre
## sobre `fuente`, se puede arrastrar de un slot del cofre a un slot de la
## mochila (o al revés) sin ningún código extra: cada slot solo conoce SU
## propia fuente.
## ══════════════════════════════════════════════════════════════════════════

const COLOR_SELECCIONADO := Color(0.72, 0.48, 1.00)

## Índice dentro de `fuente.slots` que representa este botón. Lo asigna
## quien instancia el slot (InventoryUI.gd o cofre.gd).
var indice_dato: int = -1

## Objeto que guarda los datos de este slot: expone `slots`, `tomar_slot()`,
## `colocar_en_slot()` y `agregar_item()`. Por defecto es el inventario del
## jugador; un cofre le asigna su propio ContenedorItems antes de pintar.
var fuente = Inventory

## true = slot de la hotbar persistente (fuera del inventario abierto). Ahí
## tocar selecciona/usa en vez de tomar/colocar, y no admite arrastre para
## no pisar al joystick mientras el inventario está cerrado.
@export var es_hotbar_fija: bool = false

@onready var _icono    : TextureRect = $Icono
@onready var _cantidad : Label       = $Cantidad
@onready var _estilo_normal : StyleBoxTexture = get_theme_stylebox("normal").duplicate()

var _contenido_arrastrado: Variant = null


func _ready() -> void:
	add_theme_stylebox_override("normal", _estilo_normal)


## Repinta el slot según el contenido actual de fuente.slots[indice_dato].
func pintar(seleccionado: bool) -> void:
	_estilo_normal.modulate_color = COLOR_SELECCIONADO if seleccionado else Color.WHITE

	var slot = null
	if indice_dato >= 0 and indice_dato < fuente.slots.size():
		slot = fuente.slots[indice_dato]

	if slot == null:
		_icono.texture = null
		_cantidad.text = ""
		return

	_icono.texture = slot["item"].icono
	_cantidad.text = str(slot["cantidad"]) if slot["item"].stack_max > 1 else ""


# ═════════════════════════════════════════════════════════════════════════════
#  ARRASTRAR Y SOLTAR
# ═════════════════════════════════════════════════════════════════════════════
func _get_drag_data(_at_position: Vector2) -> Variant:
	if es_hotbar_fija:
		return null

	var contenido = fuente.tomar_slot(indice_dato)
	if contenido == null:
		return null
	_contenido_arrastrado = contenido

	var vista := TextureRect.new()
	vista.texture = contenido["item"].icono
	vista.custom_minimum_size = Vector2(40, 40)
	vista.size = Vector2(40, 40)
	vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vista.modulate.a = 0.85
	set_drag_preview(vista)

	return contenido


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("item")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var sobrante = fuente.colocar_en_slot(indice_dato, data)
	_contenido_arrastrado = null
	# colocar_en_slot casi siempre coloca/mezcla/intercambia todo; por las
	# dudas, si algo no entró, lo devolvemos a ESTA fuente en vez de perderlo.
	if sobrante != null:
		fuente.agregar_item(sobrante["item"], sobrante["cantidad"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _contenido_arrastrado != null:
		if not get_viewport().gui_is_drag_successful():
			fuente.colocar_en_slot(indice_dato, _contenido_arrastrado)
		_contenido_arrastrado = null

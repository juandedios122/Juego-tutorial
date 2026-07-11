extends CanvasLayer
## InventoryUI.gd  —  Autoload Singleton (InventoryUI)
## Script de la escena Scenes/UI/InventoryUI.tscn.
##
## Inventario estilo Minecraft:
##   • Hotbar fija abajo (siempre visible en el mundo), con el slot
##     seleccionado resaltado. Tocar un slot lo selecciona; tocarlo de nuevo
##     (ya estando seleccionado) usa el ítem si es consumible.
##   • Ícono 🎒 junto a la hotbar (o tecla I) abre el inventario completo:
##     mochila arriba + la MISMA hotbar reflejada abajo — igual que el
##     inventario real del juego.
##   • Dentro del inventario, tocar un slot "levanta" su contenido (aparece
##     flotando pegado al dedo/mouse); tocar otro slot lo coloca, lo mezcla
##     si es el mismo ítem, o lo intercambia si es distinto. También se
##     puede arrastrar directamente de un slot a otro (mouse o dedo).
##   • Teclas 1-9 seleccionan el slot de hotbar correspondiente (PC).
##
## Todo el aspecto visual (paneles, slots, botones) viene de la escena — este
## script solo puebla los slots dinámicamente (son 9 + 27 + 9 = 45 en total)
## instanciando Scenes/UI/SlotUI.tscn, y conecta la lógica con Inventory.gd.

const ESCENAS_SIN_INVENTARIO : Array[String] = [
	"res://Scenes/MainMenu.tscn",
	"res://Scenes/PantallaMuserte.tscn",
	"res://Scenes/PantallaVictoria.tscn",
]

const SLOT_SCENE := preload("res://Scenes/UI/SlotUI.tscn")

# ─────────────────────────────────────────────────────────────────────────────
#  NODOS (vienen de InventoryUI.tscn)
# ─────────────────────────────────────────────────────────────────────────────
@onready var raiz              : Control       = $Raiz
@onready var boton_toggle      : Button         = $Raiz/HotbarPersistente/BotonToggle
@onready var hotbar_persistente : HBoxContainer = $Raiz/HotbarPersistente
@onready var overlay           : ColorRect      = $Raiz/Overlay
@onready var panel_inventario  : Panel          = $Raiz/PanelInventario
@onready var grid_mochila      : GridContainer  = $Raiz/PanelInventario/Margen/Col/GridMochila
@onready var hotbar_en_panel   : HBoxContainer  = $Raiz/PanelInventario/Margen/Col/HotbarEnPanel
@onready var label_info        : Label          = $Raiz/PanelInventario/Margen/Col/LabelInfo
@onready var boton_soltar      : Button         = $Raiz/PanelInventario/Margen/Col/FilaBotones/BotonSoltar
@onready var boton_cerrar      : Button         = $Raiz/PanelInventario/Margen/Col/FilaBotones/BotonCerrar
@onready var cursor_item       : Control        = $Raiz/CursorItem
@onready var icono_cursor      : TextureRect    = $Raiz/CursorItem/IconoCursor
@onready var label_cursor      : Label          = $Raiz/CursorItem/LabelCursor

var botones_hotbar_fija    : Array = []   ## SlotUI x9  (hotbar siempre visible)
var _botones_mochila       : Array = []   ## SlotUI x27 (mochila, dentro del panel)
var _botones_hotbar_panel  : Array = []   ## SlotUI x9  (hotbar reflejada dentro del panel)

## Lo que el jugador "trae en la mano" mientras el inventario está abierto
## (sistema de tap-tap; el arrastre nativo maneja su propio estado en cada
## SlotUI y no usa esta variable).
var _item_en_mano : Variant = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_poblar_slots()
	boton_toggle.pressed.connect(_toggle_inventario)
	boton_soltar.pressed.connect(_on_soltar_pulsado)
	boton_cerrar.pressed.connect(_cerrar)

	Inventory.inventario_cambiado.connect(_refrescar_todo)
	Inventory.slot_activo_cambiado.connect(_refrescar_hotbar_fija)
	Inventory.item_no_cupo.connect(_on_item_no_cupo)
	SceneTransition.escena_cambiada.connect(_on_cambio_escena)
	_refrescar_todo()


func _process(_delta: float) -> void:
	if _item_en_mano != null:
		var pos := get_viewport().get_mouse_position()
		cursor_item.position = pos - cursor_item.size / 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Inventario") and boton_toggle.visible:
		_toggle_inventario()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and panel_inventario.visible:
		_cerrar()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and boton_toggle.visible:
		var tecla: Key = event.physical_keycode
		if tecla >= KEY_1 and tecla <= KEY_9:
			_on_hotbar_fija_pulsada(int(tecla) - int(KEY_1))
			get_viewport().set_input_as_handled()


# ═════════════════════════════════════════════════════════════════════════════
#  POBLAR SLOTS  (instancia SlotUI.tscn, no crea botones por código)
# ═════════════════════════════════════════════════════════════════════════════
func _poblar_slots() -> void:
	# Hotbar persistente: se insertan ANTES del Espaciador/BotonToggle, que ya
	# están en la escena.
	for i in range(Inventory.HOTBAR_SIZE):
		var slot := SLOT_SCENE.instantiate()
		slot.indice_dato = i
		slot.es_hotbar_fija = true
		slot.pressed.connect(_on_hotbar_fija_pulsada.bind(i))
		hotbar_persistente.add_child(slot)
		hotbar_persistente.move_child(slot, i)
		botones_hotbar_fija.append(slot)

	# Mochila (dentro del panel).
	for i in range(Inventory.HOTBAR_SIZE, Inventory.num_slots):
		var slot := SLOT_SCENE.instantiate()
		slot.indice_dato = i
		slot.pressed.connect(_on_slot_inventario_pulsado.bind(i))
		grid_mochila.add_child(slot)
		_botones_mochila.append(slot)

	# Hotbar reflejada dentro del panel (mismos índices 0..8 que la de afuera).
	for i in range(Inventory.HOTBAR_SIZE):
		var slot := SLOT_SCENE.instantiate()
		slot.indice_dato = i
		slot.pressed.connect(_on_slot_inventario_pulsado.bind(i))
		hotbar_en_panel.add_child(slot)
		_botones_hotbar_panel.append(slot)


# ═════════════════════════════════════════════════════════════════════════════
#  ABRIR / CERRAR
# ═════════════════════════════════════════════════════════════════════════════
func _toggle_inventario() -> void:
	if panel_inventario.visible:
		_cerrar()
	else:
		_abrir()

func _abrir() -> void:
	overlay.visible          = true
	panel_inventario.visible = true
	get_tree().paused = true
	if has_node("/root/SFX"):
		SFX.play("inventory_open")

func _cerrar() -> void:
	# Si el jugador cierra con algo "en la mano" (tap-tap), se lo devolvemos
	# al inventario en vez de perderlo.
	if _item_en_mano != null:
		_soltar_item_en_mano_al_inventario()

	overlay.visible          = false
	panel_inventario.visible = false
	get_tree().paused = false
	if has_node("/root/SFX"):
		SFX.play("inventory_close")

func _on_cambio_escena() -> void:
	_cerrar()
	var escena := get_tree().current_scene
	var ocultar := escena != null and escena.scene_file_path in ESCENAS_SIN_INVENTARIO
	boton_toggle.visible        = not ocultar
	hotbar_persistente.visible  = not ocultar


# ═════════════════════════════════════════════════════════════════════════════
#  HOTBAR PERSISTENTE (fuera del inventario abierto)
# ═════════════════════════════════════════════════════════════════════════════
func _on_hotbar_fija_pulsada(indice: int) -> void:
	if Inventory.slot_activo == indice:
		_usar_slot_activo()
	else:
		Inventory.seleccionar_slot_activo(indice)

func _usar_slot_activo() -> void:
	var contenido = Inventory.obtener_item_activo()
	if contenido == null:
		return
	var item: Item = contenido["item"]
	if not item.consumible:
		return

	var jugador := get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		jugador = get_tree().current_scene.get_node_or_null("Jugador")

	if jugador != null and item.aplicar_efecto(jugador):
		Inventory.vaciar_slot(Inventory.slot_activo, 1)
		if has_node("/root/SFX") and item.id.begins_with("Pocion"):
			SFX.play("potion_drink")


# ═════════════════════════════════════════════════════════════════════════════
#  SLOTS DENTRO DEL INVENTARIO ABIERTO (tap-tap: tomar / colocar)
# ═════════════════════════════════════════════════════════════════════════════
func _on_slot_inventario_pulsado(indice: int) -> void:
	if _item_en_mano == null:
		var contenido = Inventory.tomar_slot(indice)
		if contenido != null:
			_item_en_mano = contenido
			_mostrar_info(contenido["item"])
	else:
		var restante = Inventory.colocar_en_slot(indice, _item_en_mano)
		_item_en_mano = restante
		if restante != null:
			_mostrar_info(restante["item"])

	_actualizar_cursor_visual()

func _on_soltar_pulsado() -> void:
	if _item_en_mano == null:
		label_info.text = "No tienes nada en la mano."
		return
	label_info.text = "Soltaste: %s" % _item_en_mano["item"].nombre
	_item_en_mano = null
	_actualizar_cursor_visual()

func _soltar_item_en_mano_al_inventario() -> void:
	if _item_en_mano == null:
		return
	var sobrante := Inventory.agregar_item(_item_en_mano["item"], _item_en_mano["cantidad"])
	if sobrante > 0:
		# No cupo en ningún lado (caso muy raro): se pierde, avisamos por consola.
		push_warning("InventoryUI: se perdió %dx %s al cerrar (inventario lleno)." %
			[sobrante, _item_en_mano["item"].nombre])
	_item_en_mano = null
	_actualizar_cursor_visual()

func _mostrar_info(item: Item) -> void:
	label_info.text = "%s — %s" % [item.nombre, item.descripcion]

func _actualizar_cursor_visual() -> void:
	if _item_en_mano == null:
		cursor_item.visible = false
		return
	cursor_item.visible  = true
	icono_cursor.texture = _item_en_mano["item"].icono
	label_cursor.text    = str(_item_en_mano["cantidad"]) if _item_en_mano["item"].stack_max > 1 else ""

func _on_item_no_cupo(item: Item, _cantidad: int) -> void:
	label_info.text = "Inventario lleno — no entró: %s" % item.nombre


# ═════════════════════════════════════════════════════════════════════════════
#  REFRESCO VISUAL
# ═════════════════════════════════════════════════════════════════════════════
func _refrescar_todo() -> void:
	_refrescar_hotbar_fija(Inventory.slot_activo)
	for slot in _botones_mochila:
		slot.pintar(false)
	for i in range(_botones_hotbar_panel.size()):
		_botones_hotbar_panel[i].pintar(i == Inventory.slot_activo)

func _refrescar_hotbar_fija(_indice_activo: int) -> void:
	for i in range(botones_hotbar_fija.size()):
		botones_hotbar_fija[i].pintar(i == Inventory.slot_activo)

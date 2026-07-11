extends Node2D
## cofre.gd
## ══════════════════════════════════════════════════════════════════════════
## Cofre interactivo TIPO INVENTARIO (como un cofre de Minecraft), mismo
## patrón de proximidad que npc.gd:
##   • Al acercarse el jugador aparece el botón "Abrir".
##   • La primera vez que se abre, reproduce la animación de
##     Assets/sprites/objects/chest_01.png (4 cuadros) — las veces siguientes
##     el cofre ya se ve abierto y el botón lleva directo al panel.
##   • Se abre un panel con DOS grillas de slots, iguales a las del
##     inventario del jugador (misma escena SlotUI.tscn, mismo Panel.png):
##       - Arriba: el contenido del cofre.
##       - Abajo: la mochila completa del jugador.
##     Se puede tocar (tomar/colocar) o ARRASTRAR ítems libremente entre las
##     dos grillas, en cualquier dirección — sacar del cofre, o guardar algo
##     tuyo ahí adentro.
##   • El cofre recuerda su contenido mientras la escena esté cargada (no es
##     "usar una vez": podés sacar algunas cosas ahora y volver más tarde a
##     buscar el resto). Si querés que además se guarde entre partidas,
##     avisame y le agrego persistencia como la de Inventory.gd.
##
## Configuración en el Inspector:
##   • "Objetos"          → ítems con los que arranca el cofre (uno por
##     slot). Por defecto, en Scenes/Cofre.tscn, viene con uno de cada ítem
##     del juego.
##   • "Radio Interaccion" → qué tan cerca debe estar el jugador para ver
##     el botón "Abrir" (igual que en npc.gd).
## ══════════════════════════════════════════════════════════════════════════

const FRAME_SIZE := 16
const TOTAL_FRAMES := 4          ## chest_01.png: 0=cerrado ... 3=abierto
const DURACION_ANIMACION := 0.5  ## segundos que tarda en abrirse
const SLOT_SCENE := preload("res://Scenes/UI/SlotUI.tscn")

@export var objetos: Array[Resource] = []
@export var radio_interaccion: float = 40.0

@onready var sprite             : Sprite2D          = $Sprite2D
@onready var zona_interaccion   : Area2D            = $ZonaInteraccion
@onready var forma_interaccion  : CollisionShape2D  = $ZonaInteraccion/CollisionShape2D

@onready var boton_abrir    : Button        = $UI_Cofre/BotonAbrir
@onready var overlay        : ColorRect     = $UI_Cofre/Overlay
@onready var panel_cofre    : Panel         = $UI_Cofre/PanelCofre
@onready var grid_cofre     : GridContainer = $UI_Cofre/PanelCofre/Margen/Col/GridCofre
@onready var grid_jugador   : GridContainer = $UI_Cofre/PanelCofre/Margen/Col/GridJugador
@onready var boton_cerrar   : Button        = $UI_Cofre/PanelCofre/Margen/Col/BotonCerrar

## Datos del cofre — usa la misma API que Inventory.gd (ver ContenedorItems.gd)
## para que SlotUI.tscn lo trate exactamente igual que la mochila del jugador.
var contenedor: ContenedorItems

var _slots_cofre   : Array = []
var _slots_jugador : Array = []

var _jugador_cerca    : bool    = false
var _animacion_hecha  : bool    = false
var _item_en_mano      : Variant = null


func _ready() -> void:
	# Para que el panel siga funcionando aunque el juego esté en pausa
	# mientras el cofre está abierto (igual que InventoryUI).
	process_mode = Node.PROCESS_MODE_ALWAYS

	var total_slots: int = objetos.size() if objetos.size() > 0 else 12
	contenedor = ContenedorItems.new(total_slots)
	for i in range(objetos.size()):
		var item := objetos[i] as Item
		if item != null:
			contenedor.slots[i] = {"item": item, "cantidad": 1}

	if forma_interaccion.shape is CircleShape2D:
		forma_interaccion.shape.radius = radio_interaccion

	_pintar_frame(0)
	boton_abrir.visible = false
	overlay.visible      = false
	panel_cofre.visible  = false

	_poblar_slots()

	zona_interaccion.body_entered.connect(_on_zona_interaccion_body_entered)
	zona_interaccion.body_exited.connect(_on_zona_interaccion_body_exited)
	boton_abrir.pressed.connect(_abrir_cofre)
	boton_cerrar.pressed.connect(_cerrar_panel)

	contenedor.inventario_cambiado.connect(_refrescar_cofre)
	Inventory.inventario_cambiado.connect(_refrescar_jugador)


# ═════════════════════════════════════════════════════════════════════════════
#  ARMAR LAS GRILLAS  (instancia SlotUI.tscn, la misma escena que la mochila)
# ═════════════════════════════════════════════════════════════════════════════
func _poblar_slots() -> void:
	for i in range(contenedor.slots.size()):
		var slot := SLOT_SCENE.instantiate()
		slot.indice_dato = i
		slot.fuente       = contenedor
		slot.custom_minimum_size = Vector2(44, 44)
		slot.pressed.connect(_on_slot_pulsado.bind(slot))
		grid_cofre.add_child(slot)
		_slots_cofre.append(slot)

	for i in range(Inventory.num_slots):
		var slot := SLOT_SCENE.instantiate()
		slot.indice_dato = i
		slot.fuente       = Inventory
		slot.custom_minimum_size = Vector2(44, 44)
		slot.pressed.connect(_on_slot_pulsado.bind(slot))
		grid_jugador.add_child(slot)
		_slots_jugador.append(slot)


# ═════════════════════════════════════════════════════════════════════════════
#  PROXIMIDAD  (mismo patrón que npc.gd)
# ═════════════════════════════════════════════════════════════════════════════
func _on_zona_interaccion_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		_jugador_cerca = true
		if not panel_cofre.visible:
			boton_abrir.visible = true

func _on_zona_interaccion_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		_jugador_cerca = false
		boton_abrir.visible = false


# ═════════════════════════════════════════════════════════════════════════════
#  ABRIR / CERRAR EL PANEL
# ═════════════════════════════════════════════════════════════════════════════
func _abrir_cofre() -> void:
	boton_abrir.visible = false

	if not _animacion_hecha:
		_animacion_hecha = true
		if has_node("/root/SFX"):
			SFX.play("chest_open")
		await _animar_apertura()

	overlay.visible      = true
	panel_cofre.visible  = true
	get_tree().paused    = true
	_refrescar_cofre()
	_refrescar_jugador()

func _cerrar_panel() -> void:
	# Si el jugador cierra con algo "en la mano" (tap-tap), se lo devolvemos
	# — primero intenta al cofre, y si no entra, a su propia mochila.
	if _item_en_mano != null:
		var sobrante: int = contenedor.agregar_item(_item_en_mano["item"], _item_en_mano["cantidad"])
		if sobrante > 0:
			Inventory.agregar_item(_item_en_mano["item"], sobrante)
		_item_en_mano = null

	overlay.visible      = false
	panel_cofre.visible  = false
	get_tree().paused    = false

	if _jugador_cerca:
		boton_abrir.visible = true


func _animar_apertura() -> void:
	var tween := create_tween()
	for cuadro in range(1, TOTAL_FRAMES):
		tween.tween_callback(_pintar_frame.bind(cuadro))
		tween.tween_interval(DURACION_ANIMACION / TOTAL_FRAMES)
	await tween.finished

func _pintar_frame(cuadro: int) -> void:
	sprite.region_enabled = true
	sprite.region_rect = Rect2(cuadro * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)


# ═════════════════════════════════════════════════════════════════════════════
#  TAP-TAP  (tocar un slot levanta su contenido, tocar otro lo coloca —
#  funciona igual entre las dos grillas: cada slot solo conoce su `fuente`)
# ═════════════════════════════════════════════════════════════════════════════
func _on_slot_pulsado(slot: Button) -> void:
	if _item_en_mano == null:
		var contenido = slot.fuente.tomar_slot(slot.indice_dato)
		if contenido != null:
			_item_en_mano = contenido
	else:
		var restante = slot.fuente.colocar_en_slot(slot.indice_dato, _item_en_mano)
		_item_en_mano = restante


# ═════════════════════════════════════════════════════════════════════════════
#  REPINTADO
# ═════════════════════════════════════════════════════════════════════════════
func _refrescar_cofre() -> void:
	for s in _slots_cofre:
		s.pintar(false)

func _refrescar_jugador() -> void:
	for s in _slots_jugador:
		s.pintar(false)

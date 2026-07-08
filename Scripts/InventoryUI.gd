extends CanvasLayer
## InventoryUI.gd  —  Autoload Singleton (InventoryUI)
##
## Inventario estilo Minecraft:
##   • Hotbar fija abajo (siempre visible en el mundo), con el slot
##     seleccionado resaltado. Tocar un slot lo selecciona; tocarlo de nuevo
##     (ya estando seleccionado) usa el ítem si es consumible.
##   • Botón 🎒 (o tecla I) abre el inventario completo: mochila arriba +
##     la MISMA hotbar reflejada abajo, separada por una línea — igual que
##     el inventario real del juego.
##   • Dentro del inventario, tocar un slot "levanta" su contenido (aparece
##     flotando pegado al dedo/mouse); tocar otro slot lo coloca, lo mezcla
##     si es el mismo ítem, o lo intercambia si es distinto.
##   • Teclas 1-9 seleccionan el slot de hotbar correspondiente (PC).

const ESCENAS_SIN_INVENTARIO : Array[String] = [
	"res://Scenes/MainMenu.tscn",
	"res://Scenes/PantallaMuserte.tscn",
	"res://Scenes/PantallaVictoria.tscn",
]

const COLOR_PANEL_BG     := Color(0.055, 0.039, 0.118, 0.92)
const COLOR_BORDE        := Color(0.42, 0.28, 0.72, 0.75)
const COLOR_BOTON_BG     := Color(0.10, 0.07, 0.20, 0.95)
const COLOR_BOTON_HOVER  := Color(0.22, 0.14, 0.40, 0.97)
const COLOR_BOTON_PRESS  := Color(0.32, 0.20, 0.58, 1.00)
const COLOR_ACENTO       := Color(0.72, 0.48, 1.00)
const COLOR_TEXTO        := Color(0.95, 0.90, 1.00)

const TAMANO_SLOT   := 60

const TEX_ICONO_INVENTARIO := preload("res://Assets/Menu/Icon-Inventario.png")

# ─────────────────────────────────────────────────────────────────────────────
#  NODOS
# ─────────────────────────────────────────────────────────────────────────────
var raiz              : Control
var boton_toggle       : Button
var overlay            : ColorRect

var hotbar_persistente : HBoxContainer
var botones_hotbar_fija : Array[Button] = []

var panel_inventario   : Panel
var grid_mochila        : GridContainer
var hotbar_en_panel     : HBoxContainer
var label_info          : Label
var boton_soltar        : Button

var cursor_item   : Control
var icono_cursor  : TextureRect
var label_cursor  : Label

var _botones_mochila : Array[Button] = []
var _botones_hotbar_panel : Array[Button] = []

## Lo que el jugador "trae en la mano" mientras el inventario está abierto.
## null, o {item: Item, cantidad: int}.
var _item_en_mano : Variant = null


func _ready() -> void:
	layer        = 95   # debajo del PauseManager (layer 100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_ui()
	_aplicar_tema_visual()
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

func _cerrar() -> void:
	# Si el jugador cierra con algo "en la mano", se lo devolvemos al
	# inventario en vez de perderlo.
	if _item_en_mano != null:
		_soltar_item_en_mano_al_inventario()

	overlay.visible          = false
	panel_inventario.visible = false
	get_tree().paused = false

func _on_cambio_escena() -> void:
	_cerrar()
	var escena := get_tree().current_scene
	var ocultar := escena != null and escena.scene_file_path in ESCENAS_SIN_INVENTARIO
	boton_toggle.visible        = not ocultar
	hotbar_persistente.visible  = not ocultar


# ═════════════════════════════════════════════════════════════════════════════
#  CONSTRUCCIÓN DE LA INTERFAZ
# ═════════════════════════════════════════════════════════════════════════════
func _construir_ui() -> void:
	raiz = Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	_construir_boton_toggle()
	_construir_hotbar_persistente()
	_construir_overlay_y_panel()
	_construir_cursor_item()


func _construir_boton_toggle() -> void:
	boton_toggle = Button.new()
	boton_toggle.name = "BotonInventario"
	boton_toggle.icon = TEX_ICONO_INVENTARIO
	boton_toggle.expand_icon = true
	boton_toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton_toggle.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	boton_toggle.tooltip_text = "Inventario"
	boton_toggle.custom_minimum_size = Vector2(52, 52)
	boton_toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	boton_toggle.offset_left   = 12
	boton_toggle.offset_top    = 16
	boton_toggle.offset_right  = 64
	boton_toggle.offset_bottom = 68
	boton_toggle.focus_mode = Control.FOCUS_NONE
	boton_toggle.visible = false
	raiz.add_child(boton_toggle)
	boton_toggle.pressed.connect(_toggle_inventario)


func _construir_hotbar_persistente() -> void:
	hotbar_persistente = HBoxContainer.new()
	hotbar_persistente.name = "HotbarPersistente"
	hotbar_persistente.add_theme_constant_override("separation", 6)
	hotbar_persistente.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_persistente.offset_top    = -80
	hotbar_persistente.offset_bottom = -16
	var mitad := Inventory.HOTBAR_SIZE * (TAMANO_SLOT - 6) * 0.5
	hotbar_persistente.offset_left  = -mitad
	hotbar_persistente.offset_right =  mitad
	hotbar_persistente.visible = false
	raiz.add_child(hotbar_persistente)

	for i in range(Inventory.HOTBAR_SIZE):
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(TAMANO_SLOT - 6, TAMANO_SLOT - 6)
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(_on_hotbar_fija_pulsada.bind(i))
		hotbar_persistente.add_child(boton)
		botones_hotbar_fija.append(boton)


func _construir_overlay_y_panel() -> void:
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	raiz.add_child(overlay)

	var ancho_panel := Inventory.HOTBAR_SIZE * (TAMANO_SLOT + 8) + (TAMANO_SLOT + 8) + 60
	panel_inventario = _crear_panel_centrado("PanelInventario", ancho_panel, 520)
	raiz.add_child(panel_inventario)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left",   18)
	margen.add_theme_constant_override("margin_right",  18)
	margen.add_theme_constant_override("margin_top",    18)
	margen.add_theme_constant_override("margin_bottom", 18)
	panel_inventario.add_child(margen)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margen.add_child(col)

	var titulo := Label.new()
	titulo.text = "INVENTARIO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	col.add_child(titulo)
	col.add_child(HSeparator.new())

	# ── Mochila ──────────────────────────────────────────────────────────────
	grid_mochila = GridContainer.new()
	grid_mochila.columns = Inventory.HOTBAR_SIZE
	grid_mochila.add_theme_constant_override("h_separation", 6)
	grid_mochila.add_theme_constant_override("v_separation", 6)
	col.add_child(grid_mochila)

	col.add_child(HSeparator.new())

	# ── Hotbar reflejada dentro del panel (mismos slots 0..8) ───────────────
	hotbar_en_panel = HBoxContainer.new()
	hotbar_en_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_en_panel.add_theme_constant_override("separation", 6)
	col.add_child(hotbar_en_panel)

	col.add_child(HSeparator.new())

	label_info = Label.new()
	label_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	label_info.custom_minimum_size = Vector2(0, 40)
	label_info.text = "Toca un objeto para tomarlo. Otro slot lo coloca."
	col.add_child(label_info)

	var fila_botones := HBoxContainer.new()
	fila_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_botones.add_theme_constant_override("separation", 10)
	col.add_child(fila_botones)

	boton_soltar = _crear_boton_menu("Soltar lo que tengo en mano")
	boton_soltar.pressed.connect(_on_soltar_pulsado)
	fila_botones.add_child(boton_soltar)

	var btn_cerrar := _crear_boton_menu("Cerrar")
	btn_cerrar.pressed.connect(_cerrar)
	fila_botones.add_child(btn_cerrar)

	_construir_slots_mochila()
	_construir_slots_hotbar_panel()


func _construir_slots_mochila() -> void:
	for i in range(Inventory.HOTBAR_SIZE, Inventory.num_slots):
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(TAMANO_SLOT, TAMANO_SLOT)
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(_on_slot_inventario_pulsado.bind(i))
		grid_mochila.add_child(boton)
		_botones_mochila.append(boton)

func _construir_slots_hotbar_panel() -> void:
	for i in range(Inventory.HOTBAR_SIZE):
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(TAMANO_SLOT, TAMANO_SLOT)
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(_on_slot_inventario_pulsado.bind(i))
		hotbar_en_panel.add_child(boton)
		_botones_hotbar_panel.append(boton)


func _construir_cursor_item() -> void:
	cursor_item = Control.new()
	cursor_item.name = "CursorItem"
	cursor_item.custom_minimum_size = Vector2(TAMANO_SLOT, TAMANO_SLOT)
	cursor_item.size = Vector2(TAMANO_SLOT, TAMANO_SLOT)
	cursor_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_item.visible = false
	cursor_item.z_index = 10
	raiz.add_child(cursor_item)

	icono_cursor = TextureRect.new()
	icono_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono_cursor.modulate.a = 0.9
	cursor_item.add_child(icono_cursor)

	label_cursor = Label.new()
	label_cursor.add_theme_font_size_override("font_size", 14)
	label_cursor.add_theme_color_override("font_color", COLOR_TEXTO)
	label_cursor.add_theme_color_override("font_outline_color", Color.BLACK)
	label_cursor.add_theme_constant_override("outline_size", 3)
	label_cursor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	label_cursor.offset_left = -24
	label_cursor.offset_top  = -20
	label_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_item.add_child(label_cursor)


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


# ═════════════════════════════════════════════════════════════════════════════
#  SLOTS DENTRO DEL INVENTARIO ABIERTO (tomar / colocar)
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
	for i in range(_botones_mochila.size()):
		_pintar_slot(_botones_mochila[i], Inventory.HOTBAR_SIZE + i, false)
	for i in range(_botones_hotbar_panel.size()):
		_pintar_slot(_botones_hotbar_panel[i], i, i == Inventory.slot_activo)

func _refrescar_hotbar_fija(_indice_activo: int) -> void:
	for i in range(botones_hotbar_fija.size()):
		_pintar_slot(botones_hotbar_fija[i], i, i == Inventory.slot_activo)

func _pintar_slot(boton: Button, indice_dato: int, seleccionado: bool) -> void:
	for hijo in boton.get_children():
		hijo.queue_free()
	_estilizar_boton_slot(boton, seleccionado)

	var slot = Inventory.slots[indice_dato]
	if slot == null:
		return

	var icono := TextureRect.new()
	icono.texture = slot["item"].icono
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(icono)

	if slot["item"].stack_max > 1:
		var lbl_cant := Label.new()
		lbl_cant.text = str(slot["cantidad"])
		lbl_cant.add_theme_font_size_override("font_size", 14)
		lbl_cant.add_theme_color_override("font_color", COLOR_TEXTO)
		lbl_cant.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_cant.add_theme_constant_override("outline_size", 3)
		lbl_cant.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		lbl_cant.offset_left  = -24
		lbl_cant.offset_top   = -20
		lbl_cant.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(lbl_cant)


# ═════════════════════════════════════════════════════════════════════════════
#  HELPERS DE CONSTRUCCIÓN  (mismo estilo que pause_manager.gd)
# ═════════════════════════════════════════════════════════════════════════════
func _crear_panel_centrado(nombre: String, ancho: int, alto: int) -> Panel:
	var panel := Panel.new()
	panel.name = nombre
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -ancho / 2.0
	panel.offset_right  =  ancho / 2.0
	panel.offset_top    = -alto / 2.0
	panel.offset_bottom =  alto / 2.0
	panel.visible = false
	return panel

func _crear_boton_menu(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(0, 44)
	btn.focus_mode = Control.FOCUS_NONE
	return btn


# ═════════════════════════════════════════════════════════════════════════════
#  TEMA VISUAL
# ═════════════════════════════════════════════════════════════════════════════
func _aplicar_tema_visual() -> void:
	_estilizar_panel(panel_inventario)
	_estilizar_boton_generico(boton_toggle)
	_estilizar_boton_generico(boton_soltar)
	for hijo in raiz.find_children("*", "Button", true, false):
		if hijo not in botones_hotbar_fija and hijo not in _botones_mochila \
				and hijo not in _botones_hotbar_panel and hijo != boton_toggle:
			_estilizar_boton_generico(hijo)

func _estilizar_panel(panel: Panel) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_PANEL_BG
	s.set_corner_radius_all(14)
	s.set_border_width_all(1)
	s.border_color = COLOR_BORDE
	panel.add_theme_stylebox_override("panel", s)

func _crear_estilo_slot(borde: Color, grosor: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BOTON_BG
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(grosor)
	sb.border_color = borde
	return sb

func _estilizar_boton_slot(boton: Button, seleccionado: bool) -> void:
	var borde := COLOR_ACENTO if seleccionado else COLOR_BORDE
	var grosor := 3 if seleccionado else 1
	boton.add_theme_stylebox_override("normal",  _crear_estilo_slot(borde, grosor))
	boton.add_theme_stylebox_override("hover",   _crear_estilo_slot(COLOR_ACENTO, 2))
	boton.add_theme_stylebox_override("pressed", _crear_estilo_slot(COLOR_ACENTO, 3))

func _estilizar_boton_generico(boton: Button) -> void:
	var mk := func(c: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = COLOR_BORDE
		sb.content_margin_left   = 10
		sb.content_margin_right  = 10
		sb.content_margin_top    = 6
		sb.content_margin_bottom = 6
		return sb
	boton.add_theme_stylebox_override("normal",  mk.call(COLOR_BOTON_BG))
	boton.add_theme_stylebox_override("hover",   mk.call(COLOR_BOTON_HOVER))
	boton.add_theme_stylebox_override("pressed", mk.call(COLOR_BOTON_PRESS))
	boton.add_theme_color_override("font_color",         COLOR_TEXTO)
	boton.add_theme_color_override("font_hover_color",   Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)

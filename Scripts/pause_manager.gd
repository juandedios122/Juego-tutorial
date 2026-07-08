extends CanvasLayer
## pause_manager.gd  —  Autoload Singleton (PauseManager)
## Sistema de pausa global con menú de opciones expandido:
##   • Tamaño de los botones (joystick / ataque / pausa)
##   • Volumen de música
##   • Volumen de efectos de sonido
##   • Mostrar / ocultar contador de muertes
##   • Cambiar foto de perfil

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────
const ESCENA_MENU_PRINCIPAL := "res://Scenes/MainMenu.tscn"
const ESCENA_AL_SALIR       := "res://Scenes/MainMenu.tscn"

const NODOS_ESCALABLES : Array[String] = ["JoystickControl", "BotonAtaque"]

const AVATARES_JUEGO : Array[String] = [
	"res://Assets/avatares_default/portrait.png"
]

const COLOR_PANEL_BG    := Color(0.055, 0.039, 0.118, 0.92)
const COLOR_BORDE       := Color(0.42, 0.28, 0.72, 0.75)
const COLOR_BOTON_BG    := Color(0.10, 0.07, 0.20, 0.95)
const COLOR_BOTON_HOVER := Color(0.22, 0.14, 0.40, 0.97)
const COLOR_BOTON_PRESS := Color(0.32, 0.20, 0.58, 1.00)
const COLOR_ACENTO      := Color(0.72, 0.48, 1.00)
const COLOR_TEXTO       := Color(0.95, 0.90, 1.00)

# ── Recursos pixel-art (botones "Continuar/Ajustes/Salir" + fondo del panel) ──
const TEX_BOTON_PIXEL := preload("res://Assets/Menu/Plantilla-boton.png")
const TEX_PANEL_PAUSA := preload("res://Assets/Menu/Panel-pausa.png")
const TEX_ICONO_PAUSA := preload("res://Assets/Menu/PAUSA.png")
const FUENTE_PIXEL    := preload("res://Assets/fonts/VT323-Regular.ttf")

const MARGEN_BOTON_PIXEL : int = 8   # borde de Plantilla-boton.png (160x32)
const MARGEN_PANEL_PAUSA : int = 48  # borde + adorno de esquina de Panel-pausa.png (320x240)

# ─────────────────────────────────────────────────────────────────────────────
#  NODOS
# ─────────────────────────────────────────────────────────────────────────────
var raiz                  : Control
var boton_pausa           : Button
var overlay               : ColorRect

var panel_pausa           : Panel
var panel_opciones        : Panel
var panel_selector_avatar : Panel
var panel_reposicionar    : Panel

var slider_tamano_botones : HSlider
var slider_musica         : HSlider
var slider_sfx            : HSlider
var toggle_contador       : CheckButton

var avatar_preview           : TextureRect
var grid_avatares             : GridContainer
var vista_previa_dispositivo  : TextureRect
var boton_usar_imagen         : Button

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO INTERNO
# ─────────────────────────────────────────────────────────────────────────────
var _escena_actual      : Node       = null
var _file_dialog        : FileDialog = null
var _imagen_dispositivo : Texture2D  = null

# ── Reposicionar controles por arrastre ─────────────────────────────────────
var _modo_reposicionar  : bool     = false
var _nodo_arrastrado    : Control  = null
var _indice_arrastre    : int      = -3   # -3 nada · -2 mouse · >=0 dedo
var _offset_arrastre    : Vector2  = Vector2.ZERO


# ═════════════════════════════════════════════════════════════════════════════
#  INICIALIZACIÓN
# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	layer        = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_ui()
	_aplicar_tema_visual()
	SceneTransition.escena_cambiada.connect(_on_cambio_escena)




func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and boton_pausa.visible:
		if overlay.visible:
			_cerrar_todo_y_continuar()
		else:
			_abrir_menu_pausa()
		get_viewport().set_input_as_handled()


## Solo activo mientras "Reposicionar controles" está abierto. Usa el mismo
## patrón de touch_index que joystick.gd / boton_ataque.gd para soportar
## arrastre por dedo o por mouse sin interferir con el resto del juego.
func _input(event: InputEvent) -> void:
	if not _modo_reposicionar:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _nodo_arrastrado == null:
				_intentar_agarrar(event.position, event.index)
		else:
			if _indice_arrastre == event.index:
				_soltar_arrastre()

	elif event is InputEventScreenDrag:
		if _nodo_arrastrado != null and _indice_arrastre == event.index:
			_nodo_arrastrado.global_position = event.position - _offset_arrastre

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _nodo_arrastrado == null:
				_intentar_agarrar(event.position, -2)
		else:
			if _indice_arrastre == -2:
				_soltar_arrastre()

	elif event is InputEventMouseMotion:
		if _nodo_arrastrado != null and _indice_arrastre == -2:
			_nodo_arrastrado.global_position = event.position - _offset_arrastre


func _on_cambio_escena() -> void:
	# BUG corregido: _escena_actual nunca se estaba asignando, así que la
	# comprobación de "es_menu_principal" jamás llegaba a evaluarse y el
	# icono de pausa se quedaba visible aunque estuvieras en el menú principal.
	_escena_actual = get_tree().current_scene
	_cerrar_todo_y_continuar()
	var es_menu_principal := false
	if _escena_actual != null:
		es_menu_principal = _escena_actual.scene_file_path == ESCENA_MENU_PRINCIPAL
	boton_pausa.visible = not es_menu_principal
	if not es_menu_principal:
		call_deferred("_aplicar_escala_botones", Global.ui_scale_botones)
		call_deferred("_aplicar_posiciones_personalizadas")


# ═════════════════════════════════════════════════════════════════════════════
#  CONSTRUCCIÓN DE LA INTERFAZ
# ═════════════════════════════════════════════════════════════════════════════
func _construir_ui() -> void:
	raiz = Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	# ── Botón de pausa ─────────────────────────────────────────────────────
	boton_pausa = Button.new()
	boton_pausa.name = "BotonPausa"
	boton_pausa.icon = TEX_ICONO_PAUSA
	boton_pausa.expand_icon = true
	boton_pausa.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton_pausa.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	boton_pausa.tooltip_text = "Pausa"
	boton_pausa.custom_minimum_size = Vector2(64, 64)
	boton_pausa.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	boton_pausa.offset_left   = -76
	boton_pausa.offset_top    = 16
	boton_pausa.offset_right  = -12
	boton_pausa.offset_bottom = 80
	boton_pausa.focus_mode = Control.FOCUS_NONE
	boton_pausa.visible = false
	raiz.add_child(boton_pausa)
	boton_pausa.pressed.connect(_abrir_menu_pausa)

	# ── Overlay oscuro ─────────────────────────────────────────────────────
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	raiz.add_child(overlay)

	# ── Panel PAUSA ────────────────────────────────────────────────────────
	panel_pausa = _crear_panel_centrado("PanelPausa", 300, 280)
	raiz.add_child(panel_pausa)
	var col_pausa := _vbox_en_panel(panel_pausa, 16)

	var titulo_pausa := Label.new()
	titulo_pausa.text = "PAUSA"
	titulo_pausa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_pausa.add_theme_font_size_override("font_size", 26)
	col_pausa.add_child(titulo_pausa)

	var btn_continuar := _crear_boton_menu("Continuar")
	btn_continuar.set_meta("estilo_pixel", true)
	btn_continuar.pressed.connect(_cerrar_todo_y_continuar)
	col_pausa.add_child(btn_continuar)

	var btn_opciones := _crear_boton_menu("Ajustes")
	btn_opciones.set_meta("estilo_pixel", true)
	btn_opciones.pressed.connect(_abrir_opciones)
	col_pausa.add_child(btn_opciones)

	var btn_salir := _crear_boton_menu("Salir")
	btn_salir.set_meta("estilo_pixel", true)
	btn_salir.pressed.connect(_on_salir)
	col_pausa.add_child(btn_salir)

	# ── Panel OPCIONES (ampliado con los nuevos ajustes) ───────────────────
	panel_opciones = _crear_panel_centrado("PanelOpciones", 360, 560)
	raiz.add_child(panel_opciones)
	var col_opt := _vbox_en_panel(panel_opciones, 10)

	var titulo_opt := Label.new()
	titulo_opt.text = "OPCIONES"
	titulo_opt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_opt.add_theme_font_size_override("font_size", 24)
	col_opt.add_child(titulo_opt)

	col_opt.add_child(_separador_h())

	# ── Tamaño de botones ──────────────────────────────────────────────────
	col_opt.add_child(_label_ajuste("🎮  Tamaño de los botones"))
	slider_tamano_botones = _crear_slider(0.6, 1.6, 0.05)
	col_opt.add_child(slider_tamano_botones)
	slider_tamano_botones.value_changed.connect(_on_cambio_tamano_botones)

	col_opt.add_child(_separador_h())

	# ── Volumen de música ──────────────────────────────────────────────────
	col_opt.add_child(_label_ajuste("🎵  Volumen de música"))
	slider_musica = _crear_slider(0.0, 1.0, 0.02)
	col_opt.add_child(slider_musica)
	slider_musica.value_changed.connect(_on_cambio_musica)

	# ── Volumen de efectos ─────────────────────────────────────────────────
	col_opt.add_child(_label_ajuste("🔊  Volumen de efectos"))
	slider_sfx = _crear_slider(0.0, 1.0, 0.02)
	col_opt.add_child(slider_sfx)
	slider_sfx.value_changed.connect(_on_cambio_sfx)

	col_opt.add_child(_separador_h())

	# ── Contador de muertes ────────────────────────────────────────────────
	var fila_contador := HBoxContainer.new()
	fila_contador.add_theme_constant_override("separation", 12)
	col_opt.add_child(fila_contador)

	var lbl_contador := Label.new()
	lbl_contador.text = "💀  Mostrar contador de muertes"
	lbl_contador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_contador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila_contador.add_child(lbl_contador)

	toggle_contador = CheckButton.new()
	toggle_contador.focus_mode = Control.FOCUS_NONE
	toggle_contador.toggled.connect(_on_toggle_contador_muertes)
	fila_contador.add_child(toggle_contador)

	col_opt.add_child(_separador_h())

	# ── Avatar ─────────────────────────────────────────────────────────────
	var fila_avatar := HBoxContainer.new()
	fila_avatar.add_theme_constant_override("separation", 14)
	col_opt.add_child(fila_avatar)

	var marco_avatar := PanelContainer.new()
	marco_avatar.custom_minimum_size = Vector2(64, 64)
	fila_avatar.add_child(marco_avatar)
	avatar_preview = TextureRect.new()
	avatar_preview.custom_minimum_size = Vector2(64, 64)
	avatar_preview.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	marco_avatar.add_child(avatar_preview)
	# ← Antes: 5 líneas de Shader.new/ShaderMaterial.new/shader.code duplicadas.
	AvatarUtil.aplicar_shader_circular(avatar_preview)

	var btn_cambiar_foto := _crear_boton_menu("Cambiar foto de perfil")
	btn_cambiar_foto.custom_minimum_size.y = 64
	fila_avatar.add_child(btn_cambiar_foto)
	btn_cambiar_foto.pressed.connect(_abrir_selector_avatar)
	btn_cambiar_foto.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_reposicionar := _crear_boton_menu("🎮  Reposicionar controles")
	btn_reposicionar.pressed.connect(_abrir_reposicionar)
	col_opt.add_child(btn_reposicionar)

	var btn_volver_opt := _crear_boton_menu("Volver")
	btn_volver_opt.pressed.connect(_abrir_menu_pausa)
	col_opt.add_child(btn_volver_opt)

	# ── Panel REPOSICIONAR CONTROLES ───────────────────────────────────────
	# Este panel es una pequeña instrucción flotante que se muestra ENCIMA
	# del juego (sin overlay oscuro) mientras el jugador arrastra.
	panel_reposicionar = Panel.new()
	panel_reposicionar.name    = "PanelReposicionar"
	panel_reposicionar.visible = false
	panel_reposicionar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel_reposicionar.offset_left   = -180.0
	panel_reposicionar.offset_right  =  180.0
	panel_reposicionar.offset_top    =  16.0
	panel_reposicionar.offset_bottom =  130.0
	raiz.add_child(panel_reposicionar)
	var col_repos := _vbox_en_panel(panel_reposicionar, 10)

	var lbl_repos := Label.new()
	lbl_repos.text = "🎮  Mueve los controles con el dedo\n     y presiona Listo cuando termines."
	lbl_repos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col_repos.add_child(lbl_repos)

	var fila_repos := HBoxContainer.new()
	fila_repos.add_theme_constant_override("separation", 8)
	col_repos.add_child(fila_repos)

	var btn_repos_listo := _crear_boton_menu("✔  Listo")
	btn_repos_listo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_repos_listo.pressed.connect(_cerrar_reposicionar)
	fila_repos.add_child(btn_repos_listo)

	var btn_repos_reset := _crear_boton_menu("↺  Restaurar")
	btn_repos_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_repos_reset.pressed.connect(_on_restaurar_posiciones)
	fila_repos.add_child(btn_repos_reset)

	# ── Panel SELECTOR DE AVATAR ───────────────────────────────────────────
	panel_selector_avatar = _crear_panel_centrado("PanelSelectorAvatar", 360, 460)
	raiz.add_child(panel_selector_avatar)
	var col_selector := _vbox_en_panel(panel_selector_avatar, 12)

	var titulo_selector := Label.new()
	titulo_selector.text = "Foto de perfil"
	titulo_selector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo_selector.add_theme_font_size_override("font_size", 22)
	col_selector.add_child(titulo_selector)

	var label_predef := Label.new()
	label_predef.text = "Avatares del juego"
	col_selector.add_child(label_predef)

	grid_avatares = GridContainer.new()
	grid_avatares.columns = 3
	grid_avatares.add_theme_constant_override("h_separation", 10)
	grid_avatares.add_theme_constant_override("v_separation", 10)
	col_selector.add_child(grid_avatares)
	# ← Antes: _cargar_avatares_predefinidos() (30 líneas duplicadas). Ahora:
	AvatarUtil.poblar_grid(grid_avatares, AVATARES_JUEGO, 78, _seleccionar_avatar_juego)

	var sep2 := HSeparator.new()
	col_selector.add_child(sep2)

	var label_dispositivo := Label.new()
	label_dispositivo.text = "O elige una imagen de tu teléfono"
	col_selector.add_child(label_dispositivo)

	var fila_dispositivo := HBoxContainer.new()
	fila_dispositivo.add_theme_constant_override("separation", 10)
	col_selector.add_child(fila_dispositivo)

	vista_previa_dispositivo = TextureRect.new()
	vista_previa_dispositivo.custom_minimum_size = Vector2(56, 56)
	vista_previa_dispositivo.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vista_previa_dispositivo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fila_dispositivo.add_child(vista_previa_dispositivo)

	var btn_examinar := _crear_boton_menu("Examinar galería")
	btn_examinar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_dispositivo.add_child(btn_examinar)
	btn_examinar.pressed.connect(_on_examinar_presionado)

	boton_usar_imagen = _crear_boton_menu("Usar esta imagen")
	boton_usar_imagen.visible = false
	col_selector.add_child(boton_usar_imagen)
	boton_usar_imagen.pressed.connect(_on_usar_imagen_dispositivo)

	var btn_cerrar_selector := _crear_boton_menu("Volver")
	btn_cerrar_selector.pressed.connect(_abrir_opciones)
	col_selector.add_child(btn_cerrar_selector)


# ── Helpers de construcción ────────────────────────────────────────────────
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

func _vbox_en_panel(panel: Panel, separacion: int) -> VBoxContainer:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left",   18)
	margen.add_theme_constant_override("margin_right",  18)
	margen.add_theme_constant_override("margin_top",    18)
	margen.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", separacion)
	margen.add_child(col)
	return col

func _crear_boton_menu(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	return btn

func _label_ajuste(texto: String) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	return lbl

func _crear_slider(minv: float, maxv: float, paso: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step      = paso
	s.custom_minimum_size = Vector2(0, 28)
	return s

func _separador_h() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	return sep


# ═════════════════════════════════════════════════════════════════════════════
#  TEMA VISUAL
# ═════════════════════════════════════════════════════════════════════════════
func _aplicar_tema_visual() -> void:
	_estilizar_panel_pixel(panel_pausa)
	_estilizar_panel(panel_opciones)
	_estilizar_panel(panel_selector_avatar)
	_estilizar_panel(panel_reposicionar)
	_estilizar_boton(boton_pausa)
	for hijo in raiz.find_children("*", "Button", true, false):
		if hijo == boton_pausa:
			continue
		if hijo.has_meta("estilo_pixel"):
			_estilizar_boton_pixel(hijo)
		else:
			_estilizar_boton(hijo)

func _estilizar_panel(panel: Panel) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_PANEL_BG
	s.set_corner_radius_all(14)
	s.set_border_width_all(1)
	s.border_color = COLOR_BORDE
	panel.add_theme_stylebox_override("panel", s)

## Fondo del panel de pausa usando Panel-pausa.png (9-slice vía StyleBoxTexture).
func _estilizar_panel_pixel(panel: Panel) -> void:
	var s := StyleBoxTexture.new()
	s.texture = TEX_PANEL_PAUSA
	s.texture_margin_left   = MARGEN_PANEL_PAUSA
	s.texture_margin_right  = MARGEN_PANEL_PAUSA
	s.texture_margin_top    = MARGEN_PANEL_PAUSA
	s.texture_margin_bottom = MARGEN_PANEL_PAUSA
	panel.add_theme_stylebox_override("panel", s)

## Stylebox 9-slice a partir de Plantilla-boton.png, con un tinte según el estado.
func _crear_stylebox_boton_pixel(tinte: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_BOTON_PIXEL
	sb.texture_margin_left   = MARGEN_BOTON_PIXEL
	sb.texture_margin_right  = MARGEN_BOTON_PIXEL
	sb.texture_margin_top    = MARGEN_BOTON_PIXEL
	sb.texture_margin_bottom = MARGEN_BOTON_PIXEL
	sb.modulate_color = tinte
	return sb

## Estilo pixel-art (Plantilla-boton.png + fuente VT323) para Continuar/Ajustes/Salir.
func _estilizar_boton_pixel(boton: Button) -> void:
	boton.add_theme_stylebox_override("normal",  _crear_stylebox_boton_pixel(Color(1, 1, 1, 1)))
	boton.add_theme_stylebox_override("hover",   _crear_stylebox_boton_pixel(Color(1.2, 1.2, 1.3, 1)))
	boton.add_theme_stylebox_override("pressed", _crear_stylebox_boton_pixel(Color(0.75, 0.75, 0.85, 1)))
	boton.add_theme_font_override("font", FUENTE_PIXEL)
	boton.add_theme_font_size_override("font_size", 28)
	boton.add_theme_color_override("font_color",         COLOR_TEXTO)
	boton.add_theme_color_override("font_hover_color",   Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.95))
	boton.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.18, 1))
	boton.add_theme_constant_override("outline_size", 3)

func _estilizar_boton(boton: Button) -> void:
	var mk := func(c: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = COLOR_BORDE
		sb.content_margin_left   = 14
		sb.content_margin_right  = 14
		sb.content_margin_top    = 8
		sb.content_margin_bottom = 8
		return sb
	boton.add_theme_stylebox_override("normal",  mk.call(COLOR_BOTON_BG))
	boton.add_theme_stylebox_override("hover",   mk.call(COLOR_BOTON_HOVER))
	boton.add_theme_stylebox_override("pressed", mk.call(COLOR_BOTON_PRESS))
	boton.add_theme_color_override("font_color",        COLOR_TEXTO)
	boton.add_theme_color_override("font_hover_color",  Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)


# ═════════════════════════════════════════════════════════════════════════════
#  FLUJO DEL MENÚ DE PAUSA
# ═════════════════════════════════════════════════════════════════════════════
func _abrir_menu_pausa() -> void:
	get_tree().paused = true
	boton_pausa.visible = false
	overlay.visible      = true
	panel_pausa.visible  = true
	panel_opciones.visible        = false
	panel_selector_avatar.visible = false

func _abrir_opciones() -> void:
	# Sincronizar todos los controles con los valores guardados
	slider_tamano_botones.value = Global.ui_scale_botones
	slider_musica.value         = Global.musica_volumen
	slider_sfx.value            = Global.sfx_volumen
	toggle_contador.button_pressed = Global.show_death_counter
	_actualizar_preview_avatar()

	panel_pausa.visible           = false
	panel_selector_avatar.visible = false
	panel_opciones.visible        = true

func _abrir_selector_avatar() -> void:
	panel_opciones.visible        = false
	panel_selector_avatar.visible = true

func _abrir_reposicionar() -> void:
	panel_opciones.visible     = false
	panel_reposicionar.visible = true
	get_tree().paused          = false   # el jugador tiene que ver la escena real
	overlay.visible            = false
	_modo_reposicionar         = true

func _cerrar_reposicionar() -> void:
	_modo_reposicionar         = false
	_nodo_arrastrado           = null
	_indice_arrastre           = -3
	_guardar_posiciones_actuales()
	get_tree().paused          = true
	overlay.visible            = true
	panel_reposicionar.visible = false
	panel_opciones.visible     = true

func _cerrar_todo_y_continuar() -> void:
	get_tree().paused             = false
	overlay.visible               = false
	panel_pausa.visible           = false
	panel_opciones.visible        = false
	panel_selector_avatar.visible = false
	panel_reposicionar.visible    = false
	boton_usar_imagen.visible     = false
	_imagen_dispositivo           = null
	_modo_reposicionar            = false
	_nodo_arrastrado              = null
	if boton_pausa != null and _escena_actual != null:
		boton_pausa.visible = _escena_actual.scene_file_path != ESCENA_MENU_PRINCIPAL

func _on_salir() -> void:
	get_tree().paused = false
	SceneTransition.ir_a(ESCENA_AL_SALIR)


# ─────────────────────────────────────────────────────────────────────────────
#  ARRASTRE  (helpers privados)
# ─────────────────────────────────────────────────────────────────────────────
func _intentar_agarrar(pos_global: Vector2, indice: int) -> void:
	for nombre in NODOS_ESCALABLES:
		var encontrados : Array = []
		if _escena_actual != null:
			_buscar_nodos_por_nombre(_escena_actual, nombre, encontrados)
		for nodo in encontrados:
			if nodo is Control and nodo.get_global_rect().has_point(pos_global):
				_nodo_arrastrado = nodo
				_indice_arrastre = indice
				_offset_arrastre = pos_global - nodo.global_position
				return

func _soltar_arrastre() -> void:
	_nodo_arrastrado = null
	_indice_arrastre = -3

func _guardar_posiciones_actuales() -> void:
	if _escena_actual == null:
		return
	for nombre in NODOS_ESCALABLES:
		var encontrados : Array = []
		_buscar_nodos_por_nombre(_escena_actual, nombre, encontrados)
		for nodo in encontrados:
			if nodo is Control:
				if not nodo.has_meta("pos_original"):
					continue
				var pos_original : Vector2 = nodo.get_meta("pos_original")
				var delta_pos = nodo.global_position - pos_original
				Global.set_offset_control(nombre, delta_pos)

func _aplicar_posiciones_personalizadas() -> void:
	if _escena_actual == null:
		return
	for nombre in NODOS_ESCALABLES:
		var encontrados : Array = []
		_buscar_nodos_por_nombre(_escena_actual, nombre, encontrados)
		for nodo in encontrados:
			if nodo is Control:
				# Guardar la posición original la primera vez, para poder calcular offset
				if not nodo.has_meta("pos_original"):
					nodo.set_meta("pos_original", nodo.global_position)
				var pos_original : Vector2 = nodo.get_meta("pos_original")
				nodo.global_position = pos_original + Global.get_offset_control(nombre)


# ═════════════════════════════════════════════════════════════════════════════
#  TAMAÑO DE LOS BOTONES
# ═════════════════════════════════════════════════════════════════════════════
func _on_cambio_tamano_botones(valor: float) -> void:
	Global.set_ui_scale_botones(valor)
	_aplicar_escala_botones(valor)

func _aplicar_escala_botones(factor: float) -> void:
	_escalar_control(boton_pausa, factor)
	if _escena_actual == null:
		return
	for nombre in NODOS_ESCALABLES:
		var encontrados : Array = []
		_buscar_nodos_por_nombre(_escena_actual, nombre, encontrados)
		for nodo in encontrados:
			if nodo is Control:
				_escalar_control(nodo, factor)

func _escalar_control(nodo: Control, factor: float) -> void:
	if not nodo.has_meta("escala_base"):
		nodo.set_meta("escala_base", nodo.scale)
	var base : Vector2 = nodo.get_meta("escala_base")
	nodo.pivot_offset = nodo.size / 2.0
	nodo.scale        = base * factor

func _buscar_nodos_por_nombre(raiz_busqueda: Node, nombre: String, resultado: Array) -> void:
	if raiz_busqueda.name == nombre:
		resultado.append(raiz_busqueda)
	for hijo in raiz_busqueda.get_children():
		_buscar_nodos_por_nombre(hijo, nombre, resultado)


# ═════════════════════════════════════════════════════════════════════════════
#  AJUSTES DE AUDIO
# ═════════════════════════════════════════════════════════════════════════════
func _on_cambio_musica(valor: float) -> void:
	Global.set_musica_volumen(valor)

func _on_cambio_sfx(valor: float) -> void:
	Global.set_sfx_volumen(valor)


# ═════════════════════════════════════════════════════════════════════════════
#  AJUSTE: CONTADOR DE MUERTES
# ═════════════════════════════════════════════════════════════════════════════
func _on_toggle_contador_muertes(valor: bool) -> void:
	Global.set_show_death_counter(valor)


# ═════════════════════════════════════════════════════════════════════════════
#  AJUSTE: REPOSICIONAR CONTROLES
# ═════════════════════════════════════════════════════════════════════════════
func _on_restaurar_posiciones() -> void:
	Global.reset_offsets_controles()
	if _escena_actual == null:
		return
	for nombre in NODOS_ESCALABLES:
		var encontrados : Array = []
		_buscar_nodos_por_nombre(_escena_actual, nombre, encontrados)
		for nodo in encontrados:
			if nodo is Control and nodo.has_meta("pos_original"):
				nodo.global_position = nodo.get_meta("pos_original")


# ═════════════════════════════════════════════════════════════════════════════
#  FOTO DE PERFIL  —  toda la lógica delegada a AvatarUtil
#  Antes: ~90 líneas duplicadas de main_menu.gd. Ahora: ~25 líneas.
# ═════════════════════════════════════════════════════════════════════════════
func _seleccionar_avatar_juego(path: String) -> void:
	var tex := ResourceLoader.load(path) as Texture2D
	AvatarUtil.aplicar_como_avatar(tex, path, avatar_preview)
	_abrir_opciones()

func _actualizar_preview_avatar() -> void:
	if Global.player_avatar_texture != null:
		avatar_preview.texture = Global.player_avatar_texture
	elif ResourceLoader.exists(AVATARES_JUEGO[0]):
		avatar_preview.texture = ResourceLoader.load(AVATARES_JUEGO[0]) as Texture2D

func _on_examinar_presionado() -> void:
	if OS.get_name() == "Android":
		OS.request_permissions()
	# ← Antes: 12 líneas de FileDialog setup duplicadas. Ahora:
	_file_dialog = AvatarUtil.abrir_file_dialog(self, _on_archivo_seleccionado)

func _on_archivo_seleccionado(path: String) -> void:
	_imagen_dispositivo              = AvatarUtil.cargar_imagen_archivo(path)
	vista_previa_dispositivo.texture = _imagen_dispositivo
	boton_usar_imagen.visible        = _imagen_dispositivo != null

func _on_usar_imagen_dispositivo() -> void:
	AvatarUtil.aplicar_como_avatar(_imagen_dispositivo, "dispositivo", avatar_preview)
	boton_usar_imagen.visible = false
	_abrir_opciones()

extends Control
## main_menu.gd  —  Tutorial 2.0
## Duplicaciones eliminadas → toda la lógica de avatar circular vive
## en AvatarUtil (Scripts/AvatarUtil.gd).

# ─────────────────────────────────────────────────────────────────────────────
#  REFERENCIAS A NODOS
# ─────────────────────────────────────────────────────────────────────────────
@onready var panel_perfil         : Panel        = $PanelPerfil
@onready var contenedor_avatar    : Panel        = $PanelPerfil/ContenedorAvatar
@onready var textura_avatar       : TextureRect  = $PanelPerfil/ContenedorAvatar/TexturaAvatar
@onready var boton_cambiar_avatar : BaseButton   = $PanelPerfil/BotonCambiarAvatar
@onready var input_nombre         : LineEdit     = $PanelPerfil/InputNombre

@onready var boton_jugar   : BaseButton = $ContenedorCentro/BotonJugar
@onready var boton_ajustes : BaseButton = $ContenedorCentro/BotonAjustes
@onready var boton_salir   : BaseButton = $ContenedorCentro/BotonSalir

@onready var overlay             : ColorRect    = $Overlay
@onready var selector_avatar     : Panel        = $SelectorAvatar
@onready var grid_avatares       : GridContainer = $SelectorAvatar/MargenSelector/ColumnaSelector/Pestañas/Predeterminados/GridAvatares
@onready var btn_cerrar_selector : BaseButton   = $SelectorAvatar/MargenSelector/ColumnaSelector/CabeceraSelector/BotonCerrarSelector
@onready var vista_previa        : TextureRect  = $SelectorAvatar/MargenSelector/ColumnaSelector/Pestañas/Dispositivo/VistaPrevia
@onready var boton_examinar      : BaseButton   = $SelectorAvatar/MargenSelector/ColumnaSelector/Pestañas/Dispositivo/BotonExaminar
@onready var boton_usar_imagen   : BaseButton   = $SelectorAvatar/MargenSelector/ColumnaSelector/Pestañas/Dispositivo/BotonUsarImagen

@onready var panel_ajustes      : Panel      = $PanelAjustes
@onready var btn_cerrar_ajustes : BaseButton = $PanelAjustes/MargenAjustes/ColumnaAjustes/CabeceraAjustes/BotonCerrarAjustes
@onready var slider_musica      : HSlider    = $PanelAjustes/MargenAjustes/ColumnaAjustes/FilaMusica/SliderMusica
@onready var slider_sfx         : HSlider    = $PanelAjustes/MargenAjustes/ColumnaAjustes/FilaSFX/SliderSFX

# ─────────────────────────────────────────────────────────────────────────────
#  CONSTANTES
# ─────────────────────────────────────────────────────────────────────────────
const AVATARES_JUEGO : Array[String] = [
	"res://Assets/avatares_default/portrait.png"
]

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO INTERNO
# ─────────────────────────────────────────────────────────────────────────────
var _imagen_dispositivo : Texture2D  = null
var _file_dialog        : FileDialog = null
var _tween_activo       : Tween      = null
var _toggle_shader    : CheckButton = null
var _toggle_contador  : CheckButton = null
var _slider_tamano    : HSlider     = null

# ─────────────────────────────────────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_configurar_panel_perfil()
	# ← Antes: 20 líneas de shader + ShaderMaterial inline. Ahora: una línea.
	AvatarUtil.aplicar_shader_circular(textura_avatar)
	_estilizar_popups()
	# ← Antes: 40 líneas de _cargar_avatares_predefinidos(). Ahora: una línea.
	AvatarUtil.poblar_grid(grid_avatares, AVATARES_JUEGO, 84, _seleccionar_avatar_juego)
	_cargar_datos_jugador()
	_extender_panel_ajustes()
	_conectar_señales()
	_conectar_feedback_botones()
	Global.play_music()
	_animar_entrada()
	print("✅ MainMenu listo — Jugador: ", Global.player_name)


# ─────────────────────────────────────────────────────────────────────────────
#  ANIMACIÓN DE ENTRADA
# ─────────────────────────────────────────────────────────────────────────────
func _animar_entrada() -> void:
	modulate.a = 0.0
	var pos_perfil_original  := panel_perfil.position
	var pos_botones_original := contenedor_centro_ref().position

	panel_perfil.position.x            -= 220.0
	contenedor_centro_ref().position.y += 160.0

	var tw := create_tween().set_parallel(false)
	tw.tween_property(self, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.set_parallel(true)
	tw.tween_property(panel_perfil, "position:x",
		pos_perfil_original.x, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05)
	tw.tween_property(contenedor_centro_ref(), "position:y",
		pos_botones_original.y, 0.50) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)

func contenedor_centro_ref() -> Control:
	return $ContenedorCentro


# ─────────────────────────────────────────────────────────────────────────────
#  CONFIGURACIÓN VISUAL
# ─────────────────────────────────────────────────────────────────────────────
func _configurar_panel_perfil() -> void:
	panel_perfil.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	contenedor_avatar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _estilizar_popups() -> void:
	var COLOR_BORDE := Color(0.42, 0.28, 0.72, 0.75)
	var COLOR_POPUP := Color(0.07, 0.05, 0.15, 0.97)

	_set_panel_style(selector_avatar, COLOR_POPUP, COLOR_BORDE, 12)
	_set_panel_style(panel_ajustes,   COLOR_POPUP, COLOR_BORDE, 12)

	_set_boton_pequeño(btn_cerrar_selector)
	_set_boton_pequeño(btn_cerrar_ajustes)
	_set_boton_pequeño(boton_examinar)
	_set_boton_pequeño(boton_usar_imagen)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.05, 0.16, 1.0)
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = COLOR_BORDE
	s.content_margin_left  = 8
	s.content_margin_right = 8
	s.content_margin_top    = 5
	s.content_margin_bottom = 5
	input_nombre.add_theme_stylebox_override("normal", s)
	input_nombre.add_theme_stylebox_override("focus",  s)
	input_nombre.add_theme_color_override("font_color",             Color.WHITE)
	input_nombre.add_theme_color_override("font_placeholder_color", Color(0.5, 0.45, 0.65))
	input_nombre.add_theme_color_override("caret_color",            Color(0.72, 0.48, 1.00))
	input_nombre.add_theme_color_override("selection_color",        Color(0.4, 0.28, 0.7, 0.6))
	input_nombre.add_theme_font_size_override("font_size", 12)


# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS DE ESTILO
# ─────────────────────────────────────────────────────────────────────────────
func _set_panel_style(panel: Panel, bg: Color, borde: Color, radio: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radio)
	s.set_border_width_all(1)
	s.border_color = borde
	panel.add_theme_stylebox_override("panel", s)

func _set_boton_pequeño(boton: BaseButton) -> void:
	var mk := func(c: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(6)
		s.set_border_width_all(1)
		s.border_color = Color(0.5, 0.35, 0.8, 0.8)
		return s
	boton.add_theme_stylebox_override("normal", mk.call(Color(0.16, 0.10, 0.30, 0.9)))
	boton.add_theme_stylebox_override("hover",  mk.call(Color(0.28, 0.18, 0.50, 0.95)))
	boton.add_theme_color_override("font_color",       Color(0.92, 0.88, 1.00))
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_font_size_override("font_size", 13)


# ─────────────────────────────────────────────────────────────────────────────
#  DATOS DEL JUGADOR
# ─────────────────────────────────────────────────────────────────────────────
func _cargar_datos_jugador() -> void:
	input_nombre.text = Global.player_name

	if Global.player_avatar_texture != null:
		textura_avatar.texture = Global.player_avatar_texture
	elif ResourceLoader.exists(AVATARES_JUEGO[0]):
		var tex := ResourceLoader.load(AVATARES_JUEGO[0]) as Texture2D
		if tex:
			textura_avatar.texture       = tex
			Global.player_avatar_texture = tex

	if Global.music_player != null:
		slider_musica.value = clampf(db_to_linear(Global.music_player.volume_db), 0.0, 1.0)
	slider_sfx.value = Global.sfx_volumen

func _guardar_nombre() -> void:
	var nombre := input_nombre.text.strip_edges()
	if nombre.is_empty():
		nombre = "Jugador"
		input_nombre.text = nombre
	Global.player_name = nombre
	Global.guardar_perfil()


# ─────────────────────────────────────────────────────────────────────────────
#  SEÑALES
# ─────────────────────────────────────────────────────────────────────────────
func _conectar_señales() -> void:
	boton_jugar.pressed.connect(_on_jugar)
	boton_ajustes.pressed.connect(_on_abrir_ajustes)
	boton_salir.pressed.connect(_on_salir)

	boton_cambiar_avatar.pressed.connect(_on_abrir_selector)
	input_nombre.text_submitted.connect(func(_t): _guardar_nombre())
	input_nombre.focus_exited.connect(_guardar_nombre)

	btn_cerrar_selector.pressed.connect(_cerrar_selector)
	boton_examinar.pressed.connect(_abrir_file_dialog)
	boton_usar_imagen.pressed.connect(_on_usar_imagen_dispositivo)

	overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_cerrar_todos_popups()
	)

	btn_cerrar_ajustes.pressed.connect(_cerrar_ajustes)
	slider_musica.value_changed.connect(_on_volumen_musica)
	slider_sfx.value_changed.connect(_on_volumen_sfx)


# ─────────────────────────────────────────────────────────────────────────────
#  FEEDBACK TÁCTIL
# ─────────────────────────────────────────────────────────────────────────────
func _conectar_feedback_botones() -> void:
	for btn in [boton_jugar, boton_ajustes, boton_salir, boton_cambiar_avatar]:
		btn.button_down.connect(_animar_press.bind(btn))
		btn.button_up.connect(_animar_release.bind(btn))

func _animar_press(btn: Control) -> void:
	SFX.play("ui_click")
	if _tween_activo:
		_tween_activo.kill()
	_tween_activo = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_activo.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.08)
	_tween_activo.tween_property(btn, "pivot_offset", btn.size / 2.0, 0.0)

func _animar_release(btn: Control) -> void:
	if _tween_activo:
		_tween_activo.kill()
	_tween_activo = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween_activo.tween_property(btn, "scale", Vector2.ONE, 0.35)


# ─────────────────────────────────────────────────────────────────────────────
#  BOTONES PRINCIPALES
# ─────────────────────────────────────────────────────────────────────────────
func _on_jugar() -> void:
	_guardar_nombre()
	EnemyPool.limpiar_pool()
	SceneTransition.ir_a("res://Scenes/mundo.tscn")

func _on_salir() -> void:
	_guardar_nombre()
	get_tree().quit()


# ─────────────────────────────────────────────────────────────────────────────
#  SELECTOR DE AVATAR
# ─────────────────────────────────────────────────────────────────────────────
func _on_abrir_selector() -> void:
	_cerrar_todos_popups()
	overlay.visible         = true
	selector_avatar.visible = true

func _cerrar_selector() -> void:
	overlay.visible           = false
	selector_avatar.visible   = false
	boton_usar_imagen.visible = false
	_imagen_dispositivo       = null

func _seleccionar_avatar_juego(path: String) -> void:
	# ← Antes: 8 líneas inline. Ahora: delegamos a AvatarUtil.
	AvatarUtil.aplicar_como_avatar(
		ResourceLoader.load(path) as Texture2D, path, textura_avatar)
	_cerrar_selector()

func _abrir_file_dialog() -> void:
	# ← Antes: 12 líneas de FileDialog setup duplicadas. Ahora: una línea.
	_file_dialog = AvatarUtil.abrir_file_dialog(self, _on_archivo_seleccionado)

func _on_archivo_seleccionado(path: String) -> void:
	_imagen_dispositivo       = AvatarUtil.cargar_imagen_archivo(path)
	vista_previa.texture      = _imagen_dispositivo
	boton_usar_imagen.visible = _imagen_dispositivo != null

func _on_usar_imagen_dispositivo() -> void:
	AvatarUtil.aplicar_como_avatar(_imagen_dispositivo, "dispositivo", textura_avatar)
	_cerrar_selector()



# ─────────────────────────────────────────────────────────────────────────────
#  AJUSTES — PANEL EXTENDIDO
#  Añade a los sliders de volumen existentes los mismos controles del pause
#  menu: tamaño de botones, toggle shader, toggle contador de muertes.
# ─────────────────────────────────────────────────────────────────────────────
func _extender_panel_ajustes() -> void:
	var col := panel_ajustes.get_node_or_null(
		"MargenAjustes/ColumnaAjustes") as VBoxContainer
	if col == null:
		push_warning("MainMenu: ColumnaAjustes no encontrado — ajusta la ruta si tu tscn difiere")
		return

	col.add_child(HSeparator.new())

	# ── Tamaño de botones de control ──────────────────────────────────────
	var lbl_tam := Label.new()
	lbl_tam.text = "🎮  Tamaño de botones"
	col.add_child(lbl_tam)
	_slider_tamano = HSlider.new()
	_slider_tamano.min_value = 0.6
	_slider_tamano.max_value = 1.6
	_slider_tamano.step      = 0.05
	_slider_tamano.value     = Global.ui_scale_botones
	_slider_tamano.custom_minimum_size = Vector2(0, 28)
	_slider_tamano.value_changed.connect(func(v): Global.set_ui_scale_botones(v))
	col.add_child(_slider_tamano)

	col.add_child(HSeparator.new())

	# ── Toggle efectos visuales (shader) ──────────────────────────────────
	var fila_sh := HBoxContainer.new()
	fila_sh.add_theme_constant_override("separation", 12)
	col.add_child(fila_sh)
	var lbl_sh := Label.new()
	lbl_sh.text = "✨  Efectos visuales (shader)"
	lbl_sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_sh.add_child(lbl_sh)
	_toggle_shader = CheckButton.new()
	_toggle_shader.button_pressed = Global.postprocess_activo
	_toggle_shader.focus_mode = Control.FOCUS_NONE
	_toggle_shader.toggled.connect(func(v: bool) -> void:
		Global.postprocess_activo = v
		Global.guardar_perfil()
		if has_node("/root/PostProcess"):
			get_node("/root/PostProcess").set_activo(v))
	fila_sh.add_child(_toggle_shader)

	# ── Toggle contador de muertes ────────────────────────────────────────
	var fila_cnt := HBoxContainer.new()
	fila_cnt.add_theme_constant_override("separation", 12)
	col.add_child(fila_cnt)
	var lbl_cnt := Label.new()
	lbl_cnt.text = "💀  Mostrar contador de muertes"
	lbl_cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_cnt.add_child(lbl_cnt)
	_toggle_contador = CheckButton.new()
	_toggle_contador.button_pressed = Global.show_death_counter
	_toggle_contador.focus_mode = Control.FOCUS_NONE
	_toggle_contador.toggled.connect(func(v: bool): Global.set_show_death_counter(v))
	fila_cnt.add_child(_toggle_contador)

# ─────────────────────────────────────────────────────────────────────────────
#  AJUSTES
# ─────────────────────────────────────────────────────────────────────────────
func _on_abrir_ajustes() -> void:
	_guardar_nombre()
	_cerrar_todos_popups()
	overlay.visible       = true
	panel_ajustes.visible = true
	if _toggle_shader   != null: _toggle_shader.button_pressed   = Global.postprocess_activo
	if _toggle_contador != null: _toggle_contador.button_pressed = Global.show_death_counter
	if _slider_tamano   != null: _slider_tamano.value            = Global.ui_scale_botones

func _cerrar_ajustes() -> void:
	overlay.visible       = false
	panel_ajustes.visible = false

func _on_volumen_musica(valor: float) -> void:
	if Global.music_player != null:
		Global.music_player.volume_db = linear_to_db(maxf(valor, 0.0001))
	Global.musica_volumen = valor
	Global.guardar_perfil()

func _on_volumen_sfx(valor: float) -> void:
	Global.sfx_volumen = valor
	Global.guardar_perfil()

func _cerrar_todos_popups() -> void:
	overlay.visible         = false
	selector_avatar.visible = false
	panel_ajustes.visible   = false

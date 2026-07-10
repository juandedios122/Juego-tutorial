extends Control
## boton_ataque.gd
## Usa el MISMO patrón de joystick.gd: _input() de bajo nivel con
## seguimiento explícito de touch_index, en vez de depender de gui_input.
## Esto garantiza que mover (joystick, dedo A) y atacar (este botón, dedo B)
## funcionen de forma realmente independiente y simultánea, sin importar
## cómo Godot dispatchee gui_input internamente.
##
## ── Cooldown visual ──────────────────────────────────────────────────────
## Cuando jugador.gd empieza un swing, emite Global.player_attack_started
## con la duración del golpe. Este script:
##   1. Bloquea el botón (ignora toques) durante ese tiempo, para no mandar
##      un segundo ataque mientras la animación todavía se está viendo.
##   2. Pinta el botón con un shader (cooldown_wipe.gdshader) que lo pone
##      gris y va "subiendo" el color normal desde abajo hasta llenarlo por
##      completo cuando el cooldown termina.

var is_pressing : bool = false

# -1 = nadie tocando · -2 = se está usando el mouse (para probar en PC)
# >=0 = índice del dedo que está tocando el botón
var touch_index : int = -1

# true mientras el botón está bloqueado esperando a que termine el swing.
var _en_cooldown : bool = false

var _mat_recarga : ShaderMaterial = null

@onready var boton : TextureRect = $Button


func _ready() -> void:
	_preparar_shader_recarga()
	Global.player_attack_started.connect(_on_player_attack_started)


## La escena (boton_ataque.tscn) todavía tiene conectada la señal
## "gui_input" del TextureRect a este método por compatibilidad.
## Ya no se usa para la lógica (ver _input() más abajo), pero lo dejamos
## vacío para no tener que tocar la escena en el editor.
func _on_button_gui_input(_event: InputEvent) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_manejar_touch(event)
	elif event is InputEventScreenDrag:
		# Si el dedo se arrastra fuera del botón mientras lo sostiene, se suelta
		# (evita ataques "fantasma" si el jugador desliza el dedo afuera).
		if is_pressing and touch_index == event.index:
			if not boton.get_global_rect().has_point(event.position):
				_soltar()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_manejar_mouse(event)


func _manejar_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _en_cooldown:
			return
		# Solo capturar si el botón está libre y el toque cae dentro de su rect.
		if touch_index == -1 and boton.get_global_rect().has_point(event.position):
			touch_index = event.index
			_presionar()
			get_viewport().set_input_as_handled()
	else:
		# Solo soltar si es el MISMO dedo que lo presionó.
		if touch_index == event.index:
			_soltar()
			get_viewport().set_input_as_handled()


func _manejar_mouse(event: InputEventMouseButton) -> void:
	if event.pressed:
		if _en_cooldown:
			return
		if touch_index == -1 and boton.get_global_rect().has_point(event.position):
			touch_index = -2
			_presionar()
	else:
		if touch_index == -2:
			_soltar()


func _presionar() -> void:
	is_pressing = true
	boton.modulate = Color(0.6, 0.6, 0.6, 1.0)

	var action_press := InputEventAction.new()
	action_press.action  = "Attack"
	action_press.pressed = true
	Input.parse_input_event(action_press)


func _soltar() -> void:
	is_pressing  = false
	touch_index  = -1
	boton.modulate = Color(1, 1, 1, 1.0)

	# ✅ Envía el RELEASE del action para que Godot limpie el estado
	# y el próximo just_pressed funcione (mismo fix que ya tenías).
	var action_release := InputEventAction.new()
	action_release.action  = "Attack"
	action_release.pressed = false
	Input.parse_input_event(action_release)


# ─────────────────────────────────────────────────────────────────────────────
#  COOLDOWN VISUAL — barrido gris sobre el ícono del botón
# ─────────────────────────────────────────────────────────────────────────────
func _preparar_shader_recarga() -> void:
	var shader := ResourceLoader.load("res://Shaders/cooldown_wipe.gdshader") as Shader
	if shader == null:
		push_warning("BotonAtaque: no se encontró Shaders/cooldown_wipe.gdshader")
		return
	_mat_recarga = ShaderMaterial.new()
	_mat_recarga.shader = shader
	_mat_recarga.set_shader_parameter("progreso", 1.0)
	boton.material = _mat_recarga


func _on_player_attack_started(duracion: float) -> void:
	_en_cooldown = true

	if _mat_recarga == null:
		# Sin shader no hay feedback visual, pero el bloqueo del botón
		# (arriba) sigue funcionando igual.
		await get_tree().create_timer(duracion).timeout
		_en_cooldown = false
		return

	_mat_recarga.set_shader_parameter("progreso", 0.0)

	var tween := create_tween()
	tween.tween_method(_actualizar_progreso, 0.0, 1.0, duracion)
	tween.tween_callback(func(): _en_cooldown = false)


func _actualizar_progreso(valor: float) -> void:
	if _mat_recarga != null:
		_mat_recarga.set_shader_parameter("progreso", valor)

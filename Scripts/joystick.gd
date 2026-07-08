extends Control

@export var handle_texture: Texture2D
@export var background_texture: Texture2D
@export var max_radius: float = 60.0
@export var deadzone: float = 0.1

var is_pressed: bool = false
var touch_index: int = -1
var output: Vector2 = Vector2.ZERO

@onready var background = $Background
@onready var handle = $Handle

func _ready():
	if handle_texture:
		handle.texture = handle_texture
	if background_texture:
		background.texture = background_texture

	await get_tree().process_frame
	_reset_joystick()
	print("✅ Joystick listo. Rect global: ", get_global_rect())

func _get_center() -> Vector2:
	return get_global_rect().get_center()

func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		var touch_pos = event.position

		if event.pressed:
			# Solo capturar si no hay otro dedo ya en el joystick
			if get_global_rect().has_point(touch_pos) and touch_index == -1:
				is_pressed = true
				touch_index = event.index
				_update_joystick(touch_pos)
				get_viewport().set_input_as_handled()

		else:
			# ✅ FIX: Verificar que sea el mismo dedo que inició el joystick
			if touch_index == event.index:
				is_pressed = false
				touch_index = -1
				# ✅ FIX: Limpiar output INMEDIATAMENTE y de forma explícita
				# para que el jugador no siga caminando
				output = Vector2.ZERO
				_reset_joystick()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		# ✅ FIX: Verificar ambas condiciones antes de mover el handle
		if is_pressed and touch_index == event.index:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()

func _update_joystick(touch_pos: Vector2):
	var center = _get_center()
	var direction = touch_pos - center
	var distance = direction.length()

	if distance > max_radius:
		direction = direction.normalized() * max_radius

	# Aplicar deadzone: si está muy cerca del centro, output = cero
	if distance < max_radius * deadzone:
		output = Vector2.ZERO
	else:
		output = direction.normalized()

	# Mover el handle visualmente
	var offset = direction
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius

	handle.position = background.size / 2 - handle.size / 2 + offset

func _reset_joystick():
	# ✅ FIX: Siempre limpiar output aquí también para doble seguridad
	output = Vector2.ZERO
	handle.position = background.size / 2 - handle.size / 2

func get_vector() -> Vector2:
	return output

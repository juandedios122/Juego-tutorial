extends Node
## VFX.gd  —  Autoload Singleton
## Sistema centralizado de efectos visuales: screen shake, partículas de
## impacto y explosión de muerte. Usa dust_particles_01.png (el asset huérfano
## que existía en el proyecto sin estar referenciado en ningún script).
##
## Añade al Autoload en Project → Project Settings → Autoload:
##   Nombre: VFX    Ruta: res://Scripts/VFX.gd
##
## Uso desde cualquier script:
##   VFX.golpe(posicion_global)         # partículas de impacto
##   VFX.muerte(posicion_global, color) # explosión de muerte
##   VFX.shake(intensidad, duracion)    # screen shake

const DUST_TEXTURE_PATH := "res://Assets/sprites/particles/dust_particles_01.png"

# Cuántas partículas por evento
const N_GOLPE  : int = 6
const N_MUERTE : int = 12

var _camera      : Camera2D = null
var _shake_tween : Tween    = null
var _cam_offset_base : Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# La cámara puede no existir aún — la buscamos lazy en el primer shake.

# ─────────────────────────────────────────────────────────────────────────────
#  SCREEN SHAKE
# ─────────────────────────────────────────────────────────────────────────────

## Agita la cámara.
## intensidad: píxeles máximos de desplazamiento (recomendado 3–8 para golpe,
##             10–18 para muerte).
## duracion: segundos que dura el shake (recomendado 0.15–0.35).
func shake(intensidad: float = 5.0, duracion: float = 0.20) -> void:
	_encontrar_camara()
	if _camera == null:
		return

	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var pasos := int(duracion / 0.04)

	for i in range(pasos):
		var fuerza := intensidad * (1.0 - float(i) / pasos)
		var target := Vector2(
			randf_range(-fuerza, fuerza),
			randf_range(-fuerza, fuerza)
		)
		_shake_tween.tween_property(_camera, "offset", _cam_offset_base + target, 0.04)

	# Volver al reposo
	_shake_tween.tween_property(_camera, "offset", _cam_offset_base, 0.06)

func _encontrar_camara() -> void:
	if is_instance_valid(_camera):
		return
	var arbol := get_tree()
	if arbol == null:
		return
	var camaras := arbol.get_nodes_in_group("cameras")
	if not camaras.is_empty():
		_camera = camaras[0] as Camera2D
		return
	# Fallback: buscar cualquier Camera2D activa en la escena actual
	var escena := arbol.current_scene
	if escena == null:
		return
	for nodo in escena.find_children("*", "Camera2D", true, false):
		var cam := nodo as Camera2D
		if cam != null and cam.enabled:
			_camera = cam
			_cam_offset_base = cam.offset
			return

# ─────────────────────────────────────────────────────────────────────────────
#  PARTÍCULAS DE IMPACTO (golpe de espada o recibir daño)
# ─────────────────────────────────────────────────────────────────────────────

## Emite partículas de polvo/impacto en `pos` (coordenadas globales).
## color_override: si no es Color(0,0,0,0) modula las partículas con ese color.
func golpe(pos: Vector2, color_override: Color = Color(0, 0, 0, 0)) -> void:
	_emitir_particulas(pos, N_GOLPE, 28.0, 0.30, 0.45, color_override)
	shake(4.0, 0.12)

## Emite una explosión de partículas al morir un enemigo.
func muerte(pos: Vector2, color_override: Color = Color(0, 0, 0, 0)) -> void:
	_emitir_particulas(pos, N_MUERTE, 50.0, 0.45, 0.70, color_override)
	shake(9.0, 0.28)

# ─────────────────────────────────────────────────────────────────────────────
#  SISTEMA DE PARTÍCULAS (puro código — sin .tscn, sin .tres)
#  Cada partícula es un Sprite2D lanzado con un Tween y liberado al terminar.
# ─────────────────────────────────────────────────────────────────────────────
func _emitir_particulas(
		pos         : Vector2,
		cantidad    : int,
		velocidad   : float,
		vida_min    : float,
		vida_max    : float,
		color       : Color) -> void:

	var escena := get_tree().current_scene
	if escena == null:
		return

	var tex := ResourceLoader.load(DUST_TEXTURE_PATH) as Texture2D
	if tex == null:
		push_warning("VFX: No se pudo cargar " + DUST_TEXTURE_PATH)
		return

	for _i in range(cantidad):
		var sprite := Sprite2D.new()
		sprite.texture        = tex
		sprite.global_position = pos
		sprite.z_index        = 50

		if color != Color(0, 0, 0, 0):
			sprite.modulate = color

		var escala_base := randf_range(0.5, 1.2)
		sprite.scale = Vector2.ONE * escala_base
		escena.add_child(sprite)

		var angulo    := randf() * TAU
		var fuerza    := randf_range(velocidad * 0.5, velocidad)
		var vel       := Vector2(cos(angulo), sin(angulo)) * fuerza
		var vida      := randf_range(vida_min, vida_max)
		var destino   := pos + vel * vida

		var tw := sprite.create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "global_position", destino, vida)
		tw.tween_property(sprite, "scale",
			Vector2.ONE * escala_base * randf_range(0.1, 0.4), vida)
		tw.tween_property(sprite, "modulate:a", 0.0, vida * 0.85) \
			.set_delay(vida * 0.15)
		tw.tween_property(sprite, "rotation",
			sprite.rotation + randf_range(-PI, PI), vida)
		tw.finished.connect(sprite.queue_free)

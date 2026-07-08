extends CanvasLayer
## SceneTransition.gd  —  Autoload
## ══════════════════════════════════════════════════════════════
##  Uso desde cualquier script:
##      SceneTransition.ir_a("res://Scenes/mundo.tscn")
##
##  Reemplaza todos los get_tree().change_scene_to_file(...)
##  con un fade negro suave de entrada y salida.
## ══════════════════════════════════════════════════════════════

const DURACION_FADE := 0.30   # segundos por fade (entrada + salida)

var _rect  : ColorRect
var _tween : Tween
var _ocupado := false

## Emitida justo después del fade-out (nueva escena ya visible).
## PauseManager se conecta a esto en vez de comprobar current_scene en _process.
signal escena_cambiada

func _ready() -> void:
	# CanvasLayer en la capa más alta para cubrir todo
	layer = 128

	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.modulate.a = 0.0
	add_child(_rect)

	# Fade-in de salida al iniciar (la primera escena aparece suavemente)
	_fade_out()


## Cambia de escena con fade negro de entrada y salida
func ir_a(ruta: String) -> void:
	if _ocupado:
		return
	_ocupado = true

	# 1) Fade a negro
	await _fade_in()

	# 2) Cambiar escena
	get_tree().change_scene_to_file(ruta)
	await get_tree().process_frame

	# 3) Salir del negro
	await _fade_out()
	_ocupado = false
	escena_cambiada.emit()   # sin argumentos — compatible con _on_cambio_escena()


# ─── Helpers ────────────────────────────────────────────────────────────────
func _fade_in() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_rect, "modulate:a", 1.0, DURACION_FADE)
	await _tween.finished


func _fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_rect, "modulate:a", 0.0, DURACION_FADE)
	await _tween.finished

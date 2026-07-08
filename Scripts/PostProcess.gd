extends CanvasLayer
## PostProcess.gd  —  Autoload Singleton
##
## Añade este script a Project → Project Settings → Autoload con el nombre
## "PostProcess" y la ruta "res://Scripts/PostProcess.gd".
##
## Se sienta en layer 5, por encima del mundo del juego (layer 0) pero por
## debajo del HUD (layer 10) y los menús (layer 100), de modo que unifica
## visualmente los sprites del juego sin tocar la interfaz.
##
## Para ajustar los parámetros en tiempo real desde el menú de pausa,
## llama a PostProcess.set_param("pixel_size", 2.0) etc.

const SHADER_PATH := "res://Shaders/post_process.gdshader"

# Valores por defecto (se cargan del perfil en _ready)
var _params := {
	"pixel_size"      : 2.0,
	"palette_steps"   : 10.0,
	"enable_palette"  : true,
	"saturation"      : 1.18,
	"contrast"        : 1.08,
	"vignette_amount" : 0.30,
}

var _rect   : ColorRect      = null
var _mat    : ShaderMaterial  = null
var _activo : bool            = true

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer        = 5                         # entre el mundo y el HUD
	process_mode = Node.PROCESS_MODE_ALWAYS  # no se pausa con get_tree().paused

	var shader := ResourceLoader.load(SHADER_PATH) as Shader
	if shader == null:
		push_error("PostProcess: no se encontró el shader en '%s'. " % SHADER_PATH +
				   "Asegúrate de que el archivo existe en res://Shaders/.")
		return

	_mat        = ShaderMaterial.new()
	_mat.shader = shader

	_rect = ColorRect.new()
	_rect.name = "PostProcessRect"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material    = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	_aplicar_todos_los_params()

	# Respetar preferencias guardadas si Global ya cargó el perfil
	if Global.has_method("get") and "postprocess_activo" in Global:
		_activo = Global.get("postprocess_activo")
	_rect.visible = _activo

	print("✅ PostProcess iniciado (layer 5, activo=%s)" % str(_activo))

# ─────────────────────────────────────────────────────────────────────────────
#  API PÚBLICA
# ─────────────────────────────────────────────────────────────────────────────

## Activa o desactiva el efecto completo (útil para toggle en opciones).
func set_activo(valor: bool) -> void:
	_activo = valor
	if _rect:
		_rect.visible = valor

## Ajusta un parámetro del shader por nombre.
## Nombres válidos: "pixel_size", "palette_steps", "enable_palette",
##                  "saturation", "contrast", "vignette_amount"
func set_param(nombre: String, valor) -> void:
	if nombre not in _params:
		push_warning("PostProcess.set_param: parámetro desconocido '%s'" % nombre)
		return
	_params[nombre] = valor
	if _mat:
		_mat.set_shader_parameter(nombre, valor)

## Devuelve el valor actual de un parámetro.
func get_param(nombre: String):
	return _params.get(nombre)

## Resetea todos los parámetros a los valores por defecto.
func reset_params() -> void:
	_params = {
		"pixel_size"      : 2.0,
		"palette_steps"   : 10.0,
		"enable_palette"  : true,
		"saturation"      : 1.18,
		"contrast"        : 1.08,
		"vignette_amount" : 0.30,
	}
	_aplicar_todos_los_params()

# ─────────────────────────────────────────────────────────────────────────────
#  PRIVADO
# ─────────────────────────────────────────────────────────────────────────────
func _aplicar_todos_los_params() -> void:
	if _mat == null:
		return
	for nombre in _params:
		_mat.set_shader_parameter(nombre, _params[nombre])

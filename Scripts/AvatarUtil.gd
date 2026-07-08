class_name AvatarUtil
extends RefCounted
## AvatarUtil — Componente reutilizable de selección de avatar circular.
##
## Antes: SHADER_CIRCULO, _cargar_avatares_predefinidos(), _abrir_file_dialog(),
##        _on_archivo_seleccionado() y _on_usar_imagen_dispositivo() estaban
##        copiados casi línea por línea en main_menu.gd Y en pause_manager.gd.
##
## Ahora: todas esas responsabilidades viven aquí una sola vez.
## Uso:
##   AvatarUtil.aplicar_shader_circular(mi_texrect)
##   AvatarUtil.poblar_grid(grid, paths, 78, _on_avatar_elegido)
##   AvatarUtil.abrir_file_dialog(self, _on_imagen_de_archivo)


# ─────────────────────────────────────────────────────────────────────────────
#  SHADER  (fuente única de verdad — ya no se duplica)
# ─────────────────────────────────────────────────────────────────────────────
const SHADER_CIRCULO := """
shader_type canvas_item;
void fragment() {
\tvec2 uv = UV - vec2(0.5);
\tif (length(uv) > 0.48) discard;
\tCOLOR = texture(TEXTURE, UV);
}
"""

const _COLOR_BORDE_AVATAR := Color(0.50, 0.35, 0.80)
const _COLOR_BTN_NORMAL   := Color(0.12, 0.08, 0.22)
const _COLOR_BTN_HOVER    := Color(0.28, 0.18, 0.50)
const _COLOR_BTN_PRESS    := Color(0.40, 0.26, 0.68)


# ─────────────────────────────────────────────────────────────────────────────
#  SHADER MATERIAL
# ─────────────────────────────────────────────────────────────────────────────

## Devuelve un ShaderMaterial nuevo con el shader circular listo para usar.
static func crear_material_circular() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER_CIRCULO
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

## Aplica el shader circular directamente a un TextureRect.
## Úsalo para el avatar principal del perfil del jugador.
static func aplicar_shader_circular(texrect: TextureRect) -> void:
	texrect.material = crear_material_circular()


# ─────────────────────────────────────────────────────────────────────────────
#  BOTÓN DE AVATAR
# ─────────────────────────────────────────────────────────────────────────────

## Crea un Button circular que muestra la textura en `path`.
## Devuelve null si el path no existe o no se puede cargar.
## `on_press` es un Callable sin argumentos que se conecta a `pressed`.
static func crear_boton_avatar(path: String, tamano: int,
								on_press: Callable) -> Button:
	if not ResourceLoader.exists(path):
		return null
	var tex := ResourceLoader.load(path) as Texture2D
	if tex == null:
		return null

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(tamano, tamano)
	btn.focus_mode          = Control.FOCUS_NONE
	btn.clip_children = Control.CLIP_CHILDREN_ONLY

	var img := TextureRect.new()
	img.texture      = tex
	img.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.material     = crear_material_circular()
	btn.add_child(img)

	@warning_ignore("integer_division")
	var radio : int = tamano / 2  # división entera intencional
	var mk := func(c: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(radio)
		s.set_border_width_all(2)
		s.border_color = _COLOR_BORDE_AVATAR
		return s
	btn.add_theme_stylebox_override("normal",  mk.call(_COLOR_BTN_NORMAL))
	btn.add_theme_stylebox_override("hover",   mk.call(_COLOR_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", mk.call(_COLOR_BTN_PRESS))

	btn.pressed.connect(on_press)
	return btn


# ─────────────────────────────────────────────────────────────────────────────
#  GRID DE AVATARES
# ─────────────────────────────────────────────────────────────────────────────

## Rellena `grid` con un botón circular por cada path en `paths`.
## Limpia los hijos previos del grid antes de poblar.
## `on_seleccion` recibe el path elegido como String.
static func poblar_grid(grid: GridContainer, paths: Array[String],
						 tamano: int, on_seleccion: Callable) -> void:
	for child in grid.get_children():
		child.queue_free()

	for path in paths:
		var cap := path   # captura local del closure
		var btn := crear_boton_avatar(path, tamano,
			func(): on_seleccion.call(cap))
		if btn != null:
			grid.add_child(btn)


# ─────────────────────────────────────────────────────────────────────────────
#  FILE DIALOG  (selector de imagen del dispositivo)
# ─────────────────────────────────────────────────────────────────────────────

## Abre un FileDialog para que el jugador elija una imagen del dispositivo.
## `parent_node` se usa como padre del diálogo (necesario para que sea visible).
## `on_archivo_seleccionado(path: String)` se llama al confirmar la imagen.
## Devuelve el FileDialog creado (guárdalo si quieres reutilizarlo).
static func abrir_file_dialog(parent_node: Node,
							   on_archivo_seleccionado: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode         = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access            = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters           = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Imágenes"])
	dialog.title             = "Seleccionar imagen de perfil"
	dialog.min_size          = Vector2i(680, 480)
	dialog.process_mode      = Node.PROCESS_MODE_ALWAYS
	dialog.file_selected.connect(on_archivo_seleccionado)
	parent_node.add_child(dialog)
	dialog.popup_centered(Vector2i(680, 480))
	return dialog

## Carga una imagen desde un archivo del sistema de archivos y la convierte
## en Texture2D. Devuelve null y emite un warning si falla.
static func cargar_imagen_archivo(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null:
		push_warning("AvatarUtil: No se pudo cargar la imagen: " + path)
		return null
	return ImageTexture.create_from_image(img)


# ─────────────────────────────────────────────────────────────────────────────
#  APLICAR AVATAR
# ─────────────────────────────────────────────────────────────────────────────

## Aplica `tex` como avatar activo, lo muestra en `destino`, y lo persiste
## en Global. `path` puede ser la ruta res:// o "dispositivo" para imágenes
## cargadas desde el sistema de archivos.
static func aplicar_como_avatar(tex: Texture2D, path: String,
								 destino: TextureRect) -> void:
	if tex == null or destino == null:
		return
	destino.texture              = tex
	Global.player_avatar_texture = tex
	Global.player_avatar_path    = path
	Global.guardar_perfil()

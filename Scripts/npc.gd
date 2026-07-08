extends Node2D

# ════════════════════════════════════════════════════════════════════════════
#  NPC ESTÁTICO CON DIÁLOGO
# ════════════════════════════════════════════════════════════════════════════
#  Qué hace este NPC:
#   • NUNCA se mueve. Solo reproduce la animación "Idle" en bucle, siempre.
#   • NO puede recibir daño de nada: no tiene variable de vida, no tiene
#     "hitbox" de daño y no implementa receive_damage()/enemy(), así que
#     ningún sistema del juego (ataque del jugador, enemigos, etc.) tiene
#     forma de hacerle daño.
#   • Cuando el jugador entra en su zona de interacción, aparece el botón
#     "Hablar" en la parte de arriba de la pantalla.
#   • Al presionar "Hablar" se abre el cuadro de diálogo con el texto de
#     "historia". Tocar la pantalla mientras el diálogo está abierto avanza
#     a la siguiente línea, y cierra el cuadro al llegar al final.
#   • Si el jugador se aleja a mitad de la conversación, el cuadro se cierra
#     solo.
#
#  PARA TERMINAR DE CONFIGURARLO (lo único que falta):
#   1) Abre el nodo "AnimatedSprite2D" → panel "Sprite Frames" y agrega los
#      cuadros de tu sprite a la animación "Idle" (ya está creada, solo le
#      faltan las imágenes).
#   2) Si quieres otro texto o nombre, cámbialos desde el Inspector en las
#      variables exportadas "Nombre Npc" e "Historia" (puedes agregar tantas
#      líneas como quieras, cada una se mostrará al ir tocando la pantalla).
#   3) "Radio Interaccion" controla qué tan cerca debe estar el jugador para
#      que aparezca el botón de hablar.
# ════════════════════════════════════════════════════════════════════════════

@export var nombre_npc : String = "Ermitaño"
@export var historia : Array[String] = [
	"Forastero... llevas la marca de alguien que sobrevivió la primera oleada. Pocos llegan hasta mí.",
	"Este bosque era tranquilo hasta hace diez noches. Entonces los slimes comenzaron a aparecer desde las grietas.",
	"Dicen que hay un Champiñón Corrupto que los comanda. Si lo derrotas, las grietas se cerrarán.",
	"Cada oleada que sobrevivas te hará más fuerte. Tu cuerpo aprende, tu espada golpea más duro.",
	"Ve con cuidado. El jefe final no llega solo — lo preceden sus más fuertes seguidores.",
	"... Ah, y si ves una luz dorada flotando, es XP. Recógela antes de que desaparezca. ¡Suerte!"
]
@export var radio_interaccion     : float       = 40.0
@export var nombre_animacion_idle : String      = "Idle"

@onready var sprite             : AnimatedSprite2D = $AnimatedSprite2D
@onready var zona_interaccion   : Area2D           = $ZonaInteraccion
@onready var forma_interaccion  : CollisionShape2D = $ZonaInteraccion/CollisionShape2D
@onready var boton_hablar       : Button           = $UI_NPC/BotonHablar
@onready var panel_dialogo      : Control          = $UI_NPC/PanelDialogo
@onready var label_nombre       : Label            = $UI_NPC/PanelDialogo/Fondo/NombreNPC
@onready var label_texto        : Label            = $UI_NPC/PanelDialogo/Fondo/TextoDialogo

var jugador_cerca  : bool = false
var dialogo_activo : bool = false
var linea_actual   : int  = 0

# ─────────────────────────────────────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# El radio de detección se aplica por código para que puedas ajustarlo
	# desde el Inspector ("Radio Interaccion") sin tener que editar la forma.
	if forma_interaccion.shape is CircleShape2D:
		forma_interaccion.shape.radius = radio_interaccion

	# El NPC solo conoce una animación y la reproduce para siempre.
	sprite.play(nombre_animacion_idle)

	boton_hablar.visible  = false
	panel_dialogo.visible = false

	zona_interaccion.body_entered.connect(_on_zona_interaccion_body_entered)
	zona_interaccion.body_exited.connect(_on_zona_interaccion_body_exited)
	boton_hablar.pressed.connect(_abrir_dialogo)
	panel_dialogo.gui_input.connect(_on_panel_dialogo_gui_input)

# ─────────────────────────────────────────────────────────────────────────────
#  DETECCIÓN DE PROXIMIDAD (mismo patrón que mushroom.gd / slime.gd)
# ─────────────────────────────────────────────────────────────────────────────
func _on_zona_interaccion_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		jugador_cerca = true
		if not dialogo_activo:
			boton_hablar.visible = true

func _on_zona_interaccion_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		jugador_cerca = false
		boton_hablar.visible = false
		if dialogo_activo:
			_cerrar_dialogo()

# ─────────────────────────────────────────────────────────────────────────────
#  CUADRO DE DIÁLOGO
# ─────────────────────────────────────────────────────────────────────────────
func _on_panel_dialogo_gui_input(event: InputEvent) -> void:
	var es_toque: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if es_toque:
		_avanzar_dialogo()

func _abrir_dialogo() -> void:
	dialogo_activo        = true
	linea_actual           = 0
	boton_hablar.visible   = false
	label_nombre.text      = nombre_npc
	panel_dialogo.visible  = true
	_mostrar_linea()

func _avanzar_dialogo() -> void:
	linea_actual += 1
	if linea_actual >= historia.size():
		_cerrar_dialogo()
	else:
		_mostrar_linea()

func _mostrar_linea() -> void:
	label_texto.text = "" if historia.is_empty() else historia[linea_actual]

func _cerrar_dialogo() -> void:
	dialogo_activo         = false
	panel_dialogo.visible  = false
	# Si el jugador sigue cerca, le volvemos a mostrar el botón de hablar
	# para que pueda iniciar otra conversación.
	if jugador_cerca:
		boton_hablar.visible = true

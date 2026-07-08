extends Button
## boton_pixel.gd  —  Botón reutilizable con la plantilla pixel-art
## (Assets/Menu/Plantilla-boton.png) y la fuente VT323.
##
## Se usa instanciando la escena Scenes/UI/BotonPixel.tscn, tanto colocada
## a mano en un .tscn (editando la propiedad "texto" en el Inspector) como
## creada por código:
##
##     var btn := preload("res://Scenes/UI/BotonPixel.tscn").instantiate()
##     btn.texto = "JUGAR"
##     algun_contenedor.add_child(btn)

## Texto que se muestra en el botón.
@export var texto: String = "BOTÓN":
	set(valor):
		texto = valor
		if is_node_ready():
			text = texto

func _ready() -> void:
	text = texto

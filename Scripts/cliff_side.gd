extends Node2D

func _ready() -> void:
	await get_tree().process_frame
	
	# Si viene de Mundo, posicionar en la entrada de cliff_side
	if Global.current_scene == "Mundo":
		$Jugador.global_position = Vector2(Global.cliff_entry_x, Global.cliff_entry_y)
	
	Global.current_scene = "cliff_side"

func _process(_delta: float) -> void:
	change_scene()

func _on_mundo_transition_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		Global.transition_scene = true

func _on_mundo_transition_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		Global.transition_scene = false

func change_scene():
	if Global.transition_scene == true and Global.current_scene == "cliff_side":
		Global.transition_scene = false
		SceneTransition.ir_a("res://Scenes/mundo.tscn")

extends KinematicBody2D

export var speed := 1000
var direction := Vector2.ZERO
var _velocity: = Vector2.ZERO
var shooter_path: = ""


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
func _physics_process(delta):
	_velocity = direction * speed
	_velocity = move_and_slide(_velocity)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Area2D_body_entered(body):
	if shooter_path != body.get_path():
		if body.is_in_group("players"):
			var reward_from_action = body.reduce_health()
			get_tree().get_node(shooter_path).reward += reward_from_action
		queue_free()
	pass # Replace with function body.

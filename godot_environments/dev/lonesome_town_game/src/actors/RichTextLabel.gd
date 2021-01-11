extends RichTextLabel


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _process(delta):
	set_text("Health: " + str(get_parent().health))


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

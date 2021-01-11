extends RichTextLabel


func _process(delta):
	set_text("Player orientation:" + str(get_parent().get_node("YSort/Player").get_position()))


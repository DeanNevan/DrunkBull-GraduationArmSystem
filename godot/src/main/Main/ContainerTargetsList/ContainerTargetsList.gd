extends VBoxContainer

signal target_selected(target_name)
signal unselected

var scene_button_target : PackedScene = preload("res://src/main/Main/ContainerTargetsList/ButtonTarget.tscn")
var items := []
var colors := []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func activate(_items : Array, _colors : Array):
	items = _items
	colors = _colors
	for i in get_children():
		if i.toggled.is_connected(self._on_button_target_toggled):
			i.toggled.disconnect(self._on_button_target_toggled)
		i.queue_free()
	for i in items.size():
		var button_target : CheckBox = scene_button_target.instantiate()
		add_child(button_target)
		button_target.text = items[i]
		if colors.size() >= i + 1:
			button_target.modulate = colors[i]
		button_target.toggled.connect(self._on_button_target_toggled.bind(button_target))
	pass

func _on_button_target_toggled(pressed : bool, button):
	if pressed:
		for i in get_children():
			if i != button:
				i.button_pressed = false
		emit_signal("target_selected", items.find(button.text), button.text)
	else:
		emit_signal("unselected")

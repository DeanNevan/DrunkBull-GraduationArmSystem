extends Node2D

var world_objects := []
var pred_result := {}
var synset_names := []
var camera : Camera3D
var colors := []

var is_active := false

func _draw():
	if pred_result == {}:
		return
	colors.clear()
	for i in world_objects.size():
		var color : Color
		if world_objects.size() == 0:
			color = Color.WHITE
		else:
			color = Color.from_hsv(float(i) / (world_objects.size()), 1, 1)
		colors.append(color)
		var object : Node3D = world_objects[i]
		var object_center_3d : Vector3 = object.global_transform.origin
		var object_center_2d : Vector2 = camera.unproject_position(object_center_3d)
		
		if is_active:
			draw_string(
				preload("res://assets/font/wei_ruan_ya_hei.ttf"),
				object_center_2d,
				synset_names[pred_result.pred_class_ids[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color
			)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func activate():
	is_active = true
	queue_redraw()

func inactivate():
	is_active = false
	queue_redraw()

extends Node2D

var pred_result := {}
var scale_x := 1.0
var scale_y := 1.0
var synset_names := []
var world_objects := []
var camera : Camera3D

var is_active := false



func _draw():
	if !is_active:
		return
	if pred_result == {}:
		return
	var colors := []
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
		
		var pos1 : Vector2 = camera.unproject_position(object.corners[0])
		var pos2 : Vector2 = camera.unproject_position(object.corners[1])
		var pos3 : Vector2 = camera.unproject_position(object.corners[2])
		var pos4 : Vector2 = camera.unproject_position(object.corners[3])
		var pos5 : Vector2 = camera.unproject_position(object.corners[4])
		var pos6 : Vector2 = camera.unproject_position(object.corners[5])
		var pos7 : Vector2 = camera.unproject_position(object.corners[6])
		var pos8 : Vector2 = camera.unproject_position(object.corners[7])
		
		draw_circle(pos1, 2, color)
		draw_circle(pos2, 2, color)
		draw_circle(pos3, 2, color)
		draw_circle(pos4, 2, color)
		draw_circle(pos5, 2, color)
		draw_circle(pos6, 2, color)
		draw_circle(pos7, 2, color)
		draw_circle(pos8, 2, color)
		
		draw_line(pos1, pos2, color, 2, true)
		draw_line(pos2, pos3, color, 2, true)
		draw_line(pos3, pos4, color, 2, true)
		draw_line(pos4, pos1, color, 2, true)
		
		draw_line(pos5, pos6, color, 2, true)
		draw_line(pos6, pos7, color, 2, true)
		draw_line(pos7, pos8, color, 2, true)
		draw_line(pos8, pos5, color, 2, true)
		
		draw_line(pos1, pos8, color, 2, true)
		draw_line(pos2, pos7, color, 2, true)
		draw_line(pos3, pos6, color, 2, true)
		draw_line(pos4, pos5, color, 2, true)
		
		var pos_x_axis : Vector3 = object_center_3d + object.global_transform.basis.x.normalized() * 0.1
		var pos_y_axis : Vector3 = object_center_3d + object.global_transform.basis.y.normalized() * 0.1
		var pos_z_axis : Vector3 = object_center_3d + object.global_transform.basis.z.normalized() * 0.1
		draw_line(object_center_2d, camera.unproject_position(pos_x_axis), Color.RED, 4)
		draw_line(object_center_2d, camera.unproject_position(pos_y_axis), Color.GREEN, 4)
		draw_line(object_center_2d, camera.unproject_position(pos_z_axis), Color.BLUE, 4)
	
	for i in world_objects.size():
		var object : Node3D = world_objects[i]
		var object_center_3d : Vector3 = object.global_transform.origin
		var object_center_2d : Vector2 = camera.unproject_position(object_center_3d) - Vector2(24, 0)
		draw_string(
			preload("res://assets/font/wei_ruan_ya_hei.ttf"),
			object_center_2d,
			synset_names[pred_result.pred_class_ids[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, colors[i]
		)
		
		pass
	pass

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

var _count := 0
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_count += 1
	if _count % 10 == 0:
		queue_redraw()
	pass

func activate():
	is_active = true
	queue_redraw()
	pass

func inactivate():
	is_active = false
	queue_redraw()
	pass
	

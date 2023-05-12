extends Node2D
var is_active := false
var bboxes := []

func _draw():
	if !is_active:
		return
	var colors := []
	for i in bboxes.size():
		var color : Color
		if bboxes.size() == 0:
			color = Color.WHITE
		else:
			color = Color.from_hsv(float(i) / (bboxes.size()), 1, 1)
		colors.append(color)
		draw_rect(bboxes[i][0], color, false, 5)
	for i in bboxes.size():
		draw_string(
			preload("res://assets/font/wei_ruan_ya_hei.ttf"),
			Vector2(bboxes[i][0].position.x + bboxes[i][0].size.x, bboxes[i][0].position.y),
			bboxes[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, colors[i]
		)
	pass

func clear():
	bboxes.clear()
	pass

func add_bbox(bbox : Rect2, label := "NULL"):
	bboxes.append([bbox, label])
	pass

func activate():
	is_active = true
	queue_redraw()
	pass

func inactivate():
	is_active = false
	queue_redraw()
	pass


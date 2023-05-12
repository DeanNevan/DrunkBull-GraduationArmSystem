extends Node
@onready var _RGB = %RGB
@onready var _BBoxDrawer2D = %BBoxDrawer2D

var SIZE_2D := Vector2(224, 126)

var pred_result := {}
var rgb : Texture2D
var synset_names := []

func activate():
	_RGB.texture = rgb
	_RGB.show()
	var scale_x : float = float(_RGB.size.x) / SIZE_2D.x
	var scale_y : float = float(_RGB.size.y) / SIZE_2D.y
#	var scale_x : float = 1
#	var scale_y : float = 1
	_BBoxDrawer2D.clear()
	if pred_result == {}:
		return
	for i in pred_result.pred_bboxes.size():
		var start_position : Vector2 = Vector2(pred_result.pred_bboxes[i][1] * scale_x, pred_result.pred_bboxes[i][0] * scale_y)
		var end_position : Vector2 = Vector2(pred_result.pred_bboxes[i][3] * scale_x, pred_result.pred_bboxes[i][2] * scale_y)
		_BBoxDrawer2D.add_bbox(
			Rect2(
				start_position,
				end_position - start_position
			), synset_names[pred_result.pred_class_ids[i]]
		)
		pass
	_BBoxDrawer2D.activate()
	pass

func inactivate():
	_RGB.hide()
	_BBoxDrawer2D.inactivate()

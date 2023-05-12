extends MarginContainer

@onready var _LabelVisionOnline = %LabelVisionOnline
@onready var _LabelArmOnline = %LabelArmOnline
@onready var _LabelServerOnline = %LabelServerOnline

var is_arm_online := false
var is_vision_online := false
var is_server_online := false

func update_all():
	if is_server_online:
		_LabelServerOnline.text = "在线"
		_LabelServerOnline.modulate = Color.GREEN
	else:
		_LabelServerOnline.text = "离线"
		_LabelServerOnline.modulate = Color.RED
	if is_arm_online:
		_LabelArmOnline.text = "在线"
		_LabelArmOnline.modulate = Color.GREEN
	else:
		_LabelArmOnline.text = "离线"
		_LabelArmOnline.modulate = Color.RED
	if is_vision_online:
		_LabelVisionOnline.text = "在线"
		_LabelVisionOnline.modulate = Color.GREEN
	else:
		_LabelVisionOnline.text = "离线"
		_LabelVisionOnline.modulate = Color.RED
	pass

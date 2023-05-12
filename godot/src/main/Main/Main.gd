extends Control

@onready var _ClientOnlineStatus = %ClientOnlineStatus
@onready var _World3D = %World3D
@onready var _Draw2DBBox = %Draw2DBBox
@onready var _Draw6D = %Draw6D
@onready var _LayerUI = %LayerUI
@onready var _ThumbnailContainer = %ThumbnailContainer
@onready var _ContainerControlArmRaw = %ContainerControlArmRaw
@onready var _ButtonResetArm = %ButtonResetArm
@onready var _ButtonUpdateRawArmControl = %ButtonUpdateRawArmControl
@onready var _ButtonRawArmControl = %ButtonRawArmControl
@onready var _ButtonRawArmControlInputPos = %ButtonRawArmControlInputPos
@onready var _ContainerRawArmDegControl = %ContainerRawArmDegControl
@onready var _ContainerRawArmEnterPos = %ContainerRawArmEnterPos
@onready var _EditArmTargetX = %EditArmTargetX
@onready var _EditArmTargetY = %EditArmTargetY
@onready var _EditArmTargetThi = %EditArmTargetThi
@onready var _ContainerCatchTarget = %ContainerCatchTarget
@onready var _ButtonConfirmCatchTarget = %ButtonConfirmCatchTarget
@onready var _ButtonOpenCatchTarget = %ButtonOpenCatchTarget
@onready var _ContainerTargetsList = %ContainerTargetsList
@onready var _ContainerTargetInfo = %ContainerTargetInfo
@onready var _LabelTargetInfo = %LabelTargetInfo
@onready var _LayerBG = %LayerBG

@onready var _HSliderRaw1 = %HSliderRaw1
@onready var _HSliderRaw2 = %HSliderRaw2
@onready var _HSliderRaw3 = %HSliderRaw3
@onready var _HSliderRaw4 = %HSliderRaw4
@onready var _HSliderRaw5 = %HSliderRaw5
@onready var _HSliderRaw6 = %HSliderRaw6
@onready var _LabelRaw1 = %LabelRaw1
@onready var _LabelRaw2 = %LabelRaw2
@onready var _LabelRaw3 = %LabelRaw3
@onready var _LabelRaw4 = %LabelRaw4
@onready var _LabelRaw5 = %LabelRaw5
@onready var _LabelRaw6 = %LabelRaw6
@onready var h_sliders_raw := [_HSliderRaw1, _HSliderRaw2, _HSliderRaw3, _HSliderRaw4, _HSliderRaw5, _HSliderRaw6]
@onready var labels_raw := [_LabelRaw1, _LabelRaw2, _LabelRaw3, _LabelRaw4, _LabelRaw5, _LabelRaw6]

var ARM_SERVOS_INIT_TRUE_DEG = [
	85, 90, 57, 85, 0, 76
]

var SIZE_2D := Vector2(224, 126)
var synset_names := ['other',  # 0
					'bottle',  # 1
					'bowl',  # 2
					'camera',  # 3
					'can',  # 4
					'car',  # 5
					'mug',  # 6
					'aeroplane',  # 7
					'BG',  # 8
					]

var texture_color := ImageTexture.new()
var texture_sim_depth := ImageTexture.new()
var texture_syn_depth := ImageTexture.new()
var pred_result := {}
var current_view_index := 0

var catch_target_pos_relative := Vector2()
var catch_target_thi_relative := 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
#	var vector1 := Vector3(0, 1.8, 3.5)
#	var vector2 := Vector3(0,3.34786, 6.180974)
#	for i in 11:
#		var vec : Vector3 = vector1.lerp(vector2, float(i) / 10)
#		print(vec)
	
#	var vectors := [
#		Vector2(50, 70),
#		Vector2(60, 82),
#		Vector2(70, 96.5),
#		Vector2(80, 110),
#		Vector2(90, 132),
#		Vector2(100, 160),
#	]
#
#	print("归一化前：" + str(vectors))
#
#	var min_x := 100000
#	var min_y := 100000
#	var max_x := 0
#	var max_y := 0
#
#	for vector in vectors:
#		if vector.x < min_x:
#			min_x = vector.x
#		if vector.y < min_y:
#			min_y = vector.y
#		if vector.x > max_x:
#			max_x = vector.x
#		if vector.y > max_y:
#			max_y = vector.y
#
#	var min_to_max_x := max_x - min_x
#	var min_to_max_y := max_y - min_y
#
#	var normalized_vectors := []
#
#	for vector in vectors:
#		vector.x = (vector.x - min_x) / min_to_max_x
#		vector.y = (vector.y - min_y) / min_to_max_y
#		normalized_vectors.append(vector)
#
#	print("归一化后：" + str(normalized_vectors))
	
	var file := FileAccess.open("res://src/test/Test/data/1/result.json", FileAccess.READ)
	pred_result = JSON.parse_string(file.get_as_text())
	
	
	for i in h_sliders_raw.size():
		h_sliders_raw[i].value_changed.connect(self._on_h_slider_raw_value_changed.bind(i))
		h_sliders_raw[i].value = ARM_SERVOS_INIT_TRUE_DEG[i]
	
	ServerConnection.responsed.connect(self._on_responsed)
	HeartbeatManager.timeouted.connect(self._on_heartbeat_timeouted)
	HeartbeatManager.heartbeated.connect(self._on_heartbeated)
	ServerConnection.connect_to()
	HeartbeatManager.activate()
	_ClientOnlineStatus.update_all()
	_ThumbnailContainer.update_all()
	
	_Draw2DBBox.synset_names = synset_names
	
	_World3D.synset_names = synset_names
	
	_Draw6D.synset_names = synset_names
	_Draw6D.camera = _World3D._FakeCamera
	
	current_view_index = 0
	update_all()
	pass # Replace with function body.

func get_arm_raw_values() -> Array:
	var result := []
	for i in h_sliders_raw:
		result.append(i.value)
	return result

func update_all():
	_Draw2DBBox.pred_result = pred_result
	_Draw6D.pred_result = pred_result
	_World3D.pred_result = pred_result
	
	_Draw2DBBox.rgb = texture_color
	_Draw6D.rgb = texture_color
	_World3D.update_world_objects()
	_Draw6D.world_objects = _World3D.world_objects
	
	_ThumbnailContainer.texture_color = texture_color
	_ThumbnailContainer.texture_sim_depth = texture_sim_depth
	_ThumbnailContainer.texture_syn_depth = texture_syn_depth
	_ThumbnailContainer.update_all()
	
	_LayerBG.hide()
	
	if current_view_index == 1:
		_Draw2DBBox.activate()
		_Draw6D.inactivate()
		_World3D.inactivate()
	elif current_view_index == 2:
		_Draw2DBBox.inactivate()
		_Draw6D.activate()
		_World3D.inactivate()
	elif current_view_index == 3:
		_Draw2DBBox.inactivate()
		_Draw6D.inactivate()
		_World3D.activate()
	else:
		_LayerBG.show()
		_Draw2DBBox.inactivate()
		_Draw6D.inactivate()
		_World3D.inactivate()
	
	_ContainerControlArmRaw.visible = _ButtonRawArmControl.button_pressed
	_on_button_raw_arm_control_input_pos_toggled(_ButtonRawArmControlInputPos.button_pressed)
	_on_button_open_catch_target_toggled(_ButtonOpenCatchTarget.button_pressed)
#	for i in h_sliders_raw.size():
#		labels_raw[i].text = str(h_sliders_raw[i].value)
	pass

func _on_responsed(response : Message.SCMessage):
	if !response.get_heartbeat():
		var sc_monitor_message = response.get_sc_monitor_message()
#		print(sc_monitor_message.get_cmd())
		if sc_monitor_message.get_cmd() == Message.M_CMD.M_UPDATE_CLIENTS:
			_ClientOnlineStatus.is_arm_online = sc_monitor_message.get_client_arm_online()
			_ClientOnlineStatus.is_vision_online = sc_monitor_message.get_client_vision_online()
			_ClientOnlineStatus.update_all()
#			print(sc_monitor_message.get_client_arm_online())
#			print(sc_monitor_message.get_client_vision_online())
			pass
		elif sc_monitor_message.get_cmd() == Message.M_CMD.M_UPDATE_VISION:
			var bytes_color : PackedByteArray = sc_monitor_message.get_color_image()
			var bytes_sim_depth : PackedByteArray = sc_monitor_message.get_sim_depth_image()
			var bytes_syn_depth : PackedByteArray = sc_monitor_message.get_syn_depth_image()
			
			var image_color := Image.new()
			image_color.load_png_from_buffer(bytes_color)
			var image_sim_depth := Image.new()
			image_sim_depth.load_png_from_buffer(bytes_sim_depth)
			var image_syn_depth := Image.new()
			image_syn_depth.load_png_from_buffer(bytes_syn_depth)
			
			texture_color = texture_color.create_from_image(image_color)
			texture_sim_depth = texture_sim_depth.create_from_image(image_sim_depth)
			texture_syn_depth = texture_syn_depth.create_from_image(image_syn_depth)
			
			var pred_result_json : String = sc_monitor_message.get_pred_result_json()
			pred_result = JSON.parse_string(pred_result_json)
			
			print(pred_result)
			
			update_all()
			
	pass

func _on_heartbeat_timeouted():
	ServerConnection.connect_to()
	HeartbeatManager.activate()
	_ClientOnlineStatus.is_server_online = false
	_ClientOnlineStatus.is_arm_online = false
	_ClientOnlineStatus.is_vision_online = false
	_ClientOnlineStatus.update_all()
	pass

func _on_heartbeated():
	_ClientOnlineStatus.is_server_online = true
	_ClientOnlineStatus.update_all()

func _on_button_view_type_item_selected(index):
	current_view_index = index
	update_all()
	pass # Replace with function body.


func _on_button_update_vision_pressed():
	ServerConnection.send_message_update_vision()


func _on_button_raw_arm_control_toggled(button_pressed):
	_ContainerControlArmRaw.visible = _ButtonRawArmControl.button_pressed
	pass # Replace with function body.


func _on_button_update_raw_arm_control_pressed():
	if _ButtonRawArmControlInputPos.button_pressed:
		var x : float = float(_EditArmTargetX.text)
		var y : float = float(_EditArmTargetY.text)
		var vec := Vector2(x, y)
		vec *= 1
		var thi : float = float(_EditArmTargetThi.text)
		print("转动到x: %.2f, y:%.2f, thi:%.2f" % [x, y, thi])
		ServerConnection.send_message_control_arm_target(
			x, y, thi
		)
	else:
		ServerConnection.send_message_control_arm_raw(get_arm_raw_values())
	pass # Replace with function body.


func _on_button_reset_arm_pressed():
	for i in h_sliders_raw.size():
		h_sliders_raw[i].value = ARM_SERVOS_INIT_TRUE_DEG[i]
	pass # Replace with function body.

func _on_h_slider_raw_value_changed(value : int, idx : int):
	labels_raw[idx].text = str(value)
	pass


func _on_button_raw_arm_control_input_pos_toggled(button_pressed):
	if button_pressed:
		_ContainerRawArmDegControl.hide()
		_ContainerRawArmEnterPos.show()
	else:
		_ContainerRawArmDegControl.show()
		_ContainerRawArmEnterPos.hide()



func _on_button_open_catch_target_toggled(button_pressed):
	_ContainerCatchTarget.visible = button_pressed
	var items := []
	if pred_result.has("pred_class_ids"):
		for i in pred_result.pred_class_ids:
			items.append(synset_names[i])
	if button_pressed:
		_on_container_targets_list_unselected()
		_ContainerTargetsList.activate(items, _World3D.get_colors())
	pass # Replace with function body.


func _on_container_targets_list_target_selected(idx, target_name):
	_ContainerTargetInfo.show()
	
	
	var position_relative : Vector3 = _World3D.get_object_position_relative_to_arm(_World3D.world_objects[idx])
	var thi_relative : float = _World3D.get_object_thi_relative_to_arm(_World3D.world_objects[idx])
	
	var position_relative_correct : Vector2 = Vector2(
		-position_relative.z * 1000,
		-position_relative.x * 1000
	)
	
	position_relative_correct *= 0.6

	var vec = (_World3D.world_objects[idx].global_position - _World3D._FakeCamera.global_position)
	print("相机到目标物体向量为:%s" % vec) 
	print("长度为:%s" % vec.length()) 
	
	_LabelTargetInfo.text = "x:%.1f, y:%.1f\nlen:%.1f, thi：%.1f" % [
		position_relative_correct.x, position_relative_correct.y, position_relative_correct.length(), thi_relative
	]
	
	catch_target_pos_relative = position_relative_correct
	catch_target_thi_relative = thi_relative
	
	
	pass # Replace with function body.


func _on_container_targets_list_unselected():
	_ContainerTargetInfo.hide()
	pass # Replace with function body.


func _on_button_confirm_catch_target_pressed():
	ServerConnection.send_message_control_arm_target_full(
		catch_target_pos_relative.x, 
		catch_target_pos_relative.y, 
		catch_target_thi_relative
	)
	pass # Replace with function body.

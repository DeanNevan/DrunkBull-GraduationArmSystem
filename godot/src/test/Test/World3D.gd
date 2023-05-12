extends Node3D

@onready var _MainCamera = %MainCamera
@onready var _FakeCamera = %FakeCamera
@onready var _WorldEnvironment = %WorldEnvironment
@onready var _DirectionalLight3D = %DirectionalLight3D
@onready var _MeshInstanceCamera = %MeshInstanceCamera
@onready var _WorldObjects = %WorldObjects
@onready var _OriginMeshCamera = %OriginMeshCamera
@onready var _World3DDrawer = %World3DDrawer
@onready var _CameraShield = %CameraShield
@onready var _Arm = %arm

var scene_world_object := preload("res://src/test/Test/WorldObject.tscn")

var pred_result := {}
var rgb : Texture2D
var synset_names := []

var world_objects := []

var count := 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _unhandled_input(event):
	if event is InputEventKey:
		if event.key_label == KEY_SPACE:
			_MainCamera.global_transform = _FakeCamera.global_transform
#			_MainCamera._total_pitch = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
#	count += 1
#	if count % 200 == 0:
#		activate()
	pass

func update_world_objects():
	world_objects.clear()
	for i in _WorldObjects.get_children():
		i.queue_free()
	if pred_result == {}:
		return
	for i in pred_result.pred_RTs.size():
		var RT_array : Array = pred_result.pred_RTs[i]
		var world_object := scene_world_object.instantiate()
		_WorldObjects.add_child(world_object)
		var proj := Projection(
			Vector4(RT_array[0][0], -RT_array[1][0], -RT_array[2][0], 0),
			Vector4(RT_array[0][1], -RT_array[1][1], -RT_array[2][1], 0),
			Vector4(RT_array[0][2], -RT_array[1][2], -RT_array[2][2], 0),
			Vector4(RT_array[0][3], -RT_array[1][3], -RT_array[2][3], 1),
		)
		world_object.global_transform = _FakeCamera.global_transform * Transform3D(proj)
		var vec3 : Vector3 = world_object.global_position - _FakeCamera.global_position
		vec3 *= 1.0
		world_object.global_position = _FakeCamera.global_position + vec3
		if _FakeCamera.is_position_behind(world_object.global_transform.origin):
			_WorldObjects.remove_child(world_object)
		else:
			world_objects.append(world_object)
			world_object.size = Vector3(
				pred_result.pred_scales[i][0],
				pred_result.pred_scales[i][1],
				pred_result.pred_scales[i][2]
			)
		#print
		#world_object.position.z = -world_object.position.z
		#world_object.position.y = -world_object.position.y
	_World3DDrawer.world_objects = world_objects
	_World3DDrawer.pred_result = pred_result
	_World3DDrawer.synset_names = synset_names
	_World3DDrawer.camera = _MainCamera
	_World3DDrawer.activate()
	pass

func get_colors() -> Array:
	return _World3DDrawer.colors

func get_object_position_relative_to_arm(object : WorldObject) -> Vector3:
	return object.global_position - _Arm.global_position

func get_object_main_direction(object : WorldObject) -> Vector3:
	if object.size.x >= object.size.y and object.size.x >= object.size.z:
		return object.global_transform.basis.x
	if object.size.y >= object.size.x and object.size.y >= object.size.z:
		return object.global_transform.basis.y
	else:
		return object.global_transform.basis.z
		

func get_object_thi_relative_to_arm(object : WorldObject) -> float:
	var main_direction : Vector3 = get_object_main_direction(object)
	var main_direction_2d : Vector2 = Vector2(
		main_direction.x,
		main_direction.z
	)
	var arm_x_drection : Vector3 = _Arm.global_transform.basis.z
	var arm_x_drection_2d : Vector2 = Vector2(
		arm_x_drection.x,
		arm_x_drection.z
	)
	
	return rad_to_deg(main_direction_2d.angle_to(arm_x_drection_2d))
	

func activate():
	show()
	update_world_objects()
#1 0 0 2
#0 1 0 2
#0 0 1 2
#0 0 0 1

#2 2 2 1
#0 0 1 0
#0 1 0 0


func inactivate():
	hide()
	_World3DDrawer.inactivate()


func _on_main_camera_moved():
	_World3DDrawer.queue_redraw()
	pass # Replace with function body.

extends Control

@export var resource_rgb : Texture2D
@export var resource_sim_depth : Texture2D
@export var resource_syn_depth : Texture2D
@export var resource_result_json : JSON
@export var path_cad_model : String

@onready var _World3D = %World3D
@onready var _Draw2DBBox = %Draw2DBBox
@onready var _Draw6D = %Draw6D
@onready var _LayerUI = %LayerUI
@onready var _Thumbnail = %Thumbnail
@onready var _ThumbnailContainer = %ThumbnailContainer


var result := {}


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

func _input(event):
	if event is InputEventKey:
		if event.key_label == KEY_1:
			_Thumbnail.texture = resource_rgb
			_ThumbnailContainer.show()
		if event.key_label == KEY_2:
			_Thumbnail.texture = resource_sim_depth
			_ThumbnailContainer.show()
		if event.key_label == KEY_3:
			_Thumbnail.texture = resource_syn_depth
			_ThumbnailContainer.show()
		if event.key_label == KEY_4:
			_ThumbnailContainer.hide()

# Called when the node enters the scene tree for the first time.
func _ready():
	_ThumbnailContainer.hide()
	#var file_access := FileAccess.open("res://src/test/Test/result.json", FileAccess.READ)
	#var json_string : String = file_access.get_as_text()
	result = resource_result_json.data
	print(result)
	
	_Draw2DBBox.result = result
	_Draw2DBBox.rgb = resource_rgb
	_Draw2DBBox.synset_names = synset_names
	
	_World3D.result = result
	_World3D.rgb = resource_rgb
	_World3D.synset_names = synset_names
	
	_on_button_type_item_selected(3)
	_on_button_type_item_selected(0)
	
	_Draw6D.result = result
	_Draw6D.rgb = resource_rgb
	_Draw6D.synset_names = synset_names
	_Draw6D.camera = _World3D._FakeCamera
	_Draw6D.world_objects = _World3D.world_objects
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_button_type_item_selected(index):
	print(index)
	if index == 1:
		_Draw2DBBox.activate()
		_Draw6D.inactivate()
		_World3D.inactivate()
	elif index == 2:
		_Draw2DBBox.inactivate()
		_Draw6D.activate()
		_World3D.inactivate()
	elif index == 3:
		_Draw2DBBox.inactivate()
		_Draw6D.inactivate()
		_World3D.activate()
	else:
		_Draw2DBBox.inactivate()
		_Draw6D.inactivate()
		_World3D.inactivate()
	pass # Replace with function body.

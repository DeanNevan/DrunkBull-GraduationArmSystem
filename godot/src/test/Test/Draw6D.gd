extends Node

@onready var _RGB = %RGB
@onready var _Drawer6D = %Drawer6D

var SIZE_2D := Vector2(224, 126)

var pred_result := {}
var rgb : Texture2D
var synset_names := []

var world_objects := []
var camera : Camera3D

var _count := 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func activate():
	_RGB.texture = rgb
	_RGB.show()
	var scale_x : float = float(_RGB.size.x) / SIZE_2D.x
	var scale_y : float = float(_RGB.size.y) / SIZE_2D.y
	_Drawer6D.scale_x = scale_x
	_Drawer6D.scale_y = scale_y
	_Drawer6D.synset_names = synset_names
	_Drawer6D.world_objects = world_objects
	_Drawer6D.camera = camera
	_Drawer6D.pred_result = pred_result
	_Drawer6D.activate()
	pass

func inactivate():
	_RGB.hide()
	_Drawer6D.inactivate()
	pass

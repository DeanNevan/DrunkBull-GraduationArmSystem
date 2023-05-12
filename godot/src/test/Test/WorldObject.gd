extends Node3D
class_name WorldObject

@onready var _AxisOrigin = %AxisOrigin


var size := Vector3(1, 1, 1):
	set(_size):
		size = _size
		$MeshInstance3D.scale = size
		corners.clear()
		for i in $MeshInstance3D.get_children():
			corners.append(i.global_transform.origin)

var corners := []

# Called when the node enters the scene tree for the first time.
func _ready():
	var s := "123\n234\n232\n1"
	print(s.count('\n'))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


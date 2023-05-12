extends Node

signal heartbeated
signal timeouted

var is_active := false

# Called when the node enters the scene tree for the first time.
func _ready():
	ServerConnection.responsed.connect(self._on_responsed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func activate():
	is_active = true
	$Timer.paused = false
	$Timer.start()
	$TimerTimeout.paused = false
	$TimerTimeout.start()
	pass

func inactivate():
	is_active = false
	$Timer.paused = true
	$TimerTimeout.paused = true
	pass

func _on_timer_timeout():
	if is_active:
		var cs_message := Message.CSMessage.new()
		cs_message.set_client_type(Message.ClinetType.MONITOR)
		cs_message.set_heartbeat(true)
		ServerConnection.send_message(cs_message)
		print("发送心跳")
	pass # Replace with function body.

func _on_responsed(response : Message.SCMessage):
	heartbeated.emit()
	$TimerTimeout.start()
	print("收到心跳")


func _on_timer_timeout_timeout():
	if is_active:
		timeouted.emit()
		print("心跳超时")
		$TimerTimeout.start()
	pass # Replace with function body.

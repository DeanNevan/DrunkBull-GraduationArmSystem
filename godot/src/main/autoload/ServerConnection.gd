extends Node

signal responsed(response)
signal connected

var reading := false
var expected_length := 0 

var client_id : String = ""
var gate_server_id : String = ""
var is_connected_to_server := false

#var ip := "114.132.153.229"
#var port : int = 6000
var ip := "127.0.0.1"
var port : int = 9999
var tcp = StreamPeerTCP.new()

var read_bytes := PackedByteArray()

var temp_bytes := PackedByteArray()

func _ready() -> void:
	responsed.connect(self._on_responsed)

func _process(delta: float) -> void:
	_process_read_tcp()
	pass

func _process_read_tcp():
	if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		#不在读取数据body且可读byte>0，则读取数据包长度
		if !reading and tcp.get_available_bytes() > 3:
			var temp : Array = tcp.get_data(4)
			expected_length = (
				temp[1][0] * pow(256, 3) + 
				temp[1][1] * pow(256, 2) +
				temp[1][2] * 256 +
				temp[1][3]
			)
			reading = true
		var available_bytes_count = tcp.get_available_bytes()
		if reading and expected_length > 65536:
			var t = tcp.get_data(available_bytes_count)
			temp_bytes.append_array(t[1])
			if temp_bytes.size() >= expected_length:
				var a = Message.SCMessage.new()
				a.from_bytes(temp_bytes)
				#print(a.to_string())
				reading = false
				temp_bytes = PackedByteArray()
				emit_signal("responsed", a)
		
		elif reading and available_bytes_count >= expected_length:
			var temp = tcp.get_data(expected_length)
			var err_code = temp[0]
			var data = temp[1]
			var a = Message.SCMessage.new()
			a.from_bytes(data)
			#print(a.to_string())
			reading = false
			#if request_id2timestamp.has(a.get_request_id()):
			#print(request_id2timestamp.has(a.get_request_id()))
			emit_signal("responsed", a)
		pass

func connect_to(_ip : String = ip, _port : int = port):
	ip = _ip
	port = _port
	tcp.disconnect_from_host()
	tcp.connect_to_host(
		_ip,
		_port
	)
	await get_tree().create_timer(5).timeout # 等待五秒
	tcp.poll() # 更新状态

func send_message_control_arm_target(x := 0.0, y := 0.0, thi := 0.0):
	var message := Message.CSMessage.new()
	message.set_client_type(Message.ClinetType.MONITOR)
	message.set_heartbeat(false)
	message.new_cs_monitor_message()
	message.get_cs_monitor_message().set_cmd(Message.M_CMD.M_CONTROL_ARM_TARGET) 
	message.get_cs_monitor_message().set_control_arm_target_x(x)
	message.get_cs_monitor_message().set_control_arm_target_y(y)
	message.get_cs_monitor_message().set_control_arm_target_r(thi)
	send_message(message)

func send_message_control_arm_target_full(x := 0.0, y := 0.0, thi := 0.0):
	var message := Message.CSMessage.new()
	message.set_client_type(Message.ClinetType.MONITOR)
	message.set_heartbeat(false)
	message.new_cs_monitor_message()
	message.get_cs_monitor_message().set_cmd(Message.M_CMD.M_CONTROL_ARM_TARGET_FULL) 
	message.get_cs_monitor_message().set_control_arm_target_x(x)
	message.get_cs_monitor_message().set_control_arm_target_y(y)
	message.get_cs_monitor_message().set_control_arm_target_r(thi)
	send_message(message)

func send_message_control_arm_raw(values := [90, 90, 90, 90, 90, 90]):
	var message := Message.CSMessage.new()
	message.set_client_type(Message.ClinetType.MONITOR)
	message.set_heartbeat(false)
	message.new_cs_monitor_message()
	message.get_cs_monitor_message().set_cmd(Message.M_CMD.M_CONTROL_ARM_RAW) 
	message.get_cs_monitor_message().set_control_arm_raw_pos1(values[0])
	message.get_cs_monitor_message().set_control_arm_raw_pos2(values[1])
	message.get_cs_monitor_message().set_control_arm_raw_pos3(values[2])
	message.get_cs_monitor_message().set_control_arm_raw_pos4(values[3])
	message.get_cs_monitor_message().set_control_arm_raw_pos5(values[4])
	message.get_cs_monitor_message().set_control_arm_raw_pos6(values[5])
	send_message(message)

func send_message_update_vision():
	var message := Message.CSMessage.new()
	message.set_client_type(Message.ClinetType.MONITOR)
	message.set_heartbeat(false)
	message.new_cs_monitor_message()
	message.get_cs_monitor_message().set_cmd(Message.M_CMD.M_UPDATE_VISION) 
	send_message(message)

func send_message(message : Message.CSMessage):
	if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		send_packed_bytes(message.to_bytes())
	else:
		print("tcp is not connected:%d" % tcp.get_status())

func send_packed_bytes(bytes : PackedByteArray):
	#logger.debug("发送数据 %s" % bytes.get_string_from_utf8())
	#bytes.insert(0, bytes.size())
	var size : int = bytes.size()
	var size1 : int = size / pow(256, 3)
	size -= size1
	var size2 : int = size / pow(256, 2)
	size -= size2
	var size3 : int = size / 256
	size -= size3
	var size4 : int = size
	bytes.insert(0, size4)
	bytes.insert(0, size3)
	bytes.insert(0, size2)
	bytes.insert(0, size1)
	var err = tcp.put_data(bytes)
func _on_responsed(_response : Message.SCMessage):
	pass



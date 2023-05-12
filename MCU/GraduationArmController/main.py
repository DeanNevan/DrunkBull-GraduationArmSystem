import time
import network
import usocket
import struct
import _thread
import minipb
import math
import mek_arm

arm = mek_arm.MekArm() # 机械臂对象

wifi_name = "DrunkBull"     # wifi名称
wifi_psw = "DrunkBull233"   # wifi密码
server_ip = "192.168.137.1" # 服务端IP
server_port = 9999          # 服务端端口

# minipb通过这种注解+class的方式实现protobuf的轻量化编解码
@minipb.process_message_fields
class CSArmMessage(minipb.Message):
    pass

@minipb.process_message_fields
class SCArmMessage(minipb.Message):
    cmd = minipb.Field(1, minipb.TYPE_INT, required=True)
    control_arm_raw_pos1 = minipb.Field(2, minipb.TYPE_INT, required=False)
    control_arm_raw_pos2 = minipb.Field(3, minipb.TYPE_INT, required=False)
    control_arm_raw_pos3 = minipb.Field(4, minipb.TYPE_INT, required=False)
    control_arm_raw_pos4 = minipb.Field(5, minipb.TYPE_INT, required=False)
    control_arm_raw_pos5 = minipb.Field(6, minipb.TYPE_INT, required=False)
    control_arm_raw_pos6 = minipb.Field(7, minipb.TYPE_INT, required=False)
    control_arm_target_x = minipb.Field(8, minipb.TYPE_FLOAT, required=False)
    control_arm_target_y = minipb.Field(9, minipb.TYPE_FLOAT, required=False)
    control_arm_target_r = minipb.Field(10, minipb.TYPE_FLOAT, required=False)

@minipb.process_message_fields
class CSMessage(minipb.Message):
    client_type = minipb.Field(1, minipb.TYPE_INT, required=True)
    heartbeat = minipb.Field(2, minipb.TYPE_BOOL, required=True)
    cs_arm_message = minipb.Field(4, CSArmMessage, required=False)

@minipb.process_message_fields
class SCMessage(minipb.Message):
    client_type = minipb.Field(1, minipb.TYPE_INT, required=True)
    heartbeat = minipb.Field(2, minipb.TYPE_BOOL, required=True)
    sc_arm_message = minipb.Field(4, SCArmMessage, required=False)

class ServerConnection():
    """包含同服务端连接的所有内容，作为线程被使用
    """
    global arm

    def __init__(self, host, port):
        self.wlan = None
        self.sock = None
        self.host = host
        self.port = port
        self.connected = False
        self.expected_bytes_count = 0
        self.received_bytes_count = 0
        self.is_waiting_head = True
        self.buf_bytes = b""
        self.last_heartbeat_time = 0
        self.flag_quit = False
        pass
    
    def reset_read_state(self):
        self.is_waiting_head = True
        self.expected_bytes_count = 0
        self.received_bytes_count = 0
        self.buf_bytes = b""
    
    def send_proto(self, proto):
        """发送protobuf对象到服务端

        Args:
            proto (protobuf对象)
        """
        if self.sock is not None:
            print("send_proto")
            serialized_string = proto.encode()
            serialized_string_length = len(serialized_string)
            head = struct.pack(">I", serialized_string_length) # 在数据包头部插入4个字节大端表示的数据包包体大小
            # rospy.logwarn("!!!!!!")
            # rospy.logwarn(serialized_string_length)
            # rospy.logwarn(np.fromstring(head, dtype=np.uint8))
            print("send bytes:%d" % serialized_string_length)
            send_data_string = head + serialized_string
            try :
                self.sock.send(send_data_string)
            except usocket.error :
                self.connected = False
                return
            except :
                self.connected = False
                return

    def do_connect(self):
        """连接（重连）wlan和服务端
        """
        if self.wlan is None or not self.wlan.isconnected():
            print("try connecting wlan...")
            self.wlan = network.WLAN(network.STA_IF)
            self.wlan.active(True)
            if not self.wlan.isconnected():
                print('connecting to network...')
                self.wlan.connect(wifi_name, wifi_psw)
                while not self.wlan.isconnected():
                    pass
            print('network config:', self.wlan.ifconfig())
        self.sock = usocket.socket(usocket.AF_INET, usocket.SOCK_STREAM)
        sockaddr = usocket.getaddrinfo(self.host, self.port)[0][-1]

        try :
            print("try connecting...")
            self.sock.connect(sockaddr)
            self.connected = True
            self.last_heartbeat_time = time.time()
        except :
            self.connected = False
            return
	
    def run(self, _):
        """线程的运行函数
        """
        while not self.flag_quit:
            try:
                if self.connected:
                    if (time.time() - self.last_heartbeat_time) > 10: # 心跳超时
                        self.connected = False
                        continue
                    
                    if self.is_waiting_head: # 等待数据包头部
                        head_data = self.sock.recv(4) # 4字节大小的包头
                        # data_len = int.from_bytes(head_data, byteorder='big')
                        data_len = struct.unpack(">I", head_data)[0] # 按大端解码，得到数据包包体大小
                        print("new packet, size will be:%d" % data_len)
                        if data_len > 0: # 准备读取数据包包体内容
                            self.reset_read_state()
                            self.expected_bytes_count = data_len
                            self.is_waiting_head = False
                    if not self.is_waiting_head: # 读取数据包包体内容
                        data = self.sock.recv(self.expected_bytes_count - self.received_bytes_count) # 计划读取剩余所有字节
                        data_len = len(data)
                        self.received_bytes_count += data_len # 实际读取字节因为TCP分包缘故可能小于计划值，故累加实际值
                        self.buf_bytes += data # 将读取到的字节存入字节缓冲区
                        assert(self.received_bytes_count <= self.expected_bytes_count)
                        if self.received_bytes_count == self.expected_bytes_count: # 读满数据包包体
                            sc_message = SCMessage.decode(self.buf_bytes) # 解码数据包
                            self.reset_read_state()
                            self.last_heartbeat_time = time.time()
                            if sc_message.heartbeat: # 接收到的是心跳包
                                print("receive heartbeat")
                                pass
                            else:
                                print("handle message")
                                sc_arm_message = sc_message.sc_arm_message

                                if sc_arm_message.cmd == 0: # 如果指令是控制机械臂6个舵机
                                    print("===ARM CONTROL [RAW]===")
                                    arm.servos_target_true_deg = [
                                        sc_arm_message.control_arm_raw_pos1,
                                        sc_arm_message.control_arm_raw_pos2,
                                        sc_arm_message.control_arm_raw_pos3,
                                        sc_arm_message.control_arm_raw_pos4,
                                        sc_arm_message.control_arm_raw_pos5,
                                        sc_arm_message.control_arm_raw_pos6
                                    ]
                                    print("rotate to %s" % arm.servos_target_true_deg)
                                    arm.reset_servos_percent()
                                    print("======")
                                
                                if sc_arm_message.cmd == 1: # 如果指令是控制机械臂转动到指定方位
                                    res = arm.set_target((sc_arm_message.control_arm_target_x, sc_arm_message.control_arm_target_y), sc_arm_message.control_arm_target_r)
                                    print("===ARM CONTROL [TARGET] %s===" % "SUCCESS!" if res else "FAIL!")
                                    print("target at x:%.2f, y:%.2f, thi:%.2f" % (
                                        sc_arm_message.control_arm_target_x, 
                                        sc_arm_message.control_arm_target_y, 
                                        sc_arm_message.control_arm_target_r
                                        )
                                    )
                                    print("calculated tong_pos x:%.2f, y:%.2f" % (arm.tong_pos[0], arm.tong_pos[1])) 
                                    print("calculated R:%.2f" % arm.R) 
                                    print("rotate to " + str(arm.servos_target_true_deg))
                                    print("======")
                                
                                if sc_arm_message.cmd == 2: # 如果指令是自动抓取指定目标
                                    arm.start_catch_task((sc_arm_message.control_arm_target_x, sc_arm_message.control_arm_target_y), sc_arm_message.control_arm_target_r)
                                    print("===ARM CONTROL [TARGET_FULL]===")
                                    print("target at x:%.2f, y:%.2f, thi:%.2f" % (
                                        sc_arm_message.control_arm_target_x, 
                                        sc_arm_message.control_arm_target_y, 
                                        sc_arm_message.control_arm_target_r
                                        )
                                    )
                                    print("======")

                else:
                    self.do_connect()
                    time.sleep_ms(1000)
                time.sleep_ms(100)
            except :
                print("disconnected")
                self.connected = False

class HeartbeatSender():
    """心跳发送器，作为线程被使用
    """
    def __init__(self, server_connection):
        self.server_connection = server_connection
        self.flag_quit = False
    def run(self, _):
        """线程运行函数
        """
        while not self.flag_quit:
            try:
                cs_message = CSMessage()
                cs_message.client_type = 2
                cs_message.heartbeat = True
                print("send heartbeat")
                self.server_connection.send_proto(cs_message)
            except :
                pass
            time.sleep_ms(3000)
    pass


server_connection = ServerConnection(server_ip, server_port) # 线程：服务端连接
thread_server_connection = _thread.start_new_thread(server_connection.run, (server_connection,))
heartbeat_sender = HeartbeatSender(server_connection) # 线程：心跳发送器
thread_heartbeat_sender = _thread.start_new_thread(heartbeat_sender.run, (heartbeat_sender,))


last_time = time.ticks_ms() / 1000.0
time.sleep_ms(20)
while True: # 主循环逻辑
    current_time = time.ticks_ms() / 1000.0
    delta_time = current_time - last_time

    arm.process(delta_time) # 调用机械臂的process，使其工作

    last_time = current_time
    time.sleep_ms(20)


#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
@Description: 部署于ROS环境，需要设备已经联网（可以访问到服务端）
"""
import sys
import os
import rospy  # 导入rospy包 ROS的python客户端
import message_filters  # 导入message_filters包 消息过滤器
from sensor_msgs.msg import Image, CameraInfo  # sensor_msgs.msg包的Image, CameraInfo消息类型
import numpy as np
import time
import Message_pb2 as ProtoMessage
import socket
import struct
from cv_bridge import CvBridge, CvBridgeError
import cv2
import threading

server_ip = "192.168.137.1" # 服务端IP
server_port = 9999          # 服务端端口
# server_ip = "114.132.153.229"
# server_port = 6000

latest_color = None
latest_depth = None
bridge = CvBridge()

class ServerConnection(threading.Thread):
    """管理服务端连接，以线程方式调用
    """
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.sock = None
        self.host = host
        self.port = port
        self.connected = False
        self.expected_bytes_count = 0
        self.received_bytes_count = 0
        self.is_waiting_head = True
        self.buf_bytes = b""
        self.update_vision_to_server = False
        self.last_heartbeat_time = 0
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
            serialized_string = proto.SerializeToString()
            serialized_string_length = len(serialized_string)
            head = struct.pack(">I", serialized_string_length) # 在数据包头部插入4个字节大端表示的数据包包体大小
            # print("!!!!!!")
            # print(serialized_string_length)
            # print(np.fromstring(head, dtype=np.uint8))
            print("send bytes:%d" % serialized_string_length)
            send_data_string = head + serialized_string
            try :
                self.sock.send(send_data_string)
            except socket.error :
                self.connected = False
                return
            except :
                self.connected = False
                return

    def do_connect(self):
        """连接（重连）服务端
        """
        print("connecting server...")
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try :
            self.sock.connect((self.host, self.port))
            self.connected = True
            self.last_heartbeat_time = time.time()
        except :
            self.connected = False
            return
    
    def run(self):
        """线程的运行函数
        """
        while True:
            try:
                if self.connected:
                    if (time.time() - self.last_heartbeat_time) > 10: # 心跳超时
                        self.connected = False
                        continue
                    if self.is_waiting_head: # 等待数据包头部
                        head_data = self.sock.recv(4) # 4字节大小的包头
                        # data_len = int.from_bytes(head_data, byteorder='big')
                        data_len = struct.unpack(">I", head_data)[0] # 按大端解码，得到数据包包体大小
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
                            sc_message = ProtoMessage.SCMessage()
                            sc_message.ParseFromString(self.buf_bytes) # 解码数据包
                            self.last_heartbeat_time = time.time()
                            if sc_message.heartbeat: # 接收到的是心跳包
                                print("receive heartbeat")
                                pass
                            else:
                                print("handle message")
                                sc_vision_message = sc_message.sc_vision_message
                                if sc_vision_message.cmd == ProtoMessage.V_CMD.V_UPDATE: # 刷新视觉
                                    print("ready to update vision")
                                    self.update_vision_to_server = True # 将标志切换为True，在外部主循环中会检测这个标志来判断是否更新上传图像
                                
                            self.reset_read_state()
                else:
                    self.do_connect()
                    time.sleep(1)
                time.sleep(0.01)
            except :
                self.connected = False

class HeartbeatSender(threading.Thread):
    """心跳发送器，作为线程被使用
    """
    def __init__(self, server_connection):
        threading.Thread.__init__(self)
        self.server_connection = server_connection
    def run(self):
        """线程运行函数
        """
        while True:
            try:
                print("send heartbeat")
                cs_message = ProtoMessage.CSMessage(client_type = ProtoMessage.ClinetType.VISION)
                cs_message.heartbeat = True
                self.server_connection.send_proto(cs_message)
            except :
                pass
            time.sleep(3)
    pass

def callback_color(image):
    global latest_color
    latest_color = image

def callback_depth(image):
    global latest_depth
    latest_depth = image



def numpy_to_bytes(image_np):
    """将图像的numpy数组转换成压缩后的png，并编码成bytes

    Args:
        image_np (numpy)

    Returns:
        bytes
    """
    # params = [cv2.IMWRITE_JPEG_QUALITY, 100]
    params = [cv2.IMWRITE_PNG_COMPRESSION, 3]
    data = cv2.imencode('.png', image_np, params)[1]
    image_bytes = data.tobytes()
    # print(np.fromstring(image_bytes, dtype=np.uint8)[0:255])
    return image_bytes

def client_vision():
    """视觉节点客户端主函数
    """
    global latest_color
    global latest_depth
    rospy.init_node('client_vision', anonymous=True) # 初始化节点listener

    
    server_connection = ServerConnection(server_ip, server_port) # 线程：服务端连接
    # server_connection = ServerConnection()
    server_connection.start()
    heartbeat_sender = HeartbeatSender(server_connection) # 线程：心跳发送器
    heartbeat_sender.start()

    sub_color = rospy.Subscriber("/camera/color/image_raw", Image, callback_color)
    sub_depth = rospy.Subscriber("/camera/depth/image_raw", Image, callback_depth)

    # 每秒十次频率循环
    rate = rospy.Rate(10) 
    while not rospy.is_shutdown():
        if server_connection.connected:
            # 如果上传图像标志为真（在server_connection线程中更新该标志）
            if (latest_color is not None) and (latest_depth is not None) and server_connection.update_vision_to_server:
                print("update vision")
                # 构造proto协议消息
                cs_message = ProtoMessage.CSMessage(client_type = ProtoMessage.ClinetType.VISION)
                cs_message.heartbeat = False
                cs_vision_message = ProtoMessage.CSVisionMessage(cmd = ProtoMessage.V_CMD.V_UPDATE)
                # 编码颜色和深度图像
                cv_image_color = bridge.imgmsg_to_cv2(latest_color)
                cv_image_depth = bridge.imgmsg_to_cv2(latest_depth)
                # 切割对齐到342x608尺寸
                cv_image_color = cv_image_color[69:411, 0:608]
                cv_image_depth = cv_image_depth[29:371, 32:640]
                # 编码颜色和深度图像
                cs_vision_message.color_image = numpy_to_bytes(cv_image_color)
                cs_vision_message.depth_image = numpy_to_bytes(cv_image_depth)
                cs_message.cs_vision_message.CopyFrom(cs_vision_message) 
                # 发送消息
                server_connection.send_proto(cs_message)
                server_connection.update_vision_to_server = False
        rate.sleep()


if __name__ == '__main__':
    client_vision()



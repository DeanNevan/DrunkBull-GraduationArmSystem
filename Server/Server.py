# -*- coding: utf-8 -*-
"""
@Description: 服务端主要文件，为机械臂、视觉、图形界面三个客户端提供服务
"""
import sys
import os
os.environ["OPENCV_IO_ENABLE_OPENEXR"]="1"
import socket
from socket import error as SocketError
import threading
import time
import protobuf.Message_pb2 as ProtoMessage
import io
import cv2
from PIL import Image
import numpy as np
import matplotlib.pyplot as plt
import imageio
import OpenEXR
import Imath
import time
from depth_restoration.DepthRestoration import DepthRestoration
from cate_pose_estimation.CatePoseEstimation import CatePoseEstimation
import json
import struct


clients = []
client_vision = None
client_arm = None
client_monitor = None
model_depth_restoration = DepthRestoration()        # 深度修复模型的调用类
model_cate_pose_estimation = CatePoseEstimation()   # 位姿估计模型的调用类

def net_listener(s):
    """监听TCP连接，作为线程被使用

    Args:
        s: 服务端socket
    """
    global clients
    while True:
        try:
            new_socket, client_addr = s.accept()
            client = Client(new_socket, client_addr)
            clients.append(client)
            client.last_heartbeat_time = time.time()
            thread_client_handler = threading.Thread(target = client_handler, args=(client,))
            thread_client_handler.start()
            print("new connection")
        except KeyboardInterrupt:
            print("quit")
            break
        time.sleep(0.01)

# def bytes_to_numpy(image_bytes, dtype):    
#     image_np = np.frombuffer(image_bytes, dtype=dtype)
#     image_np2 = cv2.imdecode(image_np, cv2.IMREAD_COLOR)
#     return image_np2

def send_proto_to_client(proto, client):
    """发送protobuf对象到指定客户端

    Args:
        proto (protobuf对象)
        client (Client)
    """
    if client is None:
        return
    serialized_string = proto.SerializeToString()
    serialized_string_length = len(serialized_string)
    print("send proto, size will be:%d" % serialized_string_length)
    head = struct.pack(">I", serialized_string_length)
    send_data_string = head + serialized_string
    client.socket.send(send_data_string)

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
    # rospy.logwarn(np.fromstring(image_bytes, dtype=np.uint8)[0:255])
    return image_bytes

def clients_heartbeat_manager():
    """管理心跳机制
    """
    global clients
    global client_vision
    global client_arm
    global client_monitor
    while True:
        will_disconnect_clients = []
        for client in clients:
            if not client.flag_disconnect:
                time_period = time.time() - client.last_heartbeat_time
                if time_period > 10:
                    print("client %s timeout!" % client)
                    client.flag_disconnect = True
                    client.socket.close()
                    will_disconnect_clients.append(client)
                    if client_vision == client:
                        client_vision = None
                    elif client_arm == client:
                        client_arm = None
                    elif client_monitor == client:
                        client_monitor = None
        for client in will_disconnect_clients:
            clients.remove(client)
        time.sleep(0.01)

def thread_vision_task(cs_message):
    """调用模型（单次任务）

    Args:
        cs_message (protobuf对象，CSMessage)
    """
    global client_monitor
    cs_vision_message = cs_message.cs_vision_message
    
    # 从字节缓冲区中读取颜色和深度图
    color_image_np = np.frombuffer(cs_vision_message.color_image, np.uint8)
    color_image = cv2.imdecode(color_image_np, cv2.IMREAD_COLOR)
    depth_pil_picture_stream = io.BytesIO(cs_vision_message.depth_image)
    depth_pil_picture = Image.open(depth_pil_picture_stream)

    # 对深度图的数据进行单位缩放
    depth_np = np.array(depth_pil_picture)
    depth_np_float = depth_np.astype("float32")
    depth_np_float = depth_np_float * 0.001

    # 调用深度修复模型，同时记录耗时
    time_start = time.time()
    print("===model_depth_restoration===")
    print("start at: %.3fs" % time_start)
    syn_depth_result = model_depth_restoration.work(color_image, depth_np_float)
    time_end = time.time()
    print("end at: %.3fs" % time_end)
    time_cost = time_end - time_start
    print("cost: %.3fs" % time_cost)
    print("=============================")

    # 调用位姿估计模型，同时记录耗时
    time_start = time.time()
    print("===cate_pose_estimation===")
    print("start at: %.3fs" % time_start)
    temp = model_cate_pose_estimation.work(color_image, depth_np_float, syn_depth_result)
    print(temp)
    cate_pose_estimation_result = {}
    if len(temp) > 0:
        cate_pose_estimation_result = temp[0]
    else:
        print("no fitting result")
        return
    serialized_result = {}
    for i in cate_pose_estimation_result:
        serialized_result[i] = cate_pose_estimation_result[i].tolist()
    time_end = time.time()
    print("end at: %.3fs" % time_end)
    time_cost = time_end - time_start
    print("cost: %.3fs" % time_cost)
    print("=============================")

    # imageio.imwrite('img_depth.exr', depth_np_float)
    # imageio.imwrite('img_color.png', color_image)
    # imageio.imwrite('img_depth_restoration.exr', syn_depth_result)
    # with open("result.json", 'w', encoding='utf-8') as f:
    #     json.dump(serialized_result, f)
    
    sc_message = ProtoMessage.SCMessage()
    sc_monitor_message = ProtoMessage.SCMonitorMessage()
    sc_monitor_message.cmd = ProtoMessage.M_CMD.M_UPDATE_VISION
    color_image = cv2.cvtColor(color_image, cv2.COLOR_BGR2RGB)
    sc_monitor_message.color_image = numpy_to_bytes(color_image)

    depth_np = (depth_np - np.min(depth_np)) / (np.max(depth_np) - np.min(depth_np)) * 256
    # sim_depth_np_rgb = np.zeros((depth_np.shape[0], depth_np.shape[1], 3), dtype=np.uint8)
    # sim_depth_np_rgb[:,:,0] = depth_np
    # sim_depth_np_rgb[:,:,1] = depth_np
    # sim_depth_np_rgb[:,:,2] = depth_np

    syn_depth_result = (syn_depth_result - np.min(syn_depth_result)) / (np.max(syn_depth_result) - np.min(syn_depth_result)) * 256
    # syn_depth_result_rgb = np.zeros((syn_depth_result.shape[0], syn_depth_result.shape[1], 3), dtype=np.uint8)
    # syn_depth_result_rgb[:,:,0] = syn_depth_result
    # syn_depth_result_rgb[:,:,1] = syn_depth_result
    # syn_depth_result_rgb[:,:,2] = syn_depth_result

    sc_monitor_message.sim_depth_image = numpy_to_bytes(depth_np)
    sc_monitor_message.syn_depth_image = numpy_to_bytes(syn_depth_result)
    sc_monitor_message.pred_result_json = json.dumps(serialized_result)
    sc_message.sc_monitor_message.CopyFrom(sc_monitor_message)
    sc_message.client_type = ProtoMessage.ClinetType.MONITOR
    sc_message.heartbeat = False
    send_proto_to_client(sc_message, client_monitor)


def client_handler(client):
    """处理客户端发来的数据，以线程的方式被调用

    Args:
        client (Client): 指定客户端
    """
    global clients
    global client_vision
    global client_arm
    global client_monitor
    # 若客户端已连接
    while not client.flag_disconnect: 
        try:
            # 等待数据包头部
            if client.is_waiting_head:
                head_data = client.socket.recv(4) # 4字节大小的包头
                data_len = int.from_bytes(head_data, byteorder='big') # 按大端解码，得到数据包包体大小
                # print(data_len)
                # print(np.fromstring(head_data, dtype=np.uint8))
                if data_len > 0: # 准备读取数据包包体内容
                    client.is_valid = True
                    client.reset()
                    client.expected_bytes_count = data_len
                    client.is_waiting_head = False
                    
            if not client.is_waiting_head: # 读取数据包包体内容
                data = client.socket.recv(client.expected_bytes_count - client.received_bytes_count) # 计划读取剩余所有字节
                data_len = len(data)
                client.received_bytes_count += data_len # 实际读取字节因为TCP分包缘故可能小于计划值，故累加实际值
                client.buf_bytes += data # 将读取到的字节存入字节缓冲区
                assert(client.received_bytes_count <= client.expected_bytes_count)
                if client.received_bytes_count == client.expected_bytes_count: # 读满数据包包体
                    print("new packet received")
                    cs_message = ProtoMessage.CSMessage()
                    cs_message.ParseFromString(client.buf_bytes) # 解码数据包

                    client.last_heartbeat_time = time.time()
                    # 客户端——视觉
                    if cs_message.client_type == ProtoMessage.ClinetType.VISION:
                        # 如果时新的视觉节点，更新客户端对象
                        if client_vision != client:
                            client_vision = client
                        # 如果是心跳包，回复心跳
                        if cs_message.heartbeat:
                            print("heartbeat")
                            sc_message_heartbeat = ProtoMessage.SCMessage(client_type = ProtoMessage.ClinetType.VISION)
                            sc_message_heartbeat.heartbeat = True
                            send_proto_to_client(sc_message_heartbeat, client)
                            client.reset()
                            continue
                        print("handle vision message")

                        # 开启调用模型线程
                        vision_task = threading.Thread(target=thread_vision_task, args=(cs_message,))
                        vision_task.start()
                        
                    # 客户端——机械臂
                    elif cs_message.client_type == ProtoMessage.ClinetType.ARM:
                        if client_arm != client:
                            client_arm = client
                        if cs_message.heartbeat:
                            print("heartbeat")
                            sc_message_heartbeat = ProtoMessage.SCMessage(client_type = ProtoMessage.ClinetType.ARM)
                            sc_message_heartbeat.heartbeat = True
                            send_proto_to_client(sc_message_heartbeat, client)
                            client.reset()
                            continue
                        print("handle arm message")
                        
                    # 客户端——监控软件
                    elif cs_message.client_type == ProtoMessage.ClinetType.MONITOR:
                        if client_monitor != client:
                            client_monitor = client
                        if cs_message.heartbeat:
                            print("heartbeat")
                            sc_message_heartbeat = ProtoMessage.SCMessage(client_type = ProtoMessage.ClinetType.MONITOR)
                            sc_message_heartbeat.heartbeat = False
                            sc_monitor_message = ProtoMessage.SCMonitorMessage(cmd = ProtoMessage.M_CMD.M_UPDATE_CLIENTS)
                            sc_monitor_message.client_arm_online = client_arm is not None
                            sc_monitor_message.client_vision_online = client_vision is not None
                            sc_message_heartbeat.sc_monitor_message.CopyFrom(sc_monitor_message)
                            send_proto_to_client(sc_message_heartbeat, client)
                            client.reset()
                            continue
                        print("handle monitor message")
                        cs_monitor_message = cs_message.cs_monitor_message
                        
                        # 客户端指令：M_UPDATE_VISION，即刷新视觉
                        if cs_monitor_message.cmd == ProtoMessage.M_CMD.M_UPDATE_VISION:
                            sc_message = ProtoMessage.SCMessage(client_type = ProtoMessage.ClinetType.ARM)
                            sc_message.heartbeat = False
                            sc_vision_message = ProtoMessage.SCVisionMessage()
                            sc_vision_message.cmd = ProtoMessage.V_CMD.V_UPDATE
                            sc_message.sc_vision_message.CopyFrom(sc_vision_message)
                            send_proto_to_client(sc_message, client_vision)
                        
                        # 客户端指令：M_CONTROL_ARM_RAW，即以六个舵机的角度的方式原始控制机械臂
                        if cs_monitor_message.cmd == ProtoMessage.M_CMD.M_CONTROL_ARM_RAW:
                            sc_message = ProtoMessage.SCMessage(client_type = ProtoMessage.ClinetType.ARM)
                            sc_message.heartbeat = False
                            sc_arm_message = ProtoMessage.SCArmMessage()
                            sc_arm_message.cmd = ProtoMessage.A_CMD.A_CONTROL_RAW
                            sc_arm_message.control_arm_raw_pos1 = cs_monitor_message.control_arm_raw_pos1
                            sc_arm_message.control_arm_raw_pos2 = cs_monitor_message.control_arm_raw_pos2
                            sc_arm_message.control_arm_raw_pos3 = cs_monitor_message.control_arm_raw_pos3
                            sc_arm_message.control_arm_raw_pos4 = cs_monitor_message.control_arm_raw_pos4
                            sc_arm_message.control_arm_raw_pos5 = cs_monitor_message.control_arm_raw_pos5
                            sc_arm_message.control_arm_raw_pos6 = cs_monitor_message.control_arm_raw_pos6
                            sc_message.sc_arm_message.CopyFrom(sc_arm_message)
                            send_proto_to_client(sc_message, client_arm)
                        
                        # 客户端指令：M_CONTROL_ARM_TARGET，即以指定目标方位的方式原始控制机械臂
                        if cs_monitor_message.cmd == ProtoMessage.M_CMD.M_CONTROL_ARM_TARGET:
                            sc_message = ProtoMessage.SCMessage(client_type = ProtoMessage.ClinetType.ARM)
                            sc_message.heartbeat = False
                            sc_arm_message = ProtoMessage.SCArmMessage()
                            sc_arm_message.cmd = ProtoMessage.A_CMD.A_CONTROL_TARGET
                            sc_arm_message.control_arm_target_x = cs_monitor_message.control_arm_target_x
                            sc_arm_message.control_arm_target_y = cs_monitor_message.control_arm_target_y
                            sc_arm_message.control_arm_target_r = cs_monitor_message.control_arm_target_r
                            sc_message.sc_arm_message.CopyFrom(sc_arm_message)
                            send_proto_to_client(sc_message, client_arm)
                        
                        # 客户端指令：M_CONTROL_ARM_TARGET_FULL，即抓取指定目标（给定目标方位）
                        if cs_monitor_message.cmd == ProtoMessage.M_CMD.M_CONTROL_ARM_TARGET_FULL:
                            sc_message = ProtoMessage.SCMessage(client_type = ProtoMessage.ClinetType.ARM)
                            sc_message.heartbeat = False
                            sc_arm_message = ProtoMessage.SCArmMessage()
                            sc_arm_message.cmd = ProtoMessage.A_CMD.A_CONTROL_TARGET_FULL
                            sc_arm_message.control_arm_target_x = cs_monitor_message.control_arm_target_x
                            sc_arm_message.control_arm_target_y = cs_monitor_message.control_arm_target_y
                            sc_arm_message.control_arm_target_r = cs_monitor_message.control_arm_target_r
                            sc_message.sc_arm_message.CopyFrom(sc_arm_message)
                            send_proto_to_client(sc_message, client_arm)


                    
                    client.reset()
        except SocketError as e:
            return
        time.sleep(0.01)



class Client(object):
    """客户端类
    """
    def __init__(self, socket, addr):
        self.socket = socket
        self.addr = addr
        self.connected = False
        self.expected_bytes_count = 0
        self.received_bytes_count = 0
        self.is_waiting_head = True
        self.buf_bytes = b""
        self.last_heartbeat_time = 0
        self.flag_disconnect = False
        self.is_valid = False
        pass
    
    def __str__(self):
        return "Client:{0}".format(self.addr)
        #return "Client:%s" % self.addr
    
    def reset(self):
        self.is_waiting_head = True
        self.expected_bytes_count = 0
        self.received_bytes_count = 0
        self.buf_bytes = b""

    def connect(self):
        self.connected = True
    
    def disconnect(self):
        self.connected = False

def main():
    global is_alive
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("", 9999))
    s.listen(5)
    print("Waiting for connection...")
    thread_net_listener = threading.Thread(target = net_listener, args = (s,))
    thread_net_listener.start()
    thread_clients_heartbeat_manager = threading.Thread(target = clients_heartbeat_manager)
    thread_clients_heartbeat_manager.start()
    thread_net_listener.join()

if __name__ == "__main__":
    main()
    



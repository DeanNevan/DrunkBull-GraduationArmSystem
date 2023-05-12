# import network
# wlan = network.WLAN(network.STA_IF)
# wlan.active(True)
# wlan.connect('DrunkBull', 'DrunkBull233')
# import mip
# mip.install("logging")
import time
import mek_arm

arm = mek_arm.MekArm()



# print(arm.servos_current_true_deg[0])
# print(arm.servos_target_true_deg[0])
# print(arm.servos_current_percent[0])

# arm.update_all((200, 100), 0)

# print(arm.servos_current_true_deg[0])
# print(arm.servos_target_true_deg[0])
# print(arm.servos_current_percent[0])

last_time = time.ticks_ms() / 1000.0
time.sleep_ms(20)
while True:
    current_time = time.ticks_ms() / 1000.0
    delta_time = current_time - last_time

    arm.process_servos(delta_time)
    print(arm.servos_current_true_deg[0])
    print(arm.servos_target_true_deg[0])
    print(arm.servos_current_percent[0])

    last_time = current_time
    time.sleep_ms(20)



# import Message_upb2 as Message

# message = Message.ScmessageMessage()
# message.heartbeat = False
# message.client_type = Message.Clinettype.ARM

# arm_message = Message.ScarmmessageMessage()
# arm_message.cmd = Message.A_cmd.A_CONTROL_RAW
# arm_message.control_arm_raw_pos1 = 90
# arm_message.control_arm_raw_pos2 = 90
# arm_message.control_arm_raw_pos3 = 90
# # message.sc_arm_message = arm_message.serialize()

# data = arm_message.serialize()
# for i in data:
#     print(i)

# unserialzed_message = Message.ScarmmessageMessage()
# unserialzed_message.parse(data)


# print(unserialzed_message.cmd)
# print(unserialzed_message.control_arm_raw_pos1)

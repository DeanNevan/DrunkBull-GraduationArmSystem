"""
@Description: 重置二轴云台
"""
from VisionServoController import ServoController
from time import sleep
servo_controller = ServoController()
servo_controller.add_servo(14, 150) # 1号舵机pwm引脚连接14号，初始角度150
servo_controller.add_servo(15, 130) # 2号舵机pwm引脚连接15号，初始角度130
sleep(1)

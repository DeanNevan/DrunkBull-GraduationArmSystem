from servo import Servos
from machine import I2C, Pin
from math import cos, sin, atan, sqrt, pow, asin, acos, pi
import math

i2c = I2C(sda=Pin(21), scl=Pin(22), freq=10000)
servos = Servos(i2c, address=0x40)

class MekArm:
    @staticmethod
    def cal_pos(j1, r) -> tuple:
        return (r * cos(j1), r * sin(j1))
    
    @staticmethod
    def cal_j1(x, y) -> float:
        return atan(y / x)
    
    @staticmethod
    def cal_r(x, j1) -> float:
        return x / cos(j1)

    @staticmethod
    def cal_lr(r, g5, g1) -> float:
        return sqrt(pow(r, 2) + pow((g5 - g1), 2))
    
    @staticmethod
    def cal_ji(r, lr) -> float:
        return asin(r / lr)

    @staticmethod
    def cal_i2(lr, g2, g3) -> float:
        return acos((pow(lr, 2) + pow(g2, 2) - pow(g3, 2)) / (2 * lr * g2))
    
    @staticmethod
    def cal_i3(lr, g2, g3) -> float:
        return acos((pow(g3, 2) + pow(g2, 2) - pow(lr, 2)) / (2 * g3 * g2))

    @staticmethod
    def cal_i4(lr, g2, g3) -> float:
        return acos((pow(lr, 2) + pow(g3, 2) - pow(g2, 2)) / (2 * lr * g3))

    @staticmethod
    def cal_j2(ji, i2) -> float:
        return ji - i2
    
    @staticmethod
    def cal_j3(i3) -> float:
        return pi - i3
    
    @staticmethod
    def cal_j4(i4, ji) -> float:
        return pi - i4 - ji
    
    @staticmethod
    def cal_j2_pos(g1) -> tuple:
        return (0, g1)
    
    @staticmethod
    def cal_j3_pos(G1, G2, j2) -> tuple:
        return (G2 * cos(pi / 2 + j2), G1 + G2 * sin(pi / 2 + j2))
    
    @staticmethod
    def cal_j4_pos(r, G5) -> tuple:
        return (-r, G5)
    
    def __init__(self) -> None:
        self.servo_idx_1 = 5
        self.servo_idx_2 = 4
        self.servo_idx_3 = 3
        self.servo_idx_4 = 2
        self.servo_idx_5 = 1
        self.servo_idx_6 = 0

        self.G1 = 0.0
        self.G2 = 0.0
        self.G3 = 0.0
        self.G5 = 0.0
        self.r = 0.0
        self.lr = 0.0

        self.j1 = 0.0
        self.j2 = 0.0
        self.j3 = 0.0
        self.j4 = 0.0
        self.ji = 0.0

        self.i2 = 0.0
        self.i3 = 0.0
        self.i4 = 0.0


    def __str__(self) -> str:
        return "机械臂"

    def 

    

servo_j1 = 5
servo_j2 = 5
servo_j3 = 5
servo_j4 = 5
servo_j5 = 5
servo_j6 = 5




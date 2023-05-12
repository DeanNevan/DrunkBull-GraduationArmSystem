# -*- coding: utf-8 -*-
import logging
import math
import cmath
import time
from machine import I2C, Pin
from servo import Servos
from utils import clamp, lerp_ease_in_out

logging.basicConfig(level=logging.DEBUG)

class ArmStateMachine():
    def __init__(self) -> None:
        # 状态机状态
        self.STATE_IDLE = 0
        self.STATE_RESETING = 1
        self.STATE_MOVING_TO_TARGET_1 = 2
        self.STATE_MOVING_TO_TARGET_2 = 3
        self.STATE_CATCHING = 4
        self.STATE_PULL_UP = 5
        self.STATE_MOVING_BACK = 6
        self.STATE_PUT_DOWN = 7
        self.STATE_RELEASING = 8

        self.STATE_CHAIN = [
            self.STATE_IDLE, 
            self.STATE_MOVING_TO_TARGET_1,
            self.STATE_MOVING_TO_TARGET_2,
            self.STATE_CATCHING,
            self.STATE_PULL_UP,
            self.STATE_MOVING_BACK,
            self.STATE_PUT_DOWN,
            self.STATE_RELEASING,
            self.STATE_PULL_UP,
            self.STATE_RESETING
        ]

        # 每个状态的时间（到时则切换至Task指定的下一状态），单位秒，负数表示无限时长直到外部打断
        self.TIME_EACH_STATE = {
            self.STATE_IDLE : -1,
            self.STATE_RESETING : 2.0,
            self.STATE_MOVING_TO_TARGET_1 : 2.0,
            self.STATE_MOVING_TO_TARGET_2 : 2.0,
            self.STATE_CATCHING : 2.0,
            self.STATE_PULL_UP : 2.0,
            self.STATE_MOVING_BACK : 2.0,
            self.STATE_PUT_DOWN : 2.0,
            self.STATE_RELEASING : 2.0,
        }

        self.current_state = self.STATE_IDLE
        self.current_state_idx = 0

        self.time_state_begin = 0
        self.current_time = 0
    
    def _next_state(self):
        print("_next_state start")
        self.current_state_idx += 1
        if self.current_state_idx >= len(self.STATE_CHAIN):
            self.current_state_idx = 0
        self.current_state = self.STATE_CHAIN[self.current_state_idx]
        self.time_state_begin = self.current_time
        print("_next_state end")
    
    def force_change_state(self, state_idx):
        print("force_change_state start")
        self.current_state_idx = state_idx
        self.current_state = self.STATE_CHAIN[state_idx]
        self.time_state_begin = self.current_time
        print("force_change_state end")
    
    def process(self, delta_time):
        self.current_time += delta_time
        if self.TIME_EACH_STATE[self.current_state] >= 0 and (self.current_time - self.time_state_begin) >= self.TIME_EACH_STATE[self.current_state]:
            # 到时，切换状态
            self._next_state()

class MekArm:
    """
    定义机械臂的长度，单位mm
    工作空间
    坐标calculate 
    """
    # 以下定义机械臂的物理参数，对照手册配图
    G1 = 96.0
    G2 = 106.0
    G3 = 125.0
    G4 = 80.0
    G0 = 1.0  # 小骨
    G6 = 1.0  # 末骨
    G7 = 76  # 抓手长
    J = [0, 0, 0, 0, 0, 0]  # 表示关节角度，J1,J2,J3,J4,J5,J6
    tong_pos = (0, 0)
    work_range = (96, G2+G3-5)
    R = 0
    current_pos = [0, 0, 0, 0, 0, 0]
    current_deg = [0, 0, 0, 0, 0]

    target_pos = (100, 0)
    target_thi = 0

    servo_2_pos_before_pull_up = 0
    servo_3_pos_before_pull_up = 0

    # SERVOS_INIT_TRUE_DEG = [85, 90, 57, 85, 78, 76]
    SERVOS_INIT_TRUE_DEG = [85, 90, 57, 85, 0, 76]
    SERVOS_DIRECTION = [True, False, True, True, True, True]
    SERVOS_TRUE_DEG_RANGE = [
        (0, 180), 
        (0, 180), 
        (0, 180), 
        (0, 180), 
        (0, 180), 
        (76, 136)
    ]
    SERVO_CATCH_POS = 136
    SERVO_RELEASE_POS = 76
    SERVOS_SPEED = [0.2, 0.2, 0.2, 0.2, 0.2, 0.2]
    SERVOS_IDX = [5, 4, 3, 2, 1, 0]
    
    servos_target_true_deg = [i for i in SERVOS_INIT_TRUE_DEG]
    servos_current_true_deg = [i for i in SERVOS_INIT_TRUE_DEG]
    servos_current_percent = [0, 0, 0, 0, 0, 0] # 各舵机当前已朝目标角度转动的百分比

    i2c = I2C(sda=Pin(21), scl=Pin(22), freq=10000)
    servos = Servos(i2c, address=0x40)

    state_machine = ArmStateMachine()

    last_state = state_machine.STATE_IDLE

    def __init__(self):
        pass

    def start_catch_task(self, pos, thi):
        """开始抓取任务

        Args:
            pos (元组，二维工作平面坐标): 目标位置
            thi (float): 目标主方向与机械臂x轴夹角
        """
        print("catch task! x:%.2f, y:%.2f, thi:%.2f" % (pos[0], pos[1], thi))
        self.target_pos = pos
        self.target_thi = thi
        self.last_state = 0
        # 强制切换状态机状态到1——STATE_RESETING，以便开启自动抓取流程
        self.state_machine.force_change_state(1)

    def reset_servos_percent(self):
        self.servos_current_percent = [0, 0, 0, 0, 0, 0]

    def process(self, delta_time):
        """process函数通过传入的delta_time以获悉系统经过的时间，该函数被频繁调用，每次调用都会更新系统工作情况

        Args:
            delta_time (float): 单位秒，距离上次process调用经过的时间
        """
        self.state_machine.process(delta_time)
        if self.state_machine.current_state != self.last_state:
            # 抓取任务
            # 按照状态机当前状态执行不同代码
            state = self.state_machine.current_state
            if state == self.state_machine.STATE_IDLE:
                print("===STATE_IDLE===")
                pass
            if state == self.state_machine.STATE_RESETING:
                print("===STATE_RESETING===")
                self.reset_servos_percent()
                self.servos_target_true_deg = [i for i in self.SERVOS_INIT_TRUE_DEG]
                pass
            if state == self.state_machine.STATE_MOVING_TO_TARGET_1:
                print("===STATE_MOVING_TO_TARGET_1===")
                self.reset_servos_percent()
                temp = [i for i in self.servos_target_true_deg]
                self.set_target(self.target_pos, self.target_thi)
                self.servos_target_true_deg[1] = temp[1]
                self.servos_target_true_deg[2] = temp[2]
                pass
            if state == self.state_machine.STATE_MOVING_TO_TARGET_2:
                print("===STATE_MOVING_TO_TARGET_2===")
                self.reset_servos_percent()
                self.set_target(self.target_pos, self.target_thi)
                pass
            if state == self.state_machine.STATE_CATCHING:
                print("===STATE_CATCHING===")
                self.reset_servos_percent()
                self.servos_target_true_deg[5] = self.SERVO_CATCH_POS
                pass
            if state == self.state_machine.STATE_PULL_UP:
                print("===STATE_PULL_UP===")
                self.reset_servos_percent()
                self.servo_2_pos_before_pull_up = self.servos_target_true_deg[1]
                self.servo_3_pos_before_pull_up = self.servos_target_true_deg[2]
                self.servos_target_true_deg[1] = self.SERVOS_INIT_TRUE_DEG[1]
                self.servos_target_true_deg[2] = self.SERVOS_INIT_TRUE_DEG[2]
                pass
            if state == self.state_machine.STATE_MOVING_BACK:
                print("===STATE_MOVING_BACK===")
                self.reset_servos_percent()
                self.servos_target_true_deg[0] = 0
                pass
            if state == self.state_machine.STATE_PUT_DOWN:
                print("===STATE_PUT_DOWN===")
                self.reset_servos_percent()
                self.servos_target_true_deg[1] = self.servo_2_pos_before_pull_up
                self.servos_target_true_deg[2] = self.servo_3_pos_before_pull_up
                pass
            if state == self.state_machine.STATE_RELEASING:
                print("===STATE_RELEASING===")
                self.reset_servos_percent()
                self.servos_target_true_deg[5] = self.SERVO_RELEASE_POS
                pass
            pass

        for i in range(0, len(self.servos_current_percent)):
            self.servos_current_percent[i] = clamp(self.servos_current_percent[i] + self.SERVOS_SPEED[i] * delta_time, 0, 1)

        for i in range(0, len(self.servos_current_true_deg)):
            self.servos_current_true_deg[i] = lerp_ease_in_out(
                self.servos_current_true_deg[i],
                self.servos_target_true_deg[i],
                self.servos_current_percent[i]
            )
        
        for i in range(0, len(self.servos_current_true_deg)):
            self.servos.position(self.SERVOS_IDX[i], self.servos_current_true_deg[i])
        
        self.last_state = self.state_machine.current_state


    def set_target(self, target_pos, target_thi):
        self.target_pos = target_pos
        self.target_thi = target_thi
        res, self.J[0], self.J[4], self.R = MekArm.cal_j1_j5_R(self.G0, self.G6, self.work_range, target_pos[0], target_pos[1], target_thi)
        if not res:
            return False
        print("R is:%.2f" % self.R)
        print("work range is from %.2f to %.2f" % (self.work_range[0], self.work_range[1]))
        res, self.J[1], self.J[2], self.J[3] = MekArm.cal_j2_j3_j4(self.G1, self.G2, self.G3, self.G4, self.G7, self.R)
        if not res:
            return False
        res, self.tong_pos = MekArm.cal_tong_pos(self.J[0], self.R)
        if not res:
            return False

        for i in range(0, len(self.J)):
            delta_deg = self.J[i]
            if not self.SERVOS_DIRECTION[i]:
                delta_deg = -delta_deg
            
            self.servos_target_true_deg[i] = clamp(
                self.SERVOS_INIT_TRUE_DEG[i] + delta_deg, 
                self.SERVOS_TRUE_DEG_RANGE[i][0], 
                self.SERVOS_TRUE_DEG_RANGE[i][1]
            )
        

        self.reset_servos_percent()
        return True
        pass

    @staticmethod
    def cal_j1_r(tong_pos):
        """
        #已知tong_pos，求J1单位/°,R距离/mm
        """
        try:
            (x, y) = tong_pos
            J1 = math.atan(y / x) / math.pi*180
            return True, (x / math.cos(J1), J1)
        except Exception as e:
            logging.error("cal_j1_r error:%s" % e)
            return False, (0, 0)

    @staticmethod
    def cal_tong_pos(J1, R):
        """
        #已知J1单位/°,R距离/mm，求tong_pos
        """
        try:
            (x, y) = (0, 0)
            x = R*math.cos(J1/180*math.pi)
            y = R*math.sin(J1/180*math.pi)
            return True, (round(x, 2), round(y, 2))
        except Exception as e:
            logging.error("cal_j1 error:%s" % e)
            return False, (0, 0)

    @staticmethod
    def cal_j1(x, y):
        """
        #已知tong_pos，求J1单位/°,R距离/mm
        """
        try:
            R = math.sqrt(x**2+y**2)
            J1 = math.degrees(cmath.polar(complex(x, y))[1])
            return True, (round(R, 2), round(J1, 2))
        except Exception as e:
            logging.error("cal_j1 error:%" % e)
            return False, (0, 0)

    @staticmethod
    def judge_quadrant(x, y):
        """
        根据直角坐标（x,y）,判断在第几象限
        返回值
        1:第一象限
        2:第二象限
        3:第三象限
        4:第四象限
        10:在x正半轴
        -10:在x负半轴
        20:在y正半轴
        -20:在y负半轴
        0:在坐标原点
        """
        if x > 0 and y > 0:
            return 1
        elif x < 0 and y > 0:
            return 2
        elif x < 0 and y < 0:
            return 3
        elif x > 0 and y < 0:
            return 4
        elif x > 0 and y == 0:
            return 10
        elif x < 0 and y == 0:
            return -10
        elif x == 0 and y > 0:
            return 20
        elif x == 0 and y < 0:
            return -20
        else:
            return 0

    @staticmethod
    def cal_j5_pos(g6, g0, x0, y0, thi):
        """
        已知物体的坐标，主方向，cal_j1、J6、R
        x0，y0为物体中心点坐标
        thi为物体主方向与机械臂x轴的逆时针夹角°
        """
        try:
            x5 = x0+g6*math.cos(math.radians(thi))
            x5i = x0+g6*math.cos(math.radians(180+thi))
            y5 = y0+g6*math.sin(math.radians(thi))
            y5i = y0+g6*math.sin(math.radians(180+thi))
            r = math.sqrt(x5**2+y5**2)
            ri = math.sqrt(x5i**2+y5i**2)
            # print("x5,y5,x5i,y5i,r,ri",x5,y5,x5i,y5i,r,ri)

            if r <= ri and g0 < r:
                return True, (x5, y5)
            elif r <= ri and g0 < ri and g0 > r:
                return True, (x5i, y5i)
            elif r > ri and g0 < ri:
                return True, (x5i, y5i)
            elif r > ri and g0 < r and g0 > ri:
                return True, (x5, y5)
            else:
                logging.error("cannot calculate  J5，woring target value")
                return False, (x5, y5)

        except Exception as e:
            logging.error("calculate cal_j5_pos error:%s" % e)
            return False, (0, 0)

    @staticmethod
    def cal_deg_3_points(p1, p0, p2):
        """
        calculate 向量P0-->p1至 P0-->p2的逆时针转角
        math.degrees(x)弧度转换为角度
        math.radians(x)角度转弧度
        cn = complex(3,4)
        cmath.polar(cn)  #返回长度和弧度
        cn1 = cmath.rect(2, cmath.pi)极坐标转直直角坐标
        cn1.real，cn1.imag#返回x,y
        """

        try:
            (x0, y0) = p0
            (x1, y1) = p1
            (x2, y2) = p2

            # 向量P0-->p1的极坐标转角
            x = x1-x0
            y = y1-y0
            alpha1 = math.degrees(cmath.polar(complex(x, y))[1])
            # 向量P0-->p2的极坐标转角
            x = x2-x0
            y = y2-y0
            alpha2 = math.degrees(cmath.polar(complex(x, y))[1])

            alpha = alpha2-alpha1
            return True, round(alpha, 2)
        except Exception as e:
            logging.error("calculate cal_j5_pos error:%s" % e)
            return False, 0

    @staticmethod
    def cal_j1_j5_R(g0, g6, work_range, x0, y0, thi):
        """
        已知物体的坐标，主方向，cal_j1、J5、R
        x0，y0为物体中心点坐标
        thi为物体主方向与机械臂x轴的逆时针夹角°
        """
        (minr, maxr) = work_range
        try:
            res, pJ5 = MekArm.cal_j5_pos(g0, g6, x0, y0, thi)
            if pJ5 != 0:
                (x5, y5) = pJ5
                # print("Pj5:",pJ5)
                cr = math.sqrt(x5**2+y5**2)
                i1 = math.degrees(cmath.polar(complex(x5, y5))[1])
                R = math.sqrt(cr**2-g0**2)
                i2 = math.degrees(math.asin(g0/cr))
                J1 = i1+i2
                p0 = (x0, y0)  # 目标点中心坐标
                res, pm = MekArm.cal_tong_pos(J1, R)  # 假想目标点中心坐标
                res, J5 = MekArm.cal_deg_3_points(p0, pJ5, pm)
                if R < minr or R > maxr:
                    logging.error("not in work_range, R:%.2f" % R)
                    return False, round(J1, 2), round(J5, 2), round(R, 2)
                else:
                    return True, round(J1, 2), round(J5, 2), round(R, 2)
            else:
                logging.error("cal_j1_j5_R error")
                return False, round(J1, 2), round(J5, 2), round(R, 2)
        except Exception as e:
            logging.error("calculate cal_j1_j5_R error:%s" % e)
            return False, 0, 0, 0

    @staticmethod
    def cal_j2_j3_j4(g1, g2, g3, g4, g7, r):
        """
        已知
            g1=self.G1
            g2=self.G2
            g3=self.G3
            g4=self.G4
            g5=g4+self.G7  
            r=self.R
        求关节，J2、J3、J4
        """
        try:
            g5 = g4+g7

            lr = math.sqrt(r**2+(g5-g1)**2)
            Ji = math.asin(r/lr)/math.pi*180
            i2 = math.acos((lr**2+g2**2-g3**2)/(2*lr*g2))/math.pi*180
            i3 = math.acos((g3**2+g2**2-lr**2)/(2*g3*g2))/math.pi*180
            i4 = math.acos((lr**2+g3**2-g2**2)/(2*lr*g3))/math.pi*180
            J2 = Ji-i2
            J3 = 180-i3
            J4 = 180-i4-Ji
            # print("calculate 结果",lr,Ji,i2,i3,i4,J2,J3,J4)
            return True, J2, J3, J4
        except Exception as e:
            logging.error("cal_j2_j3_j4 error:", e)
            return False, 0, 0, 0

    @staticmethod
    def cal_joints_pos(g1, g2, g4, g7, r, J2):
        """
        已知关节旋转角度，求在R平面的关节坐标
        """
        g5 = g4+g7

        try:

            x = [0, 0, 0, 0, 0]
            y = [0, 0, 0, 0, 0]
            x[1] = 0  # 关节J2的x坐标
            y[1] = g1  # 关节J2的y坐标
            x[2] = g2*math.cos((90+J2)/180*math.pi)
            y[2] = g1+g2*math.sin((90+J2)/180*math.pi)
            x[3] = -r
            y[3] = g5
            x[4] = -r
            y[4] = 0
            return True, (x, y)
        except Exception as e:
            logging.error("calculate points error:%s" % e)
            return False, (0, 0)

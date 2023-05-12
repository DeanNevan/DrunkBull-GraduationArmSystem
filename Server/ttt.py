# -*- coding: utf-8 -*-
"""
Created on Sat Jul 31 11:29:37 2021
@author: JAMES费
"""
 
import matplotlib.animation as animation
import matplotlib.pyplot as plt
import sys
import logging
import time
import numpy as np
import math
import cmath
import cv2
logging.basicConfig(level=logging.DEBUG)
 
 
class Mini_Arm:
    """
    定义机械臂的长度，单位mm
    工作空间
    坐标计算
    """
    exval={
            "com":"COM21",
            "baud":115200,
            "port":6666,
            "host":"localhost"
            }    
    #以下定义机械臂的物理参数，对照手册配图
    骨长1=170.46
    骨长2=136.35
    骨长3=100
    骨长4=75
    小骨长=80
    末骨长=62.4
    抓手长=60
    J=[0,0,0,0,0,0] #表示关节角度，J1,J2,J3,J4,J5,J6
    抓手坐标=(0,0)
    工作半径范围=(50,骨长2+骨长3-5)
    R=0
    mycobot=None
    当前坐标=[0,0,0,0,0,0]
    当前角度=[0,0,0,0,0]
    winevent={
            "doubleclick":0,
            "keymod":0
            }
    winH=900
    winW=1600
    pz2=(int(winW*3/4),int(winH/3))
    p0=(None,None)
    thi=0
    pJ5=(None,None)
    
    
    def __init__(self, **kwargs):
        
        """
        初始化类:
                串口:com="COM21"
                波特率:baud=115200
                web端口:port=6666
                主机地址：host="localhost"
        """
        self.mathods=dir(self) 
        
        for k,v in kwargs.items():
            if k in self.exval.keys():                
                self.exval[k]=v
        
        #self.mycobot = MyCobot(self.exval["com"])
        cv2.namedWindow('mini_arm')
        cv2.setMouseCallback('mini_arm',self.mousecallback)
        #print(self.exval["com"])
    
 
    #监听点击像素坐标
    def mousecallback(self,event,x,y,flags,param):
         if event==cv2.EVENT_LBUTTONDBLCLK:             
             if self.winevent["keymod"]==1:
                 self.根据窗口点击计算目标点(x,y)
                 print("点击坐标点",(x,y))
                 
                 
 
    def 根据窗口点击计算目标点(self,x,y):
        #转化为机械臂坐标
        (px,py)=self.pz2
       
        #r=np.sqrt((x-px)**2+(py-y)**2) 
        (x0,y0)=(x-px,py-y)
        self.thi=30
        res,J1,J5,R=self.计算J1_5_R(x0,y0,self.thi) 
        if res!=True:
            print("out of workspace")
            self.p0=(None,None)
        else:   
            self.p0=(x0,y0)            
            self.J[0],self.J[4],self.R=J1,J5,R
            print("计算结果J1，J5，R：",[self.J[0],self.J[4],self.R])
            print("目标点坐标",self.p0)
 
        #计算其它坐标
        
        return 1
    
    
    def 计算J1和R(self):
        """
        #已知抓手坐标，求J1单位/°,R距离/mm
        """        
        try:
             (x,y)=self.抓手坐标
             J1=np.arctan(y/x)/np.pi*180
             self.R=x/np.cos(J1)
             self.J[0]=J1
             return 1
        except Exception as e:
             logging.error("计算J1异常：",e)    
    
 
    def 计算抓手坐标(self,J1,R): 
        """
        #已知J1单位/°,R距离/mm，求抓手坐标
        """
        try:
             (x,y)=(0,0)
             x=R*np.cos(J1/180*np.pi)
             y=R*np.sin(J1/180*np.pi)
             return (round(x, 2),round(y, 2))
        except Exception as e:
             logging.error("计算J1异常：",e)   
        
    
    def 计算J1(self,x,y):  
        """
        #已知抓手坐标，求J1单位/°,R距离/mm
        """
        try:
             R=np.sqrt(x**2+y**2)             
             J1=math.degrees(cmath.polar(complex(x,y))[1])
             return round(R, 2),round(J1, 2)
        except Exception as e:
             logging.error("计算J1异常：",e)  
 
 
    def 判断象限(self,x,y):
        """
        根据直角坐标（x,y）,判断在第几象限
        返回值
        1：第一象限
        2：第二象限
        3：第三象限
        4：第四象限
        10：在x正半轴
        -10：在x负半轴
        20：在y正半轴
        -20：在y负半轴
        0:在坐标原点
        """
        if x>0 and y>0:
            return 1
        elif x<0 and y>0:
            return 2
        elif x<0 and y<0:
            return 3
        elif x>0 and y<0:
            return 4
        elif x>0 and y==0:
            return 10
        elif x<0 and y==0:
            return -10
        elif x==0 and y>0:
            return 20
        elif x==0 and y<0:
            return -20
        else:
            return 0
            
    def 计算J5坐标(self,x0,y0,thi):
        """
        已知物体的坐标，主方向，计算J1、J6、R
        x0，y0为物体中心点坐标
        thi为物体主方向与机械臂x轴的逆时针夹角°
        """
        g6=self.末骨长
        g0=self.小骨长
        try:        
            x5=x0+g6*np.cos(math.radians(thi))
            x5i=x0+g6*np.cos(math.radians(180+thi))
            y5=y0+g6*np.sin(math.radians(thi))
            y5i=y0+g6*np.sin(math.radians(180+thi))
            r=np.sqrt(x5**2+y5**2)
            ri=np.sqrt(x5i**2+y5i**2)  
            #print("x5,y5,x5i,y5i,r,ri",x5,y5,x5i,y5i,r,ri)
                        
            if r<=ri and g0<r:
                return (x5,y5)
            elif r<=ri and g0<ri and g0>r:
                return (x5i,y5i)
            elif r>ri and g0<ri:
                return (x5i,y5i)
            elif r>ri and g0<r and g0>ri:
                return (x5,y5)
            else:
                self.p0=(None,None)
                logging.error("cannot 计算 J5，woring 目标值")
                return False
                
        except Exception as e:
             logging.error("计算计算J5坐标异常：",e)        
 
    def 计算三点逆时针角度(self,p1,p0,p2):
        """
        计算向量P0-->p1至 P0-->p2的逆时针转角
        math.degrees(x)弧度转换为角度
        math.radians(x)角度转弧度
        cn = complex(3,4)
        cmath.polar(cn)  #返回长度和弧度
        cn1 = cmath.rect(2, cmath.pi)极坐标转直直角坐标
        cn1.real，cn1.imag#返回x,y
        """
 
        try:     
            (x0,y0)=p0
            (x1,y1)=p1
            (x2,y2)=p2 
            
            #向量P0-->p1的极坐标转角
            x=x1-x0
            y=y1-y0
            alpha1=math.degrees(cmath.polar(complex(x,y))[1])
            #向量P0-->p2的极坐标转角
            x=x2-x0
            y=y2-y0
            alpha2=math.degrees(cmath.polar(complex(x,y))[1])    
            
            alpha=alpha2-alpha1
            return round(alpha, 2)  
        except Exception as e:
             logging.error("计算计算J5坐标异常：",e)   
 
        
 
    
    def 计算J1_5_R(self,x0,y0,thi): 
        """
        已知物体的坐标，主方向，计算J1、J5、R
        x0，y0为物体中心点坐标
        thi为物体主方向与机械臂x轴的逆时针夹角°
        """
        g0=self.小骨长
        (minr,maxr)=self.工作半径范围
        try:
                            
            pJ5=self.计算J5坐标(x0,y0,thi)
            if pJ5!=0:
                               
                (x5,y5)=pJ5
                self.pJ5=pJ5
                #print("Pj5:",pJ5)
                cr=np.sqrt(x5**2+y5**2)
                i1=math.degrees(cmath.polar(complex(x5,y5))[1])                
                R=np.sqrt(cr**2-g0**2)
                i2=math.degrees(np.arcsin(g0/cr))
                J1=i1+i2
                p0=(x0,y0)#目标点中心坐标
                pm=self.计算抓手坐标(J1,R)#假想目标点中心坐标
                J5=self.计算三点逆时针角度(p0,pJ5,pm)
                if R<minr or R>maxr:
                    logging.error("超出工作范围")
                    return False,self.J[0],self.J[4],self.R
                else:
                    return True,round(J1, 2),round(J5, 2),round(R, 2)
            else:
                logging.error("计算J1_5_R异常")
                return False,self.J[0],self.J[4],self.R
        except Exception as e:
            logging.error("计算计算J1_5_R异常：",e)          
    
    def 计算J2_4(self):
        """
        已知
            g1=self.骨长1
            g2=self.骨长2
            g3=self.骨长3
            g4=self.骨长4
            g5=g4+self.抓手长  
            r=self.R
        求关节，J2、J3、J4
        """
        try:
            g1=self.骨长1
            g2=self.骨长2
            g3=self.骨长3
            g4=self.骨长4
            g5=g4+self.抓手长  
            r=self.R
            
            lr=np.sqrt(r**2+(g5-g1)**2)
            Ji=np.arcsin(r/lr)/np.pi*180;
            i2=np.arccos((lr**2+g2**2-g3**2)/(2*lr*g2))/np.pi*180
            i3=np.arccos((g3**2+g2**2-lr**2)/(2*g3*g2))/np.pi*180
            i4=np.arccos((lr**2+g3**2-g2**2)/(2*lr*g3))/np.pi*180
            J2=Ji-i2
            J3=180-i3
            J4=180-i4-Ji
            self.J[1]=J2
            self.J[2]=J3
            self.J[3]=J4    
            #print("计算结果",lr,Ji,i2,i3,i4,J2,J3,J4)
            return 1
        except Exception as e:
             logging.error("计算J2_4异常：",e)    
    def 计算各关节点坐标(self):
        """
        已知关节旋转角度，求在R平面的关节坐标
        """
        g1=self.骨长1
        g2=self.骨长2
        g3=self.骨长3
        g4=self.骨长4
        g5=g4+self.抓手长  
        r=self.R
        J2=self.J[1]
        
        try:
            
            x=[0,0,0,0,0] 
            y=[0,0,0,0,0]
            x[1]=0#关节J2的x坐标
            y[1]=g1#关节J2的y坐标
            x[2]=g2*np.cos((90+J2)/180*np.pi)
            y[2]=g1+g2*np.sin((90+J2)/180*np.pi)
            x[3]=-r
            y[3]=g5 
            x[4]=-r
            y[4]=0
            return (x,y)
        except Exception as e:
             logging.error("计算各点坐标异常：",e) 
             
    def ui(self,H,W):
            #text format
        org = (40, 80)
        fontFace = cv2.FONT_HERSHEY_COMPLEX
        fontScale = 0.5
        fontcolor = (0, 255, 0) # BGR
        thickness = 1 
        lineType = 4
        bottomLeftOrigin = 1
        
        while 1: 
            #背景颜色               高，宽
            self.winH=H
            self.winW=W
            background = np.zeros((H, W, 3), np.uint8) #生成一个空灰度图像        
            
            key = cv2.waitKey(1)
            if int(key) == ord('q'):
                cv2.destroyWindow('mini_arm')
                break
            if self.winevent["keymod"]==0:
                if int(key) == ord('['):
                    self.J[0]+=2
                    if self.J[0]>=160:
                        self.J[0]=160
                if int(key) == ord(']'):
                    self.J[0]-=2
                    if self.J[0]<=-160:
                        self.J[0]=-160
                if int(key) == ord('w'):
                    self.R+=2
                    if self.R>=self.工作半径范围[1]:
                        self.R=self.工作半径范围[1]
                if int(key) == ord('s'):
                    self.R-=2
                    if self.R<=self.工作半径范围[0]:
                        self.R=self.工作半径范围[0]
                if int(key)==ord('z'):
                    self.R=200
                    self.J[0]=0
            else:
                if int(key) == ord('['):
                    self.thi+=2
                    if self.thi>=180:
                        self.thi=180
                    res,J1,J5,R=self.计算J1_5_R(self.p0[0],self.p0[1],self.thi) 
                    if res:
                        self.J[0],self.J[4],self.R=J1,J5,R
      
                    
                if int(key) == ord(']'):
                    self.thi-=2
                    if self.thi<=-180:
                        self.thi=-180
                    res,J1,J5,R=self.计算J1_5_R(self.p0[0],self.p0[1],self.thi) 
                    if res:
                        self.J[0],self.J[4],self.R=J1,J5,R 
 
            
            if int(key)==ord('o'):
                if self.winevent["keymod"]==0:
                    self.winevent["keymod"]=1
                else:
                    self.winevent["keymod"]=0            
            #update(a,axes) 
            
            
            if self.winevent["keymod"]==1:
                text = "window selected mod press o to esc"
                (px,py)=self.pz2
                if self.p0 !=(None,None) and self.pJ5!=(None,None):
                    p=self.计算抓手坐标(self.J[0],self.R)
                    px0=px+int(p[0])
                    py0=py-int(p[1])  
                    cv2.circle(background,(int(self.p0[0]+px),int(py-self.p0[1])),5,(255,255,255),-1) 
                    cv2.circle(background,(int(self.pJ5[0]+px),int(py-self.pJ5[1])),5,(255,255,255),-1) 
                    cv2.line(background,(px0,py0),(int(self.pJ5[0]+px),int(py-self.pJ5[1])),(255,0,255),4,cv2.LINE_AA)
                    
                
            else:
                text = "keyboard manhand control mod " 
                tips="press [/] turn J1,w/s to front / back"
                cv2.putText(background, tips, (W-400, 30), fontFace, fontScale, fontcolor, thickness, lineType)       
            cv2.putText(background, text, (W-400, 10), fontFace, fontScale, fontcolor, thickness, lineType)        
                
 
            #######绘制左边边的坐标图
            pz1=(int(W*1.5/4),int(H/2))#左侧坐标的原点
            
            if self.计算J2_4():
                point=self.计算各关节点坐标()
                x=point[0]
                y=point[1]
                ##画关节点
                num=0
                bones=[]           
                for dx,dy,j in zip(x,y,self.J):
                    tx=pz1[0]+int(dx)
                    ty=pz1[1]-int(dy) 
                    bones.append((tx,ty))
                    cv2.circle(background,(tx,ty),5,(255,255,0),-1) 
                            #画标注
                    text = str((round(dx, 2),round(dy, 2)))+"J:"+str(round(j, 2))+"'"
                    #text = 'angles:little[ddd'+str(888)
                    cv2.putText(background, text, (tx+8, ty-8), fontFace, fontScale, fontcolor, thickness, lineType)
                    
                   
                ##画骨架
                for i in range(4):                
                    cv2.line(background,bones[i],bones[i+1],(255,0,255),4,cv2.LINE_AA)
                    
    
            
            #######绘制右边的坐标图
            
            pz2=(int(W*3/4),int(H/3))#旋转坐标的原点
            self.pz2=pz2
            #计算抓手坐标及转换成图像坐标        
            p=self.计算抓手坐标(self.J[0],self.R)
            px=pz2[0]+int(p[0])
            py=pz2[1]-int(p[1])       
            
            ###画半径
            cv2.circle(background,pz2,int(self.R),(0,0,255),2)  #画圆
 
            
            #画抓手坐标点
            cv2.circle(background,(px,py),5,(0,255,255),-1)  #画圆
 
            #画标注
            text = str(p)+"J1:"+str(self.J[0])
            #text = 'angles:little[ddd'+str(888)
            cv2.putText(background, text, (px+8, py-8), fontFace, fontScale, fontcolor, thickness, lineType)
            
            cv2.line(background,pz2,(px,py),(0,255,255),2,cv2.LINE_AA)
            
            #计算边界线
            p=self.计算抓手坐标(160,self.R)
            px=pz2[0]+int(p[0])
            py=pz2[1]-int(p[1]) 
            pyy=pz2[1]+int(p[1]) 
            cv2.line(background,pz2,(px,py),(0,0,255),4,cv2.LINE_AA)
            cv2.line(background,pz2,(px,pyy),(0,0,255),4,cv2.LINE_AA)
            
     
           
    
            cv2.imshow('mini_arm',background)
        
 
    
if __name__ == '__main__':
    a=Mini_Arm()    
    a.R=200
    a.J[0]=30
    print("正解抓手坐标为：",a.计算抓手坐标(a.J[0],a.R))
    
    x=173.20
    y=100
    print("正解抓手J1为：",a.计算J1(x,y))
 
    a.ui(900,1600)
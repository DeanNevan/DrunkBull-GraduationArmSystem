import argparse
import json
import logging
import os
os.environ["OPENCV_IO_ENABLE_OPENEXR"]="1"
import random
import sys
import time
import numpy as np
from PIL import Image
import imgaug as ia
from imgaug import augmenters as iaa
from numpy.core.fromnumeric import put
from numpy.lib.twodim_base import mask_indices
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.tensorboard import SummaryWriter
from torch.nn.modules.loss import CrossEntropyLoss
from torch.utils.data import DataLoader
from tqdm import tqdm
from torchvision import transforms
import cv2
import matplotlib.pyplot as plt
import time
import copy
import math
import _pickle as cPickle
from utils.metrics_nocs import align , draw_detections , compute_degree_cm_mAP ,prepare_data_posefitting

input_only = [
    "simplex-blend", "add", "mul", "hue", "sat", "norm", "gray", "motion-blur", "gaus-blur", "add-element",
    "mul-element", "guas-noise", "lap-noise", "dropout", "cdropout"
]

# Validation Dataset
augs_test = iaa.Sequential([
    iaa.Resize({
        "height": 224,
        "width": 224
    }, interpolation='nearest'),
])

class CatePoseEstimationWorker():
    def __init__(self, args, model, device_list, continue_ckpt_path):
        if continue_ckpt_path is not None:
            msg = model.load_state_dict(torch.load(continue_ckpt_path)['model_state_dict'])
            print("self trained swin unet", msg)
        
        self.material_mask = {'transparent': args.mask_transparent,
                              'specular': args.mask_specular,
                              'diffuse': args.mask_diffuse}

        self.data_path_val = args.val_data_path
        
        if args.val_depth_path :
            self.val_depth_path = args.val_depth_path
        else :
            self.val_depth_path = args.val_data_path
        self.output_path = args.output_dir
        self.obj_path_train = args.train_obj_path
        if args.val_obj_path :
            self.obj_path_val = args.val_obj_path
        else :
            self.val_depth_path = args.train_obj_path

        self.num_classes = args.num_classes
        self.batch_size = args.batch_size * args.n_gpu

        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        
        self.val_data_type = args.val_data_type

        # realsense D415 
        self.fx_real_input = 918.295227050781           
        self.fy_real_input = 917.5439453125             
        self.fx_real_label = 918.295227050781 / 2.0
        self.fy_real_label = 917.5439453125 / 2.0

        # simulated depth sensor
        self.fx_sim = 446.31
        self.fy_sim = 446.31

        # the shape of depth map for computing metrics
        self.get_metrics_w = 224
        self.get_metrics_h = 126

        if args.n_gpu > 1:
            self.model = nn.DataParallel(model, device_list)
        else:
            self.model = model
        
        self.writer = SummaryWriter(self.output_path + '/log')
        # from datasets.dataset_synapse import Synapse_dataset, RandomGenerator
        logging.basicConfig(filename=self.output_path + "/log.txt", level=logging.INFO,
                            format='[%(asctime)s.%(msecs)03d] %(message)s', datefmt='%H:%M:%S')
        logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
        logging.info(str(args))
    

    def transfer_to_device(self, sample_batched):
        for key in sample_batched:
            sample_batched[key] = sample_batched[key].to(self.device)
        return sample_batched

    def transfer_to_cpu(self, sample_batched):
        for key in sample_batched:
            sample_batched[key] = sample_batched[key].to('cpu')
        return sample_batched

    def forward(self, sample_batched, mode):
        rgbs = sample_batched['rgb']
        sim_xyzs = sample_batched['sim_xyz']
        sim_ds = sample_batched['sim_depth']
        syn_ds = sample_batched['syn_depth']
        pred_sem_seg, pred_coords  = self.model(rgbs, sim_xyzs)    # [bs, 150, 512, 512], [bs, 150, 512, 512])
        return pred_sem_seg, pred_coords
    
    def _activator_masks(self, images, augmenter, parents, default):
        '''Used with imgaug to help only apply some augmentations to images and not labels
        Eg: Blur is applied to input only, not label. However, resize is applied to both.
        '''
        if input_only and augmenter.name in input_only:
            return False
        else:
            return default 
    
    def compute_xyz(self, depth_img, camera_params):
        """ Compute ordered point cloud from depth image and camera parameters.

            If focal lengths fx,fy are stored in the camera_params dictionary, use that.
            Else, assume camera_params contains parameters used to generate synthetic data (e.g. fov, near, far, etc)

            @param depth_img: a [H x W] numpy array of depth values in meters
            @param camera_params: a dictionary with parameters of the camera used
        """
        # Compute focal length from camera parameters
        fx = camera_params['fx']
        fy = camera_params['fy']
        x_offset = camera_params['cx']
        y_offset = camera_params['cy']
        indices = np.indices((int(camera_params['yres']), int(camera_params['xres'])), dtype=np.float32).transpose(1,2,0)
        z_e = depth_img
        x_e = (indices[..., 1] - x_offset) * z_e / fx
        y_e = (indices[..., 0] - y_offset) * z_e / fy
        xyz_img = np.stack([x_e, y_e, z_e], axis=-1)  # Shape: [H x W x 3]
        return xyz_img

    def work(self, color_np, sim_depth_np, syn_depth_np):
        os.environ["OPENCV_IO_ENABLE_OPENEXR"]="1"
        _output_depth = sim_depth_np.copy()

        if len(sim_depth_np.shape) == 3:
            sim_depth_np = sim_depth_np[:, :, 0]
        sim_depth_np = sim_depth_np[np.newaxis, ...]


        if len(_output_depth.shape) == 3:
            _output_depth = _output_depth[:, :, 0]
        _output_depth = _output_depth[np.newaxis, ...]          # (1, 360, 640)

        if len(syn_depth_np.shape) == 3:
            syn_depth_np = syn_depth_np[:, :, 0]
        syn_depth_np = syn_depth_np[np.newaxis, ...]


        # Apply image augmentations and convert to Tensor
        if augs_test:
            det_tf = augs_test.to_deterministic()
            det_tf_only_resize = augs_test.to_deterministic()

            sim_depth_np = sim_depth_np.transpose((1, 2, 0))  # To Shape: (H, W, 1)
            # transform to xyz_img
            img_h = sim_depth_np.shape[0]
            img_w = sim_depth_np.shape[1]
            
            sim_depth_np = det_tf_only_resize.augment_image(sim_depth_np, hooks=ia.HooksImages(activator=self._activator_masks))
            sim_depth_np = sim_depth_np.transpose((2, 0, 1))  # To Shape: (1, H, W)
            sim_depth_np[sim_depth_np <= 0] = 0.0
            sim_depth_np = sim_depth_np.squeeze(0)            # (H, W)

            fx = self.fx_real_input
            fy = self.fy_real_input
            cx = img_w * 0.5 - 0.5
            cy = img_h * 0.5 - 0.5
            
            camera_params = {
                'fx': fx,
                'fy': fy,
                'cx': cx,
                'cy': cy,
                'yres': img_h,
                'xres': img_w,
            }

            # get image scale, (x_s, y_s)
            scale = (224 / img_w, 224 / img_h)
            camera_params['fx'] *= scale[0]
            camera_params['fy'] *= scale[1]
            # camera_params['cx'] *= scale[0]
            # camera_params['cy'] *= scale[1]
            camera_params['cx'] = 112 - 0.5
            camera_params['cy'] = 112 - 0.5
            camera_params['xres'] *= scale[0]
            camera_params['yres'] *= scale[1]

            _sim_xyz = self.compute_xyz(sim_depth_np, camera_params)            
            color_np = det_tf.augment_image(color_np)

            syn_depth_np = syn_depth_np.transpose((1, 2, 0))  # To Shape: (H, W, 1)
            syn_depth_np = det_tf_only_resize.augment_image(syn_depth_np, hooks=ia.HooksImages(activator=self._activator_masks))
            syn_depth_np = syn_depth_np.transpose((2, 0, 1))  # To Shape: (1, H, W)

            _output_depth = _output_depth.transpose((1, 2, 0))  # To Shape: (H, W, 1)
            _output_depth = det_tf_only_resize.augment_image(_output_depth, hooks=ia.HooksImages(activator=self._activator_masks))
            _output_depth = _output_depth.transpose((2, 0, 1))  # To Shape: (1, H, W)

        # Return Tensors
        _rgb_tensor = transforms.ToTensor()(color_np)
        _sim_xyz_tensor = transforms.ToTensor()(_sim_xyz)
        _sim_depth_tensor = transforms.ToTensor()(sim_depth_np)
        _syn_depth_tensor = torch.from_numpy(syn_depth_np)
        _output_depth_tensor = torch.from_numpy(_output_depth)

        _rgb_tensor = _rgb_tensor.unsqueeze(0)
        _sim_xyz_tensor = _sim_xyz_tensor.unsqueeze(0)
        _sim_depth_tensor = _sim_depth_tensor.unsqueeze(0)
        _syn_depth_tensor = _syn_depth_tensor.unsqueeze(0)
        _output_depth_tensor = _output_depth_tensor.unsqueeze(0)

        batch = {
            "rgb" : _rgb_tensor,
            "sim_depth" : _sim_depth_tensor,
            "output_depth" : _output_depth_tensor,
            "syn_depth" : _syn_depth_tensor,
            "sim_xyz" : _sim_xyz_tensor,
        }

        self.pose_fitting_result = []
        self.model.eval()
        sample_batched = self.transfer_to_device(batch)
        with torch.no_grad():
            output_sem_seg, output_coords = self.forward(sample_batched, mode='val')
        self.inference_iter_coord_metrics(self.transfer_to_cpu(batch), output_sem_seg.detach().cpu(), output_coords.detach().cpu(),mode='val')
        # self.inference_epoch_coord_metrics(mode='inference')
        return self.pose_fitting_result
        
    def inference_iter_coord_metrics(self,batch,output_sem_masks, output_coords,mode):
        #sim_ds = np.array(sim_ds*1000,dtype=int)
        output_ds = np.array(batch['output_depth'])
        syn_ds = np.array(batch['syn_depth'])
        #scale = np.array(batch['scale'])
        rgbs = np.array((batch['rgb']*255),dtype=int).transpose(0,2,3,1)
        syn_ds = syn_ds.squeeze(1)
        output_ds = output_ds.squeeze(1)
        #sim_xyzs = np.array(batch['sim_xyz']).transpose(0,2,3,1)

        output_sem_masks = F.softmax(output_sem_masks, dim=1)  # [1, 150, 512, 512]
        output_sem_masks = output_sem_masks.argmax(dim=1)  # [1, 512, 512]

        output_sem_masks = np.array(output_sem_masks)

        output_coords = np.array(output_coords)
        output_coords = output_coords.transpose(0,2,3,1)

        #intrinsics = np.array([[156.2085, 0, 111.825], [0, 156.2085, 62.825], [0, 0, 1]])
        intrinsics = np.zeros((3,3))
        if self.val_data_type =='real':
            img_h = 480 
            img_w = 640  
            # fx = 502.30
            # fy = 502.30
            fx = self.fx_real_input
            fy = self.fy_real_input
        else :
            img_h = 360
            img_w = 640  
            # fx = 502.30
            # fy = 502.30
            fx = self.fx_sim
            fy = self.fy_sim
        cx = img_w * 0.5 - 0.5
        cy = img_h * 0.5 - 0.5
        camera_params = {
            'fx': fx,
            'fy': fy,
            'cx': cx,
            'cy': cy,
            'yres': img_h,
            'xres': img_w,
        }
        # get image scale, (x_s, y_s)
        
        hw = (224 / img_w, 126 / img_h)
        camera_params['fx'] *= hw[0]
        camera_params['fy'] *= hw[1]
        camera_params['cx'] *= hw[0]
        camera_params['cy'] *= hw[1]
        camera_params['xres'] *= hw[0]
        camera_params['yres'] *= hw[1]
        intrinsics[0,0] = camera_params['fx']
        intrinsics[0,2] = camera_params['cx']
        intrinsics[1,1] = camera_params['fy']
        intrinsics[1,2] = camera_params['cy']
        intrinsics[2,2] = 1.0
        #print(camera_params)
        camera_params_pred = {
            'fx': fx,
            'fy': fy,
            'cx': cx,
            'cy': cy,
            'yres': img_h,
            'xres': img_w,
        }
        

        synset_names = ['other',  # 0
                    'bottle',  # 1
                    'bowl',  # 2
                    'camera',  # 3
                    'can',  # 4
                    'car',  # 5
                    'mug',  # 6
                    'aeroplane',  # 7
                    'BG',  # 8
                    ]
        
        
        
        for i in range(self.batch_size) :
            #resize_xyzs = cv2.resize(sim_xyzs[i], (224, 126), interpolation=cv2.INTER_NEAREST)
            #np.savetxt(save_path+'/{}_sim_xyzs_pts.txt'.format(i), resize_xyzs.reshape(224*126,3))
            resize_rgbs = cv2.resize(rgbs[i], (224, 126), interpolation=cv2.INTER_NEAREST)
            resize_syn_ds = cv2.resize(syn_ds[i], (224, 126), interpolation=cv2.INTER_NEAREST)
            #print(output_ds.shape)
            resize_output_ds = cv2.resize(output_ds[i], (224, 126), interpolation=cv2.INTER_NEAREST)
            resize_output_sem_masks = cv2.resize(output_sem_masks[i], (224, 126), interpolation=cv2.INTER_NEAREST)
            resize_output_coords = cv2.resize(output_coords[i], (224, 126), interpolation=cv2.INTER_NEAREST)

            pred_class_ids , pred_scores , pred_masks ,pred_coords ,\
                    pred_boxes = prepare_data_posefitting(resize_output_sem_masks,resize_output_coords)

            if len(pred_class_ids) == 0:
                continue
            result = {}

            result['pred_class_ids'] = pred_class_ids
            result['pred_bboxes'] = pred_boxes
            result['pred_RTs'] = None   
            result['pred_scores'] = pred_scores
            result['pred_RTs'], result['pred_scales'], error_message, elapses =  align(pred_class_ids, 
                                                                                        pred_masks, 
                                                                                        pred_coords, 
                                                                                        resize_output_ds, 
                                                                                        intrinsics, 
                                                                                        synset_names, 
                                                                                        if_norm=True)
            

            
            
            self.pose_fitting_result.append(result)
            

    
    def inference_epoch_coord_metrics(self,mode):
        synset_names = ['other',  # 0
                    'bottle',  # 1
                    'bowl',  # 2
                    'camera',  # 3
                    'can',  # 4
                    'car',  # 5
                    'mug',  # 6
                    'aeroplane',  # 7
                    #'BG',  # 8
                    ]
        result = {}
        # print(type(self.pose_fitting_result))
        # for i in range(0, len(self.pose_fitting_result)):
        #     result[i] = {}
        #     print(type(self.pose_fitting_result[i]))
        #     for j in self.pose_fitting_result[i]:
        #         result[i][j] = self.pose_fitting_result[i][j].tolist()
        #         print(type(result[i][j]))

        for i in self.pose_fitting_result[0]:
            result[i] = self.pose_fitting_result[0][i].tolist()

        with open("result.json", 'w', encoding='utf-8') as f:
            json.dump(result, f)
        # save_path =os.path.join(self.output_path ,'result.pkl') 
        # with open(save_path, 'wb') as f:
        #     cPickle.dump(self.pose_fitting_result, f)
        # print(save_path)
        # aps = compute_degree_cm_mAP(self.pose_fitting_result, synset_names, self.output_path ,
        #                                                         degree_thresholds = [5, 10, 15], 
        #                                                         shift_thresholds= [2,5, 10, 15],  
        #                                                         iou_3d_thresholds=np.linspace(0, 1, 101),
        #                                                         iou_pose_thres=0.1,
        #                                                         use_matches_for_pose=True)
        return
  

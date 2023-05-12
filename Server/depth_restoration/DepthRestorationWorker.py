import argparse
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
import imageio
from numpy.core.fromnumeric import put
from numpy.lib.twodim_base import mask_indices
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
# from torch.utils.tensorboard import SummaryWriter
# from torch.nn.modules.loss import CrossEntropyLoss
# from torch.utils.data import DataLoader
# from tqdm import tqdm
from torchvision import transforms
import cv2
import matplotlib.pyplot as plt
import time
import copy

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

class DepthRestorationWorker():
    def __init__(self, args, model, device_list, continue_ckpt_path):
        if continue_ckpt_path is not None:
            msg = model.load_state_dict(torch.load(continue_ckpt_path)['model_state_dict'])
            print("self trained swin unet", msg)
        
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        
        # realsense D415 
        self.fx_real_input = 918.295227050781           
        self.fy_real_input = 917.5439453125             
        self.fx_real_label = 918.295227050781 / 2.0
        self.fy_real_label = 917.5439453125 / 2.0

        if args.n_gpu > 1:
            self.model = nn.DataParallel(model, device_list)
        else:
            self.model = model
        
        # logging.basicConfig(filename=self.output_path + "/log.txt", level=logging.INFO,
        #                     format='[%(asctime)s.%(msecs)03d] %(message)s', datefmt='%H:%M:%S')
        # logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
        # logging.info(str(args))
        # self.writer = SummaryWriter(self.output_path + '/log')
    
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


    def transfer_to_device(self, sample_batched):
        for key in sample_batched:
            sample_batched[key] = sample_batched[key].to(self.device)
        return sample_batched

    def forward(self, sample_batched, mode):
        loss_weight_d = 1.0 
        loss_weight_sem_seg = 1.0
        loss_weight_coord = 3.0

        rgbs = sample_batched['rgb']
        sim_xyzs = sample_batched['sim_xyz']
        sim_ds = sample_batched['sim_depth']
        pred_ds, pred_ds_initial, confidence_sim_ds, confidence_initial = self.model(rgbs, sim_ds)    # [bs, 150, 512, 512], [bs, 150, 512, 512])
        return pred_ds, confidence_sim_ds, confidence_initial# , pred_sem_seg, pred_coords

    def _activator_masks(self, images, augmenter, parents, default):
        '''Used with imgaug to help only apply some augmentations to images and not labels
        Eg: Blur is applied to input only, not label. However, resize is applied to both.
        '''
        if input_only and augmenter.name in input_only:
            return False
        else:
            return default 

    def work(self, color_np, depth_np):
        # os.environ["OPENCV_IO_ENABLE_OPENEXR"]="1"
        # # Open rgb images
        # rgb_path = "D://Project/Universal/Graduation/projects/Server/img_color.png"
        # # rgb_path = "data_test/test2/00000/0000_color.png"
        # color_np = Image.open(rgb_path).convert('RGB')
        # color_np = np.array(color_np)

        # # Open simulated depth images
        # sim_depth_path = "D://Project/Universal/Graduation/projects/Server/img_depth.exr"
        # # sim_depth_path = "data_test/test2/00000/0000_simDepth.exr"
        # depth_np =  cv2.imread(sim_depth_path, cv2.IMREAD_ANYCOLOR | cv2.IMREAD_ANYDEPTH) 
        
        
        if len(depth_np.shape) == 3:
            depth_np = depth_np[:, :, 0]
        depth_np = depth_np[np.newaxis, ...]
        # Apply image augmentations and convert to Tensor
        if augs_test:
            det_tf = augs_test.to_deterministic()
            det_tf_only_resize = augs_test.to_deterministic()

            depth_np = depth_np.transpose((1, 2, 0))  # To Shape: (H, W, 1)
            # transform to xyz_img
            img_h = depth_np.shape[0]
            img_w = depth_np.shape[1]
            
            depth_np = det_tf_only_resize.augment_image(depth_np, hooks=ia.HooksImages(activator=self._activator_masks))
            depth_np = depth_np.transpose((2, 0, 1))  # To Shape: (1, H, W)
            depth_np[depth_np <= 0] = 0.0
            depth_np = depth_np.squeeze(0)            # (H, W)
          

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

            _sim_xyz = self.compute_xyz(depth_np, camera_params)

            color_np = det_tf.augment_image(color_np)
        
        # Return Tensors
        _rgb_tensor = transforms.ToTensor()(color_np)
        _sim_xyz_tensor = transforms.ToTensor()(_sim_xyz)
        _sim_depth_tensor = transforms.ToTensor()(depth_np)

        _rgb_tensor = _rgb_tensor.unsqueeze(0)
        _sim_xyz_tensor = _sim_xyz_tensor.unsqueeze(0)
        _sim_depth_tensor = _sim_depth_tensor.unsqueeze(0)

        # size1 = _rgb_tensor.size()
        # size2 = _sim_xyz_tensor.size()
        # size3 = _sim_depth_tensor.size()

        batch = {
            "rgb" : _rgb_tensor,
            "sim_depth" : _sim_depth_tensor,
            "sim_xyz" : _sim_xyz_tensor,
        }

        self.model.eval()
        sample_batched = self.transfer_to_device(batch)
        with torch.no_grad():
            outputs_depth, confidence_sim_ds, confidence_initial = self.forward(sample_batched, mode='val')
            # print("outputs_depth[0][0]", outputs_depth[0][0])
            # print("len(outputs_depth[0][0])", len(outputs_depth[0][0]))
            # print("len(outputs_depth[0][0][0])", len(outputs_depth[0][0][0]))
            result = cv2.resize(outputs_depth[0][0].cpu().numpy(), (224, 126))
            # imageio.imwrite('float_img.exr', cv2.resize(outputs_depth[0][0].cpu().numpy(), (224, 126)))
            return result



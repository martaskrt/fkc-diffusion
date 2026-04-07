import torch
import numpy as np
import pandas as pd
import time
import matplotlib.pyplot as plt

import json
from PIL import Image
from transformers import CLIPTextModel, CLIPTokenizer
import ImageReward as RM
import torchvision

from diffusers import AutoencoderKL, UNet2DConditionModel
from diffusers import EulerDiscreteScheduler
from torch.nn.attention import SDPBackend, sdpa_kernel
from transformers import CLIPProcessor, CLIPModel


import wandb
import argparse
import os, re
from tqdm import tqdm

PATH = "/projects/superdiff/saved_sd_results/"

dtype = torch.float32
device = torch.device("cuda")

sd_model="stabilityai/stable-diffusion-xl-base-1.0"

vae = AutoencoderKL.from_pretrained(sd_model, subfolder="vae", use_safetensors=True)
tokenizer = CLIPTokenizer.from_pretrained(sd_model, subfolder="tokenizer")
text_encoder = CLIPTextModel.from_pretrained(
    sd_model, subfolder="text_encoder", use_safetensors=True
)
unet = UNet2DConditionModel.from_pretrained(
    sd_model, subfolder="unet", use_safetensors=True
)

torch_device = torch.device('cuda')
vae.to(torch_device)
text_encoder.to(torch_device)
unet.to(torch_device)

scheduler = EulerDiscreteScheduler.from_pretrained(sd_model, subfolder="scheduler")
 
with open("imagenet_class_index.json") as f:
    class_idx = json.load(f)
IMAGENET_IDX2LABEL = [class_idx[str(k)][1] for k in range(len(class_idx))]

@torch.no_grad
def get_text_embedding(prompt):
    text_input = tokenizer(
        prompt,
        padding="max_length",
        max_length=tokenizer.model_max_length,
        truncation=True,
        return_tensors="pt",
    )
    return text_encoder(text_input.input_ids.to(torch_device))[0]


def compute_clip_score(clip_processor, clip, img, prompt):
    inputs = clip_processor(
        text=[prompt],
        images=img,
        return_tensors="pt",
        padding=True,
    )
    outputs = clip(**inputs)
    logits_per_image = (
        outputs.logits_per_image
    )  # this is the image-text similarity score
    return logits_per_image.cpu().item()

def compute_image_reward(image_reward, img, prompt):
    return image_reward.score(prompt, img)
    
def get_img_prompt(cls):
    prompt = IMAGENET_IDX2LABEL[cls]
    prompt = " ".join(prompt.split("_"))
    return prompt

def load_img(filepath):
    try:
        img = Image.open(filepath)
        # Convert the PIL Image to a NumPy array
        #img_array = np.array(img)
        return img
    except Exception as e:
        print(f"Error opening image: {e}")
        return None 

def get_cls(args, filename, cls_arr, fkc=False):
    idx = filename.replace(".png", "")
    idx = int(idx)
    if fkc:
        assert idx % args.batch_size == 0
        idx = idx // args.batch_size
    cls = cls_arr[idx]
    return cls

def get_labels(args, fkc=False):
    if fkc and args.batch_size == 32:
        labels = np.load("class_idx.npy")
    elif fkc and args.batch_size == 64:
        labels = np.load("fkc_classlabels_10000_bs64/class_idx.npy")
    elif fkc and args.batch_size == 16:
        labels = np.load("fkc_classlabels_10000_bs16/class_idx.npy")
    elif fkc and args.batch_size == 8:
        labels = np.load("fkc_classlabels_10000_bs8/class_idx.npy")
    elif fkc and args.batch_size == 4:
        labels = np.load("fkc_classlabels_10000_bs4/class_idx.npy")
    elif fkc and args.batch_size == 2:
        labels = np.load("fkc_classlabels_10000_bs2/class_idx.npy")
    elif fkc and args.batch_size == 1:
        labels = np.load("fkc_classlabels_10000_bs1/class_idx.npy")
    else:
        labels = np.load("cfg_classlabels_10000_bs1/class_idx.npy")
    return labels

def run(args):
    ## compute CLIP score
    print("Computing CLIP score...")
    clip = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
    clip_processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")

    image_reward = RM.load("ImageReward-v1.0")

    scores = []
    labels_arr = get_labels(args, args.fkc)
    print("labels_arr", labels_arr)
    counter = 0
    for rootdir, subdirs, files in sorted(os.walk(args.img_dir)):
        for i, f in tqdm(enumerate(sorted(files)), colour="YELLOW"):
            if ".png" not in f: continue
            counter += 1
            if counter < args.start: continue
            if counter >= args.end: continue
            #if counter == 1000:  break
            path_ = os.path.join(rootdir, f)
            print("counter", counter, "path_", path_)
            img = load_img(path_)
            
            cls = get_cls(args, f, labels_arr, fkc=args.fkc)
            prompt = get_img_prompt(cls)

            clip_score = compute_clip_score(clip_processor, clip, img, prompt)  

            image_reward_score = compute_image_reward(
                image_reward, img, prompt
            )
            scores.append((cls, prompt, clip_score,  image_reward_score, path_))
            
    df = pd.DataFrame(scores, columns=['class',"prompt", 'clip', "ir", 'path'])
    df.to_csv(args.save_path)

    print(" ======== CLIP ======= ")
    print(f"{df['clip'].mean():.4f} ± {df['clip'].std():.4f}")
    print()
    print(" ======== IMAGE REWARD ======= ")
    print(f"{df['ir'].mean():.4f} ± {df['ir'].std():.4f}")
       
def main():
    # arguments
    parser = argparse.ArgumentParser(description="Your script description here")
    parser.add_argument("--img_dir", type=str)
    parser.add_argument("--start", type=int)
    parser.add_argument("--end", type=int)
    parser.add_argument("--save_path", type=str)
    parser.add_argument("--batch_size", type=int, default=32)
    parser.add_argument("--fkc", action="store_true")
    args = parser.parse_args()

    if "fkc_" in args.img_dir:
        args.fkc = True
    else:
        args.fkc = False

    m = re.search(r"_bs(\d+)", args.img_dir)
    if m:
        args.batch_size = int(m.group(1))
    
    # run script
    print("Script is running with the provided arguments.\n")
    print(args)
    run(args)
    

if __name__ == "__main__":
    main()

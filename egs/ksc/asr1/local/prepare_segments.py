#!/usr/bin/env python

import sys, argparse, re, os, random, glob, pdb
import pandas as pd
from pathlib import Path
import wave
import contextlib

def get_args():
    parser = argparse.ArgumentParser(description="", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--dataset_dir", help="Input data directory", required=True)
    print(' '.join(sys.argv))
    args = parser.parse_args()
    return args


def get_duration(file_path):
    duration = None
    if os.path.exists(file_path) and Path(file_path).stat().st_size > 0:
        with contextlib.closing(wave.open(file_path,'r')) as f:
            frames = f.getnframes()
            if frames>0:
                rate = f.getframerate()
                duration = frames / float(rate)
    return duration if duration else 0
            
def prepare_data(dataset_dir, path_root):
    total_duration = 0
    wav_format = '-r 16000 -c 1 -b 16 -t wav - downsample |'
    
    files = [] ## depending on how you store your segments prepare function that returns a list of paths of all audio segments ##
    files.sort()
    with open(path_root + '/text', 'w', encoding="utf-8") as f1, \
    open(path_root + '/utt2spk', 'w', encoding="utf-8") as f2, \
    open(path_root + '/wav.scp', 'w', encoding="utf-8") as f3:
        for file_path in files:
            total_duration += get_duration(file_path) 
           
            f1.write(file_path + ' ' + 'X' + '\n')
            f2.write(file_path + ' ' + file_path + '\n')
            f3.write(file_path + ' sox ' + file_path  + ' ' + wav_format +  '\n') 
            
    return total_duration / 3600

def main():
    args = get_args()
    
    dataset_dir = args.dataset_dir
    test = []
    test_dir_name = 'test'
    
    save_data_root = 'data/'
    test_root = save_data_root + test_dir_name
    
    print('total duration:', prepare_data(dataset_dir, test_root))

if __name__ == "__main__":
    main()

#!/bin/bash

# Copyright 2019 Nagoya University (Takenori Yoshimura)
#           2019 RevComm Inc. (Takekatsu Hiramura)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

if [ ! -f path.sh ] || [ ! -f cmd.sh ]; then
    echo "Please change current directory to recipe directory e.g., egs/ksc/asr1"
    exit 1
fi

. ./path.sh

# general configuration
backend=pytorch
stage=0       # start from 0 if you need to start from data preparation
stop_stage=100
ngpu=0         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
verbose=1      # verbose option
dumpdir=dump
# feature configuration
do_delta=false

# rnnlm related
use_lang_model=true
lang_model=pretrained_320h_sp/rnnlm_internal/rnnlm.model.best

# decoding parameter
cmvn=pretrained_320h_sp/cmvn.ark 
recog_model=pretrained_320h_sp/model/model.last10.avg.best  
decode_config=conf/decode_transformer.yaml
decode_dir=decode

api=v2

# download related


. utils/parse_options.sh || exit 1;

# make shellcheck happy
train_cmd=
decode_cmd=
test_set=test
. ./cmd.sh

wav=$1

set -e
set -u
set -o pipefail


# Check file existence
if [ ! -f "${cmvn}" ]; then
    echo "No such CMVN file: ${cmvn}"
    exit 1
fi
if [ ! -f "${lang_model}" ] && ${use_lang_model}; then
    echo "No such language model: ${lang_model}"
    exit 1
fi
if [ ! -f "${recog_model}" ]; then
    echo "No such E2E model: ${recog_model}"
    exit 1
fi
if [ ! -f "${decode_config}" ]; then
    echo "No such config file: ${decode_config}"
    exit 1
fi


decode_dir=decode
arg_opts='path_to_segmented_audios' 

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then

    mkdir -p data
    mkdir -p data/test
    echo "stage 0: Data preparation"
    
    local/prepare_segments.py --dataset_dir $arg_opts

  for x in ${test_set}; do
    utils/utt2spk_to_spk2utt.pl data/${x}/utt2spk > data/${x}/spk2utt
    sed -i.bak -e "s/$/ sox -R -t wav - -t wav - rate 16000 dither | /" data/${x}/wav.scp
  done
fi

feat_recog_dir=${dumpdir}/${test_set}/delta${do_delta}; mkdir -p ${feat_recog_dir}

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo "stage 1: Feature Generation"
        
    fbankdir=fbank    
    steps/make_fbank_pitch.sh --cmd "$train_cmd" --nj 3 --write_utt2num_frames true \
          data/${test_set} exp/make_fbank/${test_set} ${fbankdir}

    dump.sh --cmd "$train_cmd" --nj 3 --do_delta ${do_delta} data/${test_set}/feats.scp ${cmvn} exp/dump_feats/test ${feat_recog_dir}    
    
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "stage 2: Json Data Preparation"

    dict=data/dict
    echo "<unk> 1" > ${dict}
    data2json.sh --feat ${feat_recog_dir}/feats.scp \
        data/${test_set} ${dict} > ${feat_recog_dir}/data.json
    rm -f ${dict}
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 3: Decoding"
    if ${use_lang_model}; then
        recog_opts="--rnnlm ${lang_model}"
    else
        recog_opts=""
    fi

    ${decode_cmd} ${decode_dir}/log/decode.log \
        asr_recog.py \
        --config ${decode_config} \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --debugmode ${debugmode} \
        --verbose ${verbose} \
        --recog-json ${feat_recog_dir}/data.json \
        --result-label ${decode_dir}/result.json \
        --model ${recog_model} \
        --api ${api} \
        ${recog_opts}


fi
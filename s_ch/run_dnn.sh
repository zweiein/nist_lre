#!/bin/bash

# Copyright 2012-2014  Brno University of Technology (Author: Karel Vesely)
# Apache 2.0


. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

. ./path.sh ## Source the tools/utils (import the queue.pl)

# Config:
gmmdir=exp/tri3
data_fmllr=data_fmllr
stage=2 # resume training with --stage=N
# End of config.
. utils/parse_options.sh || exit 1;
#

if [ $stage -le 0 ]; then
  # train
  dir=$data_fmllr/full
  steps/nnet/make_fmllr_feats.sh --nj 4 --cmd "$train_cmd" \
     --transform-dir ${gmmdir}_ali \
     $dir data/full $gmmdir $dir/log $dir/data || exit 1
     
  # split the data : 90% train 10% cross-validation (held-out)
  utils/subset_data_dir_tr_cv.sh $dir ${dir}_tr90 ${dir}_cv10 || exit 1
fi

if [ $stage -le 1 ]; then
  # Pre-train DBN, i.e. a stack of RBMs (small database, smaller DNN)
  dir=exp/dnn4_pretrain-dbn
  (tail --pid=$$ -F $dir/log/pretrain_dbn.log 2>/dev/null)& # forward log
  
  $cuda_cmd $dir/log/pretrain_dbn.log \
    steps/nnet/pretrain_dbn.sh --hid-dim 1024 --rbm-iter 20 $data_fmllr/full $dir || exit 1;
fi

if [ $stage -le 2 ]; then
  # Train the DNN optimizing per-frame cross-entropy.
  dir=exp/dnn4_pretrain-dbn_dnn
  ali=${gmmdir}_ali
  feature_transform=exp/dnn4_pretrain-dbn/final.feature_transform
  dbn=exp/dnn4_pretrain-dbn/6.dbn
  (tail --pid=$$ -F $dir/log/train_nnet.log 2>/dev/null)& # forward log
  
  # Train
  $cuda_cmd $dir/log/train_nnet.log \
    steps/nnet/train.sh --feature-transform $feature_transform --dbn $dbn --hid-layers 0 --learn-rate 0.008 \
    $data_fmllr/full $data_fmllr/full data/lang $ali $ali $dir || exit 1;
    
  # Decode (reuse HCLG graph)
  steps/nnet/decode.sh --nj 4 --cmd "$decode_cmd" --acwt 0.2 \
    $gmmdir/graph $data_fmllr/full $dir/decode_full || exit 1;
fi


if [ $stage -le 5 ]; then
    bash RESULTS
fi

echo Success
exit 0

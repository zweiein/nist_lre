#!/bin/bash

##  Copyright(C) 2016 Ming-Han Yang
##
##  mhyang [at] iis [dot] sinica [dot] edu [dot] tw
##
##  This program is free software: you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with this program.  If not, see <http://www.gnu.org/licenses/>.


. ./cmd.sh 
[ -f path.sh ] && . ./path.sh

set -e

train_cmd="run.pl --mem 1G"
decode_cmd="run.pl --mem 2G"

# Acoustic model parameters
numLeavesTri1=2500
numGaussTri1=15000
numLeavesMLLT=2500
numGaussMLLT=15000
numLeavesSAT=2500
numGaussSAT=15000
numGaussUBM=400
numLeavesSGMM=7000
numGaussSGMM=9000

feats_nj=2
train_nj=4
decode_nj=4

stage=0


if [ $stage -le 0 ]; then
    echo ============================================================================
    echo "                Data & Lexicon & Language Preparation  (Python3)            "
    echo ============================================================================

    nistlre=/mnt/md1/user_XXX/your_dir
    local/nistlre_data_prep.sh $nistlre

    # generate feats.scp for data/full
    featdir=mfcc
    mkdir -p $featdir
    for x in full ; do
        steps/make_mfcc.sh --nj $feats_nj --mfcc-config conf/mfcc.conf --cmd "run.pl" data/$x exp/make_mfcc  $featdir/$x
        steps/compute_cmvn_stats.sh data/$x exp/make_mfcc  $featdir/$x
    done

    local/nistlre_prepare_dict.sh

    ## Caution below: we remove optional silence by setting "--sil-prob 0.0",
    ## in nistlre the silence appears also as a word in the dictionary and is scored.
    utils/prepare_lang.sh --sil-prob 0.0 --position-dependent-phones false --num-sil-states 3 \
     data/local/dict "sil" data/local/lang_tmp data/lang

    local/nistlre_format_data.sh

fi


if [ $stage -le 2 ]; then
    echo ============================================================================
    echo "                     MonoPhone Training & Decoding  (Python2.7 below)              "
    echo ============================================================================

    steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" data/full data/lang exp/mono

    utils/mkgraph.sh --mono data/lang_test_bg exp/mono exp/mono/graph

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" exp/mono/graph data/full exp/mono/decode_full
fi

if [ $stage -le 4 ]; then
    echo ============================================================================
    echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
    echo ============================================================================

    steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" \
     data/full data/lang exp/mono exp/mono_ali

    # Train tri1, which is deltas + delta-deltas, on train data.
    steps/train_deltas.sh --cmd "$train_cmd" \
     $numLeavesTri1 $numGaussTri1 data/full data/lang exp/mono_ali exp/tri1

    utils/mkgraph.sh data/lang_test_bg exp/tri1 exp/tri1/graph

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
     exp/tri1/graph data/full exp/tri1/decode_full
fi

if [ $stage -le 6 ]; then
    echo ============================================================================
    echo "                 tri2 : LDA + MLLT Training & Decoding                    "
    echo ============================================================================

    steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
      data/full data/lang exp/tri1 exp/tri1_ali

    steps/train_lda_mllt.sh --cmd "$train_cmd" \
     --splice-opts "--left-context=3 --right-context=3" \
     $numLeavesMLLT $numGaussMLLT data/full data/lang exp/tri1_ali exp/tri2

    utils/mkgraph.sh data/lang_test_bg exp/tri2 exp/tri2/graph

    steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
     exp/tri2/graph data/full exp/tri2/decode_full
fi

if [ $stage -le 8 ]; then
    echo ============================================================================
    echo "              tri3 : LDA + MLLT + SAT Training & Decoding                 "
    echo ============================================================================

    # Align tri2 system with train data.
    steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
     --use-graphs true data/full data/lang exp/tri2 exp/tri2_ali

    # From tri2 system, train tri3 which is LDA + MLLT + SAT.
    steps/train_sat.sh --cmd "$train_cmd" \
     $numLeavesSAT $numGaussSAT data/full data/lang exp/tri2_ali exp/tri3

    utils/mkgraph.sh data/lang_test_bg exp/tri3 exp/tri3/graph

    steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
     exp/tri3/graph data/full exp/tri3/decode_full
fi

if [ $stage -le 10 ]; then
    echo ============================================================================
    echo "                        SGMM2 Training & Decoding                         "
    echo ============================================================================

    steps/align_fmllr.sh --nj "$train_nj" --cmd "$train_cmd" \
    data/full data/lang exp/tri3 exp/tri3_ali

    steps/train_ubm.sh --cmd "$train_cmd" \
    $numGaussUBM data/full data/lang exp/tri3_ali exp/ubm4

    steps/train_sgmm2.sh --cmd "$train_cmd" $numLeavesSGMM $numGaussSGMM \
    data/full data/lang exp/tri3_ali exp/ubm4/final.ubm exp/sgmm2_4

    utils/mkgraph.sh data/lang_test_bg exp/sgmm2_4 exp/sgmm2_4/graph

    steps/decode_sgmm2.sh --nj "$decode_nj" --cmd "$decode_cmd" \
     --transform-dir exp/tri3/decode_full  exp/sgmm2_4/graph data/full \
     exp/sgmm2_4/decode_full
fi

if [ $stage -le 12 ]; then
    echo ============================================================================
    echo "                    MMI + SGMM2 Training & Decoding                       "
    echo ============================================================================

    steps/align_sgmm2.sh --nj "$train_nj" --cmd "$train_cmd" \
     --transform-dir exp/tri3_ali --use-graphs true --use-gselect true \
     data/full data/lang exp/sgmm2_4 exp/sgmm2_4_ali

    steps/make_denlats_sgmm2.sh --nj "$train_nj" --sub-split "$train_nj" \
     --acwt 0.2 --lattice-beam 10.0 --beam 18.0 \
     --cmd "$decode_cmd" --transform-dir exp/tri3_ali \
     data/full data/lang exp/sgmm2_4_ali exp/sgmm2_4_denlats

    steps/train_mmi_sgmm2.sh --acwt 0.2 --cmd "$decode_cmd" \
     --transform-dir exp/tri3_ali --boost 0.1 --drop-frames true \
     data/full data/lang exp/sgmm2_4_ali exp/sgmm2_4_denlats exp/sgmm2_4_mmi_b0.1

    for iter in 1 2 3 4; do
       steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
       --transform-dir exp/tri3/decode_full data/lang_test_bg data/full \
       exp/sgmm2_4/decode_full exp/sgmm2_4_mmi_b0.1/decode_full_it$iter
    done
fi

echo ============================================================================
echo "                    Getting Results [see RESULTS file]                    "
echo ============================================================================

bash RESULTS

echo ============================================================================
echo "Finished successfully on" `date`
echo ============================================================================

exit 0

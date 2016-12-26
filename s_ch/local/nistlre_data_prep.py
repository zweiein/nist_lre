#!/usr/bin/python3
# -*- coding: utf-8 -*-

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

from __future__ import print_function
import sys
import os
from subprocess import Popen, PIPE, DEVNULL
from utils.utils import parse_arguments
import pandas as pd
import copy


if __name__ != '__main__':
    raise ImportError("This script can only be run, and can\'t be imported")

else:   
    # check the arguments
    arg_elements = [sys.argv[i] for i in range(1, len(sys.argv))]
    arguments = parse_arguments(arg_elements)
    required_arguments = ['corpus_stuff_dir', 'df_pkl_dir', 'label_dir', 'output_dir']

    for essential_arg in required_arguments:
        if essential_arg in arguments == False :
            print("Error: the argument {0} has to be specified".format(arg))
            exit(1)
    #// for args

    corpus_stuff_dir = arguments['corpus_stuff_dir']
    df_pkl_dir = arguments['df_pkl_dir']
    label_dir = arguments['label_dir']
    output_dir = arguments['output_dir']


    df = pd.read_pickle(df_pkl_dir)
    df_ch = df[df.corpus == "ogi06"][df.language == "Chinese"]

    wav_list = df_ch.audio.tolist()
    wav_uttid_list = df_ch.session.tolist()

    wav_uttid_list
    print("(LOG) Get {0} utterances!".format(len(wav_uttid_list)))
    # ============================================================================
    #                                 Prepare wav.scp
    # ============================================================================

    wav_tuple_list = zip(wav_uttid_list, wav_list) # 把utt_id和wav路徑合併成tiple

    fp_wav_scp = open(output_dir + "/wav.scp", "w")

    for every_wav_pair in wav_tuple_list :
        ## utt_id使用"ogi06_macall-27-g.story-bt"太長了, 改成"ogi06_macall_27"; 用utt_id[:-11]就好
        key2list = every_wav_pair[0][:-11].split('-')
        new_key = key2list[0] + "-" + key2list[1].zfill(3)

        fp_wav_scp.write("{0} {1}\n".format(new_key, every_wav_pair[1]))
    #// end for()

    print("(LOG)wav.scp preparation succeeded! {0} utterances".format(len(wav_list)))
    fp_wav_scp.close()


    # ============================================================================
    #                                 Prepare text
    # ============================================================================
    # key存在wav_uttid_list裡面, 只要檔名加上.lab就可以找到對應的label

    label_list = [s + ".lab" for s in wav_uttid_list]
    fp_text = open(output_dir + "/text", 'w')

    for every_label_file in label_list:
        full_path = label_dir + "/" + every_label_file
        this_utt_phone_list = []

        # 使用awk抓phone label(第三個column)
        p1 = Popen(["awk", "{print $3}", full_path], stdout=PIPE)
        this_file_phone_seq_list = p1.stdout.read().split()

        # 每個str轉成utf-8格式, 不然印出的時候前面會多一個b; ex: 'sil' --> b'sil'
        tmp = [s.decode('UTF-8') for s in this_file_phone_seq_list]

        # 把@符號換成底線 (不然後面的prepare lang的perl程式會出錯 = =)
        #tmp_replaced = [s.replace("@", "_") for s in tmp]

        # 接著把key跟phone sequence存到text裡面!!!
        key2list = every_label_file[:-15].split('-')
        new_key = key2list[0] + "-" + key2list[1].zfill(3)
        fp_text.write("{0} {1}\n".format(new_key, " ".join(map(str, tmp))))

        #print("(LOG) Get {0} Phones in {1}".format(len(this_file_phone_seq_list), every_label_file))
    #// end for (READ phone labels from every label file)

    print("(LOG)text preparation succeeded! {0} utterances".format(len(label_list)))
    fp_text.close()

    # ============================================================================
    #                                 Prepare utt2spk
    # ============================================================================
    # 暫時先把所有的utterance當成不同speaker
    # 格式: utt_id  spk

    fp_utt2spk = open(output_dir + "/utt2spk", 'w')

    for utt in wav_uttid_list:
        key2list = utt[:-11].split('-')
        new_key = key2list[0] + "-" + key2list[1].zfill(3)
        fp_utt2spk.write("{0} {1}\n".format(new_key, new_key))
    #// end for ()

    print("(LOG)utt2spk preparation succeeded!\n {0} utterances".format(len(wav_uttid_list)))
    fp_utt2spk.close()



#if __name__ == '__main__':
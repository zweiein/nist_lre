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


## This program is used to calculate the frequency of each phone occurranced in data/full/text.
## In order to avoid the error message below when constructing decision tree.
## ** The warnings above about 'no stats' generally mean you have phones **
## ** (or groups of phones) in your phone set that had no corresponding data. **
## ** You should probably figure out whether something went wrong, **
## ** or whether your data just doesn't happen to have examples of those **
## ** phones. **

from __future__ import print_function
import sys
import os
from subprocess import Popen, PIPE, DEVNULL
from utils.utils import parse_arguments
import pickle


if __name__ != '__main__':
    raise ImportError("This script can only be run, and can\'t be imported")

else:   
    # check the arguments
    arg_elements = [sys.argv[i] for i in range(1, len(sys.argv))]
    arguments = parse_arguments(arg_elements)
    required_arguments = ['text_path', 'phonestxt_path', 'output_dir']

    for essential_arg in required_arguments:
        if essential_arg in arguments == False :
            print("Error: the argument {0} has to be specified".format(arg))
            exit(1)
    #// for args

    text_path = arguments['text_path']
    phonetxt_path = arguments['phonestxt_path']
    output_dir = arguments['output_dir']

    fp_phonetxt = open(phonetxt_path, "r")

    phone_list = fp_phonetxt.read().split()
    phone_list = list(filter(lambda s: len(s) > 0, phone_list))

    # 以phonestxt當做基底來建立dict的雛形, 格式:
    # key=phone, value=出現次數
    phone_dict = {}
    for phone in phone_list:
        phone_dict[phone] = 0
    #// end for initialize phone dict

    # 接著用awk讀取text, 並且計算
    p1 = Popen(["awk", "{for (i=2; i<=NF; i++) print $i}", text_path], stdout=PIPE)
    text_phone_list = p1.stdout.read().split()
    tmp = [s.decode('UTF-8') for s in text_phone_list]
    text_phone_list = list(filter(lambda s: len(s) > 0, tmp))

    for phone in text_phone_list :

        if phone in phone_dict:
            phone_dict[phone] += 1
        else:
            print("Unexpected phone: {0}".format(phone))
    #// end for()

    # 產生log檔, 與輸出dict
    pickle.dump(phone_dict, open(output_dir + "/phone_occs.pkl", "wb"))

    fp_log = open(output_dir + "/phone_occs.log", "w")
    fp_log.write("phones\t\tfreq\n")
    for key, value in phone_dict.items():
        fp_log.write("{0}\t\t{1}\n".format(key, value))
    #// end for

    fp_log.close()
    fp_phonetxt.close()

    print("(LOG) succeeded! log file is in {0}".format(output_dir + "/phone_occs.log"))
#if __name__ == '__main__':
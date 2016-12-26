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
from utils.utils import parse_arguments


if __name__ != '__main__':
    raise ImportError("This script can only be run, and can\'t be imported")

else:   
    # check the arguments
    arg_elements = [sys.argv[i] for i in range(1, len(sys.argv))]
    arguments = parse_arguments(arg_elements)
    required_arguments = ['phones_txt', 'sil_phones_txt']

    for essential_arg in required_arguments:
        if essential_arg in arguments == False :
            print("Error: the argument {0} has to be specified".format(arg))
            exit(1)
    #// for args

    phonestxt_path = arguments['phones_txt']
    sil_phonestxt_path = arguments['sil_phones_txt']


    phone_list = open(phonestxt_path, "r").read().split()
    phone_list = list(filter(lambda s: len(s) > 0, phone_list))

    sil_phone_list = open(sil_phonestxt_path, "r").read().split()
    sil_phone_list = list(filter(lambda s: len(s) > 0, sil_phone_list))

    for phone in phone_list:
        if phone not in sil_phone_list:
            print(phone, end=" ")
    #// end for ()
    print("\n", end="")


#if __name__ == '__main__':
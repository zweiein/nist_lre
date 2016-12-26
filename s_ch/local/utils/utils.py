#!/usr/bin/python3

##  Copyright (C) 2016 Ming-Han Yang
##
##  mhyang [at] iis [dot] sinica [dot] edu [dot] tw
##
##  This program is free software: you can redistribute it and/or modify it under the 
##  terms of the GNU General Public License as published by the Free Software 
##  Foundation, either version 3 of the License, or (at your option) any later 
##  version.
##
##  This program is distributed in the hope that it will be useful, but WITHOUT ANY 
##  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
##  PARTICULAR PURPOSE.  See the GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with this program.  If not, see <http://www.gnu.org/licenses/>.

def parse_arguments(arg_elements):
    args = {}
    arg_num = int(len(arg_elements) / 2)

    for i in range(arg_num):
        key = arg_elements[2*i].replace("--","").replace("-", "_");
        args[key] = arg_elements[2*i+1]
    #// for()
    return args


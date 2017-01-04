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


if [ $# -ne 1 ]; then
   echo "Argument should be the Nistlre directory, see ../run.sh for example."
   exit 1;
fi

dir=data/full
mkdir -p $dir
label_dir=$*/labels


python3  local/nistlre_data_prep.py  --corpus-stuff-dir $*  --df-pkl-dir $*/df.pkl  \
  --label-dir $label_dir --output-dir $dir

# Sort all of the files under data/full

cat $dir/utt2spk |  sort -u > $dir/tmp_utt2spk
cp  $dir/tmp_utt2spk  $dir/utt2spk

utils/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/tmp_spk2utt
cat $dir/tmp_spk2utt |  sort -u > $dir/spk2utt

cat $dir/text |  sort -u > $dir/tmp_text
cp  $dir/tmp_text  $dir/text

cat $dir/wav.scp |  sort -u > $dir/tmp_wav.scp
cp  $dir/tmp_wav.scp  $dir/wav.scp


rm $dir/tmp_*


############ Uncomment by yourself, if you need train, dev and test set" ############ 
# split to train, dev and test set
#                 10%     10%
# utils/subset_data_dir_tr_cv.sh $dir data/tmp data/test
# utils/subset_data_dir_tr_cv.sh data/tmp data/train data/dev
# rm -rf data/tmp

## Prepare STM file for sclite:
for x in full; do
  wav-to-duration scp:data/${x}/wav.scp ark,t:data/${x}/dur.ark || exit 1
  awk -v dur=data/${x}/dur.ark \
  'BEGIN{
     while(getline < dur) { durH[$1]=$2; }
     print ";; LABEL \"O\" \"Overall\" \"Overall\"";
     print ";; LABEL \"F\" \"Female\" \"Female speakers\"";
     print ";; LABEL \"M\" \"Male\" \"Male speakers\"";
   }
   { wav=$1; spk=gensub(/_.*/,"",1,wav); $1=""; ref=$0;
     gender=(substr(spk,0,1) == "f" ? "F" : "M");
     printf("%s 1 %s 0.0 %f <O,%s> %s\n", wav, spk, durH[wav], gender, ref);
  }
  ' data/${x}/text >data/${x}/stm || exit 1
  ##Create dummy GLM file for sclite:
  echo ';; empty.glm
  [FAKE]     =>  %HESITATION     / [ ] __ [ ] ;; hesitation token
  ' > data/${x}/glm
done


echo "Data preparation succeeded"
exit 0;

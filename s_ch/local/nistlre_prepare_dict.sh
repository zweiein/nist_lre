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

# Call this script from one level above, e.g. from the s3/ directory.  It puts
# its output in data/local/.


# The parts of the output of this that will be needed are
# [in data/local/dict/ ]
# lexicon.txt
# extra_questions.txt
# nonsilence_phones.txt
# optional_silence.txt
# silence_phones.txt


# run this from ../
srcdir=data/local/data
dir=data/local/dict
lmdir=data/local/nist_lm
tmpdir=data/local/lm_tmp

mkdir -p $dir $lmdir $tmpdir

[ -f path.sh ] && . ./path.sh

## 產生 train.text, train_wav.scp, utt2spk, spk2utt 給之後的prepare dic 使用

mkdir -p $srcdir
for x in train  dev  test ; do
   cp  data/$x/text  $srcdir/${x}.text
   cp  data/$x/wav.scp  $srcdir/${x}_wav.scp
   cp  data/$x/utt2spk  $srcdir/${x}.utt2spk
   cp  data/$x/spk2utt  $srcdir/${x}.spk2utt
   cat data/$x/wav.scp | awk '{ print $1 }' > $srcdir/${x}.uttids
done


#(1) Dictionary preparation:

# Make phones symbol-table (adding in silence and verbal and non-verbal noises at this point).
# We are adding suffixes _B, _E, _S for beginning, ending, and singleton phones.

# silence phones, one per line.
echo sil > $dir/silence_phones.txt
echo sil > $dir/optional_silence.txt

# nonsilence phones; on each line is a list of phones that correspond
# really to the same base phone.

ignore_phone_r="no"
cut -d' ' -f2- $srcdir/train.text | tr ' ' '\n' | sort -u > $dir/phones.txt
## Create the lexicon, which is just an identity mapping
#if [ "$ignore_phone_r" == "yes" ]; then
#    donothing=1
#else
#    cut -d' ' -f2- $srcdir/train.text | tr ' ' '\n' | sort -u > $dir/phones.txt
#fi

paste $dir/phones.txt $dir/phones.txt > $dir/lexicon.txt || exit 1;
grep -v -F -f $dir/silence_phones.txt $dir/phones.txt > $dir/nonsilence_phones.txt 

# A few extra questions that will be added to those obtained by automatically clustering
# the "real" phones.  These ask about stress; there's also one for silence.
cat $dir/silence_phones.txt| awk '{printf("%s ", $1);} END{printf "\n";}' > $dir/extra_questions.txt || exit 1;
python3 local/prep_nonsilence_phones.py --phones-txt $dir/phones.txt  --sil-phones-txt $dir/silence_phones.txt >> $dir/extra_questions.txt || exit 1;

#cat $dir/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {
#  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' \
# >> $dir/extra_questions.txt || exit 1;   #***#

# (2) Create the phone bigram LM
if [ -z $IRSTLM ] ; then
  export IRSTLM=$KALDI_ROOT/tools/irstlm/
fi

export PATH=${PATH}:$IRSTLM/bin
if ! command -v prune-lm >/dev/null 2>&1 ; then
  echo "$0: Error: the IRSTLM is not available or compiled" >&2
  echo "$0: Error: We used to install it by default, but." >&2
  echo "$0: Error: this is no longer the case." >&2
  echo "$0: Error: To install it, go to $KALDI_ROOT/tools" >&2
  echo "$0: Error: and run extras/install_irstlm.sh" >&2
  exit 1
fi

cut -d' ' -f2- $srcdir/train.text | sed -e 's:^:<s> :' -e 's:$: </s>:' \
    > $srcdir/lm_train.text

#if [ "$ignore_phone_r" == "yes" ]; then
#    donothing=1
#else
#    cut -d' ' -f2- $srcdir/train.text | sed -e 's:^:<s> :' -e 's:$: </s>:' \
#    > $srcdir/lm_train.text
#fi

build-lm.sh -i $srcdir/lm_train.text -n 2 \
  -o $tmpdir/lm_phone_bg.ilm.gz

compile-lm $tmpdir/lm_phone_bg.ilm.gz -t=yes /dev/stdout | \
grep -v unk | gzip -c > $lmdir/lm_phone_bg.arpa.gz 

echo "Dictionary & language model preparation succeeded"

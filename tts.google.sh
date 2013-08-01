#!/bin/bash

#for the Raspberry Pi, we need to insert some sort of FILLER here since it cuts off the first bit of audio
time1=$(date +%s%N | cut -b1-13)
string=$@
lang="en"
if [ "$1" == "-l" ] ; then
    lang="$2"
    string=`echo "$string" | sed -r 's/^.{6}//'`
fi

md5str=`echo -n $string | md5sum | awk '{ print $1 }'`

if [ -e /dev/shm/$md5str.mp3 ] ; then
	#cat "/dev/shm/$md5str.mp3" | mpg123 - 1>>/dev/shm/voice.log 2>>/dev/shm/voice.log
	play /dev/shm/$md5str.mp3 speed 1.00 pitch 0
	time2=$(date +%s%N | cut -b1-13)
	echo $(($time2-$time1))
	exit 0
fi

#empty the original file
echo "" > "/dev/shm/speak.mp3"

len=${#string}
while [ $len -ge 100 ] ;
do
    #lets split this up so that its a maximum of 99 characters
    tmp=${string:0:100}
    string=${string:100}
    
    #now we need to make sure there aren't split words, let's find the last space and the string after it
    lastspace=${tmp##* }
    tmplen=${#lastspace}

    #here we are shortening the tmp string
    tmplen=`expr 100 - $tmplen` 
    tmp=${tmp:0:tmplen}
    
    #now we concatenate and the string is reconstructed
    string="$lastspace$string"
    len=${#string}
    
    #get the first 100 characters
    wget -q -U Mozilla -O "/dev/shm/tmp.mp3" "http://translate.google.com/translate_tts?tl=${lang}&q=$tmp"
    cat "/dev/shm/tmp.mp3" >> "/dev/shm/$md5str.mp3"
done
#this will get the last remnants
wget -q -U Mozilla -O "/dev/shm/tmp.mp3" "http://translate.google.com/translate_tts?tl=${lang}&q=$string"
cat "/dev/shm/tmp.mp3" >> "/dev/shm/$md5str.mp3"
#now we finally say the whole thing
#cat "/dev/shm/$md5str.mp3" | mpg123 - 1>>/dev/shm/voice.log 2>>/dev/shm/voice.log
play /dev/shm/$md5str.mp3 speed 1.00 pitch 0
time2=$(date +%s%N | cut -b1-13)
echo $(($time2-$time1))

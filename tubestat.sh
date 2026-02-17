#!/bin/bash
#set -xv

tfile=/tmp/tubestatus.$$

trap "sudo /usr/local/bin/bright ; setterm --term linux --cursor on 2>/dev/null ; setterm -term linux --blank 1 2>/dev/null ; setterm --term linux --blank=poke 2>/dev/null ; rm $tfile ; exit" 2

setterm --term linux --blank=force 2>/dev/null
sudo /usr/local/bin/dim
while :
do
  . /home/marcusc/git/pylearn/lines.txt
  curl https://api.tfl.gov.uk/$TUBELINES/Disruption 2> /dev/null | jq -r '.[] | .description' > $tfile
  
  if [ -s $tfile ]
  then
    setterm --term linux --blank=poke 2>/dev/null
    setterm --term linux --blank 0 2>/dev/null
    setterm --term linux --cursor off 2>/dev/null
    printf "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
    cat $tfile | sort -u | while read line rest
    do
      case "$line" in
        PICCADILLY|Piccadilly|piccadilly)	fg=white; bg=blue;;
        CENTRAL|Central|central)	fg=white; bg=red;;
        NORTHERN|Northern|northern)	fg=black; bg=white;;
        DISTRICT|District|district)	fg=black; bg=green;;
        *)			fg=white; bg=black;;
      esac
      setterm --term linux --background=$bg --foreground=$fg 2>/dev/null
      echo ""
      echo "$line $rest"
      setterm --term linux --background=black --foreground=white 2>/dev/null
    done
    i=1
    while [ "$i" -lt "29" ]
    do
      echo ""
      sleep 2
      i=$((i+1))
    done
  else
    setterm --term linux --cursor off 2>/dev/null
    setterm --term linux --blank=force 2>/dev/null
    sleep 30
  fi
done

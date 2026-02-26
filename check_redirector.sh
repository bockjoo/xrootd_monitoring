#!/bin/bash
# Configure
notifytowhom="your_email"
redirector="your_redirector" # e.g., cmsio2.rc.ufl.edu
export X509_USER_PROXY="your_x509_proxy" # e.g., $X509_USER_PROXY
if [ $(/bin/hostname -s) != $(echo $redirector | cut -d. -f1)  ] ; then
    echo ERROR this has to be run on the $redirector machine
    exit 1
fi
which xrdmapc 1>/dev/null 2>/dev/null
if [ $? -eq 0 ] ; then
    servers=$(xrdmapc --list all $redirector:1094 | grep Srv | awk '{print $2}' | cut -d: -f1)
else # manually configure
    servers=$(for i in {3..7} 10 ; do echo cmsio$i ; done)
fi
# Configure

#echo $servers
server_counts=$(for server in $servers ; do echo $(grep "cms_SelNode: "   /var/log/xrootd/clustered/cmsd.log | grep -v affinity | awk '{print $5}' | grep $server | wc -l)+$server ; done)
N=$(echo $servers | wc -w)
#printf "$server_counts\n"
echo $N servers
#server_counts="
#863147+cmsio4
#1740+cmsio5
#661+cmsio6
#514+cmsio7
#400+cmsio10
#0+cmsio3"
printf "$server_counts\n"

mu=$(sum=0 ; for server_count in $server_counts ; do count=$(echo $server_count | cut -d+ -f1) ; sum=$(echo "scale=0 ; $count + $sum" | bc) ; done ; echo "scale=0 ; $sum / $N " | bc)
echo $mu mu
#sigma=$(sum=0 ; for server_count in $server_counts ; do count=$(echo $server_count | cut -d+ -f1) ; sum=$(echo "scale=0 ; $sum + ($count - $mu)^2" | bc) ; done ; echo "scale=0 ; ($sum / $N )^1/2" | bc)
#echo $sigma sigma
sigma=$(for server_count in $server_counts ; do echo $server_count | cut -d+ -f1 ; done | awk '{sum+=$1; sumsq+=$1*$1} END {print sqrt(sumsq/NR - (sum/NR)**2)}')

outlier=0
for server_count in $server_counts ; do
    count=$(echo $server_count | cut -d+ -f1)
    server=$(echo $server_count | cut -d+ -f2)
    Z=$(echo "scale=1 ; ( $count - $mu ) / $sigma * 10 " |bc | cut -d. -f1) # $server
    [ $Z -lt 0 ] && Z=$(expr -1 \* $Z)
    #echo DEBUG Z = $Z
    [ $Z -gt 30 ] && outlier=$(expr $outlier + 1)
done

if [ $outlier -gt 0 ] ; then
    echo There is an imbalance in selecting servers
    printf "$(/bin/hostname -s) $(/bin/basename $0)\nThere is an imbalance in selecting servers\n$(cat check_redirector.log)" | mail -s "Warning $(/bin/basename $0) imbalance in server selection" $notifytowhom
else
    echo OK
fi

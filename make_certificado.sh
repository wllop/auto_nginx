#/bin/bash
var1=$1
var2=$2
var3=$3
if [ "$3" != "" ]; then
    var3=",$var3"
fi
if [ -d "$var2" ];then
/opt/letsencrypt/letsencrypt-auto certonly -a webroot --webroot-path=$var2 -d $var1$var3
else
echo "$var2 NO existe"
fi

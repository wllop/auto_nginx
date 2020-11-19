#/bin/bash
if [ $# -le 0 ];then
  echo "Indique la URL del nuevo sitio web!!"
  exit 33
fi

while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
do
 read -p "¿Quieres aislar este sitio Web mediante CHROOT? (S/N)" res
done

if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
##CHROOT
#/bin/bash
if [ $# -le 0 ];then
  echo "Indique la URL del nuevo sitio web!!"
  exit 33
fi
##Compruebo nuevas versiones de plantillas
if [ ! -f /etc/nginx/sites-available/plantilla_chroot_site ];then
   cp -fr plantillas/plantilla_chroot_nginx /etc/nginx/sites-available/plantilla_chroot_site
else
 diff rq plantillas/plantilla_chroot_nginx /etc/nginx/sites-available/plantilla_chroot_site 2>/dev/null >/dev/null || cp -f plantillas/plantilla_chroot_nginx /etc/nginx/sites-available/plantilla_chroot_site
fi
##Compruebo nuevas versiones de plantillas_SSL
if [ ! -f /etc/nginx/sites-available/plantilla_chroot_site_ssl ];then
     cp -fr plantillas/plantilla_chroot_nginx_ssl /etc/nginx/sites-available/plantilla_chroot_site_ssl
else
 diff rq plantillas/plantilla_chroot_nginx_ssl /etc/nginx/sites-available/plantilla_chroot_site_ssl 2>/dev/null >/dev/null || cp -f plantillas/plantilla_chroot_nginx_ssl /etc/nginx/sites-available/plantilla_chroot_site_ssl
fi

##Usuario para chrootear
user=$(grep -i "webjack_" /etc/passwd|cut -d: -f1|cut -d_ -f2|sort -n|tail -1)
user=webjack_$(echo $[user+1])
if [ -e "/var/www/$user/" ];then
  echo "El directorio /var/www/$user existe"
else
mkdir -p /var/www/$user/
fi
#creo ruta
useradd -b /var/www/ -s /dev/null -M $user
mkdir -p /var/www/$user/chroot/web
mkdir -p /var/www/$user/chroot/tmp
mkdir -p /var/www/$user/chroot/log
echo $1>/var/www/$user/info.txt
sites=$(ls /etc/nginx/sites-enabled|wc -l)
if [ "$sites" -ge "1" ];then ##Ya hay
  #Elimino las opciones listen 443 para que no haya error de configuración
  linea=$(grep "listen 443" /etc/nginx/sites-available/plantilla_chroot_site_ssl -n|cut -d: -f1)
  sed -i  "${linea}d" /etc/nginx/sites-available/plantilla_chroot_site_ssl
  sed -i "${linea}i\listen 443;" /etc/nginx/sites-available/plantilla_chroot_site_ssl
  linea=$(grep "listen 443" /etc/nginx/sites-available/plantilla_site_ssl -n|cut -d: -f1)
  sed -i  "${linea}d" /etc/nginx/sites-available/plantilla_site_ssl
  sed -i "${linea}i\listen 443;" /etc/nginx/sites-available/plantilla_site_ssl
fi
#------
##Tengo que coger el usuario de nginx.conf
usernginx=$(grep -w user /etc/nginx/nginx.conf|awk '{ print $2}'|tr -d ";")

if type php 2>/dev/null >/dev/null;then
 #Ruta fichero plantilla!
 rpool=$(find /etc/php -name "pool.d" -type d)
 cp plantillas/plantilla_pool.conf $rpool/$user.conf
 sed -i s/{pool_name}/$user/g  $rpool/$user.conf
 sed -i s/{usernginx}/$usernginx/g  $rpool/$user.conf
 #Solicitamos modificar las variables de php form submit y upload en .php
 #post_max_size = 8M 
 #upload_max_filesize = 2M
 res=""
  #vphp1=$(grep upload_max_filesize $rpool/$user.conf)
  #vphp2=$(grep post_max_size $rpool/$user.conf)
  echo "Valor por defecto de las variables:"
  echo "Upload_Max_Filesize: 50M"
  echo "Post_Max_Size: 50M"
  vnphp1="50M"
  vnphp2="50M"
  while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
  do
  read -p "¿Quieres modificar estos valores (S/N)? " res
  done
  if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
    read -p "Nuevo valor para post_max_size (Ej. 100M) " vnphp1
    read -p "Nuevo valor para upload_max_size (Ej. 40M) " vnphp2
  fi

    sed -i "s/{uploadmax}/$vnphp2/g" $rpool/$user.conf
    sed -i "s/{postmaxsize}/$vnphp1/g" $rpool/$user.conf
echo "Optimización PHP"
res=""
while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
  do
  read -p "¿Espera un elevado número de tráfico en este sitio (S/N)? " res
  done
  if [ "$res" == "s" ] || [ "$res" == "S" ]; then #A mejorar y tener en cuenta características equipo. https://serverfault.com/questions/939436/understand-correctly-pm-max-children-tuning
       sed -i s/{pm_type}/dynamic/g  $rpool/$user.conf
       sed -i s/{usernginx}/$usernginx/g  $rpool/$user.conf
       sed -i s/{pm_uno}/"pm.max_children = 6"/g  $rpool/$user.conf  
       sed -i s/{pm_dos}/"pm.start_servers = 4"/g  $rpool/$user.conf
       sed -i s/{pm_tres}/"pm.min_spare_servers = 1"/g  $rpool/$user.conf
       sed -i s/{pm_cuatro}/"pm.max_spare_servers = 4"/g  $rpool/$user.conf
  else
       sed -i s/{pm_type}/ondemand/g  $rpool/$user.conf
       sed -i s/{usernginx}/$usernginx/g  $rpool/$user.conf
       sed -i s/{pm_uno}/"pm.max_children = 6"/g  $rpool/$user.conf
       sed -i s/{pm_dos}/"pm.process_idle_timeout = 3s"/g  $rpool/$user.conf
       sed -i s/{pm_tres}/" "/g  $rpool/$user.conf
       sed -i s/{pm_cuatro}/" "/g  $rpool/$user.conf
  fi
for ruta in $(find /etc/init.d/ -name "*php*"); do
    $ruta restart
done
else
 echo PHP NO instalado
fi

cp -f /etc/nginx/sites-available/plantilla_chroot_site /tmp/$1

#regula=$(echo $1|cut -d. -f2-) 
regula=$1
sed -i "s/{URL}/$regula/g" /tmp/$1
#regulariza ruta
reg="\/var\/www\/$user\/chroot\/web"
sed -i "s/{PATH}/$reg/g" /tmp/$1
#Ya que el certificado NO es wildcard y estará asociado al dominio indicado aquí, la comprobación será sin https para dominio.com y www.dominio.com!   
regula=$(echo $1|cut -d. -f1)
dominio=$(echo $1|cut -d. -f2-) 
if [ "$regula" == "www" ]; then
    hhost="$dominio"
  else
    read -n 1 -p "¿Quieres añadir el host www.$1? (S/N) " resc 
    if [ "$resc" == "S" ] || [ "$resc" == "s" ]; then  
     hhost="www.$1"
    else
     hhost=""
    fi
fi
sed -i "s/{URL2}/$hhost/g" /tmp/$1
#Pool PHP
if  type php >/dev/null 2>/dev/null; then
     vphp="1"
     rutafcgi=$(find /run/ -name *$user.sock|head -1|sed 's/\//\\\//g')
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" /tmp/$1
else
     vphp="0"
     sed -i "s/::fastcgi::/#/g" /tmp/$1

fi
mv /tmp/$1 /etc/nginx/sites-available/$1
if [ -f /etc/nginx/sites-enabled/$1 ];then
   rm -fr /etc/nginx/sites-enabled/$1
fi
ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/$1
/etc/init.d/nginx configtest
if [ $? != 0 ];then
 echo "Error configuración nginx. Revise el fichero ."
 rm -fr /var/www/$user/
 rm /etc/nginx/sites-available/$1
 rm /etc/nginx/sites-enabled/$1
 exit
fi
res=""
usermod -a -G $user $usernginx
echo "Funciona!!" >/var/www/$user/chroot/web/index.htm
#Búsqueda sendmail para envío correos:
echo "Para garantizar el envío de correos a través del entorno CHROOT, debe instalar mini_sendmail: https://github.com/vkucukcakar/mini_sendmail/blob/master/README.md. El ejecutable debe renombrarlo a sendmail."
read -p "Pulse una tecla para continuar...." var
read -p "Introduzca la ruta donde está ubicado mini_sendmail: (Recuerde renombrar el ejecutable a sendmail)-->" rutasend
mkdir -p /var/www/$user/chroot/usr/sbin/
if [ -f $rutasend ]; then
cp $rutasend /var/www/$user/chroot/usr/sbin/sendmail
else
  if [ -f $rutasend/sendmail ]; then
  cp $rutasend/sendmail /var/www/$user/chroot/usr/sbin/sendmail
  fi
fi
mkdir -p /var/www/$user/chroot/dev
mkdir -p /var/www/$user/chroot/bin
cp -f /bin/sh /var/www/$user/chroot/bin/sh 
touch /var/www/$user/chroot/dev/urandom
mount --bind /dev/urandom /var/www/$user/chroot/dev/urandom
mkdir -p /var/www/$user/chroot/etc/ssl/certs
mount -o "ro,bind" /etc/ssl/certs /var/www/$user/chroot/etc/ssl/certs
touch /var/www/$user/chroot/etc/resolv.conf
mount --bind /etc/resolv.conf /var/www/$user/chroot/etc/resolv.conf
mkdir -p /var/www/$user/chroot/lib/x86_64-linux-gnu
touch /var/www/$user/chroot/lib/x86_64-linux-gnu/libnss_dns.so.2
mount --bind /lib/x86_64-linux-gnu/libnss_dns.so.2 /var/www/$user/chroot/lib/x86_64-linux-gnu/libnss_dns.so.2
touch /var/www/$user/chroot/lib/x86_64-linux-gnu/libc.so.6
mount --bind /lib/x86_64-linux-gnu/libc.so.6 /var/www/$user/chroot/lib/x86_64-linux-gnu/libc.so.6
mkdir -p /var/www/$user/chroot/lib64/
touch /var/www/$user/chroot/lib64/ld-linux-x86-64.so.2
mount --bind /lib64/ld-linux-x86-64.so.2 /var/www/$user/chroot/lib64/ld-linux-x86-64.so.2
touch /var/www/$user/chroot/etc/hosts
touch /var/www/$user/chroot/etc/localtime
mount --bind /etc/hosts /var/www/$user/chroot/etc/hosts
mount --bind /etc/localtime /var/www/$user/chroot/etc/localtime
mkdir -p /var/www/$user/chroot/usr/share/zoneinfo
mount -o "ro,bind" /usr/share/zoneinfo /var/www/$user/chroot/usr/share/zoneinfo
mkdir -p /var/www/$user/chroot/usr/share/ca-certificates
mount -o "ro,bind" /usr/share/ca-certificates /var/www/$user/chroot/usr/share/ca-certificates
chown -R root:$user /var/www/$user/chroot 2>/dev/null >/dev/null
chmod 0010 /var/www/$user/chroot
chmod 0070 /var/www/$user/chroot/web
chmod 0030 /var/www/$user/chroot/log
chmod -R 0030 /var/www/$user/chroot/tmp/
/etc/init.d/nginx reload 2>/dev/null || /etc/init.d/nginx start
while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
do
 read -p "¿Quieres instalar un certificado SSL para este sitio? (S/N)" res
done

if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
  #Si no está la carpeta /etc/nginx/ssl, la creo
  if [ ! -d /etc/nginx/ssl ];then
    mkdir -p /etc/nginx/ssl 
  fi
  if [ ! -f /etc/ssl/certs/dhparam.pem ]; #Para mejorar, debería estar instalado pero... SSL
   then
   openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
  fi

  if [ ! -x ./make_certificado.sh ];then
    chmod a+x ./make_certificado.sh
  fi

  if [ -e /etc/letsencrypt/live/$1* ]; then
    rm -fr /etc/letsencrypt/live/$1*
  fi
  
  if [ -e /etc/letsencrypt/renewal/$1* ]; then
    rm -fr /etc/letsencrypt/renewal/$1*
  fi

  if [ $? = 0 ];then
   if [ -e /etc/nginx/ssl/$1 ]; then
    rm -fr /etc/nginx/ssl/$1
   fi
   
  ./make_certificado.sh $1 /var/www/$user/chroot/web $hhost
  if [ $? != 0 ];then
   echo "Error en el certificado."
   exit
  fi
  rutacert=$(ls -d  /etc/letsencrypt/live/$1* 2>/dev/null)
  if [ "$rutacert" == "" ]; then
     rutacert=$(ls -d  /etc/letsencrypt/live/www.$1* 2>/dev/null)
  fi
  ln -s $rutacert /etc/nginx/ssl/$1 2>/dev/null
  mkdir -p /var/www/$user/chroot/ssl/$1
  mount -o "ro,bind" /etc/letsencrypt/live/$1 /var/www/$user/chroot/ssl/$1 

  fi
  regula=$1
  cp -f /etc/nginx/sites-available/plantilla_chroot_site_ssl /tmp/$1
  sed -i "s/{URL}/$regula/g" /tmp/$1
  #regulariza ruta
  sed -i "s/{PATH}/$reg/g" /tmp/$1
  sed -i "s/{URL2}/$hhost/g" /tmp/$1
  #AHORA ACTIVO LA REDIRECCIÓN 301 SI ES WWW O SIN WWW
#Ya que el certificado NO es wildcard y estará asociado al dominio indicado aquí!
regula=$(echo $1|cut -d. -f1)
dominio=$(echo $1|cut -d. -f2-) 
if [ "$regula" == "www" ]; then
    red301="if (\$host = $dominio) { return 301 https:\/\/www.\$host\$request_uri;}"
  else
    red301="if (\$host = www.$1) { return 301 https:\/\/\$host\$request_uri;}"
fi
sed -i "s/{RED301}/$red301/g" /tmp/$1
#Pool PHP
if  type php >/dev/null 2>/dev/null; then
     vphp="1"
     rutafcgi=$(find /run/ -name *$user.sock|head -1|sed 's/\//\\\//g')
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" /tmp/$1
else
     vphp="0"
     sed -i "s/::fastcgi::/#/g" /tmp/$1

fi
#
##Una vez creado, hay que eliminar las opciones listen ssl http2 y backlog
if [ -f /etc/nginx/sites-available/$1 ];then
   rm -fr /etc/nginx/sites-available/$1
fi
mv /tmp/$1 /etc/nginx/sites-available/$1

if [ -f /etc/nginx/sites-enabled/$1 ];then
   rm -fr /etc/nginx/sites-enabled/$1
fi
ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/$1

/etc/init.d/nginx configtest
  if [ $? != 0 ];then
   echo "Error configuración nginx con SSL. Revise el fichero ."
  exit
  fi
  /etc/init.d/nginx reload
fi
for ruta in $(find /etc/init.d/ -name "*php*"); do
    $ruta restart
done
else ##NO CHROOT
if [ -e "/var/www/$1" ];then
  echo "El directorio /var/www/$1 existe"
else
mkdir -p /var/www/$1/web
fi
sites=$(ls /etc/nginx/sites-enabled|wc -l)
if [ "$sites" -ge "1" ];then ##Ya hay
  echo dentro
  #Elimino las opciones listen 443 para que no haya error de configuración
  linea=$(grep "listen 443" /etc/nginx/sites-available/plantilla_site_ssl -n|cut -d: -f1)
  sed -i  "${linea}d" /etc/nginx/sites-available/plantilla_site_ssl
  sed -i "${linea}i\listen 443;" /etc/nginx/sites-available/plantilla_site_ssl
  linea=$(grep "listen 443" /etc/nginx/sites-available/plantilla_chroot_site_ssl -n|cut -d: -f1)
  sed -i  "${linea}d" /etc/nginx/sites-available/plantilla_chroot_site_ssl
  sed -i "${linea}i\listen 443;" /etc/nginx/sites-available/plantilla_chroot_site_ssl
fi

##Tengo que coger el usuario de nginx.conf
usernginx=$(grep -w user /etc/nginx/nginx.conf|awk '{ print $2}'|tr -d ";")
chown -R $usernginx:$usernginx /var/www/$1/web
if [ ! -f /etc/nginx/sites-available/plantilla_site ];then
   cp -fr plantillas/plantilla_nginx /etc/nginx/sites-available/plantilla_site
fi
cp -f /etc/nginx/sites-available/plantilla_site /tmp/$1
#SinPool PHP
if  type php >/dev/null 2>/dev/null; then
     vphp="1"
     for rutafpm in $(find /etc -name www.conf|head -1)
     do
      rutafcgi=$(grep "listen =" $rutafpm|cut -d"=" -f2-|tr -d " "|sed 's/\//\\\//g')
     done
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" /tmp/$1
else
     vphp="0"
     sed -i "s/::fastcgi::/#/g" /tmp/$1

fi
 
regula=$1
sed -i "s/{URL}/$regula/g" /tmp/$1
#regulariza ruta
reg="\/var\/www\/$1\/web"
sed -i "s/{PATH}/$reg/g" /tmp/$1
#Ya que el certificado NO es wildcard y estará asociado al dominio indicado aquí, la comprobación será sin https para dominio.com y www.dominio.com!   
regula=$(echo $1|cut -d. -f1)
dominio=$(echo $1|cut -d. -f2-) 
if [ "$regula" == "www" ]; then
    hhost="$dominio"
  else
    read -n 1 -p "¿Quieres añadir el host www.$1? (S/N) " resc 
    if [ "$resc" == "S" ] || [ "$resc" == "s" ]; then  
     hhost="www.$1"
    else
     hhost=""
    fi
fi
sed -i "s/{URL2}/$hhost/g" /tmp/$1

mv /tmp/$1 /etc/nginx/sites-available/$1
if [ -f /etc/nginx/sites-enabled/$1 ];then
   rm -fr /etc/nginx/sites-enabled/$1
fi
ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/$1
/etc/init.d/nginx configtest
if [ $? != 0 ];then
 echo "Error configuración nginx. Revise el fichero ."
 rm -fr /var/www/$1
 rm /etc/nginx/sites-available/$1
 rm /etc/nginx/sites-enabled/$1
 exit
fi

/etc/init.d/nginx reload 2>/dev/null || /etc/init.d/nginx start
res=""
while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
do
 read -p "¿Quieres instalar un certificado SSL para este sitio? (S/N)" res
done
if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
  #Si no está la carpeta /etc/nginx/ssl, la creo
  if [ ! -d /etc/nginx/ssl ];then
    mkdir /etc/nginx/ssl
  fi
  if [ ! -f /etc/ssl/certs/dhparam.pem ]; #Para mejorar, debería estar instalado pero... SSL
   then
   openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
  fi


if [ ! -f /etc/nginx/sites-available/plantilla_site_ssl ];then
   cp -fr plantillas/plantilla_nginx_ssl /etc/nginx/sites-available/plantilla_site_ssl
fi

  if [ ! -x ./make_certificado.sh ];then
    chmod a+x ./make_certificado.sh
  fi

  if [ -e /etc/letsencrypt/live/$1 ]; then
    rm -fr /etc/letsencrypt/live/$1
  fi

  ./make_certificado.sh $1 /var/www/$1/web $hhost

  if [ $? = 0 ];then
   if [ -e /etc/nginx/ssl/$1 ]; then
    rm -fr /etc/nginx/ssl/$1
   fi
  rutacert=$(ls -d  /etc/letsencrypt/live/$1* 2>/dev/null)
  if [ "$rutacert" == "" ]; then
     rutacert=$(ls -d  /etc/letsencrypt/live/www.$1* 2>/dev/null)
  fi
  ln -s $rutacert /etc/nginx/ssl/$1 2>/dev/null
  fi
  regula=$1
  cp -f /etc/nginx/sites-available/plantilla_site_ssl /tmp/$1
#SinPool PHP
if  type php >/dev/null 2>/dev/null; then
     vphp="1"
     for rutafpm in $(find /etc -name www.conf|head -1)
     do
      rutafcgi=$(grep "listen =" $rutafpm|cut -d"=" -f2-|tr -d " "|sed 's/\//\\\//g')
     done
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" /tmp/$1
else
     vphp="0"
     sed -i "s/::fastcgi::/#/g" /tmp/$1

fi
  sed -i "s/{URL}/$regula/g" /tmp/$1
  #regulariza ruta
  sed -i "s/{PATH}/$reg/g" /tmp/$1
  sed -i "s/{URL2}/$hhost/g" /tmp/$1
  #AHORA ACTIVO LA REDIRECCIÓN 301 SI ES WWW O SIN WWW
#Ya que el certificado NO es wildcard y estará asociado al dominio indicado aquí!
regula=$(echo $1|cut -d. -f1)
dominio=$(echo $1|cut -d. -f2-) 
if [ "$regula" == "www" ]; then
    red301="if (\$host = $dominio) { return 301 https:\/\/www.\$host\$request_uri;}"
  else
    red301="if (\$host = www.$1) { return 301 https:\/\/\$host\$request_uri;}"
fi
sed -i "s/{RED301}/$red301/g" /tmp/$1

  mv /tmp/$1 /etc/nginx/sites-available/$1
##Una vez creado, hay que eliminar las opciones listen ssl http2 y backlog
  /etc/init.d/nginx configtest
  if [ $? != 0 ];then
   echo "Error configuración nginx con SSL. Revise el fichero ."
  exit
  fi
  /etc/init.d/nginx reload
fi
echo "Funciona!!" >/var/www/$1/web/index.htm
fi #FinElseChroot

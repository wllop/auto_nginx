#!/bin/bash
#Compruebo si existe
export PATH=$PATH:/usr/sbin:/usr/local/sbin:/sbin
ide=$(id)
#echo "${ide:0:5}"
if [ "${ide:0:5}" != "uid=0" ];then
 echo "Debes ser ROOT para poder instalar el servicio nginx."
 exit
fi

if [ -f /etc/init.d/nginx ];then
  echo "Nginx ya se encuentra instalado."
  while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
  do
    read -p "¿Quieres actualizar las plantillas de site de Nginx? (S/N)" res
  done
  if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
   ##Comprobar plantillas
   cp -f plantillas/plantilla_nginx /tmp/plantilla_site
   cp -f plantillas/plantilla_nginx_ssl /tmp/plantilla_site_ssl
   if  type php >/dev/null 2>/dev/null; then
     vphp="1"
     rutafcgi=$(find /run/php -name *.sock|head -1|sed 's/\//\\\//g')
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" /tmp/plantilla_site
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" /tmp/plantilla_site_ssl
    else
     vphp="0"
     sed -i "s/::fastcgi::/#/g" /tmp/plantilla_site
     sed -i "s/::fastcgi::/#/g" /tmp/plantilla_site_ssl
   fi 
   #Copiamos las plantillas de sites en /etc/nginx/sites-availables
   if [ -d /etc/nginx/sites-available ]; then
     mv /tmp/plantilla_site /etc/nginx/sites-available
     mv /tmp/plantilla_site_ssl /etc/nginx/sites-available
   else
     mkdir -p /etc/nginx/sites-available
     mv /tmp/plantilla_site /etc/nginx/sites-available
     mv /tmp/plantilla_site_ssl /etc/nginx/sites-available
   fi
   echo "Plantillas actualizadas"
   exit
 else
  exit
 fi
fi
#Mirar si es debianlsb o Ubuntu
so=$(lsb_release -d|expand|tr -s " "|cut -d: -f2|cut -d" " -f2|tr [:upper:] [:lower:])
verso=$(lsb_release -c|expand|tr -d " "|cut -d: -f2|tr [:upper:] [:lower:])
echo "deb http://nginx.org/packages/mainline/$so/ $verso nginx">/etc/apt/sources.list.d/nginx.list
echo "deb-src http://nginx.org/packages/mainline/$so $verso nginx">>/etc/apt/sources.list.d/nginx.list
wget http://nginx.org/keys/nginx_signing.key -O /etc/apt/nginx_signing.key && apt-key add /etc/apt/nginx_signing.key && apt-get update && apt-get install -y nginx || echo "Error instalación Nginx" && exit 33
#Habilitamos firewall para evitar conexiones mientras configuramos/securizamos el servidor
#Compruebo si hay regla firewall de 80 si está debo comprobar si está DROP
#if ! iptables -L -n|grep -e ":80" >/dev/null 2>/dev/null ;then
#  iptables -A INPUT -p tcp --dport 80 -j DROP
#fi
#Compruebo si hay regla firewall de 443
#if ! iptables -L -n|grep -e ":443" >/dev/null 2>/dev/null ;then
#  iptables -A INPUT -p tcp --dport 443 -j DROP
#fi
#Ahora vamos a optimizar la configuración del servidor.
#Comprobar el número de micros.
if grep -i "nginx" /etc/passwd >/dev/null 2>/dev/null; then
   usuario=nginx
elif grep -i "www-data" /etc/passwd >/dev/null 2>/dev/null; then
  usuario=www-data
fi
if [ "$usuario" == "" ];then
  echo "Error: Usuario asociado al servicio Nginx NO encontrado"
  exit
fi
#Preparamos la configuración de nginx.
micros=$(grep processor /proc/cpuinfo |wc -l)  
workers=$(ulimit -n)
sysctl -w net.core.somaxconn=65535
if ! test -f plantillas/nginx.conf_template; then
   echo "Error: Es necesario el fichero: plantillas/nginx.conf_template"
   exit
fi
cp plantillas/nginx.conf_template /tmp/nginx.conftmp
sed -i "s/::vprocess::/$micros/g" /tmp/nginx.conftmp
sed -i "s/::vwconn::/$workers/g" /tmp/nginx.conftmp
sed -i "s/::vuser::/$usuario/g" /tmp/nginx.conftmp
mv /tmp/nginx.conftmp /etc/nginx/nginx.conf
mkdir /etc/nginx/ssl
#Solicitamos si quiere motor PHP
if  ! type php >/dev/null 2>/dev/null; then
while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
do
 read -p "¿Quieres instalar un motor PHP? (S/N)" res
done

if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
   #Instalar fpm-php
   #Añadir repositorios SURY
   apt install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https
   wget https://packages.sury.org/php/apt.gpg -O /tmp/apt.gpg
   apt-key add /tmp/apt.gpg
   echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.list
   apt-get update
   
  echo -n "Se va a instalar la siguiente versión de PHP: "
  apt-cache show php-fpm|grep version
  echo "Junto con los módulos de PHP: Mysql - OpCache - MbString"
  res=""
  while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
  do
  read -p "¿Quieres instalar esta versión de PHP? (S/N)" res
  done
  if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
   #Instalar fpm-php
   apt-get -y install php-fpm php-mysql php-mbstring php-gd php-json
   #Regularizo, en su caso, usuario por defecto de php a nginx
    find /etc/php/ -name "*.conf"  -exec sed -i "s/www-data/$usuario/g" {} +
  fi
fi
fi #Fin IF para saber si PHP ya está instalado.
if ! test -f plantillas/plantilla_nginx ; then
   echo "Error: Es necesario el fichero: plantillas/plantilla_nginx"
   exit
fi
if ! test -f plantillas/plantilla_nginx_ssl ; then
   echo "Error: Es necesario el fichero: plantillas/plantilla_nginx_ssl"
   exit
fi
cp plantillas/plantilla_nginx plantilla_site
cp plantillas/plantilla_nginx_ssl plantilla_site_ssl
if  type php >/dev/null 2>/dev/null; then
     vphp="1"
     rutafcgi=$(find /run/php -name *.sock|head -1|sed 's/\//\\\//g')
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" plantilla_site
     sed -i "s/::fastcgi::/fastcgi_pass unix:$rutafcgi;/g" plantilla_site_ssl
else
     vphp="0"
     sed -i "s/::fastcgi::/#/g" plantilla_site
     sed -i "s/::fastcgi::/#/g" plantilla_site_ssl

fi
#Copiamos las plantillas de sites en /etc/nginx/sites-availables
if [ -d /etc/nginx/sites-available ]; then
     mv plantilla_site /etc/nginx/sites-available
     mv plantilla_site_ssl /etc/nginx/sites-available
else
     mkdir -p /etc/nginx/sites-available
     mv plantilla_site /etc/nginx/sites-available
     mv plantilla_site_ssl /etc/nginx/sites-available
fi
#Comprobamos que exite el directorio sites-enabled
if [ ! -d "/etc/nginx/sites-enabled" ];then
  mkdir -p /etc/nginx/sites-enabled
fi

#Solicitamos modificar las variables de php form submit y upload en .php
#post_max_size = 8M 
#upload_max_filesize = 2M
res=""
for ruta in $(find /etc -name php.ini); do
if [ -f $ruta ];then
 if [ "$vnphp1" != "" ]; then #Si  tiene valor es directamente modificamos el fichero
    sed -i "s/$vphp1/$vnphp1/g" $ruta
    sed -i "s/$vphp2/$vnphp2/g" $ruta
 elif [ "$res" != "" ];then #Sólo puede ser no, sino entraría en la condición anterior.
    break
 else
  vphp1=$(grep upload_max_filesize $ruta)
  vphp2=$(grep post_max_size $ruta)
  echo "Valor por defecto de las variables:"
  echo $vphp1
  echo $vphp2
  while [ "$res" != "s" ] && [ "$res" != "S" ] && [ "$res" != "n" ] && [ "$res" != "N" ];
  do
  read -p "¿Quieres modificar estos valores (S/N)? " res
  done
  if [ "$res" == "s" ] || [ "$res" == "S" ]; then 
    read -p "Nuevo valor para post_max_size (Ej. 100M) " vnphp1
    read -p "Nuevo valor para upload_max_size (Ej. 40M) " vnphp2
    if [ "$vnphp2" == "" ]; then
      vnphp1=$vphp1
    else 
      vnphp1="post_max_size = $vnphp1"
    fi 
    if [ "$vnphp2" == "" ]; then
      vnphp2=$vphp2
    else
      vnphp2="upload_max_filesize = $vnphp2"
    fi 
    sed -i "s/$vphp1/$vnphp1/g" $ruta
    sed -i "s/$vphp2/$vnphp2/g" $ruta
  fi
fi
fi
done
if [ "$res" == "s" ] || [ "$res" == "S" ]; then #Se han realizado cambios en php.ini
   for ruta in $(find /etc/init.d/ -name "*php*"); do
     $ruta restart
   done
fi 
## Si hemos configurado el motor PHP, comprobamos la ruta de php-fpm y dejamos listas las plantillas para los sites!!
if ! test -f /opt/letsencrypt/letsencrypt-auto; then
  if ! git 2>/dev/null >/dev/null;then
    apt-get -y install git
  fi
  git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
fi
if [ ! -f /etc/ssl/certs/dhparam.pem ]; #Para mejorar SSL
then
      openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
fi

#Ahora ya permitimos el acceso
#Habilitamos firewall
#Compruebo si hay regla firewall de 80
#if ! iptables -L -n|grep -e ":80" >/dev/null 2>/dev/null ;then
#  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
#fi
##Compruebo si hay regla firewall de 443
#if ! iptables -L -n|grep -e ":443" >/dev/null 2>/dev/null ;then
#  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
#fi
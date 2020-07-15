#/bin/bash
if [ $# -le 0 ];then
  echo "Indique la URL del nuevo sitio web!!"
  exit 33
fi

if [ -e "/var/www/$1" ];then
  echo "El directorio /var/www/$1 existe"
else
mkdir -p /var/www/$1/web
fi

sites=$(ls /etc/nginx/sites-enabled|wc -l)
if [ "$sites" -eq "1" ];then ##Ya hay
  echo dentro
  #Elimino las opciones listen 443 para que no haya error de configuración
  linea=$(grep "listen 443" /etc/nginx/sites-available/plantilla_site_ssl -n|cut -d: -f1)
  sed -i  "${linea}d" /etc/nginx/sites-available/plantilla_site_ssl
  sed -i "${linea}i\listen 443;" /etc/nginx/sites-available/plantilla_site_ssl
fi

##Tengo que coger el usuario de nginx.conf
usernginx=$(grep -w user /etc/nginx/nginx.conf|awk '{ print $2}'|tr -d ";")
chown -R $usernginx:$usernginx /var/www/$1/web
if [ ! -f /etc/nginx/sites-available/plantilla_site ];then
   cp -fr plantillas/plantilla_nginx /etc/nginx/sites-available/plantilla_site
fi
cp -f /etc/nginx/sites-available/plantilla_site /tmp/$1

#regula=$(echo $1|cut -d. -f2-) 
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
  rutacert=$(ls -d  /etc/letsencrypt/live/$1*)
  ln -s $rutacert /etc/nginx/ssl/$1 2>/dev/null
  fi
  regula=$1
  cp -f /etc/nginx/sites-available/plantilla_site_ssl /tmp/$1
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
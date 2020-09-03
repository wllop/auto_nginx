# # AUTO Nginx - Instalación y Configuración automática de Nginx.
# Instala, Administra y securiza tus sitios web (Host Virtuales con posibilidad de CHROOT!!!) con Nginx de forma fácil, rápida y segura.
Este conjunto de scripts, que posteriormente agruparé, están pensados para automatizar la instalación y configuración de Nginx a la hora de dar de "alta" sitios webs, añadiendo el soporte a PHP y a SSL con letsencrypt.
*pendiente de revisión y completar texto.

USO:

# INSTALACIÓN NGINX
# ./instala_nginx.sh:
  Este script comprueba si ya se encuentra instalado el servidor web Nginx. En caso de que no estuviera instalado, procederá a instalar, desde los repositorios oficiales, el software Nginx. Además, los dará la posibilidad de instalar un motor PHP (PHP-FPM) y el soporte a SSL (HTTPS). Durante la instalación, realizará la configuración de Nginx más óptima, en función de las características hardware del servidor. Además preparará todas las plantillas que serán posteriormente utilizadas por el resto de scripts.

# ALTA NUEVO SITE
# nuevo_site.sh <url>
  Este script permite dar de alta un nuevo sitio web; por lo que creará el fichero de configuración correspondiente. Nos permitirá indicar opciones de PHP e incluso si queremos CHROOTEAR el site para PHP.  Adicionalmente, solicitará si queremos habilitar SSL para dicho sitio web. En este caso, se hará uso de letsencrypt para solicitar e instalar el certificado correspondiente, además, debemos tener en cuenta que la URL debe apuntar a la IP del servidor (comprobar DNS), para que letsencrypt realice de forma satisfactoria la comprobación entre la URL y la IP del servidor para generar el certificado.

# IMPORTANTE
FASE DE PRUEBAS!!!!! Falta mayor testeo para comprobar que TODO funciona de forma correcta. 
Puesto que el entorno CHROOT requiere montaje de ciertas ubicaciones dentro del CHROOT, he creado un .sh llamada autochroot.sh que realiza el montaje de TODAS los sitios web 'chrooteados'. Puesto que esta operación hay que realizarala cada vez que se reinice el servidor, hay que ubicar el script en /etc/init.d, dar permisos de ejecución chmod a+x autochroot.sh y ejecutar update-rc.d autochroot defaults y LISTO!! 
También para que en entorno CHROOT funcione el envío de correos a través de la función, por ejemplo mail(), es necesario descargar y compilar Mini_Sendmail: https://github.com/vkucukcakar/mini_sendmail/blob/master/README.md
Probado de forma satisfactoria en Debian 10 "Buster".

# MEJORAS PENDIENTES
- Unificar todo en un único script (Menú Opciones)
- Habilitar la protección mediante contraseñas de directorios.
- ... las que surjan... ;)

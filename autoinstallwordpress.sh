#!/bin/bash

# Función para solicitar entrada del usuario
function prompt {
  read -p "$1: " $2
}

# Solicitar al usuario la contraseña root de MariaDB
prompt "Ingrese la contraseña root de MariaDB" root_password

# Solicitar al usuario el nombre de usuario de la base de datos de WordPress
prompt "Ingrese el nombre de usuario de la base de datos de WordPress" wp_db_user

# Solicitar al usuario la contraseña del usuario de la base de datos de WordPress
prompt "Ingrese la contraseña del usuario de la base de datos de WordPress" wp_db_password

# Solicitar al usuario el nombre de la base de datos de WordPress
prompt "Ingrese el nombre de la base de datos de WordPress" wp_db_name

# Actualizar paquetes del sistema
sudo apt update
sudo apt upgrade -y

# Instalar Nginx
sudo apt install nginx -y

# Instalar MariaDB
sudo apt install mariadb-server -y

# Instalar PHP 8.3 y extensiones necesarias
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.3 php8.3-fpm php8.3-mysql -y

# Configurar MariaDB
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Configurar la base de datos de WordPress
sudo mysql -uroot -p${root_password} <<EOF
CREATE DATABASE ${wp_db_name};
CREATE USER '${wp_db_user}'@'localhost' IDENTIFIED BY '${wp_db_password}';
GRANT ALL PRIVILEGES ON ${wp_db_name}.* TO '${wp_db_user}'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Descargar WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
sudo mv wordpress /var/www/html/wordpress

# Configurar permisos
sudo chown -R www-data:www-data /var/www/html/wordpress
sudo chmod -R 755 /var/www/html/wordpress

# Configurar wp-config.php
cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
sudo sed -i "s/database_name_here/${wp_db_name}/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/username_here/${wp_db_user}/" /var/www/html/wordpress/wp-config.php
sudo sed -i "s/password_here/${wp_db_password}/" /var/www/html/wordpress/wp-config.php

# Configurar Nginx para WordPress
cat <<EOF | sudo tee /etc/nginx/sites-available/wordpress
server {
    listen 80;
    server_name _;
    root /var/www/html/wordpress;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Habilitar el sitio de WordPress en Nginx
sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# Finalizar
echo "Instalación de WordPress completada. Por favor, abra su navegador y diríjase a su servidor para completar la configuración de WordPress."


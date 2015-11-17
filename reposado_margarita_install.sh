#!/bin/bash

# install reposado and margarita dependecies
apt-get -y install apache2-utils libapache2-mod-wsgi git python-setuptools python curl python-pip apache2
easy_install flask

# make directory for storing reposado and margarita
mkdir /usr/local/sus

# download reposado and margarita
git clone https://github.com/wdas/reposado.git /usr/local/sus/reposado
git clone https://github.com/jessepeterson/margarita.git /usr/local/sus/margarita

# Make directories for storing software updates
mkdir /srv/sus /srv/sus/www /srv/sus/meta

# Write reposado config file
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>LocalCatalogURLBase</key>
        <string></string>
        <key>UpdatesMetadataDir</key>
        <string>/srv/sus/meta</string>
        <key>UpdatesRootDir</key>
        <string>/srv/sus/www</string>
</dict>
</plist>' > /usr/local/sus/reposado/code/preferences.plist

chown -R root:www-data /usr/local/sus /srv/sus/meta /srv/sus/www
chmod -R g+r /usr/local/sus

# Link reposado data so margarita can access it
ln -s /usr/local/sus/reposado/code/reposadolib /usr/local/sus/margarita/reposadolib
ln -s /usr/local/sus/reposado/code/preferences.plist /usr/local/sus/margarita/preferences.plist

# Write wsgi script for auto-starting margarita with apache
echo 'import sys
EXTRA_DIR = "/usr/local/sus/margarita"
if EXTRA_DIR not in sys.path:
    sys.path.append(EXTRA_DIR)
 
from margarita import app as application' > /usr/local/sus/margarita/margarita.wsgi

# Write apache sites configuration
echo '# /etc/apache2/sites-enabled/000-default.conf

# SUS/Reposado lives at 8080
Listen 8080
#Margarita Lives at 8086
Listen 8086

#JDS Stuff lives at 443
<IfModule ssl_module>
        Listen 443
</IfModule>

<IfModule mod_gnutls.c>
        Listen 443
</IfModule>' > /etc/apache2/ports.conf

echo '<VirtualHost *:8080>
    ServerAdmin webmaster@localhost
    DocumentRoot /srv/sus/www

    Alias /content /srv/sus/www/content
    <Directory />
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    # Logging
    ErrorLog ${APACHE_LOG_DIR}/sus-error.log
    LogLevel warn
    CustomLog ${APACHE_LOG_DIR}/sus-access.log combined
</VirtualHost>' > /etc/apache2/sites-enabled/reposado.conf

echo '<VirtualHost *:8086>
    ServerAdmin webmaster@localhost
    DocumentRoot /srv/sus/www
 
    # Base cofiguration
    <Directory />
        Options FollowSymLinks
        AllowOverride None
    </Directory>
 
    # Margarita
    Alias /static /usr/local/sus/margarita/static
    WSGIDaemonProcess margarita home=/usr/local/sus/margarita user=www-data group=www-data threads=5
    WSGIScriptAlias / /usr/local/sus/margarita/margarita.wsgi
    <Directory />
        WSGIProcessGroup margarita
        WSGIApplicationGroup %{GLOBAL}
        AuthType Basic
        AuthName "Margarita (SUS Configurator)"
        AuthUserFile /usr/local/sus/margarita/.htpasswd
        Require valid-user
    </Directory>
 
    # Logging
    ErrorLog ${APACHE_LOG_DIR}/sus-error.log
    LogLevel warn
    CustomLog ${APACHE_LOG_DIR}/sus-access.log combined
</VirtualHost>' > /etc/apache2/sites-enabled/margarita.conf

# correct folder permissions
chown -R root:www-data /usr/local/sus
chmod -R g+r /usr/local/sus

# Kickoff reposado SUS sync
/usr/local/sus/reposado/code/./repo_sync
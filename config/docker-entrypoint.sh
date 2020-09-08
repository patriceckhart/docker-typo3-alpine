#!/bin/bash
set -ex

DIR="/data/typo3/Web"
FILE=/data/typo3/composer.lock
PHP="/php"

if [ -f "$PHP" ]; then
  echo "PHP has already been configured."
else
  echo "PHP Configuration ..."
  echo "date.timezone=${PHP_TIMEZONE:-Europe/Berlin}" > $PHP_INI_DIR/conf.d/date_timezone.ini
  echo "memory_limit=${PHP_MEMORY_LIMIT:-4096M}" > $PHP_INI_DIR/conf.d/memory_limit.ini
  echo "upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE:-1024M}" > $PHP_INI_DIR/conf.d/upload_max_filesize.ini
  echo "post_max_size=${PHP_UPLOAD_MAX_FILESIZE:-1024M}" > $PHP_INI_DIR/conf.d/post_max_size.ini
  echo "allow_url_include=${PHP_ALLOW_URL_INCLUDE:-1}" > $PHP_INI_DIR/conf.d/allow_url_include.ini
  echo "max_execution_time=${PHP_MAX_EXECUTION_TIME:-240}" > $PHP_INI_DIR/conf.d/max_execution_time.ini
  echo "max_input_vars=${PHP_MAX_INPUT_VARS:-1500}" > $PHP_INI_DIR/conf.d/max_input_vars.ini
  rm -rf /var/cache/apk/*
  apk update && apk add tzdata
  cp /usr/share/zoneinfo/${PHP_TIMEZONE:-UTC} /etc/localtime
  apk del tzdata
  rm -rf /var/cache/apk/*
  echo "php" > /php
  echo "PHP configuration completed."
fi

/usr/local/sbin/php-fpm -y /usr/local/etc/php-fpm.conf -R -D
chmod 066 /var/run/php-fpm.sock
chown www-data:www-data /var/run/php-fpm.sock

if [ -f "$FILE" ]; then

  if [ "$GITHUB_TOKEN" != "nogittoken" ]; then

    composer config -g github-oauth.github.com $GITHUB_TOKEN

  fi

  echo "TYPO3 CMS is already installed."
else

  composer clear-cache --no-interaction

  echo "Downloading TYPO3 CMS ..."
  mkdir -p /data/typo3

  if [ "$GITHUB_TOKEN" == "nogittoken" ]; then

    git clone $GITHUB_REPOSITORY /data/typo3

  else

    git clone https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$GITHUB_REPOSITORY /data/typo3
    composer config -g github-oauth.github.com $GITHUB_TOKEN
  
  fi

  echo "Installing TYPO3 CMS ..."
  chown -R www-data:www-data /data
  chmod -R 755 /data
  echo "Wait until composer update is finished!"
  cd /data/typo3 && composer update --no-interaction
  cd /data/typo3/public && echo "a" >> FIRST_INSTALL
  chown -R www-data:www-data /data
  chmod -R 775 /data
  # create FIRST_INSTALL
  echo "TYPO3 CMS installation completed."

  echo "TYPO3 CMS must be installed manually."

fi

CRONDIR="/data/cron/"

if [ -d "$CRONDIR" ]; then
  
  echo "Cron directories exist."

else

  echo "Create cron directories ..."

  mkdir -p /data/cron
  mkdir -p /data/cron/15min
  mkdir -p /data/cron/hourly
  mkdir -p /data/cron/daily
  mkdir -p /data/cron/weekly
  mkdir -p /data/cron/monthly

  echo "Cron directories created."

fi

rm -rf /etc/periodic/15min
rm -rf /etc/periodic/hourly
rm -rf /etc/periodic/daily
rm -rf /etc/periodic/weekly
rm -rf /etc/periodic/monthly

ln -s /data/cron/15min /etc/periodic/15min
ln -s /data/cron/hourly /etc/periodic/hourly
ln -s /data/cron/daily /etc/periodic/daily
ln -s /data/cron/weekly /etc/periodic/weekly
ln -s /data/cron/monthly /etc/periodic/monthly

nginx
echo "nginx has started."

chown -R www-data:www-data /data
chmod -R 775 /data

echo "Start import Github keys ..."

set -e

[ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -q -b 1024 -N '' -t rsa -f /etc/ssh/ssh_host_rsa_key
[ -f /etc/ssh/ssh_host_dsa_key ] || ssh-keygen -q -b 1024 -N '' -t dsa -f /etc/ssh/ssh_host_dsa_key
[ -f /etc/ssh/ssh_host_ecdsa_key ] || ssh-keygen -q -b 521  -N '' -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -b 1024 -N '' -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

[ -d /data/.ssh ] || mkdir /data/.ssh
[ -f /data/.ssh/authorized_keys ] || touch /data/.ssh/authorized_keys
chown www-data:www-data -R /data/.ssh
chmod go-w /data/
chmod 700 /data/.ssh
chmod 600 /data/.ssh/authorized_keys

PASS=$(pwgen -c -n -1 16)
echo "www-data:$PASS" | chpasswd

if [ -z "${GITHUB_USERNAME+xxx}" ] || [ -z "${GITHUB_USERNAME}" ]; then
  echo "WARNING: env variable \$GITHUB_USERNAME is not set. Please set it to have access to this container via SSH."
else
  for user in $(echo $GITHUB_USERNAME | tr "," "\n"); do
    echo "user: $user"
    su www-data -c "/github-keys.sh $user"
  done
fi

cp /update-typo3.sh /usr/local/bin/updatetypo3
cp /update-typo3-silent.sh /usr/local/bin/updatetypo3silent

cp /pull-app.sh /usr/local/bin/pullapp

chown -Rf nginx:nginx /var/lib/nginx

postfix start

/usr/sbin/sshd

echo "SSH has started."

/usr/sbin/crond -fS

echo "crond has started."

echo "Container is up und running."

tail -f /dev/null
#exec "$@"
#!/bin/bash
set -ex

DIR="/data/typo3"
PHP="/php"

if [ -f "$PHP" ]; then
  echo "PHP has already been configured."
else
  echo "PHP Configuration ..."
  echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini
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

if [ -d "$DIR" ]; then
  
  echo "TYPO3 CMS is already installed."
else
  echo "Downloading TYPO3 CMS ..."
  mkdir -p /data/typo3

  git clone $GITHUB_REPOSITORY /data/typo3

  echo "Installing TYPO3 CMS ..."
  chown -R www-data:www-data /data
  chmod -R 775 /data
  echo "Wait until composer update is finished!"
  cd /data/typo3 && composer update --no-interaction
  chown -R www-data:www-data /data
  chmod -R 775 /data
  echo "TYPO3 CMS installation completed."

fi

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

/usr/sbin/sshd
echo "SSH has started."

/usr/sbin/crond -fS
echo "crond has started."

tail -f /dev/null
#exec "$@"
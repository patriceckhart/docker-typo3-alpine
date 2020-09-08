#!/bin/bash

cd /data && echo "update" >> update

cd /data/typo3 && composer update --no-interaction

chown -R www-data:www-data /data/typo3

cd /data && rm -rf update
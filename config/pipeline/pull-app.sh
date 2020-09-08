#!/bin/bash

echo "Start pulling the git repository ... "

cd /data/typo3 && git reset --hard

if [ "$GITHUB_TOKEN" == "nogittoken" ]; then
	cd /data/typo3 && git pull $GITHUB_REPOSITORY
else
	cd /data/typo3 && git pull https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$GITHUB_REPOSITORY
fi

chown -R www-data:www-data /data/typo3

echo "Git repository was pulled successfully."

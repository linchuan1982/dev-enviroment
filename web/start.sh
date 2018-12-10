#!/usr/bin/env bash

CWD=`dirname $(readlink -f ${0})`
${CWD}/config.sh

chown -R www-data /mnt/log
chown -R www-data /mnt/aivideo

sudo sslocal -c /etc/shadowsocks.json -d start
sudo polipo socksParentProxy=localhost:1086 &
sudo cron 

mkdir -p /tmp/sensor_statistics
chown -R www-data /tmp/sensor_statistics/

if [ "${CLUSTER}" == "prod" ] || [ "${CLUSTER}" == "pre" ]
then
    DJANGO_SETTINGS_MODULE=aivideo.settings_prod
elif [ "${CLUSTER}" == "pre" ]
then
    DJANGO_SETTINGS_MODULE=aivideo.settings_pre
elif [ "${CLUSTER}" == "test" ]
then
    DJANGO_SETTINGS_MODULE=aivideo.settings_test
else
    DJANGO_SETTINGS_MODULE=aivideo.settings_local
fi

DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE} gunicorn aivideo.wsgi:application --name=aivideo --worker-class=gevent --workers=5 --user=www-data --group=www-data --bind=unix:/mnt/run/aivideo/gunicorn.sock --log-level=info --log-file=/mnt/log/gunicorn/gunicorn.log --timeout=300 --daemon --limit-request-line=8190

# Resolve an issue with PingPP server cert
echo "121.43.74.100   api.pingxx.com" >> /etc/hosts
# depends on priviledged=true on compose file
echo 2048 > /proc/sys/net/core/somaxconn

sudo -u www-data DJANGO_SETTINGS_MODULE=aivideo.settings_prod python manage.py collectstatic --noinput

sudo python -m maintainer/patch/apply_patch_web

/opt/logagent/bin/logagent >>/mnt/log/logagent.log 2>>/mnt/log/logagent.err &

sudo /opt/filebeat-6.3.2-linux-x86_64/filebeat -e -c /opt/filebeat-6.3.2-linux-x86_64/filebeat.yml &

nginx

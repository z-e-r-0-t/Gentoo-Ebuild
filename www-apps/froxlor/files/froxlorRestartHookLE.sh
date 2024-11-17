#!/bin/bash
if which rc-service &>/dev/null; then
    rc-service -i -s postfix restart
    rc-service -i -s dovecot restart
    rc-service -i -s proftpd restart
    rc-service -i -s pure-ftpd restart
elif which systemctl &>/dev/null; then
    systemctl is-active postfix && systemctl restart postfix
    systemctl is-active dovecot && systemctl restart dovecot
    systemctl is-active proftpd && systemctl restart proftpd
    systemctl is-active pure-ftpd && systemctl restart pure-ftpd
else
    echo 'Error: RestartHookLE: missing rc-service and systemctl to restart services'
    exit 1
fi

#!/bin/bash
rc-service -i -s postfix restart
rc-service -i -s dovecot restart
rc-service -i -s proftpd restart
rc-service -i -s pure-ftpd restart

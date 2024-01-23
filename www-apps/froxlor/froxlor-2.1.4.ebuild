# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/Froxlor/Froxlor.git"
	EGIT_CHECKOUT_DIR=${WORKDIR}/${PN}
	inherit git-r3 vcs-clean
	KEYWORDS=""
else
	RESTRICT="mirror"
	SRC_URI="https://files.froxlor.org/releases/${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

DESCRIPTION="A PHP-based webhosting-oriented control panel for servers."
HOMEPAGE="https://www.froxlor.org/"

LICENSE="GPL-2"
SLOT="0"
IUSE="+apache2 awstats bind +dovecot fcgid +fpm +goaccess lighttpd mailquota nginx pdns +postfix +proftpd pureftpd quota +ssl webalizer"

DEPEND="
	app-admin/logrotate
	app-crypt/gnupg
	>=dev-lang/php-7.4:*[bcmath,cli,ctype,curl,filter,gd,gmp,mysql,pdo,posix,session,xml,zip]
	>=sys-auth/libnss-extrausers-0.6
	virtual/cron
	virtual/mysql
	pureftpd? (
		net-ftp/pure-ftpd[mysql,ssl=]
	)
	proftpd? (
		net-ftp/proftpd[mysql,softquota,ssl=]
	)
	goaccess? (
		net-analyzer/goaccess
		app-misc/jq
	)
	awstats? (
		www-misc/awstats
	)
	webalizer? (
		app-admin/webalizer
	)
	bind? ( net-dns/bind )
	pdns? ( net-dns/pdns[mysql] )
	ssl? ( dev-libs/openssl )
	apache2? (
		www-servers/apache[ssl=]
		!fpm? (
			!fcgid? (
				dev-lang/php:*[apache2]
			)
		)
	)
	lighttpd? ( www-servers/lighttpd[php,ssl=] )
	nginx? (
		www-servers/nginx:*[http2,ssl=]
	)
	fcgid? (
		dev-lang/php:*[cgi]
		apache2? (
			www-apache/mod_fcgid
			www-servers/apache[suexec]
			acct-user/froxlor[min_uid_1000]
		)
	)
	fpm? (
		dev-lang/php:*[fpm]
		apache2? (
			www-servers/apache[suexec,apache2_modules_proxy,apache2_modules_proxy_fcgi]
		)
		nginx? (
			www-servers/nginx[nginx_modules_http_auth_basic,nginx_modules_http_fastcgi,nginx_modules_http_rewrite]
		)
	)
	dovecot? (
		acct-user/vmail
		acct-group/vmail
		>=net-mail/dovecot-2.2.0[argon2,mysql]
	)
	postfix? (
		>=mail-mta/postfix-3.8[dovecot-sasl,mysql,ssl=]
	)
	quota? (
		sys-fs/quotatool
	)
	acct-user/froxlor
	acct-group/froxlor"

RDEPEND="${DEPEND}"

REQUIRED_USE="
	^^ (
		apache2
		lighttpd
		nginx
	)
	^^ (
		awstats
		goaccess
		webalizer
	)
	fcgid? ( !fpm )
	nginx? (
		fpm
	)
	pdns? ( !bind )
	postfix? ( dovecot )
	proftpd? ( !pureftpd )"

# lets check user defined variables
FROXLOR_DOCROOT="${FROXLOR_DOCROOT:-/var/www/froxlor/}"
WWW_DEFAULT_DOCROOT="${WWW_DEFAULT_DOCROOT:-/var/www/localhost/htdocs/}"

S="${WORKDIR}/${PN}"

src_unpack() {
	if [[ ${PV} == *9999 ]] ; then
		git-r3_src_unpack
	else
		unpack ${A}
	fi
}

src_prepare() {
	if [[ ${PV} == *9999 ]] ; then
		egit_clean
	fi

	default

	einfo "Setting 'lastguid' to '10000'"
	patch_default_sql "system" "lastguid" "10000"

	einfo "Updating httpuser"
	patch_default_sql "phpfpm" "vhost_httpuser" "froxlor"
	patch_default_sql "phpfpm" "vhost_httpgroup" "froxlor"
	patch_default_sql "system" "mod_fcgid_httpuser" "froxlor"
	patch_default_sql "system" "mod_fcgid_httpgroup" "froxlor"

	# set correct webserver reload
	if use lighttpd; then
		einfo "Switching settings to fit 'lighttpd'"
		patch_default_sql "system" "apachereload_command" "/etc/init.d/lighttpd restart"
		patch_default_sql "system" "webserver" "lighttpd"
		patch_default_sql "system" "apacheconf_vhost" "/etc/lighttpd/vj/"
		patch_default_sql "system" "apacheconf_diroptions" "/etc/lighttpd/diroptions.conf"
		patch_default_sql "system" "apacheconf_htpasswddir" "/etc/lighttpd/htpasswd/"
		patch_default_sql "system" "httpuser" "lighttpd"
		patch_default_sql "system" "httpgroup" "lighttpd"
		patch_default_sql "phpfpm" "fastcgi_ipcdir" "/var/run/lighttpd/"
	elif use nginx; then
		einfo "Switching settings to fit 'nginx'"
		patch_default_sql "system" "apachereload_command" "/etc/init.d/nginx restart"
		patch_default_sql "system" "webserver" "nginx"
		patch_default_sql "system" "apacheconf_vhost" "/etc/nginx/vhosts.d/"
		patch_default_sql "system" "apacheconf_diroptions" "/etc/nginx/diroptions.conf"
		patch_default_sql "system" "apacheconf_htpasswddir" "/etc/nginx/htpasswd/"
		patch_default_sql "system" "httpuser" "nginx"
		patch_default_sql "system" "httpgroup" "nginx"
		patch_default_sql "phpfpm" "fastcgi_ipcdir" "/var/run/nginx/"
	else
		einfo "Switching settings to fit 'apache2'"
		patch_default_sql "system" "apacheconf_vhost" "/etc/apache2/vhosts.d/"
		patch_default_sql "system" "apacheconf_diroptions" "/etc/apache2/vhosts.d/"
		patch_default_sql "system" "httpuser" "apache"
		patch_default_sql "system" "httpgroup" "apache"
	fi

	if use fcgid && ! use lighttpd && ! use nginx ; then
		einfo "Switching 'fcgid' to 'On'"
		patch_default_sql "system" "mod_fcgid" "1"

		einfo "Setting wrapper to FcgidWrapper"
		patch_default_sql "system" "mod_fcgid_wrapper" "1"
	fi

	if use fpm ; then
		einfo "Switching 'fpm' to 'On'"
		patch_default_sql "phpfpm" "enabled" "1"
	elif use fcgid; then
		einfo "Switching 'fcgid' to 'On'"
		patch_default_sql "system" "mod_fcgid" "1"
	fi

	# If Bind and pdns will not be used disable nameserver.
	if ! use bind && ! use pdns; then
		einfo "Disabling nameserver"
		patch_default_sql "system" "bind_enable" "0"
		patch_default_sql "system" "bindreload_command" "/bin/true"
	fi

	if use bind ; then
		einfo "Setting bind9 reload command"
		patch_default_sql "system" "bind_enable" "1"
		patch_default_sql "system" "bindreload_command" "/etc/init.d/named reload"
	fi

	if use pdns ; then
		einfo "Switching from 'bind' to 'powerdns'"
		patch_default_sql "system" "bind_enable" "1"
		patch_default_sql "system" "bindconf_directory" "/etc/powerdns/"
		patch_default_sql "system" "bindreload_command" "/etc/init.d/pdns restart"
		patch_default_sql "system" "dns_server" "PowerDNS"
		"${FILESDIR}/updateConfig.py" lib/configfiles/gentoo.xml \
			"./distribution/defaults/default[@settinggroup='system'][@varname='bindreload_command']" value \
			"/etc/init.d/pdns restart" || die "Unable to enable webalizer"

		ewarn ""
		ewarn "Note that you need to configure pdns and create a separate database for it, see:"
		ewarn "https://doc.powerdns.com/authoritative/backends/generic-mysql.html"
		ewarn ""
	fi

	# default value is mailquota='0'
	if use mailquota ; then
		einfo "Switching 'mailquota' to 'On'"
		patch_default_sql "system" "mail_quota_enabled" "1"
	fi

	if use quota ; then
		einfo "Switching 'system_diskquota_enabled' to 'On'"
		patch_default_sql "system" "diskquota_enabled" "1"
		DQ_C_PART=$(df /var/ | tail -n 1 | cut -d ' ' -f1)
		patch_default_sql "system" "diskquota_customer_partition" "${DQ_C_PART}"
		patch_default_sql "system" "diskquota_quotatool_path" "/usr/sbin/quotatool"

		ewarn ""
		ewarn "You enabled quota support"
		ewarn "Remember to setup quota support for Gentoo manually (Kernel + Filesystem)"
		ewarn "More Info: https://wiki.gentoo.org/wiki/Disk_quotas"
		ewarn ""
	fi

	# default value is ssl_enabled='1'
	if ! use ssl ; then
		einfo "Switching 'SSL' to 'Off'"
		patch_default_sql "system" "use_ssl" "0"
	fi

	if use awstats ; then
		einfo "Enable awstats"
		patch_default_sql "system" "awstats_icons" "/usr/share/awstats/wwwroot/icon/"
		"${FILESDIR}/updateConfig.py" lib/configfiles/gentoo.xml \
			"./distribution/defaults/default[@settinggroup='system'][@varname='traffictool']" value awstats \
			|| die "Unable to enable awstats"
	fi

	if use goaccess ; then
		einfo "Enable goaccess"
		"${FILESDIR}/updateConfig.py" lib/configfiles/gentoo.xml \
			"./distribution/defaults/default[@settinggroup='system'][@varname='traffictool']" value goaccess \
			|| die "Unable to enable goaccess"
	fi

	if use webalizer ; then
		einfo "Enable webalizer"
		patch_default_sql "system" "webalizer_quiet" "0"
		"${FILESDIR}/updateConfig.py" lib/configfiles/gentoo.xml \
			"./distribution/defaults/default[@settinggroup='system'][@varname='traffictool']" value webalizer \
			|| die "Unable to enable webalizer"
	fi

	if use pureftpd ; then
		einfo "Switching from 'ProFTPd' to 'Pure-FTPd'"
		patch_default_sql "system" "ftpserver" "pureftpd"
	fi

	if use dovecot || use postfix; then
		VMAIL_UID=$(id -u vmail)
		einfo "Setting system.vmail_uid to ${VMAIL_UID}"
		patch_default_sql "system" "vmail_uid" "${VMAIL_UID}"

		VMAIL_GID=$(id -u vmail)
		einfo "Setting system.vmail_gid to ${VMAIL_GID}"
		patch_default_sql "system" "vmail_gid" "${VMAIL_GID}"
	fi
}

src_install() {
	insinto "${FROXLOR_DOCROOT}"
	doins -r .

	fperms 0755 "${FROXLOR_DOCROOT}/bin/froxlor-cli"

	# Create symbolic link to froxlor docroot
	if [[ -d "${WWW_DEFAULT_DOCROOT}" ]]; then
		FROXLOR_APACHE_LINK="${WWW_DEFAULT_DOCROOT}froxlor"
		dosym -r "${ROOT}${FROXLOR_DOCROOT}" "${FROXLOR_APACHE_LINK}"
	else
		ewarn "Unable to find existing www default htdocs root. Please manually adjust your docroot if necessary."
	fi

	if use apache2; then
		# Ensure dir is writable by apache
		fowners -R apache:apache "${FROXLOR_DOCROOT}"

		insinto /etc/apache2/modules.d/
		newins "${FILESDIR}/apache_modules.d_00_default_settings.conf" 00_default_settings.conf

		if use fpm ; then
			insinto /etc/apache2/modules.d/
			newins "${FILESDIR}/apache_fpm_modules.d_70_mod_php.conf" 70_mod_php.conf

			newconfd "${FILESDIR}/apache_fpm_conf.d_apache2" apache2

			# overwrite default www.conf if present
			FPM_DIR="/etc/php/fpm-$(eselect php show fpm)/fpm.d/"
			if [ -f "$FPM_DIR/www.conf" ]; then
				insinto "$FPM_DIR"
				newins "${FILESDIR}/php_fpm_www_apache.conf" www.conf
			fi
		elif use fcgid; then
			insinto /etc/apache2/modules.d/
			newins "${FILESDIR}/apache_fcgid_modules.d_20_mod_fcgid.conf" 20_mod_fcgid.conf

			newconfd "${FILESDIR}/apache_fcgid_conf.d_apache2" apache2

			dosym /usr/bin/php-cgi /var/www/localhost/htdocs/fcgid-bin/php-fcgid-wrapper
		else
			# mod_php
			newconfd "${FILESDIR}/apache_mod_php_conf.d_apache2" apache2
		fi
	elif use nginx; then
		# Ensure dir is writable by nginx
		fowners -R nginx:nginx "${FROXLOR_DOCROOT}"
		if use fpm ; then
			insinto /etc/nginx/
			newins "${FILESDIR}/nginx_nginx.conf" nginx.conf

			# overwrite default www.conf if present
			FPM_DIR="/etc/php/fpm-$(eselect php show fpm)/fpm.d/"
			if [ -f "$FPM_DIR/www.conf" ]; then
				insinto "$FPM_DIR"
				newins "${FILESDIR}/php_fpm_www_nginx.conf" www.conf
			fi
		fi
	fi
}

pkg_postinst() {
	if use fpm && use apache2; then
		# we need this in order to apache being able to access fpm socket
		usermod -a -G froxlor apache
	fi

	# we need to check if this is going to be an update or a fresh install!
	if [[ -f "${ROOT}${FROXLOR_DOCROOT}/lib/userdata.inc.php" ]] ; then
		elog "Froxlor is already installed on this system!"
		elog
		elog "Froxlor will update the database when you open"
		elog "it in your browser the first time after the update-process."
	else
		elog "Don't forget to setup your MySQL databases root user and password"
		elog "using \"emerge --config mysql\" or \"emerge --config mariadb\"."
		elog
		elog "Don't forget to apply possible config changes, e.g. using \"dispatch-conf\""
		elog
		elog "Don't forget to restart services after config change, e.g. \"/etc/init.d/... restart\""
		elog
		elog "Please open http://[ip]/froxlor in your browser to continue"
		elog "with the basic setup of Froxlor."
	fi
}

patch_default_sql() {
	KEY="'$1', '$2', "
	KEY_PRETTY="$1.$2"
	NEW_VALUE="$3"
	SQL_FILE="${S}/install/froxlor.sql.php"
	OLD_VALUE="'[^']*'"
	SEARCH="(\(${KEY})${OLD_VALUE}(\),?)\$"

	grep -E "${SEARCH}" "${SQL_FILE}" &>/dev/null || die "Unable to find key: ${KEY_PRETTY}"
	sed -E -e "s|${SEARCH}|\1'${NEW_VALUE}'\2|g" -i "${SQL_FILE}" || die "Unable to patch key: ${KEY_PRETTY}"
}

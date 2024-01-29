# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"

DESCRIPTION="A PHP-based webhosting-oriented control panel for servers."
HOMEPAGE="https://www.froxlor.org/"

LICENSE="GPL-2"
SLOT="0"
IUSE="+apache2 awstats bind fcgid +fpm +goaccess lighttpd mailquota nginx pdns +proftpd pureftpd quota +ssl webalizer"

DEPEND="
	acct-user/froxlor
	acct-group/froxlor
	acct-user/vmail
	acct-group/vmail
	app-admin/logrotate
	app-crypt/gnupg
	>=dev-lang/php-7.4:*[bcmath,cli,ctype,curl,filter,gd,gmp,mysql,pdo,posix,session,xml,zip]
	>=net-mail/dovecot-2.2.0[argon2,mysql]
	>=mail-mta/postfix-3.8[dovecot-sasl,mysql,ssl=]
	>=sys-auth/libnss-extrausers-0.6
	sys-process/cronie
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
	quota? (
		sys-fs/quotatool
	)
	"

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
	proftpd? ( !pureftpd )"

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/Froxlor/Froxlor.git"
	EGIT_CHECKOUT_DIR=${WORKDIR}/${PN}
	inherit git-r3 vcs-clean
	KEYWORDS=""
	BDEPEND="${BDEPEND}
		dev-php/composer
		dev-php/pecl-gnupg
		net-libs/nodejs"
else
	RESTRICT="mirror"
	SRC_URI="https://github.com/Froxlor/Froxlor/releases/download/${PV}/${P}.tar.gz https://files.froxlor.org/releases/${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

# lets check user defined variables
FROXLOR_DOCROOT="${FROXLOR_DOCROOT:-/var/www/froxlor/}"

S="${WORKDIR}/${PN}"

src_unpack() {
	if [[ ${PV} == *9999 ]] ; then
		git-r3_src_unpack
		pushd "${S}" > /dev/null || die
		composer install --no-dev || die
		npm install || die
		npm run build || die
		popd > /dev/null || die
	else
		unpack "${A}"
	fi
}

src_prepare() {
	if [[ ${PV} == *9999 ]] ; then
		egit_clean
	fi

	default

	CUSTOM_GENTOO_XML_PATH="${FILESDIR}/gentoo-v${PV}.xml"
	SRC_GENTOO_XML_PATH="lib/configfiles/gentoo.xml"
	if [ -f "${CUSTOM_GENTOO_XML_PATH}" ]; then
		einfo "Using custom .xml: ${CUSTOM_GENTOO_XML_PATH}"
		cp "${CUSTOM_GENTOO_XML_PATH}" "${SRC_GENTOO_XML_PATH}" || die "Failed to copy xml"
	fi

	CUSTOM_PATCHES_PATH="${FILESDIR}/*-v${PV}.patch"
	for PATCH in ${CUSTOM_PATCHES_PATH}; do
		[ -e "$PATCH" ] || continue
		eapply "${PATCH}"
	done

	einfo "Setting 'lastguid' to '10000'"
	patch_defaults "system" "lastguid" "10000"

	einfo "Updating httpuser"
	patch_defaults "phpfpm" "vhost_httpuser" "froxlor"
	patch_defaults "phpfpm" "vhost_httpgroup" "froxlor"
	patch_defaults "system" "mod_fcgid_httpuser" "froxlor"
	patch_defaults "system" "mod_fcgid_httpgroup" "froxlor"

	# set correct webserver reload
	if use lighttpd; then
		einfo "Switching settings to fit 'lighttpd'"
		patch_defaults "system" "apachereload_command" "$(get_restart_command lighttpd restart)"
		patch_defaults "system" "webserver" "lighttpd"
		patch_defaults "system" "apacheconf_vhost" "/etc/lighttpd/vj/"
		patch_defaults "system" "apacheconf_diroptions" "/etc/lighttpd/diroptions.conf"
		patch_defaults "system" "apacheconf_htpasswddir" "/etc/lighttpd/htpasswd/"
		patch_defaults "system" "httpuser" "lighttpd"
		patch_defaults "system" "httpgroup" "lighttpd"
		patch_defaults "phpfpm" "fastcgi_ipcdir" "/var/run/lighttpd/"
	elif use nginx; then
		einfo "Switching settings to fit 'nginx'"
		patch_defaults "system" "apachereload_command" "$(get_restart_command nginx restart)"
		patch_defaults "system" "webserver" "nginx"
		patch_defaults "system" "apacheconf_vhost" "/etc/nginx/vhosts.d/"
		patch_defaults "system" "apacheconf_diroptions" "/etc/nginx/diroptions.conf"
		patch_defaults "system" "apacheconf_htpasswddir" "/etc/nginx/htpasswd/"
		patch_defaults "system" "httpuser" "nginx"
		patch_defaults "system" "httpgroup" "nginx"
		patch_defaults "phpfpm" "fastcgi_ipcdir" "/var/run/nginx/"
	else
		einfo "Switching settings to fit 'apache2'"
		patch_defaults "system" "apachereload_command" "$(get_restart_command apache2 reload)"
		patch_defaults "system" "apacheconf_vhost" "/etc/apache2/vhosts.d/"
		patch_defaults "system" "apacheconf_diroptions" "/etc/apache2/vhosts.d/"
		patch_defaults "system" "httpuser" "apache"
		patch_defaults "system" "httpgroup" "apache"
	fi

	if use fpm ; then
		einfo "Switching 'fpm' to 'On'"
		patch_defaults "phpfpm" "enabled" "1"
	elif use fcgid and use apache2; then
		einfo "Adjusting settings for apache2 with fcgid"
		patch_defaults "system" "mod_fcgid" "1"
		patch_defaults "system" "mod_fcgid_wrapper" "1"
	fi

	# If Bind and pdns will not be used disable nameserver.
	if ! use bind && ! use pdns; then
		einfo "Disabling nameserver"
		patch_defaults "system" "bind_enable" "0"
		patch_defaults "system" "bindreload_command" "/bin/true"
	fi

	if use bind ; then
		einfo "Setting bind9 reload command"
		patch_defaults "system" "bind_enable" "1"
		patch_defaults "system" "bindreload_command" "$(get_restart_command named reload)"
	fi

	if use pdns ; then
		einfo "Switching from 'bind' to 'powerdns'"
		patch_defaults "system" "bind_enable" "1"
		patch_defaults "system" "bindconf_directory" "/etc/powerdns/"
		patch_defaults "system" "bindreload_command" "$(get_restart_command pdns restart)"
		patch_defaults "system" "dns_server" "PowerDNS"
		patch_defaults "system" "bindreload_command" "$(get_restart_command pdns restart)"

		ewarn ""
		ewarn "Note that you need to configure pdns and create a separate database for it. More details:"
		ewarn "https://doc.powerdns.com/authoritative/backends/generic-mysql.html"
		ewarn ""
	fi

	if use mailquota ; then
		einfo "Switching 'mailquota' to 'On'"
		patch_defaults "system" "mail_quota_enabled" "1"
	fi

	if use quota ; then
		einfo "Switching 'system_diskquota_enabled' to 'On'"
		patch_defaults "system" "diskquota_enabled" "1"
		DQ_C_PART=$(df /var/ | tail -n 1 | cut -d ' ' -f1)
		patch_defaults "system" "diskquota_customer_partition" "${DQ_C_PART}"
		patch_defaults "system" "diskquota_quotatool_path" "/usr/sbin/quotatool"

		ewarn ""
		ewarn "You enabled quota support"
		ewarn "Remember to setup quota support for Gentoo manually (Kernel + Filesystem)"
		ewarn "More Info: https://wiki.gentoo.org/wiki/Disk_quotas"
		ewarn ""
	fi

	# default value is ssl_enabled='1'
	if ! use ssl ; then
		einfo "Switching 'SSL' to 'Off'"
		patch_defaults "system" "use_ssl" "0"
	fi

	if use awstats ; then
		einfo "Enable awstats"
		patch_defaults "system" "awstats_icons" "/usr/share/awstats/wwwroot/icon/"
		patch_defaults "system" "traffictool" "awstats"
	fi

	if use goaccess ; then
		einfo "Enable goaccess"
		patch_defaults "system" "traffictool" "goaccess"
	fi

	if use webalizer ; then
		einfo "Enable webalizer"
		patch_defaults "system" "webalizer_quiet" "0"
		patch_defaults "system" "traffictool" "webalizer"
	fi

	if use pureftpd ; then
		einfo "Switching from 'ProFTPd' to 'Pure-FTPd'"
		patch_defaults "system" "ftpserver" "pureftpd"
	fi

	VMAIL_UID=$(id -u vmail)
	patch_defaults "system" "vmail_uid" "${VMAIL_UID}"
	VMAIL_GID=$(id -u vmail)
	patch_defaults "system" "vmail_gid" "${VMAIL_GID}"

	patch_defaults "system" "crondreload" "$(get_restart_command cronie restart)"

	if is_systemd; then
		einfo "Patching service restart for systemd"
		sed -i 's/\/etc\/init\.d\/\([^ ]\+\) \(restart\|reload\)/systemctl \2 \1.service/g' "${SRC_GENTOO_XML_PATH}" \
			|| die "Unable to patch init.d for systemd"
	fi

	if use fpm; then
		einfo "Patching web installer for PHP FPM"
		PHP_FPM_VERSION=$(eselect php show fpm | grep -Eo '[0-9\.]+')
		if is_systemd; then
			sed -i "s/^\([[:space:]]\+\$reload = \).*/\1\"$(get_restart_command php-fpm@"${PHP_FPM_VERSION}" restart)\";/g" \
				"${S}/lib/Froxlor/Install/Install/Core.php" || die "Unable to patch installer php-fpm systemd"
		else
			sed -i "s/^\([[:space:]]\+\$reload = \).*/\1\"$(get_restart_command php-fpm restart | sed -e 's/\//\\\//g')\";/g" \
				"${S}/lib/Froxlor/Install/Install/Core.php" || die "Unable to patch installer php-fpm openrc"
		fi
		sed -i "s/^\([[:space:]]\+\$config_dir = \).*/\1\"\/etc\/php\/fpm-php${PHP_FPM_VERSION}\/fpm.d\/\";/g" \
			"${S}/lib/Froxlor/Install/Install/Core.php" || die "Unable to patch installer php-fpm dir"
	elif use fcgid; then
		einfo "Patch web installer for PHP fcgid"
		PHP_CGI_VERSION=$(eselect php show cgi | grep -Eo '[0-9\.]+')
		sed -i "s/^\([[:space:]]\+\$binary = \).*/\1\"\/usr\/bin\/php-cgi${PHP_CGI_VERSION}\";/g" \
			"${S}/lib/Froxlor/Install/Install/Core.php" || die "Unable to patch installer php-cgi path"
	fi
}

src_install() {
	insinto "${FROXLOR_DOCROOT}"
	doins -r .

	fperms 0755 "${FROXLOR_DOCROOT}/bin/froxlor-cli"

	if use apache2; then
		WWW_DEFAULT_DOCROOT="/var/www/localhost/htdocs/"
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
		WWW_DEFAULT_DOCROOT="/var/www/localhost/"
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

	# Create symbolic link to froxlor docroot
	if [[ -n ${WWW_DEFAULT_DOCROOT} && -d "${WWW_DEFAULT_DOCROOT}" ]]; then
		FROXLOR_LINK="${WWW_DEFAULT_DOCROOT}froxlor"
		dosym -r "${ROOT}${FROXLOR_DOCROOT}" "${FROXLOR_LINK}"
	else
		ewarn ""
		ewarn "Unable to find existing www default htdocs root. Please manually adjust your docroot if necessary."
		ewarn ""
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
		elog "using \"emerge --config mariadb\" or \"emerge --config mysql\"."
		elog
		elog "Don't forget to apply possible config changes, e.g. using \"dispatch-conf\""
		elog
		elog "Don't forget to start/restart services after config change, e.g. \"$(get_restart_command XXX restart)\""
		elog "in order to be able to access the web installer."
		elog
		elog "Please open http://[ip]/froxlor in your browser to continue with web installer"
		elog "and basic setup of Froxlor."
	fi
}

patch_defaults() {
	einfo "Updating default '$1:$2' to '$3'"
	"${FILESDIR}/updateDefaults.py" "lib/configfiles/gentoo.xml" \
			"$1" "$2" "$3" || die "Unable to updateDefaults: $1, $2, $3"
}

get_restart_command() {
	service="$1"
	action="$2"
	if is_systemd; then
		echo "systemctl ${action} ${service}.service"
	else
		echo "/etc/init.d/${service} ${action}"
	fi
}

is_systemd() {
	if which systemctl &>/dev/null; then
		return 0;
	else
		return 1;
	fi;
}

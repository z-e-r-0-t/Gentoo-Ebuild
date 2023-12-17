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
IUSE="awstats goaccess webalizer +apache2 bind +dovecot fcgid fpm ftpquota lighttpd +log mailquota nginx pdns +postfix +proftpd pureftpd quota ssl"

DEPEND="
	virtual/mysql
	virtual/cron
	>=dev-lang/php-7.4:*[bcmath,cli,ctype,curl,filter,gd,gmp,mysql,pdo,posix,session,xml,zip]
	pureftpd? (
		net-ftp/pure-ftpd[mysql,ssl=]
	)
	proftpd? (
		net-ftp/proftpd[mysql,ssl=]
		ftpquota? ( net-ftp/proftpd[softquota] )
	)
	goaccess? (
		net-analyzer/goaccess
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
			dev-lang/php:*[apache2]
			)
	)
	lighttpd? ( www-servers/lighttpd[php,ssl=] )
	nginx? (
		www-servers/nginx:*[ssl=]
	)
	fcgid? (
		dev-lang/php:*[cgi]
		||
			(
				sys-auth/libnss-extrausers
				sys-auth/libnss-mysql
			)
			(
				apache2? (
					www-servers/apache[apache2_modules_proxy_fcgi]
				)
			)
	)
	fpm? (
		dev-lang/php:*[fpm]
		||
			(
				sys-auth/libnss-extrausers
				sys-auth/libnss-mysql
			)
			(
				apache2? (
					www-servers/apache[apache2_modules_proxy_fcgi]
				)
			)
	)
	dovecot? (
		>=net-mail/dovecot-2.2.0[mysql]
	)
	postfix? (
		>=mail-mta/postfix-2.4[dovecot-sasl,mysql,ssl=]
	)
	log? (
		app-admin/logrotate
	)
	quota? (
		sys-fs/quotatool
	)"

RDEPEND="${DEPEND}"

REQUIRED_USE="
	^^ (
		apache2
		lighttpd
		nginx
	)
	fcgid? ( !fpm )
	pdns? ( !bind )
	postfix? ( dovecot )"

# lets check user defined variables
FROXLOR_DOCROOT="${FROXLOR_DOCROOT:-/var/www/froxlor/}"
APACHE_DEFAULT_DOCROOT="${APACHE_DEFAULT_DOCROOT:-/var/www/localhost/htdocs/}"

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
	sed -e "s|'lastguid', '9999'|'lastguid', '10000'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change lastguid"

	# Change all service reload commands from service to rc-service.
	sed -e "s|service '|rc-service |g" -i "${S}/install/froxlor.sql.php" || die "Unable to change service reload commands."

	# set correct webserver reload
	if use lighttpd; then
		einfo "Switching settings to fit 'lighttpd'"
		sed -e "s|/etc/init.d/apache2 reload|/etc/init.d/lighttpd restart|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver restart-command"
		sed -e "s|'webserver', 'apache2'|'webserver', 'lighttpd'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver version"
		sed -e "s|'apacheconf_vhost', '/etc/apache2/sites-enabled/'|'apacheconf_vhost', '/etc/lighttpd/vj/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver vhost directory"
		sed -e "s|'apacheconf_diroptions', '/etc/apache2/sites-enabled/'|'apacheconf_diroptions', '/etc/lighttpd/diroptions.conf'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver diroptions file"
		sed -e "s|'apacheconf_htpasswddir', '/etc/apache2/htpasswd/'|'apacheconf_htpasswddir', '/etc/lighttpd/htpasswd/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver htpasswd directory"
		sed -e "s|'httpuser', 'www-data'|'httpuser', 'lighttpd'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver user"
		sed -e "s|'httpgroup', 'www-data'|'httpgroup', 'lighttpd'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver group"
		sed -e "s|'fastcgi_ipcdir', '/var/lib/apache2/fastcgi/'|'fastcgi_ipcdir', '/var/run/lighttpd/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change php-ipc directory"
	elif use nginx; then
		einfo "Switching settings to fit 'nginx'"
		sed -e "s|/etc/init.d/apache2 reload|/etc/init.d/nginx restart|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver restart-command"
		sed -e "s|'webserver', 'apache2'|'webserver', 'nginx'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver version"
		sed -e "s|'apacheconf_vhost', '/etc/apache2/sites-enabled/'|'apacheconf_vhost', '/etc/nginx/vhosts.d/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver vhost directory"
		sed -e "s|'apacheconf_diroptions', '/etc/apache2/sites-enabled/'|'apacheconf_diroptions', '/etc/nginx/diroptions.conf'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver diroptions file"
		sed -e "s|'apacheconf_htpasswddir', '/etc/apache2/htpasswd/'|'apacheconf_htpasswddir', '/etc/nginx/htpasswd/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver htpasswd directory"
		sed -e "s|'httpuser', 'www-data'|'httpuser', 'nginx'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver user"
		sed -e "s|'httpgroup', 'www-data'|'httpgroup', 'nginx'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver group"
		sed -e "s|'fastcgi_ipcdir', '/var/lib/apache2/fastcgi/'|'fastcgi_ipcdir', '/var/run/nginx/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change php-ipc directory"
	else
		einfo "Switching settings to fit 'apache2'"
		sed -e "s|'apacheconf_vhost', '/etc/apache2/sites-enabled/'|'apacheconf_vhost', '/etc/apache2/vhosts.d/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver vhost directory"
		sed -e "s|'apacheconf_diroptions', '/etc/apache2/sites-enabled/'|'apacheconf_diroptions', '/etc/apache2/vhosts.d/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver diroptions file"
		sed -e "s|'httpuser', 'www-data'|'httpuser', 'apache'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver user"
		sed -e "s|'httpgroup', 'www-data'|'httpgroup', 'apache'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to change webserver group"
	fi

	if use fcgid && ! use lighttpd && ! use nginx ; then
		einfo "Switching 'fcgid' to 'On'"
		sed -e "s|'mod_fcgid', '0'|'mod_fcgid', '1'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to set fcgid to 'On'"

		einfo "Setting wrapper to FcgidWrapper"
		sed -e "s|'mod_fcgid_wrapper', '0'|'mod_fcgid_wrapper', '1'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to set fcgi-wrapper to 'FCGIWrapper'"
	fi

	if use fpm ; then
		einfo "Switching 'fpm' to 'On'"
		sed -e "s|'phpfpm', 'enabled', '0'|'phpfpm', 'enabled', '1'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to set fpm to 'On'"

		# Hw to get version of required/installed php package?
		# einfo "Setting configdir for fpm"
		# sed -e "s|'phpfpm', 'configdir', '/etc/php-fpm.d/'|'phpfpm', 'configdir', '/etc/php/fpm-php5.3/fpm.d/'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to set configdir for 'fpm'"

	fi

	# If Bind and pdns will not be used disable nameserver.
	if ! use bind && ! use pdns; then
		einfo "Disabling nameserver"
		sed -e 's|'bind_enable', '1'|'bind_enable', '0'|g' -i "${S}/install/froxlor.sql.php" || die "Unable to change binds enabled flag"
		sed -e 's|/etc/init.d/bind9 reload|/bin/true|g' -i "${S}/install/froxlor.sql.php" || die "Unable to change reload path for Bind"
	fi

	if use bind ; then
		einfo "Setting bind9 reload command"
		sed -e 's|'bind_enable', '0'|'bind_enable', '1'|g' -i "${S}/install/froxlor.sql.php" || die "Unable to change binds enabled flag"
		sed -e 's|/etc/init.d/bind9 reload|/etc/init.d/named reload|g' -i "${S}/install/froxlor.sql.php" || die "Unable to change reload path for Bind"
	fi

	if use pdns ; then
		einfo "Switching from 'bind' to 'powerdns'"
		sed -e 's|'bind_enable', '0'|'bind_enable', '1'|g' -i "${S}/install/froxlor.sql.php" || die "Unable to change binds enabled flag"
		sed -e 's|/etc/init.d/bind9 reload|/etc/init.d/pdns restart|g' -i "${S}/install/froxlor.sql.php" || die "Unable to change reload path for pdns"
		sed -e 's|'dns_server', 'bind'|'dns_server', 'pdns'|g' -i "${S}/install/froxlor.sql.php" || die "Unable to change dns-server value from bind to pdns"
		ewarn ""
		ewarn "Note that you need to configure pdns and create a separate database for it, see:"
		ewarn "https://doc.powerdns.com/3/authoritative/installation/#basic-setup-configuring-database-connectivity"
		ewarn ""
	fi

	# default value is logging_enabled='1'
	if ! use log ; then
		einfo "Switching 'log' to 'Off'"
		sed -e "s|'logger', 'enabled', '1'|'logger', 'enabled', '0'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to set logging to 'Off'"
	fi

	# default value is mailquota='0'
	if use mailquota ; then
		einfo "Switching 'mailquota' to 'On'"
		sed -e "s|'mail_quota_enabled', '0'|'mail_quota_enabled', '1'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to set mailquota to 'On'"
	fi

	# default value is ssl_enabled='1'
	if ! use ssl ; then
		einfo "Switching 'SSL' to 'Off'"
		sed -e "s|'use_ssl','1'|'use_ssl','0'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to set ssl to 'Off'"
	fi

	if use awstats ; then
		einfo "Switching from 'Webalizer' to 'AWStats'"
		sed -e "s|'webalizer_quiet', '2'|'webalizer_quiet', '0'|g" -i "${S}/install/froxlor.sql.php"
		sed -e "s|'awstats_enabled', '0'|'awstats_enabled', '1'|g" -i "${S}/install/froxlor.sql.php" || die "Unable to enable AWStats"
	fi

	if use pureftpd ; then
		einfo "Switching from 'ProFTPd' to 'Pure-FTPd'"
		sed -e "s|'ftpserver', 'proftpd'|'ftpserver', 'pureftpd'|g" -i "${S}/install/froxlor.sql.php"
	fi
}

src_install() {
	insinto "${FROXLOR_DOCROOT}"
	doins -r .

	fperms 0755 "${FROXLOR_DOCROOT}/bin/froxlor-cli"

	if use apache2; then
		# Ensure dir is writable by apache
		fowners -R apache:apache "${FROXLOR_DOCROOT}"

		# Create symbolic link to froxlor docroot
		if [[ -d "${APACHE_DEFAULT_DOCROOT}" ]]; then
			FROXLOR_APACHE_LINK="${APACHE_DEFAULT_DOCROOT}froxlor"
			dosym -r "${ROOT}${FROXLOR_DOCROOT}" "${FROXLOR_APACHE_LINK}" || ewarn "Unable to create symlink in htdocs root. Please manually adjust your docroot if necessary."
		else
			ewarn "Unable to find existing apache default htdocs root. Please manually adjust your docroot if necessary."
		fi
	fi
}

pkg_postinst() {
	# we need to check if this is going to be an update or a fresh install!
	if [[ -f "${ROOT}${FROXLOR_DOCROOT}/lib/userdata.inc.php" ]] ; then
		elog "Froxlor is already installed on this system!"
		elog
		elog "Froxlor will update the database when you open"
		elog "it in your browser the first time after the update-process"
	else
		if use apache2; then
			if ! use fpm && ! use fcgid ; then
				elog "Don't forget to enable mod_php in /etc/conf.d/apache2 by adding \" -D PHP\" to APACHE2_OPTS var."
				elog
			fi
		fi
		elog "Don't forget to setup your MySQL databases root user and password"
		elog "using \"emerge --config mysql\" or \"emerge --config mariadb\""
		elog
		elog "Please open http://[ip]/froxlor in your browser to continue"
		elog "with the basic setup of Froxlor."
	fi
}

# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI="5"

inherit eutils

if [[ ${PV} = "9999" ]] ; then
	EGIT_REPO_URI="https://github.com/Froxlor/Froxlor.git"
	EGIT_CHECKOUT_DIR=${WORKDIR}/${PN}
	inherit git-r3
	KEYWORDS=""
else
	RESTRICT="mirror"
	SRC_URI="http://files.froxlor.org/releases/${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

DESCRIPTION="A PHP-based webhosting-oriented control panel for servers."
HOMEPAGE="http://www.froxlor.org/"

LICENSE="GPL-2"
SLOT="0"
IUSE="awstats bind domainkey +dovecot fcgid ftpquota fpm libressl lighttpd +log mailquota nginx pureftpd quota ssl +tickets vsftpd"

DEPEND="
	!www-apps/syscp
	>=mail-mta/postfix-2.4[mysql,ssl=]
	virtual/cron
	virtual/mysql
	>=dev-lang/php-5.3:*[bcmath,cli,ctype,filter,ftp,gd,mysql,nls,pcntl,pdo,posix,session,simplexml,ssl=,tokenizer,unicode,xml,xslt,zlib]
	pureftpd? (
		net-ftp/pure-ftpd[mysql,ssl=]
	)
	vsftpd? (
		net-ftp/vsftpd[pam,ssl=]
		sys-auth/pam_mysql
	)
	!pureftpd? (
		( !vsftpd? (
			net-ftp/proftpd[mysql,ssl=]
			ftpquota? ( net-ftp/proftpd[softquota] )
			)
		)
	)
	awstats? (
		www-misc/awstats
	)
	!awstats? (
		app-admin/webalizer
	)
	bind? ( net-dns/bind
		domainkey? ( mail-filter/opendkim )
	)
	ssl? (
		!libressl? ( >=dev-libs/openssl-1.0.2:* )
		libressl? ( dev-libs/libressl:= )
	)
	lighttpd? ( www-servers/lighttpd[php,ssl=] )
	nginx? (
		www-servers/nginx:*[ssl=]
	)
	!lighttpd? (
		( !nginx? (
			www-servers/apache[ssl=]
			!fpm? (
				dev-lang/php:*[apache2]
				)
			)
		)
	)
	fcgid? ( dev-lang/php:*[cgi]
		 sys-auth/libnss-mysql
			( !lighttpd? (
				!nginx? (
					www-servers/apache[suexec]
					www-apache/mod_fcgid
					)
				)
			)
	)
	fpm? ( dev-lang/php:*[fpm]
		sys-auth/libnss-mysql
	)
	dovecot? ( >=net-mail/dovecot-2.2.0[mysql,ssl=]
		   >=mail-mta/postfix-2.4[dovecot-sasl]
	)
	!dovecot? ( dev-libs/cyrus-sasl[mysql,ssl=]
		    net-libs/courier-authlib[crypt,mysql]
		    net-mail/courier-imap
		    >=mail-mta/postfix-2.4[sasl]
	)
	mailquota? ( >=mail-mta/postfix-2.4[vda] )
	quota? ( sys-fs/quotatool )"

RDEPEND="${DEPEND}"

REQUIRED_USE="lighttpd? ( !nginx ) fcgid? ( !fpm ) vsftpd? ( !ftpquota )"

# we need that to set the standardlanguage later
LANGS="de en fr it nl pt se"
for X in ${LANGS} ; do
	IUSE="${IUSE} linguas_${X}"
done

# lets check user defined variables
FROXLOR_DOCROOT="${FROXLOR_DOCROOT:-/var/www}"

S="${WORKDIR}/${PN}"

src_unpack() {
	if [[ ${PV} == "9999" ]] ; then
		git-r3_src_unpack
	else
		unpack ${A}
	fi
}

src_prepare() {
	epatch_user
}

src_install() {
	# set default language
	local MYLANG=""
	if use linguas_de ; then
		MYLANG="Deutsch"
	elif use linguas_fr ; then
		MYLANG="Fran&ccedil;ais"
	elif use linguas_it ; then
		MYLANG="Italian"
	elif use linguas_nl ; then
		MYLANG="Dutch"
	elif use linguas_pt ; then
		MYLANG="Portugu&ecirc;s"
	elif use linguas_se ; then
		MYLANG="Swedish"
	fi

	if [[ ${MYLANG} != '' ]] ; then
		einfo "Setting standardlanguage to '${MYLANG}'"
		sed -e "s|'standardlanguage', 'English'|'standardlanguage', '${MYLANG}'|g" -i "${S}/install/froxlor.sql" || die "Unable to change default language"
	fi

	einfo "Setting 'lastguid' to '10000'"
	sed -e "s|'lastguid', '9999'|'lastguid', '10000'|g" -i "${S}/install/froxlor.sql" || die "Unable to change lastguid"

	# set correct webserver reload
	if use lighttpd; then
		einfo "Switching settings to fit 'lighttpd'"
		sed -e "s|/etc/init.d/apache2 reload|/etc/init.d/lighttpd restart|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver restart-command"
		sed -e "s|'webserver', 'apache2'|'webserver', 'lighttpd'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver version"
		sed -e "s|'apacheconf_vhost', '/etc/apache2/vhosts.conf'|'apacheconf_vhost', '/etc/lighttpd/froxlor-vhosts.conf'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver vhost directory"
		sed -e "s|'apacheconf_diroptions', '/etc/apache2/diroptions.conf'|'apacheconf_diroptions', '/etc/lighttpd/diroptions.conf'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver diroptions file"
		sed -e "s|'apacheconf_htpasswddir', '/etc/apache2/htpasswd/'|'apacheconf_htpasswddir', '/etc/lighttpd/htpasswd/'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver htpasswd directory"
		sed -e "s|'httpuser', 'www-data'|'httpuser', 'lighttpd'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver user"
		sed -e "s|'httpgroup', 'www-data'|'httpgroup', 'lighttpd'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver group"
		sed -e "s|'fastcgi_ipcdir', '/var/lib/apache2/fastcgi/'|'fastcgi_ipcdir', '/var/run/lighttpd/'|g" -i "${S}/install/froxlor.sql" || die "Unable to change php-ipc directory"
	elif use nginx; then
		einfo "Switching settings to fit 'nginx'"
		sed -e "s|/etc/init.d/apache2 reload|/etc/init.d/nginx restart|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver restart-command"
		sed -e "s|'webserver', 'apache2'|'webserver', 'nginx'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver version"
		sed -e "s|'apacheconf_vhost', '/etc/apache2/vhosts.conf'|'apacheconf_vhost', '/etc/nginx/froxlor-vhosts.conf'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver vhost directory"
		sed -e "s|'apacheconf_diroptions', '/etc/apache2/diroptions.conf'|'apacheconf_diroptions', '/etc/nginx/diroptions.conf'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver diroptions file"
		sed -e "s|'apacheconf_htpasswddir', '/etc/apache2/htpasswd/'|'apacheconf_htpasswddir', '/etc/nginx/htpasswd/'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver htpasswd directory"
		sed -e "s|'httpuser', 'www-data'|'httpuser', 'nginx'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver user"
		sed -e "s|'httpgroup', 'www-data'|'httpgroup', 'nginx'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver group"
		sed -e "s|'fastcgi_ipcdir', '/var/lib/apache2/fastcgi/'|'fastcgi_ipcdir', '/var/run/nginx/'|g" -i "${S}/install/froxlor.sql" || die "Unable to change php-ipc directory"
	else
		einfo "Switching settings to fit 'apache2'"
		sed -e "s|'apacheconf_vhost', '/etc/apache2/vhosts.conf'|'apacheconf_vhost', '/etc/apache2/vhosts.d/'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver vhost directory"
		sed -e "s|'httpuser', 'www-data'|'httpuser', 'apache'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver user"
		sed -e "s|'httpgroup', 'www-data'|'httpgroup', 'apache'|g" -i "${S}/install/froxlor.sql" || die "Unable to change webserver group"
	fi

	if use fcgid && ! use lighttpd && ! use nginx ; then
		einfo "Switching 'fcgid' to 'On'"
		sed -e "s|'mod_fcgid', '0'|'mod_fcgid', '1'|g" -i "${S}/install/froxlor.sql" || die "Unable to set fcgid to 'On'"

		einfo "Setting wrapper to FcgidWrapper"
		sed -e "s|'mod_fcgid_wrapper', '0'|'mod_fcgid_wrapper', '1'|g" -i "${S}/install/froxlor.sql" || die "Unable to set fcgi-wrapper to 'FCGIWrapper'"
	fi

	if use fpm ; then
		einfo "Switching 'fpm' to 'On'"
		sed -e "s|'phpfpm', 'enabled', '0'|'phpfpm', 'enabled', '1'|g" -i "${S}/install/froxlor.sql" || die "Unable to set fpm to 'On'"

		einfo "Setting configdir for fpm"
		sed -e "s|'phpfpm', 'configdir', '/etc/php-fpm.d/'|'phpfpm', 'configdir', '/etc/php/fpm-php5.3/fpm.d/'|g" -i "${S}/install/froxlor.sql" || die "Unable to set configdir for 'fpm'"

#		ewarn "tell here what to do for including fpm.d/*.conf"
#		einfo "Enable custom configdir for fpm"
#		sed -e "s|;include=/etc/php/fpm-php5.3/fpm.d/*.conf|include=/etc/php/fpm-php5.3/fpm.d/*.conf|g" -i "/etc/php/fpm-php5.3/php-fpm.conf" || die "Unable to set custom configdir for 'fpm'"

#		einfo "Checking for directory /etc/php/fpm-php5.3/fpm.d/"
#		if [ ! -d /etc/php/fpm-php5.3/fpm.d/ ]; then
#			dodir "/etc/php/fpm-php5.3/fpm.d/"
#		fi

	fi

	# If Bind will not used disable it and change the reload path for it
	if ! use bind ; then
		einfo "Switching 'bind' to 'Off'"
		sed -e 's|'bind_enable', '1'|'bind_enable', '0'|g' -i "${S}/install/froxlor.sql" || die "Unable to change reload path for Bind"
		sed -e 's|/etc/init.d/named reload|/bin/true|g' -i "${S}/install/froxlor.sql" || die "Unable to change reload path for Bind"
	fi

	# default value is logging_enabled='1'
	if ! use log ; then
		einfo "Switching 'log' to 'Off'"
		sed -e "s|'logger', 'enabled', '1'|'logger', 'enabled', '0'|g" -i "${S}/install/froxlor.sql" || die "Unable to set logging to 'Off'"
	fi

	# default value is tickets_enabled='1'
	if ! use tickets ; then
		einfo "Switching 'tickets' to 'Off'"
		sed -e "s|'ticket', 'enabled', '1'|'ticket', 'enabled', '0'|g" -i "${S}/install/froxlor.sql" || die "Unable to set ticketsystem to 'Off'"
	fi

	# default value is mailquota='0'
	if use mailquota ; then
		einfo "Switching 'mailquota' to 'On'"
		sed -e "s|'mail_quota_enabled', '0'|'mail_quota_enabled', '1'|g" -i "${S}/install/froxlor.sql" || die "Unable to set mailquota to 'On'"
	fi

	# default value is dkim_enabled='0'
	if use domainkey && use bind ; then
		einfo "Switching 'domainkey' to 'On'"
		sed -e "s|'use_dkim', '0'|'use_dkim', '1'|g" -i "${S}/install/froxlor.sql" || die "Unable to set domainkey to 'On'"

		einfo "Setting dkim-path to gentoo value"
		sed -e "s|'dkim_prefix', '/etc/postfix/dkim/'|'dkim_prefix', '/etc/mail/dkim-filter/'|g" -i "${S}/install/froxlor.sql" || die "Unable to set domainkey prefix"
	fi

	# default value is ssl_enabled='1'
	if ! use ssl ; then
		einfo "Switching 'SSL' to 'Off'"
		sed -e "s|'use_ssl','1'|'use_ssl','0'|g" -i "${S}/install/froxlor.sql" || die "Unable to set ssl to 'Off'"
	fi

	if use awstats ; then
		einfo "Switching from 'Webalizer' to 'AWStats'"
		sed -e "s|'webalizer_quiet', '2'|'webalizer_quiet', '0'|g" -i "${S}/install/froxlor.sql"
		sed -e "s|'awstats_enabled', '0'|'awstats_enabled', '1'|g" -i "${S}/install/froxlor.sql" || die "Unable to enable AWStats"
	fi

	if use pureftpd ; then
		einfo "Switching from 'ProFTPd' to 'Pure-FTPd'"
		sed -e "s|'ftpserver', 'proftpd'|'ftpserver', 'pureftpd'|g" -i "${S}/install/froxlor.sql"
	fi

	# Install the Froxlor files
	einfo "Installing Froxlor files"
	dodir ${FROXLOR_DOCROOT}
	cp -Rf "${S}/" "${D}${FROXLOR_DOCROOT}/" || die "Installation of the Froxlor files failed"
}

pkg_postinst() {
	# we need to check if this is going to be an update or a fresh install!
	if [[ -f "${ROOT}${FROXLOR_DOCROOT}/froxlor/lib/userdata.inc.php" ]] ; then
		elog "Froxlor is already installed on this system!"
		elog
		elog "Froxlor will update the database when you open"
		elog "it in your browser the first time after the update-process"
	elif [[ -f "${ROOT}${FROXLOR_DOCROOT}/syscp/lib/userdata.inc.php" ]] ; then
		elog "This seems to be an upgrade from syscp"
		elog "please move ${FROXLOR_DOCROOT}/syscp/lib/userdata.inc.php to"
		elog "${FROXLOR_DOCROOT}/froxlor/lib/"
		elog "and don't forget to copy "${ROOT}/usr/share/${PN}/froxlor.cron""
		elog "to /etc/cron.d/froxlor and remove /etc/cron.d/syscp"
	else
		elog "Please open http://[ip]/froxlor in your browser to continue"
		elog "continue with the basic setup of Froxlor."
		elog
		elog "Don't forget to setup your MySQL databases root user and password"
		elog "using emerge --config mysql"
	fi
}

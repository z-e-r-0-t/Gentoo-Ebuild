# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="nss module to have an additional passwd, shadow and group file"
HOMEPAGE="https://sources.debian.org/src/libnss-extrausers/0.6-4/"
SRC_URI="mirror://debian/pool/main/libn/${PN}/${PN}_${PV}.orig.tar.gz
	mirror://debian/pool/main/libn/${PN}/${PN}_${PV}-4.debian.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"

src_prepare() {
	for patch in $(< "${WORKDIR}"/debian/patches/series); do
		eapply "${WORKDIR}"/debian/patches/${patch}
	done
	default
}

src_compile() {
	emake -j1
}

src_install() {
	emake DESTDIR="${D}" libprefix="/usr/$(get_libdir)" install
}

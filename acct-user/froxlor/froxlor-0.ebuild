# Copyright 2019-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user user-info

IUSE="min-uid-1000"

ACCT_USER_ID=-1
ACCT_USER_GROUPS=( ${PN} )

acct-user_add_deps

pkg_setup() {
	if use min-uid-1000; then
		einfo "Minimum uid >= 1000 requested: looking for next free uid"
		ACCT_USER_ID=1000
		while true; do
			local user_by_id=$(egetusername "${ACCT_USER_ID}")
			if [[ -n ${user_by_id} ]]; then
				ACCT_USER_ID=$((ACCT_USER_ID+1))
			else
				break
			fi
		einfo "Found free uid: ${ACCT_USER_ID}"
		done
	fi
}

pkg_postinst() {
	if [[ ! -n ${_ACCT_USER_ADDED} ]]; then
		uid_by_name=$(id -u "${PN}")
		if [[ ${ACCT_USER_ID} -ne ${uid_by_name} && ${ACCT_USER_ID} -ne -1 ]]; then
			ewarn "UID >= 1000 requested, user already exists, manual change of UID required"
			ewarn "Please manually execute the following command"
			ewarn "usermod -u ${ACCT_USER_ID} ${PN}"
		fi
	fi
}

#!/usr/bin/env bash

# BooBoo Quick CA
# Copyright (C) 2017, Bernd Stroessenreuther <booboo@gluga.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# 2017-07-17 booboo:
# This script revokes certificates

function help { # .-------------------------------------------------------
    echo
    echo "call using:"
    echo "$0 -f <cert_file>"
    echo "$0 -i"
    echo "$0 -h"
    echo
    echo "where:"
    echo "    <cert_file> is the file containing the certificate you want to revoke"
    echo "    -i          revoke the certificate of your Issuing CA"
    echo "    -h          Display this help screen and exit"
    echo
}
#.

BOOBOO_QUICK_CA_BASE=${BOOBOO_QUICK_CA_BASE:-$(readlink -f "$(dirname "$0")/..")}
QUICK_CA_CFG_FILE=$BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg
CERT_FILE=""
CRL_CHECK_OPTION=""
REVOKE_ISSUING_CA=0

# shellcheck source=common_functions
source "${BOOBOO_QUICK_CA_BASE}/bin/common_functions"
do_not_run_as_root

if [[ -f $QUICK_CA_CFG_FILE ]]; then
    # shellcheck source=/dev/null
    source "$QUICK_CA_CFG_FILE"
fi

hook_script pre

# .-- command line options -----------------------------------------------
while getopts ":if:h" opt; do
    case $opt in
    i)
        REVOKE_ISSUING_CA=1
        ;;
    f)
        CERT_FILE=$OPTARG
        ;;
    h)
        help
        exit 0
        ;;
    \?)
        echo "Invalid option: -$OPTARG"
        help
        exit 1
        ;;
    esac
done

if [[ -z $CERT_FILE ]] && [[ $REVOKE_ISSUING_CA -eq 0 ]]; then
    help
    exit 1
fi

#.

if [[ $REVOKE_ISSUING_CA = 1 ]]; then
    if [[ $SEPARATE_ISSUING_CA != "yes" ]]; then
        echo ::
        echo -e :: "${RED}You do not have a separate Issuing CA - unable to revoke it!${NO_COLOR}"
        echo ::
        exit 1
    fi

    OPENSSL_CNF_FILE=$ROOT_CA_OPENSSL_CNF_FILE
    CERT_FILE=$ISSUING_CA_CERT_FILE

    if [[ -n "$ROOT_CA_CRL_DISTRIBUTION_POINTS" ]]; then
        CRL_CHECK_OPTION="-crl_check_all"
    fi
else
    OPENSSL_CNF_FILE=$ISSUING_CA_OPENSSL_CNF_FILE

    if [[ -n "$ISSUING_CA_CRL_DISTRIBUTION_POINTS" ]]; then
        CRL_CHECK_OPTION="-crl_check_all"
    fi
fi

echo ::
echo -e ":: ${HEADLINE_COLOR}Revoking Certificate${NO_COLOR}"
echo ::
openssl ca -config "$OPENSSL_CNF_FILE" -revoke "$CERT_FILE"
display_rc $? 0

echo ::
echo -e ":: ${HEADLINE_COLOR}Re-creating Certificate Revocation Lists${NO_COLOR}"
echo ::
create_crl_root_ca
create_crl_issuing_ca

if [[ -n $CRL_CHECK_OPTION ]]; then
    echo ::
    echo -e ":: ${HEADLINE_COLOR}Verifying Certificate against trust chain${NO_COLOR}"
    echo :: expected message: certificate revoked
    echo ::
    openssl verify $CRL_CHECK_OPTION -CAfile "$CA_CHAIN_PLUS_CRL_FILE" "$CERT_FILE"
    openssl verify $CRL_CHECK_OPTION -CAfile "$CA_CHAIN_PLUS_CRL_FILE" "$CERT_FILE" | grep "lookup:certificate revoked" > /dev/null 2>/dev/null
    display_rc $? 0
fi

hook_script post

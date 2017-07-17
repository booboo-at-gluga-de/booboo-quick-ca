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


# 2017-07-07 booboo:
# This script just renews the certificate revocation list(s) (CRL(s))
# if you are using CRL(s). That means if you did set
# ROOT_CA_CRL_DISTRIBUTION_POINTS and / or ISSUING_CA_CRL_DISTRIBUTION_POINTS
# in booboo-quick-ca.cfg
# (if both settings are empty you do not get CRLs)
#
# By default the CRL(s) is/are valid for 30 days. That means they need to be
# renewed regularly.

function help { # .-------------------------------------------------------
    echo
    echo "call using:"
    echo "$0"
    echo "$0 -c"
    echo "$0 -h"
    echo
    echo "call without parameter:"
    echo "         Renew the CRL(s)"
    echo "call with parameter:"
    echo "    -c   Check validity period only (do not renew)"
    echo "    -h   Display this help screen and exit"
    echo
}
#.

BOOBOO_QUICK_CA_BASE=${BOOBOO_QUICK_CA_BASE:-$(readlink -f $(dirname $0)/..)}
QUICK_CA_CFG_FILE=$BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg
CHECK_ONLY=0

source $BOOBOO_QUICK_CA_BASE/bin/common_functions
do_not_run_as_root

if [[ -f $QUICK_CA_CFG_FILE ]]; then
    source $QUICK_CA_CFG_FILE
fi

# .-- command line options -----------------------------------------------
while getopts ":ch" opt; do
    case $opt in
    c)
        CHECK_ONLY=1
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

#.

if [[ $CHECK_ONLY -eq 1 ]]; then
    check_crl_validity "root_ca"
    check_crl_validity "issuing_ca"
else
    create_crl_root_ca
    create_crl_issuing_ca
fi

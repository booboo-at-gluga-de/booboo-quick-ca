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

if [[ $EUID -eq 0 ]]; then
    echo
    echo You should not run your CA as root user.
    echo Better create a separate unprivileged user account especially for your CA.
    echo
    exit 1
fi

BOOBOO_QUICK_CA_BASE=${BOOBOO_QUICK_CA_BASE:-$(readlink -f $(dirname $0)/..)}
QUICK_CA_CFG_FILE=$BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg

source $BOOBOO_QUICK_CA_BASE/bin/common_functions
if [[ -f $QUICK_CA_CFG_FILE ]]; then
    source $QUICK_CA_CFG_FILE
fi

create_crl_root_ca
create_crl_issuing_ca

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


# A hook script can be used for your own automation topics. It can be called
# before and after each script of BooBoo Quick CA. It might be useful e. g.
# for copying your CRLs to the CRL distribution point (probably a webserver).
#
# This is just a sample. Copy it to any location you like and make sure
# HOOK_SCRIPT in ca_config/booboo-quick-ca.cfg points to this location.
#
# It gets two parameters:
# The first one is "pre" - called before a script starts working
# or "post" - called after the script has done it's work.
# The second one is the basename of the calling script.

HOOK=$1
CALLING_SCRIPT=$2

if [[ $HOOK != "pre" ]] && [[ $HOOK != "post" ]]; then
    echo "::: first param HOOK must be \"pre\" or \"post\""
    exit 1
fi

case $CALLING_SCRIPT in
    "create_customer_cert.sh")
        if [[ $HOOK = "pre" ]]; then
            echo "::: pre script hook for create_customer_cert.sh"
        elif [[ $HOOK = "post" ]]; then
            echo "::: post script hook for create_customer_cert.sh"
        fi
        ;;
    "renew_crl.sh")
        if [[ $HOOK = "pre" ]]; then
            echo "::: pre script hook for renew_crl.sh"
        elif [[ $HOOK = "post" ]]; then
            echo "::: post script hook for renew_crl.sh"
        fi
        ;;
    "revoke.sh")
        if [[ $HOOK = "pre" ]]; then
            echo "::: pre script hook for revoke.sh"
        elif [[ $HOOK = "post" ]]; then
            echo "::: post script hook for revoke.sh"
        fi
        ;;
    "setup_CA.sh")
        if [[ $HOOK = "pre" ]]; then
            echo "::: pre script hook for setup_CA.sh"
        elif [[ $HOOK = "post" ]]; then
            echo "::: post script hook for setup_CA.sh"
        fi
        ;;
    "sign_customer_cert.sh")
        if [[ $HOOK = "pre" ]]; then
            echo "::: pre script hook for sign_customer_cert.sh"
        elif [[ $HOOK = "post" ]]; then
            echo "::: post script hook for sign_customer_cert.sh"
        fi
        ;;
    *)
        echo "::: unknown calling script $CALLING_SCRIPT"
        exit 2
        ;;
esac

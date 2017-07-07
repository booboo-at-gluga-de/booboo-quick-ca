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


# 2017-07-04 booboo:
# This script tries to find out for every SSL related file, what type
# it is and tries to show it's content.

function help { # .-------------------------------------------------------
    echo
    echo "This script displays the content of different, SSL/TLS related file types"
    echo
    echo "Call using:"
    echo "$0 [-p|-n] <FILE> [<FILE>]+"
    echo "$0 -h|--help"
    echo ""
    echo "where"
    echo "    <FILE>     is a file you want to display."
    echo "               It should be of type csr, pem, der, jks or pkcs12"
    echo "    -n         No Color: Print headers uncolored. (Better for parsing output.)"
    echo "    -p         Plain: Display the plain content of the file. No headers at all."
    echo "    -h|--help  Display this help screen and exit."
    echo
}
#.

function display_header { # .---------------------------------------------
    if [[ $DISPLAY_HEADERS -eq 1 ]]; then
        echo -e ":: $1"
    fi
}
#.

BOOBOO_QUICK_CA_BASE=${BOOBOO_QUICK_CA_BASE:-$(readlink -f $(dirname $0)/..)}
DISPLAY_HEADERS=1
source $BOOBOO_QUICK_CA_BASE/bin/common_functions

if [[ -z "$1" ]] || [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; then
    help
    exit 0
fi

for OPTION in $*; do
    case "$OPTION" in
        # OPTION may be a parameter...
        '-n')
            # no color
            HEADLINE_COLOR=""
            NO_COLOR=""
            RED=""
            GREEN=""
            ORANGE=""
            ;;
        '-p')
            # do not display headers
            DISPLAY_HEADERS=0
            ;;
        # ... or OPTION may be a file
        *)
            FILE=$OPTION
            display_header
            display_header "${HEADLINE_COLOR}$FILE${NO_COLOR}"
            if [[ ! -f $FILE ]] && [[ ! -L $FILE ]]; then
                echo -e :: ${RED}$FILE is not a regular file${NO_COLOR}
                continue
            fi
            EXTENSION="${FILE##*.}"
            if [[ -L $FILE ]]; then
                LINK=$(LANG=C file -b $FILE)
                display_header "$LINK"
                FILE=$(readlink -f $FILE)
            fi
            TYPE=$(LANG=C file -b $FILE)

            case "$TYPE" in
                'PEM certificate')
                    display_header "Type: ${GREEN}$TYPE${NO_COLOR}"
                    display_header
                    openssl x509 -noout -text -in $FILE
                    ;;
                'PEM certificate request')
                    display_header "Type: ${GREEN}$TYPE${NO_COLOR}"
                    display_header
                    openssl req -text -noout -in $FILE
                    ;;
                'PEM RSA private key')
                    display_header "Type: ${GREEN}$TYPE${NO_COLOR}"
                    display_header
                    cat $FILE
                    ;;
                'Java KeyStore')
                    display_header "Type: ${GREEN}$TYPE${NO_COLOR}"
                    display_header
                    # list keystore content only
                    # (echo an empty string for password prompt)
                    echo | keytool -list -keystore $FILE
                    ;;
                'data')
                    display_header "Type: ${GREEN}$TYPE${NO_COLOR}"
                    if [[ $EXTENSION = "p12" ]]; then
                        display_header "Filename extension: ${GREEN}$EXTENSION${NO_COLOR}"
                        display_header "Trying to read as PKCS12 keystore"
                        display_header
                        openssl pkcs12 -in $FILE -nodes
                    elif [[ $EXTENSION = "der" ]] || [[ $EXTENSION = "cer" ]]; then
                        display_header "Filename extension: ${GREEN}$EXTENSION${NO_COLOR}"
                        display_header "Trying to read as DER format"
                        display_header
                        openssl x509 -noout -text -inform DER -in $FILE
                    else
                        display_header "Filename extension: ${ORANGE}$TYPE${NO_COLOR}"
                        display_header "${ORANGE}unknown how to handle${NO_COLOR}"
                    fi
                    ;;
                'ASCII text')
                    display_header "Type: ${GREEN}$TYPE${NO_COLOR}"
                    if [[ $(grep -c '\-----BEGIN X509 CRL-----' $FILE) -gt 0 ]]; then
                        display_header "Trying to read as CRL"
                        display_header
                        openssl crl -text -noout -in $FILE
                    else
                        display_header
                        cat $FILE
                    fi
                    ;;
                'empty')
                    display_header "Type: ${GREEN}$TYPE${NO_COLOR}"
                    ;;
                *)
                    display_header "Type: ${ORANGE}$TYPE${NO_COLOR}"
                    display_header "${ORANGE}unknown how to handle${NO_COLOR}"
                    ;;
            esac
            ;;
        esac
done

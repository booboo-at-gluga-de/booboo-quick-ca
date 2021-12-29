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


# 2017-05-15 booboo:
# This script signs a CSR (Certificate Signing Request) for a CA customer
# and creates a customer certifcate.

function help { # .-------------------------------------------------------
    echo
    echo "call using:"
    echo "$0 [-c|-s] -f <CSR_FILE>"
    echo "$0 -h"
    echo
    echo "where"
    echo "    <CSR_FILE> is the file containing the Certificate Signing"
    echo "               Request"
    echo "    -c         tells to create a client certificate"
    echo "    -s         tells to create a server certificate (this is the default)"
    echo "    -h         display this help screen and exit"
    echo
}
#.

BOOBOO_QUICK_CA_BASE=${BOOBOO_QUICK_CA_BASE:-$(readlink -f "$(dirname "$0")/..")}
QUICK_CA_CFG_FILE=$BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg
EXISTING_CONFIG_FILES=0
CUSTOMER_CERT_TYPE="server_cert"
DEVIANT_CERT_FILENAME=0

# shellcheck source=common_functions
source "${BOOBOO_QUICK_CA_BASE}/bin/common_functions"
do_not_run_as_root

# .-- command line options -----------------------------------------------
while getopts ":f:csh" opt; do
    case $opt in
    f)
        CUSTOMER_CERT_CSR_FILE_COMMANDLINE=$OPTARG
        ;;
    c)
        CUSTOMER_CERT_TYPE="client_cert"
        ;;
    s)
        CUSTOMER_CERT_TYPE="server_cert"
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

if [[ -z $CUSTOMER_CERT_CSR_FILE_COMMANDLINE ]]; then
    help
    exit 1
fi

if [[ ! -f $CUSTOMER_CERT_CSR_FILE_COMMANDLINE ]]; then
    echo
    echo "$CUSTOMER_CERT_CSR_FILE_COMMANDLINE is not a valid file!"
    help
    exit 1
fi
#.

if [[ -f $QUICK_CA_CFG_FILE ]]; then
    # shellcheck source=/dev/null
    source "$QUICK_CA_CFG_FILE"
else
    echo "::"
    echo -e ":: ${HEADLINE_COLOR}No config file found in $QUICK_CA_CFG_FILE${NO_COLOR}"
    echo "::"
    echo ":: Did you already setup your CA by using the setup_CA.sh script?"
    echo ":: If no: Please do this first!"
    echo ":: If yes: You probably gave a different base directory"
    echo ":: (not $BOOBOO_QUICK_CA_BASE)"
    echo ":: when running setup_CA.sh. Please set the BOOBOO_QUICK_CA_BASE"
    echo ":: environment varible to the correct path, e. g. by calling"
    echo "::    BOOBOO_QUICK_CA_BASE=/path/to/base $0"
    echo "::"
    exit 1
fi

hook_script pre

CUSTOMER_CERT_CN=$(openssl req -text -noout -in "$CUSTOMER_CERT_CSR_FILE_COMMANDLINE" | grep "Subject: " | perl -e '$in=<STDIN>; if ( $in =~ m/CN *= *([^\/,]+)/ ) { print "$1\n" } else  { print "none\n" }')
if [[ $CUSTOMER_CERT_CN = "none" ]]; then
    SERIAL=$(cat "$ISSUING_CA_SERIAL_FILE")
    CUSTOMER_CERT_CN="CERT_$SERIAL"
fi

# source config file once again because some filenames base on CUSTOMER_CERT_CN
# shellcheck source=/dev/null
source "$QUICK_CA_CFG_FILE"

echo ::
echo -e ":: ${HEADLINE_COLOR}Checking for already existing files...${NO_COLOR}"
echo ::
for FILE in $CUSTOMER_CERT_CERT_FILE_PEM $CUSTOMER_CERT_CERT_FILE_DER; do
    if [[ -f $FILE ]]; then
        echo ":: $FILE already exists"
        EXISTING_CONFIG_FILES=$(( EXISTING_CONFIG_FILES + 1 ))
    fi
done

if [[ $EXISTING_CONFIG_FILES -gt 0 ]]; then
    echo ::
    echo -e ":: ${RED}Files for this certifcate already exist.${NO_COLOR}"
    echo ":: If you want to setup a new one, please remove file(s) above."
    echo ::
    exit 1
else
    echo :: There are none.
    display_rc 0 0
fi

echo ::
echo -e ":: ${HEADLINE_COLOR}Creating certificate...${NO_COLOR}"
echo ::
# To create a certificate, use the issuing CA to sign the CSR.
# If the certificate is going to be used on a server, use the server_cert
# extension. If the certificate is going to be used for user authentication,
# use the usr_cert extension.

TMP_OPENSSL_CNF_FILE=$(mktemp --tmpdir="$BOOBOO_QUICK_CA_BASE/tmp" --suffix=.cnf openssl.XXX)
cp "$ISSUING_CA_OPENSSL_CNF_FILE" "$TMP_OPENSSL_CNF_FILE"
sed -i -e "s/^ *commonName_default *=.*/commonName_default              =$CUSTOMER_CERT_CN/" "$TMP_OPENSSL_CNF_FILE"

#
# set crlDistributionPoints (if configured)
#
if [[ -n "$ISSUING_CA_CRL_DISTRIBUTION_POINTS" ]]; then
    sed -i -e "s#^ *\# *crlDistributionPoints *=.*#crlDistributionPoints              =$ISSUING_CA_CRL_DISTRIBUTION_POINTS#" "$TMP_OPENSSL_CNF_FILE"
fi

# if issuing a client certificate and CN is a eMail address:
# suggest to put this eMail address into the email field too
# (not only in the CN field) if USE_MAIL_ADDRESS_FOR_CN_AND_EMAIL
# is set to yes in booboo-quick-ca.cfg
if [[ $USE_MAIL_ADDRESS_FOR_CN_AND_EMAIL = "yes" ]]; then
    if [[ $(echo "$CUSTOMER_CERT_CN" | grep -E -c "^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+$") -gt 0 ]]; then
        # CN seems to be a valid eMail address
        sed -i -e "s/^ *emailAddress_default *=.*/emailAddress_default            =$CUSTOMER_CERT_CN/" "$TMP_OPENSSL_CNF_FILE"
    fi
fi

# put SANs into the temporary config file
cat >> "$TMP_OPENSSL_CNF_FILE" <<END

[alt_names_customer_cert]
DNS.1 = $CUSTOMER_CERT_CN
END

# add all given SANs
COUNTER=2
for SAN in "${SUBJECT_ALTERNATE_NAMES[@]}"; do
    echo DNS.$COUNTER = "$SAN" >> "$TMP_OPENSSL_CNF_FILE"
    COUNTER=$(( COUNTER + 1 ))
done

RC=255
while [[ $RC -ne 0 ]]; do
    openssl ca -config "$TMP_OPENSSL_CNF_FILE" -extensions ${CUSTOMER_CERT_TYPE} \
        -days "$CUSTOMER_CERT_LIFE_TIME" -notext -md sha256 -in "$CUSTOMER_CERT_CSR_FILE_COMMANDLINE" \
        -out "$CUSTOMER_CERT_CERT_FILE_PEM"
    RC=$?
    [[ $RC -ne 0 ]] && echo -e ":: ${ORANGE}WARNING: This did not work. Retrying...${NO_COLOR}"
done
chmod 444 "$CUSTOMER_CERT_CERT_FILE_PEM"

rm "$TMP_OPENSSL_CNF_FILE"

# provide PEM file also under a name based on the CSR filename
# (which is important for retrieving it by http)
CSR_BASENAME=$(basename "$CUSTOMER_CERT_CSR_FILE_COMMANDLINE" .csr)
CUSTOMER_CERT_CERT_FILE_PEM_BASED_ON_FILENAME="${CUSTOMER_CERT_DIR}/${CSR_BASENAME}.cert.pem"
CUSTOMER_CERT_CERT_FILE_DER_BASED_ON_FILENAME="${CUSTOMER_CERT_DIR}/${CSR_BASENAME}.cert.der"
if [[ $CUSTOMER_CERT_CERT_FILE_PEM != "$CUSTOMER_CERT_CERT_FILE_PEM_BASED_ON_FILENAME" ]]; then
    DEVIANT_CERT_FILENAME=1
    cp "$CUSTOMER_CERT_CERT_FILE_PEM" "$CUSTOMER_CERT_CERT_FILE_PEM_BASED_ON_FILENAME"
    chmod 444 "$CUSTOMER_CERT_CERT_FILE_PEM_BASED_ON_FILENAME"
fi

# The $ISSUING_CA_INDEX_FILE  file should contain a line referring to this new certificate.

#V 160420124233Z 1000 unknown ... /CN=www.example.com

echo ::
echo -e ":: ${HEADLINE_COLOR}Please verify your new Certificate:${NO_COLOR}"
echo -e ":: ${HEADLINE_COLOR}-----------------------------------${NO_COLOR}"
echo ::

openssl x509 -noout -text -in "$CUSTOMER_CERT_CERT_FILE_PEM"

echo ::
echo -n ":: Please verify your certificate and press ENTER if OK "
IFS= read -r _

# The Issuer is the issuing CA. The Subject refers to the certificate itself.
#
# The output will also show the X509v3 extensions. When creating the
# certificate, you used either the server_cert or usr_cert extension.
# The options from the corresponding configuration section will be reflected
# in the output.

echo ::
echo -e ":: ${HEADLINE_COLOR}Verifying the certificate against the CA...${NO_COLOR}"
echo ::

if [[ -n "$ISSUING_CA_CRL_DISTRIBUTION_POINTS" ]]; then
    CRL_CHECK_OPTION="-crl_check_all"
else
    CRL_CHECK_OPTION=
fi
# Use the CA certificate chain file we created earlier to verify that the new
# certificate has a valid chain of trust.
openssl verify $CRL_CHECK_OPTION -CAfile "$CA_CHAIN_PLUS_CRL_FILE" "$CUSTOMER_CERT_CERT_FILE_PEM"
display_rc $? 1

if [[ $CUSTOMER_CERT_CREATE_DER = "yes" ]]; then
    echo ::
    echo -e ":: ${HEADLINE_COLOR}Providing the certificate in DER format...${NO_COLOR}"
    echo ::
    openssl x509 -in "$CUSTOMER_CERT_CERT_FILE_PEM" -inform PEM -out "$CUSTOMER_CERT_CERT_FILE_DER" -outform DER
    display_rc $? 0
    chmod 444 "$CUSTOMER_CERT_CERT_FILE_DER"

    if [[ $DEVIANT_CERT_FILENAME -ne 0 ]]; then
        cp "$CUSTOMER_CERT_CERT_FILE_DER" "$CUSTOMER_CERT_CERT_FILE_DER_BASED_ON_FILENAME"
        chmod 444 "$CUSTOMER_CERT_CERT_FILE_DER_BASED_ON_FILENAME"
    fi
fi

# pkcs12 and jks can not be generated: For both we would need the private key of the customer cert.

echo ::
echo -e ":: ${HEADLINE_COLOR}What you got:${NO_COLOR}"
echo -e ":: ${HEADLINE_COLOR}-------------${NO_COLOR}"
echo ::
echo :: The certificate in PEM format:
ls "$CUSTOMER_CERT_CERT_FILE_PEM"
display_rc $? 0

if [[ $DEVIANT_CERT_FILENAME -ne 0 ]]; then
    echo :: This file can also been found under:
    ls "$CUSTOMER_CERT_CERT_FILE_PEM_BASED_ON_FILENAME"
    display_rc $? 0
fi
echo ::

if [[ $CUSTOMER_CERT_CREATE_DER = "yes" ]]; then
    echo :: The certificate in DER format \(as an alternative\):
    ls "$CUSTOMER_CERT_CERT_FILE_DER"
    display_rc $? 0

    if [[ $DEVIANT_CERT_FILENAME -ne 0 ]]; then
        echo :: This file can also been found under:
        ls "$CUSTOMER_CERT_CERT_FILE_DER_BASED_ON_FILENAME"
        display_rc $? 0
    fi
    echo ::
fi

# remind user to renew CRL certificates if needed
check_crl_validity "root_ca" -q
check_crl_validity "issuing_ca" -q

hook_script post

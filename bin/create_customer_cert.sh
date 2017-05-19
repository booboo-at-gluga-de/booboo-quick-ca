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


# 2017-03-27 booboo:
# This script creates a server or client certificate for a CA customer.
# It also creates the private key file and the certificate signing request (CSR).
# If you already have a CSR (created on the target machine - as recommended)
# please use sign_customer_cert.sh

function help {
    echo
    echo "call using:"
    echo "$0 [-c|-s] -n <COMMON_NAME> [-a <SUBJECT_ALTERNATE_NAME>]+"
    echo "$0 -h"
    echo
    echo "where"
    echo "    -c            tells to create a client certificate"
    echo "    -s            tells to create a server certificate (this is the default)"
    echo "    -a            add a subject alternate name"
    echo "                  the certificate will be valid for the <COMMON_NAME> as well"
    echo "                  as for all names given as <SUBJECT_ALTERNATE_NAME>"
    echo "                  (you may give -a multiple times if needed)"
    echo "    -h            display this help screen and exit"
    echo "    <COMMON_NAME> is the COMMON_NAME (CN) of the certificate you want to create"
    echo
}

if [[ $EUID -eq 0 ]]; then
    echo
    echo You should not run your CA as root user.
    echo Better create a separate unprivileged user account especially for your CA.
    echo
    exit 1
fi

BOOBOO_QUICK_CA_BASE=${BOOBOO_QUICK_CA_BASE:-$(readlink -f $(dirname $0)/..)}
QUICK_CA_CFG_FILE=$BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg
EXISTING_CONFIG_FILES=0
HAVE_KEYTOOL=1
CUSTOMER_CERT_TYPE="server_cert"
declare -a SUBJECT_ALTERNATE_NAMES

# command line options
while getopts ":scn:a:h" opt; do
    case $opt in
    n)
        CUSTOMER_CERT_CN=$OPTARG
        ;;
    c)
        CUSTOMER_CERT_TYPE="client_cert"
        ;;
    s)
        CUSTOMER_CERT_TYPE="server_cert"
        ;;
    a)
        SUBJECT_ALTERNATE_NAMES+=("$OPTARG")
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

if [[ -z $CUSTOMER_CERT_CN ]]; then
    help
    exit 1
fi

if [[ -f $QUICK_CA_CFG_FILE ]]; then
    source $QUICK_CA_CFG_FILE
else
    echo ::
    echo :: No config file found in $QUICK_CA_CFG_FILE
    echo ::
    echo :: Did you already setup your CA by using the setup_CA.sh script?
    echo :: If no: Please do this first!
    echo :: If yes: You probably gave a different base directory
    echo :: \(not $BOOBOO_QUICK_CA_BASE\)
    echo :: when running setup_CA.sh. Please set the BOOBOO_QUICK_CA_BASE
    echo :: environment varible to the correct path, e. g. by calling
    echo ::    BOOBOO_QUICK_CA_BASE=/path/to/base $0
    echo ::
    exit 1
fi

echo ::
echo :: Checking for already existing files...
echo ::
for FILE in $CUSTOMER_CERT_KEY_FILE $CUSTOMER_CERT_CSR_FILE $CUSTOMER_CERT_CERT_FILE_PEM $CUSTOMER_CERT_CERT_FILE_DER $CUSTOMER_CERT_PKCS12_FILE $CUSTOMER_CERT_JKS_FILE; do
    if [[ -f $FILE ]]; then
        echo :: $FILE already exists
        EXISTING_CONFIG_FILES=$(($EXISTING_CONFIG_FILES+1))
    fi
done

if [[ $EXISTING_CONFIG_FILES -gt 0 ]]; then
    echo ::
    echo :: Files for this certifcate already exist.
    echo :: If you want to setup a new one, please remove file\(s\) above.
    echo ::
    exit 1
else
    echo :: OK
fi

echo ::
echo :: Creating Key...
echo ::

umask 077
openssl genrsa -aes256 -out $CUSTOMER_CERT_KEY_FILE $CUSTOMER_CERT_KEY_LENGTH
chmod 400 $CUSTOMER_CERT_KEY_FILE

echo ::
echo :: Creating Certificate Signing Request \(CSR\)...
echo ::

TMP_OPENSSL_CNF_FILE=$(mktemp --tmpdir=$BOOBOO_QUICK_CA_BASE/tmp --suffix=.cnf openssl.XXX)
cp $ISSUING_CA_OPENSSL_CNF_FILE $TMP_OPENSSL_CNF_FILE
sed -i -e "s/^ *commonName_default *=.*/commonName_default              =$CUSTOMER_CERT_CN/" $TMP_OPENSSL_CNF_FILE

# put SANs into the temporary config file
cat >> $TMP_OPENSSL_CNF_FILE <<END

[alt_names_customer_cert]
DNS.1 = $CUSTOMER_CERT_CN
END

# add all given SANs
COUNTER=2
for SAN in ${SUBJECT_ALTERNATE_NAMES[@]}; do
    echo DNS.$COUNTER = $SAN >> $TMP_OPENSSL_CNF_FILE
    COUNTER=$(( $COUNTER + 1 ))
done

openssl req -config $TMP_OPENSSL_CNF_FILE \
      -key $CUSTOMER_CERT_KEY_FILE -new -sha256 -out $CUSTOMER_CERT_CSR_FILE

echo ::
echo :: Creating certificate...
echo ::
# To create a certificate, use the issuing CA to sign the CSR.
# If the certificate is going to be used on a server, use the server_cert
# extension. If the certificate is going to be used for user authentication,
# use the usr_cert extension.

openssl ca -config $TMP_OPENSSL_CNF_FILE -extensions ${CUSTOMER_CERT_TYPE} \
      -days $CUSTOMER_CERT_LIFE_TIME -notext -md sha256 -in $CUSTOMER_CERT_CSR_FILE \
      -out $CUSTOMER_CERT_CERT_FILE_PEM || exit 1
chmod 444 $CUSTOMER_CERT_CERT_FILE_PEM

# The $ISSUING_CA_INDEX_FILE  file should contain a line referring to this new certificate.

#V 160420124233Z 1000 unknown ... /CN=www.example.com

rm $TMP_OPENSSL_CNF_FILE

echo ::
echo :: Please verify your new Certificate:
echo :: -----------------------------------
echo ::

openssl x509 -noout -text -in $CUSTOMER_CERT_CERT_FILE_PEM

echo ::
echo -n ":: Please verify your certificate and press ENTER if OK "
read TMP

# The Issuer is the issuing CA. The Subject refers to the certificate itself.
#
# The output will also show the X509v3 extensions. When creating the
# certificate, you used either the server_cert or usr_cert extension.
# The options from the corresponding configuration section will be reflected
# in the output.

echo ::
echo :: Verifying the certificate against the Root CA...
echo ::

# Use the CA certificate chain file we created earlier to verify that the new
# certificate has a valid chain of trust.
openssl verify -CAfile $CA_CHAIN_FILE $CUSTOMER_CERT_CERT_FILE_PEM || exit 1
# should report www.example.com.cert.pem: OK

if [[ $CUSTOMER_CERT_CREATE_DER = "yes" ]]; then
    echo ::
    echo :: Providing the certificate in DER format...
    echo ::
    openssl x509 -in $CUSTOMER_CERT_CERT_FILE_PEM -inform PEM -out $CUSTOMER_CERT_CERT_FILE_DER -outform DER && echo :: OK
    chmod 444 $CUSTOMER_CERT_CERT_FILE_DER
fi

if [ $CUSTOMER_CERT_CREATE_PKCS12 = "yes" -o $CUSTOMER_CERT_CREATE_JKS = "yes" ]; then
    echo ::
    echo :: Providing a complete keystore in PKCS12 format...
    echo ::
    openssl pkcs12 -export -out $CUSTOMER_CERT_PKCS12_FILE -inkey $CUSTOMER_CERT_KEY_FILE \
        -in $CUSTOMER_CERT_CERT_FILE_PEM -certfile $CA_CHAIN_FILE
fi

if [[ $CUSTOMER_CERT_CREATE_JKS = "yes" ]]; then
    echo ::
    echo :: Providing a complete keystore in Java Keystore \(jks\) format...
    echo ::
    echo :: As \"destination keystore password\" please give the password you want to
    echo :: set for the jks file.
    echo :: As \"source keystore password\" you need to give the password you just did
    echo :: set for the PKCS12 keystore \(we just convert this one now\)

    type keytool >/dev/null 2>/dev/null
    HAVE_KEYTOOL=$?
    if [[ $HAVE_KEYTOOL -eq 0 ]]; then
        # create a complete keystore (key, Cert, issuing CA)
        # according to https://www.tbs-certificates.co.uk/FAQ/en/626.html
        # keytool -importkeystore -srckeystore [MY_FILE.p12] -srcstoretype pkcs12
        #  -srcalias [ALIAS_SRC] -destkeystore [MY_KEYSTORE.jks]
        #  -deststoretype jks -deststorepass [PASSWORD_JKS] -destalias [ALIAS_DEST]

        keytool -importkeystore -srckeystore $CUSTOMER_CERT_PKCS12_FILE -srcstoretype pkcs12 \
            -destkeystore $CUSTOMER_CERT_JKS_FILE -deststoretype jks
    else
        echo :: Sorry, no keytool binary found in the PATH, skipping creation of jks
    fi
fi

echo ::
echo :: What you got:
echo :: -------------
echo ::
echo :: The private key in PEM format:
ls $CUSTOMER_CERT_KEY_FILE
echo ::
echo :: The certificate in PEM format:
ls $CUSTOMER_CERT_CERT_FILE_PEM
echo ::
if [[ $CUSTOMER_CERT_CREATE_DER = "yes" ]]; then
    echo :: The certificate in DER format \(as an alternative\):
    ls $CUSTOMER_CERT_CERT_FILE_DER
    echo ::
fi
if [ $CUSTOMER_CERT_CREATE_PKCS12 = "yes" -o $CUSTOMER_CERT_CREATE_JKS = "yes" ]; then
    echo :: A keystore containing the private key, the certificate and needed CA in PKCS12 format:
    ls $CUSTOMER_CERT_PKCS12_FILE
fi

if [[ $HAVE_KEYTOOL -eq 0 ]]; then
    echo ::
    echo :: A keystore containing the private key, the certificate and needed CA in Java Keystore format:
    ls $CUSTOMER_CERT_JKS_FILE
fi

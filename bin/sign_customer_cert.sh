#!/usr/bin/env bash

# 2017-05-15 booboo:
# This script signs a CSR (Certificate Signing Request) for a CA customer
# and creates a customer certifcate.

function help {
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

# command line options
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
    echo $CUSTOMER_CERT_CSR_FILE_COMMANDLINE is not a valid file!
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

CUSTOMER_CERT_CN=$(openssl req -text -noout -in $CUSTOMER_CERT_CSR_FILE_COMMANDLINE | grep "Subject: " | perl -e '$in=<STDIN>; if ( $in =~ m/CN=([^\/]+)/ ) { print "$1\n" } else  { print "none\n" }')
if [[ $CUSTOMER_CERT_CN = "none" ]]; then
    SERIAL=$(cat $ISSUING_CA_SERIAL_FILE)
    CUSTOMER_CERT_CN="CERT_$SERIAL"
fi

# source config file once again because some filenames base on CUSTOMER_CERT_CN
source $QUICK_CA_CFG_FILE

echo ::
echo :: Checking for already existing files...
echo ::
for FILE in $CUSTOMER_CERT_CERT_FILE_PEM $CUSTOMER_CERT_CERT_FILE_DER $CUSTOMER_CERT_PKCS12_FILE $CUSTOMER_CERT_JKS_FILE; do
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
echo :: Creating certificate...
echo ::
# To create a certificate, use the issuing CA to sign the CSR.
# If the certificate is going to be used on a server, use the server_cert
# extension. If the certificate is going to be used for user authentication,
# use the usr_cert extension.

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

openssl ca -config $TMP_OPENSSL_CNF_FILE -extensions ${CUSTOMER_CERT_TYPE} \
      -days $CUSTOMER_CERT_LIFE_TIME -notext -md sha256 -in $CUSTOMER_CERT_CSR_FILE_COMMANDLINE \
      -out $CUSTOMER_CERT_CERT_FILE_PEM || exit 1
chmod 444 $CUSTOMER_CERT_CERT_FILE_PEM

rm $TMP_OPENSSL_CNF_FILE

# The $ISSUING_CA_INDEX_FILE  file should contain a line referring to this new certificate.

#V 160420124233Z 1000 unknown ... /CN=www.example.com

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
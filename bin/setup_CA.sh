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


# 2017-03-22 booboo:
# this script initializes the CA with all needed config files
# and initially creates the CA (root) certificate

function logical_symlink { # .--------------------------------------------
    LINK_DEST=$1
    LINK_SOURCE=$2

    BASENAME_LINK_DEST=$(basename $LINK_DEST)
    BASENAME_LINK_SOURCE=$(basename $LINK_SOURCE)
    DIRNAME_LINK_DEST=$(dirname $LINK_DEST)
    DIRNAME_LINK_SOURCE=$(dirname $LINK_SOURCE)

    if [[ $DIRNAME_LINK_DEST = $DIRNAME_LINK_SOURCE ]]; then
        echo ":: in $DIRNAME_LINK_DEST symlinking $BASENAME_LINK_SOURCE -> $BASENAME_LINK_DEST"
        cd $DIRNAME_LINK_DEST
        ln -s $BASENAME_LINK_DEST $BASENAME_LINK_SOURCE
        cd - >/dev/null
    else
        echo ":: symlinking $LINK_SOURCE -> $LINK_DEST"
        ln -s $LINK_DEST $LINK_SOURCE
    fi
}
#.

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

if [[ -f $QUICK_CA_CFG_FILE ]]; then
    source $QUICK_CA_CFG_FILE
fi

echo ::
echo :: Setting up your new root CA
echo :: ===========================
echo ::
echo :: Base directory for you CA is $BOOBOO_QUICK_CA_BASE
echo :: If this is not what you want, set environment variable BOOBOO_QUICK_CA_BASE
echo :: to point somewhere else e. g. by calling this script as
echo :: BOOBOO_QUICK_CA_BASE=/path/to/base $0
echo ::
echo -n ":: Do you want to setup your CA in $BOOBOO_QUICK_CA_BASE? "
read ANSWER
if [[ $(echo $ANSWER | egrep -i "^(y|yes)$" | wc -l) -eq 0 ]]; then
    echo Aborting...
    exit 1
fi

echo ::
echo :: Checking base directory...
echo ::
for FILE in $ROOT_CA_INDEX_FILE $ROOT_CA_SERIAL_FILE $ROOT_CA_KEY_FILE $ROOT_CA_CERT_FILE; do
    if [[ -f $FILE ]]; then
        echo :: $FILE already exists
        EXISTING_CONFIG_FILES=$(($EXISTING_CONFIG_FILES+1))
    fi
done

if [[ $EXISTING_CONFIG_FILES -gt 0 ]]; then
    echo ::
    echo :: Seems there is an existing CA already in $BOOBOO_QUICK_CA_BASE
    echo :: If you want to setup a new one, please remove file\(s\) above.
    echo ::
    exit 1
else
    echo :: OK
fi

echo ::
echo :: Creating sub directories...
umask 077
mkdir -p $BOOBOO_QUICK_CA_BASE/ca_config $BOOBOO_QUICK_CA_BASE/ca_certs $BOOBOO_QUICK_CA_BASE/ca_private_keys $BOOBOO_QUICK_CA_BASE/customer_certs $BOOBOO_QUICK_CA_BASE/customer_private_keys $BOOBOO_QUICK_CA_BASE/crl $BOOBOO_QUICK_CA_BASE/csr $BOOBOO_QUICK_CA_BASE/tmp
chmod 700 $BOOBOO_QUICK_CA_BASE/ca_config $BOOBOO_QUICK_CA_BASE/ca_private_keys $BOOBOO_QUICK_CA_BASE/customer_certs $BOOBOO_QUICK_CA_BASE/customer_private_keys $BOOBOO_QUICK_CA_BASE/csr $BOOBOO_QUICK_CA_BASE/tmp
chmod 755 $BOOBOO_QUICK_CA_BASE/ca_certs $BOOBOO_QUICK_CA_BASE/crl

echo ::
echo :: Creating config files...
echo ::

#.
# .-- creating $QUICK_CA_CFG_FILE ----------------------------------------.
if [[ ! -f $QUICK_CA_CFG_FILE ]]; then
    echo :: A config file
    echo :: $QUICK_CA_CFG_FILE
    echo :: does not exist. Creating it for you!

    cat > $QUICK_CA_CFG_FILE <<END
###########################################################################
# Default values for openssl commands
###########################################################################
#
# Everytime a Certificate Signing Request (CSR) is created, openssl
# asks for some informations. As you might not want to type them
# every time, we provide defaults here.
#
# Please note: This are only default values!! You still get the
# chance to overwrite them for every single CSR!

COUNTRY_NAME_DEFAULT="DE"
STATE_OR_PROVINCE_NAME_DEFAULT="Gallien"
LOCALITY_NAME_DEFAULT="Gallisches Dorf"
ORGANIZATION_NAME_DEFAULT="Die Gallier"
ORGANIZATIONAL_UNIT_NAME_DEFAULT=""
EMAILADDRESS_DEFAULT="certificates@example.com"
ROOT_CA_COMMON_NAME_DEFAULT="RootCA.example.com"
ISSUING_CA_COMMON_NAME_DEFAULT="IssuingCA.example.com"

###########################################################################
# Key length
###########################################################################
#
# Which key length (in bits) do you want to use for the private keys?

ROOT_CA_KEY_LENGTH=4096
ISSUING_CA_KEY_LENGTH=4096
CUSTOMER_CERT_KEY_LENGTH=2048

###########################################################################
# Use a separate issuing CA?
###########################################################################
#
# All the professional and community based certificate authorities use
# a root CA certificate and a separate issuing CA certificate (issued by
# the root CA certificate) because it makes key management more flexible
# for them. That's why "yes" is the default here.
# However this may seem oversized for some private usecases so decide
# yourself.
# If set to "no", the root CA certificate will be used as issuing CA too.
#
# You may set this to "yes" or "no"
SEPARATE_ISSUING_CA="yes"

###########################################################################
# Certificate life time
###########################################################################
#
# How long should your certificates be valid? (in days)

ROOT_CA_LIFE_TIME=3653
ISSUING_CA_LIFE_TIME=1827
CUSTOMER_CERT_LIFE_TIME=365

###########################################################################
# Output formats for customer certificates
###########################################################################
#
# Which formats do you want to produce your customer certificates in?
# set each of them to "yes" or "no"

# DER format?
CUSTOMER_CERT_CREATE_DER="yes"
# PKCS12 keystore format (including CA certificate)?
CUSTOMER_CERT_CREATE_PKCS12="yes"
# Java keystore format (jks) including CA certificate?
# (if you set this to yes, PKCS12 is also created, because technically needed)
CUSTOMER_CERT_CREATE_JKS="yes"

###########################################################################
# Path settings
###########################################################################
#
# Where to store files (certificates, keys, config files)
#
# Usually there should be no reason for changing paths

ROOT_CA_INDEX_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/root_ca_index.txt
ROOT_CA_SERIAL_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/root_ca_serial
ROOT_CA_CRL_NUMBER_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/root_ca_crlnumber
ROOT_CA_CRL_PEM_FILE=\$BOOBOO_QUICK_CA_BASE/crl/root_ca.crl.pem
ROOT_CA_OPENSSL_CNF_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/root_ca_openssl.cnf
ROOT_CA_KEY_FILE=\$BOOBOO_QUICK_CA_BASE/ca_private_keys/root_ca.key.pem
ROOT_CA_CERT_FILE=\$BOOBOO_QUICK_CA_BASE/ca_certs/root_ca.cert.pem

ISSUING_CA_INDEX_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/issuing_ca_index.txt
ISSUING_CA_SERIAL_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/issuing_ca_serial
ISSUING_CA_CRL_NUMBER_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/issuing_ca_crlnumber
ISSUING_CA_CRL_PEM_FILE=\$BOOBOO_QUICK_CA_BASE/crl/issuing_ca.crl.pem
ISSUING_CA_OPENSSL_CNF_FILE=\$BOOBOO_QUICK_CA_BASE/ca_config/issuing_ca_openssl.cnf
ISSUING_CA_DATE_EXTENSION=\$(date +%Y)
ISSUING_CA_KEY_FILE_FULL=\$BOOBOO_QUICK_CA_BASE/ca_private_keys/issuing_ca.\${ISSUING_CA_DATE_EXTENSION}.key.pem
ISSUING_CA_KEY_FILE=\$BOOBOO_QUICK_CA_BASE/ca_private_keys/issuing_ca.key.pem
ISSUING_CA_CERT_FILE_FULL=\$BOOBOO_QUICK_CA_BASE/ca_certs/issuing_ca.\${ISSUING_CA_DATE_EXTENSION}.cert.pem
ISSUING_CA_CERT_FILE=\$BOOBOO_QUICK_CA_BASE/ca_certs/issuing_ca.cert.pem
ISSUING_CA_CSR_FILE=\$BOOBOO_QUICK_CA_BASE/csr/issuing_ca.csr.pem

CA_CHAIN_FILE_FULL=\$BOOBOO_QUICK_CA_BASE/ca_certs/ca-chain.\${ISSUING_CA_DATE_EXTENSION}.cert.pem
CA_CHAIN_FILE=\$BOOBOO_QUICK_CA_BASE/ca_certs/ca-chain.cert.pem

CUSTOMER_CERT_DATE_EXTENSION=\$(date +%Y-%m-%d)
CUSTOMER_CERT_KEY_FILE=\$BOOBOO_QUICK_CA_BASE/customer_private_keys/\${CUSTOMER_CERT_CN}.\${CUSTOMER_CERT_DATE_EXTENSION}.key.pem
CUSTOMER_CERT_CERT_FILE_PEM=\$BOOBOO_QUICK_CA_BASE/customer_certs/\${CUSTOMER_CERT_CN}.\${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem
CUSTOMER_CERT_CERT_FILE_DER=\$BOOBOO_QUICK_CA_BASE/customer_certs/\${CUSTOMER_CERT_CN}.\${CUSTOMER_CERT_DATE_EXTENSION}.cert.der
CUSTOMER_CERT_CSR_FILE=\$BOOBOO_QUICK_CA_BASE/csr/\${CUSTOMER_CERT_CN}.\${CUSTOMER_CERT_DATE_EXTENSION}.csr
CUSTOMER_CERT_PKCS12_FILE=\$BOOBOO_QUICK_CA_BASE/customer_certs/\${CUSTOMER_CERT_CN}.\${CUSTOMER_CERT_DATE_EXTENSION}.p12
CUSTOMER_CERT_JKS_FILE=\$BOOBOO_QUICK_CA_BASE/customer_certs/\${CUSTOMER_CERT_CN}.\${CUSTOMER_CERT_DATE_EXTENSION}.jks
END

    echo ::
    echo :: Edit this file now and fill it with you wanted values.
    echo :: At the moment it contains only sample data!
    echo ::
    echo :: Afterwards, start this script \($0\) again.
    echo ::
    exit 0
fi
#.

# The index.txt file is where the OpenSSL ca tool stores the certificate
# database. Do not delete or edit this file by hand. It should now contain
# a line that refers to the issuing CA certificate.
touch $ROOT_CA_INDEX_FILE

echo 1000 > $ROOT_CA_SERIAL_FILE

# crlnumber is used to keep track of certificate revocation lists.
echo 1000 > $ROOT_CA_CRL_NUMBER_FILE

# .-- root_ca_openssl.cnf -------------------------------------------------.
cat > $ROOT_CA_OPENSSL_CNF_FILE <<END
[ ca ]
# see 'man ca'
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = $BOOBOO_QUICK_CA_BASE/
certs             = \$dir/ca_certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/customer_certs
database          = $ROOT_CA_INDEX_FILE
serial            = $ROOT_CA_SERIAL_FILE
RANDFILE          = \$dir/ca_config/.rand
unique_subject    = no

# The root CA key certificate.
private_key       = $ROOT_CA_KEY_FILE
certificate       = $ROOT_CA_CERT_FILE

# For certificate revocation lists.
crlnumber         = $ROOT_CA_CRL_NUMBER_FILE
crl               = $ROOT_CA_CRL_PEM_FILE
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_strict

[ policy_strict ]
# The root CA should only sign certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the ca man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the 'req' tool ('man req').
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             =$COUNTRY_NAME_DEFAULT
stateOrProvinceName_default     =$STATE_OR_PROVINCE_NAME_DEFAULT
localityName_default            =$LOCALITY_NAME_DEFAULT
0.organizationName_default      =$ORGANIZATION_NAME_DEFAULT
organizationalUnitName_default  =$ORGANIZATIONAL_UNIT_NAME_DEFAULT
emailAddress_default            =$EMAILADDRESS_DEFAULT
commonName_default              =$ROOT_CA_COMMON_NAME_DEFAULT

[ v3_ca ]
# Extensions for a typical CA ('man x509v3_config').
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectAltName = @alt_names_v3_ca

[ v3_issuing_ca ]
# Extensions for a typical issuing CA ('man x509v3_config').
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectAltName = @alt_names_v3_issuing_ca

[ client_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
subjectAltName = @alt_names_customer_cert

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names_customer_cert

[ crl_ext ]
# Extension for CRLs ('man x509v3_config').
authorityKeyIdentifier=keyid:always

[ ocsp ]
# Extension for OCSP signing certificates ('man ocsp').
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning

[alt_names_v3_ca]
DNS.1 = $ROOT_CA_COMMON_NAME_DEFAULT

[alt_names_v3_issuing_ca]
DNS.1 = $ISSUING_CA_COMMON_NAME_DEFAULT
END
#.

echo ::
echo :: Creating Key for Root CA...
echo ::
openssl genrsa -aes256 -out $ROOT_CA_KEY_FILE $ROOT_CA_KEY_LENGTH

chmod 400 $ROOT_CA_KEY_FILE

echo ::
echo :: Creating Root CA certificate...
echo ::
openssl req -config $ROOT_CA_OPENSSL_CNF_FILE -key $ROOT_CA_KEY_FILE \
      -new -x509 -days $ROOT_CA_LIFE_TIME -sha256 -extensions v3_ca -out $ROOT_CA_CERT_FILE

chmod 444 $ROOT_CA_CERT_FILE

echo ::
echo :: Please verify your new Root CA Certificate:
echo :: -------------------------------------------
echo ::
openssl x509 -noout -text -in $ROOT_CA_CERT_FILE
echo ::
echo -n ":: Please verify your Root CA and press ENTER if OK "
read TMP

echo ::
echo :: Setting up your new issuing CA
echo :: ==============================
echo ::

if [[ $SEPARATE_ISSUING_CA = "yes" ]]; then
    touch $ISSUING_CA_INDEX_FILE
    echo 1000 > $ISSUING_CA_SERIAL_FILE

    # crlnumber is used to keep track of certificate revocation lists.
    echo 1000 > $ISSUING_CA_CRL_NUMBER_FILE


    # .-- issuing_ca_openssl.cnf ---------------------------------------------.
    cat > $ISSUING_CA_OPENSSL_CNF_FILE <<END
[ ca ]
# see 'man ca'
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = $BOOBOO_QUICK_CA_BASE/
certs             = \$dir/ca_certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/customer_certs
database          = $ISSUING_CA_INDEX_FILE
serial            = $ISSUING_CA_SERIAL_FILE
RANDFILE          = \$dir/ca_config/.rand
unique_subject    = no

# The root CA key certificate.
private_key       = $ISSUING_CA_KEY_FILE
certificate       = $ISSUING_CA_CERT_FILE

# For certificate revocation lists.
crlnumber         = $ISSUING_CA_CRL_NUMBER_FILE
crl               = $ISSUING_CA_CRL_PEM_FILE
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_loose

[ policy_strict ]
# The root CA should only sign certificates that match.
# See the POLICY FORMAT section of 'man ca'.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the ca man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the 'req' tool ('man req').
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             =$COUNTRY_NAME_DEFAULT
stateOrProvinceName_default     =$STATE_OR_PROVINCE_NAME_DEFAULT
localityName_default            =$LOCALITY_NAME_DEFAULT
0.organizationName_default      =$ORGANIZATION_NAME_DEFAULT
organizationalUnitName_default  =$ORGANIZATIONAL_UNIT_NAME_DEFAULT
emailAddress_default            =$EMAILADDRESS_DEFAULT
commonName_default              =$ISSUING_CA_COMMON_NAME_DEFAULT

[ v3_ca ]
# Extensions for a typical CA ('man x509v3_config').
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectAltName = @alt_names_v3_ca

[ v3_issuing_ca ]
# Extensions for a typical issuing CA ('man x509v3_config').
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectAltName = @alt_names_v3_issuing_ca

[ client_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
subjectAltName = @alt_names_customer_cert

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names_customer_cert

[ crl_ext ]
# Extension for CRLs ('man x509v3_config').
authorityKeyIdentifier=keyid:always

[ ocsp ]
# Extension for OCSP signing certificates ('man ocsp').
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning

[alt_names_v3_ca]
DNS.1 = $ROOT_CA_COMMON_NAME_DEFAULT

[alt_names_v3_issuing_ca]
DNS.1 = $ISSUING_CA_COMMON_NAME_DEFAULT
END
#.

    echo ::
    echo :: Creating Key for Issuing CA...
    echo ::
    openssl genrsa -aes256 -out $ISSUING_CA_KEY_FILE_FULL $ISSUING_CA_KEY_LENGTH

    chmod 400 $ISSUING_CA_KEY_FILE_FULL
    logical_symlink $ISSUING_CA_KEY_FILE_FULL $ISSUING_CA_KEY_FILE

    echo ::
    echo :: Creating Certificate Signing Request \(CSR\) for Issuing CA...
    echo ::

    # Use the issuing CA key to create a certificate signing request (CSR). The details should generally match the root CA. The Common Name, however, must be different.

    openssl req -config $ISSUING_CA_OPENSSL_CNF_FILE -new -sha256 \
          -key $ISSUING_CA_KEY_FILE_FULL -out $ISSUING_CA_CSR_FILE

    echo ::
    echo :: Creating Issuing CA certificate...
    echo ::
    # To create an issuing CA certificate, use the root CA with the v3_issuing_ca extension to sign the issuing CSR.
    # The issuing CA certificate should be valid for a shorter period than the root certificate. Ten years would be reasonable.

    # This time, specify the root CA configuration file

    openssl ca -config $ROOT_CA_OPENSSL_CNF_FILE -extensions v3_issuing_ca \
          -days $ISSUING_CA_LIFE_TIME -notext -md sha256 \
          -in $ISSUING_CA_CSR_FILE -out $ISSUING_CA_CERT_FILE_FULL

    chmod 444 $ISSUING_CA_CERT_FILE_FULL
    logical_symlink $ISSUING_CA_CERT_FILE_FULL $ISSUING_CA_CERT_FILE


    echo ::
    echo :: Please verify your new Issuing CA Certificate:
    echo :: ----------------------------------------------
    echo ::
    openssl x509 -noout -text -in $ISSUING_CA_CERT_FILE_FULL
    echo ::
    echo -n ":: Please verify your Issuing CA and press ENTER if OK "
    read TMP

    echo ::
    echo :: Verifying the Issuing CA file against the Root CA certificate
    echo ::
    openssl verify -CAfile $ROOT_CA_CERT_FILE $ISSUING_CA_CERT_FILE_FULL || exit 1


    echo ::
    echo :: Creating a CA certificate chain file...
    echo ::
    # To create the CA certificate chain, concatenate the issuing CA and root
    # certificates together. This can be used to verify certificates signed by
    # the issuing CA.

    cat $ISSUING_CA_CERT_FILE_FULL $ROOT_CA_CERT_FILE > $CA_CHAIN_FILE_FULL
    chmod 444 $CA_CHAIN_FILE_FULL
    logical_symlink $CA_CHAIN_FILE_FULL $CA_CHAIN_FILE
    echo :: CA chain file is: $CA_CHAIN_FILE_FULL
else
    # $SEPARATE_ISSUING_CA = "no"
    echo ::
    echo :: As you decided to work without a separate Issuing CA Certificate
    echo :: just symlinking you Root CA files as Issuing CA files
    logical_symlink $ROOT_CA_INDEX_FILE $ISSUING_CA_INDEX_FILE
    logical_symlink $ROOT_CA_CRL_NUMBER_FILE $ISSUING_CA_CRL_NUMBER_FILE
    logical_symlink $ROOT_CA_OPENSSL_CNF_FILE $ISSUING_CA_OPENSSL_CNF_FILE
    logical_symlink $ROOT_CA_KEY_FILE $ISSUING_CA_KEY_FILE
    logical_symlink $ROOT_CA_CERT_FILE $ISSUING_CA_CERT_FILE
    logical_symlink $ROOT_CA_CERT_FILE $CA_CHAIN_FILE
fi

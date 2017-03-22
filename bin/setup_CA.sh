#!/usr/bin/env bash

# 2017-03-22 booboo:
# this script initializes the CA with all needed config files
# and initially creates the CA (root) certificate

if [[ $EUID -eq 0 ]]; then
    echo
    echo You should not run your CA as root user.
    echo Better create a separate unprivileged user account especially for your CA.
    echo
    exit 1
fi

echo ::
echo :: Setting up your new CA
echo :: ======================

BOOBOO_QUICK_CA_BASE=${BOOBOO_QUICK_CA_BASE:-$(readlink -f $(dirname $0)/..)}
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
echo :: Creating sub directories...
umask 077
mkdir -p $BOOBOO_QUICK_CA_BASE/ca_config $BOOBOO_QUICK_CA_BASE/ca_certs $BOOBOO_QUICK_CA_BASE/ca_private_keys $BOOBOO_QUICK_CA_BASE/customer_certs $BOOBOO_QUICK_CA_BASE/customer_private_keys $BOOBOO_QUICK_CA_BASE/crl
chmod 700 $BOOBOO_QUICK_CA_BASE/ca_config $BOOBOO_QUICK_CA_BASE/ca_private_keys $BOOBOO_QUICK_CA_BASE/customer_certs $BOOBOO_QUICK_CA_BASE/customer_private_keys
chmod 755 $BOOBOO_QUICK_CA_BASE/ca_certs $BOOBOO_QUICK_CA_BASE/crl

echo ::
echo :: Creating config files...
echo ::

if [[ -f $BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg ]]; then
    source $BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg
fi

# .-- default values -----------------------------------------------------.
#
#                _   _   _             _   _
#               / \ | |_| |_ ___ _ __ | |_(_) ___  _ __
#              / _ \| __| __/ _ \ '_ \| __| |/ _ \| '_ \
#             / ___ \ |_| ||  __/ | | | |_| | (_) | | | |
#            /_/   \_\__|\__\___|_| |_|\__|_|\___/|_| |_|
#
# Attention: If you want your own defaults do   N O T   change them here!
#            Change them in $BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg

COUNTRY_NAME_DEFAULT=${COUNTRY_NAME_DEFAULT:-"DE"}
STATE_OR_PROVINCE_NAME_DEFAULT=${STATE_OR_PROVINCE_NAME_DEFAULT:-"Gallien"}
LOCALITY_NAME_DEFAULT=${LOCALITY_NAME_DEFAULT:-"Gallisches Dorf"}
ORGANIZATION_NAME_DEFAULT=${ORGANIZATION_NAME_DEFAULT:-"Die Gallier"}
ORGANIZATIONAL_UNIT_NAME_DEFAULT=${ORGANIZATIONAL_UNIT_NAME_DEFAULT:-""}
EMAILADDRESS_DEFAULT=${EMAILADDRESS_DEFAULT:-"certificates@examples.com"}
CA_COMMON_NAME_DEFAULT=${CA_COMMON_NAME_DEFAULT:-"RootCA.example.com"}

#.

if [[ ! -f $BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg ]]; then
    echo :: A config file
    echo :: $BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg
    echo :: does not exist. Creating it for you!

    cat > $BOOBOO_QUICK_CA_BASE/ca_config/booboo-quick-ca.cfg <<END
# Default values for openssl commands
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
EMAILADDRESS_DEFAULT="certificates@examples.com"
CA_COMMON_NAME_DEFAULT="RootCA.example.com"
END

    echo ::
    echo :: Edit this file now and fill it with you wanted values.
    echo :: At the moment it contains only sample data!
    echo ::
    echo :: Afterwards, start this script \($0\) again.
    echo ::
    exit 0
fi

touch $BOOBOO_QUICK_CA_BASE/ca_config/index.txt
echo 1000 > $BOOBOO_QUICK_CA_BASE/ca_config/serial

# .-- root_ca_openssl.cnf -------------------------------------------------.
cat > $BOOBOO_QUICK_CA_BASE/ca_config/root_ca_openssl.cnf <<END
[ ca ]
# man ca
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = $BOOBOO_QUICK_CA_BASE/
certs             = \$dir/ca_certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/customer_certs
database          = \$dir/ca_config/index.txt
serial            = \$dir/ca_config/serial
RANDFILE          = \$dir/ca_config/.rand

# The root CA key certificate.
private_key       = \$dir/ca_private_keys/root_ca.key.pem
certificate       = \$dir/ca_certs/root_ca.cert.pem

# For certificate revocation lists.
crlnumber         = \$dir/ca_config/crlnumber
crl               = \$dir/crl/ca.crl.pem
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
# See the POLICY FORMAT section of man ca.
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
# Options for the req tool (man req).
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
commonName_default              =$CA_COMMON_NAME_DEFAULT

[ v3_ca ]
# Extensions for a typical CA (man x509v3_config).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions for a typical intermediate CA ('man x509v3_config').
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ usr_cert ]
# Extensions for client certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ server_cert ]
# Extensions for server certificates ('man x509v3_config').
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

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
END
#.

echo ::
echo :: Creating Key for Root CA...
echo ::
openssl genrsa -aes256 -out $BOOBOO_QUICK_CA_BASE/ca_private_keys/root_ca.key.pem 4096

chmod 400 $BOOBOO_QUICK_CA_BASE/ca_private_keys/root_ca.key.pem

echo ::
echo :: Creating Root CA certificate...
echo ::
openssl req -config $BOOBOO_QUICK_CA_BASE/ca_config/root_ca_openssl.cnf \
      -key $BOOBOO_QUICK_CA_BASE/ca_private_keys/root_ca.key.pem \
      -new -x509 -days 7305 -sha256 -extensions v3_ca \
      -out $BOOBOO_QUICK_CA_BASE/ca_certs/root_ca.cert.pem

chmod 444 $BOOBOO_QUICK_CA_BASE/ca_certs/root_ca.cert.pem

echo ::
echo :: Please verify your new Root CA Certificate:
echo :: -------------------------------------------
echo ::
openssl x509 -noout -text -in $BOOBOO_QUICK_CA_BASE/ca_certs/root_ca.cert.pem

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
mkdir -p $BOOBOO_QUICK_CA_BASE/ca_config $BOOBOO_QUICK_CA_BASE/ca_certs $BOOBOO_QUICK_CA_BASE/ca_private_keys $BOOBOO_QUICK_CA_BASE/customer_certs $BOOBOO_QUICK_CA_BASE/customer_private_keys $BOOBOO_QUICK_CA_BASE/crl $BOOBOO_QUICK_CA_BASE/csr
chmod 700 $BOOBOO_QUICK_CA_BASE/ca_config $BOOBOO_QUICK_CA_BASE/ca_private_keys $BOOBOO_QUICK_CA_BASE/customer_certs $BOOBOO_QUICK_CA_BASE/customer_private_keys $BOOBOO_QUICK_CA_BASE/csr
chmod 755 $BOOBOO_QUICK_CA_BASE/ca_certs $BOOBOO_QUICK_CA_BASE/crl

echo ::
echo :: Creating config files...
echo ::

# .-- default values -----------------------------------------------------.
#
# Attention: If you want your own defaults do   N O T   change them here!
#            Change them in $QUICK_CA_CFG_FILE

COUNTRY_NAME_DEFAULT=${COUNTRY_NAME_DEFAULT:-"DE"}
STATE_OR_PROVINCE_NAME_DEFAULT=${STATE_OR_PROVINCE_NAME_DEFAULT:-"Gallien"}
LOCALITY_NAME_DEFAULT=${LOCALITY_NAME_DEFAULT:-"Gallisches Dorf"}
ORGANIZATION_NAME_DEFAULT=${ORGANIZATION_NAME_DEFAULT:-"Die Gallier"}
ORGANIZATIONAL_UNIT_NAME_DEFAULT=${ORGANIZATIONAL_UNIT_NAME_DEFAULT:-""}
EMAILADDRESS_DEFAULT=${EMAILADDRESS_DEFAULT:-"certificates@example.com"}
ROOT_CA_COMMON_NAME_DEFAULT=${CA_COMMON_NAME_DEFAULT:-"RootCA.example.com"}
ISSUING_CA_COMMON_NAME_DEFAULT=${CA_COMMON_NAME_DEFAULT:-"IssuingCA.example.com"}

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
# Variables for the booboo-quick-ca scripts
###########################################################################

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
ISSUING_CA_KEY_FILE=\$BOOBOO_QUICK_CA_BASE/ca_private_keys/issuing_ca.key.pem
ISSUING_CA_CERT_FILE=\$BOOBOO_QUICK_CA_BASE/ca_certs/issuing_ca.cert.pem
ISSUING_CA_CSR_FILE=\$BOOBOO_QUICK_CA_BASE/csr/issuing_ca.csr.pem

CA_CHAIN_FILE=\$BOOBOO_QUICK_CA_BASE/ca_certs/ca-chain.cert.pem
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
# a line that refers to the intermediate certificate.
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
openssl genrsa -aes256 -out $ROOT_CA_KEY_FILE 4096

chmod 400 $ROOT_CA_KEY_FILE

echo ::
echo :: Creating Root CA certificate...
echo ::
openssl req -config $ROOT_CA_OPENSSL_CNF_FILE -key $ROOT_CA_KEY_FILE \
      -new -x509 -days 7305 -sha256 -extensions v3_ca -out $ROOT_CA_CERT_FILE

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
echo :: Creating Key for Issuing CA...
echo ::
openssl genrsa -aes256 -out $ISSUING_CA_KEY_FILE 4096

chmod 400 $ISSUING_CA_KEY_FILE

echo ::
echo :: Creating Certificate Signing Request \(CSR\) for Issuing CA...
echo ::

# Use the intermediate key to create a certificate signing request (CSR). The details should generally match the root CA. The Common Name, however, must be different.

openssl req -config $ISSUING_CA_OPENSSL_CNF_FILE -new -sha256 \
      -key $ISSUING_CA_KEY_FILE -out $ISSUING_CA_CSR_FILE

echo ::
echo :: Creating Issuing CA certificate...
echo ::
# To create an intermediate certificate, use the root CA with the v3_intermediate_ca extension to sign the intermediate CSR.
# The intermediate certificate should be valid for a shorter period than the root certificate. Ten years would be reasonable.

# This time, specify the root CA configuration file

openssl ca -config $ROOT_CA_OPENSSL_CNF_FILE -extensions v3_intermediate_ca \
      -days 3652 -notext -md sha256 \
      -in $ISSUING_CA_CSR_FILE -out $ISSUING_CA_CERT_FILE

chmod 444 $ISSUING_CA_CERT_FILE


echo ::
echo :: Please verify your new Issuing CA Certificate:
echo :: ----------------------------------------------
echo ::
openssl x509 -noout -text -in $ISSUING_CA_CERT_FILE
echo ::
echo -n ":: Please verify your Issuing CA and press ENTER if OK "
read TMP

echo ::
echo :: Verifying the Issuing CA file against the Root CA certificate
echo ::
openssl verify -CAfile $ROOT_CA_CERT_FILE $ISSUING_CA_CERT_FILE


echo ::
echo :: Creating a CA certificate chain file...
echo ::
# To create the CA certificate chain, concatenate the intermediate and root
# certificates together. This can be used to verify certificates signed by
# the intermediate CA.

cat $ISSUING_CA_CERT_FILE $ROOT_CA_CERT_FILE > $CA_CHAIN_FILE
chmod 444 $CA_CHAIN_FILE
echo :: CA chain file is: $CA_CHAIN_FILE

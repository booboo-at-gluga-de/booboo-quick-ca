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


# 2021-12-21 booboo:
# This script performs some unit tests on the scripts in bin directory.
# If it exits with return code 0, at least basic functionallity of
# BooBoo Quick CA is given.

CODE_BASE=${CODE_BASE:-$(readlink -f $(dirname $0)/..)}
CWD=$(pwd)
SIGNALS="HUP INT QUIT TERM ABRT"
LC_ALL=C

source ${CODE_BASE}/bin/common_functions
do_not_run_as_root


#
# Utilities
#
cleanup_temp_files() {
    SIGNALS=$1

    # if you want to keep the temporary working directory, make sure you set
    # an environment variable
    # KEEP_TMP=1
    # before calling the script
    if [[ ${KEEP_TMP} -eq 0 ]]; then
        rm -Rf ${UNITTEST_WORKINGDIR}
    else
        utecho ""
        utecho "Keeping working directory in ${UNITTEST_WORKINGDIR} - please care for removing it yourself"
        utecho ""
    fi

    trap - ${SIGNALS}
}

oneTimeTearDown() {
    # Cleanup before program termination
    # Using named signals to be POSIX compliant
    cleanup_temp_files ${SIGNALS}
}

function utecho() {
    MESSAGE="$*"
    echo -e "${UNITTEST_MARKER_COLOR}###${NO_COLOR} ${MESSAGE}"
}

oneTimeSetUp() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running Unit Tests for BooBoo Quick CA Scripts${NO_COLOR}"
    utecho "${UNITTEST_COLOR}==============================================${NO_COLOR}"
    utecho ""
    utecho "Base directory for you CA is ${CODE_BASE}"

    UNITTEST_WORKINGDIR=$(mktemp -d)
    BOOBOO_QUICK_CA_BASE=${UNITTEST_WORKINGDIR}

    utecho ""
    utecho "${UNITTEST_COLOR}Preparing Working directory for unit tests in ${UNITTEST_WORKINGDIR}${NO_COLOR}"
    utecho ""
    cp -Rv ${CODE_BASE}/bin ${UNITTEST_WORKINGDIR}

    CUSTOMER_CERT_DATE_EXTENSION=$(date +%Y-%m-%d)
}


#
# Check Prereq's
#
if [[ -z "${SHUNIT2}" ]]; then
    SHUNIT2=$( command -v shunit2 )
    if [[ -z "${SHUNIT2}" ]] && [[ -x "/usr/share/shunit2/shunit2" ]]; then
        SHUNIT2="/usr/share/shunit2/shunit2"
    fi
    if [[ -z "${SHUNIT2}" ]]; then
        cat <<EOF
To be able to run the unit test you need a copy of shUnit2
You can download it from https://github.com/kward/shunit2
Once downloaded please set the SHUNIT2 variable with the location
of the 'shunit2' script
EOF
        exit 1
    else
        echo "shunit2 detected: ${SHUNIT2}"
    fi
fi

if [[ ! -x "${SHUNIT2}" ]]; then
    echo "Error: the specified shUnit2 script (${SHUNIT2}) is not an executable file"
    exit 1
fi


#
# The Unit Tests to execute
#
testRunSetupCaFirstTime() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running setup_CA.sh (first execution)${NO_COLOR}"
    utecho ""
    cd ${UNITTEST_WORKINGDIR} || exit 1
    ${CODE_BASE}/tests/setup_CA.sh.1.expect
    cd ${CWD}

    test -f ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg has not been created" "0" "${EXIT_CODE}"
}

testEditRootCaCrlDistributionPoint() {
    utecho ""
    utecho "${UNITTEST_COLOR}Editing booboo-quick-ca.cfg${NO_COLOR}"
    utecho ""
    sed -i ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg -e 's/^ROOT_CA_CRL_DISTRIBUTION_POINTS=/ROOT_CA_CRL_DISTRIBUTION_POINTS="URI:http:\/\/example.com\/root_ca.crl.pem"/'

    egrep '^ROOT_CA_CRL_DISTRIBUTION_POINTS="URI:http' ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg should ROOT_CA_CRL_DISTRIBUTION_POINTS should contain an URL, but does not" "0" "${EXIT_CODE}"
}
testEditIssuingCaCrlDistributionPoint()
{
    sed -i ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg -e 's/^ISSUING_CA_CRL_DISTRIBUTION_POINTS=/ISSUING_CA_CRL_DISTRIBUTION_POINTS="URI:http:\/\/example.com\/issuing_ca.crl.pem"/'

    egrep '^ISSUING_CA_CRL_DISTRIBUTION_POINTS="URI:http' ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg should ISSUING_CA_CRL_DISTRIBUTION_POINTS should contain an URL, but does not" "0" "${EXIT_CODE}"
}
testEditDisableJks()
{
    sed -i ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg -e 's/^CUSTOMER_CERT_CREATE_JKS="yes"/CUSTOMER_CERT_CREATE_JKS="no"/'

    egrep '^CUSTOMER_CERT_CREATE_JKS="no"' ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg
    EXIT_CODE=$?
    assertEquals "Generating JKS keystores should be disabled in ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg for unit-tests, but seems not to. Return code" "0" "${EXIT_CODE}"
}

testRunSetupCaSecondTime() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running setup_CA.sh (second execution)${NO_COLOR}"
    utecho ""
    cd ${UNITTEST_WORKINGDIR} || exit 1
    ${CODE_BASE}/tests/setup_CA.sh.2.expect
    cd ${CWD}

    test -f ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg has not been created" "0" "${EXIT_CODE}"
}

testRootCaPrivateKey() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking Root CA${NO_COLOR}"
    utecho ""
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN RSA PRIVATE KEY\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/ca_private_keys/root_ca.key.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/ca_private_keys/root_ca.key.pem should be a RSA PRIVATE KEY in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testRootCaCertificate() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/ca_certs/root_ca.cert.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/ca_certs/root_ca.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testRootCaCrl() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN X509 CRL\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/crl/root_ca.crl.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/crl/root_ca.crl.pem should be a CRL in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testIssuingCaPrivateKey() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking Issuing CA${NO_COLOR}"
    utecho ""
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN RSA PRIVATE KEY\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/ca_private_keys/issuing_ca.key.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/ca_private_keys/issuing_ca.key.pem should be a RSA PRIVATE KEY in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testIssuingCaCertificate() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/ca_certs/issuing_ca.cert.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/ca_certs/issuing_ca.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testIssuingCaCrl() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN X509 CRL\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem should be a CRL in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testVerifyIssuingCaAgainstRootCa() {
    utecho ""
    utecho "${UNITTEST_COLOR}Verifying the Issuing CA file against the Root CA certificate${NO_COLOR}"
    utecho ""
    openssl verify -crl_check_all -CAfile ${UNITTEST_WORKINGDIR}/ca_certs/ca_chain_plus_crl.cert.pem ${UNITTEST_WORKINGDIR}/ca_certs/issuing_ca.cert.pem
    EXIT_CODE=$?
    assertEquals "Verify of Issuing CA file against Root CA certificate was unsuccessful. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testCreateServerCert() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running create_customer_cert.sh to create a Server Cert${NO_COLOR}"
    utecho ""
    cd ${UNITTEST_WORKINGDIR} || exit 1
    ${CODE_BASE}/tests/create_customer_cert.sh.servercert.expect
    cd ${CWD}

    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testServerCertKey() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking files created with the Server Cert${NO_COLOR}"
    utecho ""
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN RSA PRIVATE KEY\-\-\-\-\-' ${UNITTEST_WORKINGDIR}/customer_private_keys/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.key.pem)
    assertEquals "${UNITTEST_WORKINGDIR}/customer_private_keys/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.key.pem should be a RSA PRIVATE KEY in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testServerCertDer() {
    openssl x509 -in ${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der -inform DER -noout
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der should be a Certificate in DER format, but seems not to be. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testServerCertPkcs12() {
    openssl pkcs12 -in ${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.p12 -nodes -passin pass:test123 >/dev/null
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.p12 should be a Keystore in PKCS#12 format, but seems not to be. Return Code of openssl command" "0" "${EXIT_CODE}"
}

# @TODO: verify cert against root CA


#
# run the Unit Tests with shunit2
#
. "${SHUNIT2}"

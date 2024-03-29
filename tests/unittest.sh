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

CODE_BASE=${CODE_BASE:-$(readlink -f "$(dirname "$0")/..")}
SIGNALS="HUP INT QUIT TERM ABRT"
LC_ALL=C

# shellcheck source=/dev/null
source "${CODE_BASE}/bin/common_functions"
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
        rm -Rf "${UNITTEST_WORKINGDIR}"
    else
        utecho ""
        utecho "Keeping working directory in ${UNITTEST_WORKINGDIR} - please care for removing it yourself"
        utecho ""
    fi

    # shellcheck disable=SC2086   # SIGNALS contains multiple signals and SHOULD be splitted
    trap - ${SIGNALS}
}

oneTimeTearDown() {
    # Cleanup before program termination
    # Using named signals to be POSIX compliant
    cleanup_temp_files "${SIGNALS}"
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

    utecho ""
    utecho "${UNITTEST_COLOR}Preparing Working directory for unit tests in ${UNITTEST_WORKINGDIR}${NO_COLOR}"
    utecho ""
    cp -Rv "${CODE_BASE}/bin" "${UNITTEST_WORKINGDIR}"

    # prepare hook script for unit tests
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: pre script hook for create_customer_cert.sh\"#this file was created by pre script hook for create_customer_cert.sh\" >${UNITTEST_WORKINGDIR}/tmp/create_customer_cert.sh.pre#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: post script hook for create_customer_cert.sh\"#this file was created by post script hook for create_customer_cert.sh\" >${UNITTEST_WORKINGDIR}/tmp/create_customer_cert.sh.post#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: pre script hook for renew_crl.sh\"#this file was created by pre script hook for renew_crl.sh\" >${UNITTEST_WORKINGDIR}/tmp/renew_crl.sh.pre#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: post script hook for renew_crl.sh\"#this file was created by post script hook for renew_crl.sh\" >${UNITTEST_WORKINGDIR}/tmp/renew_crl.sh.post#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: pre script hook for revoke.sh\"#this file was created by pre script hook for revoke.sh\" >${UNITTEST_WORKINGDIR}/tmp/revoke.sh.pre#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: post script hook for revoke.sh\"#this file was created by post script hook for revoke.sh\" >${UNITTEST_WORKINGDIR}/tmp/revoke.sh.post#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: pre script hook for setup_CA.sh\"#this file was created by pre script hook for setup_CA.sh\" >${UNITTEST_WORKINGDIR}/tmp/setup_CA.sh.pre#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: post script hook for setup_CA.sh\"#this file was created by post script hook for setup_CA.sh\" >${UNITTEST_WORKINGDIR}/tmp/setup_CA.sh.post#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: pre script hook for sign_customer_cert.sh\"#this file was created by pre script hook for sign_customer_cert.sh\" >${UNITTEST_WORKINGDIR}/tmp/sign_customer_cert.sh.pre#"
    sed -i "${UNITTEST_WORKINGDIR}/bin/hook_script_sample.sh" -e "s#::: post script hook for sign_customer_cert.sh\"#this file was created by post script hook for sign_customer_cert.sh\" >${UNITTEST_WORKINGDIR}/tmp/sign_customer_cert.sh.post#"

    CUSTOMER_CERT_DATE_EXTENSION=$(date +%Y-%m-%d)
}

setUp() {
    echo -en "${UNITTEST_PREFIX_COLOR}Evaluating:${NO_COLOR} "
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
    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        "${CODE_BASE}/tests/setup_CA.sh.1.expect"
    )

    test -f "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg"
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg has not been created" "0" "${EXIT_CODE}"
}

testEditRootCaCrlDistributionPoint() {
    utecho ""
    utecho "${UNITTEST_COLOR}Editing booboo-quick-ca.cfg${NO_COLOR}"
    utecho ""
    sed -i "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg" -e 's/^ROOT_CA_CRL_DISTRIBUTION_POINTS=/ROOT_CA_CRL_DISTRIBUTION_POINTS="URI:http:\/\/example.com\/root_ca.crl.pem"/'

    grep -E '^ROOT_CA_CRL_DISTRIBUTION_POINTS="URI:http' "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg"
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg: ROOT_CA_CRL_DISTRIBUTION_POINTS should contain an URL, but does not" "0" "${EXIT_CODE}"
}
testEditIssuingCaCrlDistributionPoint()
{
    sed -i "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg" -e 's/^ISSUING_CA_CRL_DISTRIBUTION_POINTS=/ISSUING_CA_CRL_DISTRIBUTION_POINTS="URI:http:\/\/example.com\/issuing_ca.crl.pem"/'

    grep -E '^ISSUING_CA_CRL_DISTRIBUTION_POINTS="URI:http' "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg"
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg: ISSUING_CA_CRL_DISTRIBUTION_POINTS should contain an URL, but does not" "0" "${EXIT_CODE}"
}
testEditDisableJks()
{
    sed -i "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg" -e 's/^CUSTOMER_CERT_CREATE_JKS="yes"/CUSTOMER_CERT_CREATE_JKS="no"/'

    grep -E '^CUSTOMER_CERT_CREATE_JKS="no"' "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg"
    EXIT_CODE=$?
    assertEquals "Generating JKS keystores should be disabled in ${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg for unit-tests, but seems not to. Return code" "0" "${EXIT_CODE}"
}
testEditEnableHookScript() {
    sed -i "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg" -e 's/# HOOK_SCRIPT=/HOOK_SCRIPT=/'

    grep -E '^HOOK_SCRIPT=' "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg"
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg: HOOK_SCRIPT should point to a script, but does not" "0" "${EXIT_CODE}"
}

testRunSetupCaSecondTime() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running setup_CA.sh (second execution)${NO_COLOR}"
    utecho ""
    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        "${CODE_BASE}/tests/setup_CA.sh.2.expect"
    )

    test -f "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg"
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/ca_config/booboo-quick-ca.cfg has not been created" "0" "${EXIT_CODE}"
}

testRootCaPrivateKey() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking Root CA${NO_COLOR}"
    utecho ""
    SEARCHCOUNT=$(grep -E -c '\-\-\-\-\-BEGIN (RSA|ENCRYPTED) PRIVATE KEY\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/ca_private_keys/root_ca.key.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/ca_private_keys/root_ca.key.pem should be a PRIVATE KEY in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testRootCaCertificate() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/ca_certs/root_ca.cert.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/ca_certs/root_ca.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testRootCaCrl() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN X509 CRL\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/crl/root_ca.crl.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/crl/root_ca.crl.pem should be a CRL in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testHookScriptSetupCaPre() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/setup_CA.sh.pre"
    EXIT_CODE=$?
    assertEquals "Pre Hook for setup_CA.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/setup_CA.sh.pre - return code" "0" "${EXIT_CODE}"
}
testHookScriptSetupCaPost() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/setup_CA.sh.post"
    EXIT_CODE=$?
    assertEquals "Post Hook for setup_CA.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/setup_CA.sh.post - return code" "0" "${EXIT_CODE}"
}

testIssuingCaPrivateKey() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking Issuing CA${NO_COLOR}"
    utecho ""
    SEARCHCOUNT=$(grep -E -c '\-\-\-\-\-BEGIN (RSA|ENCRYPTED) PRIVATE KEY\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/ca_private_keys/issuing_ca.key.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/ca_private_keys/issuing_ca.key.pem should be a PRIVATE KEY in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testIssuingCaCertificate() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/ca_certs/issuing_ca.cert.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/ca_certs/issuing_ca.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testIssuingCaCrl() {
    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN X509 CRL\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem should be a CRL in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testVerifyIssuingCaAgainstRootCa() {
    utecho ""
    utecho "${UNITTEST_COLOR}Verifying the Issuing CA file against the Root CA certificate${NO_COLOR}"
    utecho ""
    openssl verify -crl_check_all -CAfile "${UNITTEST_WORKINGDIR}/ca_certs/ca_chain_plus_crl.cert.pem" "${UNITTEST_WORKINGDIR}/ca_certs/issuing_ca.cert.pem"
    EXIT_CODE=$?
    assertEquals "Verify of Issuing CA file against Root CA certificate was unsuccessful. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testCreateServerCert() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running create_customer_cert.sh to create a Server Cert${NO_COLOR}"
    utecho ""
    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        "${CODE_BASE}/tests/create_customer_cert.sh.servercert.expect"
    )

    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testServerCertKey() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking files created with the Server Cert${NO_COLOR}"
    utecho ""
    SEARCHCOUNT=$(grep -E -c '\-\-\-\-\-BEGIN (RSA )?PRIVATE KEY\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/customer_private_keys/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.key.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/customer_private_keys/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.key.pem should be a PRIVATE KEY in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testServerCertDer() {
    openssl x509 -in "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der" -inform DER -noout
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der should be a Certificate in DER format, but seems not to be. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testServerCertPkcs12() {
    openssl pkcs12 -in "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.p12" -nodes -passin pass:test123 >/dev/null
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.p12 should be a Keystore in PKCS#12 format, but seems not to be. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testServerCertVerifyAgainstCaAndCrl() {
    openssl verify -crl_check_all -CAfile "${UNITTEST_WORKINGDIR}/ca_certs/ca_chain_plus_crl.cert.pem" "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem"
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should be able to be verified against CA and CRL, but is not. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testHookScriptCreateCustomerCertPre() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/create_customer_cert.sh.pre"
    EXIT_CODE=$?
    assertEquals "Pre Hook for create_customer_cert.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/create_customer_cert.sh.pre - return code" "0" "${EXIT_CODE}"
}
testHookScriptCreateCustomerCertPost() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/create_customer_cert.sh.post"
    EXIT_CODE=$?
    assertEquals "Post Hook for create_customer_cert.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/create_customer_cert.sh.post - return code" "0" "${EXIT_CODE}"
}

testRevokeServerCert() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running revoke.sh to revoke the Server Cert${NO_COLOR}"
    utecho ""
    cp "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem" "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.cert.pem"
    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        "${CODE_BASE}/tests/revoke.sh.servercert.expect"
    )

    SEARCHCOUNT=$(openssl verify -crl_check_all -CAfile "${UNITTEST_WORKINGDIR}/ca_certs/ca_chain_plus_crl.cert.pem" "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem" 2>&1 | grep -c "certificate revoked")
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/servercert.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should report to be revoked, but seems not to be. Count" "1" "${SEARCHCOUNT}"
}

testCrlIssuingCaHasRevokedCert() {
    utecho ""
    utecho "${UNITTEST_COLOR}CRL should contain one entry${NO_COLOR}"
    utecho ""
    SEARCHCOUNT=$(openssl crl -in "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem" -noout -text | grep -A 1 "Serial Number:" | grep -c "Revocation Date:")
    assertEquals "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem should contain 1 revoked certificate. Count" "1" "${SEARCHCOUNT}"
}

testHookScriptRevokePre() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/revoke.sh.pre"
    EXIT_CODE=$?
    assertEquals "Pre Hook for revoke.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/revoke.sh.pre - return code" "0" "${EXIT_CODE}"
}
testHookScriptRevokePost() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/revoke.sh.post"
    EXIT_CODE=$?
    assertEquals "Post Hook for revoke.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/revoke.sh.post - return code" "0" "${EXIT_CODE}"
}

testCreateServerCertMultiSan() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running create_customer_cert.sh to create a Server Cert with multiple SANs${NO_COLOR}"
    utecho ""
    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        "${CODE_BASE}/tests/create_customer_cert.sh.servercert.multi.san.expect"
    )

    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testMultiSanCertContainsNameFromCn() {
    SEARCHCOUNT=$(openssl x509 -in "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem" -noout -text | grep -c 'DNS:multisan.unittest.example.com')
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should contain DNS:multisan.unittest.example.com. Count" "1" "${SEARCHCOUNT}"
}

testMultiSanCertContainsSan1() {
    SEARCHCOUNT=$(openssl x509 -in "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem" -noout -text | grep -c 'DNS:san1.example.com')
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should contain DNS:san1.example.com. Count" "1" "${SEARCHCOUNT}"
}

testMultiSanCertContainsSan2() {
    SEARCHCOUNT=$(openssl x509 -in "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem" -noout -text | grep -c 'DNS:san2.example.com')
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should contain DNS:san2.example.com. Count" "1" "${SEARCHCOUNT}"
}

testMultiSanCertContainsSan3() {
    SEARCHCOUNT=$(openssl x509 -in "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem" -noout -text | grep -c 'DNS:san3.example.com')
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should contain DNS:san3.example.com. Count" "1" "${SEARCHCOUNT}"
}

testRenewCrl() {
    utecho ""
    utecho "${UNITTEST_COLOR}Running renew_crl.sh${NO_COLOR}"
    utecho ""
    TIMESTAMP_ISSUING_CA_CRL_BEFORE=$(stat --format=%Y "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem")
    TIMESTAMP_ROOT_CA_CRL_BEFORE=$(stat --format=%Y "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem")
    utecho "TIMESTAMP_ISSUING_CA_CRL_BEFORE: ${TIMESTAMP_ISSUING_CA_CRL_BEFORE}"
    utecho "TIMESTAMP_ROOT_CA_CRL_BEFORE: ${TIMESTAMP_ROOT_CA_CRL_BEFORE}"
    sleep 1
    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        "${CODE_BASE}/tests/renew_crl.sh.expect"
        EXIT_CODE=$?

        assertEquals "renew_crl.sh should execute without errors. Return Code" "0" "${EXIT_CODE}"
    )
}

testIssuingCaCrlHasNewerTimestamp() {
    utecho "TIMESTAMP_ISSUING_CA_CRL_BEFORE: ${TIMESTAMP_ISSUING_CA_CRL_BEFORE}"
    TIMESTAMP_ISSUING_CA_CRL_AFTER=$(stat --format=%Y "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem")
    utecho "TIMESTAMP_ISSUING_CA_CRL_AFTER: ${TIMESTAMP_ISSUING_CA_CRL_AFTER}"

    assertNotEquals "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem should now have a different modification time than before renwal." "${TIMESTAMP_ISSUING_CA_CRL_BEFORE}" "${TIMESTAMP_ISSUING_CA_CRL_AFTER}"
}

testRootCaCrlHasNewerTimestamp() {
    utecho "TIMESTAMP_ROOT_CA_CRL_BEFORE: ${TIMESTAMP_ROOT_CA_CRL_BEFORE}"
    TIMESTAMP_ROOT_CA_CRL_AFTER=$(stat --format=%Y "${UNITTEST_WORKINGDIR}/crl/root_ca.crl.pem")
    utecho "TIMESTAMP_ROOT_CA_CRL_AFTER: ${TIMESTAMP_ROOT_CA_CRL_AFTER}"

    assertNotEquals "${UNITTEST_WORKINGDIR}/crl/root_ca.crl.pem should now have a different modification time than before renwal." "${TIMESTAMP_ROOT_CA_CRL_BEFORE}" "${TIMESTAMP_ROOT_CA_CRL_AFTER}"
}

testHookScriptRenewCrlPre() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/renew_crl.sh.pre"
    EXIT_CODE=$?
    assertEquals "Pre Hook for renew_crl.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/renew_crl.sh.pre - return code" "0" "${EXIT_CODE}"
}
testHookScriptRenewCrlPost() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/renew_crl.sh.post"
    EXIT_CODE=$?
    assertEquals "Post Hook for renew_crl.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/renew_crl.sh.post - return code" "0" "${EXIT_CODE}"
}

testRenewCrlMinusC() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/renew_crl.sh" -c | grep -c 'CRL ok! Valid until')
    assertEquals "${UNITTEST_WORKINGDIR}/bin/renew_crl.sh -c should report 2 CRLs with status CRL ok. Count" "2" "${SEARCHCOUNT}"
}

testRenewCrlMinusCR() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/renew_crl.sh" -c -r | grep -c 'CRL ok! Valid until')
    assertEquals "${UNITTEST_WORKINGDIR}/bin/renew_crl.sh -c -r should report 1 CRL with status CRL ok. Count" "1" "${SEARCHCOUNT}"
}

testRenewCrlMinusCI() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/renew_crl.sh" -c -i | grep -c 'CRL ok! Valid until')
    assertEquals "${UNITTEST_WORKINGDIR}/bin/renew_crl.sh -c -i should report 1 CRL with status CRL ok. Count" "1" "${SEARCHCOUNT}"
}

testSignCustomerCert() {
    utecho ""
    utecho "${UNITTEST_COLOR}Testing sign_customer_cert.sh${NO_COLOR}"
    utecho ""
    # generate key
    openssl genrsa -out "${UNITTEST_WORKINGDIR}/tmp/signonly.key.pem" 2048
    # generate csr
    cp "${UNITTEST_WORKINGDIR}/ca_config/issuing_ca_openssl.cnf" "${UNITTEST_WORKINGDIR}/tmp/openssl.signonly.cnf"
    # SANs from CSR are not taken over to the Certificate, see https://www.golinuxcloud.com/openssl-subject-alternative-name/
#    sed -i -e "s/^ *commonName_default *=.*/commonName_default              =signonly.unittest.example.com/" "${UNITTEST_WORKINGDIR}/tmp/openssl.signonly.cnf"
#    sed -i -e "s#^ *\# *crlDistributionPoints *=.*#crlDistributionPoints              =URI:http://example.com/issuing_ca.crl.pem#" "${UNITTEST_WORKINGDIR}/tmp/openssl.signonly.cnf"
#
#    cat >> "${UNITTEST_WORKINGDIR}/tmp/openssl.signonly.cnf" <<END
#
#[ req ]
#req_extensions = req_ext
#
#[req_ext]
#subjectAltName = @alt_names_customer_cert
#
#[alt_names_customer_cert]
#DNS.1 = signonly.unittest.example.com
#DNS.2 = san4.example.com
#DNS.3 = san5.example.com
#END

    openssl req -config "${UNITTEST_WORKINGDIR}/tmp/openssl.signonly.cnf" -key "${UNITTEST_WORKINGDIR}/tmp/signonly.key.pem" -new -sha256 -out "${UNITTEST_WORKINGDIR}/tmp/signonly.csr" -subj "/C=DE/ST=Gallien/L=Gallisches Dorf/O=Die Gallier/CN=signonly.unittest.example.com/emailAddress=certificates@example.com"

    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        "${CODE_BASE}/tests/sign_customer_cert.sh.expect"
    )

    SEARCHCOUNT=$(grep -c '\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-' "${UNITTEST_WORKINGDIR}/customer_certs/signonly.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem")
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/signonly.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should be a CERTIFICATE in PEM format, but seems not to be" "1" "${SEARCHCOUNT}"
}

testSignOnlyCertDer() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking files created with sign_customer_cert.sh${NO_COLOR}"
    utecho ""
    openssl x509 -in "${UNITTEST_WORKINGDIR}/customer_certs/signonly.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der" -inform DER -noout
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/signonly.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der should be a Certificate in DER format, but seems not to be. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testSignOnlyCertVerifyAgainstCaAndCrl() {
    openssl verify -crl_check_all -CAfile "${UNITTEST_WORKINGDIR}/ca_certs/ca_chain_plus_crl.cert.pem" "${UNITTEST_WORKINGDIR}/customer_certs/signonly.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem"
    EXIT_CODE=$?
    assertEquals "${UNITTEST_WORKINGDIR}/customer_certs/signonly.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should be able to be verified against CA and CRL, but is not. Return Code of openssl command" "0" "${EXIT_CODE}"
}

testHookScriptSignCustomerCertPre() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/sign_customer_cert.sh.pre"
    EXIT_CODE=$?
    assertEquals "Pre Hook for sign_customer_cert.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/sign_customer_cert.sh.pre - return code" "0" "${EXIT_CODE}"
}
testHookScriptSignCustomerCertPost() {
    test -f "${UNITTEST_WORKINGDIR}/tmp/sign_customer_cert.sh.post"
    EXIT_CODE=$?
    assertEquals "Post Hook for sign_customer_cert.sh should have been executed, but was not: no file ${UNITTEST_WORKINGDIR}/tmp/sign_customer_cert.sh.post - return code" "0" "${EXIT_CODE}"
}

testShowSslFileHelp() {
    utecho ""
    utecho "${UNITTEST_COLOR}Checking show_ssl_file.sh${NO_COLOR}"
    utecho ""
    CMDOUT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" -h | grep '<FILE>')
    assertNotNull "show_ssl_file.sh -h should contain the string '<FILE>'" "${CMDOUT}"
}

testShowSslFileCertPem() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem" | grep -c 'Subject: C = DE, ST = Gallien, L = Gallisches Dorf, O = Die Gallier, CN = multisan.unittest.example.com, emailAddress = certificates@example.com')
    assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh ${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.pem should display a certain subject, but seems not to. Count" "1" "${SEARCHCOUNT}"
}

testShowSslFileCertDer() {
    "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der"
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der" | grep -c 'Subject: C = DE, ST = Gallien, L = Gallisches Dorf, O = Die Gallier, CN = multisan.unittest.example.com, emailAddress = certificates@example.com')
    assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh ${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.cert.der should display a certain subject, but seems not to. Count" "1" "${SEARCHCOUNT}"
}

testShowSslFileCertP12() {
    cp "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.p12" "${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.p12"
    (
        cd "${UNITTEST_WORKINGDIR}" || fail "unable to change to ${UNITTEST_WORKINGDIR}"
        SEARCHCOUNT=$("${CODE_BASE}/tests/show_ssl_file.sh-p12.expect" | grep -c 'subject=C = DE, ST = Gallien, L = Gallisches Dorf, O = Die Gallier, CN = multisan.unittest.example.com, emailAddress = certificates@example.com')
        assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh ${UNITTEST_WORKINGDIR}/customer_certs/multisan.unittest.example.com.p12 should display a certain subject, but seems not to. Count" "1" "${SEARCHCOUNT}"
    )
}

testShowSslFilePrivateKey() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" "${UNITTEST_WORKINGDIR}/customer_private_keys/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.key.pem" | grep -E -c "\-\-\-\-\-BEGIN (RSA )?PRIVATE KEY\-\-\-\-\-")
    assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh ${UNITTEST_WORKINGDIR}/customer_private_keys/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.key.pem should display a private key, but seems not to. Count" "1" "${SEARCHCOUNT}"
}

testShowSslFileCsr() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" "${UNITTEST_WORKINGDIR}/csr/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.csr" | grep -c 'Subject: C = DE, ST = Gallien, L = Gallisches Dorf, O = Die Gallier, CN = multisan.unittest.example.com, emailAddress = certificates@example.com')
    assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh ${UNITTEST_WORKINGDIR}/csr/multisan.unittest.example.com.${CUSTOMER_CERT_DATE_EXTENSION}.csr should display a certain subject, but seems not to. Count" "1" "${SEARCHCOUNT}"
}

testShowSslFileCrl() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem" | grep -A 1 "Revoked Certificates:" | grep -c "Serial Number:")
    assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh ${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem should display one revoked certificate. Count" "1" "${SEARCHCOUNT}"
}

testShowSslFileCrlMinusN() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" -n "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem" | grep -A 1 "Revoked Certificates:" | grep -c "Serial Number:")
    assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh -n ${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem should display one revoked certificate. Count" "1" "${SEARCHCOUNT}"
}

testShowSslFileCrlMinusP() {
    SEARCHCOUNT=$("${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh" -p "${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem" | grep -A 1 "Revoked Certificates:" | grep -c "Serial Number:")
    assertEquals "${UNITTEST_WORKINGDIR}/bin/show_ssl_file.sh -p ${UNITTEST_WORKINGDIR}/crl/issuing_ca.crl.pem should display one revoked certificate. Count" "1" "${SEARCHCOUNT}"
}


#
# run the Unit Tests with shunit2
#
# shellcheck source=/dev/null
. "${SHUNIT2}"

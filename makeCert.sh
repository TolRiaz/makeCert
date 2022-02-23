#!/bin/bash

# Define directory
CERTS_DIR=certs
ROOT_DIR=${CERTS_DIR}/root
CA_DIR=${CERTS_DIR}/ca
PKI_DIR=${CERTS_DIR}/pki
MY_DIR=${CERTS_DIR}/my

# Certs configuration
ROOT_ALIAS=root
ROOT_KEYSTORE=${ROOT_DIR}/${ROOT_ALIAS}.jks
ROOT_CERT=${ROOT_DIR}/${ROOT_ALIAS}.pem

CA_ALIAS=ca
CA_KEYSTORE=${CA_DIR}/${CA_ALIAS}.jks
CA_CERT=${CA_DIR}/${CA_ALIAS}.pem

PKI_ALIAS=pki
PKI_KEYSTORE=${PKI_DIR}/${PKI_ALIAS}.jks
PKI_CERT=${PKI_DIR}/${PKI_ALIAS}.pem

MY_ALIAS=craftx
MY_KEYSTORE=${MY_DIR}/${MY_ALIAS}.jks
MY_CERT=${MY_DIR}/${MY_ALIAS}.pem

# Certs info
PASSWORD=p@ssw0rd

rm -rf certs 2> /dev/null
mkdir ${CERTS_DIR} ${ROOT_DIR} ${CA_DIR} ${PKI_DIR} ${MY_DIR} 

echo "===================================================="
echo "Creating fake third-party chain root -> ca"
echo "===================================================="

# generate private keys (for root and ca)

keytool -genkeypair -alias ${ROOT_ALIAS} -dname "cn=Local Network - Development" -validity 10000 -keyalg RSA -keysize 2048 -ext bc:c -keystore ${ROOT_KEYSTORE} -keypass ${PASSWORD} -storepass ${PASSWORD}
keytool -genkeypair -alias ${CA_ALIAS} -dname "cn=Local Network - Development" -validity 10000 -keyalg RSA -keysize 2048 -ext bc:c -keystore ${CA_KEYSTORE} -keypass ${PASSWORD} -storepass ${PASSWORD}

# generate root certificate

keytool -exportcert -rfc -keystore ${ROOT_KEYSTORE} -alias ${ROOT_ALIAS} -storepass ${PASSWORD} > ${ROOT_CERT}

# generate a certificate for ca signed by root (root -> ca)

keytool -keystore ${CA_KEYSTORE} -storepass ${PASSWORD} -certreq -alias ${CA_ALIAS} \
	| keytool -keystore ${ROOT_KEYSTORE} -storepass ${PASSWORD} -gencert -alias ${ROOT_ALIAS} -ext bc=0 -ext san=dns:ca -rfc > ${CA_CERT}

# import ca cert chain into ${CA_KEYSTORE}

keytool -keystore ${CA_KEYSTORE} -storepass ${PASSWORD} -importcert -trustcacerts -noprompt -alias ${ROOT_ALIAS} -file ${ROOT_CERT}
keytool -keystore ${CA_KEYSTORE} -storepass ${PASSWORD} -importcert -alias ${CA_ALIAS} -file ${CA_CERT}

echo  "===================================================================="
echo  "Fake third-party chain generated. Now generating ${PKI_KEYSTORE} ..."
echo  "===================================================================="

# generate private keys (for server)

keytool -genkeypair -alias ${PKI_ALIAS} -dname cn=server -validity 10000 -keyalg RSA -keysize 2048 -keystore ${PKI_KEYSTORE} -keypass ${PASSWORD} -storepass ${PASSWORD}

# generate a certificate for server signed by ca (root -> ca -> server)

keytool -keystore ${PKI_KEYSTORE} -storepass ${PASSWORD} -certreq -alias ${PKI_ALIAS} \
	| keytool -keystore ${CA_KEYSTORE} -storepass ${PASSWORD} -gencert -alias ${CA_ALIAS} -ext ku:c=dig,keyEnc -ext "san=dns:localhost,ip:192.1.1.18" -ext eku=sa,ca -rfc > ${PKI_CERT}

# import server cert chain into ${PKI_KEYSTORE}

keytool -keystore ${PKI_KEYSTORE} -storepass ${PASSWORD} -importcert -trustcacerts -noprompt -alias ${ROOT_ALIAS} -file ${ROOT_CERT}
keytool -keystore ${PKI_KEYSTORE} -storepass ${PASSWORD} -importcert -alias ${CA_ALIAS} -file ${CA_CERT}
keytool -keystore ${PKI_KEYSTORE} -storepass ${PASSWORD} -importcert -alias ${PKI_ALIAS} -file ${PKI_CERT}

echo "====================================================="
echo "Keystore generated. Now generating ${MY_KEYSTORE} ..."
echo "====================================================="

# import my cert chain into ${MY_KEYSTORE}

keytool -keystore ${MY_KEYSTORE} -storepass ${PASSWORD} -importcert -trustcacerts -noprompt -alias ${ROOT_ALIAS} -file ${ROOT_CERT}
keytool -keystore ${MY_KEYSTORE} -storepass ${PASSWORD} -importcert -alias ${CA_ALIAS} -file ${CA_CERT}
keytool -keystore ${MY_KEYSTORE} -storepass ${PASSWORD} -importcert -alias ${PKI_ALIAS} -file ${PKI_CERT}

# delete my self-signed certs
keytool -delete -keystore ${MY_KEYSTORE} -storepass ${PASSWORD} -alias ${ROOT_ALIAS}
keytool -delete -keystore ${MY_KEYSTORE} -storepass ${PASSWORD} -alias ${CA_ALIAS}

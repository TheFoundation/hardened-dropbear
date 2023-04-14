# hardened-dropbear
Hardened Dropbear with weaknesses disabled .. (hopefully )weekly built 

## Installation (samples)

### Ubuntu
```
export OSVER=$((head -n1 /etc/lsb-release;echo "-" ;head -n3 /etc/lsb-release |tail -n1)|cut -d "=" -f2|tr  '[:upper:]' '[:lower:]'|tr -d '\n')
export DROPBEAR_VERSION=$(curl -s "https://github.com/TheFoundation/hardened-dropbear/releases"|grep expanded_assets|grep 'src="https://github.com/'|sed 's/.\+expanded_assets\/v//g;s/".\+//g'|head -n1);
export DOWNLOAD_URL="https://github.com/TheFoundation/hardened-dropbear/releases/download/v$DROPBEAR_VERSION/hardened-dropbear-$OSVER."$(_buildx_arch |sed 's~/~_~g')
```


### Alpine
```
export OSVER=alpine
export DROPBEAR_VERSION=$(curl -s "https://github.com/TheFoundation/hardened-dropbear/releases"|grep expanded_assets|grep 'src="https://github.com/'|sed 's/.\+expanded_assets\/v//g;s/".\+//g'|head -n1);
export DOWNLOAD_URL="https://github.com/TheFoundation/hardened-dropbear/releases/download/v$DROPBEAR_VERSION/hardened-dropbear-$OSVER."$(_buildx_arch |sed 's~/~_~g')
```


## Configs: 

```
#define DROPBEAR_AES128 0
#define DROPBEAR_DEFAULT_RSA_SIZE 4096
#define DROPBEAR_DSS 0
#define DROPBEAR_AES256 1
#define DROPBEAR_TWOFISH256 0
#define DROPBEAR_TWOFISH128 0
#define DROPBEAR_CHACHA20POLY1305 1
#define DROPBEAR_ENABLE_CTR_MODE 1
#define DROPBEAR_ENABLE_CBC_MODE 0
#define DROPBEAR_ENABLE_GCM_MODE 1
#define DROPBEAR_MD5_HMAC 0
#define DROPBEAR_SHA1_HMAC 0
#define DROPBEAR_SHA2_256_HMAC 1
#define DROPBEAR_SHA1_96_HMAC 0
#define DROPBEAR_ECDSA 1
#define DROPBEAR_DH_GROUP14_SHA1 0
#define DROPBEAR_DH_GROUP14_SHA256 1
#define DROPBEAR_DH_GROUP16 0
#define DROPBEAR_CURVE25519 1
#define DROPBEAR_ECDH 0
#define DROPBEAR_DH_GROUP1 0
#define DROPBEAR_DH_GROUP1_CLIENTONLY 0
```

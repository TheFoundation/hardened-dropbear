#!/bin/bash
test -e /ccache.tgz  && ( echo  "loading ccache "$(cd / ;tar xvzf /ccache.tgz|wc -l )"... files" )
test -e /tmp/ccache.$(uname -m).tgz && ( echo "loading arch cache"$(cd / ;tar xvzf /tmp/ccache.$(uname -m).tgz|wc -l )"... files" )
test -e "$HOME"/.ccache||mkdir "$HOME"/.ccache
test -e "$HOME"/.ccache/ccache.conf || ( echo 'max_size = 1.0G' >> "$HOME"/.ccache/ccache.conf )
which apk && apk add ccache gcc make autoconf ca-certificates git zlib-dev libc-dev

test -e /tmp/.beardef.h  && rm /tmp/.beardef.h  

beartarget=/usr/src/dropbear
cd /tmp/ 
test -e "$beartarget" ||  git clone https://github.com/mkj/dropbear.git $beartarget 
test -e "$beartarget" && cd  "$beartarget" && git pull 


cd "$beartarget/src/" && echo varsetup && ( 
echo '
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
' |grep -v ^$ > /tmp/.bear_configvars )
test -e /tmp/.bear_configvars || exit 10

cd /$beartarget || exit 10

echo -n replacing" " && for var in $(cut -d" " -f2 /tmp/.bear_configvars);do 
        echo "|"$var"|";
        sed 's/.\+'$var'.\+//g' $beartarget/src/default_options.h -i ;done && (
            mv $beartarget/src/default_options.h /tmp/.beardef.h 
        )

test -e /tmp/.beardef.h || exit 20

( cat /tmp/.beardef.h  /tmp/.bear_configvars  ) >  $beartarget/src/default_options.h 
tail -n 1 "/$beartarget/src/default_options.h"|grep -q "$(tail -n 1 /tmp/.bear_configvars)" || echo "SNIPPET NOT FOUND..exit"
tail -n 1 "/$beartarget/src/default_options.h"|grep -q "$(tail -n 1 /tmp/.bear_configvars)" || exit 30

export PREFIX=/usr
export CC='ccache gcc'

echo CONFIG_AUTOMAKE
( cd "/$beartarget" && pwd && autoconf 2>&1  &&  autoheader  2>&1 && autoreconf -i 2>&1 )| tee /tmp/.autoconfres|sed 's/$/ → /g'|tr -d '\n'  
grep -e error: /tmp/.autoconfres && exit 123

echo CONFIG_configure
( cd "/$beartarget" && pwd &&  ccache ./configure --prefix=$PREFIX --enable-plugin  --enable-bundled-libtom 2>&1 ) | tee /tmp/.configureres |sed 's/$/ → /g'|tr -d '\n'  

#grep -e error: /tmp/.configureres && exit 124
echo BUILD
time ( cd "/$beartarget" ;  make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert " -j$(($(nproc)+2)) 2>/tmp/builderr 1>/tmp/buildlog )
echo INSTALL
PFX=""
which sudo  && {  (id -u|grep ^0$ ) || PFX=sudo ; } ;
installresult=$(bash -c $PFX' make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp"   SCPPROGRESS=1  install ' 2>&1)
echo "#####"
echo "##### BUILD OUTPUT"
echo "###############################################"
echo "$installresult"
echo "###############################################"

KEEPFILES=$(echo "$installresult"|grep ^install|grep -v '^install -'|while read line;do file=$(echo "$line"|cut -d" " -f2);dir=$(echo "$line"|cut -d" " -f3);echo $dir"/"$file;done )
echo "$KEEPFILES"
[[ -z "$KEEPFILES" ]] || $PFX tar cvzf /binaries.tgz $KEEPFILES

[[ "$(id -u)" = "0" ]] &&  [[ -z "$HOME" ]] && HOME="/root"
test -e /ccache.tgz  && rm /ccache.tgz  
echo "###############################################"
 
#find /|grep ccache
#echo "$HOME" 
#ls "$HOME"/.ccache
caches=$($PFX find /root/ /home/*/ -maxdepth 1 -name .ccache  -type d)
[[ -z "$caches" ]] || (
    echo "saving ccache: "$(bash -c "$PFX tar cvzf /tmp/ccache."$(uname -m)".tgz $caches"| wc -l)" files..."
    echo "saving buildcache: "$(tar cvzf /ccache.tgz "$beartarget" /tmp/ccache.$(uname -m).tgz| wc -l)" files..."
 )

tar tvzf /binaries.tgz 
echo  "SIZE_KBYTE:"
du -k /binaries.tgz 

test -e /ccache.tgz  && du -k /ccache.tgz 

(echo "$installresult"|grep -q "install dropbear /")|| exit 222
exit 0

# || exit 222

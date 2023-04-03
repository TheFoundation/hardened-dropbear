#!/bin/bash
[[ -z "$1" ]] || IMAGETAGS=$1
[[ -z "$2" ]] || ARCHLIST=$( echo "$2"|sed 's~_SLASH_~/~g')


[[ -z "$PLATFORMS_ALPINE" ]] || BUILD_TARGET_PLATFORMS=$PLATFORMS_ALPINE
[[ -z "$BUILD_TARGET_PLATFORMS" ]] && BUILD_TARGET_PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"

_platform_tag() { echo "$1"|sed 's~/~_~g' ;};
_oneline()               { tr -d '\n' ; } ;
_buildx_arch()           { case "$(uname -m)" in aarch64) echo linux/arm64;; x86_64) echo linux/amd64 ;; armv7l|armv7*) echo linux/arm/v7;; armv6l|armv6*) echo linux/arm/v6;;  esac ; } ;

test -e dropbear-src || git clone https://github.com/mkj/dropbear.git dropbear-src

mkdir builds
startdir=$(pwd)

#IMAGETAG_SHORT=alpine
[[ -z "$IMAGETAGS" ]] && IMAGETAGS="alpine ubuntu-focal ubuntu-bionic"
for IMAGETAG_SHORT in $IMAGETAGS;do
REGISTRY_HOST=ghcr.io
REGISTRY_PROJECT=thefoundation-builder
PROJECT_NAME=hardened-dropbear
[[ -z "$GH_IMAGE_NAME" ]] && IMAGETAG=${REGISTRY_HOST}/${REGISTRY_PROJECT}/${PROJECT_NAME}:${IMAGETAG_SHORT}
[[ -z "$GH_IMAGE_NAME" ]] || IMAGETAG="$GH_IMAGE_NAME":${IMAGETAG_SHORT}




#docker build . --progress plain -f Dockerfile.alpine -t $IMAGETAG
[[ -z "$ARCHLIST" ]] && ARCHLIST=$(echo $BUILD_TARGET_PLATFORMS |sed 's/,/ /g') 
for BUILDARCH in $ARCHLIST;do
TARGETARCH=$(_platform_tag $BUILDARCH  )
TARGETDIR=builds/${IMAGETAG_SHORT}"_"$TARGETARCH
echo "building to "$TARGETDIR
mkdir -p "$TARGETDIR"
cd "$TARGETDIR"
mkdir build
(
    cd build
    cp ${startdir}/build-bear.sh . -v
    test -e ccache.tgz && rm ccache.tgz
    docker export $(docker create --name cicache_${IMAGETAG//[:\/]/_}_${TARGETARCH} ${IMAGETAG}_${TARGETARCH}_builder /bin/false ) |tar xv ccache.tgz ;docker rm cicache_${IMAGETAG//[:\/]/_}_${TARGETARCH}
     test -e ccache.tgz ||    (  (echo FROM ${IMAGETAG}_${TARGETARCH};echo RUN echo yocacheme) | time docker buildx build  --output=type=local,dest=/tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder  --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH}   --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH}_builder $buildstring -f - ) ;
     test -e /tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder && test -e /tmp/buildout_${IMAGETAG}_${TARGETARCH}/ccache.tgz && mv /tmp/buildout_${IMAGETAG}_${TARGETARCH}/ccache.tgz .
     test -e /tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder && rm -rf "/tmp/buildout_${IMAGETAG}_${TARGETARCH}"    
    test -e ccache.tgz || ( mkdir .tmpempty ;echo 123 .tmpempty/file;tar cvzf ccache.tgz .tmpempty )
    test -e dropbear-src || cp -rau ${startdir}/dropbear-src .
    test -e .tmpempty && rm -rf .tmpempty
)

buildstring=build
DFILENAME=$startdir/Dockerfile.${IMAGETAG_SHORT}
echo "singlearch-build for "$BUILDARCH
echo time docker buildx build  --output=type=registry,push=true --push   --pull --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH}_builder $buildstring -f "${DFILENAME}" 
     (
     test -e binaries.tgz && rm binaries.tgz
     ## first image named _baseimage does only apt/apk installs
     grep -v -e COPY -e build-bear "${DFILENAME}"  > "${DFILENAME}_baseimage" 
     time docker buildx build  --output=type=registry,push=true --push  --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache_baseimage --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache_baseimage --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH}_baseimage $buildstring -f "${DFILENAME}_baseimage" ;
     
     # second image name _builder is the full thingy ( will be large . .)
     ( echo "FROM ${IMAGETAG}_${TARGETARCH}_baseimage";grep -v -e ^FROM -e "apk add" -e "apt " -e "apt-get" "${DFILENAME}")  > "${DFILENAME}_real" 
     
     time docker buildx build  --output=type=registry,push=true --push  --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH}_builder $buildstring -f "${DFILENAME}_real"  ;
     docker rmi ${IMAGETAG}_${TARGETARCH}_builder
     ### our arch ..
     docker export $(docker create --name cicache_${IMAGETAG//[:\/]/_}_${TARGETARCH} ${IMAGETAG}_${TARGETARCH}_builder /bin/false ) |tar xv binaries.tgz ;docker rm cicache_${IMAGETAG//[:\/]/_}_${TARGETARCH};docker rmi ${IMAGETAG}_${TARGETARCH}
##### multi arch
     test -e binaries.tgz ||    (  time docker buildx build  --output=type=local,dest=/tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder   --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH}   --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH}_builder $buildstring -f "${DFILENAME}" ) ;
     test -e /tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder && test -e /tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder/binaries.tgz && mv /tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder/binaries.tgz .
     test -e /tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder && rm -rf "/tmp/buildout_${IMAGETAG}_${TARGETARCH}_builder"
     test -e binaries.tgz || echo "ERROR: NO BINARIES"
### final (prod) image
     test -e binaries.tgz && cp binaries.tgz build/hardened-dropbear-$IMAGETAG_SHORT.$TARGETARCH.tar.gz &&  (  (grep ^FROM "${DFILENAME}" |tail -n1;echo "ADD hardened-dropbear-$IMAGETAG_SHORT.$TARGETARCH.tar.gz /";echo "RUN dropbear --help|grep -e ommand -e assword"  ) |time docker buildx build  --output=type=registry,push=true --push  --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH}  -t  ${IMAGETAG}_${TARGETARCH} $buildstring -f - );
     test -e binaries.tgz && mv binaries.tgz ${startdir}/hardened-dropbear-$IMAGETAG_SHORT.$TARGETARCH.tar.gz
     
    ) &
     

done
done
wait 
df -m
docker image ls|grep $IMAGETAG_SHORT
cd "${startdir}"
#find |grep tar.gz |grep hardened-dropbear || exit 1
find |grep tar.gz |grep hardened-dropbear ||exit 0
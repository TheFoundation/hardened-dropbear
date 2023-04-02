#!/bin/bash
[[ -z "$PLATFORMS_ALPINE" ]] || BUILD_TARGET_PLATFORMS=$PLATFORMS_ALPINE
[[ -z "$BUILD_TARGET_PLATFORMS" ]] && BUILD_TARGET_PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"

_platform_tag() { echo "$1"|sed 's~/~_~g' ;};
_oneline()               { tr -d '\n' ; } ;
_buildx_arch()           { case "$(uname -m)" in aarch64) echo linux/arm64;; x86_64) echo linux/amd64 ;; armv7l|armv7*) echo linux/arm/v7;; armv6l|armv6*) echo linux/arm/v6;;  esac ; } ;

test -e dropbear-src || git clone https://github.com/mkj/dropbear.git dropbear-src

mkdir builds
startdir=$(pwd)

#IMAGETAG_SHORT=alpine
for IMAGETAG_SHORT in alpine ubuntu-focal ubuntu-bionic;do
REGISTRY_HOST=ghcr.io
REGISTRY_PROJECT=thefoundation-builder
PROJECT_NAME=hardened-dropbear
[[ -z "$GH_IMAGE_NAME" ]] && IMAGETAG=${REGISTRY_HOST}/${REGISTRY_PROJECT}/${PROJECT_NAME}:${IMAGETAG_SHORT}
[[ -z "$GH_IMAGE_NAME" ]] || IMAGETAG="$GH_IMAGE_NAME":${IMAGETAG_SHORT}




#docker build . --progress plain -f Dockerfile.alpine -t $IMAGETAG
for BUILDARCH in $(echo $BUILD_TARGET_PLATFORMS |sed 's/,/ /g') ;do
TARGETARCH=$(_platform_tag $BUILDARCH  )
TARGETDIR=builds/$TARGETARCH
echo "building to "$TARGETDIR
mkdir -p "$TARGETDIR"
cd "$TARGETDIR"
mkdir build
(
    cd build
    cp ${startdir}/build-bear.sh . -v
    test -e ccache.tgz && rm ccache.tgz
    docker export $(docker create --name cicache ${IMAGETAG}_${TARGETARCH} /bin/false ) |tar xv ccache.tgz ;docker rm cicache
    test -e ccache.tgz || ( mkdir .tmpempty ;echo 123 .tmpempty/file;tar cvzf ccache.tgz .tmpempty )
    test -e dropbear-src || cp -rau ${startdir}/dropbear-src .
    test -e .tmpempty && rm -rf .tmpempty
)

buildstring=build
DFILENAME=$startdir/Dockerfile.${IMAGETAG_SHORT}
echo "singlearch-build for "$BUILDARCH
echo time docker buildx build  --output=type=registry,push=true --push   --pull --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH} $buildstring -f "${DFILENAME}" 
     (
    test -e binaries.tgz && rm binaries.tgz
     docker rmi ${IMAGETAG}_${TARGETARCH}
     time docker buildx build  --output=type=registry,push=true --push  --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH} $buildstring -f "${DFILENAME}" ;
     docker export $(docker create --name cicache ${IMAGETAG}_${TARGETARCH} /bin/false ) |tar xv binaries.tgz ;docker rm cicache
     test -e binaries.tgz && mv binaries.tgz ${startdir}/hardened-dropbear.$IMAGETAG_SHORT.$TARGETARCH.tar.gz
    ) &
     

done
done
wait 

find |grep tar.gz |grep release || exit 1
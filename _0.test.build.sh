#!/bin/bash
[[ -z "$BUILD_TARGET_PLATFORMS" ]] && BUILD_TARGET_PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"

_platform_tag() { echo "$1"|sed 's~/~_~g' ;};
_oneline()               { tr -d '\n' ; } ;
_buildx_arch()           { case "$(uname -m)" in aarch64) echo linux/arm64;; x86_64) echo linux/amd64 ;; armv7l|armv7*) echo linux/arm/v7;; armv6l|armv6*) echo linux/arm/v6;;  esac ; } ;

IMAGETAG_SHORT=alpine
REGISTRY_HOST=ghcr.io
REGISTRY_PROJECT=thefoundation-builder
PROJECT_NAME=hardened-dropbear
[[ -z "$GH_IMAGE_NAME" ]] && IMAGETAG=${REGISTRY_HOST}/${REGISTRY_PROJECT}/${PROJECT_NAME}:${IMAGETAG_SHORT}
[[ -z "$GH_IMAGE_NAME" ]] || IMAGETAG="$GH_IMAGE_NAME":${IMAGETAG_SHORT}



mkdir builds


#docker build . --progress plain -f Dockerfile.alpine -t $IMAGETAG
ALLARCH=$(_buildx_arch)
for BUILDARCH in $ALLARCH ;do
TARGETARCH=$(_platform_tag $BUILDARCH  )
TARGETDIR=builds/$TARGETARCH
echo "building to "$TARGETDIR
mkdir -p "$TARGETDIR"
startdir=$(pwd)
cd "$TARGETDIR"
mkdir build
(
    cd build
    cp ${startdir}/build-bear.sh . -v
    test -e ccache.tgz && rm ccache.tgz
    docker export $(docker create --name cicache $IMAGETAG /bin/false ) |tar xv ccache.tgz ;docker rm cicache
    test -e ccache.tgz || ( mkdir .tmpempty ;echo 123 .tmpempty/file;tar cvzf ccache.tgz .tmpempty )
    test -e dropbear-src || git clone https://github.com/mkj/dropbear.git dropbear-src
    test -e .tmpempty && rm -rf .tmpempty
)

buildstring=build
DFILENAME=$startdir/Dockerfile.alpine
echo "singlearch-build for "$BUILDARCH
echo time docker buildx build  --output=type=registry,push=true --push   --pull --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH} $buildstring -f "${DFILENAME}" 
     time docker buildx build  --output=type=registry,push=true --push   --pull --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH} $buildstring -f "${DFILENAME}" 


done
#TARGETARCH=$BUILD_TARGET_PLATFORMS

#time docker buildx build  --output=type=registry,push=true  --push  --pull --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${TARGETARCH} --cache-from ${IMAGETAG} -t  ${IMAGETAG} $buildstring -f "${DFILENAME}" 

for BUILDARCH in $(echo $BUILD_TARGET_PLATFORMS |sed 's/,/ /g');do
TARGETARCH=$(_platform_tag $BUILDARCH  )
TARGETDIR=builds/$TARGETARCH
echo "building to "$TARGETDIR
mkdir -p "$TARGETDIR"
startdir=$(pwd)
cd "$TARGETDIR"
mkdir build
(
    cd build
    cp ${startdir}/build-bear.sh . -v
    test -e ccache.tgz && rm ccache.tgz
    docker export $(docker create --name cicache $IMAGETAG /bin/false ) |tar xv ccache.tgz ;docker rm cicache
    test -e ccache.tgz || ( mkdir .tmpempty ;echo 123 .tmpempty/file;tar cvzf ccache.tgz .tmpempty )
    test -e dropbear-src || git clone https://github.com/mkj/dropbear.git dropbear-src
    test -e .tmpempty && rm -rf .tmpempty
)

buildstring=build
DFILENAME=$startdir/Dockerfile.alpine
echo "build for "$BUILDARCH
echo time docker buildx build  --output=type=registry,push=true --push   --pull --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH} $buildstring -f "${DFILENAME}" 
time docker buildx build  --output=type=registry,push=true --push   --pull --progress plain --network=host --memory-swap -1 --memory 1024 --platform=${BUILDARCH} --cache-to ${IMAGETAG}_${TARGETARCH}_buildcache  --cache-from ${IMAGETAG}_${TARGETARCH}_buildcache -t  ${IMAGETAG}_${TARGETARCH} $buildstring -f "${DFILENAME}" &

done
wait
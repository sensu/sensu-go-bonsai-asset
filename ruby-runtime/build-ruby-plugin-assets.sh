#!/bin/bash
##
# General asset build script
##
[[ -z "$WDIR" ]] && { echo "WDIR is empty using bonsai/" ; WDIR="bonsai/"; }

[[ -z "$GITHUB_TOKEN" ]] && { echo "GITHUB_TOKEN is empty" ; exit 1; }
[[ -z "$1" ]] && { echo "Parameter 1, GEM_NAME is empty" ; exit 1; }
[[ -z "$2" ]] && { echo "Parameter 2, GIT_OWNER_REPO is empty" ; exit 1; }
[[ -z "$3" ]] && { echo "Parameter 3, GIT_REF is empty" ; exit 1; }

GEM_NAME=$1
GIT_OWNER_REPO=$2
GIT_REF=$3
GITHUB_RELEASE_TAG=$4
TAG=$GITHUB_RELEASE_TAG
[[ -z "$TAG" ]] && { echo "GITHUB_RELEASE_TAG is empty" ; TAG="0.0.1"; }
echo $GEM_NAME $GIT_OWNER_REPO $TAG $GIT_REF

mkdir dist
GIT_REPO="https://github.com/${GIT_OWNER_REPO}.git"


if [ -d dist ]; then
  # Build Debian asset
  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-debian -f ${WDIR}/ruby-runtime/Dockerfile.debian .
  docker cp $(docker create --rm ruby-plugin-debian:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_debian_linux_amd64.tar.gz

  # Build Alpine asset
  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-alpine:latest -f ${WDIR}/ruby-runtime/Dockerfile.alpine .
  docker cp $(docker create --rm ruby-plugin-alpine:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_alpine_linux_amd64.tar.gz

  # Build CentOS asset
  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-centos:latest -f ${WDIR}/ruby-runtime/Dockerfile.centos .
  docker cp $(docker create --rm ruby-plugin-centos:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_centos_linux_amd64.tar.gz

  # Generate the sha512sum for all the assets
  files=$( ls dist/*.tar.gz )
  echo $files
  for filename in $files; do
    if [[ "$GITHUB_RELEASE_TAG" ]]; then
      echo "upload $filename"
      ${WDIR}/github-release-upload.sh github_api_token=$GITHUB_TOKEN repo_slug="$GIT_OWNER_REPO" tag="${GITHUB_RELEASE_TAG}" filename="$filename"
    fi
  done 
  file=$(basename "${files[0]}")
  IFS=_ read -r package leftover <<< "$file"
  unset leftover
  if [ -n "$package" ]; then
    echo "Generating sha512sum for ${package}"
    cd dist || exit
    sha512_file="${package}_${TAG}_sha512-checksums.txt"
    #echo "${sha512_file}" > sha512_file
    echo "sha512_file: ${sha512_file}"
    sha512sum ./*.tar.gz > "${sha512_file}"
    echo ""
    cat "${sha512_file}"
    cd ..
    if [[ "$GITHUB_RELEASE_TAG" ]]; then
      echo "upload ${sha512_file}"
      ${WDIR}/github-release-upload.sh github_api_token=$GITHUB_TOKEN repo_slug="$GIT_OWNER_REPO" tag="${GITHUB_RELEASE_TAG}" filename="dist/${sha512_file}"
    fi
  fi

else
  echo "error dist directory is missing"
fi


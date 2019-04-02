#!/bin/bash

##
# TravisCI specific asset build script.
#   Uses several TravisCI specific environment variables 
##
[[ -z "$GITHUB_TOKEN" ]] && { echo "GITHUB_TOKEN is empty" ; exit 1; }
[[ -z "$1" ]] && { echo "Parameter 1, GEM_NAME is empty" ; exit 1; }
[[ -z "$TRAVIS_REPO_SLUG" ]] && { echo "TRAVIS_REPO_SLUG is empty" ; exit 1; }
[[ -z "$TRAVIS_COMMIT" ]] && { echo "TRAVIS_COMMIT is empty" ; exit 1; }

GEM_NAME=$1
TAG=$TRAVIS_TAG
[[ -z "$TAG" ]] && { echo "TRAVIS_TAG is empty" ; TAG="0.0.1"; }
echo $GEM_NAME $TRAVIS_REPO_SLUG $TAG $TRAVIS_COMMIT

mkdir dist
GIT_REPO="https://github.com/${TRAVIS_REPO_SLUG}.git"
GIT_REF=${TRAVIS_COMMIT}


if [ -d dist ]; then
  # Build Debian asset
  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-debian -f Dockerfile.debian .
  docker cp $(docker create --rm ruby-plugin-debian:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_debian_linux_amd64.tar.gz

  # Build Alpine asset
  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-alpine:latest -f Dockerfile.alpine .
  docker cp $(docker create --rm ruby-plugin-alpine:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_alpine_linux_amd64.tar.gz

  # Build CentOS asset
  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-centos:latest -f Dockerfile.centos .
  docker cp $(docker create --rm ruby-plugin-centos:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_centos_linux_amd64.tar.gz

  # Generate the sha512sum for all the assets
  files=$( ls dist/*.tar.gz )
  echo $files
  for filename in $files; do
    if [[ "$TRAVIS_TAG" ]]; then
      echo "upload $filename"
      travis/github-release-upload.sh github_api_token=$GITHUB_TOKEN repo_slug="$TRAVIS_REPO_SLUG" tag="${TRAVIS_TAG}" filename="$filename"
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
    if [[ "$TRAVIS_TAG" ]]; then
      echo "upload ${sha512_file}"
      travis/github-release-upload.sh github_api_token=$GITHUB_TOKEN repo_slug="$TRAVIS_REPO_SLUG" tag="${TRAVIS_TAG}" filename="dist/${sha512_file}"
    fi
  fi

else
  echo "error dist directory is missing"
fi


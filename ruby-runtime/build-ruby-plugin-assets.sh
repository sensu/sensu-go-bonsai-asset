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

platforms=( alpine debian alpine3.8 debian9 centos7 centos6 )
ruby_version=2.4.4
if [ -d dist ]; then
  for platform in "${platforms[@]}"
  do

  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-${platform} -f ${WDIR}/ruby-runtime/Dockerfile.${platform} .
  docker cp $(docker create --rm ruby-plugin-${platform}:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_${platform}_linux_amd64.tar.gz

  done

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

  # Generate github release edit event 
  ${WDIR}/github-release-event.sh github_api_token=$GITHUB_TOKEN repo_slug="$GIT_OWNER_REPO" tag="${GITHUB_RELEASE_TAG}" 

else
  echo "error dist directory is missing"
fi


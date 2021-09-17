#!/bin/bash
# Argument 1: GEM name
# Argument 2: comma separated list of platforms to build

[[ -z "$WDIR" ]] && { echo "WDIR is empty using bonsai/" ; WDIR="bonsai/"; }

##
#   Setup parameters
##
[[ -z "$GITHUB_TOKEN" ]] && { echo "GITHUB_TOKEN is empty, upload disabled" ; }
[[ -z "$REPO_SLUG" ]] && { echo "REPO_SLUG is empty"; exit 1; }
[[ -z "$1" ]] && { echo "Parameter 1, GEM_NAME is empty" ; exit 1; }
: ${PLATFORMS:=$2}
IFS=', ' read -r -a platforms <<< ${PLATFORMS:="alpine,alpine3.8,debian,debian9,centos8,centos7,amzn1,amzn2"}


GEM_NAME=$1
TAG=$TRAVIS_TAG
CURRENT_COMMIT=$(git rev-parse HEAD)
[[ -z "$TAG" ]] && { echo "TRAVIS_TAG is empty" ; TAG="0.0.1"; }
[[ -z "$TRAVIS_COMMIT" ]] && { echo "TRAVIS_COMMIT is empty, using current commit" ; TRAVIS_COMMIT=$CURRENT_COMMIT; }
echo $GEM_NAME $TRAVIS_REPO_SLUG $TAG $TRAVIS_COMMIT

mkdir dist
GIT_REPO="https://github.com/${TRAVIS_REPO_SLUG}.git"
GIT_REF=${TRAVIS_COMMIT}

echo "Platforms: ${platforms[@]}"	

if [ -d dist ]; then
  for platform in "${platforms[@]}"
  do
  echo "Building for Platform: $platform"	  
  docker build --build-arg "ASSET_GEM=${GEM_NAME}" --build-arg "GIT_REPO=${GIT_REPO}"  --build-arg "GIT_REF=${GIT_REF}" -t ruby-plugin-${platform} -f "${WDIR}/ruby26-runtime/Dockerfile.${platform}" .
  status=$?
  if test $status -ne 0; then
        echo "Docker build for platform: ${platform} failed with status: ${status}"
        exit 1
  fi

  docker cp $(docker create --rm ruby-plugin-${platform}:latest sleep 0):/${GEM_NAME}.tar.gz ./dist/${GEM_NAME}_${TAG}_${platform}_linux_amd64.tar.gz
  status=$?
  if test $status -ne 0; then
        echo "Docker cp for platform: ${platform} failed with status: ${status}"
        exit 1
  fi
  done

  # Generate the sha512sum for all the assets
  files=$( ls dist/*.tar.gz )
  echo $files
  for filename in $files; do
    if [[ "$TRAVIS_TAG" ]]; then
      if [[ "$GITHUB_TOKEN" ]]; then
        if [[ "$TRAVIS_REPO_SLUG" ]]; then
          echo "upload $filename"
          ${WDIR}/github-release-upload.sh github_api_token=$GITHUB_TOKEN repo_slug="$TRAVIS_REPO_SLUG" tag="${TRAVIS_TAG}" filename="$filename"
        else
	  echo "TRAVIS_REPO_SLUG unset, skipping upload of $filename"      
	fi	 
      else
	echo "GITUB_TOKEN unset, skipping upload of $filename"      
      fi	
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
      if [[ "$GITHUB_TOKEN" ]]; then
        echo "upload ${sha512_file}"
        ${WDIR}/github-release-upload.sh github_api_token=$GITHUB_TOKEN repo_slug="$TRAVIS_REPO_SLUG" tag="${TRAVIS_TAG}" filename="dist/${sha512_file}"
      else
	echo "GITUB_TOKEN unset, skipping upload of ${sha512_file}"      
      fi
    fi
  fi
  # Generate github release edit event 
  ${WDIR}/github-release-event.sh github_api_token=$GITHUB_TOKEN repo_slug="$TRAVIS_REPO_SLUG" tag="${TRAVIS_TAG}"

else
  echo "error dist directory is missing"
fi


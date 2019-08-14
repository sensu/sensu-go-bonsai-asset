#!/usr/bin/env bash
#
# License: MIT
#
#
# This script accepts the following parameters:
#
# * owner
# * repo
# * tag
# * github_api_token
#
# Script to force release edit event using the GitHub API v3.
#
# Uses:
#    grep, tr, jq, curl
#
# Example:
#
# github-release-event.sh github_api_token=TOKEN repo_slug=hey/now tag=v0.1.0
#

# Check dependencies.
set -e

# Set Envvars Defaults:
github_api_token="aaa"
repo_slug="test/test"
tag="0.0.0"
id="0"

# Validate settings.
[ "$TRACE" ] && set -x

CONFIG=( "$@" )

# Update Envvars using cmdline args
for line in "${CONFIG[@]}"; do
  eval "$line"
done



# Define variables.
GH_API="https://api.github.com"
GH_REPO="$GH_API/repos/$repo_slug"
GH_TAGS="$GH_REPO/releases/tags/$tag"
AUTH="Authorization: token $github_api_token"

if [[ "$tag" == 'LATEST' ]]; then
  GH_TAGS="$GH_REPO/releases/latest"
fi

# Validate token.
curl -o /dev/null -sH "$AUTH" "$GH_REPO" || { echo "Error: Invalid repo, token or network issue!";  exit 1; }

# Read asset tags.
echo "curl -sH ${AUTH} ${GH_TAGS}"
response=$(curl -sH "${AUTH}" "${GH_TAGS}")

# Get ID of the asset based on given filename.
unset id
eval "$(echo "$response" | grep -m 1 "id.:" | grep -w id | tr : = | tr -cd '[[:alnum:]]=')"
echo "$id"
[ "$id" ] || { echo "Error: Failed to get release id for tag: $tag"; echo "$response" | awk 'length($0)<100' >&2; exit 1; }
unset body
body=`echo "$response" | jq .body`
echo "$body"
[ "$body" ] || { echo "Error: Failed to get release body for tag: $tag"; echo "$response" | awk 'length($0)<100' >&2; exit 1; }

# Construct url
GH_RELEASE="$GH_REPO/releases/$id"
echo "$GH_RELEASE"
echo "Editting release body"
response=`curl -sS $GITHUB_OAUTH_BASIC -H "Authorization: token $github_api_token" -X PATCH --data "{\"body\": \"Re-publishing\"}" $GH_RELEASE`
sleep 1
echo "Re-setting original release body"
response=`curl -sS $GITHUB_OAUTH_BASIC -H "Authorization: token $github_api_token" -X PATCH --data "{\"body\": ${body}}" $GH_RELEASE`

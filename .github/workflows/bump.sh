#!/bin/bash

# Fetch all Tags from remote
git fetch --all --tags

# get latest tag
latestTag=$(git describe --tags `git rev-list --tags --max-count=1`)

# get current commit hash for tag
commit=$(git rev-parse HEAD)

# Set flag for initial Tag
initialTag="false"

# if there are none, start tags at 1.0.0
if [ -z "$latestTag" ]
then
    log=$(git log --pretty=oneline)
    latestTag=1.0.0
    echo "Initial Tag"
    initialTag="true"
else
    log=$(git log $latestTag..HEAD --pretty=oneline)
    echo "Tags already exist"
fi

# Split Tag version in major, minor and patch
majorVersion=$(echo $latestTag | awk '{split($0,a,".");print a[1]}')
minorVersion=$(echo $latestTag | awk '{split($0,a,".");print a[2]}')
patchVersion=$(echo $latestTag | awk '{split($0,a,".");print a[3]}')

# get commit logs and determine how to bump the version
# supports #major, #minor, #patch (default is 'patch')
case "$log" in
    *#major* )
        echo "inside major"
        majorVersion=$((majorVersion+1))
        minorVersion=0
        patchVersion=0;;
    *#minor* )
        echo "inside minor"
        minorVersion=$((minorVersion+1))
        patchVersion=0;;
    * ) 
        if [ "$initialTag" == "false" ]
        then
            patchVersion=$((patchVersion+1))
        fi;;
esac

# Forming new version for Tag
new="$majorVersion.$minorVersion.$patchVersion"

# Printing out new tag to be created
echo "New Tag to be created - $new"

# POST a new ref to repo via Github API
#curl -s -X POST https://api.github.com/repos/$REPO_OWNER/$repo/git/refs \
curl -s -X POST https://api.github.com/repos/$GITHUB_REPOSITORY/git/refs \
-H "Authorization: token $ACCESS_TOKEN" \
-d @- << EOF
{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF

# Create a release or a pre-release
# Check GIT comments to find keyword "[release]" or "[pre-release]"

# Don't create pre-release by default
createPreRelease=false

if [[ "$log" == *\[pre-release\]* ]]
then
    createPreRelease=true
fi

if [[ "$log" == *\[release\]* || "$log" == *\[pre-release\]* ]]
then
    echo "Going to create"
    curl -s -X POST https://api.github.com/repos/$GITHUB_REPOSITORY/releases \
    -H "Authorization: token $ACCESS_TOKEN" \
    -d @- << EOF
        {
            "tag_name": "$new",
            "prerelease": $createPreRelease
        }
EOF
fi

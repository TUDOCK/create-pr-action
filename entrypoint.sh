#!/bin/sh

set -eu

# Extra variables:
# REPOSITORY
# TITLE
HEAD_BRANCH=${HEAD_BRANCH:-release}
BASE_BRANCH=${BASE_BRANCH:-main}

CREATE_PR_URL=https://api.github.com/repos/$REPOSITORY/pulls

echo "Configuration:"
echo "REPOSITORY $REPOSITORY"
echo "TITLE $TITLE"
echo "HEAD_BRANCH $HEAD_BRANCH"
echo "BASE_BRANCH $BASE_BRANCH"

check_create_PR_response() {
    ERROR="$1"
    if [ "$ERROR" != null ]; then
      PR_EXISTS=$(echo "${ERROR}" | jq 'select(. | contains("A pull request already exists for"))')
      if [ "$PR_EXISTS" != null ]; then
        echo "::info:: PR exists from $HEAD_BRANCH against $BASE_BRANCH"
        exit 0
      else
        echo "::ERROR:: Error in creating PR from $HEAD_BRANCH against $BASE_BRANCH: $ERROR "
        exit 1
      fi
    fi
}

echo "creating PR for $CREATE_PR_URL from $HEAD_BRANCH against $BASE_BRANCH"

GIT_CREATE_PR_RESPONSE=$(
curl \
  -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  "$CREATE_PR_URL" \
  -d "{\"head\":\"$HEAD_BRANCH\",\"base\":\"$BASE_BRANCH\", \"title\": \"$TITLE\"}"
)
ERROR_MSG=$(echo "${GIT_CREATE_PR_RESPONSE}" | jq '.errors[0].message')
check_create_PR_response "$ERROR_MSG"

PR_URL=$(echo "${GIT_CREATE_PR_RESPONSE}" | jq '.url'| tr -d \")

echo "PR created successfully $PR_URL"
CHANGED_FILES=$(echo "${GIT_CREATE_PR_RESPONSE}" | jq '.changed_files')

if [ "$CHANGED_FILES" = 0 ]; then
  echo "::debug:: PR has 0 files changes, hence closing the PR $PR_URL"
  GIT_CLOSE_PR_RESPONSE=$(
    curl \
      -X PATCH \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token $GITHUB_TOKEN" \
      "$PR_URL" \
      -d '{"state":"closed", "title": "PR closed as 0 file changes"}'
  )
  echo "PR auto closed as $BASE_BRANCH is up-to-date with $HEAD_BRANCH"
else
  echo "PR created successfully $PR_URL"
fi

#!/bin/bash

# === LOAD ENVIRONMENT VARIABLES ===
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "$(date) - .env file not found. Aborting." >&2
  exit 1
fi

# === CONSTANT PATHS ===
WORKDIR="$(dirname "$0")"
LOGFILE="$WORKDIR/update.log"
UPDATE_FLAG_FILE="$WORKDIR/update-available.json"

cd "$WORKDIR" || exit 1

# === BLOCKED DAYS: 4=Thursday, 5=Friday, 6=Saturday ===
DAY=$(date +%u)
IS_BLOCKED_DAY=false
if [[ "$DAY" == "4" || "$DAY" == "5" || "$DAY" == "6" ]]; then
  IS_BLOCKED_DAY=true
fi

# === FETCH LATEST RELEASE TAG FROM GITHUB ===
LATEST_RELEASE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest")

LATEST_TAG=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')
LATEST_BODY=$(echo "$LATEST_RELEASE" | jq -r '.body')

if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
  echo "$(date) - Failed to fetch latest release." >> "$LOGFILE"
  exit 1
fi

# === PARSE LOCAL VERSION FROM version.txt ===
if [[ -f "version.txt" ]]; then
  LOCAL_VERSION=$(cat version.txt | tr -d '[:space:]')
else
  echo "$(date) - version.txt not found. Aborting." >> "$LOGFILE"
  exit 1
fi

# === VALIDATE LOCAL VERSION ===
if [[ -z "$LOCAL_VERSION" ]]; then
  echo "$(date) - Invalid version in version.txt. Aborting." >> "$LOGFILE"
  exit 1
fi

# === NORMALIZE VERSIONS ===
NORMALIZED_LOCAL="v$LOCAL_VERSION"
if [[ $LOCAL_VERSION == v* ]]; then
  NORMALIZED_LOCAL="$LOCAL_VERSION"
fi

# === COMPARE VERSIONS ===
if [[ "$NORMALIZED_LOCAL" == "$LATEST_TAG" ]]; then
  echo "$(date) - Already on latest version ($LATEST_TAG)." >> "$LOGFILE"
  rm -f "$UPDATE_FLAG_FILE"
  exit 0
fi

# === HANDLE BLOCKED UPDATE WINDOWS ===
if [[ "$IS_BLOCKED_DAY" == true ]]; then
  echo "$(date) - Update available ($LATEST_TAG), but blocked today." >> "$LOGFILE"
  echo "{\"updateAvailable\": true, \"latestVersion\": \"$LATEST_TAG\", \"currentVersion\": \"$LOCAL_VERSION\", \"note\": \"$LATEST_BODY\"}" > "$UPDATE_FLAG_FILE"
  exit 0
fi

# === PERFORM UPDATE ===
{
  # TODO
} || {
  echo "$(date) - Update to $LATEST_TAG failed!" >> "$LOGFILE"
  echo "{\"updateAvailable\": true, \"latestVersion\": \"$LATEST_TAG\", \"currentVersion\": \"$LOCAL_VERSION\", \"note\": \"$LATEST_BODY\", \"error\": true}" > "$UPDATE_FLAG_FILE"
  exit 1
}
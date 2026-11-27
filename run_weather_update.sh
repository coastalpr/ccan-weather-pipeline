
#!/usr/bin/env bash

set -Eeuo pipefail

# -------- CONFIG --------

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON_SCRIPT="$PROJECT_DIR/scripts/download_historical_tempest_data_hardcoded_002.py"

OUTPUT_DIR="$PROJECT_DIR/netcdf"
TEMP_DIR="$PROJECT_DIR/temp"

NETCDF_FILE="weather_data.nc"

#GIT_BRANCH="main"
#GIT_REMOTE="git@github.com:coastalpr/ccan_weatherstations.git"

GIT_BRANCH="main"
GIT_REMOTE="https://github.com/coastalpr/ccan_weatherstations.git"

# Authenticate without saving the token in Git configuration
AUTH_HEADER="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 -w0)"
# ------------------------

echo "======================================"
echo "CCAN WEATHER STATION UPDATE"
echo "======================================"

# 1. Prepare directories

mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# 2. Remove previous NetCDF files

echo "Cleaning previous NetCDF files..."

find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*.nc" -delete
find "$TEMP_DIR" -maxdepth 1 -type f -name "*.nc" -delete

# 3. Run Python downloader

echo "Running Python downloader..."

python "$PYTHON_SCRIPT"

# 4. Verify output

NETCDF_PATH="$OUTPUT_DIR/$NETCDF_FILE"

if [[ ! -f "$NETCDF_PATH" ]]; then
    echo "ERROR: NetCDF file not found: $NETCDF_PATH"
    exit 1
fi

if [[ ! -s "$NETCDF_PATH" ]]; then
    echo "ERROR: NetCDF file is empty."
    exit 1
fi

echo "NetCDF file generated successfully."

# 5. Clone destination repository

echo "Cloning CCAN weather repository..."

#REPO_DIR="$(mktemp -d)"

#cleanup() {
#    rm -rf "$REPO_DIR"
#}

#trap cleanup EXIT

#git clone --branch "$GIT_BRANCH" "$GIT_REMOTE" "$REPO_DIR"

#cd "$REPO_DIR"

REPO_DIR="$(mktemp -d)"

git -c http.extraheader="$AUTH_HEADER" \
    clone --branch "$GIT_BRANCH" "$GIT_REMOTE" "$REPO_DIR"

cd "$REPO_DIR"

# 6. Copy generated file

cp "$NETCDF_PATH" "$NETCDF_FILE"

# 7. Configure Git

git config user.name "CCAN Weather Bot"
git config user.email "ccan-weather-bot@users.noreply.github.com"

# 8. Add NetCDF file

echo "Adding NetCDF file..."

git add "$NETCDF_FILE"

# 9. Commit and push only if changed

#if ! git diff --cached --quiet; then

#    COMMIT_MESSAGE="Update NetCDF output ($(date -u '+%Y-%m-%d %H:%M:%S UTC'))"

#    git commit -m "$COMMIT_MESSAGE"

#    echo "Pushing updated weather data..."

#    git push origin "$GIT_BRANCH"

#else

#    echo "No changes detected. Nothing to commit."

#fi

git add weather_data.nc

if ! git diff --cached --quiet; then

    git commit -m "Update NetCDF output ($(date -u '+%Y-%m-%d %H:%M:%S UTC'))"

    git -c http.extraheader="$AUTH_HEADER" \
        push origin "$GIT_BRANCH"

else
    echo "No changes detected."
fi


echo "======================================"
echo "CCAN WEATHER UPDATE COMPLETED"
echo "======================================"

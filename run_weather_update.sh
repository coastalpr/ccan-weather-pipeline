
#!/usr/bin/env bash

set -Eeuo pipefail

# ======================================
# CONFIGURATION
# ======================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON_SCRIPT="$PROJECT_DIR/scripts/download_historical_tempest_data_hardcoded_002.py"

OUTPUT_DIR="$PROJECT_DIR/netcdf"
TEMP_DIR="$PROJECT_DIR/temp"

NETCDF_FILE="weather_data.nc"

GIT_BRANCH="main"
GIT_REMOTE="https://github.com/coastalpr/ccan_weatherstations.git"

# ======================================
# AUTHENTICATION
# ======================================

if [[ -z "${GH_TOKEN:-}" ]]; then
    echo "ERROR: GH_TOKEN is missing."
    exit 1
fi

AUTH_HEADER="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 -w0)"

# ======================================
# START
# ======================================

echo "======================================"
echo "CCAN WEATHER STATION UPDATE"
echo "======================================"

# 1. Prepare directories

mkdir -p "$OUTPUT_DIR" "$TEMP_DIR"

# 2. Remove previous NetCDF files

echo "Cleaning previous NetCDF files..."

find "$OUTPUT_DIR" -maxdepth 1 -type f -name "*.nc" -delete
find "$TEMP_DIR" -maxdepth 1 -type f -name "*.nc" -delete

# 3. Run Python downloader

echo "Running Python downloader..."

python "$PYTHON_SCRIPT"

# 4. Move generated file into netcdf directory

if [[ -f "$TEMP_DIR/$NETCDF_FILE" ]]; then
    cp "$TEMP_DIR/$NETCDF_FILE" "$OUTPUT_DIR/$NETCDF_FILE"
fi

# 5. Verify output

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

# ======================================
# PUBLISH TO GITHUB
# ======================================

# 6. Create temporary destination repository directory

REPO_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$REPO_DIR"
}

trap cleanup EXIT

# 7. Clone destination repository

echo "Cloning CCAN weather repository..."

git -c "http.https://github.com/.extraheader=$AUTH_HEADER" \
    clone --branch "$GIT_BRANCH" "$GIT_REMOTE" "$REPO_DIR"

cd "$REPO_DIR"

# 8. Copy generated NetCDF file

echo "Copying NetCDF file..."

cp "$NETCDF_PATH" "$NETCDF_FILE"

# 9. Configure Git

git config user.name "CCAN Weather Bot"
git config user.email "ccan-weather-bot@users.noreply.github.com"

# 10. Commit and push

git add "$NETCDF_FILE"

if ! git diff --cached --quiet; then

    git commit -m "Update NetCDF output ($(date -u '+%Y-%m-%d %H:%M:%S UTC'))"

    echo "Pushing updated weather data..."

    git -c "http.https://github.com/.extraheader=$AUTH_HEADER" \
        push origin "$GIT_BRANCH"

else
    echo "No changes detected."
fi
# ======================================
# COMPLETE
# ======================================

echo "======================================"
echo "CCAN WEATHER UPDATE COMPLETED"
echo "======================================"

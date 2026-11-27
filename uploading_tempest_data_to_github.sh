#!/bin/bash

# Exit immediately if any command fails
set -e
rm -f /mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/netcdf/*.nc
rm -f /mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/temp/*.nc
# -------- CONFIG --------
PYTHON_SCRIPT="/mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/download_historical_tempest_data_hardcoded_002.py"
OUTPUT_DIR="/mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/netcdf"
NETCDF_FILE="weather_data.nc"
GIT_BRANCH="master"
COMMIT_MESSAGE="Update NetCDF output ($(date '+%Y-%m-%d %H:%M:%S'))"
#SSH_KEY_PATH="/home/coastal/.ssh/ccangithub"  # path to your private SSH key
SSH_KEY_PATH="/home/coastal/.ssh/id_ed25519.pem"  # path to your private SSH key
GIT_REMOTE="git@github.com/coastalpr/ccan_weatherstations.git"  # SSH URL of your repo
# ------------------------


echo "Running Python script..."
python3 "$PYTHON_SCRIPT"

# Check if NetCDF file exists
if [ ! -f "$OUTPUT_DIR/$NETCDF_FILE" ]; then
    echo "ERROR: NetCDF file not found: $OUTPUT_DIR/$NETCDF_FILE"
    exit 1
fi

echo "Clone the full report."
cd /mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/ || exit 1

if [ ! -d "ccan_weatherstations/.git" ]; then
    git clone git@github.com:coastalpr/ccan_weatherstations.git ccan_weatherstations || exit 1
fi

cd ccan_weatherstations || exit 1

export GIT_SSH_COMMAND="ssh -i /home/coastal/.ssh/id_ed25519.pem -o IdentitiesOnly=yes"

git pull --rebase origin main || exit 1
#cd /mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/
#git clone git@github.com:coastalpr/ccan_weatherstations.git ccan_weatherstations

#if [ -d "ccan_weatherstations/.git" ]; then
#    echo "Repository already exists; reusing it."
	#cd ccan_weatherstations || exit 1
    #git pull --rebase origin main
    #cd ..
#else
 #git clone git@github.com:coastalpr/ccan_weatherstations.git ccan_weatherstations || exit 1
#fi

cp  /mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/netcdf/weather_data.nc .
echo "NetCDF file generated successfully."
#cd /home/coastal/Dropbox/CCAN_REAL_TIME_DATA/netcdf/

echo "Adding file to git..."
#git init
git remote set-url origin git@github.com:coastalpr/ccan_weatherstations.git

#git remote add origin git@github.com:coastalpr/ccan_weatherstations.git
#git fetch origin main
#git checkout -b main origin/main || git checkout -b main

git add "weather_data.nc"

if ! git diff --cached --quiet; then
    git commit -m "Update NetCDF output ($(date '+%Y-%m-%d %H:%M:%S'))" || exit 1
fi

git pull --rebase origin main || exit 1
git push origin main || exit 1

echo "Committing changes..."
#git commit -m "$COMMIT_MESSAGE" || echo "No changes to commit."
# Ensure remote URL is correct (SSH)

#git remote set-url origin https://github.com/coastal/ccan_weatherstations.git
echo "Pushing to GitHub using SSH key..."
# Use the specified SSH key for this push only
#git remote set-url origin git@github.com:coastalpr/ccan_weatherstations.git

#GIT_SSH_COMMAND="ssh -i /home/coastal/.ssh/ccangithub -o IdentitiesOnly=yes" git pull origin main --rebase || echo "No remote changes"
GIT_SSH_COMMAND="ssh -i /home/coastal/.ssh/id_ed25519.pem -o IdentitiesOnly=yes" git push origin main
#GIT_SSH_COMMAND="ssh -i /home/coastal/.ssh/ccangithub -o IdentitiesOnly=yes" git push origin main --rebase
echo "Done ✅ NetCDF file pushed to GitHub."

# -*- coding: utf-8 -*-
"""
Created on Fri Jan 23 22:33:16 2026

@author: Marejada
"""
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Download historical Tempest Weather Station data via JSON API
and append to NetCDF (all obs_st parameters with correct units)
"""

import requests
import pandas as pd
import numpy as np
import xarray as xr
import shutil

# ================= SETTINGS =================
API_TOKEN = "4878c623-c1e7-4810-99ce-6f356f6f11d0"
DEVICE_ID = "475512"

LOCAL_OUTFILE = r"/mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/temp/weather_data.nc"
DROPBOX_OUTFILE = r"/mnt/d/CCAN_Weatherstations_Scripts/CCAN_REAL_TIME_DATA/netcdf/weather_data.nc"

# Number of past days to download
DAYS_BACK = 3  # ← change this

# ================= obs_st FIELD ORDER =================
OBS_ST_FIELDS = [
    "time_epoch",
    "wind_lull",
    "wind_avg",
    "wind_gust",
    "wind_direction",
    "wind_sample_interval",
    "station_pressure",
    "air_temperature",
    "relative_humidity",
    "illuminance",
    "uv",
    "solar_radiation",
    "rain_accumulated",
    "precipitation_type",
    "lightning_strike_avg_distance",
    "lightning_strike_count",
    "battery",
    "report_interval",
    "local_daily_rain_accumulation",
    "rain_accum_final",
    "local_daily_rain_accum_final",
    "precipitation_analysis_type"
]

# ================= obs_st UNITS =================
OBS_ST_UNITS = {
    "time_epoch": "s since 1970-01-01 00:00:00",
    "wind_lull": "m s-1",
    "wind_avg": "m s-1",
    "wind_gust": "m s-1",
    "wind_direction": "degrees",
    "wind_sample_interval": "s",
    "station_pressure": "MB",
    "air_temperature": "degC",
    "relative_humidity": "%",
    "illuminance": "lux",
    "uv": "index",
    "solar_radiation": "W m-2",
    "rain_accumulated": "mm",
    "precipitation_type": "code (0=none,1=rain,2=hail)",
    "lightning_strike_avg_distance": "km",
    "lightning_strike_count": "count",
    "battery": "V",
    "report_interval": "minutes",
    "local_daily_rain_accumulation": "mm",
    "rain_accum_final": "mm",
    "local_daily_rain_accum_final": "mm",
    "precipitation_analysis_type": "code (0=none,1=RainCheckOn,2=RainCheckOff)"
}

# ================= HELPERS =================
def open_dataset_safe(path):
    try:
        return xr.open_dataset(path)
    except Exception:
        return None

def download_day_json(device_id, day_offset, token):
    url = f"https://swd.weatherflow.com/swd/rest/observations/device/{device_id}?day_offset={day_offset}&format=json&token={token}"
    try:
        r = requests.get(url, timeout=20)
        r.raise_for_status()
        data = r.json()
        obs_list = data.get("obs", [])
        return obs_list
    except Exception as e:
        print(f"Error downloading day_offset={day_offset}: {e}")
        return []

# ================= MAIN =================
all_new_datasets = []

for day_offset in range(DAYS_BACK):
    print(f"Downloading day_offset={day_offset}")
    obs_list = download_day_json(DEVICE_ID, day_offset, API_TOKEN)

    if not obs_list:
        print("No data for this day.")
        continue

    # ---------- INITIALIZE DATA CONTAINER ----------
    df_data = {var: [] for var in OBS_ST_FIELDS[1:]}  # exclude time_epoch
    timestamps = []

    # ---------- PARSE OBS LIST ----------
    for obs in obs_list:
        timestamps.append(pd.to_datetime(obs[0], unit="s", utc=True))  # time_epoch at index 0
        for idx, var in enumerate(OBS_ST_FIELDS[1:], start=1):
            df_data[var].append(obs[idx] if idx < len(obs) else np.nan)

    # ---------- BUILD DATAFRAME ----------
    df = pd.DataFrame(df_data)
    times = pd.to_datetime(timestamps).tz_localize(None)

    # ---------- BUILD xarray Dataset ----------
    data_vars = {}
    for var in OBS_ST_FIELDS[1:]:
        data_vars[var] = ("time", df[var].astype(np.float32).values, {"units": OBS_ST_UNITS.get(var, "")})

    ds_day = xr.Dataset(data_vars=data_vars, coords={"time": times})
    all_new_datasets.append(ds_day)

# ================= APPEND TO NETCDF =================
if not all_new_datasets:
    print("No historical data found.")
    raise SystemExit

ds_new = xr.concat(all_new_datasets, dim="time").sortby("time")

ds_old = open_dataset_safe(LOCAL_OUTFILE)

if ds_old is None:
    ds_new.to_netcdf(LOCAL_OUTFILE)
    print(f"Created NetCDF with {ds_new.time.size} records")
else:
    new_mask = ~ds_new.time.isin(ds_old.time)
    ds_add = ds_new.sel(time=new_mask)

    if ds_add.time.size > 0:
        ds_combined = xr.concat([ds_old, ds_add], dim="time")
        tmp = LOCAL_OUTFILE + ".tmp"
        ds_combined.to_netcdf(tmp)
        shutil.move(tmp, LOCAL_OUTFILE)
        print(f"Appended {ds_add.time.size} records")
    else:
        print("No new historical data to append")

# ================= COPY TO DROPBOX =================
try:
    shutil.copy2(LOCAL_OUTFILE, DROPBOX_OUTFILE)
except Exception as e:
    print(f"Warning: Could not copy to Dropbox: {e}")

print("Historical download complete.")


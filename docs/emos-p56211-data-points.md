# EMOS GoSmart P56211 data points

The following map applies to the tested P56211 over Tuya LAN 3.4 on TCP port 6668. DP numbers and meanings can differ between Tuya models and firmware versions.

## Verified and used by FelisTermostat

| DP | Raw value | Use |
| --- | --- | --- |
| 1 | Boolean | Thermostat on/off. Off can leave firmware frost protection active. |
| 2 | `auto`, `temporary`, `manual`, `boost`, `holiday` | Read and select the thermostat's operating mode. The firmware controls its behavior. |
| 3 | `heat`, `off` | Read whether the thermostat is calling for heat. `heat` was observed with the boiler running during testing. |
| 16 | Integer in tenths of a degree Celsius | Read and write the setpoint. The app allows 50–350 in steps of 5, corresponding to 5.0–35.0 °C in 0.5 °C steps. |
| 24 | Integer in tenths of a degree Celsius | Read the measured room temperature. |
| 40 | Boolean | Read and change the physical keypad lock. A missing value is displayed as unknown. |

Changing the setpoint in Auto writes only DP 16. The tested firmware can switch to Temporary on its own. FelisTermostat reads back the mode, temperatures and heating status reported by the device. It leaves the weekly schedule to the firmware.

## Observed with unresolved meaning

| DP | Observed type |
| --- | --- |
| 27, 32, 33, 101 | Integer |
| 103, 104 | String |

These points appeared in reads from the tested device. Their meanings, units, permitted values and write behavior remain unverified. The app leaves them untouched. Future investigation should compare read-only snapshots while changing one documented setting on the thermostat at a time.

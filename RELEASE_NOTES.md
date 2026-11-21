# FelisTermostat 1.0.0

First public release for the Jolla Phone 2026 on Sailfish OS 5.2, tested with the EMOS GoSmart P56211. FelisTermostat connects directly to the thermostat over Tuya LAN 3.4. Everyday use works without an active Tuya Cloud API subscription.

- View room and target temperatures, heating activity, operating mode and connection status.
- Adjust the setpoint in 0.5 °C steps and control thermostat power and the physical keypad lock.
- Select Auto, Temporary, Manual, Boost or Holiday. The thermostat continues to manage its weekly schedule.
- See both temperatures and heating activity on the Sailfish home-screen cover.
- Use the app in English or Czech.

Install `harbour-felistermostat-1.0.0-24.aarch64.rpm` and enter the thermostat's IPv4 address, Device ID and Local Key in **Settings**. The README covers setup, manual builds and the tested compatibility. Other Tuya thermostat models are unverified.

Project source is available from the [v1.0.0 tag](https://github.com/MiPal666/FelisTermostat/tree/v1.0.0) under GPL-3.0-or-later. The [dependency notices and source links](https://github.com/MiPal666/FelisTermostat/blob/v1.0.0/THIRD_PARTY.md) cover the bundled Python packages.

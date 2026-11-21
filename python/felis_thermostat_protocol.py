# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Tuya LAN transport and status decoding for the EMOS P56211."""

PORT = 6668
KEYPAD_LOCK_DP = 40
MODES = {"auto", "temporary", "manual", "boost", "holiday"}
MIN_TARGET = 50
MAX_TARGET = 350
TARGET_STEP = 5


class DeviceError(Exception):
    """An error identified by a user-facing status code."""


def decode_status(response):
    if not isinstance(response, dict):
        raise DeviceError("response")
    if "Err" in response:
        if str(response["Err"]) in {"901", "902", "905"}:
            raise DeviceError("unreachable")
        if str(response["Err"]) == "914":
            raise DeviceError("session")
        raise DeviceError("response")
    dps = response.get("dps")
    if not isinstance(dps, dict):
        raise DeviceError("response")
    powered, mode, heating, target, current = (dps.get(dp) for dp in ("1", "2", "3", "16", "24"))
    if type(powered) is not bool or not isinstance(mode, str) or mode not in MODES:
        raise DeviceError("response")
    if heating not in ("heat", "off") or type(target) is not int or type(current) is not int:
        raise DeviceError("response")
    state = {
        "powered": powered,
        "mode": mode,
        "heating": heating == "heat",
        "target": target,
        "minTarget": MIN_TARGET,
        "maxTarget": MAX_TARGET,
        "targetStep": TARGET_STEP,
        "current": current,
        "canDecrease": target - TARGET_STEP >= MIN_TARGET,
        "canIncrease": target + TARGET_STEP <= MAX_TARGET,
    }
    keypad_locked = dps.get(str(KEYPAD_LOCK_DP))
    if type(keypad_locked) is bool:
        state["keypadLocked"] = keypad_locked
    return state


class TuyaThermostat:
    def __init__(self, factory, config):
        self.factory = factory
        self.config = config

    def _device(self):
        return self.factory(
            self.config["id"],
            address=self.config["ip"],
            local_key=self.config["key"],
            port=PORT,
            version=3.4,
            connection_timeout=3.0,
            connection_retry_limit=1,
            send_retry_limit=0,
        )

    def read(self):
        try:
            device = self._device()
            try:
                reply = device.status()
            finally:
                device.close()
        except OSError:
            raise DeviceError("unreachable") from None
        except Exception:
            raise DeviceError("response") from None
        return decode_status(reply)

    def write(self, dp, value):
        device = self._device()
        try:
            device.set_value(dp, value)
        finally:
            device.close()

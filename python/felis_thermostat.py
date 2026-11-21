# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Asynchronous QML entry points called by PyOtherSide's worker."""

import ipaddress
import json
import logging
import os
from pathlib import Path
import stat
import sys
import tempfile
import time

from felis_thermostat_protocol import DeviceError, KEYPAD_LOCK_DP, MAX_TARGET, MIN_TARGET, MODES, TARGET_STEP, TuyaThermostat


def validate_config(data):
    if not isinstance(data, dict):
        raise DeviceError("configInvalid")
    address, device_id, key = (data.get(field) for field in ("ip", "id", "key"))
    if not isinstance(device_id, str) or not device_id.strip():
        raise DeviceError("configId")
    if not isinstance(key, str) or len(key) != 16 or not key.isascii():
        raise DeviceError("configKey")
    try:
        if not isinstance(address, str):
            raise ValueError
        address = ipaddress.IPv4Address(address)
        if not address.is_private or address.is_unspecified or int(address) == 0xffffffff:
            raise ValueError
    except ValueError:
        raise DeviceError("configAddress") from None
    return {"ip": str(address), "id": device_id, "key": key}


def load_config(path):
    try:
        with Path(path).open(encoding="utf-8") as source:
            if stat.S_IMODE(os.fstat(source.fileno()).st_mode) != 0o600:
                raise DeviceError("configPermissions")
            data = json.load(source)
    except FileNotFoundError:
        raise DeviceError("configMissing") from None
    except (OSError, ValueError):
        raise DeviceError("configInvalid") from None
    try:
        return validate_config(data)
    except DeviceError:
        raise DeviceError("configInvalid") from None


def connection_settings(path):
    """Return only the editable, non-secret fields of the saved connection."""
    try:
        config = load_config(path)
    except DeviceError as error:
        return {"settings": None, "error": str(error)}
    return {"settings": {"ip": config["ip"], "id": config["id"]}, "error": ""}


def edited_config(path, address, device_id, key):
    if key == "":
        try:
            key = load_config(path)["key"]
        except DeviceError:
            raise DeviceError("configKey") from None
    elif isinstance(key, str) and (len(key) != 16 or not key.isascii()):
        # Ignore surrounding clipboard whitespace without changing an already valid key.
        key = key.strip()
    return validate_config({"ip": address.strip(), "id": device_id.strip(), "key": key})


def verify_connection(path, address, device_id, key):
    try:
        transport_for(edited_config(path, address, device_id, key)).read()
    except DeviceError as error:
        return {"error": str(error)}
    return {"error": ""}


def save_connection(path, address, device_id, key):
    try:
        config = edited_config(path, address, device_id, key)
    except DeviceError as error:
        return {"error": str(error)}

    destination = Path(path)
    temporary = None
    try:
        destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=destination.parent,
                                         prefix=".thermostat-", delete=False) as output:
            temporary = Path(output.name)
            json.dump(config, output)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, destination)
        temporary = None
    except OSError:
        return {"error": "configSave"}
    finally:
        if temporary is not None:
            try:
                temporary.unlink()
            except OSError:
                pass
    return {"error": ""}


def make_transport(config_path):
    return transport_for(load_config(config_path))


def transport_for(config):
    # This interpreter is private to the application process. Native wheels
    # live in the RPM's own data directory alongside the backend.
    vendor = str(Path(__file__).resolve().parent.parent / "vendor")
    if vendor not in sys.path:
        sys.path.insert(0, vendor)
    # TinyTuya debug and error logs can contain raw Tuya payloads or keys.
    logging.disable(logging.CRITICAL)
    try:
        from tinytuya import Device
    except Exception:
        raise DeviceError("dependency") from None
    return TuyaThermostat(Device, config)


def refresh(config_path):
    try:
        return {"state": make_transport(config_path).read(), "error": ""}
    except DeviceError as error:
        return {"state": None, "error": str(error)}


def change(config_path, command, confirmation_timeout=None):
    deadline = None if confirmation_timeout is None else time.monotonic() + confirmation_timeout
    try:
        transport = make_transport(config_path)
        before = transport.read()
    except DeviceError as error:
        return {"state": None, "error": str(error)}

    if command in ("increase", "decrease"):
        step = TARGET_STEP if command == "increase" else -TARGET_STEP
        dp, field, value = 16, "target", before["target"] + step
        if not MIN_TARGET <= value <= MAX_TARGET:
            return {"state": before, "error": "range"}
    elif isinstance(command, str) and command.startswith("target:"):
        try:
            value = int(command[len("target:"):])
        except ValueError:
            return {"state": before, "error": "range"}
        if not MIN_TARGET <= value <= MAX_TARGET or (value - MIN_TARGET) % TARGET_STEP:
            return {"state": before, "error": "range"}
        dp, field = 16, "target"
    elif isinstance(command, str) and command in MODES:
        dp, field, value = 2, "mode", command
    elif command in ("on", "off"):
        dp, field, value = 1, "powered", command == "on"
    elif command in ("lock", "unlock"):
        dp, field, value = KEYPAD_LOCK_DP, "keypadLocked", command == "lock"
        if field not in before:
            return {"state": before, "error": "keypadLockUnknown"}
    else:
        return {"state": before, "error": "command"}

    if deadline is not None and time.monotonic() >= deadline:
        return {"state": before, "error": "writeUnconfirmed"}
    if value == before[field]:
        return {"state": before, "error": ""}
    try:
        transport.write(dp, value)
    except Exception:
        # A failed reply may mean the device applied the write anyway.
        pass
    needs_followup = deadline is not None and field in ("mode", "powered")
    result = {"state": before, "error": "writeUnconfirmed"}
    while deadline is None or time.monotonic() < deadline:
        try:
            after = transport.read()
        except DeviceError as error:
            result = {"state": None, "error": str(error), "writeUnconfirmed": True}
        else:
            if deadline is not None and time.monotonic() >= deadline:
                break
            if after.get(field) == value:
                if not needs_followup:
                    return {"state": after, "error": ""}
                # The setpoint and relay state can lag behind a mode or power change.
                needs_followup = False
            result = {"state": after, "error": "writeUnconfirmed"}
        if deadline is None:
            break
        time.sleep(max(0, min(0.25, deadline - time.monotonic())))
    return result

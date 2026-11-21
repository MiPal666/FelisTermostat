#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

"""Read-only LAN diagnostic for the EMOS GoSmart P56211."""

import argparse
import importlib
from importlib import metadata
import ipaddress
import json
import logging
import os
from pathlib import Path
import socket
import sys
import time


PORT = 6668
TIMEOUT = 3.0
TINYTUYA_VERSION = "1.21.1"
MODES = {"auto", "temporary", "manual", "boost", "holiday"}
HEATING_STATES = {"heat", "off"}
TUYA_ERRORS = {
    "900": "neplatná odpověď JSON",
    "901": "spojení se nezdařilo",
    "902": "vypršel čas na odpověď",
    "904": "neočekávaný obsah odpovědi",
    "905": "zařízení je nedostupné",
    "914": "nezdařilo se navázat relaci Tuya LAN",
}


class ProbeError(Exception):
    """A diagnostic error whose message is safe to print."""


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError:
        raise ProbeError("Konfigurační soubor nelze přečíst.") from None
    except ValueError:
        raise ProbeError("Konfigurační soubor obsahuje neplatný JSON.") from None


def validate_config(config):
    if not isinstance(config, dict):
        raise ProbeError("Neplatný formát konfigurace.")
    device_id, key, address = (config.get(field) for field in ("id", "key", "ip"))
    if not isinstance(device_id, str) or not device_id.strip():
        raise ProbeError("V konfiguraci chybí Device ID.")
    if not isinstance(key, str) or not key.isascii() or len(key) != 16:
        raise ProbeError("Konfigurace vyžaduje 16bajtový lokální klíč ASCII.")
    if not isinstance(address, str):
        raise ProbeError("Konfigurace vyžaduje explicitní IPv4 adresu.")
    try:
        address = str(ipaddress.IPv4Address(address))
    except ValueError:
        raise ProbeError("Konfigurace vyžaduje explicitní IPv4 adresu.") from None
    return {"ip": address, "id": device_id, "key": key}


def prepare_config(snapshot_path, destination, address):
    snapshot = read_json(snapshot_path)
    devices = snapshot.get("devices") if isinstance(snapshot, dict) else None
    if not isinstance(devices, list):
        raise ProbeError("Snapshot neobsahuje seznam zařízení.")
    matches = [entry for entry in devices if isinstance(entry, dict) and entry.get("ip") == str(address)]
    if len(matches) != 1:
        raise ProbeError("Snapshot musí obsahovat právě jedno zařízení se zadanou IP adresou.")
    config = validate_config(matches[0])
    try:
        with open(destination, "x", encoding="utf-8", opener=private_file) as output:
            json.dump(config, output, indent=2)
            output.write("\n")
    except FileExistsError:
        raise ProbeError("Cílová konfigurace už existuje.") from None
    except OSError:
        raise ProbeError("Cílovou konfiguraci nelze vytvořit.") from None


def private_file(path, flags):
    return os.open(path, flags, 0o600)


def load_dependencies():
    print(f"Python {sys.version.split()[0]}", flush=True)
    for name in ("requests", "colorama", "cryptography", "tinytuya"):
        try:
            module = importlib.import_module(name)
            version = metadata.version(name)
        except Exception:
            raise ProbeError(f"Nelze načíst {name} nebo zjistit jeho verzi.") from None
        print(f"{name} {version}", flush=True)
    if version != TINYTUYA_VERSION:
        raise ProbeError(f"Pro ověření je potřeba TinyTuya {TINYTUYA_VERSION}.")
    return module


def check_tcp(address):
    try:
        with socket.create_connection((address, PORT), timeout=TIMEOUT):
            pass
    except TimeoutError:
        raise ProbeError("Vypršel čas na připojení TCP.") from None
    except OSError:
        raise ProbeError("Připojení TCP se nezdařilo.") from None


def decode_status(response):
    if not isinstance(response, dict):
        raise ProbeError("Neočekávaný formát odpovědi Tuya LAN.")
    if "Err" in response:
        code = response["Err"]
        detail = TUYA_ERRORS.get(str(code)) if type(code) in (str, int) else None
        raise ProbeError(f"Tuya LAN: {detail or 'chyba zařízení'}.")
    dps = response.get("dps")
    if not isinstance(dps, dict):
        raise ProbeError("V odpovědi chybí datové body.")
    if type(dps.get("1")) is not bool:
        raise ProbeError("DP 1 chybí nebo neobsahuje platný stav zapnutí.")
    for dp, allowed in (("2", MODES), ("3", HEATING_STATES)):
        value = dps.get(dp)
        if not isinstance(value, str) or value not in allowed:
            raise ProbeError(f"DP {dp} chybí nebo obsahuje neznámý stav.")
    for dp in ("16", "24"):
        if type(dps.get(dp)) is not int:
            raise ProbeError(f"DP {dp} chybí nebo neobsahuje celočíselnou teplotu.")
    return dps["1"], dps["2"], dps["3"], dps["16"] / 10, dps["24"] / 10


def read_status(tinytuya, config):
    try:
        device = tinytuya.Device(
            config["id"], address=config["ip"], local_key=config["key"],
            port=PORT, version=3.4, connection_timeout=TIMEOUT,
            connection_retry_limit=1, send_retry_limit=0,
        )
        try:
            response = device.status()
        finally:
            device.close()
    except TimeoutError:
        raise ProbeError("Vypršel čas na odpověď Tuya LAN.") from None
    except Exception:
        raise ProbeError("Čtení Tuya LAN se nezdařilo.") from None
    return decode_status(response)


def probe(tinytuya, config, count):
    address = config["ip"]
    try:
        check_tcp(address)
        print(f"TCP {address}:{PORT} dostupné.", flush=True)
    except ProbeError as error:
        print(f"TCP {address}:{PORT}: {error}", file=sys.stderr, flush=True)

    successes = 0
    for attempt in range(1, count + 1):
        if attempt > 1:
            time.sleep(1)
        try:
            powered, mode, heating, target, current = read_status(tinytuya, config)
        except ProbeError as error:
            print(f"Čtení {attempt}/{count}: {error}", file=sys.stderr, flush=True)
            continue
        successes += 1
        power_label = "Zapnuto" if powered else "Vypnuto"
        heating_label = "Topí" if heating == "heat" else "Netopí"
        print(
            f"Čtení {attempt}/{count}: {power_label} | režim {mode} | {heating_label} | "
            f"požadovaná {target:.1f} °C | aktuální {current:.1f} °C",
            flush=True,
        )
    print(f"Úspěšná čtení: {successes}/{count}", flush=True)
    return 0 if successes == count else 1


def main():
    default_config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=default_config / "felis-termostat/thermostat.json")
    parser.add_argument("--count", type=int, default=3, help="Počet čtení (výchozí 3).")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--prepare-config", type=Path, metavar="SNAPSHOT", help="Zapsat výběr ze snapshotu do --config.")
    action.add_argument("--check-dependencies", action="store_true", help="Ověřit Python závislosti bez připojení.")
    parser.add_argument("--ip", type=ipaddress.IPv4Address, help="IPv4 adresa pro výběr zařízení ze snapshotu.")
    args = parser.parse_args()
    if args.count < 1:
        parser.error("--count musí být kladný.")

    if (args.prepare_config is None) != (args.ip is None):
        parser.error("--prepare-config a --ip se používají společně.")

    # TinyTuya can include credentials in its debug output.
    logging.disable(logging.CRITICAL)
    try:
        if args.prepare_config is not None:
            prepare_config(args.prepare_config, args.config, args.ip)
            print("Vytvořena soukromá konfigurace termostatu.")
            return 0
        tinytuya = load_dependencies()
        if args.check_dependencies:
            return 0
        config = validate_config(read_json(args.config))
        return probe(tinytuya, config, args.count)
    except ProbeError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

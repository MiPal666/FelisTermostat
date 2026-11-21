# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

import felis_thermostat as backend
from felis_thermostat_protocol import DeviceError, TuyaThermostat, decode_status


INITIAL_DPS = {"1": True, "2": "auto", "3": "off", "16": 195, "24": 230}


class FakeThermostat:
    def __init__(self):
        self.dps = INITIAL_DPS.copy()
        self.commands = []
        self.next_response = None
        self.write_effect = None
        self.connections = 0
        self.closes = 0

    def connect(self, device_id, **options):
        self.connections += 1
        self.options = options
        if options["address"] != "192.0.2.1" or options["version"] != 3.4:
            raise AssertionError("Expected a direct Tuya LAN 3.4 connection.")
        return self

    def status(self):
        self.commands.append(("read",))
        if self.next_response is not None:
            response, self.next_response = self.next_response, None
            return response
        return {"dps": self.dps.copy()}

    def set_value(self, dp, value):
        self.commands.append(("write", dp, value))
        if self.write_effect == "ignored":
            return {"Err": "902"}
        self.dps[str(dp)] = value
        if dp == 16 and self.dps["2"] == "auto":
            self.dps["2"] = "temporary"
        if self.write_effect == "lost_read":
            self.next_response = {"Err": "902"}
        if self.write_effect in {"lost_ack", "lost_read"}:
            raise TimeoutError("fake timeout")
        return {}

    def close(self):
        self.closes += 1


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.fake = FakeThermostat()
        config = {"id": "fake-id", "ip": "192.0.2.1", "key": "0" * 16}
        transport = TuyaThermostat(self.fake.connect, config)
        dependency = patch.object(backend, "make_transport", return_value=transport)
        dependency.start()
        self.addCleanup(dependency.stop)

    def change(self, command):
        return backend.change("unused.json", command)

    def refresh(self):
        return backend.refresh("unused.json")

    def test_auto_temperature_override_uses_only_dp16_then_reads_firmware(self):
        result = self.change("increase")
        self.assertEqual(result["state"]["mode"], "temporary")
        self.assertEqual(result["state"]["target"], 200)
        self.assertEqual(self.fake.commands, [("read",), ("write", 16, 200), ("read",)])
        self.assertEqual(self.fake.connections, self.fake.closes)
        self.assertEqual(self.fake.options["send_retry_limit"], 0)
        self.fake.dps.update({"2": "auto", "16": 190})
        result = self.refresh()
        self.assertEqual((result["state"]["mode"], result["state"]["target"]), ("auto", 190))

    def test_slider_writes_absolute_target_once_then_reads_firmware(self):
        result = self.change("target:215")
        self.assertEqual(result["error"], "")
        self.assertEqual((result["state"]["target"], result["state"]["mode"]), (215, "temporary"))
        self.assertEqual(self.fake.commands, [("read",), ("write", 16, 215), ("read",)])
        self.fake.commands.clear()
        self.assertEqual(self.change("target:215")["error"], "")
        self.assertEqual(self.fake.commands, [("read",)])

    def test_slider_rejects_out_of_range_or_off_step_targets(self):
        for command in ("target:45", "target:355", "target:196", "target:19.5"):
            with self.subTest(command=command):
                self.fake.commands.clear()
                result = self.change(command)
                self.assertEqual(result["error"], "range")
                self.assertEqual(self.fake.commands, [("read",)])

    def test_temperature_waits_for_delayed_confirmation_without_repeating_write(self):
        original_write = self.fake.set_value

        def write_with_delayed_readback(dp, value):
            original_write(dp, value)
            self.fake.next_response = {"dps": INITIAL_DPS.copy()}

        with patch.object(self.fake, "set_value", side_effect=write_with_delayed_readback):
            with patch.object(backend.time, "sleep"):
                result = backend.change("unused.json", "target:215", 5)
        self.assertEqual((result["state"]["target"], result["error"]), (215, ""))
        self.assertEqual(self.fake.commands, [("read",), ("write", 16, 215), ("read",), ("read",)])

    def test_temperature_times_out_when_readback_stays_at_previous_target(self):
        self.fake.write_effect = "ignored"
        elapsed = 0

        def advance_clock(seconds):
            nonlocal elapsed
            elapsed += seconds

        with patch.object(backend, "time") as clock:
            clock.monotonic.side_effect = lambda: elapsed
            clock.sleep.side_effect = advance_clock
            result = backend.change("unused.json", "target:215", 5)
        self.assertEqual(elapsed, 5)
        self.assertEqual((result["state"]["target"], result["error"]), (195, "writeUnconfirmed"))
        self.assertGreater(self.fake.commands.count(("read",)), 2)
        self.assertEqual(self.fake.commands.count(("write", 16, 215)), 1)

    def test_temperature_does_not_accept_a_readback_after_the_deadline(self):
        with patch.object(backend.time, "monotonic", side_effect=[0, 0, 0, 5]):
            result = backend.change("unused.json", "target:215", 5)
        self.assertEqual((result["state"]["target"], result["error"]), (195, "writeUnconfirmed"))
        self.assertEqual(self.fake.commands, [("read",), ("write", 16, 215), ("read",)])

    def test_mode_and_power_write_only_their_own_dps(self):
        self.assertEqual(self.change("manual")["state"]["mode"], "manual")
        self.assertEqual(self.change("decrease")["state"]["mode"], "manual")
        self.assertEqual(self.change("auto")["state"]["mode"], "auto")
        self.assertFalse(self.change("off")["state"]["powered"])
        self.assertTrue(self.change("on")["state"]["powered"])
        self.assertEqual([item for item in self.fake.commands if item[0] == "write"], [
            ("write", 2, "manual"), ("write", 16, 190), ("write", 2, "auto"),
            ("write", 1, False), ("write", 1, True),
        ])

    def test_keypad_lock_and_unlock_write_only_dp40_and_read_it_back(self):
        self.fake.dps["40"] = False
        self.assertIs(self.refresh()["state"]["keypadLocked"], False)
        self.fake.commands.clear()
        locked = self.change("lock")
        unlocked = self.change("unlock")
        self.assertEqual((locked["error"], unlocked["error"]), ("", ""))
        self.assertIs(locked["state"]["keypadLocked"], True)
        self.assertIs(unlocked["state"]["keypadLocked"], False)
        self.assertEqual(self.fake.commands, [
            ("read",), ("write", 40, True), ("read",),
            ("read",), ("write", 40, False), ("read",),
        ])

    def test_missing_or_non_boolean_keypad_state_does_not_allow_write(self):
        for dps in (INITIAL_DPS, {**INITIAL_DPS, "40": 0}):
            with self.subTest(dps=dps):
                self.fake.dps = dps.copy()
                self.fake.commands.clear()
                result = self.change("lock")
                self.assertEqual(result["error"], "keypadLockUnknown")
                self.assertNotIn("keypadLocked", result["state"])
                self.assertEqual(self.fake.commands, [("read",)])

    def test_keypad_write_is_unconfirmed_when_followup_omits_lock_state(self):
        self.fake.dps["40"] = False
        original_write = self.fake.set_value

        def write_without_lock_readback(dp, value):
            original_write(dp, value)
            self.fake.next_response = {"dps": INITIAL_DPS.copy()}

        with patch.object(self.fake, "set_value", side_effect=write_without_lock_readback):
            result = self.change("lock")
        self.assertEqual(result["error"], "writeUnconfirmed")
        self.assertNotIn("keypadLocked", result["state"])
        self.assertEqual(self.fake.commands, [("read",), ("write", 40, True), ("read",)])

    def test_timeout_hides_state_and_next_read_recovers(self):
        self.assertTrue(self.refresh()["state"]["powered"])
        self.fake.next_response = {"Err": "902"}
        self.assertEqual(self.refresh(), {"state": None, "error": "unreachable"})
        self.fake.dps["24"] = 221
        self.assertEqual(self.refresh()["state"]["current"], 221)

    def test_failed_preflight_does_not_write(self):
        self.fake.next_response = {"Err": "905"}
        self.assertEqual(self.change("off"), {"state": None, "error": "unreachable"})
        self.assertEqual(self.fake.commands, [("read",)])

    def test_lost_write_reply_can_be_confirmed_without_retry(self):
        self.fake.write_effect = "lost_ack"
        result = self.change("increase")
        self.assertEqual(result["error"], "")
        self.assertEqual(result["state"]["target"], 200)
        self.assertEqual(self.fake.commands, [("read",), ("write", 16, 200), ("read",)])

    def test_unconfirmed_write_replaces_old_state_with_fresh_read(self):
        self.fake.write_effect = "ignored"
        result = self.change("increase")
        self.assertEqual(result["error"], "writeUnconfirmed")
        self.assertEqual(result["state"]["target"], 195)

    def test_timeout_after_write_has_no_state_and_does_not_replay_write(self):
        self.fake.write_effect = "lost_read"
        result = self.change("increase")
        self.assertEqual(result, {"state": None, "error": "unreachable", "writeUnconfirmed": True})
        self.assertEqual(self.refresh()["state"]["target"], 200)
        self.assertEqual(self.fake.commands, [("read",), ("write", 16, 200), ("read",), ("read",)])

    def test_range_and_unknown_commands_are_not_written(self):
        self.fake.dps["16"] = 50
        self.assertEqual(self.change("decrease")["error"], "range")
        self.assertEqual(self.change("unknown-mode")["error"], "command")
        self.assertEqual(self.fake.commands, [("read",), ("read",)])

    def test_all_modes_can_be_selected_and_a_repeated_selection_does_not_write(self):
        for mode in ("manual", "temporary", "boost", "holiday", "auto"):
            with self.subTest(mode=mode):
                self.fake.commands.clear()
                result = self.change(mode)
                self.assertEqual((result["state"]["mode"], result["error"]), (mode, ""))
                self.assertEqual(self.change(mode)["error"], "")
                self.assertEqual(self.fake.commands, [("read",), ("write", 2, mode), ("read",), ("read",)])

    def test_delayed_mode_confirmation_returns_the_new_target_in_the_same_snapshot(self):
        original_write = self.fake.set_value

        def write_with_delayed_readback(dp, value):
            original_write(dp, value)
            self.fake.dps["16"] = 220
            self.fake.next_response = {"dps": {**INITIAL_DPS, "16": 205}}

        with patch.object(self.fake, "set_value", side_effect=write_with_delayed_readback):
            with patch.object(backend.time, "sleep"):
                result = backend.change("unused.json", "boost", 5)
        self.assertEqual((result["state"]["mode"], result["state"]["target"], result["error"]),
                         ("boost", 220, ""))
        self.assertEqual(self.fake.commands,
                         [("read",), ("write", 2, "boost"), ("read",), ("read",), ("read",)])

    def test_mode_and_power_reload_dependent_values_after_confirmation(self):
        original_write = self.fake.set_value

        def write_with_delayed_setpoint(dp, value):
            original_write(dp, value)
            self.fake.next_response = {"dps": self.fake.dps.copy()}
            self.fake.dps["16"] = 220

        for command, dp, value in (("boost", 2, "boost"), ("off", 1, False), ("on", 1, True)):
            with self.subTest(command=command):
                self.fake.dps["16"] = 195
                self.fake.commands.clear()
                with patch.object(self.fake, "set_value", side_effect=write_with_delayed_setpoint):
                    with patch.object(backend.time, "sleep"):
                        result = backend.change("unused.json", command, 5)
                self.assertEqual((result["state"]["target"], result["error"]), (220, ""))
                self.assertEqual(self.fake.commands, [("read",), ("write", dp, value), ("read",), ("read",)])


class ConnectionSettingsTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "felistermostat" / "thermostat.json"
        self.address = "192.0.2.1"
        self.key = "1" * 16

    def test_new_settings_are_private_and_editing_does_not_return_the_key(self):
        self.assertEqual(backend.connection_settings(self.path)["error"], "configMissing")
        self.assertEqual(backend.save_connection(self.path, self.address, "first", self.key), {"error": ""})
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o600)
        self.assertEqual(backend.connection_settings(self.path),
                         {"settings": {"ip": self.address, "id": "first"}, "error": ""})
        self.assertEqual(backend.save_connection(self.path, self.address, "second", ""), {"error": ""})
        self.assertEqual(backend.load_config(self.path), {"ip": self.address, "id": "second", "key": self.key})

    def test_verification_reads_with_draft_credentials_without_saving(self):
        backend.save_connection(self.path, self.address, "saved", self.key)
        before = self.path.read_bytes()
        fake = FakeThermostat()
        proposed_key = "2" * 16
        with patch.object(backend, "transport_for",
                          side_effect=lambda config: TuyaThermostat(fake.connect, config)) as transport:
            self.assertEqual(backend.verify_connection(self.path, self.address, "draft", proposed_key), {"error": ""})
            transport.assert_called_once_with({"ip": self.address, "id": "draft", "key": proposed_key})
            fake.next_response = {"Err": "914"}
            self.assertEqual(backend.verify_connection(self.path, self.address, "saved", ""), {"error": "session"})
        self.assertEqual(fake.commands, [("read",), ("read",)])
        self.assertEqual(self.path.read_bytes(), before)

    def test_invalid_input_or_failed_replacement_preserves_existing_settings(self):
        self.assertEqual(backend.save_connection(self.path, self.address, "first", ""), {"error": "configKey"})
        self.assertFalse(self.path.exists())
        backend.save_connection(self.path, self.address, "first", self.key)
        before = self.path.read_bytes()
        self.assertEqual(backend.save_connection(self.path, "8.8.8.8", "second", ""), {"error": "configAddress"})
        with patch.object(backend.os, "replace", side_effect=OSError):
            self.assertEqual(backend.save_connection(self.path, self.address, "second", ""), {"error": "configSave"})
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(list(self.path.parent.iterdir()), [self.path])

    def test_pasted_key_accepts_surrounding_whitespace_without_changing_valid_keys(self):
        pasted = "\u00a0\t" + self.key + "\r\n"
        with patch.object(backend, "transport_for") as transport:
            self.assertEqual(backend.verify_connection(self.path, self.address, "fixture", pasted), {"error": ""})
            transport.assert_called_once_with({"ip": self.address, "id": "fixture", "key": self.key})
        self.assertEqual(backend.save_connection(self.path, self.address, "fixture", pasted), {"error": ""})
        self.assertEqual(backend.load_config(self.path)["key"], self.key)

        exact_key = " " + "x" * 14 + " "
        self.assertEqual(backend.save_connection(self.path, self.address, "fixture", exact_key), {"error": ""})
        self.assertEqual(backend.load_config(self.path)["key"], exact_key)
        self.assertEqual(backend.save_connection(self.path, self.address, "fixture", "x" * 15 + "á"),
                         {"error": "configKey"})


class DecoderTests(unittest.TestCase):
    def test_all_firmware_modes_and_heating_are_reported(self):
        for mode in ("auto", "temporary", "manual", "boost", "holiday"):
            with self.subTest(mode=mode):
                state = decode_status({"dps": {**INITIAL_DPS, "2": mode, "3": "heat"}})
                self.assertEqual(state["mode"], mode)
                self.assertTrue(state["heating"])

    def test_incomplete_or_invalid_responses_are_rejected(self):
        for response in (None, {}, {"dps": {"1": True}}, {"dps": {**INITIAL_DPS, "24": False}},
                         {"dps": {**INITIAL_DPS, "2": "unknown"}}):
            with self.subTest(response=response), self.assertRaisesRegex(DeviceError, "^response$"):
                decode_status(response)

    def test_config_permissions_and_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "thermostat.json"
            with self.assertRaisesRegex(DeviceError, "^configMissing$"):
                backend.load_config(path)
            config = {"ip": "192.0.2.1", "id": "test", "key": "1" * 16}
            path.write_text(json.dumps(config))
            path.chmod(0o644)
            with self.assertRaisesRegex(DeviceError, "^configPermissions$"):
                backend.load_config(path)
            path.chmod(0o600)
            self.assertEqual(backend.load_config(path), config)
            path.write_text(json.dumps({**config, "ip": "255.255.255.255"}))
            with self.assertRaisesRegex(DeviceError, "^configInvalid$"):
                backend.load_config(path)

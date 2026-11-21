<?xml version="1.0" encoding="utf-8"?>
<!--
SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
SPDX-License-Identifier: GPL-3.0-or-later
-->
<!DOCTYPE TS>
<TS version="2.1" language="cs_CZ" sourcelanguage="en">
<context>
    <name>AboutPage</name>
    <message>
        <source>About</source>
        <translation>O aplikaci</translation>
    </message>
    <message>
        <source>Version %1</source>
        <translation>Verze %1</translation>
    </message>
    <message>
        <source>An unofficial Sailfish OS app for controlling the EMOS GoSmart P56211 thermostat over your home network. It displays the temperature and heating status and lets you change the set temperature, operating mode and keypad lock.</source>
        <translation>Neoficiální ovládání termostatu EMOS GoSmart P56211 ze Sailfish OS přes domácí síť. Zobrazuje teplotu a stav topení a umožňuje měnit nastavenou teplotu, režim a zámek kláves.</translation>
    </message>
    <message>
        <source>Created by Michal Kasík (MiPal) with help from Klára (AI).</source>
        <translation>Vytvořil Michal Kasík (MiPal) s pomocí Kláry (AI).</translation>
    </message>
    <message>
        <source>Source code on GitHub</source>
        <translation>Zdrojový kód na GitHubu</translation>
    </message>
    <message>
        <source>Connection</source>
        <translation>Připojení</translation>
    </message>
    <message>
        <source>The app communicates directly with the thermostat over Tuya LAN using its IP address, device ID and local key.</source>
        <translation>Aplikace komunikuje s termostatem přímo přes Tuya LAN. Pro ovládání používá IP adresu, Device ID a lokální klíč.</translation>
    </message>
    <message>
        <source>License</source>
        <translation>Licence</translation>
    </message>
    <message>
        <source>This app is free software under the GNU General Public License, version 3 or any later version (GPL-3.0-or-later). It is provided without warranty. Third-party components retain their own licenses.</source>
        <translation>Tato aplikace je svobodný software pod licencí GNU General Public License verze 3 nebo kterékoli novější (GPL-3.0-or-later). Je poskytována bez záruky. Komponenty třetích stran si zachovávají vlastní licence.</translation>
    </message>
    <message>
        <source>GNU GPL v3</source>
        <translation>GNU GPL v3</translation>
    </message>
</context>
<context>
    <name>SettingsPage</name>
    <message>
        <source>Settings saved.</source>
        <translation>Nastavení uloženo.</translation>
    </message>
    <message>
        <source>Connected to the thermostat.</source>
        <translation>Spojení s termostatem funguje.</translation>
    </message>
    <message>
        <source>Test connection</source>
        <translation>Ověřit spojení</translation>
    </message>
    <message>
        <source>Save</source>
        <translation>Uložit</translation>
    </message>
    <message>
        <source>Settings</source>
        <translation>Nastavení</translation>
    </message>
    <message>
        <source>To obtain the local key (local_key) through Tuya, you need a Tuya account and temporary API access. If you already have the key, enter it below.</source>
        <translation>Pokud lokální klíč (local_key) nezískáš jinak, pro jeho získání přes Tuya potřebuješ účet Tuya a dočasný přístup k API.</translation>
    </message>
    <message>
        <source>This app has only been tested with the EMOS P56211 thermostat.</source>
        <translation>Aplikace byla otestována pouze s termostatem EMOS P56211.</translation>
    </message>
    <message>
        <source>Thermostat IP address</source>
        <translation>IP adresa termostatu</translation>
    </message>
    <message>
        <source>Device ID</source>
        <translation>Device ID</translation>
    </message>
    <message>
        <source>Local key</source>
        <translation>Lokální klíč</translation>
    </message>
    <message>
        <source>Local key is saved</source>
        <translation>Lokální klíč je uložený</translation>
    </message>
    <message>
        <source>Leave this field blank to keep the saved key.</source>
        <translation>Prázdné pole ponechá uložený klíč.</translation>
    </message>
    <message>
        <source>Connection not yet tested.</source>
        <translation>Spojení zatím neověřeno.</translation>
    </message>
</context>
<context>
    <name>harbour-felistermostat</name>
    <message>
        <source>Automatic</source>
        <translation>Automatický</translation>
    </message>
    <message>
        <source>Auto</source>
        <translation>Auto</translation>
    </message>
    <message>
        <source>Temporary</source>
        <translation>Dočasný</translation>
    </message>
    <message>
        <source>Manual</source>
        <translation>Ruční</translation>
    </message>
    <message>
        <source>Boost</source>
        <translation>Boost</translation>
    </message>
    <message>
        <source>Holiday</source>
        <translation>Dovolená</translation>
    </message>
    <message>
        <source>The thermostat is not configured. Open Settings from the pull-down menu and enter the thermostat details.</source>
        <translation>Termostat není nakonfigurován. Otevři Nastavení v horní nabídce a zadej údaje termostatu.</translation>
    </message>
    <message>
        <source>The settings file must have permissions set to 0600</source>
        <translation>Konfigurace musí mít oprávnění 0600</translation>
    </message>
    <message>
        <source>The thermostat settings are invalid</source>
        <translation>Konfigurace termostatu je neplatná</translation>
    </message>
    <message>
        <source>Enter the thermostat’s local IPv4 address.</source>
        <translation>Zadej místní adresu IPv4 termostatu.</translation>
    </message>
    <message>
        <source>Enter the thermostat’s device ID.</source>
        <translation>Zadej Device ID termostatu.</translation>
    </message>
    <message>
        <source>The local key must be 16 ASCII characters long.</source>
        <translation>Lokální klíč musí mít 16 znaků ASCII.</translation>
    </message>
    <message>
        <source>Could not save settings.</source>
        <translation>Nastavení se nepodařilo uložit.</translation>
    </message>
    <message>
        <source>Thermostat unavailable</source>
        <translation>Termostat je nedostupný</translation>
    </message>
    <message>
        <source>Could not establish a Tuya LAN session</source>
        <translation>Nelze navázat relaci Tuya LAN</translation>
    </message>
    <message>
        <source>Invalid response from the thermostat</source>
        <translation>Neplatná odpověď termostatu</translation>
    </message>
    <message>
        <source>Could not load TinyTuya</source>
        <translation>Nelze načíst TinyTuya</translation>
    </message>
    <message>
        <source>Could not start the Python backend</source>
        <translation>Nelze spustit Python backend</translation>
    </message>
    <message>
        <source>Temperature is out of range</source>
        <translation>Teplota je mimo povolený rozsah</translation>
    </message>
    <message>
        <source>Invalid command</source>
        <translation>Neplatný příkaz</translation>
    </message>
    <message>
        <source>The thermostat did not report the keypad lock status</source>
        <translation>Termostat neohlásil stav zámku kláves</translation>
    </message>
    <message>
        <source>The thermostat did not confirm the change</source>
        <translation>Termostat změnu nepotvrdil</translation>
    </message>
    <message>
        <source>Current</source>
        <translation>Aktuální</translation>
    </message>
    <message>
        <source>Set</source>
        <translation>Nastavená</translation>
    </message>
    <message>
        <source>Heating</source>
        <translation>Topí</translation>
    </message>
    <message>
        <source>Not heating</source>
        <translation>Netopí</translation>
    </message>
    <message>
        <source>Setup required</source>
        <translation>Chybí nastavení</translation>
    </message>
    <message>
        <source>Unavailable</source>
        <translation>Nedostupný</translation>
    </message>
    <message>
        <source>Reading status…</source>
        <translation>Zjišťuji stav…</translation>
    </message>
    <message>
        <source>About</source>
        <translation>O aplikaci</translation>
    </message>
    <message>
        <source>Settings</source>
        <translation>Nastavení</translation>
    </message>
    <message>
        <source>Unlock keypad</source>
        <translation>Odemknout klávesy</translation>
    </message>
    <message>
        <source>Lock keypad</source>
        <translation>Zamknout klávesy</translation>
    </message>
    <message>
        <source>Heating mode…</source>
        <translation>Režim vytápění…</translation>
    </message>
    <message>
        <source>Turn off thermostat</source>
        <translation>Vypnout termostat</translation>
    </message>
    <message>
        <source>Turn on thermostat</source>
        <translation>Zapnout termostat</translation>
    </message>
    <message>
        <source>Connected over LAN</source>
        <translation>Dostupný přes LAN</translation>
    </message>
    <message>
        <source>Set temperature</source>
        <translation>Nastavená teplota</translation>
    </message>
    <message>
        <source>Lower the set temperature by half a degree</source>
        <translation>Snížit nastavenou teplotu o půl stupně</translation>
    </message>
    <message>
        <source>Raise the set temperature by half a degree</source>
        <translation>Zvýšit nastavenou teplotu o půl stupně</translation>
    </message>
    <message>
        <source>The thermostat did not confirm the mode change.</source>
        <translation>Termostat změnu režimu nepotvrdil.</translation>
    </message>
    <message>
        <source>The thermostat did not confirm the change.</source>
        <translation>Termostat změnu nepotvrdil.</translation>
    </message>
    <message>
        <source>Waiting for the thermostat to confirm…</source>
        <translation>Čekám na potvrzení termostatu…</translation>
    </message>
    <message>
        <source>Waiting for the thermostat to confirm %1 mode…</source>
        <translation>Čekám na potvrzení režimu %1…</translation>
    </message>
    <message>
        <source>Checking the change…</source>
        <translation>Ověřuji změnu…</translation>
    </message>
    <message>
        <source>Current temperature %1</source>
        <translation>Aktuální teplota %1</translation>
    </message>
    <message>
        <source>Thermostat</source>
        <translation>Termostat</translation>
    </message>
    <message>
        <source>On</source>
        <translation>Zapnutý</translation>
    </message>
    <message>
        <source>Off</source>
        <translation>Vypnutý</translation>
    </message>
    <message>
        <source>Thermostat keypad</source>
        <translation>Klávesy termostatu</translation>
    </message>
    <message>
        <source>Locked</source>
        <translation>Zamčené</translation>
    </message>
    <message>
        <source>Unlocked</source>
        <translation>Odemčené</translation>
    </message>
    <message>
        <source>Unknown</source>
        <translation>Stav neznámý</translation>
    </message>
</context>
</TS>

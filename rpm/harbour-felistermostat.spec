# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

Name:       harbour-felistermostat
Summary:    Local EMOS GoSmart thermostat control for Sailfish OS
Version:    1.0.0
Release:    26
License:    GPL-3.0-or-later
Source0:    %{name}-%{version}.tar.bz2
ExclusiveArch: aarch64
Requires:   sailfishsilica-qt5
Requires:   pyotherside-qml-plugin-python3-qt5
Requires:   python3-base >= 3.11
Requires:   python3-base < 3.12
Requires:   python3-libs >= 3.11
BuildRequires: pkgconfig(sailfishapp) >= 1.0.2
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: desktop-file-utils
BuildRequires: qt5-qttools-linguist
%global __requires_exclude_from ^%{_datadir}/%{name}/vendor/.*$
%global __provides_exclude_from ^%{_datadir}/%{name}/vendor/.*$

%description
A native Sailfish Silica application for the EMOS GoSmart P56211.
Uses local Tuya LAN communication over a direct IPv4 connection.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5 FELISTERMOSTAT_BUILD_VERSION=%{version}-%{release}
%make_build

%install
%qmake5_install
translations_dir="%{buildroot}%{_datadir}/%{name}/translations"
install -d -m 0755 "$translations_dir"
for catalog in translations/%{name}-*.ts; do
    filename=${catalog##*/}
    lrelease -nounfinished "$catalog" -qm "$translations_dir/${filename%.ts}.qm"
done
vendor_dir="%{buildroot}%{_datadir}/%{name}/vendor"
install -d -m 0755 "$vendor_dir"
tar -xzf vendor-site.tar.gz -C "$vendor_dir" --strip-components=1
test -f "$vendor_dir/tinytuya/__init__.py"
desktop-file-install --delete-original --dir %{buildroot}%{_datadir}/applications %{buildroot}%{_datadir}/applications/%{name}.desktop

%files
%license LICENSE docs/Apache-2.0.txt docs/Native-Notices.txt
%doc README.md THIRD_PARTY.md
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

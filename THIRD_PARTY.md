# Third-party software and notices

FelisTermostat and its cat icon are project material by Michal Kasík (MiPal), released under GPL-3.0-or-later. The thermostat status icons are drawn in the project's QML. Qt Quick, Sailfish Silica, libsailfishapp, CPython 3.11 and PyOtherSide are provided by the Sailfish OS environment. The RPM uses those platform components under their own terms. See the upstream notices for [libsailfishapp](https://github.com/sailfishos/libsailfishapp/blob/master/license.lgpl) and [PyOtherSide](https://github.com/thp/pyotherside/blob/master/LICENSE).

## Bundled Python packages

The table reflects the wheels in the tested aarch64 RPM (build 1.0.0-24). Each link leads to the upstream files for the exact release, including its source distribution where provided. The RPM retains the license and notice files shipped in the wheels under `vendor/*.dist-info/licenses/`.

| Package and upstream release | License |
| --- | --- |
| [certifi 2026.10.23](https://pypi.org/project/certifi/2026.10.23/#files) | MPL-2.0. The CA bundle is distributed in the upstream PEM form. |
| [cffi 2.1.1](https://pypi.org/project/cffi/2.1.1/#files) | MIT-0 as declared by the wheel. The Linux wheel statically links libffi, listed below. |
| [charset-normalizer 3.5.2](https://pypi.org/project/charset-normalizer/3.5.2/#files) | MIT |
| [colorama 0.4.6](https://pypi.org/project/colorama/0.4.6/#files) | BSD-3-Clause |
| [cryptography 50.0.2](https://pypi.org/project/cryptography/50.0.2/#files) | Apache-2.0 OR BSD-3-Clause for cryptography itself. Its wheel also contains OpenSSL and Rust dependencies. |
| [idna 3.20](https://pypi.org/project/idna/3.20/#files) | BSD-3-Clause |
| [pycparser 3.12](https://pypi.org/project/pycparser/3.12/#files) | BSD-3-Clause |
| [requests 2.34.2](https://pypi.org/project/requests/2.34.2/#files) | Apache-2.0, with the upstream NOTICE retained |
| [TinyTuya 1.21.1](https://pypi.org/project/tinytuya/1.21.1/#files) | MIT |
| [urllib3 2.8.0](https://pypi.org/project/urllib3/2.8.0/#files) | MIT |

## Native components in the wheels

CFFI's [release build workflow](https://github.com/python-cffi/cffi/blob/v2.1.1/.github/workflows/ci.yaml#L165-L185) identifies [libffi 3.4.6](https://github.com/libffi/libffi/releases/tag/v3.4.6) as a static dependency of its Linux wheel. Its MIT notice is included in [Native-Notices.txt](docs/Native-Notices.txt).

OpenSSL is supplied by the upstream cryptography wheel. The wheel's SBOM identifies [OpenSSL 4.0.3](https://github.com/openssl/openssl/releases/tag/openssl-4.0.3), released under Apache-2.0. See [the Apache license text](docs/Apache-2.0.txt) and the upstream OpenSSL release for source and notices. The cryptography wheel retains its OpenSSL and Rust component inventories in `vendor/cryptography-50.0.2.dist-info/sboms/`. The Rust SBOM records the versions and licenses of the crates included in the wheel. The [Cargo lockfile](https://github.com/pyca/cryptography/blob/50.0.2/Cargo.lock) identifies their registry sources and checksums. The [wheel build workflow](https://github.com/pyca/cryptography/blob/50.0.2/.github/workflows/wheel-builder.yml) records how upstream built the wheel. The RPM includes additional native dependency notices in [Native-Notices.txt](docs/Native-Notices.txt). The Rust dependency `self_cell` is used under its Apache-2.0 option.

The permissive licenses listed above can coexist with GPLv3 and the separately bundled, unmodified certifi files retain MPL-2.0 and their source availability. Project source, packaging scripts and the dependency version list are available from the [v1.0.0 source tag](https://github.com/MiPal666/FelisTermostat/tree/v1.0.0).

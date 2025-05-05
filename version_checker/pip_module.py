# SPDX-FileCopyrightText: 2025 Joe Pitt
#
# SPDX-License-Identifier: GPL-3.0-only

"""Get the latest version of a PIP module from pypi"""

from os import getenv
from sys import exit as sys_exit

from requests import get


def main(package: str = None):
    """Main Function"""
    if package is None:
        package = getenv("PIP_PACKAGE")
    if package is None:
        sys_exit(1)

    response = get(f"https://pypi.org/pypi/{package}/json", timeout=10)
    response.raise_for_status()
    metadata = response.json()
    print(f'{package}={metadata["info"]["version"]}')


if __name__ == "__main__":
    main()

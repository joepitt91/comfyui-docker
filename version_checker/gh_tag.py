# SPDX-FileCopyrightText: 2025 Joe Pitt
#
# SPDX-License-Identifier: GPL-3.0-only

"""Get latest semver tag from GitHub repo"""

from os import getenv
from typing import Dict
from sys import exit as sys_exit

from semver import Version
from requests import get


def clean_version(version: str) -> str:
    """Tidy up versions numbers for parsing"""

    return (
        version.replace("v", "")
        .replace("V", "")
        .replace(".01", ".1")
        .replace(".02", ".2")
        .replace(".03", ".3")
        .replace(".04", ".4")
        .replace(".05", ".5")
        .replace(".06", ".6")
        .replace(".07", ".7")
        .replace(".08", ".8")
        .replace(".09", ".9")
    )


def get_latest_version_tag(repository: str, token: str) -> Version:
    """Gets the latest version tag from a repository.

    Args:
        repository (str): The repository name.
        token (str): The GitHub token to authenticate with.

    Raises:
        HTTPError: If the tags cannot be pulled.

    Returns:
        Version: The latest version in the repository.
    """

    current_version = Version(0)
    response = get(
        f"https://api.github.com/repos/{repository}/tags",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    response.raise_for_status()
    tags: Dict[str, str | Dict[str, str]] = response.json()
    for tag in tags:
        try:
            version = Version.parse(clean_version(tag["name"]))
            if version.compare(current_version) == 1:
                current_version = version
        except ValueError:
            pass
    return current_version


def main(repository: str | None = None, github_token: str | None = None):
    """Main Function"""
    if repository is None:
        repository = getenv("GITHUB_REPO")
    if github_token is None:
        github_token = getenv("GITHUB_TOKEN")
    if repository is None or github_token is None:
        sys_exit(1)

    print(get_latest_version_tag(repository, github_token))


if __name__ == "__main__":
    main()

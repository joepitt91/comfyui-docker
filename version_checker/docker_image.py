# SPDX-FileCopyrightText: 2025 Joe Pitt
#
# SPDX-License-Identifier: GPL-3.0-only

"""Get latest image digest from DockerHub"""

from dataclasses import dataclass
from os import getenv
from sys import exit as sys_exit

from semver import Version
from requests import get
from requests.auth import HTTPBasicAuth


@dataclass
class GitHubTag:
    """A tag on GitHub."""

    version: Version
    commit_id: str


def get_docker_token(username: str, password: str, repository: str) -> str:
    """Get a Docker Hub token to pull manifests.

    Args:
        username (str): The account username.
        password (str): The account password or token.
        repository (str): The repository requiring access.

    Raises:
        HTTPError: If the tags cannot be pulled.

    Returns:
        str: The token to use to pull manifests
    """

    response = get(
        "https://auth.docker.io/token?service=registry.docker.io&"
        f"scope=repository:{repository}:pull",
        auth=HTTPBasicAuth(username, password),
        timeout=10,
    )
    response.raise_for_status()
    token = response.json()
    return token["token"]


def main(
    repository: str | None = None,
    username: str | None = None,
    password: str | None = None,
    tag="latest",
) -> str:
    """Main Function"""

    if repository is None:
        repository = getenv("DOCKER_REPOSITORY")
    if repository is None:
        sys_exit(1)
    if username is None:
        username = getenv("DOCKER_USER")
    if username is None:
        sys_exit(2)
    if password is None:
        password = getenv("DOCKER_PASSWORD")
    if password is None:
        sys_exit(3)
    if tag == "latest":
        env_tag = getenv("DOCKER_TAG")
        if env_tag is not None:
            tag = env_tag

    api_key = get_docker_token(username, password, repository)
    response = get(
        f"https://registry-1.docker.io/v2/{repository}/manifests/{tag}",
        headers={"Authorization": f"Bearer {api_key}"},
        timeout=10,
    )
    response.raise_for_status()

    digests = response.json()
    for digest in digests["manifests"]:
        if (
            digest["platform"]["os"] == "linux"
            and digest["platform"]["architecture"] == "amd64"
        ):
            print(f'digest={digest["digest"]}')
            sys_exit()
    raise ValueError("No Matching manifest")


if __name__ == "__main__":
    main()

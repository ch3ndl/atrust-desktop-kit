# Attribution and licensing boundary

This is an independent deployment companion, not the official aTrust client
or an authorized successor to any upstream project. Original files in this
repository are offered under the MIT license in LICENSE.

## Thanks and external dependencies

- **kenvix and the aTrustLogin contributors**:
  https://github.com/kenvix/aTrustLogin . Their work provides the externally
  downloaded runtime image and inspired this deployment workflow. Inspected
  revision: `f8f25b5efb58389e277b4ec6cb232e6881d9a1e7` (2026-11-09).
  At that revision, the root contains no LICENSE file and GitHub reports no
  declared license. Public availability is not treated here as permission to
  relicense their implementation. No upstream Python source, modified full
  source file, Dockerfile, or Docker image is distributed by this repository.
  The original image is downloaded directly by the user; its components and
  any applicable terms remain the responsibility of their respective owners.
- **docker-easyconnect contributors, including hagb**:
  https://github.com/docker-easyconnect/docker-easyconnect . Foundational work
  on containerized aTrust/EasyConnect, proxy services, and desktop access.
  The repository's LICENSE.txt is WTFPL; this project's MIT license does not
  replace that license or apply to their repository.
- **noVNC and websockify contributors**:
  https://github.com/novnc/noVNC and https://github.com/novnc/websockify .
  Browser desktop access uses the copies already installed in the third-party
  image. No copies of those projects are vendored or relicensed here.
- **Sangfor** owns the proprietary aTrust client. The client binary is not
  included in this repository and is not licensed under this project's MIT
  license. aTrust and related marks belong to their respective owners.
- Selenium, Chromium, Docker, Python, and other runtime dependencies retain
  their own licenses. Refer to their official distributions for notices.

## What this project adds

Independent Windows launch/configuration scripts, optional plaintext or
Windows DPAPI credential storage, browser desktop integration, and an
independently written Selenium login helper. The helper uses real keyboard
events and checks values before submitting; each new process uses a fresh
browser session rather than importing old cookies or localStorage.

The runtime launcher replaces only the image entrypoint Python file using a
read-only bind mount; it does not import or copy aTrustLogin's Python modules.
The original source remains in the external image. No claim is made that this
repository grants rights to redistribute that image. Do not build or publish
a bundled derivative image without first resolving its licensing terms.

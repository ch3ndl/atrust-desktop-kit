# SPDX-License-Identifier: MIT
"""Entrypoint mounted into the externally supplied runtime image."""
from desktop_helper import main

if __name__ == "__main__":
    raise SystemExit(main())

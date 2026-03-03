#!/usr/bin/env python3

import os

from clienterp_runtime.license_guard import enforce_or_exit


def main() -> None:
    """Enforce license, then transfer control to Odoo CLI entrypoint."""
    enforce_or_exit()
    os.environ.setdefault("TZ", "UTC")
    import odoo

    odoo.cli.main()


if __name__ == "__main__":
    main()

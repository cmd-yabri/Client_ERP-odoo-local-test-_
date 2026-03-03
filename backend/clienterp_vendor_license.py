#!/usr/bin/env python3

"""Thin executable wrapper for vendor-side license CLI."""

from clienterp_runtime.vendor_license_cli import main


if __name__ == "__main__":
    raise SystemExit(main())

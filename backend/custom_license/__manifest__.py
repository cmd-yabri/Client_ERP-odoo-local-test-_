{
    "name": "ClientERP Offline License Guard",
    "summary": "Enforces signed offline activation for local Windows deployments",
    "description": """
Signed offline licensing for ClientERP.
- No MAC-only binding.
- Uses a signed license payload.
- Blocks server startup when license is invalid.
    """,
    "author": "ClientERP",
    "category": "Tools",
    "version": "1.0.0",
    "depends": ["base", "web"],
    "data": [],
    "installable": True,
    "auto_install": True,
    "application": False,
}

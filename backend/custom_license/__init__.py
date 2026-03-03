from . import models

def post_load():
    from clienterp_runtime.license_guard import enforce_or_raise

    enforce_or_raise()

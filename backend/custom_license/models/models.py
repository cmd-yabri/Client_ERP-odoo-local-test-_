from odoo import api, models
from odoo.exceptions import UserError

from clienterp_runtime.license_guard import (
    install_license,
    status_dict,
    write_activation_request,
)


class ClientLicense(models.AbstractModel):
    _name = "client.license"
    _description = "ClientERP Offline License"

    @api.model
    def verify(self):
        status = status_dict()
        if not status["valid"]:
            raise UserError(status["reason"])
        return True

    @api.model
    def get_status(self):
        return status_dict()

    @api.model
    def generate_activation_request(self):
        request_path = write_activation_request()
        return str(request_path)

    @api.model
    def install_license_file(self, source_path):
        target = install_license(source_path)
        return str(target)

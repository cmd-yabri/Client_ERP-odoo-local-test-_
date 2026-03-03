from odoo import models, fields

class ResPartner(models.Model):
    """Extend contacts with instructor flag used by academy module."""

    # _inherit tells Odoo: "Don't create a new table, just add to the existing one!"
    _inherit = 'res.partner'

    is_instructor = fields.Boolean(string='Is an Instructor', default=False)

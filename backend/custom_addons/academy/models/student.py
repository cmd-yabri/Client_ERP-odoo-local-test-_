from odoo import api, fields, models
from odoo.exceptions import ValidationError

class AcademyStudent(models.Model):
    """Academy student model with basic validation and create customization."""

    _name = 'academy.student'
    _description = 'Academy Student'

    name = fields.Char(string='Student Name', required=True)
    email = fields.Char(string='Email')
    course_id = fields.Many2one('academy.course', string='Course')

    # --- 1. PYTHON CONSTRAINT ---
    @api.constrains('email')
    def _check_email_validity(self):
        """Ensure entered email contains '@' when email is provided."""
        for record in self:
            if record.email and '@' not in record.email:
                raise ValidationError("Please enter a valid email address containing '@'.")

    # --- 2. BUSINESS LOGIC OVERRIDE ---
    # We are overriding Odoo's default 'create' method
    @api.model_create_multi
    def create(self, vals_list):
        """Title-case student names before delegating to default create flow."""
        for vals in vals_list:
            if 'name' in vals:
                vals['name'] = vals['name'].title()
        return super(AcademyStudent, self).create(vals_list)

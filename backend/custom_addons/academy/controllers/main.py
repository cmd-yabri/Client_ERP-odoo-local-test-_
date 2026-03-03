from odoo import http
from odoo.http import request

class AcademyAPI(http.Controller):
    """Public JSON API endpoints exposed by academy addon."""

    @http.route('/academy/get_courses', type='json', auth='public')
    def get_courses(self):
        """Return lightweight course list for public consumers."""
        courses = request.env['academy.course'].sudo().search([])
        return [{
            'id': c.id,
            'name': c.name,
            'students': c.student_count
        } for c in courses]

# -*- coding: utf-8 -*-
# from odoo import http


# class CustomLicense(http.Controller):
#     @http.route('/custom_license/custom_license', auth='public')
#     def index(self, **kw):
#         return "Hello, world"

#     @http.route('/custom_license/custom_license/objects', auth='public')
#     def list(self, **kw):
#         return http.request.render('custom_license.listing', {
#             'root': '/custom_license/custom_license',
#             'objects': http.request.env['custom_license.custom_license'].search([]),
#         })

#     @http.route('/custom_license/custom_license/objects/<model("custom_license.custom_license"):obj>', auth='public')
#     def object(self, obj, **kw):
#         return http.request.render('custom_license.object', {
#             'object': obj
#         })


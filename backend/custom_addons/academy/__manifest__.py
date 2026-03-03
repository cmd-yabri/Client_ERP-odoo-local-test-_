{
    'name': 'Academy Management System',
    'version': '1.0',
    'summary': 'Manage Courses and Students',
    'category': 'Education',
    'depends': ['base'],
    'data': [
        'security/ir.model.access.csv',
        'data/cron.xml',
        'report/course_report_template.xml',
        'views/views.xml'
    ],
    'installable': True,
    'application': True,
}
from odoo import api, fields, models

class AcademyCourse(models.Model):
    """Academy course model with workflow and student statistics."""

    _name = 'academy.course'
    _description = 'Academy Course'

    name = fields.Char(string='Course Name', required=True)
    description = fields.Text(string='Description')
    student_ids = fields.One2many('academy.student', 'course_id', string='Students')
    student_count = fields.Integer(string='Student Count', compute='_compute_student_count', store=True)
    
    # --- 1. WORKFLOW STATE FIELD ---
    state = fields.Selection([
        ('draft', 'Draft'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
    ], string='Status', default='draft')

    # --- 2. SQL CONSTRAINT ---
    _sql_constraints = [
        ('name_unique', 'unique(name)', 'The Course Name must be unique!')
    ]

    @api.depends('student_ids')
    def _compute_student_count(self):
        """Compute student count from related student records."""
        for record in self:
            record.student_count = len(record.student_ids)

    # --- 3. WORKFLOW ACTION BUTTONS ---
    def action_start_course(self):
        """Move course workflow state from draft to in progress."""
        for record in self:
            record.state = 'in_progress'

    def action_complete_course(self):
        """Mark course as completed in workflow state."""
        for record in self:
            record.state = 'completed'

    @api.model
    def check_active_courses(self):
        """Cron hook that logs count of currently in-progress courses."""
        # Search the database for all courses in progress
        in_progress_courses = self.search([('state', '=', 'in_progress')])

        # Log the result to the terminal
        import logging
        _logger = logging.getLogger(__name__)
        _logger.info(f"CRON JOB: There are currently {len(in_progress_courses)} courses in progress!")
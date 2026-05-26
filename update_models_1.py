# Update learning_module.py
with open('backend/app/models/learning_module.py', 'r') as f:
    content = f.read()

if 'assignments = relationship' not in content:
    old = '    videos = relationship("LearningVideo", back_populates="module", cascade="all, delete-orphan")'
    new = old + '\n    assignments = relationship("LearningModuleAssignment", back_populates="module", cascade="all, delete-orphan")'
    content = content.replace(old, new)

if 'class LearningModuleAssignment' not in content:
    content += '''

class LearningModuleAssignment(Base):
    __tablename__ = "learning_module_assignment"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    module_id = Column(String(36), ForeignKey("learning_module.id"), nullable=False)
    student_id = Column(String(36), ForeignKey("student.id"), nullable=False)
    assigned_by = Column(String(36), nullable=False)
    assigned_at = Column(DateTime, default=datetime.utcnow)

    module = relationship("LearningModule", back_populates="assignments")
'''

with open('backend/app/models/learning_module.py', 'w') as f:
    f.write(content)

print('✓ Updated learning_module.py')

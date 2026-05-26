# Update models/__init__.py
with open('backend/app/models/__init__.py', 'r') as f:
    content = f.read()

# Add import if not there
if 'LearningModuleAssignment' not in content:
    content = content.replace(
        'from app.models.learning_module import LearningModule, LearningVideo',
        'from app.models.learning_module import LearningModule, LearningVideo, LearningModuleAssignment'
    )
    # Add to __all__
    content = content.replace(
        '    "LearningVideo",',
        '    "LearningVideo",\n    "LearningModuleAssignment",'
    )

with open('backend/app/models/__init__.py', 'w') as f:
    f.write(content)

print('✓ Updated models/__init__.py')

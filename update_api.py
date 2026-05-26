# Update learning_modules.py API
with open('backend/app/api/learning_modules.py', 'r') as f:
    content = f.read()

# Update imports to include LearningModuleAssignment and Student
if 'LearningModuleAssignment' not in content:
    content = content.replace(
        'from app.models import User, LearningModule, LearningVideo',
        'from app.models import User, LearningModule, LearningVideo, LearningModuleAssignment, Student'
    )

# Add new endpoints before the final delete_video function
new_endpoints = '''

@router.get("/for-student/{student_id}")
def list_modules_for_student(student_id: str, db: Session = Depends(get_db)):
    """List learning modules assigned to a specific student."""
    # Verify student exists
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Get assigned modules
    assignments = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.student_id == student_id
    ).all()
    
    modules = [db.query(LearningModule).filter(LearningModule.id == str(a.module_id)).first() for a in assignments]
    modules = [m for m in modules if m]  # Filter out None values
    
    return [
        {
            "id": str(m.id),
            "name": m.name,
            "description": m.description,
            "created_at": m.created_at.isoformat() if m.created_at else None,
            "video_count": len(m.videos),
        }
        for m in modules
    ]


@router.post("/{module_id}/assign-to-student/{student_id}")
def assign_module_to_student(
    module_id: str,
    student_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Assign a learning module to a student (admin only)."""
    # Check module exists
    module = db.query(LearningModule).filter(LearningModule.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")
    
    # Check student exists
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Check if already assigned
    existing = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.student_id == student_id,
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Module already assigned to this student")
    
    # Create assignment
    assignment = LearningModuleAssignment(
        module_id=module_id,
        student_id=student_id,
        assigned_by=user.id,
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    
    return {
        "id": str(assignment.id),
        "module_id": str(assignment.module_id),
        "student_id": str(assignment.student_id),
        "assigned_at": assignment.assigned_at.isoformat() if assignment.assigned_at else None,
    }


@router.delete("/{module_id}/unassign-from-student/{student_id}")
def unassign_module_from_student(
    module_id: str,
    student_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Unassign a learning module from a student (admin only)."""
    assignment = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.student_id == student_id,
    ).first()
    
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    
    db.delete(assignment)
    db.commit()
    
    return {"message": "Module unassigned from student successfully"}

'''

# Insert before the final delete_video function
pos = content.rfind('@router.delete("/videos/{video_id}")')
if pos != -1:
    content = content[:pos] + new_endpoints + '\n' + content[pos:]

with open('backend/app/api/learning_modules.py', 'w') as f:
    f.write(content)

print('✓ Updated learning_modules.py API endpoints')

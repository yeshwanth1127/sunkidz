#!/bin/bash
# Run this script ON THE VPS to add branch_type column
# Run as: bash /path/to/add_branch_type.sh

psql -U sunkidz_user -d sunkidz_lms -h localhost << 'EOF'
ALTER TABLE branches ADD COLUMN IF NOT EXISTS branch_type VARCHAR(20) DEFAULT 'normal';
UPDATE branches SET branch_type = 'normal' WHERE branch_type IS NULL;
EOF

echo "Migration done: branch_type column added to branches table."

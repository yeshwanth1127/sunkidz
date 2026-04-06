import os
import sys
import logging
from sqlalchemy.orm import Session

# Add the project root to path so we can import 'app'
sys.path.append(os.getcwd())

from app.core.database import SessionLocal
from app.services.scheduler_service import check_pending_fee_reminders

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def run():
    """Entry point for the daily fee reminder check."""
    logger.info("Starting Daily Automated Fee Reminder script...")
    db: Session = SessionLocal()
    try:
        count = check_pending_fee_reminders(db)
        logger.info(f"Done. Successfully sent {count} notifications.")
    except Exception as e:
        logger.error(f"Error during reminder check: {str(e)}")
    finally:
        db.close()

if __name__ == "__main__":
    run()

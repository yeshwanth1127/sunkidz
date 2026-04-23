import os
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

def capture_screenshots():
    out_dir = r"d:\sunkidz\tablet_screenshots"
    os.makedirs(out_dir, exist_ok=True)
    
    # EXACT 7-inch Tablet Specifications for Google Play Console
    options = Options()
    options.add_argument("--window-size=1280,800")
    options.add_argument("--force-device-scale-factor=1.5")
    options.add_argument("--disable-infobars")
    
    # We are purposely NOT running headless so YOU can see it and log in!
    driver = webdriver.Chrome(options=options)
    
    print("\n" + "="*50)
    print("🚀 I HAVE OPENED A 7-INCH TABLET CHROME WINDOW!")
    print("👉 PLEASE LOG IN TO YOUR APP WITHIN THE NEXT 30 SECONDS...")
    print("="*50 + "\n")
    
    driver.get("http://localhost:21105/")
    time.sleep(5)
    
    # Capture Login First
    driver.save_screenshot(os.path.join(out_dir, "1_login_tablet.png"))
    
    # 30 seconds wait for manual login through the flutter canvas ui...
    time.sleep(30)
    
    print("📸 Snap! Capturing Dashboard...")
    driver.save_screenshot(os.path.join(out_dir, "2_dashboard_tablet.png"))
    
    driver.get("http://localhost:21105/#/students")
    time.sleep(8)
    print("📸 Snap! Capturing Students...")
    driver.save_screenshot(os.path.join(out_dir, "3_students_tablet.png"))
    
    driver.get("http://localhost:21105/#/enquiries")
    time.sleep(8)
    print("📸 Snap! Capturing Enquiries...")
    driver.save_screenshot(os.path.join(out_dir, "4_enquiries_tablet.png"))

    driver.get("http://localhost:21105/#/syllabus")
    time.sleep(8)
    print("📸 Snap! Capturing Syllabus...")
    driver.save_screenshot(os.path.join(out_dir, "5_syllabus_tablet.png"))

    driver.quit()
    print(f"\n✅ ALL 7-INCH SCREENSHOTS SAVED SUCCESSFULLY TO: {out_dir}\n")

if __name__ == '__main__':
    capture_screenshots()


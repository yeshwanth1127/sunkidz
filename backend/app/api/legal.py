from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["Legal"])

html_content = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - Sunkidz LMS</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background-color: #f9f9f9; color: #333; }
        .container { max-width: 800px; margin: auto; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        h1, h2, h3 { color: #2c3e50; }
        h1 { border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        p { margin-bottom: 15px; }
        ul { margin-bottom: 15px; padding-left: 20px; }
        .last-updated { font-style: italic; color: #7f8c8d; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Privacy Policy</h1>
        <p class="last-updated">Last Updated: March 2026</p>
        
        <h2>1. Introduction</h2>
        <p>Welcome to Sunkidz LMS ("we," "our," or "us"). We are committed to protecting your privacy to provide a safe, secure educational environment. This Privacy Policy outlines our practices regarding the collection, use, and disclosure of your information when you use the Sunkidz LMS mobile application and related services.</p>
        <p>This app is meticulously designed for kindergarten administration, teachers, bus staff, and parents. We strictly comply with the Google Play Store's Developer Program Policies, particularly the Families Policy, and other applicable child protection laws such as COPPA (Children's Online Privacy Protection Act).</p>

        <h2>2. Information Collection</h2>
        <p>Our app does not require or collect personal information directly from children. All student data is provided securely by the school administration, parents, or authorized legal guardians. We may collect the following types of information strictly for operational purposes:</p>
        <ul>
            <li><strong>Personal Data:</strong> Names, email addresses, phone numbers, and emergency contact information of parents and staff.</li>
            <li><strong>Student Data:</strong> Student names, dates of birth, medical/allergy information, attendance, marks, and daily activities, provided explicitly by parents and the school.</li>
            <li><strong>Media:</strong> Photos and videos uploaded by authorized staff for the daycare gallery and updates, strictly visible only to the verified parents of the child.</li>
            <li><strong>Location Data:</strong> For our school bus tracking feature, we collect real-time location data <em>only</em> from the devices of our authorized bus staff while they are on their active route. We <strong>do not</strong> track or collect the location of parents or children.</li>
            <li><strong>Device Information:</strong> Device identifiers and push notification tokens (e.g., via OneSignal) strictly for sending critical school updates such as attendance alerts and bus arrivals.</li>
        </ul>

        <h2>3. Use of Information</h2>
        <p>The information we collect is strictly used for the following educational, communicative, and safety purposes:</p>
        <ul>
            <li>To manage kindergarten admissions, daily attendance, class syllabus, and academic progress.</li>
            <li>To provide parents with real-time updates regarding their child's daytime activities, meals, and naps in daycare.</li>
            <li>To offer real-time school bus tracking for the safety and peace of mind of parents.</li>
            <li>To facilitate secure, localized messaging between parents, teachers, and administrators.</li>
            <li>To send necessary administrative notifications, event alerts, and emergency updates.</li>
        </ul>

        <h2>4. Data Sharing and Disclosure</h2>
        <p>We <strong>do not sell, rent, trade, or otherwise share</strong> your personal information or student data to third parties for marketing or advertising purposes. Data may only be shared in the following highly restricted circumstances:</p>
        <ul>
            <li><strong>With Authorized Users:</strong> Security is role-based. Parents can only access information pertaining to their own children. Staff members only access data necessary for their specific roles.</li>
            <li><strong>Service Providers:</strong> We use trusted third-party service providers (e.g., secure cloud hosting, notification services) that are legally bound by strict confidentiality and data protection agreements.</li>
            <li><strong>Legal Requirements:</strong> If explicitly required by law or a valid governmental request, we may disclose information to protect our legal rights or ensure user safety.</li>
        </ul>

        <h2>5. Third-Party Advertising & Google Play Families Policy Compliance</h2>
        <p>Sunkidz LMS is a robust tool designed for parents and educators. While children cannot create accounts, we recognize that families interact with our platform. To support our operations, the app may display third-party advertisements. To ensure a completely safe environment and strict compliance with the Google Play Store Families Policy, we guarantee the following regarding our advertising practices:</p>
        <ul>
            <li><strong>No Personalized Ads:</strong> We do not track users, collect Advertising IDs, or use personal data (such as browsing history or demographics) to serve targeted advertisements. All ads displayed are contextual and non-personalized.</li>
            <li><strong>Certified Ad Networks:</strong> We exclusively use third-party ad networks that have been certified by Google as fully compliant with their Designed for Families program.</li>
            <li><strong>Appropriate Content:</strong> We aggressively filter advertisements to ensure that no mature, explicit, deceptive, or inappropriate content is displayed. All data collection regarding students is performed under the direct supervision of the school, ensuring standard educational privacy laws are maintained regardless of advertising.</li>
        </ul>

        <h2>6. Data Security</h2>
        <p>We implement robust, industry-standard cryptographic security measures, including HTTPS encryption and secure credential storage, to protect the confidentiality and integrity of your personal information and student data against unauthorized access, alteration, or disclosure.</p>

        <h2>7. Data Retention and Deletion</h2>
        <p>We retain data only as long as necessary to provide our Service to the school and parents. If a student leaves the kindergarten, or if a parent requests account deletion, we will securely delete or anonymize their personal data in accordance with school policies and applicable laws. Users can instantly request data deletion by contacting their school administration or via the app settings.</p>

        <h2>8. Changes to This Privacy Policy</h2>
        <p>We may update our Privacy Policy periodically to reflect changes in legal or operational requirements. We will notify users of any material changes by updating the "Last Updated" date on this page, and optionally through push notifications. We encourage you to review this policy periodically.</p>

        <h2>9. Contact Us</h2>
        <p>If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us at:</p>
        <p><strong>Email:</strong> support@exora.solutions</p>
        <p><strong>Address:</strong> D Block, 694, 2nd Cross D Block Rd, AECS Layout - C Block, AECS Layout, Brookefield, Bengaluru, Karnataka 560037</p>
    </div>
</body>
</html>
"""

@router.get("/privacy-policy", response_class=HTMLResponse)
def get_privacy_policy():
    """Returns the Privacy Policy HTML page."""
    return html_content


delete_account_content = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Delete Account - Sunkidz LMS</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background-color: #f9f9f9; color: #333; }
        .container { max-width: 700px; margin: auto; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        h1 { color: #c0392b; border-bottom: 2px solid #c0392b; padding-bottom: 10px; }
        p { margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Delete Your Account</h1>
        <p><strong>App:</strong> Sunkidz LMS &mdash; by Exora Solutions</p>
        <p>To request deletion of your account and all associated data, simply send an email to:</p>
        <p><strong><a href="mailto:support@exora.solutions">support@exora.solutions</a></strong></p>
        <p>Use the subject line: <em>"Account Deletion Request - Sunkidz LMS"</em> and include your registered email address or admission number.</p>
        <p>Your account and all personal data will be permanently deleted within <strong>7 business days</strong> of your request.</p>
    </div>
</body>
</html>
"""

@router.get("/delete-account", response_class=HTMLResponse)
def get_delete_account():
    """Returns the Account Deletion request page."""
    return delete_account_content

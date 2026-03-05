# Adding Sunkidz Logo

## Steps to add your logo:

1. **Prepare your logo image:**
   - Save your logo as `sunkidz_logo.png`
   - Recommended size: 512x512 pixels (PNG format with transparent background works best)
   - You can use JPG, PNG, or other image formats supported by Flutter

2. **Place the logo file:**
   - Copy your logo file to: `mobile/assets/images/sunkidz_logo.png`
   - The folder structure is already created
   - The pubspec.yaml is already configured to include assets

3. **After adding the logo:**
   - Run `flutter pub get` to refresh assets
   - Do a full app restart (not hot reload)
   - The logo will appear on:
     - Landing page (initial screen)
     - Login page
     - All dashboard screens (Admin, Teacher, Coordinator, Parent, Bus Staff)
     - Drawer headers

4. **If you don't have a logo yet:**
   - The app will show a fallback icon (school icon)
   - Everything will still work perfectly
   - You can add the logo later without any code changes

## Logo locations in the app:
- **Landing Screen:** Large centered logo with gradient background
- **Login Screen:** Top center with "SUNKIDZ" text
- **Dashboards:** Small logo in the AppBar next to title
- **Drawers:** Logo in the drawer header

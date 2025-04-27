# Advanced Google Sheets Integration Setup

This document explains how to set up advanced Google Sheets integration using your own Google Service Account. This gives you direct API access and more control over your Mosque Management data.

## Why Use Advanced Setup?

1. **Direct API Access**: Connect directly to Google Sheets without relying on the app's server
2. **Full Control**: Use your own Google account and credentials
3. **Higher Reliability**: No dependency on third-party scripts for data access
4. **Enhanced Security**: Your data is accessed only by your own service account

## Setup Instructions

### 1. Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Create Project" and follow the prompts to create a new project
3. Note your Project ID - you'll need it later

### 2. Enable Required APIs

1. In your Google Cloud project, go to "APIs & Services" > "Library"
2. Search for and enable the following APIs:
   - Google Sheets API
   - Google Drive API

### 3. Create a Service Account

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" and select "Service Account"
3. Fill in the service account details:
   - Name: "Mosque Management" (or any name you prefer)
   - ID: This will be auto-generated
   - Description: "Service account for Mosque Management app"
4. Click "Create and Continue"
5. For "Grant this service account access to project", select "Editor" role
6. Click "Continue" and then "Done"

### 4. Create Service Account Key

1. From the Credentials page, click on your newly created service account
2. Go to the "Keys" tab
3. Click "Add Key" > "Create new key"
4. Choose "JSON" as the key type
5. Click "Create"
6. The key file (service_account.json) will be downloaded to your computer
7. Move this file to an easily accessible location on your device (e.g., Downloads folder)

### 5. Create API Key

1. In your Google Cloud project, go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" and select "API Key"
3. The new API key will be created and displayed
4. Click "Restrict Key" to set up appropriate restrictions
5. Under "API restrictions", select "Restrict key" and choose:
   - Google Sheets API
   - Google Drive API
6. Click "Save"
7. Copy your API key for use in the app

### 6. Set Up in the App

1. Open the Mosque Management app
2. Go to the first-time setup screen
3. Enter your mosque name and security key
4. Enable "Advanced Setup" by turning on the toggle
5. Click "Select Service Account File" and choose the service_account.json file you downloaded
6. Enter your email address to share the spreadsheet with
7. Enter your Google Cloud API Key created in step 5
8. Click "Enable Cloud Database" to create your spreadsheet using your service account

## Important Notes

- Keep your service_account.json file and API key secure - they contain sensitive credentials
- Make sure your device has the service account file available when you need to use the app
- The email you provide will be given editor access to the created spreadsheet
- You can access the spreadsheet directly via your Google account
- Ensure your API key has the appropriate restrictions to prevent unauthorized use

## Troubleshooting

### JSON File Selection Issues

If you're having trouble selecting the service account JSON file:

1. **File Not Visible**: Some devices may not properly show .json files. Try these solutions:
   - Rename your file to clearly indicate it's JSON (e.g., "service-account.json")
   - Move the file to a more accessible location like the Downloads folder
   - If using external storage, try moving it to internal storage

2. **File Not Recognized**: If the app doesn't recognize your file as JSON:
   - Make sure the file has a .json extension
   - Check that the file contains the required fields (see below)
   - Try opening the file in a text editor to verify it's valid JSON

3. **Verifying File Contents**: A valid service account JSON file should contain:
   - `"type": "service_account"`
   - `"project_id": "[your-project-id]"`
   - `"private_key": "-----BEGIN PRIVATE KEY-----..."`
   - `"client_email": "[something]@[your-project].iam.gserviceaccount.com"`

4. **Using Alternative File Selection**: The app will try to:
   - First look for files with .json extension
   - If that fails, allow selection of any file type and verify JSON content

### Other Common Issues

**Q: I'm getting authentication errors.**  
A: Make sure you've enabled both the Google Sheets API and Google Drive API in your Google Cloud project, and that your API key is valid and has the right permissions.

**Q: I'm getting "API key not valid" errors.**  
A: Verify that you've entered the correct API key and that it's active in your Google Cloud project. You may need to create a new API key if the current one has issues.

**Q: The app can't find my service_account.json file.**  
A: Make sure you've selected the correct file path. Try moving the file to a more accessible location.

**Q: I don't see my spreadsheet in Google Drive.**  
A: Check the email you provided during setup. The spreadsheet should be shared with that email.

**Q: Can I switch from standard to advanced setup later?**  
A: Yes, you can set up a new mosque with advanced setup and recover your data.

## Need Help?

If you encounter any issues with the advanced setup, please contact our support team for assistance. 
# Frappe Power BI Connectors

Custom connectors for Power BI that allow you to pull data from Frappe DocTypes and Reports directly into Power BI for analysis and visualization.

## Requirements

- **Power BI Desktop** (latest version) — [Download here](https://powerbi.microsoft.com/en-us/desktop/)
- **Frappe Framework instance** (ERPNext or custom Frappe app) with HTTPS enabled
- **Frappe PowerBI Integration app installed** on your Frappe site — [Install here](https://github.com/ParaLogicTech/pbi_integration)
- **OAuth 2.0 client** configured in Frappe with redirect URI: `https://oauth.powerbi.com/views/oauthredirect.html`
- Admin access to your Frappe instance to configure OAuth

## Installation

### Step 1: Download the Connectors

1. Go to [GitHub Releases](https://github.com/ParaLogicTech/frappe_pbi_connector/releases)
2. Download `frappe-power-bi-connectors.zip` from the latest release
3. Extract the ZIP file to get:
   - `FrappeDocuments.mez`
   - `FrappeReports.mez`

### Step 2: Place Connector Files in Power BI

1. Navigate to your Documents folder:
   ```
   C:\Users\[YourUsername]\Documents
   ```

2. Create this folder if it doesn't exist:
   ```
   Power BI Desktop\Custom Connectors
   ```

3. Copy the extracted `.mez` files into the Custom Connectors folder:
   - `FrappeDocuments.mez`
   - `FrappeReports.mez`

Your path should look like:
```
C:\Users\[YourUsername]\Documents\Power BI Desktop\Custom Connectors\FrappeDocuments.mez
```

### Step 3: Configure Power BI Security Settings

1. Open **Power BI Desktop**
2. Click **File** → **Options and settings** → **Options**
3. Select **Security** in the left sidebar
4. Under **Data Extensions**, choose this option:
   - **(Not Recommended) Allow any extension to load without validation or warning**
5. Click **OK**
6. **Restart Power BI Desktop completely**

### Step 4: Verify Installation

1. In Power BI Desktop, click **Get Data** → **More...**
2. Search for: `"Frappe"`
3. You should see both **"Frappe Documents"** and **"Frappe Reports"**

If they don't appear:
- Verify `.mez` files are in the correct folder
- Restart Power BI completely
- Check Security settings are configured
- Verify filenames are exactly: `FrappeDocuments.mez` and `FrappeReports.mez`

## Using the Connectors

### Initial Connection

#### For Frappe Documents

1. Click **Get Data** → **More...**
2. Search for and select **"Frappe Documents"**
3. Click **Connect**
4. Enter your **Frappe Site URL**:
   - Full URL: `https://erp.yourcompany.com`
   - Or just domain: `erp.yourcompany.com` (HTTPS is added automatically)
5. Click **Connect**

#### For Frappe Reports

1. Click **Get Data** → **More...**
2. Search for and select **"Frappe Reports"**
3. Click **Connect**
4. Enter your **Frappe Site URL**
5. Click **Connect**

### Authentication

#### OAuth 2.0 (Recommended)

1. Click **Sign In** when prompted
2. A browser window opens with the Frappe login page
3. Enter your **Frappe username and password**
4. Click **Log In**
5. Authorize the Power BI Connector to access your data
6. Click **Authorize** or **Allow**
7. The browser will close and you'll return to Power BI
8. You're now authenticated

#### API Key and Secret

1. Click the **API Key** tab in the connector dialog
2. Enter your Frappe API Key and Secret in this format: `key:secret`
   - Replace spaces with nothing
   - Example: `abc123def456:xyz789uvw012`

### Browse and Load Data

1. In the Navigator window, you'll see available Frappe DocTypes or Reports
2. Click on any DocType/Report to preview the data
3. Select the ones you want to load
4. Click **Load** to import into Power BI
5. Power BI will fetch the data and add it to your workbook

## Refreshing Data

### Manual Refresh

1. Click **Refresh** in the Power BI ribbon
2. Power BI will re-fetch data from Frappe
3. Authentication tokens refresh automatically

### Scheduled Refresh on Power BI Service

The connector supports scheduled refresh using the **On-Premises Data Gateway**.

#### Setup Steps

1. **Install the gateway:**
   - Download from [Power BI Gateway](https://powerbi.microsoft.com/en-us/gateway/)
   - Run the installer and configure it

2. **Set up service account permissions:**
   - Ensure `NT SERVICE\PBIEgwService` has access to the Custom Connectors folder
   - Or change the service account to a local user account

3. **Place connector files for gateway:**
   - Copy `.mez` files to:
     ```
     C:\WINDOWS\ServiceProfiles\PBIEgwService\Documents\Power BI Desktop\Custom Connectors
     ```
   - Create any missing folders

4. **Upload your report to Power BI Service:**
   - Go to https://app.powerbi.com
   - Publish your Power BI workbook

5. **Configure gateway in Power BI Service:**
   - Navigate to **Settings** → **Manage Connections and Gateways**
   - Select your gateway and enable:
     - "Allow user's custom data connectors to refresh through this gateway cluster"
[Configure service gateway documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-custom-connectors)

6. **Set up scheduled refresh:**
   - Go to your dataset **Settings** in Power BI Service
   - Under **Gateway connection**, select your gateway
   - Configure **Scheduled refresh** with your desired schedule

For detailed steps, see [Microsoft's Scheduled Refresh Documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/refresh-scheduled-refresh)

## URL Format

The connector accepts URLs in these formats:

```
https://erp.yourcompany.com
erp.yourcompany.com
demo.erpnext.com
```

The connector automatically normalizes URLs to use HTTPS.

## Troubleshooting

### Connectors Not Appearing in Get Data

- Verify `.mez` files are in: `C:\Users\[YourUsername]\Documents\Power BI Desktop\Custom Connectors\`
- Restart Power BI Desktop completely
- Check that Security settings are configured to allow custom connectors
- Verify filenames are exact: `FrappeDocuments.mez` and `FrappeReports.mez`

### "This is not a Frappe instance" or "pbi_integration not installed"

- Verify your Frappe site URL is correct and accessible via browser
- Ensure the **pbi_integration app** is installed on your Frappe instance
- Contact your Frappe administrator to install the app if needed

### "HTTP 401 - Unauthorized"

- Re-authenticate by removing and re-adding the data source
- Verify OAuth client is configured in Frappe
- Check that your Frappe user account is active
- Verify your API Key and Secret if using API authentication

### "HTTP 403 - Forbidden"

- Check your Frappe user permissions for the specific DocType/Report
- Verify the DocType/Report is enabled in Frappe
- Contact your Frappe administrator for access

### No Data Appears

- Verify the DocType/Report exists and has data in your Frappe instance
- Check if filters are excluding all rows (try removing filters)
- Try a different DocType/Report to verify the connector works
- Ensure your Frappe user has read permissions

### URL Display Note

Power BI's credential display may show `http://` even though your actual connection uses HTTPS internally. This is a Power BI UI limitation. Your data transfer is always secure with HTTPS.

## Support

For issues or questions:

1. Check the **Troubleshooting** section above
2. Verify your Frappe instance is accessible via browser
3. Contact your Frappe administrator for permission issues
4. Ensure your internet connection is stable

## Building from Source

For developers who want to modify the connectors, see [BUILD.md](BUILD.md).

---

**Version:** 1.0  
**Compatibility:** Power BI Desktop / Service, Frappe v12+, ERPNext v12+  
**Last Updated:** October 2026

## Contribution

You can fork this repository and create a pull request to contribute. By contributing, you agree your contributions will be licensed under its GNU General Public License (v3).

## License

Frappe Power BI Connector is licensed under GNU General Public License (v3). Copyright owned by ParaLogic and Contributors. [See here](https://github.com/ParaLogicTech/frappe_pbi_connector/blob/master/license.txt)

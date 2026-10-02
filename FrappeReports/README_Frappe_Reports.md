# Frappe Reports Connector for Power BI

This repo contains the code needed to create a Power Query and Power BI custom connector for Frappe Framework, allowing you to pull data directly from Frappe Reports into Power BI for analysis and visualization.

## Getting started

Before you begin, ensure you have the following:

- **Power BI Desktop** (latest version) — [Download here](https://powerbi.microsoft.com/en-us/desktop/)
- **Visual Studio Code** — [Download here](https://code.visualstudio.com/)
- **Power Query SDK** — [Download here](https://marketplace.visualstudio.com/items?itemName=PowerQuery.powerquerysdk)
- **Frappe Framework instance** (ERPNext, CRM, or custom Frappe app)
- **Frappe instance must be HTTPS-enabled**
- **OAuth 2.0 client configured in Frappe** with redirect URI: `https://oauth.powerbi.com/views/oauthredirect.html`

### Prerequisites

1. Verify your Frappe instance is accessible over HTTPS
2. Ensure you have admin access to your Frappe instance to configure OAuth
3. Have your Frappe user credentials ready for authentication

## Installation

### Step 1 - Download and Build

1. Clone or download this repo from [GitHub](https://github.com/ParaLogicTech/frappe_pbi_connector)
2. Extract the ZIP file to a folder on your computer
3. Open Visual Studio Code
4. Go to **Extensions** (left sidebar) and install **Power Query SDK**
5. Restart VS Code
6. Open the connector folder in VS Code: **File** → **Open Folder** → select `frappe_pbi_connector`
7. Open Terminal: **Terminal** → **Run Build Task**  → **Build connector project using MakePQX**
8. Build the connector
9. Wait for the build to complete. You should see output file created:
   - `Frappe Reports.mez`

These files are in your project's 'bin' folder in the 'Debug' folder.

### Step 2 - Enable Custom Connectors in Power BI Desktop

Power BI has security settings that prevent uncertified custom connectors from loading by default. You need to change this.

1. Open **Power BI Desktop**
2. Click **File** → **Options and settings** → **Options**
3. In the left sidebar, select **Security**
4. Under **Data Extensions**, select the **Not Recommended** of these options:
   - **(Recommended) Only allow Microsoft certified and other trusted third-party extensions to load** — for maximum security (requires certificate setup)
   - **(Not Recommended) Allow any extension to load without validation or warning** — for quick testing
5. Click **OK**
6. **Restart Power BI Desktop completely**

### Step 3 - Place the Connector Files

1. Navigate to your Documents folder:
   ```
   C:\Users\[YourUsername]\Documents
   ```

2. Create the folder if they doesn't exist:
   ```
   Power BI Desktop\Custom Connectors
   ```

3. Copy the built `.mez` files into this folder:
   - `Frappe Reports.mez`
   - `Frappe Documents.mez`

Your path should look like:
```
C:\Users\[YourUsername]\Documents\Power BI Desktop\Custom Connectors\Frappe Reports.mez
```

### Step 4 - Restart Power BI Desktop

After placing the `.mez` files, restart Power BI Desktop completely. This allows Power BI to scan the Custom Connectors folder and register the new connectors.

### Step 5 - Verify the Connector is Loaded

1. In Power BI Desktop, click **Home** → **Get Data**
2. Click **More...** at the bottom
3. In the search box, type: **"Frappe"**
4. You should see: **"Frappe Reports"**

If it doesn't appear:
- Double-check the file location (must be in Custom Connectors folder)
- Verify the filename is exact: `Frappe Reports.mez`
- Restart Power BI again
- Check that you've enabled custom connectors in Security settings
- Verify the build process completed successfully

## Using the Connector

### Initial Connection

1. In Power BI Desktop, click **Get Data** → **More...**
2. Search for and select **"Frappe Reports"**
3. Click **Connect**
4. Enter your **Frappe Site URL** (e.g., `https://erp.yourcompany.com` or `erp.yourcompany.com`)
5. Optionally enter **Filters** for filtering data before loading
6. Click **Connect**

### Authentication

1. Click **Sign In** when prompted
2. A browser window opens with the Frappe login page
3. Enter your **Frappe username and password**
4. Click **Log In**
5. Authorize the Power BI Connector to access your Frappe data
6. Click **Authorize** or **Allow**
7. The browser will confirm, and the dialog in Power BI will close
8. You're now authenticated and can browse available reports

### Load Data

1. In the Navigator window, select the reports you want to load
2. Click **Load**/**Transform Data** to import the data into Power BI
3. Power BI will fetch the data and add it to your workbook

## Scheduled Refresh on Power BI Service

The connector supports scheduled refresh through the Power BI service via a Power BI On Premises Data Gateway (Standard mode).

### Step 1 – Set up the data gateway

1. Install the Power BI On-Premises Data Gateway in Standard mode. See [On-premises data gateway documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-onprem)
2. Select **Sign in**
3. Select **Register a new gateway on this computer**
4. Give the new gateway a name
5. Provide and confirm a recovery key. **Save this key carefully — it cannot be restored if lost**

### Step 2 - Set up the service account

Under Service Settings, ensure the Gateway Service Account (`NT SERVICE\PBIEgwService`) has permissions to access the Custom Connectors folder:

1. Add `NT SERVICE\PBIEgwService` to folder permissions for the Custom Connectors directory, OR
2. Change the service account to a local user (requires restarting the gateway)

### Step 3 - Connect the custom connector

For Power BI Service to access the custom connector, the `.mez` file must be in:
```
Documents\Power BI Desktop\Custom Connectors
```

Map the Data Gateway to this folder. You should see Frappe Reports appear as a custom connector option.

### Step 4 – Configure the gateway in Power BI Service

1. Go to https://app.powerbi.com
2. Navigate to **Settings** → **Manage Connections and Gateways**
3. Select the **On-premises data gateways** tab
4. Select your gateway and click the ellipses (…) → **Settings**
5. Ensure these options are enabled:
   - Allow user's cloud data sources to refresh through this gateway cluster
   - Allow user's custom data connectors to refresh through this gateway cluster
6. Click **Save**

**Optional**: Click **Manage users** to add other report developers who need access.

### Step 5 – Upload a dataset and configure the gateway

1. Publish a workbook using the connector to https://app.powerbi.com
2. Navigate to your workspace and find the published dataset
3. Click the ellipses (…) next to the dataset → **Settings**
4. Expand **Gateway connection**
5. Click the dropdown under **Actions** → **Manually add to gateway**
6. Provide a data source name (e.g., "Frappe Reports")
7. Set authentication type to **OAuth2**
8. Set privacy level to **Organizational**
9. Save and map the connector to your gateway

### Step 6 – Schedule refresh

Configure scheduled refresh using the gateway. See [Configure scheduled refresh documentation](https://learn.microsoft.com/en-us/power-bi/connect-data/refresh-scheduled-refresh).

## URL Format

The connector accepts URLs in these formats:
```
http://erp.yourcompany.com
https://erp/yourcompny.com
erp.yourcompany.com
```

The connector will automatically clean up and normalize the URL to use HTTPS.

## Troubleshooting

### Connector not appearing in Get Data

- Verify `.mez` files are in: `Documents\Power BI Desktop\Custom Connectors\`
- Restart Power BI Desktop completely
- Check that custom connectors are enabled in Security settings
- Verify filenames are exact: `Frappe Reports.mez`

### "Please enter the full URL with https://"

- Enter the full URL including protocol: `https://erp.yourcompany.com`
- Or enter just the domain: `erp.yourcompany.com` (connector will add HTTPS)

### "HTTP 401 - Unauthorized"

- Re authenticate by removing and re adding the data source
- Verify OAuth client is configured in Frappe
- Check that your Frappe user account is active

### "HTTP 403 - Forbidden"

- Check your Frappe user permissions
- Verify the report is marked as "Enabled" in Frappe
- Contact your Frappe administrator for access

### Blank or no data appears

- Verify the report exists and has data in your Frappe instance
- Check if filters are excluding all rows (try removing filters)
- Try selecting a different report to verify the connector works

## URL Display Note

Power BI's credential display may show `http://` even though your actual connection uses HTTPS internally. This is a Power BI UI limitation. Your data transfer is always secure with HTTPS.

## Support

For issues or questions:

1. Check the Troubleshooting section above
2. Verify your Frappe instance is accessible via browser
3. Contact your Frappe administrator for permission issues
4. Check your internet connection is stable

## Version

**Connector Version**: 1.0  
**Compatibility**: Power BI Desktop / Service, Frappe v12+, ERPNext v12+  
**Last Updated**: September 2026

## License

This connector is provided as is for integration between Power BI and Frappe Framework instances.

---

**For the Frappe Documents connector, see the separate README file.**

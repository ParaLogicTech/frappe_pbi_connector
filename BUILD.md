# Building Frappe Power BI Connectors

This guide is for developers who want to build the connectors from source or modify the code.

## Prerequisites

- **Visual Studio Code** — [Download here](https://code.visualstudio.com/)
- **Power Query SDK** — [Install from VS Code Extensions](https://marketplace.visualstudio.com/items?itemName=PowerQuery.powerquerysdk)
- **GitHub account** (for accessing the repository)

## Setup

### Step 1: Clone the Repository

Clone or download this repo from [GitHub](https://github.com/ParaLogicTech/frappe_pbi_connector)

### Step 2: Install Power Query SDK

1. Open Visual Studio Code
2. Go to **Extensions** (left sidebar, or Ctrl+Shift+X)
3. Search for **"Power Query SDK"**
4. Click **Install**
5. Restart VS Code when prompted

### Step 3: Open Project in VS Code

```
File → Open Folder → select frappe_pbi_connector → select 'FrappeReports' or 'FrappeDocuments' folder
```
## Building the Connectors

1. Open Terminal: **Terminal** → **Run Build Task**
2. Select **Build connector project using MakePQX**
3. Wait for completion

### Build Output

After successful build, you'll find `.mez` files in:
```
FrappeReports/bin/AnyCPU/Debug/FrappeReports.mez
FrappeDocuments/bin/AnyCPU/Debug/FrappeDocuments.mez
```

GitHub Actions builds both connectors on pushes of tags starting with `v` (for example, `v1.0.0`) and manual runs of the **Build connectors** workflow. Download the `frappe-power-bi-connectors` artifact from a successful workflow run to get `frappe-power-bi-connectors.zip`, which contains both `.mez` files. Runs for a tag starting with `v` create a GitHub release if needed and attach this ZIP to its assets. Manual runs for a branch only produce build artifacts.

### FrappeReports.pq

Main connector for querying Frappe Reports:
- OAuth 2.0 authentication and API Key authentication
- URL normalization
- Frappe instance and app validation
- Error handling with user friendly messages
- Report data fetching

### FrappeDocuments.pq

Main connector for querying Frappe DocTypes:
- OAuth 2.0 and API Key authentication
- URL normalization
- Instance and app validation
- DocType data fetching with pagination
- Comprehensive error handling

## Setting up On premises gateway for Power BI Service

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

## Making Code Changes

### Edit and Rebuild

1. Edit `.pq` files in VS Code
2. Save the file
3. Build: `mez build`
4. Copy generated `.mez` file to Power BI Custom Connectors folder
5. Restart Power BI to test changes

### Modify Project Settings

Edit `.pqproj` files to change:
- Connector name/description
- Version number
- Icon references
- Project properties

## Testing

### Local Testing in Power BI Desktop

1. Build: `mez build`
2. Copy `.mez` file to: `C:\Users\[Username]\Documents\Power BI Desktop\Custom Connectors\`
3. Restart Power BI
4. Test in **Get Data** dialog

### Test Cases

Test the connector with:
- Valid Frappe URL with pbi_integration installed
- Invalid URLs (should show error)
- URL without pbi_integration app (should show error)
- Various authentication methods (OAuth and API Key)
- Different DocTypes and Reports

## GitHub Releases and Automation

### Manual Release

To create a release with `.mez` files:

1. Build the connectors locally
2. Create a GitHub release with tag (e.g., `v1.0.0`)
3. Upload `FrappeReports.mez` and `FrappeDocuments.mez` as release assets
4. Users can download from [GitHub Releases](https://github.com/ParaLogicTech/frappe_pbi_connector/releases)

### Release Process

1. Commit changes to repository
2. Create a tag: `git tag v1.0.0`
3. Push tag: `git push origin v1.0.0`
4. GitHub Actions automatically builds and creates a release
5. Download the `.mez` files from [GitHub Releases](https://github.com/ParaLogicTech/frappe_pbi_connector/releases)

## Troubleshooting Build Issues

### Extension Not Loading in Power BI

1. Verify `.mez` file is in correct folder
2. Check filename matches exactly
3. Restart Power BI completely
4. Check Power BI Security settings
5. Look for errors in Power BI diagnostics

## Publishing and Distribution

### Update README

After releasing a new version:
1. Update version number in README.md
2. Link to new GitHub Release
3. Update "Last Updated" date
4. Commit and push changes

## Power Query Documentation

For detailed information on Power Query development:
- [Power Query SDK Documentation](https://github.com/microsoft/powerquery-sdk)
- [Power Query M Language Reference](https://learn.microsoft.com/en-us/powerquery-m/)
- [Connector Development Best Practices](https://github.com/microsoft/powerquery-sdk/wiki)

## Contributing

To contribute improvements:

1. Fork the repository
2. Create a branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test thoroughly in Power BI
5. Commit: `git commit -m "description of changes"`
6. Push: `git push origin feature/your-feature`
7. Create a pull request
8. Your contributions will be licensed under GNU General Public License (v3)

---

**Last Updated:** October 2026

For user installation and usage instructions, see [README.md](https://github.com/ParaLogicTech/frappe_pbi_connector/blob/master/README.md)

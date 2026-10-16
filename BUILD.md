# Building Frappe Power BI Connectors

This guide is for developers who want to build the connectors from source or modify the code.

## Prerequisites

- **Visual Studio Code** — [Download here](https://code.visualstudio.com/)
- **Power Query SDK** — [Install from VS Code Extensions](https://marketplace.visualstudio.com/items?itemName=PowerQuery.powerquerysdk)

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

1. In the menu bar click on **Terminal** → **Run Build Task**
2. Select **Build connector project using MakePQX**
3. Wait for completion

### Build Output

After successful build, you'll find `.mez` files in:
```
FrappeReports/bin/AnyCPU/Debug/FrappeReports.mez
FrappeDocuments/bin/AnyCPU/Debug/FrappeDocuments.mez
```
## Frappe Power BI Connectors

- **Frappe Reports** - Query and fetch report data from Frappe Reports
- **Frappe Documents** - Fetch DocType data with pagination and filter support

- Authentication: OAuth 2.0 and API Key support
- URL normalization: Handles various URL formats, forces HTTPS
- Validation: Frappe instance and pbi_integration app detection
- Error handling: User friendly messages for common failure scenarios
- Comprehensive error handling: Distinguishes between invalid URLs, missing app installation, and authentication failures

## Making Code Changes

### Edit and Rebuild

1. Edit `.pq` files in VS Code
2. Save the file
3. Build the `.mez` file
4. Copy generated `.mez` file to `C:\Users\[Username]\Documents\Power BI Desktop\Custom Connectors\`
5. Restart Power BI to test changes

### Modify Project Settings

Edit `.pqproj` files to change:
- Connector name/description
- Version number
- Icon references
- Project properties

## Testing

### Local Testing in Power BI Desktop

1. Build the `mez` file
2. Copy `.mez` file to: `C:\Users\[Username]\Documents\Power BI Desktop\Custom Connectors\`
3. Restart Power BI
4. Search for Frappe Reports or Frappe Documents in **Get Data** dialog

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
## Troubleshooting Build Issues

### Extension Not Loading in Power BI

1. Verify `.mez` file is in correct folder. `C:\Users\[Username]\Documents\Power BI Desktop\Custom Connectors\`
2. Restart Power BI completely
3. Check Power BI Security settings

## Publishing and Distribution

### Update README

After releasing a new version:
1. Update version number in README.md
2. Link to new GitHub Release
3. Commit and push changes

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

For user installation and usage instructions, see [README.md](https://github.com/ParaLogicTech/frappe_pbi_connector/blob/master/README.md)

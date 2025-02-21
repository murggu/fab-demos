# fab-demo-tutorial-rti

Scripts to deploy the [real-time intelligence (rti) tutorial](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/tutorial-introduction) into your Fabric workspace.

[TODO pic]

This includes:
- 1 workspace
- 1 eventhouse
- 1 KQL database
- 1 eventstream
- 1 KQL dashboard
- 2 KQL querysets
- 1 semantic model
- 1 Power BI report

## Instructions

Make sure you have the [Fabric CLI](#) installed. To run a demo:

**Deploy from local**

1. Clone the repository and jump to demo folder
2. Update `config.yml` with your desired values
3. Deploy demo
    ```console
    $ ./
    ```

**Deploy using GitHub actions**

1. Fork the repository
2. Create three secrets in your repository: `FAB_TENANT_ID`, `FAB_CLIENT_ID`, and `FAB_CLIENT_SECRET`
3. Go to the Actions tab and set up parameters
4. Run the `deploy-fab-demo-rti-tutorial` workflow
    
## Notes
See notes below for additional info:

- TODO
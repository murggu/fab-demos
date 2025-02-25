# fab-demo-tutorial-lakehouse

Scripts to deploy the [lakehouse tutorial](https://learn.microsoft.com/en-us/fabric/data-engineering/tutorial-lakehouse-introduction) into your Fabric workspace.

[TODO pic]

This includes:
- 1 workspace
- 1 lakehouse, non-schema
- 2 connections, Blob (public) and ADLS Gen2 (SAS auth)
- 1 external shortcut ADLS Gen2
- 1 pipeline
- 2 notebooks
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
4. Run the `deploy-fab-demo-lakehouse-tutorial` workflow
    
## Notes
See notes below for additional info:

- This demo sliglty changed the original lakehouse tutorial to deploy it faster. Pipeline copy activity was changed to just one table and a shortcut was added. 
- TODO spn auth deployment (pipeline).
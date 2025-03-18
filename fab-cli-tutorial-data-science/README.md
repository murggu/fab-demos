# fab-cli-tutorial-data-science

Scripts to deploy the [data science tutorial](https://learn.microsoft.com/en-us/fabric/data-science/tutorial-data-science-introduction) into your Fabric workspace.

This includes:
- 1 workspace
- 1 lakehouse, non-schema
- 4 notebooks
- 1 ML experiment (auto-created by notebooks)
- 3 ML models (auto-created by notebooks) 
- 1 semantic model
- 1 Power BI report

## Instructions

Make sure you have the [Fabric CLI](/dist/) installed. To run the demo:

**Deploy from local**

1. Clone the repository and jump to demo folder
2. Deploy demo
    ```console
    $ ./fab-cli-tutorial-data-science/scripts/setup.sh \ 
    --capacity-name Trial-20240216T095351Z-aiYznZSl4kS24GSzM6Yejw \
    --postfix 87
    ```

**Deploy using GitHub actions**

1. Fork the repository
2. Create three secrets in your repository: `FAB_TENANT_ID`, `FAB_CLIENT_ID`, and `FAB_CLIENT_SECRET`
3. Go to the Actions tab and set up parameters
4. Run the `deploy-fab-cli-tutorial-data-science` workflow
    
## Notes
See notes below for additional info:

- Use `--capacity-name Trial-20240216T095351Z-aiYznZSl4kS24GSzM6Yejw --postfix 87 --spn_auth_enabled true --upn_objectid=<user-objectid>` to deploy using SPN auth from local.
- `upn_objectid` is used to grant user permission during service principal deployment.
# fab-cli-tutorial-rti

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

Make sure you have the [Fabric CLI](/dist/) installed. To run the demo:

**Deploy from local**

1. Clone the repository and jump to demo folder
2. Deploy demo
    ```console
    $ ./fab-cli-tutorial-rti/scripts/setup.sh \ 
    --capacity-name Trial-20240216T095351Z-aiYznZSl4kS24GSzM6Yejw \
    --postfix 87
    ```

**Deploy using GitHub actions**

1. Fork the repository
2. Create three secrets in your repository: `FAB_TENANT_ID`, `FAB_CLIENT_ID`, and `FAB_CLIENT_SECRET`
3. Go to the Actions tab and set up parameters
4. Run the `deploy-fab-cli-tutorial-rti` workflow
    
## Notes
See notes below for additional info:

- Use `--capacity-name Trial-20240216T095351Z-aiYznZSl4kS24GSzM6Yejw --postfix 87 --spn_auth_enabled true --upn_objectid=<user-objectid>` to deploy using SPN auth from local.
- `upn_objectid` is used to grant user permission during service principal deployment.
- After deployment finished, edit credentials of the semantic model to see data in the Power BI report.
- This demo excluded the [Reflex item type](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/tutorial-7-set-alert) deployment.
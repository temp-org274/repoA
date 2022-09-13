# terraform-reusable-workflows

This repository contains reusable github action workflows for terraform. Workflows needs to be under `.github/workflows` directory.

## workflow structure

```yaml
on:
  workflow_call:
    inputs:
      <input-name>:
        type: string
        required: true
    secrets:
      <secret-name>:
        required: true

jobs:
  <job-name>:
    runs-on: ubuntu-latest
    steps:
```

Reusable workflow can define inputs and secrets to be used within the workdlow, for eg: `${{ inputs.<input-name> }}, ${{ secrets.<secret-name> }}`

Other repositories can reference the reusable workflow by providing `<org-name>/<repo-name>/.github/workflows/<workflow-file-name>@ref`

```yaml
name: Reusable Github Workflow

on:
  push:
    branches:
      - main
  pull_request: 

jobs:
  ReuseableJob:
    uses: <org-name>/<repo-name>/.github/workflows/test.yml@main
    secrets: inherit
    with:
      <input-name>: <input-value>
```

## policy-check.yml

This workflow checks organization level sentinel policies against your terraform code.

inputs
- varset : name of the variable set containing aws credentials

secrets
- TF_TOKEN : terraform cloud token having permission for the workspace
- ORGANIZATION : terraform cloud org name


```yaml
- name: checkout sentinel policies
        uses: actions/checkout@v3
        with:
          repository: infracloudio/sentinel-policy-as-code
          ssh-key: ${{ secrets.PRIVATE_SSH_KEY }}
```

To checkout other private repositories deploy keys have been used, a ssh key pair is used for authentication. Public key has been added to the private repo being checked out as deploy key and private key has been added as actions secret to the repo calling workflow.


```yaml
- name: run docker container containing script
        uses: addnab/docker-run-action@v3
        with:
          image: ruchabhange/sentinel:0.1.1
          options: -v ${{ env.currentDir }}/sentinel-policy-as-code/common-functions:/opt/sentinel/common-functions -v ${{ env.currentDir }}/sentinel-policy-as-code/policies:/opt/sentinel/policies  -v ${{ env.currentDir }}/config-code:/opt/sentinel/config-code -e TF_TOKEN=${{ secrets.TF_TOKEN }} -e organization=${{ secrets.ORGANIZATION }} -e workspace=${{ github.event.repository.name }} -e varset=${{ inputs.varset }}
          shell: bash
          run: /opt/sentinel/script.sh
```

Above step creates a docker container to run a shell script, which uploads the terraform code configuration to terraform cloud, creates a workspace if does't exists, adds the workspace to varset if isn't already present, creates a plan only run, downloads mock data and run sentinel cli to validate the policies.

The common functions, policies and terraform code are being mounted as volumes to the container. The container expects following environment variables:

- TF_TOKEN     : terraform cloud token having permission for the workspace
- organization : terraform cloud org name
- workspace    : terraform cloud workspace name
- varset       : name of the variable set containing aws credentials


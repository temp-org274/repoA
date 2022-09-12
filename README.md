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

Other repositories can reference the reusable workflow by providing `<org-name>/<repo-name>/.github/workflows/<workflow-name>`

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

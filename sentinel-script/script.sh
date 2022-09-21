#!/bin/bash
# script required 4 environment variables
#TF_TOKEN - terraform cloud team token
#organization - name of the organization on terraform cloud
#workspace - name of the workspace in that org
#varset - variable set name containing aws credentials

# change dir
cd /opt/sentinel

# set token
if [ ! -z "$TF_TOKEN" ]; then
  echo "Using terraform token provided: " $TF_TOKEN
else
  echo "token is a mandatory argument. please provide a terraform cloud team token and run again"
  exit 1
fi

# set org
if [ ! -z "$organization" ]; then
  echo "Using organization provided: " $organization
  else
    echo "organization is a mandatory argument. please provide organization name and run again"
    exit 1
fi

# Set workspace
if [ ! -z "$workspace" ]; then
  echo "Using workspace provided: " $workspace
  else
    echo "workspace is a mandatory argument. please provide a workspace name and run again"
    exit 1
fi

# Set varset
if [ ! -z "$varset" ]; then
  echo "Using varset provided: " $varset
else
  echo "varset name containing aws credentials not provided"
  echo "provide varset name if workspace not already added to the varset on terraform cloud"
fi

sleep_duration=5

echo "Tarring configuration directory."
tar -czf config.tar.gz -C config-code --exclude .git --exclude .gitignore  --exclude .github .

cat > configversion.json <<EOF
{
  "data": {
    "type": "configuration-versions",
    "attributes": {
      "auto-queue-runs": false
    }
  }
}
EOF


cat > workspace.template.json <<EOF
{
  "data":
  {
    "attributes": {
      "name":"workspace_name",
      "terraform-version": "1.2.8"
    },
    "type":"workspaces"
  }
}
EOF


cat > run.template.json <<EOF
{
  "data": {
    "attributes": {
      "is-destroy":false,
      "plan-only":true
    },
    "type":"runs",
    "relationships": {
      "workspace": {
        "data": {
          "type": "workspaces",
          "id": "workspace_id"
        }
      }
    }
  }
}
EOF


cat > exports.template.json <<EOF
{
  "data": {
    "type": "plan-exports",
    "attributes": {
      "data-type": "sentinel-mock-bundle-v0"
    },
    "relationships": {
      "plan": {
        "data": {
          "id": "plan-id",
          "type": "plans"
        }
      }
    }
  }
}
EOF

cat > varset.template.json <<EOF
{
  "data": [
    {
      "type": "workspaces",
      "id": "workspace_id"
    }
  ]
}
EOF


#Set name of workspace in workspace.json
sed "s/workspace_name/${workspace}/" < workspace.template.json > workspace.json

# Check to see if the workspace already exists
echo ""
echo "Checking to see if workspace exists"
check_workspace_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" "https://app.terraform.io/api/v2/organizations/${organization}/workspaces/${workspace}")

# Parse workspace_id from check_workspace_result
workspace_id=$(echo $check_workspace_result | jq -r '.data.id')
echo ""
echo "Workspace ID: " $workspace_id

# Create workspace if it does not already exist
if [ "$workspace_id" = "null" ]; then
  echo ""
  echo "Workspace did not already exist; will create it."
  workspace_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --request POST --data @workspace.json "https://app.terraform.io/api/v2/organizations/${organization}/workspaces")

  # Parse workspace_id from workspace_result
  workspace_id=$(echo $workspace_result | jq -r '.data.id')
  echo ""
  echo "Workspace ID: " $workspace_id
else
  echo ""
  echo "Workspace already existed."
fi

# Set id of workspace in varset.json
sed "s/workspace_id/${workspace_id}/" < varset.template.json > varset.json

# add workspace to varset
# jq --arg v $varset -r '.data[] | select(.attributes.name == $v) | .id'
# jq --arg v "aws-creds" -r '.data[] | select(.attributes.name == $v) | select(.relationships.workspaces.data[].id == "ws-BPTFa5F1MURSpTJ") | .id'
varset_result=$(curl --header "Authorization: Bearer $TF_TOKEN" https://app.terraform.io/api/v2/organizations/${organization}/varsets)
varset_id=$(echo $varset_result | jq --arg v $varset -r '.data[] | select(.attributes.name == $v) | .id')
if [[ "$varset_id" != "" ]]; then
  curl --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --request POST --data @varset.json https://app.terraform.io/api/v2/varsets/${varset_id}/relationships/workspaces
else
  echo "either varset was not provided or provided varset doesn't exists"
fi

# Create configuration version
echo ""
echo "Creating configuration version."
configuration_version_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --data @configversion.json "https://app.terraform.io/api/v2/workspaces/${workspace_id}/configuration-versions")

# Parse configuration_version_id and upload_url
config_version_id=$(echo $configuration_version_result | jq -r '.data.id')
upload_url=$(echo $configuration_version_result | jq -r '.data.attributes."upload-url"')
echo ""
echo "Config Version ID: " $config_version_id
echo "Upload URL: " $upload_url

# Upload configuration
echo ""
echo "Uploading configuration version using config.tar.gz"
curl -s --header "Content-Type: application/octet-stream" --request PUT --data-binary @config.tar.gz "$upload_url"


# Do a run
sed "s/workspace_id/$workspace_id/" < run.template.json  > run.json
run_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --data @run.json https://app.terraform.io/api/v2/runs)

# Parse run_result
run_id=$(echo $run_result | jq -r '.data.id')
echo ""
echo "Run ID: " $run_id

# Check run result in loop
continue=1
i=0
while [ $continue -ne 0 ]; do
  # Sleep
  sleep $sleep_duration
  echo ""
  echo "Checking run status"

  # Check the status of run
  check_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" https://app.terraform.io/api/v2/runs/${run_id})

  # Parse out the run status and is-confirmable
  run_status=$(echo $check_result | jq -r '.data.attributes.status')
  echo "Run Status: " $run_status
  is_confirmable=$(echo $check_result | jq -r '.data.attributes.actions."is-confirmable"')
  echo "Run can be applied: " $is_confirmable

  # Save plan log if errored
  save_plan="false"

  # pllaned and finished means plan only has completed
  if [[ "$run_status" == "planned_and_finished" ]]; then
    continue=0
    echo ""
    echo "The run is completed. This status only exists for plan-only runs and runs that produce a plan with no changes to apply. This is a final state."
    plan_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" https://app.terraform.io/api/v2/runs/${run_id}?include=plan)
    plan_id=$(echo $plan_result | jq -r '.included[0].id')
    echo "plan id: $plan_id"
    #Set plan id in exports.json
    sed "s/plan-id/${plan_id}/" < exports.template.json > exports.json
    plan_exports_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --request POST --data @exports.json https://app.terraform.io/api/v2/plan-exports)
    #plan_exports_id=$(echo $plan_exports_result | jq -r '.data.id')
    plan_exports_id=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" https://app.terraform.io/api/v2/runs/${run_id}?include=plan | jq -r .included[0].relationships.exports.data[0].id)
    echo "plan exports id: $plan_exports_id"
    echo "Downloading mock data for sentinel policy check"
    curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --location https://app.terraform.io/api/v2/plan-exports/${plan_exports_id}/download > exports.tar.gz
    tar_size=$(ls -lh exports.tar.gz | awk '{ print $5  }')
    echo "tar_size: $tar_size)"

    if [[ "$tar_size" == 0 ]] && [[ "$i" -lt 2  ]]; then
      continue=1
      echo ""
      echo "unable to get exports data. looping again"
    else
      ((i=i+1))
    fi
  # errored means that plan had an error
  elif [[ "$run_status" == "errored" ]]; then
    echo ""
    echo "The run has errored. This is a final state."
    save_plan="true"
    continue=0
  # canceled means run has been canceled from ui" 
  elif [[ "$run_status" == "canceled" ]]; then
    echo ""
    echo "run canceled from ui"
    exit 1
  elif [[ -z "$run_status" ]] || [[ "$run_status" == "null" ]]; then
    echo ""
    echo "error in run"
    echo "output of run: $run_result"
    exit 1
  else
    # pause and then check status again in next loop
    echo "Pause and loop again"
  fi
done

# Get the plan log if $save_plan is true
if [[ "$save_plan" == "true" ]]; then
  echo ""
  echo "Getting the result of the Terraform Plan."
  plan_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" https://app.terraform.io/api/v2/runs/${run_id}?include=plan)
  plan_log_url=$(echo $plan_result | jq -r '.included[0].attributes."log-read-url"')
  echo ""
  echo "Plan Log:"
  # Retrieve Plan Log from the URL
  # and output to shell and file
  curl -s $plan_log_url | tee ${run_id}.log
  exit 1
fi

# untar mock data
tar xvzf exports.tar.gz -C policies/test/enforce-mandatory-tags/ --exclude='sentinel.hcl'
tar xvzf exports.tar.gz -C policies/test/restrict-terraform-versions/ --exclude='sentinel.hcl'
tar xvzf exports.tar.gz -C policies/test/validate-variables-have-descriptions/ --exclude='sentinel.hcl'

# run sentinel tests
sentinel test policies/enforce-mandatory-tags.sentinel
enforce_mandatory_tags_policy=$(if [ $? = 0 ]; then echo passed; else echo failed; fi)
sentinel test policies/restrict-terraform-versions.sentinel
restrict_terraform_versions_policy=$(if [ $? = 0 ]; then echo passed; else echo failed; fi)
sentinel test policies/validate-variables-have-descriptions.sentinel
validate_variables_have_descriptions_policy=$(if [ $? = 0 ]; then echo passed; else echo failed; fi)

echo "enforce_mandatory_tags_policy - $enforce_mandatory_tags_policy" >> policies/message.txt
echo "restrict_terraform_versions_policy - $restrict_terraform_versions_policy" >> policies/message.txt
echo "validate_variables_have_descriptions_policy - $validate_variables_have_descriptions_policy" >> policies/message.txt

#if grep -q fail message.txt; then exit 1; fi

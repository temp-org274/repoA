
201     plan_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" https://app.terraform.io/api/v2/runs/${run_id}?include=plan)
202     plan_id=$(echo $plan_result | jq -r '.included[0].id')
203     echo "plan id: $plan_id"
204     #Set plan id in exports.json
205     sed "s/plan-id/${plan_id}/" < exports.template.json > exports.json
206     plan_exports_result=$(curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --request POST --data @exports.json https://app.terraform.io/api/v2/plan    -exports)
207     plan_exports_id=$(echo $plan_exports_result | jq -r '.data.id')
208     echo "plan exports id: $plan_exports_id"
209     echo "Downloading mock data for sentinel policy check"
210     curl -s --header "Authorization: Bearer $TF_TOKEN" --header "Content-Type: application/vnd.api+json" --location https://app.terraform.io/api/v2/plan-exports/${plan_exports_id}/download > exports.    tar.gz
211     tar_size=$(ls -lh exports.tar.gz)
212     echo "tar_size: $tar_size)"

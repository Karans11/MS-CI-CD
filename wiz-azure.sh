#!/usr/bin/env bash

######################
# command-line usage #
######################

DOC="Wiz Azure connection script.

Usage:
  wiz-azure.sh [options] standard management-group-deployment <management-group-id>
  wiz-azure.sh [options] standard subscription-deployment <subscription-id>
  wiz-azure.sh [options] standard deploy-to-all-subscriptions <tenant-id>
  wiz-azure.sh [options] outpost management-group-deployment <management-group-id>
  wiz-azure.sh [options] outpost subscription-deployment <subscription-id>
  wiz-azure.sh [options] outpost deploy-to-all-subscriptions <tenant-id>
  wiz-azure.sh [options] aad

Options:
  --continue-on-error                       continue the deployment flow even if az cli returns an error
  --check-roles-first                       check current user has the sufficient roles for deployment
  --quiet                                   disable all interactive prompts when running
  --verbose                                 print command outputs anyway
  --with-custom-app                         always use custom aad apps instead of the wiz enterprise app
  --custom-app-name=<name>                  custom app name [default: Wiz Security]
  --reset-credentials-for-custom-app        reset credentials for the custom app if it already exists
  --setup-aad-permissions                   set up permissions for the custom app
  --custom-role-name=<name>                 custom role name [default: WizCustomRole]
  --disk-analyzer-role-name=<name>          disk analyzer role name [default: WizDiskAnalyzerRole]
  --with-data-scanning                      enable data scanning [default: false]
  --with-openai-scanning                    enable openai scanning [default: false]
  --data-scanning-role-name=<name>          data scanning role name [default: WizDataScanningRole]
  --with-serverless-scanning                enable serverless scanning [default: false]
  --serverless-scanning-role-name=<name>    serverless scanning role name [default: WizServerlessScanningRole]
  --scanner-app-name=<name>                 scanner app name, for same-tenant outpost deployments only [default: Wiz Disk Analyzer - Scanner]
  --scanner-app-id=<id>                     scanner app id, for cross-tenant outpost deployments only
  --with-keyvault                           deploy keyvault access policies
  --only-keyvault                           deploy only keyvault access policies
  --require-keyvault-permissions            fail on missing permissions to keyvault policies
  --wait-for-retry-count=<n>                retry count for waiting on background operations [default: 10]
  --wiz-gov                                 connect to wiz gov
  --wiz-managed-id=<managed-id>             application id of your Wiz's tenant managed AAD application [default: 6de4dd30-fe2c-4a5d-838f-54eea116a9fe]
  --with-aad-consent                        grant Application & Delegated permissions through admin-consent
  --with-aad-consent-only                   only grant Application & Delegated permissions through admin-consent
  --with-shadow-data                        grant shadow data inventory report permissions [default: false]
  --reconcile-role-assignment-conditions    reconcile role assignments if they already exist with missing or mismatched conditions [default: false]
"

###################
# deployment flow #
###################

aad_grant_admin_consent() {
  blue "\n# Adding Wiz app \"$__wiz_managed_id\""
  local service_principal_id

  if ! service_principal_for_app_exists "$__wiz_managed_id"; then
      create_service_principal_for_app "$__wiz_managed_id"
      service_principal_id="$output"
  else
      service_principal_id="$output"
  fi

  local PERMISSIONS="""
    00000003-0000-0000-c000-000000000000 7ab1d382-f21e-4acd-a863-ba3e13f7da61 MS Graph: Directory.Read.All
    00000003-0000-0000-c000-000000000000 246dd0d5-5bd0-4def-940b-0421030a5b68 MS Graph: Policy.Read.All
    00000003-0000-0000-c000-000000000000 c7fbd983-d9aa-4fa7-84b8-17382c103bc4 MS Graph: RoleManagement.Read.All
    00000003-0000-0000-c000-000000000000 d07a8cc0-3d51-4b77-b3b0-32704d1f69fa MS Graph: AccessReview.Read.All
    00000003-0000-0000-c000-000000000000 b0afded3-3588-46d8-8b3d-9842eff778da MS Graph: AuditLog.Read.All
  """

  local resource_id app_role_id name
  while read -r resource_id app_role_id name; do
    if [ -n "$app_role_id" ]; then
      blue "\n# Granting app \"$__wiz_managed_id\" admin-consent to role \"$name\":"
      grant_admin_consent_for_app "$service_principal_id" "$resource_id" "$app_role_id"
    fi
  done <<< "$PERMISSIONS"
}

management_group_deployment() {
    blue "Running Management-group level connection to Management Group \"$_management_group_id_\""
    lightblue "This script is going to:"
    local scope="$WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX/$_management_group_id_"
    if $__check_roles_first; then
        lightblue "* check if the current user has sufficient roles to complete the deployment"
    fi
    if $outpost; then
        lightblue "* create a service principal for the scanner app \"${__scanner_app_id:-$__scanner_app_name}\" if it does not exist"
    fi
    if $__with_custom_app; then
        lightblue "* create the custom app \"$__custom_app_name\" if it does not exist"
    else
        lightblue "* create a service principal for the Wiz Enterprise app"
    fi
    lightblue "* create the custom role \"$__custom_role_name\" if it does not exist"
    if $__with_data_scanning; then
      lightblue "* create the custom role \"$__data_scanning_role_name\" if it does not exist"
    fi
    if $__with_serverless_scanning; then
      lightblue "* create the custom role \"$__serverless_scanning_role_name\" if it does not exist"
    fi
    if $outpost; then
        lightblue "* create the custom role \"$__disk_analyzer_role_name\" if it does not exist"
    fi
    lightblue "* assign the roles described at $DOCS_URL to the app"
    if $__with_keyvault; then
        lightblue "* add iam access policies to keyvaults"
    fi

    ask_for_confirmation_to_proceed

    blue "\n# Checking login to azure"
    _az account show
    local current_subscription_id
    current_subscription_id=$(echo "$output" | jq -r .id)

    # no need to switch context, az this checks that the management group exists in the current tenant
    blue "\n# Checking if management group \"$_management_group_id_\" exists"
    assert_management_group_exists "$_management_group_id_"

    if $__check_roles_first; then
        check_permissions_for_management_group_deployment
    fi

    if $outpost; then
        create_scanner_service_principal "$__scanner_app_name" "$__scanner_app_id"
    fi

    create_or_update_fetcher_app

    validation_result="PASS"
    if ! $__only_keyvault; then
        local scope="$WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX/$_management_group_id_"
        local actions=("${WIZ_CUSTOM_ROLE_ACTIONS[@]}")
        local roles=("$__custom_role_name")
        roles+=("${STANDARD_ROLES[@]}")

        if $__with_shadow_data; then
            # Add conditional roles from associative array
            for role_name in "${!SHADOW_DATA_ROLES[@]}"; do
                roles+=("${role_name}{${SHADOW_DATA_ROLES[$role_name]}}")
            done
            actions+=("${SHADOW_DATA_ACTIONS[@]}")
        fi

        if $standard; then
            actions+=("${WIZ_CUSTOM_ROLE_DISK_ACTIONS[@]}")

            if $__with_data_scanning; then
                json_array_actions=$(array_to_json_array "${DATA_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
                create_or_update_custom_role "$__data_scanning_role_name" "$DATA_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--data-scanning-role-name"
                roles+=("$__data_scanning_role_name" "${DATA_SCANNING_STANDARD_ROLES[@]}")
            fi

            if $__with_openai_scanning; then
              roles+=("${OPENAI_STANDARD_ROLES[@]}")
            fi

            if $__with_serverless_scanning; then
                json_array_actions=$(array_to_json_array "${SERVERLESS_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
                create_or_update_custom_role "$__serverless_scanning_role_name" "$SERVERLESS_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--serverless-scanning-role-name"
                roles+=("$__serverless_scanning_role_name")
            fi
        fi
        json_array_actions=$(array_to_json_array "${actions[@]}")
        create_or_update_custom_role "$__custom_role_name" "$WIZ_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--custom-role-name"

        for role in "${roles[@]}";
        do
            blue "\n# Assigning the role \"$role\" for the app (service principal \"$service_principal_id\")"
            assign_role_to_service_principal_in_scope "$role" "$service_principal_id" "$scope"
        done

        if $outpost; then
            json_array_actions=$(array_to_json_array "${DISK_ANALYZER_CUSTOM_ROLE_ACTIONS[@]}")
            create_or_update_custom_role "$__disk_analyzer_role_name" "$DISK_ANALYZER_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" [] "--disk-analyzer-role-name"
            blue "\n# Assigning the role \"$__disk_analyzer_role_name\" for the disk analyzer (service principal \"$scanner_app_service_principal_id\")"
            assign_role_to_service_principal_in_scope "$__disk_analyzer_role_name" "$scanner_app_service_principal_id" "$scope"

            if $__with_data_scanning; then
                json_array_actions=$(array_to_json_array "${DATA_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
                create_or_update_custom_role "$__data_scanning_role_name" "$DATA_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--data-scanning-role-name"
                local data_scanning_roles=("$__data_scanning_role_name" "${DATA_SCANNING_STANDARD_ROLES[@]}")
                if $__with_openai_scanning; then
                  data_scanning_roles+=("${OPENAI_STANDARD_ROLES[@]}")
                fi
                for role in "${data_scanning_roles[@]}";
                do
                    blue "\n# Assigning the role \"$role\" for the disk analyzer (service principal \"$scanner_app_service_principal_id\")"
                    assign_role_to_service_principal_in_scope "$role" "$scanner_app_service_principal_id" "$scope"
                done
            fi

            if $__with_serverless_scanning; then
                json_array_actions=$(array_to_json_array "${SERVERLESS_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
                create_or_update_custom_role "$__serverless_scanning_role_name" "$SERVERLESS_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--serverless-scanning-role-name"
                blue "\n# Assigning the role \"$__serverless_scanning_role_name\" for the disk analyzer (service principal \"$scanner_app_service_principal_id\")"
                assign_role_to_service_principal_in_scope "$__serverless_scanning_role_name" "$scanner_app_service_principal_id" "$scope"
            fi
        fi

        validate_management_group_deployment "$app_id" "$service_principal_id" "${roles[@]}"
    fi

    if [[ "$validation_result" == "PASS" ]] && $__with_keyvault; then
        blue "\n# Assigning the role \"$KEY_VAULT_READER_ROLE\" for the app (service principal \"$service_principal_id\")"
        assign_role_to_service_principal_in_scope "$KEY_VAULT_READER_ROLE" "$service_principal_id" "$scope"

        blue "\n# Creating access policies for all keyvaults in subscriptions under management group \"$_management_group_id_\""
        keyvault_deployment_in_management_group "$service_principal_id" "$_management_group_id_"
    fi

    if ! $__only_keyvault; then
        green "\n# Deployment details"
        if [[ $custom_app_created == true ]]; then
            green "# Client ID: ${app_id}"
            green "# Client Secret: ${custom_app_secret}"
        fi
        if $outpost; then
            green "# Outpost Secret Name: ${scanner_app_id}"
        fi

        print_script_completion_message
    fi
}

subscription_deployment() {
    blue "Running Subscription level connection to Subscription \"$_subscription_id_\"\n"
    lightblue "This script is going to:"
    if $__check_roles_first; then
        lightblue "* check if the current user has sufficient roles to complete the deployment"
    fi
    if $outpost; then
        lightblue "* create a service principal for the scanner app \"${__scanner_app_id:-$__scanner_app_name}\" if it does not exist"
    fi
    if $__with_custom_app; then
        lightblue "* create the custom app \"$__custom_app_name\" if it does not exist"
    fi
    lightblue "* create the custom role \"$__custom_role_name\" if it does not exist"
    if $__with_data_scanning; then
      lightblue "* create the custom role \"$__data_scanning_role_name\" if it does not exist"
    fi
    if $__with_serverless_scanning; then
      lightblue "* create the custom role \"$__serverless_scanning_role_name\" if it does not exist"
    fi
    if $outpost; then
        lightblue "* create the custom role \"$__disk_analyzer_role_name\" if it does not exist"
    fi
    lightblue "* assign roles described at $DOCS_URL to the app"
    if $__with_keyvault; then
        lightblue "* add iam access policies to keyvaults"
    fi

    ask_for_confirmation_to_proceed

    # all az ad commands use the tenant of the current context, we so need to set that first
    blue "\n# Setting azure cli context to subscription \"$_subscription_id_\""
    _az account set --subscription "$_subscription_id_"

    blue "\n# Checking if subscription \"$_subscription_id_\" exists and is enabled"
    assert_subscription_exists_and_enabled "$_subscription_id_"

    if $__check_roles_first; then
        check_permissions_for_subscription_deployment
    fi

    if $outpost; then
        create_scanner_service_principal "$__scanner_app_name" "$__scanner_app_id"
    fi

    create_or_update_fetcher_app

    validation_result="PASS"
    if ! $__only_keyvault; then
        deploy_and_validate_service_principal_in_subscription "$service_principal_id" "$_subscription_id_"
    fi

    if [[ "$validation_result" == "PASS" ]] && $__with_keyvault; then
        blue "\n# Assigning the role \"$KEY_VAULT_READER_ROLE\" for the app (service principal \"$service_principal_id\")"
        assign_role_to_service_principal_in_scope "$KEY_VAULT_READER_ROLE" "$service_principal_id" "/subscriptions/$_subscription_id_"
        blue "\n# Adding access policies to all keyvaults in subscription \"$_subscription_id_\""
        add_access_policies_to_all_keyvaults_in_subscription "$_subscription_id_" "$service_principal_id"
        blue "\n# Adding local rbac permissions to all managed hsm keys in subscription \"$_subscription_id_\""
        add_local_rbac_permissions_to_all_managedhsm_keys_in_subscription "$_subscription_id_" "$service_principal_id"
    fi

    if ! $__only_keyvault; then
        green "\n# Deployment details"
        if [[ $custom_app_created == true ]]; then
            green "# Client ID: ${app_id}"
            green "# Client Secret: ${custom_app_secret}"
        fi
        if $outpost; then
            green "# Outpost Secret Name: ${scanner_app_id}"
        fi

        print_script_completion_message
    fi
}

deploy_to_all_subscriptions() {
    blue "Running Tenant level connection\n"
    lightblue "This script is going to:"
    if $__check_roles_first; then
        lightblue "* check if the current user has sufficient roles to complete the deployment"
    fi
    if $outpost; then
        lightblue "* create a service principal for the scanner app \"${__scanner_app_id:-$__scanner_app_name}\" if it does not exist"
    fi
    if $__with_custom_app; then
        lightblue "* create the custom app \"$__custom_app_name\" if it does not exist"
    fi
    lightblue "* in each subscription:"
    lightblue "** create the custom role \"$__custom_role_name\" if it does not exist"
    if $__with_data_scanning; then
      lightblue "** create the custom role \"$__data_scanning_role_name\" if it does not exist"
    fi
    if $__with_serverless_scanning; then
      lightblue "** create the custom role \"$__serverless_scanning_role_name\" if it does not exist"
    fi
    if $outpost; then
        lightblue "** create the custom role \"$__disk_analyzer_role_name\" if it does not exist"
    fi
    lightblue "** assign roles described at $DOCS_URL to the app"
    if $__with_keyvault; then
        lightblue "* add iam access policies to keyvaults"
    fi

    ask_for_confirmation_to_proceed

    blue "\n# Checking login to azure"
    _az account show
    local current_subscription_id
    current_subscription_id=$(echo "$output" | jq -r .id)

    if $__check_roles_first; then
        check_permissions_for_tenant_deployment
    fi

    if $outpost; then
        create_scanner_service_principal "$__scanner_app_name" "$__scanner_app_id"
    fi

    create_or_update_fetcher_app

    local all_subscriptions=""
    local enabled_subscriptions=""

    _az account list --all --query "[?tenantId=='$_tenant_id_']"
    local all_subscriptions="$output"
    # it is simpler to iterate the object array if there are no spaces in between
    # borrowed this trick from https://www.starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
    local enabled_subscriptions=($(echo "$all_subscriptions" | jq -r '.[] | select(.state=="Enabled") | {id:.id,name:.name} | @base64'))

    validation_result="PASS"
    if ! $__only_keyvault; then
        for subscription_base64 in "${enabled_subscriptions[@]}"; do
            local subscription
            subscription=$(echo "$subscription_base64" | base64 --decode | jq -c .)
            local subscription_id
            subscription_id=$(echo "$subscription" | jq -r .id)
            local subscription_name
            subscription_name=$(echo "$subscription" | jq -r .name)

            blue "\n# Setting azure context to subscription \"$subscription_id\""
            _az account set --subscription "$subscription_id"

            blue "\n# Deploying in subscription name \"$subscription_name\" id \"$subscription_id\""
            deploy_and_validate_service_principal_in_subscription "$service_principal_id" "$subscription_id"

            if [[ "$validation_result" == "FAIL" ]]; then
                break
            fi
        done
    fi

    if [[ "$validation_result" == "PASS" ]] && $__with_keyvault; then
        blue "\n# Adding access policies to all keyvaults in all enabled subscriptions in tenant \"$_tenant_id_\""
        for subscription_base64 in "${enabled_subscriptions[@]}"; do
            local subscription
            subscription=$(echo "$subscription_base64" | base64 --decode | jq -c .)
            local subscription_id
            subscription_id=$(echo "$subscription" | jq -r .id)
            local subscription_name
            subscription_name=$(echo "$subscription" | jq -r .name)

            blue "\n# Assigning the role \"$KEY_VAULT_READER_ROLE\" for the app (service principal \"$service_principal_id\")"
            assign_role_to_service_principal_in_scope "$KEY_VAULT_READER_ROLE" "$service_principal_id" "/subscriptions/$subscription_id"
            blue "\n# Adding access policies to all keyvaults in subscription name \"$subscription_name\" id \"$subscription_id\""
            add_access_policies_to_all_keyvaults_in_subscription "$subscription_id" "$service_principal_id"
            blue "\n# Adding local rbac permissions to all managed hsm keys in subscription name \"$subscription_name\" id \"$subscription_id\""
            add_local_rbac_permissions_to_all_managedhsm_keys_in_subscription "$subscription_id" "$service_principal_id"
        done
    fi

    if ! $__only_keyvault; then
        green "\n# Deployment details"
        if [[ $custom_app_created == true ]]; then
            green "# Client ID: ${app_id}"
            green "# Client Secret: ${custom_app_secret}"
        fi

        print_script_completion_message
    fi
}

##############
# validators #
##############

validate_management_group_deployment() {
    local app_id="$1"
    local service_principal_id="$2"
    shift
    shift
    local roles=("$@")

    blue "\n# Validating deployment"
    if $standard; then
        local custom_roles=("$__custom_role_name")
        if $__with_data_scanning; then
           custom_roles+=("$__data_scanning_role_name")
        fi
        if $__with_serverless_scanning; then
           custom_roles+=("$__serverless_scanning_role_name")
        fi
        for role in "${custom_roles[@]}";
        do
            if role_exists_in_management_group "$role" "$_management_group_id_"; then
                green "PASS"
            else
                red "FAIL"
                validation_result="FAIL"
            fi
        done
    fi

    for role in "${roles[@]}";
    do
        # Extract role name and condition from annotated role string
        local role_name
        local role_condition
        _extract_role_and_condition "$role"
        role_name="$role_name_out"
        role_condition="$role_condition_out"

        if role_assignment_to_app_in_management_group_exists "$role_name" "$app_id" "$_management_group_id_" "$role_condition"; then
            green "PASS"
        else
            red "FAIL"
            validation_result="FAIL"
        fi
    done

    if $outpost; then
        local custom_roles=("$__disk_analyzer_role_name")
        if $__with_data_scanning; then
           custom_roles+=("$__data_scanning_role_name")
        fi
        if $__with_serverless_scanning; then
           custom_roles+=("$__serverless_scanning_role_name")
        fi
        for role in "${custom_roles[@]}";
        do
            if role_exists_in_management_group "$role" "$_management_group_id_"; then
                green "PASS"
            else
                red "FAIL"
                validation_result="FAIL"
            fi
            if role_assignment_to_app_in_management_group_exists "$role" "$scanner_app_service_principal_id" "$_management_group_id_"; then
                green "PASS"
            else
                red "FAIL"
                validation_result="FAIL"
            fi
        done
    fi
}

validate_subscription_deployment() {
    local app_id="$1"
    local service_principal_id="$2"
    local subscription="$3"
    shift
    shift
    shift
    local roles=("$@")

    blue "\n# Validating deployment"
    if $standard; then
        local custom_roles=("$__custom_role_name")
        if $__with_data_scanning; then
           custom_roles+=("$__data_scanning_role_name")
        fi
        if $__with_serverless_scanning; then
           custom_roles+=("$__serverless_scanning_role_name")
        fi
        for role in "${custom_roles[@]}";
        do
            if role_exists_in_subscription "$role" "$subscription"; then
                green "PASS"
            else
                red "FAIL"
                validation_result="FAIL"
            fi
        done
    fi

    for role in "${roles[@]}";
    do
        # Extract role name and condition from annotated role string
        local role_name
        local role_condition
        _extract_role_and_condition "$role"
        role_name="$role_name_out"
        role_condition="$role_condition_out"

        if role_assignment_to_app_in_subscription_exists "$role_name" "$app_id" "$subscription" "$role_condition"; then
            green "PASS"
        else
            red "FAIL"
            validation_result="FAIL"
        fi
    done

    if $outpost; then
        local custom_roles=("$__disk_analyzer_role_name")
        if $__with_data_scanning; then
           custom_roles+=("$__data_scanning_role_name")
        fi
        if $__with_serverless_scanning; then
           custom_roles+=("$__serverless_scanning_role_name")
        fi
        for role in "${custom_roles[@]}";
        do
            if role_exists_in_subscription "$role" "$subscription"; then
                green "PASS"
            else
                red "FAIL"
                validation_result="FAIL"
            fi
            if role_assignment_to_app_in_subscription_exists "$role" "$scanner_app_service_principal_id" "$subscription"; then
                green "PASS"
            else
                red "FAIL"
                validation_result="FAIL"
            fi
        done
    fi
}

####################
# helper functions #
####################

create_or_update_fetcher_app() {
    app_id=""
    custom_app_secret=""
    custom_app_created=false
    service_principal_id=""
    if $__with_custom_app; then
        blue "\n# Checking if custom app \"$__custom_app_name\" already exists"
        if custom_app_exists "$__custom_app_name"; then
            app_id="$output"
            if $__reset_credentials_for_custom_app; then
                reset_custom_app_credentials "$app_id" false
                custom_app_secret=$(echo "$output" | jq -r .password)
                custom_app_created="true"
                green "# Client ID: ${app_id}"
                green "# Client Secret: ${custom_app_secret}"
            fi
        else
            if $__only_keyvault; then
                red "Custom app does not exist"
                exit 1
            fi
            blue "\n# Creating custom app"
            create_custom_app "$__custom_app_name"
            app_id="$output"
            reset_custom_app_credentials "$app_id" false
            custom_app_secret=$(echo "$output" | jq -r .password)
            custom_app_created=true
            green "# Client ID: ${app_id}"
            green "# Client Secret: ${custom_app_secret}"
        fi

        if ! service_principal_for_app_exists "$app_id"; then
            if $__only_keyvault; then
                red "Service principal does not exist"
                exit 1
            fi
            create_service_principal_for_app "$app_id"
            service_principal_id="$output"
        else
            service_principal_id="$output"
        fi

        if [ "$__only_keyvault" != "true" ] && [ "$__setup_aad_permissions" == "true" ]; then
            blue "\n# Adding Azure AD permissions to custom app id \"$app_id\""
            blue "\n# Adding app \"$app_id\" permission \"Read directory data\" in \"AAD Graph API\""
            add_permission_for_app "$app_id" "$WIZ_GRAPH_API_ID" "$WIZ_PERMISSION_READ_DIRECTORY_DATA=Role"
            blue "\n# Adding app \"$app_id\" permissions \"Read directory data\", \"User.Read\" and \"Directory.Read.All\" in \"Microsoft Graph\""
            add_permission_for_app "$app_id" "$WIZ_MICROSOFT_GRAPH_ID" "$WIZ_PERMISSION_USER_READ=Scope" "$WIZ_PERMISSION_AUDIT_LOG_READ_ALL=Role" "$WIZ_PERMISSION_DIRECTORY_READ_ALL=Role"

            blue "\n# Granting API access to custom app id \"$app_id\""
            blue "\n# Adding app \"$app_id\" API access to \"AAD Graph API\""
            grant_permission_for_app "$app_id" "$WIZ_GRAPH_API_ID"
            blue "\n# Adding app \"$app_id\" API access to \"Microsoft Graph\""
            grant_permission_for_app "$app_id" "$WIZ_MICROSOFT_GRAPH_ID"
        fi
    else
        blue "\n# Adding Wiz app"
        app_id="$__wiz_managed_id"
        if $__wiz_gov; then
            app_id="$WIZ_GOV_ENTERPRISE_APP_ID"
        fi
        if ! service_principal_for_app_exists "$app_id"; then
            if $__only_keyvault; then
                red "Service principal does not exist"
                exit 1
            fi
            create_service_principal_for_app "$app_id"
        fi
        service_principal_id="$output"

        if $__with_aad_consent; then
            aad_grant_admin_consent
        fi
    fi

}

create_scanner_service_principal() {
    local app_name="$1"
    local app_id="$2"

    if [ -z "$app_id" ]; then
      blue "\n# Checking if scanner app \"$app_name\" exists"

      if ! custom_app_exists "$app_name"; then
          _az account show --query tenantId
          local tenant_id
          tenant_id=$(echo "$output" | jq -r .)

          red "Error, scanner app \"$app_name\" not found in AD tenant \"$tenant_id\", exiting."
          red "If outpost is deployed in another tenant, you can try running the command again while passing the --scanner-app-id parameter".
          exit 1
      fi

      app_id="$output"
    fi

    get_or_create_service_principal "$app_id"

    scanner_app_service_principal_id="$output"
    scanner_app_id="$app_id"
}

deploy_and_validate_service_principal_in_subscription() {
    local service_principal_id="$1"
    local subscription="$2"
    local scope="$WIZ_SUBSCRIPTION_SCOPE_PREFIX/$subscription"

    local actions=("${WIZ_CUSTOM_ROLE_ACTIONS[@]}")
    local roles=("$__custom_role_name")
    roles+=("${STANDARD_ROLES[@]}")

    if $__with_shadow_data; then
        # Add conditional roles from associative array
        for role_name in "${!SHADOW_DATA_ROLES[@]}"; do
            roles+=("${role_name}{${SHADOW_DATA_ROLES[$role_name]}}")
        done
        actions+=("${SHADOW_DATA_ACTIONS[@]}")
    fi

    if $standard; then
        actions+=("${WIZ_CUSTOM_ROLE_DISK_ACTIONS[@]}")

        if $__with_data_scanning; then
            json_array_actions=$(array_to_json_array "${DATA_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
            create_or_update_custom_role "$__data_scanning_role_name" "$DATA_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--data-scanning-role-name"
            roles+=("$__data_scanning_role_name" "${DATA_SCANNING_STANDARD_ROLES[@]}")
        fi

        if $__with_openai_scanning; then
            roles+=("${OPENAI_STANDARD_ROLES[@]}")
        fi

        if $__with_serverless_scanning; then
            json_array_actions=$(array_to_json_array "${SERVERLESS_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
            create_or_update_custom_role "$__serverless_scanning_role_name" "$SERVERLESS_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--serverless-scanning-role-name"
            roles+=("$__serverless_scanning_role_name")
        fi
    fi
    json_array_actions=$(array_to_json_array "${actions[@]}")
    create_or_update_custom_role "$__custom_role_name" "$WIZ_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--custom-role-name"

    for role in "${roles[@]}";
    do
        # Check if this role has a condition defined
        blue "\n# Assigning the role \"$role\" in subscription \"$subscription\" for the app (service principal \"$service_principal_id\")"
        assign_role_to_service_principal_in_scope "$role" "$service_principal_id" "$scope"
    done

    if $outpost; then
        json_array_actions=$(array_to_json_array "${DISK_ANALYZER_CUSTOM_ROLE_ACTIONS[@]}")
        create_or_update_custom_role "$__disk_analyzer_role_name" "$DISK_ANALYZER_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--disk-analyzer-role-name"
        blue "\n# Assigning the role \"$__disk_analyzer_role_name\" for the disk analyzer (service principal \"$scanner_app_service_principal_id\")"
        assign_role_to_service_principal_in_scope "$__disk_analyzer_role_name" "$scanner_app_service_principal_id" "$scope"

        if $__with_data_scanning; then
            json_array_actions=$(array_to_json_array "${DATA_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
            create_or_update_custom_role "$__data_scanning_role_name" "$DATA_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--data-scanning-role-name"
            local data_scanning_roles=("$__data_scanning_role_name" "${DATA_SCANNING_STANDARD_ROLES[@]}")
            if $__with_openai_scanning; then
                data_scanning_roles+=("${OPENAI_STANDARD_ROLES[@]}")
            fi
            for role in "${data_scanning_roles[@]}";
            do
                blue "\n# Assigning the role \"$role\" for the disk analyzer (service principal \"$scanner_app_service_principal_id\")"
                assign_role_to_service_principal_in_scope "$role" "$scanner_app_service_principal_id" "$scope"
            done
        fi

        if $__with_serverless_scanning; then
            json_array_actions=$(array_to_json_array "${SERVERLESS_SCANNING_CUSTOM_ROLE_ACTIONS[@]}")
            create_or_update_custom_role "$__serverless_scanning_role_name" "$SERVERLESS_SCANNING_CUSTOM_ROLE_DESCRIPTION" "$scope" "${json_array_actions}" "[]" "--serverless-scanning-role-name"
            blue "\n# Assigning the role \"$__serverless_scanning_role_name\" for the disk analyzer (service principal \"$scanner_app_service_principal_id\")"
            assign_role_to_service_principal_in_scope "$__serverless_scanning_role_name" "$scanner_app_service_principal_id" "$scope"
        fi
    fi

    validate_subscription_deployment "$app_id" "$service_principal_id" "$subscription" "${roles[@]}"
}

keyvault_deployment_in_management_group() {
    local service_principal_id="$1"
    local management_group_id="$2"
    _az account management-group show --name "$management_group_id" --expand --no-register
    local management_group="$output"
    # it is simpler to iterate the object array if there are no spaces in between
    # borrowed this trick from https://www.starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
    local subscriptions=($(echo "$management_group" | jq -r ".children // [] | .[] | select(.type==\"$WIZ_SUBSCRIPTION_TYPE\") | {id:.id,name:.name} | @base64"))
    local child_management_groups=($(echo "$management_group" | jq -r ".children // [] | .[] | select(.type==\"$WIZ_MANAGEMENT_GROUP_TYPE\") | {id:.id,name:.name} | @base64"))
    for subscription_base64 in "${subscriptions[@]}"; do
        local subscription
        subscription=$(echo "$subscription_base64" | base64 --decode | jq -c .)
        local subscription_name
        subscription_name=$(echo "$subscription" | jq -r .name)
        blue "\n# Adding access policies to all keyvaults in subscription \"$subscription_name\""
        add_access_policies_to_all_keyvaults_in_subscription "$subscription_name" "$service_principal_id"
        blue "\n# Adding local rbac permissions to all managed hsm keys in subscription \"$subscription_name\""
        add_local_rbac_permissions_to_all_managedhsm_keys_in_subscription "$subscription_name" "$service_principal_id"
    done

    for child_management_group_base64 in "${child_management_groups[@]}"; do
        local child_management_group
        child_management_group=$(echo "$child_management_group_base64" | base64 --decode | jq -c .)
        local child_management_group_name
        child_management_group_name=$(echo "$child_management_group" | jq -r .name)
        blue "\n# Creating access policies for all keyvaults in subscriptions under management groupֿ \"$child_management_group_name\""
        keyvault_deployment_in_management_group "$service_principal_id" "$child_management_group_name"
    done
}

check_permissions_for_management_group_deployment() {
    local scope="$WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX/$_management_group_id_"
    check_permissions_for_deployment_in_scope "management group" "$scope"
}

check_permissions_for_tenant_deployment() {
    local scope="$WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX/$_tenant_id_"
    check_permissions_for_deployment_in_scope "management group" "$scope"
}

###########################################################
# command-line parser code                                #
# generated by using https://github.com/andsens/docopt.sh #
###########################################################

# docopt parser below, refresh this parser with `docopt.sh source.sh`
# shellcheck disable=2016,1075
docopt() { parse() { if ${DOCOPT_DOC_CHECK:-true}; then local doc_hash; if doc_hash=$(printf "%s" "$DOC" | (sha256sum 2>/dev/null || shasum -a 256)); then if [[ ${doc_hash:0:5} != "$digest" ]]; then stderr "The current usage doc (${doc_hash:0:5}) does not match what the parser was generated with (${digest}); Run \`docopt.sh\` to refresh the parser."; _return 70; fi; fi; fi; local root_idx=$1; shift; argv=("$@"); parsed_params=(); parsed_values=(); left=(); testdepth=0; local arg; while [[ ${#argv[@]} -gt 0 ]]; do if [[ ${argv[0]} = "--" ]]; then for arg in "${argv[@]}"; do parsed_params+=('a'); parsed_values+=("$arg"); done; break; elif [[ ${argv[0]} = --* ]]; then parse_long; elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then parse_shorts; elif ${DOCOPT_OPTIONS_FIRST:-false}; then for arg in "${argv[@]}"; do parsed_params+=('a'); parsed_values+=("$arg"); done; break; else parsed_params+=('a'); parsed_values+=("${argv[0]}"); argv=("${argv[@]:1}"); fi; done; local idx; if ${DOCOPT_ADD_HELP:-true}; then for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue; if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then stdout "$trimmed_doc"; _return 0; fi; done; fi; if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue; if [[ ${longs[$idx]} = "--version" ]]; then stdout "$DOCOPT_PROGRAM_VERSION"; _return 0; fi; done; fi; local i=0; while [[ $i -lt ${#parsed_params[@]} ]]; do left+=("$i"); ((i++)) || true; done; if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then error; fi; return 0; }; parse_shorts() { local token=${argv[0]}; local value; argv=("${argv[@]:1}"); [[ $token = -* && $token != --* ]] || _return 88; local remaining=${token#-}; while [[ -n $remaining ]]; do local short="-${remaining:0:1}"; remaining="${remaining:1}"; local i=0; local similar=(); local match=false; for o in "${shorts[@]}"; do if [[ $o = "$short" ]]; then similar+=("$short"); [[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ ${#similar[@]} -gt 1 ]]; then error "${short} is specified ambiguously ${#similar[@]} times"; elif [[ ${#similar[@]} -lt 1 ]]; then match=${#shorts[@]}; value=true; shorts+=("$short"); longs+=(''); argcounts+=(0); else value=false; if [[ ${argcounts[$match]} -ne 0 ]]; then if [[ $remaining = '' ]]; then if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then error "${short} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}"); else value=$remaining; remaining=''; fi; fi; if [[ $value = false ]]; then value=true; fi; fi; parsed_params+=("$match"); parsed_values+=("$value"); done; }; parse_long() { local token=${argv[0]}; local long=${token%%=*}; local value=${token#*=}; local argcount; argv=("${argv[@]:1}"); [[ $token = --* ]] || _return 88; if [[ $token = *=* ]]; then eq='='; else eq=''; value=false; fi; local i=0; local similar=(); local match=false; for o in "${longs[@]}"; do if [[ $o = "$long" ]]; then similar+=("$long"); [[ $match = false ]] && match=$i; fi; ((i++)) || true; done; if [[ $match = false ]]; then i=0; for o in "${longs[@]}"; do if [[ $o = $long* ]]; then similar+=("$long"); [[ $match = false ]] && match=$i; fi; ((i++)) || true; done; fi; if [[ ${#similar[@]} -gt 1 ]]; then error "${long} is not a unique prefix: ${similar[*]}?"; elif [[ ${#similar[@]} -lt 1 ]]; then [[ $eq = '=' ]] && argcount=1 || argcount=0; match=${#shorts[@]}; [[ $argcount -eq 0 ]] && value=true; shorts+=(''); longs+=("$long"); argcounts+=("$argcount"); else if [[ ${argcounts[$match]} -eq 0 ]]; then if [[ $value != false ]]; then error "${longs[$match]} must not have an argument"; fi; elif [[ $value = false ]]; then if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then error "${long} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}"); fi; if [[ $value = false ]]; then value=true; fi; fi; parsed_params+=("$match"); parsed_values+=("$value"); }; required() { local initial_left=("${left[@]}"); local node_idx; ((testdepth++)) || true; for node_idx in "$@"; do if ! "node_$node_idx"; then
left=("${initial_left[@]}"); ((testdepth--)) || true; return 1; fi; done; if [[ $((--testdepth)) -eq 0 ]]; then left=("${initial_left[@]}"); for node_idx in "$@"; do "node_$node_idx"; done; fi; return 0; }; either() { local initial_left=("${left[@]}"); local best_match_idx; local match_count; local node_idx; ((testdepth++)) || true; for node_idx in "$@"; do if "node_$node_idx"; then if [[ -z $match_count || ${#left[@]} -lt $match_count ]]; then best_match_idx=$node_idx; match_count=${#left[@]}; fi; fi; left=("${initial_left[@]}"); done; ((testdepth--)) || true; if [[ -n $best_match_idx ]]; then "node_$best_match_idx"; return 0; fi; left=("${initial_left[@]}"); return 1; }; optional() { local node_idx; for node_idx in "$@"; do "node_$node_idx"; done; return 0; }; _command() { local i; local name=${2:-$1}; for i in "${!left[@]}"; do local l=${left[$i]}; if [[ ${parsed_params[$l]} = 'a' ]]; then if [[ ${parsed_values[$l]} != "$name" ]]; then return 1; fi; left=("${left[@]:0:$i}" "${left[@]:((i+1))}"); [[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then eval "((var_$1++)) || true"; else eval "var_$1=true"; fi; return 0; fi; done; return 1; }; switch() { local i; for i in "${!left[@]}"; do local l=${left[$i]}; if [[ ${parsed_params[$l]} = "$2" ]]; then left=("${left[@]:0:$i}" "${left[@]:((i+1))}"); [[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then eval "((var_$1++))" || true; else eval "var_$1=true"; fi; return 0; fi; done; return 1; }; value() { local i; for i in "${!left[@]}"; do local l=${left[$i]}; if [[ ${parsed_params[$l]} = "$2" ]]; then left=("${left[@]:0:$i}" "${left[@]:((i+1))}"); [[ $testdepth -gt 0 ]] && return 0; local value; value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done; return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() { printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() { [[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:3225}; usage=${DOC:30:500}; digest=bb905; shorts=('' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' '' ''); longs=(--continue-on-error --verbose --with-shadow-data --with-openai-scanning --reset-credentials-for-custom-app --with-serverless-scanning --reconcile-role-assignment-conditions --wait-for-retry-count --scanner-app-name --wiz-gov --with-aad-consent --disk-analyzer-role-name --with-keyvault --custom-role-name --with-aad-consent-only --check-roles-first --serverless-scanning-role-name --require-keyvault-permissions --scanner-app-id --with-data-scanning --only-keyvault --wiz-managed-id --with-custom-app --data-scanning-role-name --custom-app-name --quiet --setup-aad-permissions); argcounts=(0 0 0 0 0 0 0 1 1 0 0 1 0 1 0 0 1 0 1 0 0 1 0 1 1 0 0); node_0(){ switch __continue_on_error 0; }; node_1(){ switch __verbose 1; }; node_2(){ switch __with_shadow_data 2; }; node_3(){ switch __with_openai_scanning 3; }; node_4(){ switch __reset_credentials_for_custom_app 4; }; node_5(){ switch __with_serverless_scanning 5; }; node_6(){ switch __reconcile_role_assignment_conditions 6; }; node_7(){ value __wait_for_retry_count 7; }; node_8(){ value __scanner_app_name 8; }; node_9(){ switch __wiz_gov 9; }; node_10(){ switch __with_aad_consent 10; }; node_11(){ value __disk_analyzer_role_name 11; }; node_12(){ switch __with_keyvault 12; }; node_13(){ value __custom_role_name 13; }; node_14(){ switch __with_aad_consent_only 14; }; node_15(){ switch __check_roles_first 15; }; node_16(){ value __serverless_scanning_role_name 16; }; node_17(){ switch __require_keyvault_permissions 17; }; node_18(){ value __scanner_app_id 18; }; node_19(){ switch __with_data_scanning 19; }; node_20(){ switch __only_keyvault 20; }; node_21(){ value __wiz_managed_id 21; }; node_22(){ switch __with_custom_app 22; }; node_23(){ value __data_scanning_role_name 23; }; node_24(){ value __custom_app_name 24; }; node_25(){ switch __quiet 25; }; node_26(){
switch __setup_aad_permissions 26; }; node_27(){ value _management_group_id_ a; }; node_28(){ value _subscription_id_ a; }; node_29(){ value _tenant_id_ a; }; node_30(){ _command standard; }; node_31(){ _command management_group_deployment management-group-deployment; }; node_32(){ _command subscription_deployment subscription-deployment; }; node_33(){ _command deploy_to_all_subscriptions deploy-to-all-subscriptions; }; node_34(){ _command outpost; }; node_35(){ _command aad; }; node_36(){ optional 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26; }; node_37(){ optional 36; }; node_38(){ required 37 30 31 27; }; node_39(){ required 37 30 32 28; }; node_40(){ required 37 30 33 29; }; node_41(){ required 37 34 31 27; }; node_42(){ required 37 34 32 28; }; node_43(){ required 37 34 33 29; }; node_44(){ required 37 35; }; node_45(){ either 38 39 40 41 42 43 44; }; node_46(){ required 45; }; cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2; printf "%s\n" "${DOC:30:500}" >&2; exit 1; }'; unset var___continue_on_error var___verbose var___with_shadow_data var___with_openai_scanning var___reset_credentials_for_custom_app var___with_serverless_scanning var___reconcile_role_assignment_conditions var___wait_for_retry_count var___scanner_app_name var___wiz_gov var___with_aad_consent var___disk_analyzer_role_name var___with_keyvault var___custom_role_name var___with_aad_consent_only var___check_roles_first var___serverless_scanning_role_name var___require_keyvault_permissions var___scanner_app_id var___with_data_scanning var___only_keyvault var___wiz_managed_id var___with_custom_app var___data_scanning_role_name var___custom_app_name var___quiet var___setup_aad_permissions var__management_group_id_ var__subscription_id_ var__tenant_id_ var_standard var_management_group_deployment var_subscription_deployment var_deploy_to_all_subscriptions var_outpost var_aad; parse 46 "$@"; local prefix=${DOCOPT_PREFIX:-''}; unset "${prefix}__continue_on_error" "${prefix}__verbose" \
"${prefix}__with_shadow_data" "${prefix}__with_openai_scanning" "${prefix}__reset_credentials_for_custom_app" "${prefix}__with_serverless_scanning" "${prefix}__reconcile_role_assignment_conditions" "${prefix}__wait_for_retry_count" "${prefix}__scanner_app_name" "${prefix}__wiz_gov" "${prefix}__with_aad_consent" "${prefix}__disk_analyzer_role_name" "${prefix}__with_keyvault" "${prefix}__custom_role_name" "${prefix}__with_aad_consent_only" "${prefix}__check_roles_first" "${prefix}__serverless_scanning_role_name" "${prefix}__require_keyvault_permissions" "${prefix}__scanner_app_id" "${prefix}__with_data_scanning" "${prefix}__only_keyvault" "${prefix}__wiz_managed_id" "${prefix}__with_custom_app" "${prefix}__data_scanning_role_name" "${prefix}__custom_app_name" "${prefix}__quiet" "${prefix}__setup_aad_permissions" "${prefix}_management_group_id_" "${prefix}_subscription_id_" "${prefix}_tenant_id_" "${prefix}standard" "${prefix}management_group_deployment" "${prefix}subscription_deployment" "${prefix}deploy_to_all_subscriptions" "${prefix}outpost" "${prefix}aad"; eval "${prefix}"'__continue_on_error=${var___continue_on_error:-false}'; eval "${prefix}"'__verbose=${var___verbose:-false}'; eval "${prefix}"'__with_shadow_data=${var___with_shadow_data:-false}'; eval "${prefix}"'__with_openai_scanning=${var___with_openai_scanning:-false}'; eval "${prefix}"'__reset_credentials_for_custom_app=${var___reset_credentials_for_custom_app:-false}'; eval "${prefix}"'__with_serverless_scanning=${var___with_serverless_scanning:-false}'; eval "${prefix}"'__reconcile_role_assignment_conditions=${var___reconcile_role_assignment_conditions:-false}'; eval "${prefix}"'__wait_for_retry_count=${var___wait_for_retry_count:-10}'; eval "${prefix}"'__scanner_app_name=${var___scanner_app_name:-'"'"'Wiz Disk Analyzer - Scanner'"'"'}'; eval "${prefix}"'__wiz_gov=${var___wiz_gov:-false}'; eval "${prefix}"'__with_aad_consent=${var___with_aad_consent:-false}'
eval "${prefix}"'__disk_analyzer_role_name=${var___disk_analyzer_role_name:-WizDiskAnalyzerRole}'; eval "${prefix}"'__with_keyvault=${var___with_keyvault:-false}'; eval "${prefix}"'__custom_role_name=${var___custom_role_name:-WizCustomRole}'; eval "${prefix}"'__with_aad_consent_only=${var___with_aad_consent_only:-false}'; eval "${prefix}"'__check_roles_first=${var___check_roles_first:-false}'; eval "${prefix}"'__serverless_scanning_role_name=${var___serverless_scanning_role_name:-WizServerlessScanningRole}'; eval "${prefix}"'__require_keyvault_permissions=${var___require_keyvault_permissions:-false}'; eval "${prefix}"'__scanner_app_id=${var___scanner_app_id:-}'; eval "${prefix}"'__with_data_scanning=${var___with_data_scanning:-false}'; eval "${prefix}"'__only_keyvault=${var___only_keyvault:-false}'; eval "${prefix}"'__wiz_managed_id=${var___wiz_managed_id:-6de4dd30-fe2c-4a5d-838f-54eea116a9fe}'; eval "${prefix}"'__with_custom_app=${var___with_custom_app:-false}'; eval "${prefix}"'__data_scanning_role_name=${var___data_scanning_role_name:-WizDataScanningRole}'; eval "${prefix}"'__custom_app_name=${var___custom_app_name:-'"'"'Wiz Security'"'"'}'; eval "${prefix}"'__quiet=${var___quiet:-false}'; eval "${prefix}"'__setup_aad_permissions=${var___setup_aad_permissions:-false}'; eval "${prefix}"'_management_group_id_=${var__management_group_id_:-}'; eval "${prefix}"'_subscription_id_=${var__subscription_id_:-}'; eval "${prefix}"'_tenant_id_=${var__tenant_id_:-}'; eval "${prefix}"'standard=${var_standard:-false}'; eval "${prefix}"'management_group_deployment=${var_management_group_deployment:-false}'; eval "${prefix}"'subscription_deployment=${var_subscription_deployment:-false}'; eval "${prefix}"'deploy_to_all_subscriptions=${var_deploy_to_all_subscriptions:-false}'; eval "${prefix}"'outpost=${var_outpost:-false}'; eval "${prefix}"'aad=${var_aad:-false}'; local docopt_i=1; [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do declare -p "${prefix}__continue_on_error" "${prefix}__verbose" \
"${prefix}__with_shadow_data" "${prefix}__with_openai_scanning" "${prefix}__reset_credentials_for_custom_app" "${prefix}__with_serverless_scanning" "${prefix}__reconcile_role_assignment_conditions" "${prefix}__wait_for_retry_count" "${prefix}__scanner_app_name" "${prefix}__wiz_gov" "${prefix}__with_aad_consent" "${prefix}__disk_analyzer_role_name" "${prefix}__with_keyvault" "${prefix}__custom_role_name" "${prefix}__with_aad_consent_only" "${prefix}__check_roles_first" "${prefix}__serverless_scanning_role_name" "${prefix}__require_keyvault_permissions" "${prefix}__scanner_app_id" "${prefix}__with_data_scanning" "${prefix}__only_keyvault" "${prefix}__wiz_managed_id" "${prefix}__with_custom_app" "${prefix}__data_scanning_role_name" "${prefix}__custom_app_name" "${prefix}__quiet" "${prefix}__setup_aad_permissions" "${prefix}_management_group_id_" "${prefix}_subscription_id_" "${prefix}_tenant_id_" "${prefix}standard" "${prefix}management_group_deployment" "${prefix}subscription_deployment" "${prefix}deploy_to_all_subscriptions" "${prefix}outpost" "${prefix}aad"; done; }
# docopt parser above, complete command for generating this parser is `docopt.sh --line-length=2048 source.sh`

########
# main #
########

wiz_azure_deployment_script() {
    eval "$(docopt "$@")"
    set -euo pipefail
    shopt -s inherit_errexit
    blue "Script version: $DOCOPT_PROGRAM_VERSION"

    get_azure_cloud_environment
    lightblue "Azure Environment: $azure_cloud_environment_name"

    disable_config_parameter_persistence

    if $__only_keyvault; then
        __with_keyvault="$__only_keyvault"
    fi

    if $aad || $__with_aad_consent_only; then
        aad_grant_admin_consent
    else
        if $management_group_deployment; then
            management_group_deployment
        fi

        if $subscription_deployment; then
            subscription_deployment
        fi

        if $deploy_to_all_subscriptions; then
            deploy_to_all_subscriptions
        fi
    fi


}

####
WIZ_GOV_ENTERPRISE_APP_ID="${WIZ_GOV_ENTERPRISE_APP_ID:-e076162d-a75e-44dc-b12f-a52027473a7f}"
WIZ_GRAPH_API_ID="${WIZ_GRAPH_API_ID:-00000002-0000-0000-c000-000000000000}"
WIZ_MICROSOFT_GRAPH_ID="${WIZ_MICROSOFT_GRAPH_ID:-00000003-0000-0000-c000-000000000000}"
WIZ_MICROSOFT_GRAPH_ID_OBJECT_ID="${WIZ_MICROSOFT_GRAPH_ID_OBJECT_ID:-a7d1991d-5c2b-412f-b0d7-52f5ccf7b204}"
WIZ_PERMISSION_READ_DIRECTORY_DATA="${WIZ_PERMISSION_READ_DIRECTORY_DATA:-5778995a-e1bf-45b8-affa-663a9f3f4d04}"
WIZ_PERMISSION_USER_READ="${WIZ_PERMISSION_USER_READ:-e1fe6dd8-ba31-4d61-89e7-88639da4683d}"
WIZ_PERMISSION_AUDIT_LOG_READ_ALL="${WIZ_PERMISSION_AUDIT_LOG_READ_ALL:-b0afded3-3588-46d8-8b3d-9842eff778da}"
WIZ_PERMISSION_DIRECTORY_READ_ALL="${WIZ_PERMISSION_DIRECTORY_READ_ALL:-7ab1d382-f21e-4acd-a863-ba3e13f7da61}"
WIZ_PERMISSION_POLICY_READ_ALL="${WIZ_PERMISSION_POLICY_READ_ALL:-246dd0d5-5bd0-4def-940b-0421030a5b68}"
WIZ_PERMISSION_ROLEMANAGEMENT_READ_ALL="${WIZ_PERMISSION_ROLEMANAGEMENT_READ_ALL:-c7fbd983-d9aa-4fa7-84b8-17382c103bc4}"
WIZ_PERMISSION_ACCESSREVIEW_READ_ALL="${WIZ_PERMISSION_ACCESSREVIEW_READ_ALL:-d07a8cc0-3d51-4b77-b3b0-32704d1f69fa}"
WIZ_PERMISSION_AUDITLOG_READ_ALL="${WIZ_PERMISSION_AUDITLOG_READ_ALL:-b0afded3-3588-46d8-8b3d-9842eff778da}"
WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX="/providers/Microsoft.Management/managementGroups"
WIZ_MANAGEMENT_GROUP_TYPE="Microsoft.Management/managementGroups"
WIZ_SUBSCRIPTION_SCOPE_PREFIX="/subscriptions"
WIZ_SUBSCRIPTION_TYPE="/subscriptions"

# Role assignment status codes
declare -r ROLE_ASSIGNMENT_MATCH_CONDITION=0
declare -r ROLE_ASSIGNMENT_NOT_FOUND=1
declare -r ROLE_ASSIGNMENT_CONDITION_MISMATCH=2


# Regular expressions
# https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules
# https://github.com/MicrosoftDocs/azure-docs/blob/main/includes/managed-identity-ua-character-limits.md
# | --------------- | ------ | --------------------------------------------- |
# | entity          | length | valid characters                              |
# | --------------- | ------ | --------------------------------------------- |
# | vaults          | 3-24   | Alphanumerics and hyphens.                    |
# |                 |        | Start with letter.  End with letter or digit. |
# |                 |        | Can't contain consecutive hyphens             |
# | --------------- | ------ | --------------------------------------------- |
# | managed         | 3-24   | Alphanumerics and hyphens.                    |
# | identities      |        | Start with letter.  End with letter or digit. |
# |                 |        | Can't contain consecutive hyphens             |
# |                 |        | For the assignment to a virtual machine or    |
# |                 |        | virtual machine scale set to work properly    |

HSM_CRYPTO_AUDITOR_ROLE_ID="2c18b078-7c48-4d3a-af88-5a3a1b3f82b3"
KEY_VAULT_NAME_REGEX="^[A-Za-z][A-Za-z0-9-]{1,22}[A-Za-z0-9]$"
KEY_VAULT_NAME_CONSECUTIVE_HYPENS_REGEX="--"

# Colors
end="\033[0m"
black="\033[0;30m"
blackb="\033[1;30m"
white="\033[0;37m"
whiteb="\033[1;37m"
red="\033[0;31m"
redb="\033[1;31m"
green="\033[0;32m"
greenb="\033[1;32m"
yellow="\033[0;33m"
yellowb="\033[1;33m"
blue="\033[0;34m"
blueb="\033[1;34m"
purple="\033[0;35m"
purpleb="\033[1;35m"
lightblue="\033[0;36m"
lightblueb="\033[1;36m"

function black {
    echo -e "${black}$@${end}"
}

function blackb {
    echo -e "${blackb}$@${end}"
}

function white {
    echo -e "${white}$@${end}"
}

function whiteb {
    echo -e "${whiteb}$@${end}"
}

function red {
    echo -e "${red}$@${end}"
}

function redb {
    echo -e "${redb}$@${end}"
}

function green {
    echo -e "${green}$@${end}"
}

function greenb {
    echo -e "${greenb}$@${end}"
}

function yellow {
    echo -e "${yellow}$@${end}"
}

function yellowb {
    echo -e "${yellowb}$@${end}"
}

function blue {
    echo -e "${blue}$@${end}"
}

function blueb {
    echo -e "${blueb}$@${end}"
}

function purple {
    echo -e "${purple}$@${end}"
}

function purpleb {
    echo -e "${purpleb}$@${end}"
}

function lightblue {
    echo -e "${lightblue}$@${end}"
}

function lightblueb {
    echo -e "${lightblueb}$@${end}"
}


ask_for_confirmation_to_proceed() {
    if $__quiet; then
        return 0
    fi
    read -r -p "Is it okay to proceed? [y/N] " response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        red "Goodbye"
        exit 1
    fi
    return 0
}

join_by () {
    local d=${1-}
    local f=${2-}
    if shift 2;  then
        printf %s "$f" "${@/#/$d}"
    fi
}

_wrap_in_quotes_if_necessary() {
    local args=$@
    local wrapped_args=()
    for arg in "$@";
    do
        if [[ $arg =~ [[:space:]]+ || $arg =~ [[] || $arg =~ [[] || $arg =~ \" || $arg =~ \' ]]; then
            wrapped_args+=("${arg@Q}")
        else
            wrapped_args+=("$arg")
        fi
    done
    join_by ' ' ${wrapped_args[@]}
}

_execute_az() {
    wrapped=$(_wrap_in_quotes_if_necessary "$@")
    lightblue \$ az "$wrapped"

    # we don't want the execution of az cli to fail the script,
    # we want to catch the error
    set +e
    output=$(AZURE_DEFAULTS_GROUP="" AZURE_DEFAULTS_LOCATION="" az "$@" --output json --only-show-errors 2>&1)
    retVal=$?
    set -e

    if [ $retVal -ne 0 ]; then
        if $__continue_on_error; then
            echo "$output"
            yellow "Continue on error"
        fi
    else
        if $__verbose; then
            echo "$output"
        fi
    fi
    return 0
}

print_error_message_and_exit() {
    local message="$1"

    red "Exiting. \n$message"
    exit 1
}

_print_generic_error_message() {
    red "If this is a permission error, you can try running the command again with '--check-roles-first' to identify the missing roles."
    red "Otherwise, please contact support."
}

_az() {
    _execute_az "$@"
    if [ $retVal -ne 0 ]; then
        if ! $__continue_on_error; then
            echo "$output"
            red "Error, exiting."
            _print_generic_error_message
            exit $retVal
        fi
    fi
    return 0
}

_openssl() {
    openssl "$@"
    if [ $retVal -ne 0 ]; then
        if ! $__continue_on_error; then
            echo "$output"
            red "Error, exiting."
            _print_generic_error_message
            exit $retVal
        fi
    fi
    return 0
}

_az_keyvault_handler() {
    _execute_az "$@"
    if [ $retVal -ne 0 ]; then
        if $__require_keyvault_permissions; then
            echo "$output"
            _print_generic_error_message
            exit $retVal
        fi
        echo "$output"
        output="[]"
        yellow "Continue on error"
        return 0
    fi
    return 0
}

_az_create_custom_role_handler() {
    _execute_az "$@"
    _role_exists_in_a_different_subscription=0
    local regex
    regex="role definition cannot be updated with a name that already exists|A custom role with the same name already exists in this directory"
    if [ $retVal -ne 0 ]; then
        if [[ "$@" =~ "role definition create" && "$output" =~ $regex ]]; then
            _role_exists_in_a_different_subscription=1
            red "Error, exiting."
            red "A role with the same name exists in a different subscription in the AD tenant."
            red "Please use a different name for the custom role, recommended using 'wiz' as a prefix, by passing the flag '${custom_role_flag_name}=<name>' in the command-line."
        else
            echo "$output"
            red "Error, exiting."
            _print_generic_error_message
        fi

        if [[ ${__unit_tests:+isset} ]]; then
            return $retVal
        fi
        exit $retVal
    fi
    return 0
}

_az_list_role_assignment_handler() {
    _execute_az "$@"
    local regex
    regex="Role .* doesn't exist."
    if [ $retVal -ne 0 ]; then
        if [[ "$output" =~ $regex ]]; then
            output="[]"
        else
            red "Error, exiting."
            _print_generic_error_message
            exit $retVal
        fi
    fi
    return 0
}

generic_resource_not_found_handler() {
    regex=$1
    if [ $retVal -ne 0 ]; then
        if [[ "$output" =~ $regex ]]; then
            echo "$output"
            return 1
        else
            echo "$output"
            red "Error, exiting."
            _print_generic_error_message
            exit $retVal
        fi
    fi
    return 0
}

_az_assign_role_to_service_principal_handler() {
    _execute_az "$@"
    local retVal=$?
    if [ $retVal -ne 0 ]; then
        # Handle "RoleAssignmentExists" error as success
        if [[ "$output" =~ "RoleAssignmentExists" ]]; then
            return 0
        fi
        # If it's not a "RoleAssignmentExists" error, handle it as a "not found" error or exit
        local regex=".*Role .* doesn't exist."
        generic_resource_not_found_handler $regex
        return $?
    fi
    return 0
}

_az_reset_custom_app_credentials_handler() {
    _execute_az "$@"
    local regex=".*Resource .* does not exist.*"
    generic_resource_not_found_handler $regex
    return $?
}

_az_create_service_principal_handler() {
    _execute_az "$@"
    local regex=".*Service principal with .* doesn't exist.*"
    generic_resource_not_found_handler $regex
    return $?
}

_az_app_permission_handler() {
    _execute_az "$@"
    local regex=".*Service principal with .* doesn't exist.*"
    generic_resource_not_found_handler $regex
    return $?
}

_az_app_admin_consent_handler() {
    _execute_az "$@"
    local regex="Permission being assigned already exists on the object"

    if [ $retVal -ne 0 ]; then
        if [[ "$output" =~ .*"$regex".* ]]; then
            return 0
        else
            return 1
        fi
    fi

    return 0
}

_trap() {
  trap "$@"
}

disable_config_parameter_persistence() {
  # Best effort - config param-persist command might not be available in older AZ cli installations
  _execute_az config param-persist show >/dev/null 2>&1 || true
  if [[ $retVal -ne 0 ]] || [[ -z "$output" ]] || [[ "$output" == "{}" ]]; then
    return 0
  fi

  _execute_az config param-persist off >/dev/null 2>&1 || true
  if [[ $retVal -ne 0 ]] || [[ -z "$output" ]] || [[ "$output" =~ "is off already" ]]; then
    return 0
  fi

  # Re-enable param-persist on exit to not disrupt previous state
  _trap "__continue_on_error=$__continue_on_error; __verbose=$__verbose; _execute_az config param-persist on >/dev/null 2>&1 || true" EXIT
}

get_azure_cloud_environment() {
  _az cloud show
  azure_cloud_environment="$output"
  azure_cloud_environment_name=$(echo "${azure_cloud_environment}" | jq -r '. | .name')
}

get_microsoft_graph_endpoint() {
  if [ -z ${azure_cloud_environment+x} ]; then
    get_azure_cloud_environment
  fi
  local endpoint=$(echo "${azure_cloud_environment}" | jq -r '. | .endpoints | .microsoftGraphResourceId')
  microsoft_graph_endpoint=${endpoint%/}
}

assert_management_group_exists() {
    local group="$1"
    _az account management-group list --query "[?name=='$group']" --no-register
    if [ $(echo "$output" | jq '. | length') != "1" ]; then
        local message
        message=$(echo "management group \"$group\" not found; either you got the name wrong or you don't have permissions to it")
        if $__continue_on_error; then
            yellow $message
        else
            red $message
            exit 1
        fi
    fi
    return 0
}

custom_app_exists() {
    local app_name="$1"
    _az ad app list --all --filter "displayName eq '$app_name'"
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" -eq "0" ]]; then
        return 1
    fi
    if [[ "$count" -eq "1" ]]; then
        output=$(echo "$output" | jq -r '. | first | .appId')
        return 0
    fi

    # more than one app with the same name exists
    red "More than one app exist with name \"$app_name\", please contact support"
    exit 1
}

create_custom_app() {
    local app_name="$1"
    _az ad app create --display-name "$1" --sign-in-audience AzureADMyOrg --key-type "password"
    output=$(echo "$output" | jq -r .appId)
}

delete_custom_app() {
    local app_id="$1"
    _az ad app delete --id "$app_id"
}

service_principal_for_app_exists() {
    local app_id="$1"
    _az ad sp list --all --filter "appId eq '$app_id'"
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" -gt "0" ]]; then
        # there can only be one, so this is safe
        output=$(echo "$output" | jq -r '. | first | .id')
        return 0
    fi
    return 1
}

service_principal_for_microsoft_app_exists() {
    local app_id="$1"
    _az ad sp list --all --filter "appId eq '$app_id'"
    local count
    count=$(echo "$output" | jq '. | length')

    if [[ "$count" -eq "1" ]]; then
        output=$(echo "$output" | jq -r '. | first | .id')
        return 0
    fi

    if [[ "$count" -gt "1" ]]; then
        red "Multiple service principals were found where at most one was expected. Please contact support."
        exit 1
    fi

    return 1
}

create_service_principal_for_app() {
    local app_id="$1"
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"
    while true; do
        if _az_create_service_principal_handler ad sp create --id "$app_id"; then
          break
        fi
        if [[ count -ge $max_retries ]]; then
          message="Failed to create service principal for custom app id $app_id"
          if $__continue_on_error; then
              yellow $message
              break
          else
              red $message
              exit 1
          fi
        fi
        lightblue "Couldn't create service principal, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    output=$(echo "$output" | jq -r '.id')
}

delete_role_assignments_for_app() {
    local app_id="$1"
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"
    while true; do
        if _az_list_role_assignment_handler role assignment list --assignee "$app_id"; then
            local role_assignments
            role_assignments=$(echo "$output" | jq -r '.[] | .id')
            for role_assignment in $role_assignments; do
                _az role assignment delete --ids "$role_assignment"
            done
            break
        fi
        if [[ count -ge $max_retries ]]; then
            message="Failed to delete role assignments for custom app id $app_id"
            if $__continue_on_error; then
                yellow $message
                break
            else
                red $message
                exit 1
            fi
        fi
        lightblue "Couldn't delete role assignments, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

}

delete_service_principal_for_app() {
    local sp_id="$1"
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"
    while true; do
        if _az_create_service_principal_handler ad sp delete --id "$sp_id"; then
          break
        fi
        if [[ count -ge $max_retries ]]; then
          message="Failed to delete service principal id $sp_id"
          if $__continue_on_error; then
              yellow $message
              break
          else
              red $message
              exit 1
          fi
        fi
        lightblue "Couldn't delete service principal, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    output=$(echo "$output" | jq -r '.id')
}

add_permission_for_app() {
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"

    local app_id="$1"
    local api="$2"
    local api_permissions="${@:3}"

    while true; do
        if _az_app_permission_handler ad app permission add --id "$app_id" --api "$api" --api-permissions $api_permissions; then
          break
        fi
        if [[ count -ge $max_retries ]]; then
          message="Failed to add permissions to api $api for custom app id $app_id"
          if $__continue_on_error; then
              yellow $message
              break
          else
              red $message
              exit 1
          fi
        fi
        lightblue "Couldn't add permissions, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    output=$(echo "$output" | jq -r '.id')
}

grant_permission_for_app() {
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"

    local app_id="$1"
    local api="$2"

    while true; do
        if _az_app_permission_handler ad app permission grant --id "$app_id" --api "$api"; then
          break
        fi
        if [[ count -ge $max_retries ]]; then
          message="Failed to grant permissions to api $api for custom app id $app_id"
          if $__continue_on_error; then
              yellow $message
              break
          else
              red $message
              exit 1
          fi
        fi
        lightblue "Couldn't grant permissions, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    output=$(echo "$output" | jq -r '.id')
}

declare -A resource_ids_cache

_az_get_resource_id_for_app() {
    if [[ -v resource_ids_cache["$1"] ]]; then
        output="${resource_ids_cache["$1"]}"
        return 0
    fi
    _az ad sp show --id "$1"
    output=$(echo "$output" | jq -r '.id')
    resource_ids_cache["$1"]="$output"
}

grant_admin_consent_for_app() {
    local service_principal_id="$1"
    local resource_id="$2"
    local app_role_id="$3"

    get_microsoft_graph_endpoint
    _az_get_resource_id_for_app "$resource_id"
    tenant_resource_id="$output"
    if ! _az_app_admin_consent_handler rest --method POST --url ${microsoft_graph_endpoint}/v1.0/servicePrincipals/$service_principal_id/appRoleAssignments --body "{\"principalId\": $(quote_json_str "$service_principal_id"),\"resourceId\": $(quote_json_str "$tenant_resource_id"),\"appRoleId\": $(quote_json_str "$app_role_id")}"; then
        message="Failed to grant admin-consent to role $app_role_id for service principal id $service_principal_id in resource $resource_id"
        if $__continue_on_error; then
            yellow $message
        else
            red $message
            exit 1
        fi
    fi
}

output_contains_exactly_one_role() {
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" == "1" ]]; then
        #   {...
        #     "id": "/providers/Microsoft.Authorization/roleDefinitions/7bbdaaed-20f6-40c2-a573-abe7093c37a2",
        #     "name": "7bbdaaed-20f6-40c2-a573-abe7093c37a2",
        #   ...}
        output=$(echo "$output" | jq -r '. | first')
        last_role="$output"
        return 0
    fi
    return 1
}

role_exists() {
    local role="$1"
    _az role definition list --query "[?roleName=='$role']"
    output_contains_exactly_one_role
    return $?
}

role_exists_in_scope() {
    local role="$1"
    local scope="$2"
    _az role definition list --query "[?roleName=='$role']" --scope "$scope"
    output_contains_exactly_one_role
    return $?
}

wait_for_custom_role_existence_with_scope_assignment() {
    local role="$1"
    local scope="$2"

    wait_for_custom_role_scope_assignment "$role" "$scope"
    return $?
}

role_exists_in_subscription() {
    local role="$1"
    local subscription="$2"
    local scope="$WIZ_SUBSCRIPTION_SCOPE_PREFIX/$subscription"

    wait_for_custom_role_scope_assignment "$role" "$scope"
    return $?
}

role_exists_in_management_group() {
    local role="$1"
    local management_group="$2"
    local scope="$WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX/$management_group"

    role_exists_in_scope "$role" "$scope"
    return $?
}

print_role_json() {
    local name="$1"
    local description="$2"
    local assignable_scopes="$3"
    local actions="$4"
    local data_actions="$5"
    echo "{
    \"Name\": \"$name\",
    \"Description\": \"$description\",
    \"Actions\": $actions,
    \"DataActions\": $data_actions,
    \"AssignableScopes\": $assignable_scopes
}"
}

create_custom_role() {
    local name="$1"
    local description="$2"
    local assignable_scopes="$3"
    local actions="$4"
    local data_actions="$5"
    local tmp_json
    tmp_json=$(mktemp)
    print_role_json "$name" "$description" "$assignable_scopes" "$actions" "$data_actions" > "$tmp_json"
    _az_create_custom_role_handler role definition create --role-definition @"$tmp_json"
    rm -f "$tmp_json"
}

update_custom_role() {
    local id="$1"
    local name="$2"
    local description="$3"
    local assignable_scopes="$4"
    local actions="$5"
    local data_actions="$6"
    local tmp_json
    tmp_json=$(mktemp)
    print_role_json "$name" "$description" "$assignable_scopes" "$actions" "$data_actions" | jq ". + {\"id\": \"$id\", \"roleName\": \"$name\"}" > "$tmp_json"
    _az role definition update --role-definition @"$tmp_json"
    rm -f "$tmp_json"
}

role_assignment_to_app_in_scope_exists() {
    local role="$1"
    local app_id="$2"
    local scope="$3"
    local expected_condition="${4:-}"

    _az_list_role_assignment_handler role assignment list --assignee "$app_id" --role "$role" --scope "$scope"
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" == "1" ]]; then
        local assignment
        assignment=$(echo "$output" | jq -r '. | first')

        # If an expected condition is provided, validate it matches
        if [[ -n "$expected_condition" ]]; then
            local actual_condition
            actual_condition=$(echo "$assignment" | jq -r '.condition // ""')

            if [[ "$actual_condition" != "$expected_condition" ]]; then
                red "Role assignment exists but condition does not match."
                red "Expected condition: $expected_condition"
                red "Actual condition: $actual_condition"
                # Return 2 to indicate condition mismatch (different from "not found" which returns 1)
                return 2
            fi
        fi

        output=$(echo "$assignment" | jq -r '.id')
        return 0
    fi
    return 1
}

update_role_assignment_condition() {
    local role="$1"
    local app_id="$2"
    local scope="$3"
    local new_condition="$4"

    # Get the existing role assignment
    _az_list_role_assignment_handler role assignment list --assignee "$app_id" --role "$role" --scope "$scope"
    local assignment
    assignment=$(echo "$output" | jq -r '. | first')

    if [[ -z "$assignment" || "$assignment" == "null" ]]; then
        red "Cannot update role assignment: assignment not found"
        return 1
    fi

    # Update the condition in the assignment JSON
    local updated_assignment
    updated_assignment=$(echo "$assignment" | jq --arg cond "$new_condition" '.condition = $cond | .conditionVersion = "2.0"')

    # Write to temp file for the update command
    local tmp_json
    tmp_json=$(mktemp)
    echo "$updated_assignment" > "$tmp_json"

    _az role assignment update --role-assignment @"$tmp_json"
    local retVal=$?
    rm -f "$tmp_json"

    if [ $retVal -ne 0 ]; then
        red "Failed to update role assignment condition"
        return 1
    fi
    return 0
}

role_assignment_to_app_in_subscription_exists() {
    local role="$1"
    local app_id="$2"
    local subscription="$3"
    local expected_condition="${4:-}"

    local scope="$WIZ_SUBSCRIPTION_SCOPE_PREFIX/$subscription"
    role_assignment_to_app_in_scope_exists "$role" "$app_id" "$scope" "$expected_condition"
    return $?
}

role_assignment_to_app_in_management_group_exists() {
    local role="$1"
    local app_id="$2"
    local management_group="$3"
    local expected_condition="${4:-}"

    local scope="$WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX/$management_group"
    role_assignment_to_app_in_scope_exists "$role" "$app_id" "$scope" "$expected_condition"
    return $?
}

# Extract base role name and optional condition from an annotated role string.
# Supported syntax: "Role Name{<condition>}"
# Example: "Storage Blob Data Contributor{@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals 'wiz-inventory-report'}"
_extract_role_and_condition() {
    local annotated_role="$1"
    role_name_out="$annotated_role"
    role_condition_out=""
    # Match everything up to the first '{' as the role name, and content inside the last trailing '}' as condition
    if [[ "$annotated_role" =~ ^([^\{]+)\{(.*)\}$ ]]; then
        role_name_out="${BASH_REMATCH[1]}"
        role_condition_out="${BASH_REMATCH[2]}"
        # Trim possible trailing spaces from role name
        role_name_out="${role_name_out%%[[:space:]]}"
        role_name_out="${role_name_out% }"
    fi
}

assign_role_to_service_principal_in_scope() {
    # https://docs.microsoft.com/en-us/azure/role-based-access-control/troubleshooting#problems-with-azure-role-assignments
    local role_annotated="$1"
    local service_principal_id="$2"
    local scope="$3"

    # Parse condition annotation (if present)
    _extract_role_and_condition "$role_annotated"
    local role_name="$role_name_out"
    local role_condition="$role_condition_out"

    local sleep_interval=10
    local count=0
    local max_retries="$__wait_for_retry_count"
    while true; do
        if [[ -z "$role_condition" ]]; then
            if _az_assign_role_to_service_principal_handler role assignment create --assignee-principal-type ServicePrincipal --assignee-object-id "$service_principal_id" --role "$role_name" --scope "$scope"; then
                break
            fi
        else
            if role_assignment_to_app_in_scope_exists "$role_name" "$service_principal_id" "$scope" "$role_condition"; then
                status=0
            else
                status=$?
            fi

            case $status in
                $ROLE_ASSIGNMENT_MATCH_CONDITION)
                    break
                    ;;
                $ROLE_ASSIGNMENT_NOT_FOUND)
                    if _az_assign_role_to_service_principal_handler role assignment create --assignee-principal-type ServicePrincipal --assignee-object-id "$service_principal_id" --role "$role_name" --scope "$scope" --condition "$role_condition" --condition-version "2.0"; then
                        break
                    fi
                    ;;
                $ROLE_ASSIGNMENT_CONDITION_MISMATCH)
                    if ${__reconcile_role_assignment_conditions:-false}; then
                        yellow "Role assignment exists with different condition, updating assignment"
                        if update_role_assignment_condition "$role_name" "$service_principal_id" "$scope" "$role_condition"; then
                            break
                        fi
                    else
                        red "ERROR: Role assignment exists but condition does not match."
                        red "Expected condition: $role_condition"
                        red "To automatically reconcile this mismatch, re-run the script with the --reconcile-role-assignment-conditions flag."
                        if ! $__continue_on_error; then
                            exit 1
                        fi
                        return 1
                    fi
                    ;;
                *) # Unexpected status
                    if ! $__continue_on_error; then
                        red "Unexpected error while checking role assignment existence"
                        exit 1
                    fi
                    return 1
                    ;;
            esac
        fi

        if [[ count -ge $max_retries ]]; then
          message="Failed assigning the role '$role_name' to the service principal"
          if $__continue_on_error; then
              yellow $message
              break
          else
              red $message
              exit 1
          fi
        fi
        lightblue "Role assignment is not applied yet, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done
    return 0
}

add_access_policies_to_all_keyvaults_in_subscription() {
    local subscription_id="$1"
    local service_principal_id="$2"

    _az keyvault list --subscription "$subscription_id" --query "[?type!='Microsoft.KeyVault/managedHSMs']"
    local all_keyvaults="$output"
    local keyvault_small_objects
    # keyvault names can contains spaces,
    # moving it to bas64 makes it easier to iterate over them
    keyvault_small_objects=$(echo "$all_keyvaults" | jq -r '.[] | {name:.name, resourceGroup:.resourceGroup} | @base64')
    for keyvault_base64 in $keyvault_small_objects; do
        local keyvault_short
        keyvault_short=$(echo $keyvault_base64 | base64 --decode | jq -c .)
        local keyvault_name
        keyvault_name=$(echo "$keyvault_short" | jq -r .name)
        keyvault_rg=$(echo "$keyvault_short" | jq -r .resourceGroup)

        # keyvault list does not return enableRbacAuthorization,
        # so we need to show each one
        _az keyvault show --name "$keyvault_name" --resource-group "$keyvault_rg" --subscription "$subscription_id"
        local keyvault="$output"
        local enableRbacAuthorization
        enableRbacAuthorization=$(echo "$keyvault" | jq -r .properties.enableRbacAuthorization)

        if [[ "$enableRbacAuthorization" != "true" ]]; then
            blue "\n# Adding access policy to keyvault name \"$keyvault_name\""
            _az_keyvault_handler keyvault set-policy --name "$keyvault_name" --resource-group "$keyvault_rg" --object-id "$service_principal_id" --subscription "$subscription_id" --certificate-permissions list listissuers get --key-permissions list --secret-permissions list
        fi
    done
}

add_local_rbac_permissions_to_all_managedhsm_keys_in_subscription() {
    local subscription_id="$1"
    local service_principal_id="$2"

    _az keyvault list --resource-type hsm --subscription "$subscription_id"

    if [ $retVal -ne 0 ]; then
        yellow "Unable to list HSMs (to add 'Managed HSM Crypto Auditor' local role permissions) in Subscription: ${subscription_id}"
        if $__continue_on_error; then
            return 1
        fi
    fi

    local all_keyvaults="$output"
    local keyvault_small_objects
    # keyvault names can contains spaces,
    # moving it to bas64 makes it easier to iterate over them
    keyvault_small_objects=$(echo "$all_keyvaults" | jq -r '.[] | {name:.name} | @base64')
    for keyvault_base64 in $keyvault_small_objects; do
        local keyvault_short
        keyvault_short=$(echo $keyvault_base64 | base64 --decode | jq -c .)
        local keyvault_name
        keyvault_name=$(echo "$keyvault_short" | jq -r .name)
        # Adding RBAC access for all keys in the vault
        blue "\n# Adding 'Managed HSM Crypto Auditor' local role permissions to managed hsm - \"$keyvault_name\""
        _az_keyvault_handler keyvault role assignment create --hsm-name "$keyvault_name" --scope /keys --role "$HSM_CRYPTO_AUDITOR_ROLE_ID" --assignee-object-id "$service_principal_id" --subscription "$subscription_id"
    done
}

user_have_role_assigned() {
    local role_name="$1"
    local role_assignments="$2"

    local result_count
    result_count=$(echo "$role_assignments" | jq ".[] | select(.roleDefinitionName==\"$role_name\")" | jq -s '. | length')
    if [[ "$result_count" == "1" ]]; then
        return 0
    fi
    return 1
}

assert_subscription_exists_and_enabled() {
    local subscription="$1"

    _az account list --all --query "[?id=='$subscription']"
    local all_subscriptions="$output"
    local enabled_subscriptions
    enabled_subscriptions=$(echo "$all_subscriptions" | jq -r '.[] | select(.state=="Enabled")' | jq -s -c .)

    if [[ $(echo "$all_subscriptions" | jq '. | length') != "1" ]]; then
        local message
        message=$(echo "subscription \"$subscription\" not found")
        if $__continue_on_error; then
            yellow $message
        else
            red $message
            exit 1
        fi
    fi

    if [[ $(echo "$enabled_subscriptions" | jq '. | length') != "1" ]]; then
        local message
        message=$(echo "subscription \"$subscription\" is disabled")
        if $__continue_on_error; then
            yellow $message
        else
            red $message
            exit 1
        fi
    fi

    return 0
}

check_permissions_for_deployment_in_scope() {
    local scope_type="$1"
    local scope="$2"

    _az ad signed-in-user show
    local user_has_sufficient_permissions=true
    local current_user_object_id
    current_user_object_id=$(echo "$output" | jq -r '.id')

    blue "\n# Checking if current user is either an Owner or User Access Admin in $scope_type \"$scope\""
    _az role assignment list --assignee "$current_user_object_id" --scope "$scope"
    local role_assignments="$output"
    if user_have_role_assigned "Owner" "$role_assignments"; then
        green "PASS"
    elif user_have_role_assigned "User Access Administrator" "$role_assignments"; then
        green "PASS"
    else
        user_has_sufficient_permissions=false
        red "User does have the sufficient roles in $scope_type \"$scope\""
    fi

    if [[ $user_has_sufficient_permissions == false ]]; then
        red "Current user does not have sufficient privileges; exiting."
        exit 1
    fi
}

check_permissions_for_subscription_deployment() {
    local scope="$WIZ_SUBSCRIPTION_SCOPE_PREFIX/$_subscription_id_"
    check_permissions_for_deployment_in_scope "subscription" "$scope"
}

b64encode() {
    if [[ "$(uname)" == "Darwin" ]]; then
        base64 -b 0
        return
    fi

    base64 -w 0
}

get_federated_credentials_for_app() {
    local app_id="$1"
    _az_reset_custom_app_credentials_handler ad app federated-credential list --id "$app_id"
    return $?
}

federated_credential_with_name_exists() {
    local app_id="$1"
    local federated_credential_params_json="$2"

    # Extract the name from the federated credential parameters JSON
    local credential_name
    credential_name=$(echo "$federated_credential_params_json" | jq -r '.name // empty')

    if [[ -z "$credential_name" ]]; then
        # If no name is provided in the JSON, we can't check for duplicates
        return 1
    fi

    # Get all federated credentials for the app
    if ! get_federated_credentials_for_app "$app_id"; then
        return 1
    fi

    local credentials="$output"
    local count
    count=$(echo "$credentials" | jq --arg name "$credential_name" '[.[] | select(.name == $name)] | length')

    if (( count > 0 )); then
        return 0
    fi
    return 1
}

create_or_update_federated_credential() {
    local custom_app_id="$1"
    local federated_credential_params_json="$2"

    # Check if a federated credential with the same name already exists
    if federated_credential_with_name_exists "$custom_app_id" "$federated_credential_params_json"; then
        yellow "Federated credential with the same name already exists for app $custom_app_id"
    elif _az_reset_custom_app_credentials_handler ad app federated-credential create --id "$custom_app_id" --parameters "$federated_credential_params_json"; then
        green "Federated credential created for app $custom_app_id"
    else
        red "Failed to create federated credential for app $custom_app_id"
    fi
}

reset_custom_app_credentials() {
    custom_app_id=$1
    with_cert=$2
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"

    if $with_cert; then
        temp_cert_pem=$(mktemp)
        temp_cert_pem+="_cert"
        temp_private_key_pem=$(mktemp)
        temp_private_key_pem+="_key"
        _openssl genpkey -out "${temp_private_key_pem}" -algorithm RSA -pkeyopt rsa_keygen_bits:4096
        _openssl req -new -x509 -key "${temp_private_key_pem}" -out "${temp_cert_pem}" -days 3650 -subj "/C=US/ST=NY/L=NY/O=Wiz/OU=Wiz/CN=wiz.io"
    fi

    while true; do
        if $with_cert; then
            if _az_reset_custom_app_credentials_handler ad app credential reset --id "$custom_app_id" --cert "@${temp_cert_pem}" --append --years 10; then
                break
            fi
        else
            if _az_reset_custom_app_credentials_handler ad app credential reset --id "$custom_app_id" --append --years 10; then
                break
            fi
        fi

        if [[ count -ge $max_retries ]]; then
          message="Failed to reset credentials for custom app id $custom_app_id"
          if $__continue_on_error; then
              yellow $message
              break
          else
              red $message
              exit 1
          fi
        fi
        lightblue "Couldn't reset custom app credentials, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    if $with_cert; then
        custom_app_cert_pem=$(cat "${temp_cert_pem}" | b64encode)
        custom_app_private_key_pem=$(cat "${temp_private_key_pem}" | b64encode)
        rm "${temp_cert_pem}"
        rm "${temp_private_key_pem}"
    else
        custom_app_secret=$(echo "$output" | jq -r .password)
    fi
}

create_or_update_custom_app() {
    local app_name="$1"
    local reset_credentials=$2
    local with_cert=$3
    local federated_credential_params_json="${4:-}"
    custom_app_id=""
    custom_app_secret=""
    custom_app_cert_pem=""
    custom_app_private_key_pem=""
    custom_app_created="false"
    custom_app_service_principal_id=""

    blue "\n# Checking if custom app \"$app_name\" already exists"
    if custom_app_exists "$app_name"; then
        custom_app_id="$output"
        blue "# App exists"
        if $reset_credentials; then
            reset_custom_app_credentials $custom_app_id $with_cert
            if $with_cert; then
                green "# Application (client) ID: ${custom_app_id}\n# Client private key PEM:\n${custom_app_private_key_pem}\n# Client cert PEM:\n${custom_app_cert_pem}\n"
            else
                green "# Application (client) ID: ${custom_app_id}\n# Client secret: ${custom_app_secret}\n"
            fi

            custom_app_created="true"
        fi
    else
        blue "\n# Creating custom app"
        create_custom_app "$app_name"
        custom_app_id="$output"
        reset_custom_app_credentials $custom_app_id $with_cert
        if $with_cert; then
            green "# Application (client) ID: ${custom_app_id}\n# Client private key PEM:\n${custom_app_private_key_pem}\n# Client cert PEM:\n${custom_app_cert_pem}\n"
        else
            green "# Application (client) ID: ${custom_app_id}\n# Client secret: ${custom_app_secret}\n"
        fi
        custom_app_created="true"
    fi
    if [[ -n "$federated_credential_params_json" ]]; then
        create_or_update_federated_credential "$custom_app_id" "$federated_credential_params_json"
    fi

    get_or_create_service_principal "$custom_app_id"
}

delete_custom_app_if_exists() {
    local app_name="$1"
    custom_app_deleted=false

    blue "\n# Checking if custom app \"$app_name\" exists"
    if custom_app_exists "$app_name"; then
        custom_app_id="$output"
        blue "# App exists"
        delete_role_assignments_for_app $custom_app_id
        if service_principal_for_app_exists "$custom_app_id"; then
            custom_app_service_principal_id="$output"
            blue "\n# Deleting service principal"
            delete_service_principal_for_app $custom_app_service_principal_id
        fi
        delete_custom_app $custom_app_id

        custom_app_deleted=true
    else
        blue "# App does not exist"
    fi
}

managed_identity_exists() {
    local name="$1"
    local subscription_id="$2"
    local resource_group_name="$3"

    _az identity list --subscription "${subscription_id}" --resource-group "${resource_group_name}" --query "[?name=='${name}']"
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" -eq "0" ]]; then
        return 1
    fi
    if [[ "$count" -eq "1" ]]; then
        managed_identity_id=$(echo "$output" | jq -r '. | first | .id')
        managed_identity_client_id=$(echo "$output" | jq -r '. | first | .clientId')
        managed_identity_principal_id=$(echo "$output" | jq -r '. | first | .principalId')
        return 0
    fi

    # more than one managed identity with the same name exists
    red "More than one managed identity exist with name \"${name}\", please contact support"
    exit 1
}

create_managed_identity() {
    local name="$1"
    local subscription_id="$2"
    local resource_group_name="$3"

    _az identity create --resource-group "${resource_group_name}" --subscription "${subscription_id}" --name "${name}"
    managed_identity_id=$(echo "$output" | jq -r '. | .id')
    managed_identity_client_id=$(echo "$output" | jq -r '. | .clientId')
    managed_identity_principal_id=$(echo "$output" | jq -r '. | .principalId')
}

get_or_create_managed_identity() {
    local managed_identity_name="$1"
    local managed_identity_subscription_id="$2"
    local managed_identity_resource_group_name="$3"
    managed_identity_id=""
    managed_identity_client_id=""
    managed_identity_principal_id=""
    managed_identity_created="false"

    blue "\n# Checking if managed identity \"$managed_identity_name\" already exists"
    if managed_identity_exists "${managed_identity_name}" "${managed_identity_subscription_id}" "${managed_identity_resource_group_name}"; then
        blue "# Managed identity exists"
    else
        blue "\n# Creating managed identity"
        create_managed_identity "${managed_identity_name}" "${managed_identity_subscription_id}" "${managed_identity_resource_group_name}"
        managed_identity_created="true"
    fi
}

get_or_create_service_principal() {
    local custom_app_id="$1"

    blue "\n# Checking if service principal exists for the custom app \"$custom_app_id\""

    if ! service_principal_for_app_exists "$custom_app_id"; then
        blue "\n# Creating service principal"
        create_service_principal_for_app "$custom_app_id"
    else
        blue "# Service principal exists"
    fi

    custom_app_service_principal_id="$output"
}

resource_group_exists() {
    local group="$1"
    local subscription="$2"
    _az group list --query "[?name=='$group']" --subscription "$subscription"
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" == "1" ]]; then
        return 0
    fi
    return 1
}

keyvault_exists() {
    local keyvault="$1"
    local resource_group="$2"
    local subscription="$3"

    _az keyvault list --query "[?name=='$keyvault']" --resource-group "$resource_group" --subscription "$subscription"
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" == "1" ]]; then
        return 0
    fi
    return 1
}

wait_keyvault_created_successfully() {
    local keyvault="$1"
    local resource_group="$2"
    local subscription="$3"
    local count=0
    local sleep_interval=5
    local max_retries="$__wait_for_retry_count"

    while true; do
        _az keyvault show --name "$keyvault" --resource-group "$resource_group" --subscription "$subscription" --query "properties.provisioningState"

        local state
        state=$(echo "$output" | jq -r .)
        if [ "$state" == "Succeeded" ]; then
          break
        fi
        if [[ count -ge $max_retries ]]; then
            red "Failed to check key-vault $keyvault provisioning state"
            return 1
        fi
        lightblue "key-vault $keyvault provisioning state is not Succeeded (is $state), will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    return 0
}

can_access_storage_account=true
storageaccount_exists() {
    local storageAccount="$1"
    local resource_group="$2"
    local subscription="$3"

    _az storage account list --query "[?name=='$storageAccount']" --resource-group "$resource_group" --subscription "$subscription"
    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" == "1" ]]; then
        local id network_acl
        id=$(echo "$output" | jq -r '. | first | .id')
        network_acl=$(az resource show --ids $id --query properties.networkAcls)

        if test "$(jq .defaultAction -r <<<"$network_acl")" = "Deny" && test "$(jq '.ipRules[0].value' -r <<<"$network_acl")" != "0.0.0.0/0"; then
            can_access_storage_account=false
        fi

        return 0
    fi
    return 1
}

wait_storageaccount_created_successfully() {
    local storageAccount="$1"
    local resource_group="$2"
    local subscription="$3"
    local count=0
    local sleep_interval=5
    local max_retries="$__wait_for_retry_count"

    while true; do
        _az storage account show --name "$storageAccount" --resource-group "$resource_group" --subscription "$subscription" --query "provisioningState"

        local state
        state=$(echo "$output" | jq -r .)
        if [ "$state" == "Succeeded" ]; then
          break
        fi
        if [[ count -ge $max_retries ]]; then
            red "Failed to check storage account $storageAccount provisioning state"
            return 1
        fi
        lightblue "storage account $storageAccount provisioning state is not Succeeded (is $state), will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    return 0
}

storageaccount_container_exists() {
    local containerName="$1"
    local storageAccount="$2"
    local subscription="$3"
    local count=0
    local sleep_interval=5
    local max_retries="$__wait_for_retry_count"

    while true; do
        _execute_az storage container list --query "[?name=='$containerName']" --account-name  "$storageAccount" --subscription "$subscription"
        if [ $retVal -eq 0 ]; then
          break
        fi
        if [[ count -ge $max_retries ]]; then
          message="Failed to check if container $containerName exists"
          if $__continue_on_error; then
              yellow $message
              break
          else
              red $message
              exit 1
          fi
        fi
        lightblue "Couldn't check if container $containerName exists, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done

    local count
    count=$(echo "$output" | jq '. | length')
    if [[ "$count" == "1" ]]; then
        return 0
    fi
    return 1
}

wait_for_custom_role_scope_assignment() {
    local role="$1"
    local scope="$2"

    blue "\n# Waiting for role \"$role\" to be assigned to \"$scope\""
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"
    while true; do
        if role_exists_in_scope "$role" "$scope"; then
            break
        fi
        if [[ count -ge $max_retries ]]; then
            return 1
        fi
        lightblue "Role assignment is not applied yet, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done
    return 0
}

wait_for_provider_to_be_registered() {
    local provider="$1"
    local subscription="$2"
    blue "\n# Waiting for registration of provider \"$provider\" to complete"
    local sleep_interval=5
    local count=0
    local max_retries="$__wait_for_retry_count"
    while true; do
        _az provider show -n "$provider" --query registrationState --subscription "$subscription"
        local state
        state=$(echo "$output" | jq -r .)
        if [[ "$state" == "Registered" ]]; then
            break
        fi

        if [[ count -ge $max_retries ]]; then
            return 1
        fi

        lightblue "Provider registration did not complete yet, will retry again in $sleep_interval seconds"
        sleep $sleep_interval
        count=$((count+=1))
        sleep_interval="$(($sleep_interval * 2))"
    done
    return 0
}

quote_json_str() {
    echo "$1" | jq -R
}

#array_to_json_array() {
#    printf '%s\n' "$@" | jq -R . | jq -s -c .
#}
array_to_json_array() {
    if [ $# -eq 0 ]; then
        echo "[]"
    else
        printf '%s\n' "$@" | jq -R . | jq -s -c .
    fi
}

create_or_update_custom_role() {
    local name="$1"
    local description="$2"
    local scope="$3"
    local actions_json="$4"
    local data_actions_json="$5"

    # this is a global variable, used in create_custom_role and in _az_keyvault_handler
    custom_role_flag_name="$6"

    blue "\n# Checking if role \"$name\" exists"
    # we check if the role exists in any scope
    if ! role_exists "$name"; then
        # Custom roles with DataActions cannot be assigned at the management group scope
        # https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles
        local data_actions_count
        data_actions_count=$(echo "$data_actions_json" | jq 'length')
        if [[ "$scope" =~ $WIZ_MANAGEMENT_GROUP_SCOPE_PREFIX && "$data_actions_count" -gt "0" ]]; then
            red "Role \"$name\" cannot be used due to a limitation in Azure:"
            red "Custom roles with DataActions cannot be assigned at the management group scope."
            exit 1
        fi

        blue "\n# Creating custom role \"$name\""
        create_custom_role "$name" "$description" "[\"$scope\"]" "$actions_json" "$data_actions_json"
    else
        blue "# Custom role exists"
        # first, we add the new scope to the existing list of assigned scopes
        local current_assigned_scopes
        local scopes_to_be_assigned
        current_assigned_scopes=$(echo "$output" | jq -r .assignableScopes)
        scopes_to_be_assigned=$(echo "$current_assigned_scopes" | jq -c -r ". += [\"$scope\"] | unique")

        local management_group_assignable_scopes
        local management_groups_to_be_assigned
        management_group_assignable_scopes=$(echo "$scopes_to_be_assigned" | jq '.[] | select(contains("managementGroups"))' | jq -s -c .)
        management_groups_count=$(echo "$management_group_assignable_scopes" | jq '. | length')

        # You can only define one management group in AssignableScopes of a custom role
        # https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles
        if [[ "$management_groups_count" -gt "1" ]]; then
            local management_groups_in_current_scope
            management_groups_in_current_scope=$(echo "$current_assigned_scopes" | jq '.[] | select(contains("managementGroups"))' | jq -s -c .)

            red "Role \"$name\" cannot be used due to a limitation in Azure:"
            red "You can only define one management group in AssignableScopes of a custom role."
            red "The role is assigned to: \n$management_groups_in_current_scope."
            red "Try creating a role in with a name, recommended using 'wiz' as a prefix, by passing the flag '${custom_role_flag_name}=<name>' in the command-line."
            exit 1
        fi

        # Custom roles with DataActions cannot be assigned at the management group scope
        # https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles
        local data_actions_count
        data_actions_count=$(echo "$data_actions_json" | jq 'length')
        if [[ "$management_groups_count" -gt "0" && "$data_actions_count" -gt "0" ]]; then
            red "Role \"$name\" cannot be used due to a limitation in Azure:"
            red "Custom roles with DataActions cannot be assigned at the management group scope."
            red "Because of this limitation, we cannot use the same role for subscription and management groups at the same time: $scopes_to_be_assigned."
            red "Try creating a role in with a name, recommended using 'wiz' as a prefix, by passing the flag '${custom_role_flag_name}=<name>' in the command-line."
            exit 1
        fi

        blue "\n# Updating custom role \"$name\""
        local role_id
        role_id=$(echo "$output" | jq -r ".name")
        update_custom_role "$role_id" "$name" "$description" "$scopes_to_be_assigned" "$actions_json" "$data_actions_json"
    fi

    # creating/updating custom roles can take time
    # this is seen when doing so from the azure portal
    if ! wait_for_custom_role_scope_assignment "$name" "$scope"; then
        red "Role \"$name\" is still not asigned to scope \$scope\""
        exit
    fi
}

ensure_object_id_has_secret_set_permission_in_keyvault() {
    local keyvault_data="$1"
    local current_user_object_id="$2"
    local subscription="$3"

    local keyvault_name
    name=$(echo "$keyvault_data" | jq .name -r)

    local enabled_rbac
    enabled_rbac=$(echo "$keyvault_data" | jq .properties.enableRbacAuthorization)
    if [[ "$enabled_rbac" == "true" ]]; then
        return 0
    fi

    local access_policies
    access_policies=$(echo "$keyvault_data" | jq .properties.accessPolicies)

    local my_access_policies
    my_access_policies=$(echo "$access_policies" | jq -r ".[] | select(.id == \"$current_user_object_id\")" | jq -s -c .)

    if [[ $(echo "$my_access_policies" | jq '. | length') != "1" ]]; then
        blue "\n# Creating access policy for current user in keyvault \"$name\""
        _az keyvault set-policy --name "$name" --secret-permissions get list set --certificate-permissions get list create import --object-id "$current_user_object_id" --subscription "$subscription"
        return 0
    fi

    local secret_permissions
    secret_permissions=$(echo "$my_access_policies" | jq '. | first | .permissions.secrets')

    local required_permissions
    required_permissions=$(echo "$secret_permissions" | jq '.[] | select(.=="set" or .=="list" or .=="get")' | jq -s -c .)

    if [[ $(echo "$required_permissions" | jq '. | length') != "3" ]]; then
        blue "\n# Updating access policy for current user in keyvault \"$name\""
        _az keyvault set-policy --name "$name" --secret-permissions get list set --certificate-permissions get list create import --object-id "$current_user_object_id" --subscription "$subscription"
    fi
}

print_script_completion_message() {
    local print_message_for_secret_deployment=${1:-true}
    green "\n# Deployment script completed."

    if [[ "$validation_result" == "PASS" ]]; then
        :
    else
        yellow "# Validation did not pass successfully."
    fi

    if [ "$print_message_for_secret_deployment" = true ]; then
        green "# Please make sure to copy the client IDs and secrets, you will need them to complete the deployment later."
        green "# The secrets are generated once and will not be regenerated or printed out in the next execution of this script."        # Existing code here...
    fi

    green "# Please continue to Wiz portal to complete the setup."
}
####################
# role definitions #
####################

STANDARD_ROLES=(
    "Azure Kubernetes Service Cluster User Role"
    "Azure Kubernetes Service RBAC Reader"
    "Reader"
)

WIZ_CUSTOM_ROLE_DESCRIPTION="Wiz Custom Role"
WIZ_CUSTOM_ROLE_ACTIONS=(
    "Microsoft.Compute/snapshots/read"
    "Microsoft.ContainerRegistry/registries/webhooks/getCallbackConfig/action"
    "Microsoft.ContainerRegistry/registries/webhooks/listEvents/action"
    "Microsoft.DataFactory/factories/querydataflowdebugsessions/action"
    "Microsoft.HDInsight/clusters/read"
    "Microsoft.Web/sites/config/list/Action"
    "Microsoft.Web/sites/slots/config/list/Action"
)
WIZ_CUSTOM_ROLE_DISK_ACTIONS=(
    "Microsoft.Compute/disks/beginGetAccess/action"
    "Microsoft.Compute/snapshots/beginGetAccess/action"
    "Microsoft.Compute/snapshots/delete"
    "Microsoft.Compute/snapshots/endGetAccess/action"
    "Microsoft.Compute/snapshots/write"
    "Microsoft.KeyVault/vaults/privateEndpointConnections/read"
    "Microsoft.KeyVault/vaults/privateEndpointConnections/write"
)

OPENAI_STANDARD_ROLES=(
    "Cognitive Services OpenAI User"
)
SERVERLESS_SCANNING_CUSTOM_ROLE_DESCRIPTION="Wiz Serverless Scanning Role"
SERVERLESS_SCANNING_CUSTOM_ROLE_ACTIONS=(
    "Microsoft.Web/hostingenvironments/sites/read"
    "Microsoft.Web/serverfarms/sites/read"
    "Microsoft.Web/sites/backup/action"
    "Microsoft.Web/sites/backup/read"
    "Microsoft.Web/sites/backups/delete"
    "Microsoft.Web/sites/backups/list/action"
    "Microsoft.Web/sites/backups/read"
    "Microsoft.Web/sites/config/list/Action"
    "Microsoft.Web/sites/config/read"
    "Microsoft.Web/sites/config/snapshots/read"
    "Microsoft.Web/sites/extensions/*/action"
    "Microsoft.Web/sites/extensions/*/read"
    "Microsoft.Web/sites/functions/*/read"
    "Microsoft.Web/sites/functions/read"
    "Microsoft.Web/sites/host/listkeys/action"
    "Microsoft.Web/sites/hostruntime/*/read"
    "Microsoft.Web/sites/instances/read"
    "Microsoft.Web/sites/listbackups/action"
    "Microsoft.Web/sites/operationresults/read"
    "Microsoft.Web/sites/operations/read"
    "Microsoft.Web/sites/publish/action"
    "Microsoft.Web/sites/publishxml/action"
    "Microsoft.Web/sites/read"
    "Microsoft.Web/sites/slots/backup/action"
    "Microsoft.Web/sites/slots/backup/read"
    "Microsoft.Web/sites/slots/backups/delete"
    "Microsoft.Web/sites/slots/backups/list/action"
    "Microsoft.Web/sites/slots/backups/read"
    "Microsoft.Web/sites/slots/config/list/Action"
    "Microsoft.Web/sites/slots/config/read"
    "Microsoft.Web/sites/slots/config/snapshots/read"
    "Microsoft.Web/sites/slots/extensions/*/action"
    "Microsoft.Web/sites/slots/extensions/*/read"
    "Microsoft.Web/sites/slots/functions/*/read"
    "Microsoft.Web/sites/slots/functions/read"
    "Microsoft.Web/sites/slots/host/listkeys/action"
    "Microsoft.Web/sites/slots/instances/read"
    "Microsoft.Web/sites/slots/listbackups/action"
    "Microsoft.Web/sites/slots/operationresults/read"
    "Microsoft.Web/sites/slots/operations/read"
    "Microsoft.Web/sites/slots/publish/action"
    "Microsoft.Web/sites/slots/publishxml/action"
    "Microsoft.Web/sites/slots/read"
    "Microsoft.Web/sites/slots/snapshots/read"
    "Microsoft.Web/sites/snapshots/read"
    "Microsoft.Web/staticSites/functions/read"
    "Microsoft.Web/staticSites/read"
    "Microsoft.Web/staticSites/userProvidedFunctionApps/read"
)
DATA_SCANNING_CUSTOM_ROLE_DESCRIPTION="Wiz Data Scanning Role"
DATA_SCANNING_CUSTOM_ROLE_ACTIONS=(
    "Microsoft.Sql/locations/capabilities/read"
    "Microsoft.Sql/servers/databases/read"
    "Microsoft.Sql/servers/databases/usages/read"
    "Microsoft.Sql/servers/databases/write"
    "Microsoft.Sql/servers/read"
    "Microsoft.Storage/storageAccounts/privateEndpointConnections/read"
    "Microsoft.Storage/storageAccounts/privateEndpointConnections/write"
    "Microsoft.DocumentDB/databaseAccounts/read"
    "Microsoft.DocumentDB/databaseAccounts/readonlykeys/action"
    "Microsoft.Insights/metrics/read"
)
DATA_SCANNING_STANDARD_ROLES=(
    "Storage Blob Data Reader"
    "Storage File Data Privileged Reader"
)
DISK_ANALYZER_CUSTOM_ROLE_DESCRIPTION="Wiz DiskAnalyzer Role"
DISK_ANALYZER_CUSTOM_ROLE_ACTIONS=(
    "Microsoft.authorization/locks/read"
    "Microsoft.Compute/disks/beginGetAccess/action"
    "Microsoft.Compute/disks/read"
    "Microsoft.Compute/galleries/images/versions/read"
    "Microsoft.Compute/snapshots/beginGetAccess/action"
    "Microsoft.Compute/snapshots/delete"
    "Microsoft.Compute/snapshots/endGetAccess/action"
    "Microsoft.Compute/snapshots/read"
    "Microsoft.Compute/snapshots/write"
    "Microsoft.ContainerRegistry/registries/pull/read"
    "Microsoft.Resources/subscriptions/read"
    "Microsoft.KeyVault/vaults/privateEndpointConnections/read"
    "Microsoft.KeyVault/vaults/privateEndpointConnections/write"
)
KEY_VAULT_READER_ROLE="Key Vault Reader"
DOCS_URL="https://docs.wiz.io/docs/azure-req-perm"

declare -A SHADOW_DATA_ROLES=(
    ["Storage Blob Data Contributor"]="@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals 'wiz-inventory-report'"
)
SHADOW_DATA_ACTIONS=(
    "Microsoft.Storage/storageAccounts/inventoryPolicies/write"
    "Microsoft.Storage/storageAccounts/inventoryPolicies/read"
    "Microsoft.Storage/storageAccounts/inventoryPolicies/delete"
)
DOCOPT_PROGRAM_VERSION="${DOCOPT_PROGRAM_VERSION:-2025-10-27T14:57:21+02:00-7aa98d63}"
wiz_azure_deployment_script "$@"

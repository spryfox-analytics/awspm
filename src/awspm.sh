#!/bin/zsh

AWS_CONFIG_FILE_PATH="${HOME}/.aws/config"
ZSH_PROFILE_FILE_PATH="${HOME}/.zprofile"
SEP="TOKENSEPARATOR"
VERSION=0.0.1

function find_aws_accounts_file() {
    aws_accounts_directory_path=$(pwd)
    while [[ "$aws_accounts_directory_path" != "" && ! -e "$aws_accounts_directory_path/.aws_accounts" ]]; do
        aws_accounts_directory_path=${aws_accounts_directory_path%/*}
    done
    if [[ "$aws_accounts_directory_path" != "" ]]; then
        echo "${aws_accounts_directory_path}/.aws_accounts"
    fi
}

function create_aws_accounts_file() {
    default_aws_accounts_file_path="$(pwd)/.aws_accounts"
    aws_accounts_file_path=""
    vared -p "Where do you want to create the .aws_accounts file? It should be located in the project root path. [${default_aws_accounts_file_path}] " -c aws_accounts_file_path
    if [[ "${aws_accounts_file_path}" = "" ]]; then
        aws_accounts_file_path="${default_aws_accounts_file_path}"
    fi
    aws_profile_prefix=""
    vared -p "Please provide the AWS profile prefix (should look like 'customer-name-project-name') [required]: " -c aws_profile_prefix
    if [[ "${aws_profile_prefix}" == "" ]]; then
        echo "AWS profile prefix is required. Exiting."
        exit 1
    fi
    aws_sso_start_url=""
    vared -p "Please provide the AWS SSO start URL (like 'https://d-123456789.awsapps.com/start') [required]: " -c aws_sso_start_url
    if [[ "${aws_sso_start_url}" == "" ]]; then
        echo "AWS SSO start URL is required. Exiting."
        exit 1
    fi
    aws_region=""
    vared -p "Please provide the AWS region (like 'eu-west-1') [required]: " -c aws_region
    if [[ "${aws_region}" == "" ]]; then
        echo "AWS region is required. Exiting."
        exit 1
    fi
    aws_managing_account_number=""
    vared -p "Please provide the AWS managing account number [optional]: " -c aws_managing_account_number
    aws_development_account_number=""
    vared -p "Please provide the AWS development account number [optional]: " -c aws_development_account_number
    aws_integration_account_number=""
    vared -p "Please provide the AWS integration account number [optional]: " -c aws_integration_account_number
    aws_production_account_number=""
    vared -p "Please provide the AWS production account number [optional]: " -c aws_production_account_number
    aws_tool_account_number=""
    vared -p "Please provide the AWS tool account number [optional]: " -c aws_tool_account_number
    configuration=()
    configuration+=("export AWS_PROFILE_PREFIX=${aws_profile_prefix}")
    configuration+=("export AWS_SSO_START_URL=${aws_sso_start_url}")
    configuration+=("export AWS_REGION=${aws_region}")
    configuration+=("export AWS_MANAGING_ACCOUNT_NUMBER=${aws_managing_account_number}")
    configuration+=("export AWS_DEVELOPMENT_ACCOUNT_NUMBER=${aws_development_account_number}")
    configuration+=("export AWS_INTEGRATION_ACCOUNT_NUMBER=${aws_integration_account_number}")
    configuration+=("export AWS_PRODUCTION_ACCOUNT_NUMBER=${aws_production_account_number}")
    configuration+=("export AWS_TOOL_ACCOUNT_NUMBER=${aws_tool_account_number}")
    create_config=""
    echo ""
    echo "The following configuration is about to be added to ${aws_accounts_file_path}:"
    for configuration_part in "${configuration[@]}"; do
        echo $configuration_part
    done
    echo ""
    vared -p "Do you want to create this file at ${aws_accounts_file_path}? [Yn] " -c create_config
    if [[ "${create_config}" = "" || "${create_config}" = "Y" || "${create_config}" = "y" ]]; then
        for configuration_part in "${configuration[@]}"; do
            echo "${configuration_part}" >> "${aws_accounts_file_path}"
        done
        echo "✅ File has been created at ${aws_accounts_file_path}."
    fi
}

function source_aws_accounts_file() {
    aws_accounts_file_path=$(find_aws_accounts_file)
    if [[ "${aws_accounts_file_path}" != "" ]]; then
        source "${aws_accounts_file_path}"
    fi
}

function collect_role_names_from_user() {
    role_names=""
    vared -p "For which role names do your want to create profiles (comma-separated values)? [view,dev,admin] " -c role_names
    if [[ "${role_names}" = "" ]]; then
        role_names="view,dev,admin"
    fi
    echo "${role_names}"
}

function check_if_profile_exists() {
    aws_profile_name=$1
    if grep -q "\[profile ${aws_profile_name}\]" "${AWS_CONFIG_FILE_PATH}"; then
        echo true
    else
        echo false
    fi
}

function build_configuration() {
    aws_profile_name=$1
    aws_sso_start_url=$2
    aws_sso_region=$3
    aws_account_number=$4
    role_name=$5
    aws_region=$6
    conf=" ${SEP}"
    conf+="[profile ${aws_profile_name}]${SEP}"
    conf+="sso_start_url = ${aws_sso_start_url}${SEP}"
    conf+="sso_region = ${aws_sso_region}${SEP}"
    if [[ "${aws_account_number}" != "" ]]; then
        conf+="sso_account_id = ${aws_account_number}${SEP}"
        conf+="sso_role_name = ${role_name}${SEP}"
        conf+="region = ${aws_region}${SEP}"
        conf+="output = json${SEP}"
    fi
    echo $conf
}

function build_missing_configurations() {
    role_names_string=$1
    aws_profile_prefix=$2
    aws_sso_start_url=$3
    aws_region=$4
    missing_configurations=""
    for stage in managing development integration production tool
    do
        aws_account_number="${(P)$(echo "AWS_${stage:u}_ACCOUNT_NUMBER")}"
        if [[ "${aws_account_number}" != "" ]]; then
            login_profile_name="${aws_profile_prefix}-${stage}-login"
            if [[ $(check_if_profile_exists "${login_profile_name}") == false ]]; then
              missing_configurations+=$(build_configuration ${login_profile_name} ${aws_sso_start_url} ${aws_region})
            fi
            role_names=(${(@s:,:)role_names_string})
            for role_name in $role_names
            do
                profile_name="${aws_profile_prefix}-${stage}-${role_name}"
                if [[ $(check_if_profile_exists "${profile_name}") == false ]]; then
                    missing_configurations+=$(build_configuration ${profile_name} ${aws_sso_start_url} ${aws_region} ${aws_account_number} ${role_name} ${aws_region})
                fi
            done
        fi
    done
    echo "${missing_configurations}"
}

function add_configurations() {
    configurations=$1
    if [[ "${configurations}" != "" ]]; then
        configuration_parts=(${(@s:TOKENSEPARATOR:)configurations})
        add_configs=""
        echo ""
        echo "The following configurations are not present in ${AWS_CONFIG_FILE_PATH}:"
        for configuration_part in "${configuration_parts[@]}"; do
            echo $configuration_part
        done
        echo ""
        vared -p "Do you want to add all configurations from above to ${AWS_CONFIG_FILE_PATH}? [Yn] " -c add_configs
        if [[ "${add_configs}" = "" || "${add_configs}" = "Y" || "${add_configs}" = "y" ]]; then
            required_login_profiles=()
            for configuration_part in "${configuration_parts[@]}"; do
                echo "${configuration_part}" >> "${AWS_CONFIG_FILE_PATH}"
                if [[ "${configuration_part}" == *"-login]"* ]]; then
                    required_login_profile=${configuration_part/"[profile "/""}
                    required_login_profile=${required_login_profile/"]"/""}
                    required_login_profiles+=("${required_login_profile}")
                fi
            done
            echo "✅ Added configurations to ${AWS_CONFIG_FILE_PATH}."
            for required_login_profile in "${required_login_profiles[@]}"; do
                echo "❎ Initial login required for ${required_login_profile}."
                aws sso login --profile "${required_login_profile}"
                echo "✅ Executed login for ${required_login_profile}."
            done
        fi
    else
        echo "✅ No configurations to add."
    fi
}

function add_cd_auto_execution() {
    if ! grep -q "function cd" "${ZSH_PROFILE_FILE_PATH}"; then
        run_on_cd=""
        echo ""
        vared -p "Do you want to run role assumption automatically when you enter Terraform stage folders? [Yn] " -c run_on_cd
        if [[ "${run_on_cd}" = "" || "${run_on_cd}" = "Y" || "${run_on_cd}" = "y" ]]; then
            cat <<EOT >> "${ZSH_PROFILE_FILE_PATH}"

function cd {
    builtin cd "\$@"
    if [[ \$(awspm test) == true ]]; then
        export AWS_PROFILE="\$(awspm profile)"
        if aws sts get-caller-identity > /dev/null ; then
            echo "✅ AWS credentials valid for \${AWS_PROFILE}."
        else
            echo "❎ AWS credentials expired for \${AWS_PROFILE}. Refreshing via SSO..."
            aws sso login
            echo "✅ AWS credentials valid for \${AWS_PROFILE}."
        fi
    fi
}
cd \$PWD
EOT
        fi
        echo "✅ Added auto-run configuration to ${ZSH_PROFILE_FILE_PATH}."
        echo "❎ Please run 'source ${ZSH_PROFILE_FILE_PATH}' in all open shells."
    fi
}

function test_if_value_set() {
    parameter_value=$1
    if [[ "${parameter_value}" == "" ]]; then
        echo false
    else
        echo true
    fi
}

function fail_for_empty_variable() {
    parameter_name=$1
    parameter_value=$2
    if [[ $(test_if_value_set "${parameter_value}") == false ]]; then
        echo "Error: Parameter ${parameter_name} not provided." >&2
        exit 1
    fi
}

function init() {
    aws_profile_prefix=$1
    fail_for_empty_variable "aws_profile_prefix" $aws_profile_prefix
    aws_sso_start_url=$2
    fail_for_empty_variable "aws_sso_start_url" $aws_sso_start_url
    aws_region=$3
    fail_for_empty_variable "aws_region" $aws_region
    role_names=$(collect_role_names_from_user)
    missing_configurations=$(build_missing_configurations "${role_names}" "${aws_profile_prefix}" "${aws_sso_start_url}" "${aws_region}")
    add_configurations "${missing_configurations}"
    add_cd_auto_execution
}

function exists_in_list() {
    LIST=$1
    DELIMITER=$2
    VALUE=$3
    [[ "$LIST" =~ ($DELIMITER|^)$VALUE($DELIMITER|$) ]]
}

function derive_profile_name_from_directory() {
    aws_profile_prefix=$1
    role_name=$2
    if [[ "${role_name}" == "" ]]; then
        fail_for_empty_variable "aws_profile_prefix" $aws_profile_prefix
    fi
    directory_name="${PWD##*/}"
    if [[ "${directory_name}" == "mgmt" ]]; then
        directory_name="managing"
    elif [[ "${directory_name}" == "dev" ]]; then
        directory_name="development"
    elif  [[ "${directory_name}" == "int" ]]; then
        directory_name="integration"
    elif  [[ "${directory_name}" == "prod" ]]; then
        directory_name="production"
    fi
    directory_names="managing development integration production tool"
    if exists_in_list "${directory_names}" " " "${directory_name}"; then
        aws_profile_base_name="${aws_profile_prefix}-${directory_name}"
        if [[ "${role_name}" == "" ]]; then
            vared -p "Which role do you want to request for ${aws_profile_base_name}? [view] " -c role_name
            if [[ "${role_name}" == "" ]]; then
                role_name="view"
            fi
        fi
        echo "${aws_profile_base_name}-${role_name}"
    fi
}

if [ "$1" = "init" ]; then
    if [[ "$(find_aws_accounts_file)" == "" ]]; then
        create_aws_accounts_file
    fi
    source_aws_accounts_file
    init "${AWS_PROFILE_PREFIX}" "${AWS_SSO_START_URL}" "${AWS_REGION}"
    exit 0
elif [ "$1" = "profile" ]; then
    source_aws_accounts_file
    echo $(derive_profile_name_from_directory "${AWS_PROFILE_PREFIX}")
    exit 0
elif [ "$1" = "test" ]; then
    source_aws_accounts_file
    if [[ "$(derive_profile_name_from_directory "${AWS_PROFILE_PREFIX}" "login")" != "" && ($(test_if_value_set "${AWS_PROFILE_PREFIX}") == true || $(test_if_value_set "${AWS_SSO_START_URL}") == true || $(test_if_value_set "${AWS_REGION}") == true) ]]; then
        echo true
    else
        echo false
    fi
    exit 0
elif [ "$1" = "version" ]; then
    echo "${VERSION}"
    exit 0
else
    echo ""
    echo "#=================================================================#"
    echo "# AWS Profile Manager ============================================#"
    echo "#=================================================================#"
    echo "Usage:"
    echo "- awspm init             -> Configures the AWS account profiles."
    echo "- awspm profile          -> Derives a profile name for the current folder."
    echo "- awspm test             -> Checks whether a valid .aws_accounts file can be found and the current folder is a Terraform folder."
    echo ""
    exit 0
fi

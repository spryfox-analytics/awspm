#!/bin/zsh

AWS_CONFIG_FILE_PATH="${HOME}/.aws/config"
ZSH_PROFILE_FILE_PATH="${HOME}/.zprofile"
SEP="TOKENSEPARATOR"
VERSION=0.0.1

function source_aws_accounts_file() {
    aws_accounts_directory_path=$(pwd)
    while [[ "$aws_accounts_directory_path" != "" && ! -e "$aws_accounts_directory_path/.aws_accounts" ]]; do
        aws_accounts_directory_path=${aws_accounts_directory_path%/*}
    done
    aws_accounts_file_path="${aws_accounts_directory_path}/.aws_accounts"
    if test -f "${aws_accounts_file_path}"; then
        source "${aws_accounts_file_path}"
    else
        echo "Cannot find .aws_accounts file in this or any parent folder."
        exit 1
    fi
}

function collect_role_names_from_user() {
    role_names=""
    vared -p "For which role names do your want to create profiles (comma-separated values)? [read,write] " -c role_names
    if [[ "${role_names}" = "" ]]; then
        role_names="read,write"
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
    for stage in development integration production tool
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
            echo "Added configurations to ${AWS_CONFIG_FILE_PATH}."
            for required_login_profile in "${required_login_profiles[@]}"; do
                echo "Enforcing initial login for ${required_login_profile}."
                aws sso login --profile "${required_login_profile}"
            done
        fi
    else
        echo "No configurations to add."
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
    awspm set
}
cd \$PWD
EOT
            source "${ZSH_PROFILE_FILE_PATH}"
        fi
    fi
}

function init() {
    aws_profile_prefix=$1
    aws_sso_start_url=$2
    aws_region=$3
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
    directory_name="${PWD##*/}"
    if [[ "${directory_name}" == "dev" ]]; then
        directory_name="development"
    elif  [[ "${directory_name}" == "int" ]]; then
        directory_name="integration"
    elif  [[ "${directory_name}" == "prod" ]]; then
        directory_name="production"
    fi
    directory_names="development integration production tool"
    if exists_in_list "${directory_names}" " " "${directory_name}"; then
        vared -p "Which role do you want to request for ${aws_profile_name}? [read] " -c role_name
        aws_profile_name="${aws_profile_prefix}-${directory_name}-${role_name}"
        echo "${aws_profile_name}"
    fi
}

function load_profile() {
    aws_profile_name=$1
    unset AWS_PROFILE
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    export AWS_PROFILE="${aws_profile_name}"
    echo "Loaded profile ${aws_profile_name}."
}

source_aws_accounts_file
if [ "$1" = "init" ]; then
    init "${AWS_PROFILE_PREFIX}" "${AWS_SSO_START_URL}" "${AWS_REGION}"
elif [ "$1" = "set" ]; then
    if [ $# -gt 3 ]; then
        echo "Too many arguments."
        exit 1
    fi
    if [ $# -lt 3 ]; then
        stage=$(derive_profile_name_from_directory "${AWS_PROFILE_PREFIX}")
        if [[ "${stage}" != "" ]]; then
            load_profile "${stage}"
            exit 0
        fi
    fi
    if [[ "$2" = "-p" || "$2" = "--profile" ]]; then
        load_profile $3
        exit 0
    else
        echo "Unknown argument $2"
        exit 1
    fi
elif [ "$1" = "version" ]; then
    echo "${VERSION}"
else
    echo ""
    echo "==================================================================="
    echo "AWS Profile Manager"
    echo "==================================================================="
    echo "Usage:"
    echo "- awspm init                -> Configures the AWS account profiles."
    echo "- awspm set                 -> Loads profile for current folder."
    echo "- awspm set -p PROFILE_NAME -> Loads profile with given name."
    echo ""
fi

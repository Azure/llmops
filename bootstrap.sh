#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 01. Setup and Preparation
echo -e "${YELLOW}01. Setup and Preparation.${NC}"

# Define the temporary directory within the current directory
current_dir=$(pwd)
temp_dir="$current_dir/temp"

# Create the temporary directory
rm -rf "$temp_dir"
mkdir -p "$temp_dir"

# Ensure the temporary directory is removed on script exit
trap "rm -rf $temp_dir" EXIT

# Change to the temporary directory
cd "$temp_dir"

# Read the variables from the bootstrap.properties file
if [ -f ../bootstrap.properties ]; then
    source ../bootstrap.properties
else
    echo -e "${RED}bootstrap.properties does not exist.${NC}"
    exit 1
fi

# Setup additional variables
if [ "$github_use_ssh" = "true" ]; then
    github_template_repo_uri="git@github.com:${github_template_repo}.git"
else
    github_template_repo_uri="https://github.com/${github_template_repo}.git"
fi
if [ "$github_use_ssh" = "true" ]; then
    github_new_repo_uri="git@github.com:${github_new_repo}.git"
else
    github_new_repo_uri="https://github.com/${github_new_repo}.git"
fi
github_new_repo_name=${github_new_repo##*/}
github_template_repo_name=${github_template_repo##*/}

echo -e "\e[33mBootstraping Parameters\e[0m"
echo -e "\e[36mGitHub Username:\e[0m $github_username"
echo -e "\e[36mGitHub Use SSH:\e[0m $github_use_ssh"
echo -e "\e[36mGitHub Template Repo:\e[0m $github_template_repo"
echo -e "\e[36mGitHub Template Repo name:\e[0m $github_template_repo_name"
echo -e "\e[36mGitHub Template Repo URI:\e[0m $github_template_repo_uri"
echo -e "\e[36mGitHub New Repo:\e[0m $github_new_repo"
echo -e "\e[36mGitHub New Repo name:\e[0m $github_new_repo_name"
echo -e "\e[36mGitHub New Repo URI:\e[0m $github_new_repo_uri"
echo -e "\e[36mGitHub New Repo Visibility:\e[0m $github_new_repo_visibility"
echo -e "\e[36mAZD Dev Environment Provision:\e[0m $azd_dev_env_provision"
echo -e "\e[36mAZD Dev Environment Name:\e[0m $azd_dev_env_name"
echo -e "\e[36mAZD Dev Environment Subscription:\e[0m $azd_dev_env_subscription"
echo -e "\e[36mAZD Dev Environment Location:\e[0m $azd_dev_env_location"


# 02. Repository Creation and Initialization
echo -e "${YELLOW}02. New GitHub Repository Creation and Initialization.${NC}"

# Remove the existing local folder if it exists
if [ -d "$new_project_repo" ]; then
    rm -rf "$new_project_repo"
fi

# Check if the repository already exists
repo_exists=$(gh repo view "$github_new_repo" > /dev/null 2>&1; echo $?)

if [ $repo_exists -ne 0 ]; then
    # Create a new GitHub repository
    echo -e "${YELLOW}Creating a new GitHub repository.${NC}"
    gh repo create "$github_new_repo" --$github_new_repo_visibility
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create new GitHub repository.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}New GitHub repository already exists.${NC}"
fi

# Clone the template repository
echo -e "${YELLOW}Cloning template repository.${NC}"
git clone --bare "$github_template_repo_uri"
cd $github_template_repo_name.git

# Mirror-push to the new repository
git push --mirror "$github_new_repo_uri"
cd ..
rm -rf $template_project_repo_name.git

# Setting default branch
echo -e "${YELLOW}Setting default branch in the new repository.${NC}"
gh repo edit $github_new_repo --default-branch develop

echo -e "${GREEN}New repository created successfully.${NC}"

if [ "$azd_dev_env_provision" = "true" ]; then

    # 03. Initializing AZD dev environment
    echo -e "${YELLOW}03. Initializing AZD dev environment.${NC}"

    # Clone the new repository
    echo -e "${YELLOW}Cloning the new GitHub repository.${NC}"
    git clone "$github_new_repo_uri"
    cd "$github_new_repo_name" 

    # Initialize the azd environment
    echo -e "${YELLOW}Running azd init.${NC}"
    azd init -e "$azd_dev_env_name" -s "$azd_dev_env_subscription" -l "$azd_dev_env_location"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to initialize the Azure Developer environment.${NC}"
        exit 1
    fi

    # 04. Provision dev environment resources
    echo -e "${YELLOW}04. Provision dev environment resources.${NC}"
    echo -e "${YELLOW}Running azd provision.${NC}"
    azd provision

    # Check if azd provision succeeded
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to provision the Azure environment.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Dev environment provisioned successfully.${NC}"
else
    echo -e "${YELLOW}AZD dev environment provisioning was not selected.${NC}"
fi
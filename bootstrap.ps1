# 01. Setup and Preparation
Write-Host "`n01. Setup and Preparation." -ForegroundColor Magenta

# Define the temporary directory within the current directory
$currentDir = Get-Location
$tempDir = Join-Path $currentDir "temp"

# Create the temporary directory
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tempDir

# Change to the temporary directory
Set-Location $tempDir

# Read the variables from the bootstrap.properties file
$bootstrapFile = "C:\Users\paulo\Downloads\test\bootstrap.properties"
if (Test-Path $bootstrapFile) {
    Get-Content $bootstrapFile | ForEach-Object {
        # Ignore comments and empty lines
        if ($_ -notmatch '^\s*#' -and $_.Trim() -ne '') {
            # Split the line into name and value
            $parts = $_ -split '=', 2
            $name = $parts[0].Trim()
            $value = $parts[1].Trim().Trim('"')
            # Create a PowerShell variable with the name and value
            Set-Variable -Name $name -Value $value
            # Print the variable name in Cyan 
            Write-Host "$name = " -NoNewline -ForegroundColor Blue
            Write-Host $value 
        }
    }
} else {
    Write-Host "bootstrap.properties does not exist." -ForegroundColor Red
    exit 1
}

# Setup additional variables
if ($github_use_ssh -eq "true") {
    $github_template_repo_uri = "git@github.com:${github_template_repo}.git"
} else {
    $github_template_repo_uri = "https://github.com/${github_template_repo}.git"
}
if ($github_use_ssh -eq "true") {
    $github_new_repo_uri = "git@github.com:${github_new_repo}.git"
} else {
    $github_new_repo_uri = "https://github.com/${github_new_repo}.git"
}
$github_new_repo_name = $github_new_repo -split '/' | Select-Object -Last 1
$github_template_repo_name = $github_template_repo -split '/' | Select-Object -Last 1
# Print the new additional 
Write-Host "github_template_repo_name = " -NoNewline -ForegroundColor Blue
Write-Host $github_template_repo_name  
Write-Host "github_template_repo_uri = " -NoNewline -ForegroundColor Blue
Write-Host $github_template_repo_uri 
Write-Host "github_new_repo_name = " -NoNewline -ForegroundColor Blue
Write-Host $github_new_repo_name 
Write-Host "github_new_repo_uri = " -NoNewline -ForegroundColor Blue
Write-Host $github_new_repo_uri 

Write-Host "`nFinished Setup and Preparation." -ForegroundColor Green

# 02. Repository Creation and Initialization
Write-Host "`n02. New GitHub Repository Creation and Initialization.`n" -ForegroundColor Magenta

# Check if the GitHub repository exists
$repoExists = $false
$repoCheck = gh repo view "$github_new_repo_uri" 2>&1
if ($LASTEXITCODE -eq 0) {
    $repoExists = $true
    Write-Host "GitHub repository $github_new_repo_uri already exists." -ForegroundColor Cyan
} else {
    if ($repoCheck -like "*gh auth login*") {
        Write-Host "Error: User is not logged in. Please log in using gh auth login." -ForegroundColor Red
    } elseif ($repoCheck -like "*Could not resolve to a Repository with the name*") {
        Write-Host "GitHub repository $github_new_repo_uri does not exist." -ForegroundColor Yellow
    } else {
        Write-Host "Error checking the repository: $repoCheck" -ForegroundColor Red
    }
}

if (-not $repoExists) {
    # Create a new GitHub repository
    Write-Host "Creating a new GitHub repository."
    gh repo create "$github_new_repo" --$github_new_repo_visibility
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create new GitHub repository."
        exit 1
    }
}

# Copying template repo in the new repository
Write-Host "Cloning template repository." -ForegroundColor Cyan
git clone --bare "$github_template_repo_uri"
Set-Location "$github_template_repo_name.git"
Write-Host "Mirroring template repository in the new GitHub repository." -ForegroundColor Cyan
git push --mirror "$github_new_repo_uri"
Write-Host "Setting default branch in the new repository." -ForegroundColor Cyan
gh repo edit $github_new_repo --default-branch develop
Set-Location ..
Remove-Item -Recurse -Force "$github_template_repo_name.git"

Write-Host "`nNew repository set up successfully." -ForegroundColor Green

if ($azd_dev_env_provision -eq "true") {

    # 03. Initializing AZD dev environment
    Write-Host "`n03. Initializing AZD dev environment.`n" -ForegroundColor Magenta

    # Clone the new repository
    Write-Host "Cloning the new GitHub repository." -ForegroundColor Cyan
    git clone "$github_new_repo_uri"
    Set-Location "$github_new_repo_name"

    # Initialize the azd environment
    Write-Host "Running azd init." -ForegroundColor Cyan
    azd init -e $azd_dev_env_name -s $azd_dev_env_subscription -l $azd_dev_env_location
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to initialize the Azure Developer environment." -ForegroundColor Red
        exit 1
    }

    # 04. Check if user logged in to Azure is Service Principal or not
    $azd_user_type = (az account show --query user.type -o tsv)
    
    if ($azd_user_type -eq "servicePrincipal") {
        Write-Host "User is a Service Principal. Setting AZURE_PRINCIPAL_TYPE to ServicePrincipal." -ForegroundColor Green
        azd env set AZURE_PRINCIPAL_TYPE ServicePrincipal
    } else {
        Write-Host "User is not a Service Principal. Setting AZURE_PRINCIPAL_TYPE to User." -ForegroundColor Green
        azd env set AZURE_PRINCIPAL_TYPE User
    }
    
    # 05. Show azd environment variables
    Write-Host "`n05. Show azd environment variables.`n" -ForegroundColor Magenta
    azd env get-values
    
    # 06. Provision dev environment resources
    Write-Host "`n06. Provision dev environment.`n" -ForegroundColor Magenta
    Write-Host "Running azd provision." -ForegroundColor Cyan
    azd provision

    # Check if azd provision succeeded
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to provision the Azure environment." -ForegroundColor Red
        exit 1
    }

    Write-Host "`nDev environment provisioned successfully." -ForegroundColor Green

} else {
    Write-Host "`nDev environment provisioning was not selected." -ForegroundColor Yellow
}

# Change back to the original directory
Set-Location $currentDir

# Remove the temporary directory
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Host "`nTemporary directory removed successfully." -ForegroundColor Cyan
# ==============================================================================
# DocumentDB Password Setup Script
# ==============================================================================
# Run this ONCE per environment BEFORE running terraform apply
# This creates the master password secret that DocumentDB will use
# ==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "btg",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

$secretName = "docdb/$ProjectName-$Environment/master-password"

Write-Host "Creating DocumentDB master password secret for $Environment environment..." -ForegroundColor Cyan

# Generate a secure random password
Add-Type -AssemblyName System.Web
$password = [System.Web.Security.Membership]::GeneratePassword(32, 10)

# Create the secret in AWS Secrets Manager
$secretValue = @{
    password = $password
} | ConvertTo-Json

try {
    # Check if secret already exists
    $existingSecret = aws secretsmanager describe-secret --secret-id $secretName --region $Region 2>$null
    
    if ($existingSecret) {
        Write-Host "Secret '$secretName' already exists!" -ForegroundColor Yellow
        $overwrite = Read-Host "Do you want to update it? (yes/no)"
        
        if ($overwrite -ne "yes") {
            Write-Host "Aborted. Using existing secret." -ForegroundColor Green
            exit 0
        }
        
        # Update existing secret
        aws secretsmanager put-secret-value `
            --secret-id $secretName `
            --secret-string $secretValue `
            --region $Region
        
        Write-Host "Secret updated successfully!" -ForegroundColor Green
    }
    else {
        # Create new secret
        aws secretsmanager create-secret `
            --name $secretName `
            --description "DocumentDB master password for $Environment" `
            --secret-string $secretValue `
            --region $Region
        
        Write-Host "Secret created successfully!" -ForegroundColor Green
    }
    
    Write-Host "`nSecret Details:" -ForegroundColor Cyan
    Write-Host "  Name: $secretName"
    Write-Host "  Region: $Region"
    Write-Host "  Password: [HIDDEN - stored in AWS Secrets Manager]"
    Write-Host "`nIMPORTANT: The password is now stored securely in AWS Secrets Manager." -ForegroundColor Yellow
    Write-Host "It will NOT appear in Terraform state files." -ForegroundColor Yellow
}
catch {
    Write-Host "Error creating secret: $_" -ForegroundColor Red
    exit 1
}

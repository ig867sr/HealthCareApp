[CmdletBinding()]
param(
    [string]$StackName = 'healthcareapp-docs',
    [string]$Profile = 'ScottAdmin',
    [string]$Region = 'us-east-1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Region -ne 'us-east-1') {
    throw 'Deploy this stack in us-east-1; CloudFront requires its ACM certificate in that region.'
}

$aws = Get-Command aws -ErrorAction SilentlyContinue
if (-not $aws) {
    throw 'AWS CLI was not found. Install AWS CLI v2 and try again.'
}

$sitePath = Join-Path $PSScriptRoot 'website\index.html'
$templatePath = Join-Path $PSScriptRoot 'infrastructure\template.yaml'
foreach ($path in @($sitePath, $templatePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required deployment file not found: $path"
    }
}

$identityOutput = & aws sts get-caller-identity --profile $Profile --region $Region --output json
if ($LASTEXITCODE -ne 0) {
    throw "Could not verify AWS identity with profile '$Profile'. Run 'aws sso login --profile $Profile' and retry."
}
$identity = $identityOutput | ConvertFrom-Json
Write-Host "Deploying as AWS account $($identity.Account)"

& aws cloudformation deploy `
    --template-file $templatePath `
    --stack-name $StackName `
    --region $Region `
    --profile $Profile
if ($LASTEXITCODE -ne 0) {
    throw "CloudFormation deployment failed for stack '$StackName'."
}

$stack = & aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --profile $Profile `
    --query 'Stacks[0].Outputs' `
    --output json
if ($LASTEXITCODE -ne 0) {
    throw "Could not read outputs for stack '$StackName'."
}
$outputs = $stack | ConvertFrom-Json
$bucketName = ($outputs | Where-Object OutputKey -eq 'WebsiteBucketName').OutputValue
$distributionId = ($outputs | Where-Object OutputKey -eq 'CloudFrontDistributionId').OutputValue
$websiteUrl = ($outputs | Where-Object OutputKey -eq 'WebsiteUrl').OutputValue
if (-not $bucketName -or -not $distributionId -or -not $websiteUrl) {
    throw "CloudFormation stack '$StackName' did not return all expected outputs."
}

& aws s3 cp $sitePath "s3://$bucketName/index.html" `
    --content-type 'text/html; charset=utf-8' `
    --cache-control 'no-cache' `
    --profile $Profile `
    --region $Region
if ($LASTEXITCODE -ne 0) {
    throw "Could not upload the documentation page to bucket '$bucketName'."
}

$invalidation = & aws cloudfront create-invalidation `
    --distribution-id $distributionId `
    --paths '/' '/index.html' `
    --profile $Profile `
    --output json
if ($LASTEXITCODE -ne 0) {
    throw "Could not invalidate CloudFront distribution '$distributionId'."
}
$invalidationResult = $invalidation | ConvertFrom-Json
Write-Host "Documentation site deployed: $websiteUrl"
Write-Host "CloudFront invalidation: $($invalidationResult.Invalidation.Id) ($($invalidationResult.Invalidation.Status))"

# Personal Health Record Assistant

Public documentation site for a personal-use healthcare data project. The site
is hosted on Amazon S3 behind CloudFront and uses an ACM certificate with DNS
validation through Route 53.

## What the app is

The Personal Health Record Assistant is a development-stage project intended
to help an individual organize and understand health information they choose
to access through a healthcare provider's patient-authorized FHIR connection.
It is not a clinical system, and it does not diagnose, treat, or replace advice
from a qualified healthcare professional.

The application is not yet connected to Stanford Health Care production data.
Development and initial testing use synthetic data in the Epic FHIR sandbox.
Production access, if pursued, will require the user's explicit authorization
through Stanford MyHealth and any required Epic or Stanford review.

## Data and privacy

- The app does not ask users to give it their MyHealth password.
- No real patient records are collected by this documentation site.
- Sandbox testing uses synthetic data only.
- Before any production health-data connection is enabled, the app's data
  handling, storage, retention, and any use of AI services must be disclosed
  and reviewed. No real health information should be entered into this
  prototype until those safeguards are in place.
- The app is for personal information access and education, not emergency use
  or medical decision-making.

## Epic FHIR R4 sandbox test

The browser-based sandbox client uses SMART App Launch v2 authorization code
flow with PKCE. It is configured with the MyHealthDataA nonproduction client ID
only (`2e4afc0c-110a-44d0-85dd-0c85affcb4e2`) and uses Epic's public
synthetic-data sandbox:

```text
FHIR base:    https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4
Callback URI: https://d3ol4u5hnfhodl.cloudfront.net/oauth/callback.html
Test page:    https://d3ol4u5hnfhodl.cloudfront.net/oauth/index.html
```

Register the callback URI exactly in the Epic **nonproduction** app. The test
page redirects the user to Epic's sandbox authorization server; after consent,
the callback exchanges the one-time authorization code using PKCE, reads the
synthetic Patient resource, then searches DiagnosticReport and laboratory
Observation resources. Results are displayed only in the browser. OAuth
tokens are held in memory only, never displayed, logged, or written to
persistent browser storage. No client secret is used. The nonproduction app
must include Patient.Read, DiagnosticReport.Search, and Observation.Search.

Do not use the production client ID or connect Stanford records with this
sandbox page. Stanford production SMART endpoints, registration, and approval
must be confirmed separately before any real patient data is accessed.

## Deploy the documentation site

Requirements: AWS CLI v2 and an authenticated AWS SSO profile. The site uses
the default CloudFront HTTPS hostname, so no custom-domain DNS access or ACM
certificate is needed.

```powershell
aws sso login --profile ScottAdmin
.\deploy.ps1
```

The CloudFormation template creates a private S3 bucket and CloudFront
distribution with Origin Access Control. The script uploads the static page and
invalidates CloudFront's cache. When custom DNS access is available later, the
distribution can be updated with `epic.trescott.org` and a DNS-validated ACM
certificate.

```powershell
aws cloudformation deploy `
  --template-file .\infrastructure\template.yaml `
  --stack-name healthcareapp-docs `
  --region us-east-1
```

## Project layout

- `website/index.html` — public app documentation
- `infrastructure/template.yaml` — S3, CloudFront, ACM, and Route 53 resources
- `deploy.ps1` — deploy infrastructure and publish the page

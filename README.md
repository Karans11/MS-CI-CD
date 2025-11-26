# Fake Banking Demo Lab

Intentionally vulnerable CNAPP demo environment showcasing insecure practices across IDE, source control, CI/CD, Terraform IaC, AKS runtime, and Azure services.

## Repository Layout

- `app/` – Fake Banking Spring Boot web app with hard-coded secrets, weak auth, exposed admin endpoints, and storage-backed PII viewer.
- `iac/` – Terraform provisioning insecure Azure resources (AKS, public storage with PII, ACR, Key Vault) and deploying the app with privileged Kubernetes settings.
- `pipelines/` – Azure DevOps YAML pipelines for Terraform and application delivery that leak secrets, skip validation, and deploy unscanned images.
- `scripts/` – `deploy_lab.sh` and `destroy_lab.sh` for one-click lab provisioning/teardown using hard-coded service principal credentials.
- `docs/` – Reserved for additional walkthrough notes.

## Key Insecurities to Highlight

- **Secrets & PII**
  - `app/.env`, `app/src/main/java/.../config/InsecureConfig.java`, and `app/src/main/resources/application.properties` contain exposed Azure credentials, DB passwords, and webhook URLs.
  - `iac/data/customer-data.json` uploads Aadhaar, PAN, and driving licence data to a publicly accessible blob.
  - Pipelines reference service principal secrets directly in YAML variables.

- **Application Layer**
  - Login controller bypasses Spring Security, uses plain-text credentials, and exposes `/admin` & `/api/pii` without auth.
  - `/transfer` endpoint is vulnerable to SQL injection.
  - Docker image runs as root and exposes port 80 with no TLS.

- **Terraform / Azure**
  - Storage allows public access, HTTP traffic, and TLS 1.0.
  - AKS cluster disables RBAC, enables dashboard, exposes API to the internet, and grants `Owner` role to workload identity.
  - Key Vault lacks soft delete, purge protection, and network restrictions.
  - Kubernetes deployment runs privileged containers and injects storage keys as env vars.

- **CI/CD**
  - Pipelines download tooling over unsecured channels, skip tests, use admin logins for ACR, and apply manifests without validation.
  - Service principal secrets live in plain text and terraform state is local-only.

These weaknesses should surface at IDE (secret scanning), repo (SAST, IaC lint), pipeline (credential usage), and runtime (AKS/Storage) when evaluated with a CNAPP platform.

## Deployment & Destroy Scripts

`scripts/deploy_lab.sh` and `scripts/destroy_lab.sh` require the Azure CLI with the Azure DevOps extension installed.

1. Export/replace the placeholders before running:
   - `AZ_SUBSCRIPTION_ID`
   - `AZ_TENANT_ID`
   - `AZ_CLIENT_ID`
   - `AZ_CLIENT_SECRET`
   - `AZ_DEVOPS_ORG` (e.g. `https://dev.azure.com/contoso`)
   - `AZ_DEVOPS_PROJECT`
   - `AZ_DEVOPS_PIPELINE_APP` (name of `pipelines/app-pipeline.yml` once imported)
   - `AZ_DEVOPS_PIPELINE_IAC` (name of `pipelines/terraform-pipeline.yml`)
   - `AZ_DEVOPS_PAT` (personal access token with pipeline execute permissions)

2. Run `./scripts/deploy_lab.sh` to:
   - Log in with the hard-coded service principal.
   - Apply Terraform from `iac/` (public storage + AKS cluster).
   - Queue Azure DevOps pipelines for IaC and application deployment.

3. Run `./scripts/destroy_lab.sh` to tear down Terraform-managed resources. Manually remove residual artifacts (resource group, ACR images) if needed.

## Azure DevOps Setup

1. Create a new project named `FakeBanking` (or update the placeholders to match your naming).
2. Import this repository and create two pipelines:
   - **FakeBanking-IaC**: point to `pipelines/terraform-pipeline.yml`.
   - **FakeBanking-App**: point to `pipelines/app-pipeline.yml`.
3. Configure pipeline variables only if you want to override the intentionally hard-coded defaults.
4. Ensure a service connection is **not** used (pipelines leverage plain-text service principal credentials per the demo scenario).

## Terraform Credentials

Terraform expects Azure service principal credentials from `variables.tf` defaults or via `TF_VAR_*` environment variables. For production, never commit these values—here they remain hard-coded intentionally for CNAPP detection.

## Demo Workflow

1. Clone repo and open in VS Code – validate IDE secret scanning / SAST detections.
2. Commit/push to trigger pipelines – CNAPP should detect exposed secrets in Git history.
3. Terraform pipeline provisions AKS + storage – observe IaC misconfiguration findings.
4. App pipeline builds/pushes root Docker image and deploys to AKS – verify runtime/Kubernetes posture alerts.
5. Visit the service’s public endpoint to demonstrate exposed `/admin` and `/api/pii` routes leaking sensitive customer data.

## Cleanup

Use `./scripts/destroy_lab.sh` or manually delete the resource group (`fakebanking-rg`) if Terraform destroy fails. Remember to revoke the demo service principal and rotate secrets after the lab if they were ever real values.

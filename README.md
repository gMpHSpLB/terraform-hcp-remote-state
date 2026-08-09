# terraform-hcp-remote-state
Remote State with HCP Terraform




# TF-01: Remote State with HCP Terraform (No AWS Costs)

Goal: take your existing local‑backend Terraform fundamentals project and:

- Move state from local `terraform.tfstate` to HCP Terraform (remote backend).
- Keep using your CLI + Make targets (CLI-driven workflow).
- Get remote state, locking, and a taste of remote runs / GitHub integration.

No AWS infra is required for this demo; you can keep using `random` + `local` providers or any zero-cost resources.

---

## 1. Set up HCP Terraform account and CLI auth

### 1.1. Create account and organization

1. Go to: `https://app.terraform.io` (HCP Terraform UI).[web:83]
2. Sign up / log in.
3. Create an **organization** (e.g., `hcrmapp-platform-lab`).

Free tier notes:

- Enhanced Free tier includes:
  - Remote state storage.
  - Remote runs.
  - VCS integration.
  - Up to **500 managed resources** at no cost.[web:87]

### 1.2. Log in from Terraform CLI

From your WSL terminal:

```bash
terraform login
```

- Terraform opens a browser or gives you a URL to paste.
- Authorize the CLI and generate an API token.
- The token is saved to `~/.terraform.d/credentials.tfrc.json`.[web:89][web:92]

This is what lets your local `terraform` binary talk to HCP Terraform securely.

---

## 2. Create a workspace for your root module

You want **one HCP Terraform workspace per root module** (per `environments/<env>` directory).[web:86][web:92]

For your dev environment:

1. In HCP Terraform UI:
   - Go to your org.
   - Click **New** → **Workspace**.
   - Choose **CLI-driven workflow** (not VCS-driven yet).[web:91][web:92]
   - Name it, e.g.: `tf01-fundamentals-dev`.

2. Note the workspace name and organization name; you’ll use them in the backend config.

This workspace will hold:

- Remote state for `environments/dev`.
- Runs history if you later use remote execution.

---

## 3. Switch backend from local to HCP Terraform (`cloud` block)

Right now your dev backend is local (implicit):

```hcl
# environments/dev/backend.tf
terraform {
  # local backend by default
}
```

Update it to use the HCP Terraform backend (`cloud` block):

```hcl
# environments/dev/backend.tf
terraform {
  cloud {
    organization = "hcrmapp-platform-lab"    # your org name

    workspaces {
      name = "tf01-fundamentals-dev"        # your dev workspace name
    }
  }
}
```

Key points:[web:92]

- `terraform { cloud { ... } }` tells Terraform:
  - “Use HCP Terraform as the backend for state and runs for this root module.”
- Each `environments/<env>` dir should eventually have its own workspace, but you can start with `dev` only.

---

## 4. Update Make targets (minimal changes)

Your existing targets already `cd` into `environments/dev` and run `terraform init/plan/apply`. With the `cloud` block added, those commands now:

- Initialize with remote backend.
- Store state remotely.
- Optionally run applies remotely if you choose remote execution.

You can keep your existing targets; just be aware they now talk to the cloud backend.

Example (already in your workflow):

```make
TF_ENV ?= dev
TF_DIR := environments/$(TF_ENV)

.PHONY: tf-init
tf-init:
	cd $(TF_DIR) && terraform init

.PHONY: tf-plan
tf-plan:
	cd $(TF_DIR) && terraform plan -var-file=terraform.tfvars

.PHONY: tf-apply
tf-apply:
	cd $(TF_DIR) && terraform apply -var-file=terraform.tfvars
```

No change needed here; the backend switch is entirely in `backend.tf`.

---

## 5. Migrate existing local state to HCP Terraform

You already have `terraform.tfstate` locally from your fundamentals work. When you run `terraform init` after adding the `cloud` block, Terraform will:

- Detect the backend change.
- Prompt to **migrate state** from local to HCP Terraform.[web:92]

From `platform-infra`:

```bash
make tf-init TF_ENV=dev
```

You’ll see something like:

- “Terraform has detected that the backend configuration has changed…”
- “Do you want to migrate state?” → answer `yes`.

After that:

- Local `environments/dev/terraform.tfstate` is no longer used.
- State lives in HCP Terraform under your `tf01-fundamentals-dev` workspace.[web:86]

---

## 6. Run plan/apply with remote state

From now on:

```bash
make tf-plan TF_ENV=dev
make tf-apply TF_ENV=dev
```

Results:

- **State** is stored in HCP Terraform (remote, locked).[web:83][web:86]
- Your CLI still triggers runs; by default:
  - `plan` executes locally but writes/reads state remotely.
  - You can opt into remote execution later if you want HCP Terraform to run plans/applies on its side.[web:91]

You can also:

- View state in the HCP Terraform UI (State tab on the workspace).
- Inspect runs history there, even if you triggered them from CLI.

---

## 7. Optional Make targets: open HCP workspace or show backend type

You can add small convenience targets.

**Show backend type (confirm remote)**:

```make
.PHONY: tf-backend-info
tf-backend-info: ## Show Terraform backend configuration for the selected environment.
	cd $(TF_DIR) && terraform providers
	@printf '$(CYAN)%s$(RESET)\n' "Check environments/$(TF_ENV)/backend.tf for cloud backend settings."
```

Or a simple echo:

```make
.PHONY: tf-backend-summary
tf-backend-summary: ## Print current backend summary for the selected environment.
	@printf '$(CYAN)%s$(RESET)\n' "Backend for $(TF_ENV) is configured in environments/$(TF_ENV)/backend.tf:"
	cat environments/$(TF_ENV)/backend.tf
```

This helps you mentally confirm “dev is now using cloud backend, not local”.

---

## 8. Why this is safe and cost‑friendly for you

- HCP Terraform’s free tier:
  - No S3 or DynamoDB costs.
  - No EC2/EKS costs unless *you* choose to create AWS resources (you’re not doing that here).[web:83][web:90]
- You’re only using:
  - Remote state storage.
  - Locking.
  - Optional remote runs.
- Your resources can stay zero‑cost (`random`, `local`, maybe `kubernetes` against kind/minikube), so your only “cloud” is HCP Terraform itself.

---

## 9. High-level mental model

You’ve now:

- Learned **local backend** (state file next to config).
- Moved to **remote backend with HCP Terraform**:
  - Same HCL, same Make targets.
  - State and runs moved to a managed service.
- This sets you up perfectly for:
  - Later EKS work (remote state already in place).
  - GitHub integration (HCP Terraform watching your repo, running plans on PRs).[web:88][web:91]

---
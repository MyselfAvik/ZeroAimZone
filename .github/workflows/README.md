# Microsoft Teams Commit Notification Setup

This guide explains how to configure GitHub Actions to send a Microsoft Teams notification whenever code is pushed to selected branches.

## Overview

This workflow sends an Adaptive Card to a Microsoft Teams channel whenever a commit is pushed to the configured branches.

**Current workflow triggers:**

- `main`
- `Feature/**`

Example:

- `Feature/login`
- `Feature/firebase-auth`
- `Feature/game-center`

---

# Prerequisites

Before starting, you should have:

- A GitHub repository
- Repository Admin access
- A Microsoft Teams Team and Channel
- Permission to add Workflows/Connectors to the Teams channel

---

# Step 1: Create the GitHub Workflow

Inside your repository, create the following directory if it doesn't already exist:

```
.github/
└── workflows/
```

Create a file named:

```
.github/workflows/ms-teams.cicd.yml
```

Paste the workflow YAML into this file.

Commit and push it.

---

# Step 2: Create a Microsoft Teams Incoming Webhook

Open Microsoft Teams.

Go to the channel where you want notifications.

Example:

```
Development
 └── CI/CD Notifications
```

Click

```
...
(Manage channel / Connectors / Workflows depending on your Teams version)
```

Then create an **Incoming Webhook**.

Give it a name such as:

```
GitHub Notifications
```

(Optional) Upload an icon.

Click

```
Create
```

Microsoft Teams will generate a webhook URL similar to:

```
https://xxxxx.webhook.office.com/webhookb2/...
```

Copy this URL.

Keep it secure.

---

# Step 3: Add the Webhook URL to GitHub Secrets

Open your GitHub repository.

Navigate to:

```
Settings
    ↓
Secrets and variables
    ↓
Actions
```

Click

```
New repository secret
```

Create the following secret:

| Name | Value |
|------|-------|
| `TEAMS_WEBHOOK_URL` | Your Microsoft Teams Incoming Webhook URL |

Click

```
Add secret
```

---

# Step 4: Verify the Workflow

Your repository should now contain:

```
.github
└── workflows
    └── ms-teams.cicd.yml
```

And your repository secrets should contain:

```
TEAMS_WEBHOOK_URL
```

---

# Step 5: Push a Commit

Push a commit to one of the configured branches.

Example:

```
git checkout Feature/test

git add .

git commit -m "Added Firebase authentication"

git push
```

or

```
git push origin main
```

---

# Step 6: View the Notification

A message similar to the following will appear in Microsoft Teams.

```
New Commit Notification

Author:
Bruce Wayne

Message:
Added Firebase authentication

Branch:
Feature/test

SHA:
e4d1e18

[View Commit]
```

Click **View Commit** to open the commit on GitHub.

---

# Branch Configuration

The workflow currently listens for pushes to:

```yaml
on:
  push:
    branches:
      - main
      - Feature/**
```

## Triggered

```
main
Feature/login
Feature/firebase
Feature/auth/google
Feature/gameplay/ui
```

## Not Triggered

```
develop
release
hotfix
bugfix
feature/login   (lowercase "feature")
```

Branch matching is case-sensitive.

---

# Changing the Branches

To monitor additional branches, edit:

```yaml
on:
  push:
    branches:
      - main
      - develop
      - release/**
      - hotfix/**
      - Feature/**
```

Examples:

```
release/v1.0
release/v2.1

hotfix/login

develop
```

---

# Workflow Information

The workflow automatically includes:

| Field | Description |
|---------|------------|
| Author | GitHub username who pushed the commit |
| Commit Message | Latest commit message |
| Branch | Branch name |
| SHA | Commit SHA |
| View Commit | Direct link to the commit |

---

# GitHub Variables Used

The workflow uses the following GitHub context variables:

| Variable | Description |
|----------|-------------|
| `${{ github.actor }}` | User who pushed |
| `${{ github.ref_name }}` | Branch name |
| `${{ github.sha }}` | Commit SHA |
| `${{ github.event.head_commit.message }}` | Commit message |
| `${{ github.event.head_commit.url }}` | Commit URL |

---

# Troubleshooting

## Workflow doesn't start

Check:

- The workflow file is located at:

```text
.github/workflows/ms-teams.cicd.yml
```

- The branch name matches the configured branch patterns.

### Branch Pattern Examples

| Pattern | Matches | Does Not Match |
|----------|----------|----------|
| `Feature/**` | `Feature/login`, `Feature/auth/google`, `Feature/gameplay/ui` | `feature/login`, `Bugfix/login` |
| `Feature/*` | `Feature/login`, `Feature/firebase` | `Feature/auth/google`, `Feature/gameplay/ui` |
| `Feature/xyz` | `Feature/xyz` | `Feature/login`, `Feature/xyz/test` |

#### Pattern Details

- `Feature/**`
  - Matches any branch that starts with `Feature/`.
  - Supports nested paths of any depth.

  Examples:

  ```text
  Feature/login
  Feature/firebase-auth
  Feature/auth/google
  Feature/gameplay/ui
  ```

- `Feature/*`
  - Matches branches directly under `Feature/`.
  - Does **not** match nested paths.

  Examples:

  ```text
  Feature/login
  Feature/firebase-auth
  ```

  Does not match:

  ```text
  Feature/auth/google
  Feature/gameplay/ui
  ```

- `Feature/xyz`
  - Matches only the exact branch name.

  Example:

  ```text
  Feature/xyz
  ```

> **Note:** Branch pattern matching in GitHub Actions is case-sensitive.  
> `Feature/login` and `feature/login` are considered different branch names.

- GitHub Actions are enabled for the repository.

## Teams notification isn't received

Verify:

- The `TEAMS_WEBHOOK_URL` secret exists.
- The webhook URL is valid and hasn't expired.
- The Teams channel still has the Incoming Webhook configured.

---

## GitHub Action fails

Open:

```
Repository
    ↓
Actions
```

Select the failed workflow and inspect the logs.

Common causes include:

- Invalid webhook URL
- Missing repository secret
- Incorrect YAML indentation
- Invalid JSON payload

---

# Security Notes

- Never commit the Teams webhook URL to your repository.
- Always store the webhook URL in GitHub Secrets.
- Rotate the webhook if it is accidentally exposed.
- Limit access to repository secrets to trusted maintainers.

---

# Repository Structure

```
repository/
│
├── .github/
│   └── workflows/
│       └── ms-teams.cicd.yml
│
├── src/
├── docs/
└── README.md
```

---

# Result

After completing the setup:

```
Developer pushes code
        │
        ▼
GitHub Action starts
        │
        ▼
Creates Adaptive Card
        │
        ▼
Posts to Microsoft Teams
        │
        ▼
Team receives instant commit notification
```

# Credits

This is a basic CI/CD pipeline built by Biswarup Naha using Github Actions and Teams Workflows to implement a broadcasting notification service on every push made on the specified github repo.

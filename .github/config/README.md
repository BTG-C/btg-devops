# Centralized Maven Configuration

## Overview
This directory contains centralized Maven configuration files used across all Java service build pipelines.

## Files

### `maven-settings.xml`
Central Maven settings for GitHub Packages authentication.

**Configured Servers:**
- `github` - btg-service-commons repository
- `github-entities` - btg-entities repository

**Usage in GitHub Actions:**
```yaml
- name: Checkout central Maven config
  uses: actions/checkout@v4
  with:
    repository: BTG-C/btg-devops
    path: .github-config
    sparse-checkout: |
      .github/config/maven-settings.xml
    sparse-checkout-cone-mode: false

- name: Configure Maven settings
  run: |
    mkdir -p ~/.m2
    cp .github-config/.github/config/maven-settings.xml ~/.m2/settings.xml

- name: Build with Maven
  env:
    GITHUB_ACTOR: ${{ github.actor }}
    GITHUB_TOKEN: ${{ secrets.DEVOPS_REPO_TOKEN }}
  run: ./mvnw clean package -B -DskipTests
```

## Benefits

✅ **Single Source of Truth** - Update authentication once, applies everywhere
✅ **Consistent Configuration** - All services use identical Maven settings
✅ **Easy Maintenance** - Add new repositories in one place
✅ **Reduced Duplication** - No repeated configuration in every workflow
✅ **Version Control** - Track configuration changes centrally

## Adding New Package Repository

To add a new GitHub Packages repository:

1. Edit `maven-settings.xml`
2. Add new server entry:
```xml
<server>
  <id>github-new-repo</id>
  <username>${env.GITHUB_ACTOR}</username>
  <password>${env.GITHUB_TOKEN}</password>
</server>
```
3. Update corresponding `pom.xml` repositories section
4. Changes automatically apply to all services on next build

## Services Using This Configuration

- btg-auth-server
- btg-gateway-service
- btg-enhancer-service
- btg-score-odd-service

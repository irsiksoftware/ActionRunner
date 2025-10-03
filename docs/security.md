# GitHub Actions Self-Hosted Runner Security Guide

## ⚠️ Security Risks Overview

Self-hosted runners pose significant security risks, especially when running workflows from public repositories or untrusted pull requests. Understanding these risks is critical before deployment.

### Critical Security Risks

1. **Arbitrary Code Execution**: Workflows can execute any code on the runner machine
2. **Secret Exposure**: Malicious workflows can exfiltrate repository secrets
3. **Network Access**: Runners can access internal network resources
4. **Privilege Escalation**: Compromised runners can attack other infrastructure
5. **Data Theft**: Access to source code, credentials, and sensitive files
6. **Resource Abuse**: Cryptocurrency mining, DDoS attacks, spam operations

### GitHub's Official Warning

> **NEVER use self-hosted runners with public repositories or untrusted pull requests.**
>
> Forks of your public repository can potentially run dangerous code on your runner machine by creating a pull request that executes the code in a workflow.

## 🔒 Security Best Practices

### 1. Repository and Organization Restrictions

**Configure runner for private repositories only:**

```bash
# During runner configuration, restrict to specific repositories
./config.cmd --url https://github.com/YOUR-ORG/YOUR-REPO --token YOUR-TOKEN

# Or restrict to organization (private repos only)
./config.cmd --url https://github.com/YOUR-ORG --token YOUR-TOKEN
```

**Disable fork PRs from running workflows:**
- Go to repository Settings → Actions → General
- Under "Fork pull request workflows", select "Require approval for all outside collaborators"
- This prevents automatic execution of untrusted code

### 2. Network Isolation

**Critical network security measures:**

#### Isolate from Internal Network
- Place runners in a DMZ or separate VLAN
- Deny access to internal network resources (databases, file shares, admin tools)
- Use firewall rules to restrict both inbound and outbound traffic

#### Outbound-Only Connectivity
- Allow ONLY outbound HTTPS (443) to GitHub APIs
- Block all inbound connections except SSH/RDP for administration
- Whitelist GitHub IP ranges if possible

#### Required Endpoints
Runners must reach these GitHub domains:
- `github.com`
- `api.github.com`
- `*.actions.githubusercontent.com`
- `github-releases.githubusercontent.com`
- `github-registry-files.githubusercontent.com`

**Network Security Checklist:**
- [ ] Runner placed in isolated network segment
- [ ] No access to production databases
- [ ] No access to internal file shares
- [ ] No access to corporate authentication systems
- [ ] Outbound traffic limited to GitHub services
- [ ] All inbound ports blocked (except admin access)
- [ ] Firewall rules documented and reviewed
- [ ] Network monitoring and logging enabled

### 3. Token Management and Rotation

**Runner Registration Tokens:**
- Registration tokens expire after 1 hour
- Generate new tokens for each runner configuration
- Never commit tokens to source control
- Store tokens in secure password manager

**Access Tokens (PAT):**
- Use fine-grained personal access tokens with minimal permissions
- Set expiration dates (max 90 days recommended)
- Rotate tokens regularly
- Revoke immediately if compromised

**Organization/Repository Access:**
- Use organization-level runners for better control
- Implement least-privilege access model
- Regularly audit runner access permissions
- Remove unused runners immediately

### 4. User Account and Permissions

**Create dedicated service account with minimal permissions:**

```powershell
# See config/runner-user-setup.ps1 for automated setup
# Key principles:
# - Non-administrator account
# - No network access rights
# - Limited file system access
# - Cannot install software
# - Cannot modify system settings
```

**Permissions Checklist:**
- [ ] Non-administrator user created
- [ ] Password never expires (service account)
- [ ] User cannot log on interactively (optional)
- [ ] Limited to runner working directory
- [ ] No access to other users' data
- [ ] Cannot modify Windows registry
- [ ] Cannot install services
- [ ] Cannot access credential manager

### 5. Ephemeral Environment Isolation

**Use Docker containers for job isolation:**

Docker containers provide process and filesystem isolation, preventing workflows from accessing the host system.

**Setup container-based execution:**

```yaml
# .github/workflows/example.yml
jobs:
  build:
    runs-on: self-hosted
    container:
      image: node:18
      options: --cpus 2 --memory 4g
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm test
```

**Container security benefits:**
- Isolated filesystem (workflows can't access host files)
- Resource limits (CPU, memory, disk)
- Network isolation options
- Automatic cleanup after job completion
- Consistent, reproducible environments

**Container isolation checklist:**
- [ ] Docker Desktop installed and configured
- [ ] Runner configured to support container jobs
- [ ] Resource limits configured per container
- [ ] Image sources restricted to trusted registries
- [ ] Container logs monitored
- [ ] Automatic cleanup of stopped containers

**Alternative: VM-based ephemeral runners**
For maximum isolation, consider:
- Packer templates for fresh VM images
- Terraform to provision/destroy runners dynamically
- Cloud provider ephemeral runners (AWS, Azure, GCP)

### 6. Secrets Management

**GitHub Secrets best practices:**

```yaml
# Use secrets, never hardcode credentials
- name: Deploy
  env:
    API_KEY: ${{ secrets.API_KEY }}
  run: deploy.ps1
```

**Secrets security checklist:**
- [ ] Never log secrets (they're automatically masked in GitHub)
- [ ] Use environment-specific secrets
- [ ] Rotate secrets regularly
- [ ] Limit secret access to required workflows only
- [ ] Use external secret managers (Azure Key Vault, AWS Secrets Manager)
- [ ] Audit secret access logs
- [ ] Never commit .env files with secrets
- [ ] Use encrypted secrets for sensitive data

**Secret rotation schedule:**
- Database passwords: 90 days
- API keys: 90 days
- SSH keys: 180 days
- Service account credentials: 90 days

### 7. Monitoring and Audit Trail

**Enable comprehensive logging:**

```powershell
# Runner logs location
C:\actions-runner\_diag\
```

**Monitoring checklist:**
- [ ] Runner service logs enabled
- [ ] Windows Event Log monitoring
- [ ] Network traffic logging
- [ ] File access auditing
- [ ] Failed authentication alerts
- [ ] Unusual process execution alerts
- [ ] Resource usage monitoring
- [ ] Integration with SIEM (if available)

**Key metrics to monitor:**
- Job execution times (detect crypto mining)
- Network traffic volume (detect data exfiltration)
- Disk usage (detect unauthorized storage)
- CPU/Memory spikes (detect resource abuse)
- Failed login attempts
- Privilege escalation attempts

### 8. Workflow Security Controls

**Require workflow approval:**
- Settings → Actions → General → Fork pull request workflows
- Enable "Require approval for first-time contributors"
- Review workflows before allowing execution

**Limit workflow permissions:**

```yaml
# Restrict default GITHUB_TOKEN permissions
permissions:
  contents: read
  pull-requests: read
  # Don't grant write access unless necessary
```

**Prevent privilege escalation in workflows:**
- Never use `sudo` or `Run as Administrator` unnecessarily
- Don't install software in workflows (use container images)
- Validate all external inputs
- Pin action versions to specific commits

### 9. Regular Security Maintenance

**Weekly tasks:**
- [ ] Review runner logs for anomalies
- [ ] Check for runner software updates
- [ ] Verify firewall rules are active
- [ ] Monitor resource usage patterns

**Monthly tasks:**
- [ ] Rotate access tokens
- [ ] Review and remove unused runners
- [ ] Audit user permissions
- [ ] Update container base images
- [ ] Review security advisories

**Quarterly tasks:**
- [ ] Full security audit
- [ ] Penetration testing (if applicable)
- [ ] Review and update security policies
- [ ] Disaster recovery testing

## 🚨 Incident Response

**If you suspect a security breach:**

1. **Immediately disable the runner:**
   ```bash
   # Stop the runner service
   Stop-Service actions.runner.*
   ```

2. **Revoke all tokens:**
   - GitHub Settings → Developer Settings → Personal Access Tokens
   - Revoke all tokens associated with the runner

3. **Isolate the machine:**
   - Disconnect from network
   - Preserve logs for forensic analysis

4. **Investigate:**
   - Review `_diag` logs
   - Check Windows Event Logs
   - Analyze network traffic logs
   - Look for unauthorized file changes

5. **Rotate all secrets:**
   - Repository secrets
   - Organization secrets
   - Any credentials that may have been exposed

6. **Report to security team:**
   - Document timeline
   - Share evidence
   - Follow organization's incident response procedures

## 📋 Security Checklist Summary

Before deploying a self-hosted runner, verify:

- [ ] **Never** using with public repositories
- [ ] Runner in isolated network segment
- [ ] Firewall rules configured (see config/firewall-rules.yaml)
- [ ] Dedicated service account with minimal permissions
- [ ] Container isolation configured
- [ ] Secrets management strategy implemented
- [ ] Monitoring and alerting enabled
- [ ] Regular maintenance schedule established
- [ ] Incident response plan documented
- [ ] Security audit completed

## 📚 Additional Resources

- [GitHub Docs: Self-hosted runner security](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
- [GitHub Docs: Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Controls](https://www.cisecurity.org/controls)

## ⚖️ Compliance Considerations

**For regulated industries (HIPAA, PCI-DSS, SOC 2):**
- Consult security team before deployment
- May require additional controls (encryption, audit logs)
- Document security controls for auditors
- Implement data classification policies
- Consider using GitHub Enterprise Cloud with GitHub-hosted runners instead

---

**Last Updated:** 2025-10-03
**Review Frequency:** Quarterly or after security incidents

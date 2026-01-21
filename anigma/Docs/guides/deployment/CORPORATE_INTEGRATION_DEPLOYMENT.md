# Corporate Integration Deployment Guide

This guide details the steps required to deploy the "Corporate Integration" features (OIDC, SCIM, Tenant Governance) into the Anigma platform.

## Phase 1: Enterprise Identity

### 1. OIDC Configuration
The `OIDCAdapter` supports standard Authorization Code Flow with PKCE.

**Configuration:**
*   **Issuer**: The URL of your OIDC provider (e.g., Okta, Azure AD).
*   **Client ID**: The client ID assigned to Anigma.
*   **Redirect URI**: The callback URL (e.g., `anigma://auth/callback`).
*   **Scopes**: Required scopes (e.g., `openid profile email`).

**Usage:**
```swift
let config = OIDCConfiguration(
    issuer: URL(string: "https://idp.example.com")!,
    clientId: "anigma-client-id",
    redirectUri: URL(string: "anigma://auth/callback")!,
    scopes: ["openid", "profile", "email"]
)
let adapter = OIDCAdapter(configuration: config)
let authUrl = await adapter.createAuthorizationURL()
// ... handle redirect and exchange code ...
```

### 2. SCIM Provisioning
The `SCIMProvider` implements SCIM 2.0 endpoints for user and group management.

**Endpoints:**
*   `POST /Users`: Create user
*   `PUT /Users/{id}`: Update user
*   `DELETE /Users/{id}`: Delete user
*   `POST /Groups`: Create group

**Integration:**
Configure your IdP (Okta, Azure AD) to point to the Anigma SCIM endpoints. Ensure the API token used by the IdP is valid and has `scim:admin` scope.

### 3. Tenant Governance
The `TenantBoundary` enforces strict isolation between tenants.

**Policy:**
*   Every request must carry a `TenantContext`.
*   Access is denied if the tenant ID is not registered or active.
*   Admin operations (audit export, tenant provisioning) are restricted to the `AdminConsole` actor.

## Verification
Run `Scripts/verify_corporate_readiness.sh` to validate that the module is correctly integrated and builds successfully.

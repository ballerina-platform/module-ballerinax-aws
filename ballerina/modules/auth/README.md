## Overview

The `auth` submodule of the [`ballerinax/aws`](https://central.ballerina.io/ballerinax/aws/latest) package provides AWS authentication: credential resolution across all standardized AWS credential sources (with automatic refresh) and AWS Signature Version 4 (SigV4) request signing. It is the authentication foundation used by the `ballerinax/aws.*` connectors, and can be used directly to call AWS services that do not have a dedicated connector yet.

Region and endpoint utilities live in the package's root module, [`ballerinax/aws`](https://central.ballerina.io/ballerinax/aws/latest).

## Credential sources

The `AuthConfig` union covers all standardized AWS credential sources:

| Config type | Source | Typical use |
|---|---|---|
| `StaticAuthConfig` | Explicit access keys (+ optional session token) | Tests, CI-injected secrets |
| `ProfileAuthConfig` | A named profile in `~/.aws/credentials` | Developer machines |
| `AssumeRoleConfig` | STS assume-role, composable over any base identity | Cross-account access, least privilege |
| `WebIdentityConfig` | An OIDC token exchanged via STS | EKS IRSA, CI/CD OIDC |
| `SsoAuthConfig` | An IAM Identity Center session (`aws sso login`) | Enterprise developer machines |
| `ProcessAuthConfig` | An external `credential_process` command | IAM Roles Anywhere, credential brokers |
| `DEFAULT_CREDENTIALS` | The default provider chain (env vars, SSO, profile, container, EC2 IMDS, …) | Production on AWS |

## Quickstart

### Step 1: Import the module

```ballerina
import ballerinax/aws.auth;
```

### Step 2: Create a credential provider

Create a `CredentialProvider` once, at initialization. On AWS infrastructure the default provider chain resolves credentials automatically:

```ballerina
auth:CredentialProvider credProvider = check new (auth:DEFAULT_CREDENTIALS);
```

Other credential sources use the same API with a different configuration — for example, STS assume-role composed over any base identity:

```ballerina
auth:CredentialProvider credProvider = check new ({
    roleArn: "arn:aws:iam::123456789012:role/reporting-read-only",
    sourceCredentials: auth:DEFAULT_CREDENTIALS
});
```

### Step 3: Resolve credentials

Fetch credentials per request; expiring temporary credentials (STS, SSO, instance profile) are renewed transparently:

```ballerina
auth:Credentials credentials = check credProvider.getCredentials();
```

Release the provider's resources when it is no longer needed:

```ballerina
check credProvider.close();
```

### Step 4: Sign a request

Sign requests to any AWS service — including services without a dedicated Ballerina connector. `getSignedHeaders` returns the headers to attach to the outbound request:

```ballerina
map<string> signedHeaders = check auth:getSignedHeaders({
    method: "POST",
    host: "sns.us-east-1.amazonaws.com",
    headers: {"content-type": "application/x-www-form-urlencoded"},
    payload: "Action=CreateTopic&Name=orders".toBytes()
}, credentials, "us-east-1", "sns");
```

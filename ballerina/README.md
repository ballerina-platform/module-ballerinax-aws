## Overview

[AWS](https://aws.amazon.com/) is a comprehensive cloud computing platform offering over 200 services, all authenticated through a common scheme: IAM credentials and [AWS Signature Version 4](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_aws-signing.html) request signing.

The `ballerinax/aws.auth` package provides shared AWS authentication for the Ballerina ecosystem: credential resolution across all standardized AWS credential sources with automatic refresh, AWS Signature Version 4 request signing, and region-based endpoint resolution. It is the authentication foundation used by the `ballerinax/aws.*` connectors, and can be used directly to call AWS services that do not have a dedicated connector yet.

### Key Features

- All standardized AWS credential sources: static keys, shared credentials file profiles, STS assume-role, web identity (OIDC/EKS IRSA), IAM Identity Center (SSO), external credential processes, and the default credential provider chain
- Automatic refresh of expiring temporary credentials, backed by the AWS SDK credential providers
- AWS Signature Version 4 request signing via the AWS SDK signer, validated against the official test vectors
- Typed `Region` values and endpoint resolution covering all AWS partitions, FIPS/dualstack variants, and custom endpoint overrides (e.g. LocalStack)
- GraalVM compatible for native image builds

## Setup guide

### Login to AWS Console

Log into the [AWS Management Console](https://console.aws.amazon.com/console). If you don't have an AWS account yet, you can create one by visiting the AWS [sign-up](https://aws.amazon.com/free/) page.

### Create a user

1. In the AWS Management Console, search for **IAM** in the services search bar and open it.
2. Navigate to **Users** and click **Create user**.
3. Provide a user name and attach the permission policies required by the AWS services you intend to call.

### Get user access keys

1. Open the created user and go to the **Security credentials** tab.
2. Click **Create access key** and select the appropriate use case.
3. Copy the generated **Access key ID** and **Secret access key**.

> **Tip:** Static access keys are only one of the supported credential sources and the least preferred for production. On AWS infrastructure (EC2, ECS/EKS), prefer IAM roles via `DEFAULT_CREDENTIALS`; on developer machines, prefer a credentials file profile or IAM Identity Center (SSO). No access keys need to be created for those sources.

## Quickstart

To use the `aws.auth` package in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

```ballerina
import ballerinax/aws.auth;
```

### Step 2: Create a credential provider

Create a `CredentialProvider` once, at initialization. On AWS infrastructure, the default credential provider chain resolves credentials automatically — no configuration needed:

```ballerina
auth:CredentialProvider credProvider = check new (auth:DEFAULT_CREDENTIALS);
```

#### Alternative credential sources

##### Static credentials

```ballerina
auth:CredentialProvider credProvider = check new ({
    accessKeyId: "AKIA...",
    secretAccessKey: "..."
});
```

##### Profile-based authentication

```ballerina
auth:CredentialProvider credProvider = check new ({
    profileName: "dev"
});
```

##### STS assume-role

```ballerina
auth:CredentialProvider credProvider = check new ({
    roleArn: "arn:aws:iam::123456789012:role/reporting-read-only",
    sourceCredentials: auth:DEFAULT_CREDENTIALS
});
```

##### Web identity (EKS IRSA, CI/CD OIDC)

```ballerina
auth:CredentialProvider credProvider = check new ({
    roleArn: "arn:aws:iam::123456789012:role/order-service",
    webIdentityTokenFile: "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
});
```

##### IAM Identity Center (SSO)

Requires an active session created with `aws sso login`:

```ballerina
auth:CredentialProvider credProvider = check new ({
    ssoStartUrl: "https://myorg.awsapps.com/start",
    ssoRegion: "us-east-1",
    accountId: "123456789012",
    roleName: "DeveloperAccess"
});
```

### Step 3: Use the APIs

#### Resolve credentials

Fetch credentials per request; expiring temporary credentials are renewed transparently:

```ballerina
auth:Credentials credentials = check credProvider.getCredentials();
```

#### Resolve a service endpoint

```ballerina
string url = auth:resolveEndpoint("events", auth:US_EAST_1);
// "https://events.us-east-1.amazonaws.com"

// For local testing, override with a custom endpoint (e.g. LocalStack):
string testUrl = auth:resolveEndpoint("events", auth:US_EAST_1, {customEndpoint: "http://localhost:4566"});
```

#### Sign a request

Sign requests to any AWS service including services without a dedicated Ballerina connector. The following calls Amazon EventBridge `PutEvents` over a plain `http:Client`:

```ballerina
import ballerina/http;
import ballerinax/aws.auth;

public function main() returns error? {
    auth:CredentialProvider credProvider = check new (auth:DEFAULT_CREDENTIALS);
    string host = auth:resolveEndpointHost("events", auth:US_EAST_1);
    http:Client eventBridge = check new ("https://" + host);

    json putEventsRequest = {
        "Entries": [
            {
                "Source": "com.mycompany.orders",
                "DetailType": "OrderPlaced",
                "Detail": {"orderId": "o-1234"}.toJsonString()
            }
        ]
    };
    byte[] payload = putEventsRequest.toJsonString().toBytes();

    auth:Credentials credentials = check credProvider.getCredentials();
    map<string> signedHeaders = check auth:getSignedHeaders({
        method: "POST",
        host,
        headers: {
            "content-type": "application/x-amz-json-1.1",
            "x-amz-target": "AWSEvents.PutEvents"
        },
        payload
    }, credentials, auth:US_EAST_1, "events");

    http:Request request = new;
    request.setBinaryPayload(payload);
    foreach [string, string] [name, value] in signedHeaders.entries() {
        request.setHeader(name, value);
    }
    http:Response response = check eventBridge->execute("POST", "/", request);
}
```

### Step 4: Run the Ballerina application

```bash
bal run
```

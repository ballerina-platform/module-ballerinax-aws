# Ballerina AWS Package

[![Build](https://github.com/ballerina-platform/module-ballerinax-aws/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-aws/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerinax-aws/branch/master/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerinax-aws)
[![Trivy](https://github.com/ballerina-platform/module-ballerinax-aws/actions/workflows/trivy-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-aws/actions/workflows/trivy-scan.yml)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerinax-aws/actions/workflows/build-with-bal-test-graalvm.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-aws/actions/workflows/build-with-bal-test-graalvm.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-aws.svg)](https://github.com/ballerina-platform/module-ballerinax-aws/commits/master)

## Overview

[AWS](https://aws.amazon.com/) is a comprehensive cloud computing platform offering over 200 services, all authenticated through a common scheme: IAM credentials and [AWS Signature Version 4](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_aws-signing.html) request signing.

The `ballerinax/aws` package provides shared AWS authentication and core utilities for the Ballerina ecosystem. It has two modules: the root module (`ballerinax/aws`) with the `Region` type and region-based endpoint resolution, and the `auth` submodule (`ballerinax/aws.auth`) with credential resolution across all standardized AWS credential sources (with automatic refresh) and AWS Signature Version 4 request signing. It is the authentication foundation used by the `ballerinax/aws.*` connectors, and can be used directly to call AWS services that do not have a dedicated connector yet.

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

1. In the AWS Management Console, search for IAM in the services search bar.
2. Click on IAM

   ![create-user-1.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/create-user-1.png)

3. Click Users

   ![create-user-2.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/create-user-2.png)

4. Click Create User

   ![create-user-3.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/create-user-3.png)

5. Provide a suitable name for the user and continue

   ![specify-user-details.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/specify-user-details.png)

6. Attach the necessary permission policies directly to the user based on the AWS services you intend to call, and click next.

   ![set-user-permissions.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/set-user-permissions.png)

7. Review and create the user

   ![review-create-user.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/review-create-user.png)

### Get user access keys

1. Click the user that created

   ![users.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/users.png)

2. Click `Create access key`

   ![create-access-key-1.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/create-access-key-1.png)

3. Click your use case and click next.

   ![select-usecase.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/select-usecase.png)

4. Record the Access Key and Secret access key. These credentials will be used to authenticate your Ballerina application with AWS.

   ![retrieve-access-key.png](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-aws/main/docs/setup/resources/retrieve-access-key.png)

> **Tip:** Static access keys are only one of the supported credential sources and the least preferred for production. On AWS infrastructure (EC2, ECS/EKS), prefer IAM roles via `DEFAULT_CREDENTIALS`; on developer machines, prefer a credentials file profile or IAM Identity Center (SSO). No access keys need to be created for those sources.

## Quickstart

To use the `ballerinax/aws` package in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the modules

```ballerina
import ballerinax/aws;
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
import ballerinax/aws;

string url = aws:resolveEndpoint("events", aws:US_EAST_1);
// "https://events.us-east-1.amazonaws.com"

// For local testing, override with a custom endpoint (e.g. LocalStack):
string testUrl = aws:resolveEndpoint("events", aws:US_EAST_1, {customEndpoint: "http://localhost:4566"});
```

#### Sign a request

Sign requests to any AWS service including services without a dedicated Ballerina connector. The following calls Amazon EventBridge `PutEvents` over a plain `http:Client`:

```ballerina
import ballerina/http;
import ballerinax/aws;
import ballerinax/aws.auth;

public function main() returns error? {
    auth:CredentialProvider credProvider = check new (auth:DEFAULT_CREDENTIALS);
    string host = aws:resolveEndpointHost("events", aws:US_EAST_1);
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
    }, credentials, aws:US_EAST_1, "events");

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

## Build from the source

### Prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:
    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)
2. Download and install [Ballerina Swan Lake](https://ballerina.io/).
3. Download and install [Docker](https://www.docker.com/get-started).

### Build options

Execute the commands below to build from the source.

1. To build the package:
   ```bash
   ./gradlew clean build
   ```
2. To run the tests:
   ```bash
   ./gradlew clean test
   ```
3. To build the without the tests:
   ```bash
   ./gradlew clean build -x test
   ```
4. To publish to the local Ballerina Central repository:
   ```bash
   ./gradlew clean build -PpublishToLocalCentral=true
   ```
5. To publish to Ballerina Central:
   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`aws.auth` package](https://central.ballerina.io/ballerinax/aws.auth/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.

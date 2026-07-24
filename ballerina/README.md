## Overview

This library provides shared AWS authentication and core utilities for the Ballerina ecosystem.

[AWS](https://aws.amazon.com/) is a comprehensive cloud computing platform offering over 200 services, all authenticated through a common scheme: IAM credentials and [AWS Signature Version 4](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_aws-signing.html) request signing. This library implements that scheme once, so it does not need to be re-implemented per AWS service.

The library has two modules: the root module (`ballerinax/aws`) with the `Region` type and region-based endpoint resolution, and the `auth` submodule (`ballerinax/aws.auth`) with credential resolution across all standardized AWS credential sources and AWS Signature Version 4 request signing. It is the authentication foundation used by the `ballerinax/aws.*` connectors, and can also be used directly to call AWS services that do not have a dedicated connector yet.

## Credential resolution

The `auth:CredentialProvider` class resolves AWS credentials from a configured source and caches them, refreshing expiring temporary credentials (STS, SSO, instance-profile) automatically. Create one per configured source, at initialization, and reuse it for the lifetime of the application:

```ballerina
import ballerinax/aws.auth;

auth:CredentialProvider credProvider = check new (auth:DEFAULT_CREDENTIALS);
```

Fetch credentials per request; expiring temporary credentials are renewed transparently:

```ballerina
auth:Credentials credentials = check credProvider.getCredentials();
```

Release the provider's resources (background refresh threads, HTTP connections for STS/SSO) when it is no longer needed:

```ballerina
check credProvider.close();
```

### Credential sources

`auth:CredentialProvider` accepts any of the following configurations as its `AuthConfig`.

#### Default credential provider chain

Resolves credentials automatically from the AWS SDK's default chain (environment variables, `~/.aws/credentials`, an EC2/ECS/EKS instance role, etc.) — no configuration needed. This is the preferred source when running on AWS infrastructure.

```ballerina
auth:CredentialProvider credProvider = check new (auth:DEFAULT_CREDENTIALS);
```

#### Static credentials

The least preferred source for production use; prefer one of the sources below when possible.

```ballerina
auth:CredentialProvider credProvider = check new ({
    accessKeyId: "AKIA...",
    secretAccessKey: "..."
});
```

> **Tip:** To create an access key, sign in to the [AWS Management Console](https://console.aws.amazon.com/console), open **IAM** → **Users** → create or select a user → **Security credentials** tab → **Create access key**.

#### Profile-based authentication

Reads credentials from a named profile in a local AWS credentials file (as created by `aws configure`).

```ballerina
auth:CredentialProvider credProvider = check new ({
    profileName: "dev"
});
```

#### STS assume-role

Obtains temporary credentials by assuming an IAM role via AWS STS.

```ballerina
auth:CredentialProvider credProvider = check new ({
    roleArn: "arn:aws:iam::123456789012:role/reporting-read-only",
    sourceCredentials: auth:DEFAULT_CREDENTIALS
});
```

#### Web identity (EKS IRSA, CI/CD OIDC)

Exchanges a web identity (OIDC) token for temporary credentials via AWS STS.

```ballerina
auth:CredentialProvider credProvider = check new ({
    roleArn: "arn:aws:iam::123456789012:role/order-service",
    webIdentityTokenFile: "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
});
```

#### IAM Identity Center (SSO)

Requires an active session created with `aws sso login`.

```ballerina
auth:CredentialProvider credProvider = check new ({
    ssoStartUrl: "https://myorg.awsapps.com/start",
    ssoRegion: "us-east-1",
    accountId: "123456789012",
    roleName: "DeveloperAccess"
});
```

#### External credential process

Executes an external command implementing the AWS `credential_process` contract, which must print a JSON credential document to stdout.

```ballerina
auth:CredentialProvider credProvider = check new ({
    command: ["/usr/local/bin/aws_signing_helper", "credential-process", "--certificate", "/path/to/cert.pem"]
});
```

> **Security note:** the configured command runs with the privileges of the running program. Prefer declaring it in `~/.aws/config` (`credential_process`) and using profile-based authentication or the default credential provider chain where possible.

## Region and endpoint resolution

`aws:Region` is a typed enum of all AWS regions. Endpoints are resolved using the AWS SDK's own endpoint metadata, covering all partitions and the FIPS/dualstack variants, with a standard-pattern fallback for regions newer than the bundled SDK:

```ballerina
import ballerinax/aws;

string url = aws:resolveEndpoint("events", aws:US_EAST_1);
// "https://events.us-east-1.amazonaws.com"

string host = aws:resolveEndpointHost("events", aws:US_EAST_1);
// "events.us-east-1.amazonaws.com"
```

`EndpointConfig` selects the FIPS or dualstack variant, or overrides the endpoint entirely — useful for local testing against [LocalStack](https://www.localstack.cloud/) or similar:

```ballerina
string testUrl = aws:resolveEndpoint("events", aws:US_EAST_1, {customEndpoint: "http://localhost:4566"});
// "http://localhost:4566"

string fipsUrl = aws:resolveEndpoint("events", aws:US_EAST_1, {fips: true});
// "https://events-fips.us-east-1.amazonaws.com"
```

## Request signing

`auth:getSignedHeaders` signs a request with AWS Signature Version 4 and returns the headers to set on the outbound request. Use it to call any AWS service, including ones without a dedicated Ballerina connector.

The following example calls Amazon EventBridge's `PutEvents` over a plain `http:Client`:

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

## Errors

`auth:Error` is the base error type for the `auth` module. `auth:CredentialResolutionError` is returned when a configured credential source cannot supply credentials — its `ErrorDetails` are populated when the failure originates from an AWS service call (e.g. STS or SSO). `auth:SigningError` is returned when signing a request fails.

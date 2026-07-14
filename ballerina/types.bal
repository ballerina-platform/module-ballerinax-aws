// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

# Instructs the credential provider to resolve credentials via the AWS default
# credential provider chain: environment variables, web identity token,
# IAM Identity Center (SSO), shared config/credentials files, external process,
# container credentials (ECS/EKS), and EC2 instance profile (IMDS) — in order,
# taking the first source that yields credentials.
public const DEFAULT_CREDENTIALS = "DEFAULT_CREDENTIALS";

# Represents the supported AWS credential source configurations.
public type AuthConfig StaticAuthConfig|ProfileAuthConfig|AssumeRoleConfig|WebIdentityConfig|SsoAuthConfig|ProcessAuthConfig|DEFAULT_CREDENTIALS;

# Represents static AWS credentials.
#
# + accessKeyId - AWS access key ID
# + secretAccessKey - AWS secret access key
# + sessionToken - AWS session token, required only for temporary credentials
public type StaticAuthConfig record {|
    string accessKeyId;
    string secretAccessKey;
    string sessionToken?;
|};

# Represents AWS credentials loaded from a named profile in a local AWS
# credentials file (as created by `aws configure`).
#
# + profileName - The named profile to use
# + credentialsFilePath - Path to the AWS credentials file
public type ProfileAuthConfig record {|
    string profileName = "default";
    string credentialsFilePath = "~/.aws/credentials";
|};

# Represents temporary credentials obtained by assuming an IAM role via AWS STS.
# The base identity used to call STS is itself an `AuthConfig`, so a role can be
# assumed from any other credential source.
#
# + roleArn - ARN of the IAM role to assume
# + roleSessionName - Identifier for the assumed-role session; a unique
# `ballerina-aws-auth-<timestamp>` name is generated if not provided
# + externalId - External ID for third-party cross-account trust, if the role requires one
# + duration - Validity period of each assumed-role session in seconds
# + stsRegion - Region of the STS endpoint to call
# + sourceCredentials - Credential source used to authenticate the AssumeRole call
public type AssumeRoleConfig record {|
    string roleArn;
    string roleSessionName?;
    string externalId?;
    int duration = 3600;
    string stsRegion = "us-east-1";
    AuthConfig sourceCredentials = DEFAULT_CREDENTIALS;
|};

# Represents temporary credentials obtained by exchanging a web identity (OIDC)
# token for an IAM role via AWS STS — e.g. EKS IAM Roles for Service Accounts
# (IRSA) or CI/CD OIDC federation.
#
# + roleArn - ARN of the IAM role to assume
# + webIdentityTokenFile - Path to the file containing the OIDC token (JWT)
# + roleSessionName - Identifier for the assumed-role session; a unique
# `ballerina-aws-auth-<timestamp>` name is generated if not provided
# + stsRegion - Region of the STS endpoint to call
public type WebIdentityConfig record {|
    string roleArn;
    string webIdentityTokenFile;
    string roleSessionName?;
    string stsRegion = "us-east-1";
|};

# Represents credentials obtained from an AWS IAM Identity Center (SSO) session.
# Requires an active session created out-of-band with `aws sso login`; the cached
# session token in `~/.aws/sso/cache` is exchanged for role credentials.
#
# + ssoStartUrl - The Identity Center start URL (e.g. `https://myorg.awsapps.com/start`)
# + ssoRegion - Region in which IAM Identity Center is configured
# + accountId - AWS account ID to get credentials for
# + roleName - Permission-set role name to get credentials for
# + ssoSessionName - Name of the `sso-session` block used at `aws sso login`,
# for logins configured the modern way (`[sso-session <name>]` in `~/.aws/config`).
# When set, the cached token is located by the session name and expiring tokens
# are refreshed automatically; when absent, the token cached under the start URL
# by a legacy `aws sso login` is used as is
public type SsoAuthConfig record {|
    string ssoStartUrl;
    string ssoRegion;
    string accountId;
    string roleName;
    string ssoSessionName?;
|};

# Represents credentials supplied by an external process (the AWS
# `credential_process` contract). The command is executed and must print a JSON
# credential document to stdout. Used by IAM Roles Anywhere and corporate
# credential brokers.
#
# Security note: the configured command is executed with the privileges of the
# running program. Prefer declaring it in `~/.aws/config` (`credential_process`)
# and using `ProfileAuthConfig`/`DEFAULT_CREDENTIALS` where possible.
#
# + command - The command to execute
public type ProcessAuthConfig record {|
    string command;
|};

# Represents resolved AWS credentials, as returned by the `CredentialProvider`.
# Values are a point-in-time snapshot; fetch credentials from the provider per
# request rather than caching this record, so refreshed credentials are picked up.
#
# + accessKeyId - AWS access key ID
# + secretAccessKey - AWS secret access key
# + sessionToken - Session token, present only for temporary credentials
public type Credentials record {
    string accessKeyId;
    string secretAccessKey;
    string sessionToken?;
};

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

# Signs a request with AWS Signature Version 4 and returns the headers to set
# on the outbound request (`authorization`, `x-amz-date`, `x-amz-content-sha256`,
# and `x-amz-security-token` for temporary credentials). Header names are
# lowercase.
# ```ballerina
# auth:Credentials credentials = check credProvider.getCredentials();
# map<string> signedHeaders = check auth:getSignedHeaders({
#   method: "POST",
#   host: "sns.us-east-1.amazonaws.com",
#   headers: {"content-type": "application/x-www-form-urlencoded"},
#   payload: "Action=CreateTopic&Name=orders".toBytes()
# }, credentials, auth:US_EAST_1, "sns");
# ```
#
# + req - The request to sign
# + credentials - The credentials to sign with
# + region - Target region
# + serviceName - Signing name of the target service (e.g. `s3`, `sns`)
# + return - Headers to set on the outbound request, or a `SigningError`
public isolated function getSignedHeaders(SignatureRequest req, Credentials credentials, Region|string region,
        string serviceName) returns map<string>|SigningError {
    return getSignedHeadersAt(req, credentials, region, serviceName);
}

# Internal signing entry point with an optional fixed timestamp,
# Use only for AWS SigV4 testing in the module.
#
# + req - The request to sign
# + credentials - The credentials to sign with
# + region - Target region
# + serviceName - Signing name of the target service
# + testAmzDate - Fixed `yyyyMMdd'T'HHmmss'Z'` timestamp; `()` in production
# + return - Headers to set on the outbound request, or a `SigningError`
isolated function getSignedHeadersAt(SignatureRequest req, Credentials credentials, Region|string region,
        string serviceName, string? testAmzDate = ()) returns map<string>|SigningError {
    return externGetSignedHeaders(req, credentials, region, serviceName, testAmzDate);
}

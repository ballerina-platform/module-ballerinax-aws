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

# A long-lived AWS credential provider which caches resolved
# credentials and refreshes expiring ones (STS, SSO, instance-profile)
# automatically.
public isolated class CredentialProvider {

    # Initializes the credential provider for the given configuration.
    # ```ballerina
    # auth:CredentialProvider credProvider = check new ({
    #   profileName: "default",
    #   credentialsFilePath: "~/.aws/credentials"
    # });
    # ```
    #
    # + config - The credential source configuration
    # + return - An `auth:Error` if the configuration is invalid, or `()`
    public isolated function init(AuthConfig config) returns Error? {
        return externInitProvider(self, config);
    }

    # Returns currently-valid credentials for signing a request. Fresh
    # credentials are served from the provider's in-memory cache; expiring
    # temporary credentials are renewed transparently before being returned.
    # ```ballerina
    # auth:Credentials credentials = check credProvider.getCredentials();
    # ```
    #
    # + return - The resolved `Credentials`, or an `auth:Error` if the
    # configured source cannot supply credentials
    public isolated function getCredentials() returns Credentials|Error {
        return externGetCredentials(self);
    }
}

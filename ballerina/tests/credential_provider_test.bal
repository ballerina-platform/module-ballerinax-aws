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

import ballerina/test;

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testDefaultCredentialsInitSucceeds() returns error? {
    // The chain is not invoked at init.
    CredentialProvider _ = check new (DEFAULT_CREDENTIALS);
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testStaticCredentialProvider() returns error? {
    CredentialProvider provider = check new (staticAuth);
    Credentials credentials = check provider.getCredentials();
    test:assertEquals(credentials.accessKeyId, dummyAccessKeyId);
    test:assertEquals(credentials.secretAccessKey, dummySecretAccessKey);
    test:assertEquals(credentials?.sessionToken, ());
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testStaticProviderWithSessionToken() returns error? {
    CredentialProvider provider = check new ({
        accessKeyId: dummyAccessKeyId,
        secretAccessKey: dummySecretAccessKey,
        sessionToken: "EXAMPLETOKEN"
    });
    Credentials credentials = check provider.getCredentials();
    test:assertEquals(credentials?.sessionToken, "EXAMPLETOKEN");
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testProfileCredentialProvider() returns error? {
    CredentialProvider provider = check new ({
        profileName: "test-profile",
        credentialsFilePath: "tests/resources/credentials"
    });
    Credentials credentials = check provider.getCredentials();
    test:assertEquals(credentials.accessKeyId, "AKIDPROFILEEXAMPLE");
    test:assertEquals(credentials.secretAccessKey, "profileSecretAccessKey");
    test:assertEquals(credentials?.sessionToken, ());
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testProfileProviderWithSessionToken() returns error? {
    CredentialProvider provider = check new ({
        profileName: "test-profile-session",
        credentialsFilePath: "tests/resources/credentials"
    });
    Credentials credentials = check provider.getCredentials();
    test:assertEquals(credentials.accessKeyId, "AKIDPROFILESESSION");
    test:assertEquals(credentials.secretAccessKey, "profileSessionSecretKey");
    test:assertEquals(credentials?.sessionToken, "profileSessionToken");
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testProcessCredentialProvider() returns error? {
    // The credential_process contract, exercised fully locally: the command
    // prints a credential JSON document to stdout.
    CredentialProvider provider = check new ({
        command: "cat tests/resources/process-credentials.json"
    });
    Credentials credentials = check provider.getCredentials();
    test:assertEquals(credentials.accessKeyId, "AKIDPROCESSEXAMPLE");
    test:assertEquals(credentials.secretAccessKey, "processSecretAccessKey");
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testWebIdentityInitSucceeds() returns error? {
    // No STS call happens at init; the token file is read at resolution time.
    CredentialProvider _ = check new ({
        roleArn: "arn:aws:iam::111111111111:role/web-identity-role",
        webIdentityTokenFile: "tests/resources/web-identity-token"
    });
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testSsoMissingCachedSessionReturnsError() returns error? {
    // Building the provider is lazy; resolution reads the local SSO cache
    // written by `aws sso login` and must fail cleanly when it is absent.
    CredentialProvider provider = check new ({
        ssoStartUrl: "https://ballerina-aws-auth-test.awsapps.com/start",
        ssoRegion: "us-east-1",
        accountId: "111111111111",
        roleName: "TestRole"
    });
    Credentials|Error credentials = provider.getCredentials();
    if credentials is Credentials {
        test:assertFail("Expected an error for a missing cached SSO session");
    } else {
        test:assertTrue(credentials.message().includes("No cached SSO session found"),
            "Unexpected error message: " + credentials.message());
    }
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testSsoSessionMissingCachedTokenReturnsError() returns error? {
    // The modern sso-session flow: the token cache is looked up by the
    // session name; a session never logged in must fail cleanly.
    CredentialProvider provider = check new ({
        ssoStartUrl: "https://ballerina-aws-auth-test.awsapps.com/start",
        ssoRegion: "us-east-1",
        accountId: "111111111111",
        roleName: "TestRole",
        ssoSessionName: "ballerina-aws-auth-nonexistent-session"
    });
    Credentials|Error credentials = provider.getCredentials();
    if credentials is Credentials {
        test:assertFail("Expected an error for a missing sso-session token");
    } else {
        test:assertTrue(credentials.message().includes("Unable to load SSO token"),
            "Unexpected error message: " + credentials.message());
    }
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testChainedAssumeRoleInitSucceeds() returns error? {
    // A two-hop role chain (static base → hub role → spoke role) must build
    CredentialProvider _ = check new ({
        roleArn: "arn:aws:iam::222222222222:role/spoke",
        sourceCredentials: {
            roleArn: "arn:aws:iam::111111111111:role/hub",
            sourceCredentials: staticAuth
        }
    });
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testCyclicSourceCredentialsRejected() {
    // A cyclic chain rejected at init with a clear error, not a StackOverflowError.
    AssumeRoleConfig roleA = {roleArn: "arn:aws:iam::111111111111:role/A"};
    AssumeRoleConfig roleB = {roleArn: "arn:aws:iam::222222222222:role/B", sourceCredentials: roleA};
    roleA.sourceCredentials = roleB;
    CredentialProvider|Error provider = new (roleA);
    if provider is CredentialProvider {
        test:assertFail("Expected an error for a cyclic sourceCredentials chain");
    } else {
        test:assertTrue(provider.message().includes("Circular sourceCredentials"),
            "Unexpected error message: " + provider.message());
    }
}

@test:Config {
    groups: ["credentialProvider"]
}
isolated function testMissingProfileReturnsError() {
    CredentialProvider|Error provider = new ({
        profileName: "nonexistent-profile-for-testing",
        credentialsFilePath: "/tmp/nonexistent-aws-credentials-file"
    });
    if provider is CredentialProvider {
        Credentials|Error credentials = provider.getCredentials(); // TODO: Assert exact error message
        test:assertTrue(credentials is Error, "Expected an error for a missing credentials file");
    }
}

@test:Config {
    groups: ["credentialProvider", "live"],
    enable: liveTestsEnabled
}
isolated function testEnvStaticCredentialProvider() returns error? {
    CredentialProvider provider = check new ({
        accessKeyId: testAccessKeyId,
        secretAccessKey: testSecretAccessKey
    });
    Credentials credentials = check provider.getCredentials();
    test:assertEquals(credentials.accessKeyId, testAccessKeyId);
    test:assertEquals(credentials.secretAccessKey, testSecretAccessKey);
}

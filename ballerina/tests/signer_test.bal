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

final Credentials & readonly signerTestCredentials = {
    accessKeyId: dummyAccessKeyId,
    secretAccessKey: dummySecretAccessKey
};
const TEST_AMZ_DATE = "20150830T123600Z";
const TEST_SIGNING_REGION = "us-east-1";
const TEST_SIGNING_SERVICE = "service";

// SHA-256 of an empty payload.
const EMPTY_PAYLOAD_HASH = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

const AUTHORIZATION_HEADER = "authorization";

@test:Config {
    groups: ["signer"]
}
isolated function testGetSignedHeadersVanillaRequest() returns error? {
    map<string> headers = check getSignedHeadersAt({
        method: "GET",
        host: "example.amazonaws.com"
    }, signerTestCredentials, TEST_SIGNING_REGION, TEST_SIGNING_SERVICE, TEST_AMZ_DATE);

    test:assertEquals(headers["x-amz-date"], TEST_AMZ_DATE);
    test:assertEquals(headers["x-amz-content-sha256"], EMPTY_PAYLOAD_HASH);
    test:assertEquals(headers[AUTHORIZATION_HEADER],
        "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, " +
        "SignedHeaders=host;x-amz-content-sha256;x-amz-date, " +
        "Signature=726c5c4879a6b4ccbbd3b24edbd6b8826d34f87450fbbf4e85546fc7ba9c1642");
    test:assertEquals(headers["host"], (), "Host must be derived from the URL, not returned");
}

@test:Config {
    groups: ["signer"]
}
isolated function testGetSignedHeadersQueryParamsAreSorted() returns error? {
    map<string> headersA = check getSignedHeadersAt({
        method: "GET",
        host: "example.amazonaws.com",
        queryParams: {"Param2": "value2", "Param1": "value1"}
    }, signerTestCredentials, TEST_SIGNING_REGION, TEST_SIGNING_SERVICE, TEST_AMZ_DATE);
    map<string> headersB = check getSignedHeadersAt({
        method: "GET",
        host: "example.amazonaws.com",
        queryParams: {"Param1": "value1", "Param2": "value2"}
    }, signerTestCredentials, TEST_SIGNING_REGION, TEST_SIGNING_SERVICE, TEST_AMZ_DATE);
    test:assertEquals(headersA[AUTHORIZATION_HEADER], headersB[AUTHORIZATION_HEADER]);
}

@test:Config {
    groups: ["signer"]
}
isolated function testGetSignedHeadersSignsSessionToken() returns error? {
    Credentials tempCredentials = {
        accessKeyId: dummyAccessKeyId,
        secretAccessKey: dummySecretAccessKey,
        sessionToken: "IQoJb3JpZ2luX2VjEXAMPLETOKEN"
    };
    map<string> headers = check getSignedHeadersAt({
        method: "GET",
        host: "example.amazonaws.com"
    }, tempCredentials, TEST_SIGNING_REGION, TEST_SIGNING_SERVICE, TEST_AMZ_DATE);

    test:assertEquals(headers["x-amz-security-token"], "IQoJb3JpZ2luX2VjEXAMPLETOKEN");
    string authorization = headers[AUTHORIZATION_HEADER] ?: "";
    test:assertTrue(authorization.includes("x-amz-security-token"),
        "The session token is expected to be included in SignedHeaders");
}

@test:Config {
    groups: ["signer"]
}
isolated function testGetSignedHeadersUnsignedPayload() returns error? {
    map<string> headers = check getSignedHeadersAt({
        method: "PUT",
        host: "examplebucket.s3.amazonaws.com",
        path: "/my-key",
        unsignedPayload: true,
        s3PathMode: true
    }, signerTestCredentials, TEST_SIGNING_REGION, "s3", TEST_AMZ_DATE);
    // Send the payload without signing it; the 'x-amz-content-sha256' header
    // carries the literal 'UNSIGNED-PAYLOAD'
    test:assertEquals(headers["x-amz-content-sha256"], "UNSIGNED-PAYLOAD");
}

@test:Config {
    groups: ["signer"]
}
isolated function testGetSignedHeadersPayloadAffectsSignature() returns error? {
    map<string> headersA = check getSignedHeadersAt({
        method: "POST",
        host: "sns.us-east-1.amazonaws.com",
        headers: {"content-type": "application/x-www-form-urlencoded"},
        payload: "Action=CreateTopic&Name=orders".toBytes()
    }, signerTestCredentials, TEST_SIGNING_REGION, "sns", TEST_AMZ_DATE);
    map<string> headersB = check getSignedHeadersAt({
        method: "POST",
        host: "sns.us-east-1.amazonaws.com",
        headers: {"content-type": "application/x-www-form-urlencoded"},
        payload: "Action=CreateTopic&Name=payments".toBytes()
    }, signerTestCredentials, TEST_SIGNING_REGION, "sns", TEST_AMZ_DATE);
    test:assertNotEquals(headersA[AUTHORIZATION_HEADER], headersB[AUTHORIZATION_HEADER]);
}

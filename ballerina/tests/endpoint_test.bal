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
    groups: ["endpoint"]
}
isolated function testStandardEndpoint() {
    test:assertEquals(resolveEndpoint("sns", US_EAST_1), "https://sns.us-east-1.amazonaws.com");
    test:assertEquals(resolveEndpoint("dynamodb", "eu-central-3"), "https://dynamodb.eu-central-3.amazonaws.com");
}

@test:Config {
    groups: ["endpoint"]
}
isolated function testChinaPartition() {
    test:assertEquals(resolveEndpoint("sns", CN_NORTH_1), "https://sns.cn-north-1.amazonaws.com.cn");
    test:assertEquals(resolveEndpoint("s3", CN_NORTHWEST_1, {dualstack: true}),
        "https://s3.dualstack.cn-northwest-1.amazonaws.com.cn");
}

@test:Config {
    groups: ["endpoint"]
}
isolated function testGovCloudPartition() {
    test:assertEquals(resolveEndpoint("sqs", US_GOV_WEST_1), "https://sqs.us-gov-west-1.amazonaws.com");
    test:assertEquals(resolveEndpoint("sqs", US_GOV_WEST_1, {fips: true}),
        "https://sqs.us-gov-west-1.amazonaws.com");
}

@test:Config {
    groups: ["endpoint"]
}
isolated function testFipsAndDualstackVariants() {
    test:assertEquals(resolveEndpoint("dynamodb", US_EAST_1, {fips: true}),
        "https://dynamodb-fips.us-east-1.amazonaws.com");
    test:assertEquals(resolveEndpoint("dynamodb", US_EAST_1, {dualstack: true}),
        "https://dynamodb.us-east-1.api.aws");
    test:assertEquals(resolveEndpoint("dynamodb", US_EAST_1, {fips: true, dualstack: true}),
        "https://dynamodb-fips.us-east-1.api.aws");
}

@test:Config {
    groups: ["endpoint"]
}
isolated function testCustomEndpointOverride() {
    test:assertEquals(resolveEndpoint("sqs", US_EAST_1, {customEndpoint: "http://localhost:4566", fips: true}),
        "http://localhost:4566");
}

@test:Config {
    groups: ["endpoint"]
}
isolated function testResolveEndpointHost() {
    test:assertEquals(resolveEndpointHost("sns", US_WEST_2), "sns.us-west-2.amazonaws.com");
    test:assertEquals(resolveEndpointHost("sqs", US_EAST_1, {customEndpoint: "http://localhost:4566"}),
        "localhost:4566");
}

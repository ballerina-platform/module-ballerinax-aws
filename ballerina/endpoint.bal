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

# Resolves the HTTPS endpoint URL for an AWS service in a region, using the
# AWS SDK's endpoint metadata (all partitions, FIPS/dualstack variants,
# per-service exceptions), with a standard-pattern fallback for regions newer
# than the bundled SDK. A `customEndpoint` overrides both.
# ```ballerina
# string url = auth:resolveEndpoint("sns", auth:US_EAST_1);
# // "https://sns.us-east-1.amazonaws.com"
#
# string testUrl = auth:resolveEndpoint("sqs", auth:US_EAST_1, {customEndpoint: "http://localhost:4566"});
# // "http://localhost:4566"
# ```
#
# + serviceName - The service's endpoint prefix (e.g. `sns`, `dynamodb`)
# + region - Target region
# + config - Endpoint options
# + return - The endpoint URL (e.g. `https://sns.us-east-1.amazonaws.com`)
public isolated function resolveEndpoint(string serviceName, Region|string region,
        EndpointConfig config = {}) returns string {
    string? customEndpoint = config?.customEndpoint;
    if customEndpoint is string {
        return customEndpoint;
    }
    string|error host = externResolveEndpointHost(serviceName, region, config.fips, config.dualstack);
    if host is string && host != "" {
        return "https://" + host;
    }
    // Fallback: standard pattern construction for services/regions unknown to
    // the bundled SDK metadata.
    string hostPrefix = config.fips ? serviceName + "-fips" : serviceName;
    return "https://" + hostPrefix + "." + region + "." + dnsSuffix(region, config.dualstack);
}

# Resolves only the host part of the endpoint — useful for request signing.
# ```ballerina
# string host = auth:resolveEndpointHost("sns", auth:US_EAST_1);
# // "sns.us-east-1.amazonaws.com"
# ```
#
# + serviceName - The service's endpoint prefix (e.g. `sns`, `dynamodb`)
# + region - Target region
# + config - Endpoint options; a `customEndpoint` is returned with its scheme stripped
# + return - The endpoint host (e.g. `sns.us-east-1.amazonaws.com`)
public isolated function resolveEndpointHost(string serviceName, Region|string region,
        EndpointConfig config = {}) returns string {
    string endpoint = resolveEndpoint(serviceName, region, config);
    if endpoint.startsWith("https://") {
        return endpoint.substring(8);
    }
    if endpoint.startsWith("http://") {
        return endpoint.substring(7);
    }
    return endpoint;
}

# Returns the partition DNS suffix, derived from the region code prefix.
#
# + regionCode - The region code (e.g. `us-east-1`, `cn-north-1`)
# + dualstack - Whether the dualstack variant is requested
# + return - The DNS suffix (e.g. `amazonaws.com`)
isolated function dnsSuffix(string regionCode, boolean dualstack) returns string {
    if regionCode.startsWith("cn-") {
        return dualstack ? "api.amazonwebservices.com.cn" : "amazonaws.com.cn";
    }
    return dualstack ? "api.aws" : "amazonaws.com";
}

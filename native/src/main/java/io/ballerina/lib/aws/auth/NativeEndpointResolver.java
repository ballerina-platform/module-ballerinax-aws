/*
 * Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.aws.auth;

import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BString;
import software.amazon.awssdk.regions.EndpointTag;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.regions.ServiceEndpointKey;
import software.amazon.awssdk.regions.ServiceMetadata;

import java.util.ArrayList;
import java.util.List;

/**
 * Endpoint resolution backed by the AWS SDK's embedded endpoint metadata
 * ({@link ServiceMetadata} from the {@code regions} artifact)
 */
public final class NativeEndpointResolver {

    private NativeEndpointResolver() {
    }

    /**
     * Resolves the endpoint host for a service in a region.
     *
     * @param serviceName the service endpoint prefix, e.g. {@code dynamodb}
     * @param region      the region code, e.g. {@code us-east-1}
     * @param fips        whether the FIPS endpoint variant is requested
     * @param dualstack   whether the dualstack endpoint variant is requested
     * @return the endpoint host as a Ballerina string (no scheme), or a
     * Ballerina {@code aws.auth:Error} if the bundled metadata cannot resolve
     * it (the caller falls back to pattern construction)
     */
    public static Object resolveEndpointHost(BString serviceName, BString region, boolean fips, boolean dualstack) {
        try {
            List<EndpointTag> tags = new ArrayList<>(2);
            if (fips) {
                tags.add(EndpointTag.FIPS);
            }
            if (dualstack) {
                tags.add(EndpointTag.DUALSTACK);
            }
            String host = ServiceMetadata.of(serviceName.getValue())
                    .endpointFor(ServiceEndpointKey.builder()
                            .region(Region.of(region.getValue()))
                            .tags(tags)
                            .build())
                    .toString();
            if (host == null || host.isEmpty()) {
                return CommonUtils.createError("No endpoint metadata found for the given service and region",
                        new IllegalStateException("Empty endpoint metadata result"));
            }
            return StringUtils.fromString(host);
        } catch (Exception e) {
            String errorMsg = String.format("Error occurred while resolving the endpoint from SDK metadata: %s",
                    e.getMessage());
            return CommonUtils.createError(errorMsg, e);
        }
    }
}

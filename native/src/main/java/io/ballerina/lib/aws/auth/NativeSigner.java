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

import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MapType;
import io.ballerina.runtime.api.types.PredefinedTypes;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;
import software.amazon.awssdk.http.ContentStreamProvider;
import software.amazon.awssdk.http.SdkHttpMethod;
import software.amazon.awssdk.http.SdkHttpRequest;
import software.amazon.awssdk.http.auth.aws.signer.AwsV4HttpSigner;
import software.amazon.awssdk.http.auth.spi.signer.HttpSigner;
import software.amazon.awssdk.http.auth.spi.signer.SignedRequest;
import software.amazon.awssdk.identity.spi.AwsCredentialsIdentity;
import software.amazon.awssdk.identity.spi.AwsSessionCredentialsIdentity;
import software.amazon.awssdk.utils.http.SdkHttpUtils;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * AWS Signature Version 4 signing implementation that delegate to
 * the AWS SDK v2 {@link AwsV4HttpSigner}
 */
public final class NativeSigner {

    private static final AwsV4HttpSigner SIGNER = AwsV4HttpSigner.create();

    private static final BString METHOD = StringUtils.fromString("method");
    private static final BString HOST = StringUtils.fromString("host");
    private static final BString PATH = StringUtils.fromString("path");
    private static final BString QUERY_PARAMS = StringUtils.fromString("queryParams");
    private static final BString HEADERS = StringUtils.fromString("headers");
    private static final BString PAYLOAD = StringUtils.fromString("payload");
    private static final BString UNSIGNED_PAYLOAD = StringUtils.fromString("unsignedPayload");
    private static final BString S3_PATH_MODE = StringUtils.fromString("s3PathMode");
    private static final BString ACCESS_KEY_ID = StringUtils.fromString("accessKeyId");
    private static final BString SECRET_ACCESS_KEY = StringUtils.fromString("secretAccessKey");
    private static final BString SESSION_TOKEN = StringUtils.fromString("sessionToken");

    private static final DateTimeFormatter AMZ_DATE_FORMAT =
            DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'");

    private NativeSigner() {
    }

    /**
     * Signs the given request description with the AWS SDK SigV4 signer and
     * returns the headers to set on the outbound request.
     *
     * @param bRequest     the Ballerina {@code SignatureRequest} record
     * @param bCredentials the Ballerina {@code Credentials} record
     * @param region       the target region code
     * @param serviceName  the signing name of the target service
     * @return a Ballerina {@code map<string>} of headers, or a Ballerina
     * {@code aws.auth:SigningError}
     */
    public static Object getSignedHeaders(BMap<BString, Object> bRequest, BMap<BString, Object> bCredentials,
                                          BString region, BString serviceName) {
        return sign(bRequest, bCredentials, region, serviceName, null);
    }

    /**
     * Test-only entry point: signs with the signing clock pinned to the given
     * timestamp, the output is deterministic and verifiable against the AWS
     * SigV4 test vectors. Invoked from the module's test sources.
     *
     * @param bRequest     the Ballerina {@code SignatureRequest} record
     * @param bCredentials the Ballerina {@code Credentials} record
     * @param region       the target region code
     * @param serviceName  the signing name of the target service
     * @param amzDate      fixed timestamp ({@code yyyyMMdd'T'HHmmss'Z'})
     * @return a Ballerina {@code map<string>} of headers, or a Ballerina
     * {@code aws.auth:SigningError}
     */
    public static Object getSignedHeadersWithFixedTime(BMap<BString, Object> bRequest,
                                                       BMap<BString, Object> bCredentials,
                                                       BString region, BString serviceName, BString amzDate) {
        return sign(bRequest, bCredentials, region, serviceName, amzDate);
    }

    @SuppressWarnings("unchecked")
    private static Object sign(BMap<BString, Object> bRequest, BMap<BString, Object> bCredentials,
                               BString region, BString serviceName, BString fixedAmzDate) {
        try {
            AwsCredentialsIdentity identity = toIdentity(bCredentials);
            boolean s3PathMode = bRequest.getBooleanValue(S3_PATH_MODE);
            boolean unsignedPayload = bRequest.getBooleanValue(UNSIGNED_PAYLOAD);
            byte[] payload = ((BArray) bRequest.get(PAYLOAD)).getBytes();

            SdkHttpRequest.Builder httpRequest = SdkHttpRequest.builder()
                    .method(SdkHttpMethod.fromValue(bRequest.getStringValue(METHOD).getValue()))
                    // The scheme never enters the signature. Added because SdkHttpRequest
                    // refuses to build without a complete, valid URI.
                    .protocol("https")
                    .host(bRequest.getStringValue(HOST).getValue())
                    .encodedPath(SdkHttpUtils.urlEncodeIgnoreSlashes(
                            bRequest.getStringValue(PATH).getValue()));
            BMap<BString, Object> queryParams = (BMap<BString, Object>) bRequest.getMapValue(QUERY_PARAMS);
            for (Map.Entry<BString, Object> entry : queryParams.entrySet()) {
                httpRequest.putRawQueryParameter(entry.getKey().getValue(), entry.getValue().toString());
            }
            BMap<BString, Object> headers = (BMap<BString, Object>) bRequest.getMapValue(HEADERS);
            for (Map.Entry<BString, Object> entry : headers.entrySet()) {
                httpRequest.appendHeader(entry.getKey().getValue(), entry.getValue().toString());
            }

            SignedRequest signed = SIGNER.sign(r -> {
                r.identity(identity)
                        .request(httpRequest.build())
                        .payload(ContentStreamProvider.fromByteArray(payload))
                        .putProperty(AwsV4HttpSigner.SERVICE_SIGNING_NAME, serviceName.getValue())
                        .putProperty(AwsV4HttpSigner.REGION_NAME, region.getValue())
                        .putProperty(AwsV4HttpSigner.DOUBLE_URL_ENCODE, !s3PathMode)
                        .putProperty(AwsV4HttpSigner.NORMALIZE_PATH, !s3PathMode)
                        .putProperty(AwsV4HttpSigner.PAYLOAD_SIGNING_ENABLED, !unsignedPayload);
                if (fixedAmzDate != null) {
                    Clock fixedClock = Clock.fixed(LocalDateTime
                            .parse(fixedAmzDate.getValue(), AMZ_DATE_FORMAT)
                            .toInstant(ZoneOffset.UTC), ZoneOffset.UTC);
                    r.putProperty(HttpSigner.SIGNING_CLOCK, fixedClock);
                }
            });

            MapType mapType = TypeCreator.createMapType(PredefinedTypes.TYPE_STRING);
            BMap<BString, Object> result = ValueCreator.createMapValue(mapType);
            for (Map.Entry<String, List<String>> header : signed.request().headers().entrySet()) {
                if ("host".equalsIgnoreCase(header.getKey())) {
                    continue;
                }
                // HTTP header names are normalize to lowercase so map lookups
                // on the returned headers are deterministic.
                result.put(StringUtils.fromString(header.getKey().toLowerCase(Locale.ROOT)),
                        StringUtils.fromString(String.join(",", header.getValue())));
            }
            return result;
        } catch (Exception e) {
            String errorMsg = String.format("Error occurred while signing the request with the AWS SDK signer: %s",
                    e.getMessage());
            return CommonUtils.createSigningError(errorMsg, e);
        }
    }

    private static AwsCredentialsIdentity toIdentity(BMap<BString, Object> bCredentials) {
        String accessKeyId = bCredentials.getStringValue(ACCESS_KEY_ID).getValue();
        String secretAccessKey = bCredentials.getStringValue(SECRET_ACCESS_KEY).getValue();
        if (bCredentials.containsKey(SESSION_TOKEN)) {
            return AwsSessionCredentialsIdentity.create(accessKeyId, secretAccessKey,
                    bCredentials.getStringValue(SESSION_TOKEN).getValue());
        }
        return AwsCredentialsIdentity.create(accessKeyId, secretAccessKey);
    }
}

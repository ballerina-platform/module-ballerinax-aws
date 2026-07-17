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

import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import software.amazon.awssdk.auth.credentials.AwsCredentials;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.AwsSessionCredentials;

/**
 * Native implementation of the Ballerina {@code aws.auth:CredentialProvider} class.
 */
public final class NativeCredentialProvider {

    private static final String NATIVE_PROVIDER = "nativeProvider";

    private static final String CREDENTIALS_RECORD = "Credentials";
    private static final BString CREDENTIALS_ACCESS_KEY_ID = StringUtils.fromString("accessKeyId");
    private static final BString CREDENTIALS_SECRET_ACCESS_KEY = StringUtils.fromString("secretAccessKey");
    private static final BString CREDENTIALS_SESSION_TOKEN = StringUtils.fromString("sessionToken");

    private NativeCredentialProvider() {
    }

    /**
     * Builds the AWS credentials provider for the given configuration and
     * attaches it to the Ballerina object as native data.
     */
    public static Object initProvider(BObject bProvider, Object bConfig) {
        try {
            AwsCredentialsProvider provider = ProviderFactory.buildProvider(bConfig);
            bProvider.addNativeData(NATIVE_PROVIDER, provider);
            return null;
        } catch (Exception e) {
            return CommonUtils.createCredentialResolutionError("initializing the credential provider", e);
        }
    }

    /**
     * Resolves currently-valid credentials from the stored provider,
     * refreshing expiring ones transparently.
     */
    public static Object getCredentials(BObject bProvider) {
        Object provider = bProvider.getNativeData(NATIVE_PROVIDER);
        if (!(provider instanceof AwsCredentialsProvider credentialsProvider)) {
            return CommonUtils.createCredentialResolutionError("resolving the AWS credentials",
                    new IllegalStateException("Credential provider is not initialized or already closed"));
        }
        try {
            AwsCredentials credentials = credentialsProvider.resolveCredentials();
            BMap<BString, Object> result = ValueCreator.createRecordValue(
                    ModuleUtils.getModule(), CREDENTIALS_RECORD);
            result.put(CREDENTIALS_ACCESS_KEY_ID, StringUtils.fromString(credentials.accessKeyId()));
            result.put(CREDENTIALS_SECRET_ACCESS_KEY, StringUtils.fromString(credentials.secretAccessKey()));
            if (credentials instanceof AwsSessionCredentials sessionCredentials) {
                result.put(CREDENTIALS_SESSION_TOKEN, StringUtils.fromString(sessionCredentials.sessionToken()));
            }
            return result;
        } catch (Exception e) {
            return CommonUtils.createCredentialResolutionError("resolving the AWS credentials", e);
        }
    }
    /**
     * Releases the resources held by the stored credentials provider
     * (background refresh threads, HTTP connections) when the provider
     * holds closeable resources.
     *
     * @param bProvider the Ballerina {@code CredentialProvider} object
     * @return {@code null} on success, or a Ballerina {@code aws.auth:Error}
     */
    public static Object close(BObject bProvider) {
        Object provider = bProvider.getNativeData(NATIVE_PROVIDER);
        try {
            if (provider instanceof AwsCredentialsProvider credentialsProvider) {
                ProviderFactory.closeProvider(credentialsProvider);
            }
            // Clear the stale reference
            bProvider.addNativeData(NATIVE_PROVIDER, null);
            return null;
        } catch (Exception e) {
            return CommonUtils.createError("closing the credential provider", e);
        }
    }
}

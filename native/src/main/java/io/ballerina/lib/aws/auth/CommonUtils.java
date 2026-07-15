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

import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;
import software.amazon.awssdk.awscore.exception.AwsErrorDetails;
import software.amazon.awssdk.awscore.exception.AwsServiceException;
import software.amazon.awssdk.http.SdkHttpResponse;

import java.util.Objects;

/**
 * Common utility functions for the Ballerina AWS Auth module.
 */
final class CommonUtils {
    private static final String ERROR = "Error";
    private static final String CREDENTIAL_RESOLUTION_ERROR = "CredentialResolutionError";
    private static final String SIGNING_ERROR = "SigningError";
    private static final String ERROR_DETAILS = "ErrorDetails";
    private static final BString ERROR_DETAILS_HTTP_STATUS_CODE = StringUtils.fromString("httpStatusCode");
    private static final BString ERROR_DETAILS_HTTP_STATUS_TEXT = StringUtils.fromString("httpStatusText");
    private static final BString ERROR_DETAILS_ERROR_CODE = StringUtils.fromString("errorCode");
    private static final BString ERROR_DETAILS_ERROR_MESSAGE = StringUtils.fromString("errorMessage");

    private CommonUtils() {
    }

    /**
     * Creates the common {@code aws.auth:Error}.
     */
    static BError createError(String message, Throwable exception) {
        BError cause = ErrorCreator.createError(exception);
        return ErrorCreator.createError(
                ModuleUtils.getModule(), ERROR, StringUtils.fromString(message), cause, null);
    }

    /**
     * Creates an {@code aws.auth:CredentialResolutionError}, attaching the AWS
     * service error details when available.
     */
    static BError createCredentialResolutionError(String message, Throwable exception) {
        BError cause = ErrorCreator.createError(exception);
        BMap<BString, Object> errorDetails = ValueCreator.createRecordValue(
                ModuleUtils.getModule(), ERROR_DETAILS);
        if (exception instanceof AwsServiceException awsServiceException &&
                Objects.nonNull(awsServiceException.awsErrorDetails())) {
            AwsErrorDetails awsErrorDetails = awsServiceException.awsErrorDetails();
            SdkHttpResponse sdkResponse = awsErrorDetails.sdkHttpResponse();
            if (Objects.nonNull(sdkResponse)) {
                errorDetails.put(ERROR_DETAILS_HTTP_STATUS_CODE, sdkResponse.statusCode());
                sdkResponse.statusText().ifPresent(httpStatusTxt -> errorDetails.put(
                        ERROR_DETAILS_HTTP_STATUS_TEXT, StringUtils.fromString(httpStatusTxt)));
            }
            errorDetails.put(ERROR_DETAILS_ERROR_CODE, StringUtils.fromString(awsErrorDetails.errorCode()));
            errorDetails.put(ERROR_DETAILS_ERROR_MESSAGE, StringUtils.fromString(awsErrorDetails.errorMessage()));
        }
        return ErrorCreator.createError(ModuleUtils.getModule(), CREDENTIAL_RESOLUTION_ERROR,
                StringUtils.fromString(message), cause, errorDetails);
    }

    /**
     * Creates an {@code aws.auth:SigningError}.
     */
    static BError createSigningError(String message, Throwable exception) {
        BError cause = ErrorCreator.createError(exception);
        return ErrorCreator.createError(
                ModuleUtils.getModule(), SIGNING_ERROR, StringUtils.fromString(message), cause, null);
    }
}

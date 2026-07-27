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

import io.ballerina.lib.aws.ErrorUtils;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;

/**
 * Common utility functions for the Ballerina AWS Auth module.
 */
final class CommonUtils {
    private static final String ERROR = "Error";
    private static final String CREDENTIAL_RESOLUTION_ERROR = "CredentialResolutionError";
    private static final String SIGNING_ERROR = "SigningError";

    private CommonUtils() {
    }

    /**
     * Creates the common {@code aws.auth:Error}.
     *
     * @param action    what was being attempted, e.g. {@code "closing the credential provider"}
     * @param exception the exception that was caught
     */
    static BError createError(String action, Throwable exception) {
        BError cause = ErrorCreator.createError(exception);
        return ErrorCreator.createError(
                ModuleUtils.getModule(), ERROR, StringUtils.fromString(message(action)), cause, null);
    }

    /**
     * Creates an {@code aws.auth:CredentialResolutionError}, attaching the AWS
     * service error details when available.
     */
    static BError createCredentialResolutionError(String action, Throwable exception) {
        BError cause = ErrorCreator.createError(exception);
        BMap<BString, Object> errorDetails = ErrorUtils.createErrorDetails(exception);
        return ErrorCreator.createError(ModuleUtils.getModule(), CREDENTIAL_RESOLUTION_ERROR,
                StringUtils.fromString(message(action)), cause, errorDetails);
    }

    /**
     * Creates an {@code aws.auth:SigningError}.
     */
    static BError createSigningError(String action, Throwable exception) {
        BError cause = ErrorCreator.createError(exception);
        return ErrorCreator.createError(
                ModuleUtils.getModule(), SIGNING_ERROR, StringUtils.fromString(message(action)), cause, null);
    }

    private static String message(String action) {
        return "Error occurred while " + action;
    }
}

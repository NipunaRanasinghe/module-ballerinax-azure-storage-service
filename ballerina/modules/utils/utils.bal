// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/crypto;
import ballerina/jballerina.java;
import ballerina/lang.array;
import ballerina/time;

# Get current date and time string.
# 
# + return - Returns current date and time string
public isolated function getCurrentDate() returns string { 
    [int, decimal] & readonly currentTime = time:utcNow(); 
    return checkpanic utcToString(currentTime, STORAGE_SERVICE_DATE_FORMAT);
}

isolated function utcToString(time:Utc utc, string pattern) returns string|error {
    [int, decimal][epochSeconds, lastSecondFraction] = utc;
    int nanoAdjustments = (<int>lastSecondFraction * 1000000000);
    var instant = ofEpochSecond(epochSeconds, nanoAdjustments);
    var zoneId = getZoneId(java:fromString(GMT));
    var zonedDateTime = atZone(instant, zoneId);
    var dateTimeFormatter = ofPattern(java:fromString(pattern));
    handle formatString = format(zonedDateTime, dateTimeFormatter);
    return formatString.toBalString();
}

# Generate canonicalized header string from a header map.
#
# + headers - Map of http request headers
# + return - Returns calonocalized header string
public isolated function generateCanonicalizedHeadersString(map<string> headers) returns string {
    string result = EMPTY_STRING;
    string[] allHeaderNames = array:sort(headers.keys());
    foreach string header in allHeaderNames {
        if (header.indexOf(X_MS) == 0) {
            result = result + header.toLowerAscii()+ COLON_SYMBOL + headers.get(header) + NEW_LINE;
        }
    }
    return result;
}

# Generate uri parameters string from a uriParameters map.
#
# + uriParameters - Map of uri parameters
# + return - Returns uri parameter string for shared key
public isolated function generateUriParamStringForSharedKey(map<string> uriParameters) returns string {
    string result = EMPTY_STRING;
    string[] allURIParams = array:sort(uriParameters.keys());
    foreach string uriParameter in allURIParams {
        result = result + NEW_LINE + uriParameter + COLON_SYMBOL + uriParameters.get(uriParameter);
    }
    return result;
}

# Generate signature for Shared Key Authorization method.
#
# + headers - Map of http request headers and values 
# + uriParameters - Map of uri parameters  
# + accountName - Azure storage account name 
# + resourcePath - Resource path  
# + verb - Http verb  
# + accountKey - Azure storage account key
# + return - If successful, returns shared key signature. Else returns error.
public isolated function generateSharedKeySignature (string accountName, string accountKey, string verb, 
                                                        string resourcePath, map<string> uriParameters, 
                                                        map<string> headers) returns string|error {                     
    string canonicalozedHeaders = generateCanonicalizedHeadersString(headers);
    string uriParameterString = generateUriParamStringForSharedKey(uriParameters);
    string canonicalizedResources = FORWARD_SLASH_SYMBOL + accountName + FORWARD_SLASH_SYMBOL + resourcePath 
        + uriParameterString;

    string contentEncoding = EMPTY_STRING;
    if (headers.hasKey(CONTENT_ENCODING)) {
        contentEncoding  =  headers.get(CONTENT_ENCODING);
    }

    string contentLanguage = EMPTY_STRING;
    if (headers.hasKey(CONTENT_LANGUAGE)) {
        contentLanguage  =  headers.get(CONTENT_LANGUAGE);
    }

    string contentLength = EMPTY_STRING;
    if (headers.hasKey(CONTENT_LENGTH)) {
        // If content-length is 0, it should be an empty string
        contentLength  =  headers.get(CONTENT_LENGTH);
        if (contentLength == ZERO) {
            contentLength = EMPTY_STRING;
        }
    }

    string contentMD5 = EMPTY_STRING;
    if (headers.hasKey(CONTENT_MD5)) {
        contentMD5  =  headers.get(CONTENT_MD5);
    }

    string contentType = EMPTY_STRING;
    if (headers.hasKey(CONTENT_TYPE)) {
        contentType  =  headers.get(CONTENT_TYPE);
    }

    // Since x-ms-date header is added for all the requests, this header is not required.
    // Even this header is provided as an optional header by the user, azure will ignore this and take x-ms-date
    string date = EMPTY_STRING;
    if (headers.hasKey(DATE)) {
        date  =  headers.get(DATE);
    }

    string ifModifiedSince = EMPTY_STRING;
    if (headers.hasKey(IF_MODIFIED_SINCE)) {
        ifModifiedSince  =  headers.get(IF_MODIFIED_SINCE);
    }

    string ifMatch = EMPTY_STRING;
    if (headers.hasKey(IF_MATCH)) {
        ifMatch  =  headers.get(IF_MATCH);
    }

    string ifNoneMatch = EMPTY_STRING;
    if (headers.hasKey(IF_NONE_MATCH)) {
        ifNoneMatch  =  headers.get(IF_NONE_MATCH);
    }

    string ifUnmodifiedSince = EMPTY_STRING;
    if (headers.hasKey(IF_UNMODIFIED_SINCE)) {
        ifUnmodifiedSince  =  headers.get(IF_UNMODIFIED_SINCE);
    }

    string range = EMPTY_STRING;
    if (headers.hasKey(RANGE)) {
        range  =  headers.get(RANGE);
    }

    string stringToSign = verb.toUpperAscii() + NEW_LINE + contentEncoding + NEW_LINE + contentLanguage + NEW_LINE
        + contentLength + NEW_LINE + contentMD5 + NEW_LINE + contentType + NEW_LINE + date + NEW_LINE + ifModifiedSince 
        + NEW_LINE + ifMatch + NEW_LINE + ifNoneMatch + NEW_LINE + ifUnmodifiedSince + NEW_LINE + range + NEW_LINE 
        + canonicalozedHeaders + canonicalizedResources;
    return array:toBase64(check crypto:hmacSha256(stringToSign.toBytes(), check array:fromBase64(accountKey)));
}

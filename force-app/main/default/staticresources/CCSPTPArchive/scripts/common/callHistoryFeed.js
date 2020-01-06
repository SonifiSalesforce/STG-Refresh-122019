/**
 * @file Where the customization for Call History feed is placed.
 */

/**
 * @description Wrapup data feed for NECF.
 * @function createCallHistoryFeed
 * @param {Object} callDataHelper provides methods for retrieving call property from callData.
 * @param {Object} calllInfo
 * @param {Object} calllData
 * @param {Object} wrapupData
 * @param {Object} userData currently we put chat transcript if call is of chat.
 * @param {Object} pageInfo
 * @optional {String} id - id param (send it when you want to UPDATE object with ID specified)
 * @optional {Bool} isInConsole 
 * @return {object} should return object which will be set into saveLog().
 */
function createCallHistoryFeed(callDataHelper, callInfo, callData, wrapupData, userData, pageInfo, id, isInConsole) {

    // Status standard -- const "Completed"
    // Subject standard -- const"Telephone"
    // Phone standard -- CallerANI or DialedTelephoneNumber
    // DNIS__c custom -- CallerDNIS (empty for dialer call)
    // CallType standard -- "Incoming", "Outgoing", "Preview", or "Predictive"
    // ActivityDate standard -- timestamp
    // CallStartTime__c custom -- call start time
    // CallEndTime__c custom -- call end time
    // CallDurationInSeconds custom -- call duration
    // CallObject standard(?) -- callId
    // CallDisposition standard -- wrapup code
    // WrapupComment custom -- wrapup comment
    // SEQNO__c custom -- from dialer record

    try {
        log.debug("createWrapUpSaveLogData: enter");

        var dialerRecord = null;

        if (callInfo.direction === "Predictive" || callInfo.direction === "Preview") {
            dialerRecord = callDataHelper.getDialerRecord(callData);
        }

        // utc1 and utc2 both to be timestamp string in ISO format.
        function timeDiffInSeconds(utc1, utc2) {
            try {
                var d1 = Date.parse(utc1);
                var d2 = Date.parse(utc2);
                // wanted to use Math.trunc() but not supported on IE.
                return parseInt((d2 - d1) / 1000, 10);
            } catch (e) {
                log.error("timeDiffInSeconds: error: " + e.message);
                return 0;
            }
        }

        // get datetime formatted for Salesforce ("yyyy-MM-dd HH:mm:ss") from ISO format.
        function getDateTime(dt) {
            // simplest one would be dt.replace("T", " ")
            return dt.replace(/(.*)T(.*)[\.].*/, function(match, p1, p2) {
                return [p1, p2].join(" ");
            });
        }

        // get date string for ActivityDate -- "yyyy-MM-dd 00:00:00".
        // date part is in local time, not in UTC/GMT, accorindg to a post https://success.salesforce.com/ideaView?id=08730000000jEaLAAU.
        function getActivityDate(dt) {
            var year = dt.getFullYear(),
                month = dt.getMonth() + 1,
                day = dt.getDate();
            return [year, month < 10 ? "0" + month : month, day < 10 ? "0" + day : day].join("-") + " 00:00:00";
        }

        function getChatTranscript(chatTranscript) {
            // chatTranscript is array of following object;
            //  "sender": [sender (such as Agent, Caller, Supervisor, and Me.]
            //  "chatLine": [chat text],
            //  "time": time-stamp 

            if (!$.isArray(chatTranscript)) {
                return "";
            }
            var index, line, text = "",
                maxIndex = chatTranscript.length;
            for (index = 0; index < maxIndex; index++) {
                line = chatTranscript[index];
                text = text + line.sender + ": " + line.chatLine + "\n";
            }
            return text;
        }

        function translateHistoryText(text) {
            if (typeof translator !== "undefined" && translator.callHistoryText) {
                return translator.callHistoryText(text);
            }
            return text;
        }

        function translateFromTo(text) {
            if (typeof translator !== "undefined" && translator.callFromToText) {
                return translator.callFromToText(text);
            }
            return text;
        }

        // helper object building up the query string for saveLog().
        var params = {};

        // get current date/time for parameters ActivityDate, CallStartTime__c, and CallEndTime__c.
        var now = new Date();

        // Status
        params.Status = translateHistoryText("Completed")

        // Subject
        if (!isInConsole) {
            var subject = typeof translator === "undefined" ? callInfo.mediaType : translator.mediaType(callInfo.mediaType);
            params.Subject = subject + ' Call ' + getDateTime(callData.CtcCallStartTime || now.toISOString());
        }

        // Phone__c and DNIS__c
        var phone_c;
        var dnis_c;
        if (dialerRecord || callInfo.direction === "Outgoing") {
            phone_c = translateFromTo(callInfo.to);
            dnis_c = ""; // we do not know what DNIS is used for manual outbound call or dialer call.
        } else {
            phone_c = translateFromTo(callInfo.from);
            dnis_c = translateFromTo(callInfo.to);
        }

        params.Phone__c = phone_c;
        params.DNIS__c = dnis_c;

        // CallType -- Inbound or Outbound.
        var callType;
        if (callInfo.direction === "Outgoing" || callInfo.direction === "Predictive" || callInfo.direction === "Preview") {
            callType = "Outbound";
        } else {
            callType = "Inbound";
        }
        params.CallType = callType;

        // CallType__c -- have it translated.
        var callType_c = translator.callDirection(callInfo.direction);
        params.CallType__c = callType_c;

        // ActivityDate -- set today mid-night in local time, according to https://success.salesforce.com/ideaView?id=08730000000jEaLAAU.
        params.ActivityDate = getActivityDate(now);

        // CallStartTime__c custom
        var callStartTime_c = callData.CtcCallStartTime || now.toISOString();
        params.CallStartTime__c = getDateTime(callStartTime_c);

        // CallEndTime__c custom -- call end time
        var callEndTime_c = callData.CtcCallEndTime || now.toISOString();
        params.CallEndTime__c = getDateTime(callEndTime_c);

        // CallDurationInSeconds custom -- call duration
        var callDurationInSeconds = timeDiffInSeconds(callStartTime_c, callEndTime_c);
        params.CallDurationInSeconds = callDurationInSeconds;

        // CallObject standard(?) -- callId in hex.
        var callObject = callInfo.callIdHex;
        params.CallObject = callObject;

        // CallDisposition
        var callDisposition = wrapupData.name; // or wrapupData.code
        params.CallDisposition = callDisposition;

        // WrapupComment custom -- wrapup comment
        var comment = "WrapUp: " + wrapupData.name + "(" + wrapupData.code + ")" + "\nComment: " + wrapupData.comment;
        params.WrapupComment__c = comment;

        // SEQNO__c custom -- from dialer record
        var seqno_c = "";
        if (dialerRecord) {
            seqno_c = callDataHelper.getDialerDataByName(dialerRecord, "SEQNO");
            params.SEQNO__c = seqno_c, true;
        }

        // ChatTranscript__c
        if (userData && userData.length > 0) {
            params.ChatTranscript__c = getChatTranscript(userData);
        }

        var objId = sfLoad_.isLightning ? pageInfo.recordId : pageInfo.objectId;
        if (objId) {
            if (objId.substr(0, 3) == '003' || pageInfo.object === "Lead" || pageInfo.objectType === "Lead") {
                params.WhoId = objId;
            } else {
                params.WhatId = objId;
            }
        }

        if (id) {
            params.Id = id;
        }

        //Following try scope related only to CCSP developer's environments
        try {
            if (shouldAppedNamespace) {
                for (var propertyName in params) {
                    if (params.hasOwnProperty(propertyName) && propertyName.includes('__c')) {
                        params[namespaceToAppend + propertyName] = params[propertyName];
                    }
                }
            }
        } catch (e) {
            console.log("Error occured while trying to append namespace: ", e);
        }


        return params;
    } catch (e) {
        log.error("createCallHistoryFeed: error: " + e.message);
        return "";
    }
}
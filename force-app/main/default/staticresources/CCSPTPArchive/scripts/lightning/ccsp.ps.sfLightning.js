/**
 * @file ccsp.ps.sfLightning.js
 * @description Salesforce CTI wrapper.
 * @copyright Enghouse Interactive, 2018
 */

window.CCSPIntegration = window.CCSPIntegration || {};

CCSPIntegration.sfLghtCti = CCSPIntegration.sfLghtCti || {};

CCSPIntegration.sfLghtCti.config = (function() {

    log.trace("CCSPIntegration.sfLghtCti.config");
    var dontUseSessionStorage = true;
    var configLoaded = false;
    var callcenterConfig = null;
    var userConfig = null;
    var configRetrievalTimeout = 10000;

    function checkPropertiesExist(target, name) {
        var i;
        for (i = 2; i < arguments.length; i++) {
            if (typeof target[arguments[i]] === 'undefined') {
                throw new Error('property [' + arguments[i] + '] is not configured in ' + name);
            }
        }
    }

    function saveToStorage(storage, prefix, o) {
        var p, n;
        if (dontUseSessionStorage) return;

        storage.setItem(prefix + "item", JSON.stringify(o));
        // add flag to mark that parameter have been saved.
        storage.setItem(prefix + "saved", "saved");
    }

    function getConfiguration(prefix, request, retrieve, restore) {
        var d = $.Deferred(),
            config = null;
        var configRetrievalTimer;

        if (window.sessionStorage && !dontUseSessionStorage) {
            config = restore(prefix, window.sessionStorage);
            if (config) {
                d.resolve(config);
                return d.promise();
            }
        }

        // set timeout for the case not runing under Salesforce or the browser is configured to call Salesforce.
        if (configRetrievalTimeout > 0) {
            configRetrievalTimer = window.setTimeout(
                function() {
                    d.reject("Timed out in waiting response from Salesforce. Possibly not running under Salesforce environment, or thr browser is not configured to call Salesforce API.");
                },
                configRetrievalTimeout);
        }

        var callback = (function(deferred, retrieve) {
            return function(response) {
                var errorMessage, settings, config;
                if (configRetrievalTimer) {
                    window.clearTimeout(configRetrievalTimer);
                }

                if (response && response.success) {
                    try {
                        settings = response.returnValue;
                        config = retrieve(prefix, settings, window.sessionStorage);
                        deferred.resolve(config);
                    } catch (e) {
                        errorMessage = "Error when parsing response.returnValue. " + e.description ? e.description : e;
                        deferred.reject(errorMessage);
                    }
                } else {
                    errorMessage = JSON.stringify(response.error) || JSON.stringify(response.errors) || "Error description not provided.";
                    deferred.reject(errorMessage);
                }

            };
        })(d, retrieve);

        request(callback);
        return d.promise();
    }

    function getCallCenterConfiguration() {
        var prefix = "callcenter_";
        var request = function(callback) {
            sforce.opencti.getCallCenterSettings({ callback: callback });
        }

        function getCustomOptions(settings) {
            var tag = "/customOptions/",
                tagLength = tag.length;
            var propertyName, optionName;
            var config = {};

            for (propertyName in settings) {
                if (propertyName.indexOf(tag) === 0) {
                    optionName = propertyName.substring(tagLength);
                    if (optionName.length > 0) {
                        config[optionName] = settings[propertyName];
                    }
                }
            }
            return config;
        }

        var retrieve = function(prefix, settings, storage) {
            var config = null;
            var serverUrlParam = "/ServerInfo/CTCServerName";
            checkPropertiesExist(settings, "CallCenterSettings", serverUrlParam);

            config = {};
            config.ctiServerUrl = settings[serverUrlParam];
            config.customOptions = getCustomOptions(settings);
            config.searchOptions = config.customOptions.searchOptions || "";

            if (storage) {
                saveToStorage(storage, prefix, config);
            }
            return config;
        }

        var restore = function(prefix, storage) {
            if (typeof storage === 'undefined' || storage.getItem(prefix + "saved") !== "saved") {
                return null;
            }

            try {
                var config = JSON.parse(storage.getItem(prefix + "item"));
                // we must have ctiServerUrl at least.
                if (!config.ctiServerUrl) {
                    return null;
                }
                return config;
            } catch (e) {
                return null;
            }
        }

        return getConfiguration(prefix, request, retrieve, restore);
    }

    function getUserConfiguration() {
        var prefix = "user_",
            i, t;


        var request = function(callback) {
            sforce.opencti.runApex({
                apexClass: 'AccountRetrievalNoSpacename',
                methodName: 'getUser',
                methodParams: '',
                callback: callback
            })
        }

        var retrieve = function(prefix, settingsRaw, storage) {
            var config = {};
            var settings = JSON.parse(settingsRaw.runApex);

            // what really need is Extension only, which represents the agent id in CCSP.
            checkPropertiesExist(settings, 'UserSettings', 'Id', 'CallCenterId', 'Extension', 'Email');

            // for user settings get all the properties
            for (i in settings) {
                if (settings.hasOwnProperty(i) && ((t = typeof settings[i]) === 'string' || t === 'number')) {
                    config[i] = settings[i];
                }
            }

            if (storage) {
                saveToStorage(storage, prefix, config);
            }
            return config;
        }

        var restore = function(prefix, storage) {
            if (typeof storage === 'undefined' || storage.getItem(prefix + "saved") !== "saved") {
                return config;
            }

            try {
                var config = JSON.parse(storage.getItem(prefix + "item"));
                // what we save are, Phone, Id, CallCenterId, Extension and config.Email
                // we must have Extension at least.
                if (!config.Extension) {
                    return null;
                }
                return config;
            } catch (e) {
                return null;
            }
        }

        return getConfiguration(prefix, request, retrieve, restore);
    }

    var load = function(defaultClickToDial) {
        $.when(getCallCenterConfiguration(), getUserConfiguration())
            .done(function(cc, user) {
                configLoaded = true;
                callcenterConfig = cc;
                userConfig = user;
                if (defaultClickToDial) {
                    CCSPIntegration.sfLghtCti.api.enableClickToDial(true)
                        .done(function() {
                            CCSPIntegration.sfLghtCti.api.onClickToDial(function(data) {
                                if (CCSPIntegration.sfLghtCti.onClickToDial) {
                                    CCSPIntegration.sfLghtCti.onClickToDial(data);
                                }
                            });
                        })
                        .fail(function(error) {
                            log.error("fail enableClickToDial. " + error);
                        });
                }

                log.dumpobj("ccConfig", cc, true);
                log.dumpobj("userConfig", user);
                if (typeof CCSPIntegration.sfLghtCti.onLoadDone === 'function') {
                    try {
                        CCSPIntegration.sfLghtCti.onLoadDone(cc, user);
                    } catch (e) {
                        log.error("Error in CCSPIntegration.sfLghtCti.onLoadDone: " + e.message);
                    }
                }
            })
            .fail(function(error) {
                configLoaded = false;
                callcenterConfig = null;
                userConfig = null;

                if (typeof CCSPIntegration.sfLghtCti.onLoadFail === 'function') {
                    try {
                        CCSPIntegration.sfLghtCti.onLoadFail(error);
                    } catch (e) {
                        log.error("Error in CCSPIntegration.sfLghtCti.onLoadFail: " + e.message);
                    }
                }
            });
    }

    return {
        'load': load,
        'isLoaded': function() { return configLoaded; },
        'callcenterConfig': function() { return callcenterConfig; },
        'userConfig': function() { return userConfig; }
    }
})();

CCSPIntegration.sfLghtCti.api = (function() {

    // helper function to get message from thrown.
    function messageInException(e) {
        if (typeof e === 'string') return e;
        return e.description || e.message || e.toString();
    }

    function dummyapicall(cb) {
        var response = { result: true };
        cb(response);
    }

    var isInConsole = function() {
        //Not yet supported in lightning (42.0), returning false
        var d = $.Deferred();
        d.resolve(false);
        return d.promise();
    }

    var defaultCallback = function (promise, errorFieldName){
        return function(response) {
            if (response.success) {
                promise.resolve(response.returnValue);
            } else {
                promise.reject(JSON.stringify(response[errorFieldName]));
            }
        };
    }

    var enableClickToDial = function(enable) {
        var d = $.Deferred(),
            methodName = enable ? "enableClickToDial" : "disableClickToDial";
        try {
            sforce.opencti[methodName]({
                callback: defaultCallback(d, "errors")
            });
        } catch (e) {
            d.reject(messageInException(e));
        }
        return d.promise();
    }

    var onClickToDial = function(listener) {
        sforce.opencti.onClickToDial({
            listener: listener
        });
    }

    var getPageInfo = function() {
        var d = $.Deferred(),
            data;
        try {
            sforce.opencti.getAppViewInfo({
                callback: defaultCallback(d, "error")
            });
        } catch (e) {
            d.reject(messageInException(e));
        }
        return d.promise();
    }

    var runApex = function(apexClass, methodName, methodParams) {
        var d = $.Deferred(),
            data;
        try {
            sforce.opencti.runApex({
                apexClass: apexClass,
                methodName: methodName,
                methodParams: methodParams,
                callback: defaultCallback(d, "error")
            });
        } catch (e) {
            d.reject(messageInException(e));
        }
        return d.promise();
    }

    var saveLog = function(objName, saveParams) {
        var d = $.Deferred();
        try {
            var params = saveParams;
            params.entityApiName = objName;
            sforce.opencti.saveLog({
                value: params,
                callback: defaultCallback(d, "errors")
            });
        } catch (e) {
            d.reject(messageInException(e));
        }
        return d.promise();
    }

    var screenPop = function(screenPopObject) {
        var d = $.Deferred();

        try {
            screenPopObject.callback = screenPopObject.callback || defaultCallback(d, "errors");

            sforce.opencti.screenPop(screenPopObject);
        } catch (e) {
            d.reject(messageInException(e));
        }
        return d.promise();
    }

    var searchAndGetScreenPopUrl = function(searchParams, queryParams, callType) {
        var d = $.Deferred();
        try {
            sforce.opencti.searchAndScreenPop({
                searchParams: searchParams,
                queryParams: queryParams,
                callType: callType, 
                callback: defaultCallback(d, "errors"),
                deferred: true
            });
        } catch (e) {
            d.reject(messageInException(e));
        }
        return d.promise();
    }

    return {
        'isInConsole': isInConsole,
        'enableClickToDial': enableClickToDial,
        'onClickToDial': onClickToDial,
        'getPageInfo': getPageInfo,
        'runApex': runApex,
        'saveLog': saveLog,
        'screenPop': screenPop,
        'searchAndGetScreenPopUrl': searchAndGetScreenPopUrl
    }
})();
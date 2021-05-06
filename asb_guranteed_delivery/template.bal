import ballerina/http;
import ballerina/io;
import ballerina/lang.'string as str;
import ballerina/log;
import ballerinax/asb;
import ballerinax/googleapis.sheets as sheets;
import ballerinax/sfdc;

//intializing constants 
const string TOPIC_PREFIX = "/topic/";
const string CREATED = "created";

// ASB configuration parameters
configurable string connection_string = ?;
configurable string queue_name = ?;
configurable string receive_mode = ?;

asb:AsbConnectionConfiguration asbConfig = {
    connectionString: connection_string
};

// Initialize the azure service bus client
asb:AsbClient asbClient = new (asbConfig);

// google sheet configuration parameters
configurable http:OAuth2RefreshTokenGrantConfig & readonly directTokenConfig = ?;
configurable string & readonly sheets_spreadsheet_id = ?;
configurable string & readonly sheets_worksheet_name = ?;

sheets:SpreadsheetConfiguration spreadsheetConfig = {
    oauthClientConfig: directTokenConfig
};

// Initialize the Spreadsheet Client
sheets:Client spreadsheetClient = check new (spreadsheetConfig);

// Salesforce configuration parameters
configurable sfdc:ListenerConfiguration & readonly listenerConfig = ?;
configurable string & readonly sfdc_push_topic = ?;

// Initialize the Salesforce Listener
listener sfdc:Listener sfdcEventListener = new (listenerConfig);

@sfdc:ServiceConfig {
    topic: TOPIC_PREFIX + sfdc_push_topic
}
service on sfdcEventListener {
    remote function onEvent(json sObject) returns error? {
        io:StringReader sr = new (sObject.toJsonString());
        json sObjectInfo = check sr.readJson();         
        json eventType = check sObjectInfo.event.'type;               
        if (CREATED.equalsIgnoreCaseAscii(eventType.toString())) {
            json sObjectId = check sObjectInfo.sobject.Id;            
            json sObjectObject = check sObjectInfo.sobject;
            check sendMessageToAsbQueue(sObjectObject);  
       
        }        
    }
}

// Initialize the azure service bus listener
listener asb:Listener asbListener = new();

@asb:ServiceConfig {
    entityConfig: {
        connectionString: connection_string,
        entityPath: queue_name,
        receiveMode: receive_mode
    }
}
service asb:Service on asbListener {
    remote function onMessage(asb:Message message) returns error? {
        json sObject = {};
        match message?.contentType {
            asb:JSON => {
                string s = check str:fromBytes(<byte[]> message.body);
                json sObjectInfo = check (s).cloneWithType(json);
                io:StringReader sr = new (sObjectInfo.toJsonString());
                sObject = check sr.readJson();
            }
        }

        log:printInfo("The message received: " + sObject.toString());
        var result = appendSheetWithNewRecord(sObject);
        if (result is error) {
            log:printError(result.message());
            var abandonResult = asbListener.abandon(message);  
            if (abandonResult is error) {
                log:printError(abandonResult.message());
            } else {
                log:printInfo("Abandon message successfully");
            }
        } else {
            log:printInfo("Message sent successfully");          
            var completeResult = asbListener.complete(message);  
            if (completeResult is error) {
                log:printError(completeResult.message());
            } else {
                log:printInfo("Complete message successfully");
            }
        }
    }
}

function sendMessageToAsbQueue(json sObject) returns @tainted error? {
    // Input values
    int timeToLive = 60; // In seconds

    asb:Message message1 = {
        body: sObject,
        contentType: asb:JSON,
        timeToLive: timeToLive
    };

    log:printInfo("Creating Asb sender connection.");
    handle queueSender = check asbClient->createQueueSender(queue_name);

    log:printInfo("Sending via Asb sender connection.");
    var result = asbClient->send(queueSender, message1);
    if (result is error) {
        log:printError(result.message());           
    }

    log:printInfo("Closing Asb sender connection.");
    check asbClient->closeSender(queueSender);  
}

function appendSheetWithNewRecord(json sObject) returns @tainted error? {
    (string)[] headerValues = [];
    (int|string|float)[] values = [];

    map<json> sObjectMap = <map<json>>sObject;
    foreach var [key, value] in sObjectMap.entries() {
        headerValues.push(key.toString());
        values.push(value.toString());
    }
    
    (string|int|float)[] headers = check spreadsheetClient->getRow(sheets_spreadsheet_id, sheets_worksheet_name, 1);
    if (headers == []) {
        _ = check spreadsheetClient->appendRowToSheet(sheets_spreadsheet_id, sheets_worksheet_name, headerValues);
    }

    _ = check spreadsheetClient->appendRowToSheet(sheets_spreadsheet_id, sheets_worksheet_name, values);

    log:printInfo("Appended Headers : " + headerValues.toString());
    log:printInfo("Appended Values : " + values.toString());
}

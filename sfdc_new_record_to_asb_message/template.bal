import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerinax/googleapis.sheets as sheets;
import ballerinax/sfdc;

//intializing constants 
const string TOPIC_PREFIX = "/topic/";
const string CREATED = "created";

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
            check appendSheetWithNewRecord(sObjectObject);            
        }        
    }
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

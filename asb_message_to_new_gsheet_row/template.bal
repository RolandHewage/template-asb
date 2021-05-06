import ballerina/http;
import ballerina/io;
import ballerina/lang.'string as str;
import ballerina/log;
import ballerinax/asb;
import ballerinax/googleapis.sheets as sheets;

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

// ASB configuration parameters
configurable string connection_string = ?;
configurable string queue_name = ?;
configurable string receive_mode = ?;

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

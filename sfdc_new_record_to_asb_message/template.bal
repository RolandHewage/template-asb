import ballerina/io;
import ballerina/log;
import ballerinax/asb;
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

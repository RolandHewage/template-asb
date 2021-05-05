import ballerina/log;
import ballerinax/asb;
import ballerinax/googleapis_calendar as calendar;
import ballerinax/googleapis_calendar.'listener as listen;

// ASB configuration parameters
configurable string connection_string = ?;
configurable string queue_path = ?;

asb:AsbConnectionConfiguration asbConfig = {
    connectionString: connection_string
};

// Initialize the azure service bus client
asb:AsbClient asbClient = new (asbConfig);

// Calendar configuration parameters
configurable int port = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?;
configurable string refreshUrl = ?;
configurable string calendarId = ?;
configurable string address = ?;

calendar:CalendarConfiguration calendarConfig = {
    oauth2Config: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        refreshUrl: refreshUrl   
    }
};

type MapStringdata map<string>;

// Initialize the calendar client
calendar:Client calendarClient = check new (calendarConfig);
// Initialize the calendar listener
listener listen:Listener calendarListener = new (port, calendarClient, calendarId, address);

service /calendar on calendarListener {
    remote function onNewEvent(calendar:Event event) returns error? {
        log:printInfo("Created new event : ", event);
        // Input values
        string stringContent = "This is My Message Body"; 
        byte[] byteContent = stringContent.toBytes();
        int timeToLive = 60; // In seconds
        int serverWaitTime = 60; // In seconds 

        json eventData = checkpanic event.cloneWithType(json);

        asb:ApplicationProperties applicationProperties = {
            properties: {a: "propertyValue1", b: "propertyValue2"}
        };

        asb:Message message1 = {
            body: eventData,
            contentType: asb:JSON,
            timeToLive: timeToLive,
            applicationProperties: applicationProperties
        };

        log:printInfo("Creating Asb sender connection.");
        handle queueSender = checkpanic asbClient->createQueueSender(queue_path);

        log:printInfo("Sending via Asb sender connection.");
        var result = asbClient->send(queueSender, message1);
        if (result is error) {
            log:printError(result.message());           
        }

        log:printInfo("Closing Asb sender connection.");
        checkpanic asbClient->closeSender(queueSender);
    }
}

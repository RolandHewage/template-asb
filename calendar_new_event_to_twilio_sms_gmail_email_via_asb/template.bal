import ballerina/lang.'string as str;
import ballerina/log;
import ballerinax/asb;
import ballerinax/googleapis_calendar as calendar;
import ballerinax/googleapis_calendar.'listener as listen;
import ballerinax/twilio;

// ASB configuration parameters
configurable string connection_string = ?;
configurable string topic_name = ?;
configurable string subscription_name1 = ?;
configurable string subscription_name2 = ?;
configurable string subscription_path1 = ?;
configurable string subscription_path2 = ?;

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

// Initialize the calendar client
calendar:Client calendarClient = check new (calendarConfig);
// Initialize the calendar listener
listener listen:Listener calendarListener = new (port, calendarClient, calendarId, address);

service /calendar on calendarListener {
    remote function onNewEvent(calendar:Event event) returns error? {
        log:printInfo("Created new event : ", event);
        // Input values
        int timeToLive = 60; // In seconds
        json eventData = checkpanic event.cloneWithType(json);

        asb:Message message1 = {
            body: eventData,
            contentType: asb:JSON,
            timeToLive: timeToLive
        };

        log:printInfo("Creating Asb sender connection.");
        handle topicSender = checkpanic asbClient->createTopicSender(topic_name);

        log:printInfo("Sending via Asb sender connection.");
        var result = asbClient->send(topicSender, message1);
        if (result is error) {
            log:printError(result.message());           
        } 

        log:printInfo("Closing Asb sender connection.");
        checkpanic asbClient->closeSender(topicSender);
    }
}

// Twilio configuration parameters
configurable string account_sid = ?;
configurable string auth_token = ?;
configurable string from_mobile = ?;
configurable string to_mobile = ?;

twilio:TwilioConfiguration twilioConfig = {
    accountSId: account_sid,
    authToken: auth_token
};

// Initialize the twilio client
twilio:Client twilioClient = new(twilioConfig);

// Initialize the azure service bus listener
listener asb:Listener asbListener = new();

@asb:ServiceConfig {
    entityConfig: {
        connectionString: connection_string,
        entityPath: subscription_path1
    }
}
service asb:Service on asbListener {
    remote function onMessage(asb:Message message) {
        string messageAsString;
        match message?.contentType {
            asb:TEXT => {
                messageAsString = checkpanic str:fromBytes(<byte[]> message.body);
            }
            asb:JSON => {
                string s = checkpanic str:fromBytes(<byte[]> message.body);
                json eventData = checkpanic (s).cloneWithType(json);
                messageAsString = eventData.toJsonString();
            }
            asb:XML => {
                string s = checkpanic str:fromBytes(<byte[]> message.body);
                xml eventData = checkpanic (s).cloneWithType(xml);
                messageAsString = eventData.toString();
            }
            asb:BYTE_ARRAY => {
                messageAsString = message.body.toString();
            }
            _ => {
                messageAsString = message.body.toString();
            }
        }        

        log:printInfo("The message received: " + messageAsString);
        var result = twilioClient->sendSms(from_mobile, to_mobile, messageAsString);
        if (result is error) {
            log:printError(result.message());
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

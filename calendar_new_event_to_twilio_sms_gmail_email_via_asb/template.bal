import ballerina/http;
import ballerina/lang.'string as str;
import ballerina/log;
import ballerinax/asb;
import ballerinax/googleapis.calendar as calendar;
import ballerinax/googleapis.calendar.'listener as listen;
import ballerinax/googleapis.gmail as gmail;
import ballerinax/twilio;

// ASB configuration parameters
configurable string connection_string = ?;
configurable string topic_name = ?;
configurable string subscription_name1 = ?;
configurable string subscription_name2 = ?;
configurable string subscription_path1 = ?;
configurable string subscription_path2 = ?;
configurable string receive_mode = ?;

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

// Initialize the calendar listener
listener listen:Listener calendarListener = new (port, calendarConfig, calendarId, address);

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
        entityPath: subscription_path1,
        receiveMode: receive_mode
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
                xml eventData = checkpanic xml:fromString(s);
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

// Gmail client configuration parameters
configurable http:OAuth2RefreshTokenGrantConfig & readonly gmailOauthConfig = ?;
configurable string & readonly recipient = ?;
configurable string & readonly cc = ?;
configurable string & readonly subject = ?;

gmail:GmailConfiguration gmailClientConfiguration = {
    oauthClientConfig: gmailOauthConfig
};

// Initialize Gmail client 
gmail:Client gmailClient = new (gmailClientConfiguration);

// Initialize the azure service bus listener
listener asb:Listener asbListener2 = new();

@asb:ServiceConfig {
    entityConfig: {
        connectionString: connection_string,
        entityPath: subscription_path2,
        receiveMode: receive_mode
    }
}
service asb:Service on asbListener2 {
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
                xml eventData = checkpanic xml:fromString(s);
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

        // Send email

        // The user's email address. The special value **me** can be used to indicate the authenticated user.
        string userId = "me";
        gmail:MessageRequest messageRequest = {};
        messageRequest.recipient = recipient; 
        messageRequest.sender = userId;
        messageRequest.cc = cc; 
        messageRequest.subject = subject;
        messageRequest.messageBody = messageAsString;
        messageRequest.contentType = message?.contentType.toString();

        [string, string]|error sendMessageResponse = gmailClient->sendMessage(userId, messageRequest);
        if (sendMessageResponse is [string, string]) {
            // If successful complete the message & remove from the queue.
            log:printInfo("Message sent successfully");
            var completeResult = asbListener.complete(message);  
            if (completeResult is error) {
                log:printError(completeResult.message());
            } else {
                log:printInfo("Complete message successfully");
            }
        } else {
            // If unsuccessful, print the error returned.
            log:printError(sendMessageResponse.message());
        }
    }
}


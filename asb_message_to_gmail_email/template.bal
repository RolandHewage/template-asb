import ballerina/http;
import ballerina/log;
import ballerina/lang.'string as str;
import ballerinax/asb;
import ballerinax/googleapis.gmail as gmail;

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
        receiveMode: asb:RECEIVEANDDELETE
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

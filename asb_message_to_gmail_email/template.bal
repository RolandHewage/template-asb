import ballerina/http;
import ballerina/log;
import ballerina/lang.'string as str;
import ballerinax/asb;
import ballerinax/googleapis_gmail as gmail;

// Gmail client configuration
configurable http:OAuth2RefreshTokenGrantConfig & readonly gmailOauthConfig = ?;
configurable string & readonly recipient = ?;
configurable string & readonly cc = ?;
configurable string & readonly subject = ?;
configurable string & readonly messageBody = ?;
configurable string & readonly contentType = ?;

gmail:GmailConfiguration gmailClientConfiguration = {
    oauthClientConfig: gmailOauthConfig
};

// Initialize Gmail client 
gmail:Client gmailClient = new (gmailClientConfiguration);

// ASB configuration parameters
configurable string connection_string = ?;
configurable string queue_path = ?;

// Initialize the azure service bus listener
listener asb:Listener asbListener = new();

asb:AsbConnectionConfiguration config = {
    connectionString: connection_string
};

asb:AsbClient asbClient = new (config);

@asb:ServiceConfig {
    entityConfig: {
        connectionString: connection_string,
        entityPath: queue_path,
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

        // Send email
        gmail:MessageRequest messageRequest = {};
        messageRequest.recipient = recipient;
        messageRequest.sender = "me";
        messageRequest.subject = subject;
        messageRequest.cc = cc;
        messageRequest.messageBody = messageAsString;
        messageRequest.contentType = message?.contentType.toString();

        [string, string]|error sendMessageResponse = checkpanic gmailClient->sendMessage("me", messageRequest);
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

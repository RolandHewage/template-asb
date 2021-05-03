import ballerinax/twilio;
import ballerina/log;
import ballerina/lang.'string as str;
import ballerinax/asb;

// Twilio configuration parameters
configurable string account_sid = ?;
configurable string auth_token = ?;
configurable string from_mobile = ?;
configurable string to_mobile = ?;

twilio:TwilioConfiguration twilioConfig = {
    accountSId: account_sid,
    authToken: auth_token
};
twilio:Client twilioClient = new(twilioConfig);

// ASB configuration parameters
configurable string connection_string = ?;
configurable string queue_path = ?;

listener asb:Listener asbListener = new();

asb:AsbConnectionConfiguration config = {
    connectionString: connection_string
};

asb:AsbClient asbClient = new (config);

@asb:ServiceConfig {
    entityConfig: {
        connectionString: connection_string,
        entityPath: queue_path
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
            log:printError("Error Occured : ", err = result.message());
        } else {
            log:printInfo("Message sent successfully");
            checkpanic asbClient->createQueueReceiver(queue_path);
            checkpanic asbClient->complete(message);
            log:printInfo("Complete message successful");
        }
    }
}

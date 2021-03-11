import ballerinax/twilio;
import ballerina/log;
import ballerinax/asb;

// Twilio configuration parameters
configurable string account_sid = ?;
configurable string auth_token = ?;
configurable string from_mobile = ?;
configurable string to_mobile = ?;

// ASB configuration parameters
configurable string connection_string = ?;
configurable string queue_path = ?;

twilio:TwilioConfiguration twilioConfig = {
    accountSId: account_sid,
    authToken: auth_token
};
twilio:Client twilioClient = new(twilioConfig);

listener asb:Listener asbListener = new();

@asb:ServiceConfig {
    queueConfig: {
        connectionString: connection_string,
        queueName: queue_path
    }
}
service asb:Service on asbListener {
    remote function onMessage(asb:Message message) {
        var messageContent = message.getTextContent();
        if (messageContent is string) {
            log:print("The message received: " + messageContent);
            var result = twilioClient->sendSms(from_mobile, to_mobile, messageContent);
            if (result is error) {
                log:printError("Error Occured : ", err = result);
            } else {
                log:print("Message sent successfully");
            }
        } else {
            log:printError("Error occurred while retrieving the message content.");
        }
    }
}

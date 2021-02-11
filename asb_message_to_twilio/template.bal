import ballerina/config;
import ballerinax/twilio;
import ballerina/log;
import ballerinax/asb;

twilio:TwilioConfiguration twilioConfig = {
    accountSId: config:getAsString("ACCOUNT_SID"),
    authToken: config:getAsString("AUTH_TOKEN")
};
twilio:Client twilioClient = new(twilioConfig);

string fromMobile = config:getAsString("SAMPLE_FROM_MOBILE");
string toMobile = config:getAsString("SAMPLE_TO_MOBILE");

listener asb:Listener asbListener = new();

@asb:ServiceConfig {
    queueConfig: {
        connectionString: config:getAsString("CONNECTION_STRING"),
        queueName: config:getAsString("QUEUE_PATH")
    }
}
service asb:Service on asbListener {
    remote function onMessage(asb:Message message) {
        var messageContent = message.getTextContent();
        if (messageContent is string) {
            log:print("The message received: " + messageContent);
            var result = twilioClient->sendSms(fromMobile, toMobile, messageContent);
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

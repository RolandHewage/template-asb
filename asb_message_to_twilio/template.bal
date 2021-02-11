import ballerina/config;
import ballerinax/twilio;
import ballerina/log;
import ballerina/runtime;
import ballerinax/asb;

twilio:TwilioConfiguration twilioConfig = {
    accountSId: config:getAsString("ACCOUNT_SID"),
    authToken: config:getAsString("AUTH_TOKEN")
};
twilio:Client twilioClient = new(twilioConfig);

string fromMobile = config:getAsString("SAMPLE_FROM_MOBILE");
string toMobile = config:getAsString("SAMPLE_TO_MOBILE");

public function main() {

    // Input values
    string stringContent = "This is My Message Body"; 
    byte[] byteContent = stringContent.toBytes();
    json jsonContent = {name: "apple", color: "red", price: 5.36};
    byte[] byteContentFromJson = jsonContent.toJsonString().toBytes();

    asb:ConnectionConfiguration config = {
        connectionString: config:getAsString("CONNECTION_STRING"),
        entityPath: config:getAsString("QUEUE_PATH")
    };

    log:print("Creating Asb sender connection.");
    asb:SenderConnection? senderConnection = checkpanic new (config);

    if (senderConnection is asb:SenderConnection) {
        log:print("Sending via Asb sender connection.");
        checkpanic senderConnection->sendMessageWithConfigurableParameters(byteContent);
        checkpanic senderConnection->sendMessageWithConfigurableParameters(byteContentFromJson);
    } else {
        log:printError("Asb sender connection creation failed.");
    }

    asb:Service asyncTestService =
    @asb:ServiceConfig {
        queueConfig: {
            connectionString: config:getAsString("CONNECTION_STRING"),
            queueName: config:getAsString("QUEUE_PATH")
        }
    }
    service object {
        remote function onMessage(asb:Message message) {
            var messageContent = message.getTextContent();
            if (messageContent is string) {
                log:print("The message received: " + messageContent);
                var success = twilioClient->sendSms(fromMobile, toMobile, messageContent);
                if (success is error) {
                    log:printError("Error Occured : ", err = success);
                } else {
                    log:print("Message sent successfully");
                }
            } else {
                log:printError("Error occurred while retrieving the message content.");
            }
        }
    };

    asb:Listener? channelListener = new();
    if (channelListener is asb:Listener) {
        checkpanic channelListener.attach(asyncTestService);
        checkpanic channelListener.'start();
        log:print("start listening");
        runtime:sleep(20000);
        log:print("end listening");
        checkpanic channelListener.detach(asyncTestService);
        checkpanic channelListener.gracefulStop();
        checkpanic channelListener.immediateStop();
    }

    if (senderConnection is asb:SenderConnection) {
        log:print("Closing Asb sender connection.");
        checkpanic senderConnection.closeSenderConnection();
    }
}

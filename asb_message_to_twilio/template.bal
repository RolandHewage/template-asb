import ballerina/lang.'string as str;
import ballerina/log;
import ballerinax/asb;
import ballerinax/twilio;

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
        var result = twilioClient->sendSms(from_mobile, to_mobile, message.toString());
        if (result is error) {
            log:printError(result.message());
        } else {
            log:printInfo("Message sent successfully");
            // var deferResult = asbListener.defer(message);  
            // if (deferResult is error) {
            //     log:printError(deferResult.message());
            // } else {
            //     log:printInfo("Defer message successfully");
            //     var getDeferResult = asbListener.receiveDeferred(deferResult);  
            //     if (getDeferResult is error) {
            //         log:printError(getDeferResult.message());
            //     }
            // }
            var completeResult = asbListener.complete(message);  
            if (completeResult is error) {
                log:printError(completeResult.message());
            } else {
                log:printInfo("Complete message successfully");
            }
            // log:printInfo("Creating Asb receiver connection.");
            // checkpanic asbClient->createQueueReceiver(queue_path);
            // var completeResult = asbClient->complete(message);
            // if (completeResult is error) {
            //     log:printError(completeResult.message());
            // } else {
            //     log:printInfo("Complete message successfully");
            // }
            // log:printInfo("Closing Asb receiver connection.");
            // checkpanic asbClient->closeReceiver();
        }
    }

    remote function onError(error e) {
        log:printInfo("Hello");
        log:printError(e.message());
    }
}

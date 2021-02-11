## Azure Service Bus to Twilio Integration

### Intergration Use Case 
This template can be used in the scenarios you need to send the messages posted to given channel as sms through twilio. Users need to configure their twilio mobile number as the number which sends the sms and an another registered mobile number as the receiver. 

### Pre-requisites
* Download and install [Ballerina](https://ballerinalang.org/downloads/).
* Twilio account with sms capable phone number
* Ballerina connectors for Azure Service Bus and Twilio which will be automatically downloaded when building the application for the first time

### configuration
* Obtain twilio Account SID and Auth Token from your project dashboard

#### ballerinax/twilio related configurations  

TWILIO_ACCOUNT_SID = ""  
TWILIO_AUTH_TOKEN = ""  

#### General configurations
In addition to the configurations related to ballerina modules user needs to provide the number obtained from your twilio account as 'FROM_MOBILE' and the number you wish to send the sms as 'TO_MOBILE'

SAMPLE_FROM_MOBILE = ""  
SAMPLE_TO_MOBILE = ""  

import ballerinax/slack;
import muthahhar/addresscheckapi;
import wso2/choreo.sendsms;
import muthahhar/policecheckapi;
import muthahhar/idcheckapi;
import ballerina/http;
import ballerina/log;
import ballerina/io;

configurable string addressClientSecret = ?;

configurable string addressClientId = ?;

configurable string policeClientSecret = ?;

configurable string policeClientId = ?;

configurable string idClientSecret = ?;

configurable string idClientId = ?;

configurable string slackAuthToken = ?;

type output record {
    boolean success;
    string msg;
};

type nicApiResponse record {
    boolean valid;
    string nic;
};

type policeApiResponse record {
    boolean valid;
    boolean isGuilty?;
    string charges?;
};

type addressApiResponse record {
    boolean valid;
    string address?;
};

slack:Client slackEp = check new (config = {
    auth: {
        token: slackAuthToken
    }
});

function sendNotificationtoSlack(string nic, string address, string errorMsg) returns string|error? {
    string Message = "Issue: The " + errorMsg + ". ( NIC: " + nic + ".   Address: " + address + ")";
    slack:Message message = {channelName: "gramachecksupport", text: Message};
    string slackResponse = check slackEp->postMessage(message);
    return slackResponse;
}

idcheckapi:Client idcheckapiEp = check new (clientConfig = {
    auth: {
        clientId: idClientId,
        clientSecret: idClientSecret
    }
});

policecheckapi:Client policecheckapiEp = check new (clientConfig = {
    auth: {
        clientId: policeClientId,
        clientSecret: policeClientSecret
    }
});

addresscheckapi:Client addresscheckapiEp = check new (clientConfig = {
    auth: {
        clientId: addressClientId,
        clientSecret: addressClientSecret
    }
});

sendsms:Client sendsmsEp = check new ();



service / on new http:Listener(9090) {

    resource function get integrateCheck/[string nic]/[string address]/[string phone]() returns output|error? {

        // nic checking API-------------------------------------------------------------

        nicApiResponse nicResult = check idcheckapiEp->getChecknicNic(nic.trim());
        io:println(nicResult);

        if nicResult.valid is false {
            output result = {
                success: false,
                msg: "NIC is not Valid"
            };

            log:printInfo("Entered NIC is Invalid");
            _ = check sendNotificationtoSlack(nic, address, "Entered Nic is Invalid");
            _ = check sendsmsEp->sendSms(toMobile = "+94"+phone.substring(1), message = "Entered NIC is Invalid: " + nic);
            return result;
        }

        // police check---------------------------------------------------------------------------------

        policeApiResponse policeResult = check policecheckapiEp->getPolicecheckNic(nic.trim());
        io:println(policeResult);

        if policeResult.valid is false || policeResult.isGuilty is true {
            output result = {
                success: false,
                msg: "Police Validation Failed"
            };
            log:printInfo("Police Validation Failed");
            _ = check sendNotificationtoSlack(nic, address, "Police Validation Failed");
            _ = check sendsmsEp->sendSms(toMobile = "+94"+phone.substring(1),message = "Police Validation Failed");
            return result;
        }

        //address check----------------------------------------------------------------------------------

        addressApiResponse addressResult = check addresscheckapiEp->getCheckaddressNicAddress(nic.trim(), address.trim());
        io:println(addressResult);

        if addressResult.valid is false {
            output result = {
                success: false,
                msg: "Address Verification Failed"
            };

            log:printInfo("Address Verification Failed");
            _ = check sendNotificationtoSlack(nic, address, "Address Validation Failed");
            _ = check sendsmsEp->sendSms(toMobile ="+94"+phone.substring(1), message = "Address Validation Failed");
            return result;
        } else {
            output result = {
                success: true,
                msg: "All Validations Are Successful"
            };

            log:printInfo("All Validations are Successful");
            _ = check sendNotificationtoSlack(nic, address, "All Validation Successful. You can Obtain your Clearance certificate");
            _ = check sendsmsEp->sendSms(toMobile = "+94"+phone.substring(1), message = "All Validations are successful. You can Obtain your Clearance certificate");
            return result;
        }

    }

}

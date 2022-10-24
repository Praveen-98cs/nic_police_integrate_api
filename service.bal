import muthahhar/addresscheckapi;
import wso2/choreo.sendsms;
import muthahhar/policecheckapi;
import muthahhar/idcheckapi;
import ballerina/http;
import ballerina/log;

configurable string addressClientSecret = ?;

configurable string addressClientId = ?;

configurable string policeClientSecret = ?;

configurable string policeClientId = ?;

configurable string idClientSecret = ?;

configurable string idClientId = ?;

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

service / on new http:Listener(9090) {

    resource function get integrateCheck/[string nic]/[string address]/[string phone]() returns output|error? {

        sendsms:Client sendsmsEp = check new ();

        // nic checking API-------------------------------------------------------------

        idcheckapi:Client idcheckapiEp = check new (clientConfig = {
            auth: {
                clientId: idClientId,
                clientSecret: idClientSecret
            }
        });

        nicApiResponse nicResult = check idcheckapiEp->getChecknicNic(nic.trim());

        if nicResult.valid is false {
            output result = {
                success: false,
                msg: "NIC is not Valid"
            };

            log:printInfo("Entered NIC is Invalid");
            future<string|error> _ = start sendsmsEp->sendSms(toMobile = "+94" + phone.substring(1), message = "Entered NIC is Invalid: " + nic);
            return result;
        }

        // police check---------------------------------------------------------------------------------

        policecheckapi:Client policecheckapiEp = check new (clientConfig = {
            auth: {
                clientId: policeClientId,
                clientSecret: policeClientSecret
            }
        });
        policeApiResponse policeResult = check policecheckapiEp->getPolicecheckNic(nic.trim());

        if policeResult.valid is false || policeResult.isGuilty is true {
            output result = {
                success: false,
                msg: "Police Validation Failed"
            };
            log:printInfo("Police Validation Failed");
            future<string|error> _ = start sendsmsEp->sendSms(toMobile = "+94" + phone.substring(1), message = "Police Validation Failed");
            return result;
        }

        //address check----------------------------------------------------------------------------------

        addresscheckapi:Client addresscheckapiEp = check new (clientConfig = {
            auth: {
                clientId: addressClientId,
                clientSecret: addressClientSecret
            }
        });

        addressApiResponse addressResult=check addresscheckapiEp->getCheckaddressNicAddress(nic.trim(),address.trim());

        if addressResult.valid is false{
            output result = {
                success: false,
                msg: "Address Verification Failed"
            };

            log:printInfo("Address Verification Failed");
            future<string|error> _ = start sendsmsEp->sendSms(toMobile = "+94" + phone.substring(1), message = "Address Validation Failed");
            return result;
        }else{
            output result = {
                success: true,
                msg: "All Validations Are Successful"
            };

            log:printInfo("All Validations are Successful");
            future<string|error> _ = start sendsmsEp->sendSms(toMobile = "+94" + phone.substring(1), message = "All Validations are successful. You can Obtain your Clearance certificate");
            return result;
        }


    }

}

import wso2/choreo.sendsms;
import muthahhar/policecheckapi;
import muthahhar/idcheckapi;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/http;
import ballerina/sql;
import ballerina/log;

configurable int port = ?;

configurable string database = ?;

configurable string password = ?;

configurable string user = ?;

configurable string host = ?;

type success record{
    boolean success;
    string msg;
};

type output record {
    boolean isNicValid;
    boolean isGuilty?;
    string charges?;
    string address?;
    string url?;
};

type nicApiResponse record {
    boolean valid;
};

type policeApiResponse record {
    boolean valid;
    boolean isGuilty?;
    string charges?;
};

type validations record {
    boolean isNicValid;
    boolean isPoliceValid;
    boolean isAddressValid;
};

type validationsInt record {
    int isNicValid;
    int isPoliceValid;
    int isAddressValid;
};

type allRequests record{
    string nic;
    string name;
    @sql:Column {
        name: "isnicvalid"
    }int isNicValid;
    @sql:Column {
        name: "ispolicevalid"
    }int isPoliceValid;
    @sql:Column {
        name: "isaddressvalid"
    }int isAddressValid;
    string address;
    string url;
    
};

mysql:Client mysqlEp = check new (host = host, user = user, password = password, database = database, port = port);

sendsms:Client sendsmsEp = check new ();

idcheckapi:Client idcheckapiEp = check new (clientConfig = {
    auth: {
        clientId: "q2ivPDHEm5B0VbAf9W_skfuMIj8a",
        clientSecret: "5pvMJLETWP0RULchGGD7kyILZn0a"
    }
});

policecheckapi:Client policecheckapiEp = check new (clientConfig = {
    auth: {
        clientId: "Nd9okFkmt1oC2wAcLBvmOI9T6OIa",
        clientSecret: "TsPOBZnGTeJ_BxDwvWiGxkEdeBAa"
    }
});

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    resource function get integrateCheck/[string nic]/[string name]/[string address]/[string url]() returns output|error? {

        nicApiResponse nicResult = check idcheckapiEp->getChecknicNic(nic.trim());

        if nicResult.valid is false {
            output result = {
                isNicValid: false
            };

            log:printInfo("Entered NIC is Invalid");
            return result;
        }

        policeApiResponse policeResult = check policecheckapiEp->getPolicecheckNic(nic.trim());

        if policeResult.valid is false {
            output result = {
                isNicValid: false
            };
            log:printInfo("Entered NIC is Invalid while police checking");
            return result;
        }

        sql:ParameterizedQuery insertQuery = `INSERT INTO verification_details(nic,name,isnicvalid,ispolicevalid,isaddressvalid,address,url) VALUES (
                                              ${nic.trim()}, ${name.trim()}, 1, 1, 0,
                                               ${address.trim()}, ${url})`;
        sql:ExecutionResult _ = check mysqlEp->execute(insertQuery);
        log:printInfo("Successfully inserted to the verification table");

        if policeResult.isGuilty is true {
            output result = {
                isNicValid: true,
                isGuilty: true,
                charges: <string>policeResult.charges,
                address: address.trim(),
                url: url
            };

            return result;

        }
        
        if policeResult.isGuilty is false  {
            output result = {
                isNicValid: true,
                isGuilty: false,
                address: address.trim(),
                url: url
            };

            return result;

        }

    }

    resource function put updateValidation/[string nic]/[string phone]() returns success|error? {
        sql:ParameterizedQuery updateQuery = `UPDATE verification_details SET isaddressvalid=1 where nic=${nic.trim()}`;
        sql:ExecutionResult result = check mysqlEp->execute(updateQuery);

        log:printInfo("verification_details table updated: "+ result.toString());

        string sendSmsResponse = check sendsmsEp->sendSms(toMobile = "+94"+phone.substring(1), message = "Getting police clearance Certificate NIC: Verified Police Report: Verified Address: Verified");
        log:printInfo(sendSmsResponse + ": +94" + phone.substring(1));

        success response={
            success:true,
            msg:"verification_details table updated"
        };
        return response;
    }

    resource function get getValidation/[string nic]() returns validations|error? {

        sql:ParameterizedQuery getValidationsQuery = `SELECT isnicvalid,ispolicevalid,isaddressvalid FROM verification_details WHERE nic=${nic.trim()}`;
        validationsInt result = check mysqlEp->queryRow(getValidationsQuery);

        log:printInfo(result.toBalString());

        if result.isAddressValid == 1 {
            validations result2 = {
                isNicValid: true,
                isPoliceValid: true,
                isAddressValid: true
            };
            return result2;
        } else {
            validations result2 = {
                isNicValid: true,
                isPoliceValid: true,
                isAddressValid: false
            };
            return result2;
        }
    }

    resource function get getAllRequests() returns allRequests[]|error? {


        stream<allRequests, error?> response =mysqlEp->query(`SELECT * FROM verification_details`);

        allRequests[]? allrqst = check from allRequests request in response
            
            select {nic: request.nic,name:request.name,isNicValid: request.isNicValid,isAddressValid: request.isAddressValid,isPoliceValid: request.isPoliceValid,address: request.address,url: request.url};

             return allrqst;
    }
}

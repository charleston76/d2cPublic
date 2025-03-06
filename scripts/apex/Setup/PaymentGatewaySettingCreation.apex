// List to create the profiles that would have access to the permission set
// when the user is created
List<PaymentGatewaySetting__c> lstSettings = new List<PaymentGatewaySetting__c>();
List<String> lstParameters = new List<String>{
    'PAYMENT_GATEWAY_SETTING',
    'PAYMENT_GATEWAY_API_LOGIN',
    'PAYMENT_GATEWAY_TRANSACTION_KEY'
};

Map<string,string> objMap = new Map<string,string>();
// Adding the values in the map
objMap.put('PAYMENT_GATEWAY_SETTING' , 'AUTHORIZE.NET');
objMap.put('PAYMENT_GATEWAY_API_LOGIN' , 'YOUR_API_LOGIN_HERE');
objMap.put('PAYMENT_GATEWAY_TRANSACTION_KEY' , 'YOUR_TRANSACTION_KEY_HERE');
// sandbox      = 'https://apitest.authorize.net/xml/v1/request.api';
// production   = 'https://api.authorize.net/xml/v1/request.api';

// Configure the profiles that needs to be checked in the trigger
for(String strSetting : lstParameters){
    PaymentGatewaySetting__c objSettings = PaymentGatewaySetting__c.getInstance();
    // Get the setting
    objSettings = PaymentGatewaySetting__c.getInstance(strSetting);

    // Check if need to create
    if (objSettings==null){
        PaymentGatewaySetting__c objNew = new PaymentGatewaySetting__c();
        objNew.Name = strSetting;
        if (! objMap.containsKey(strSetting)){
            objNew.Value__c = strSetting;
        } else {
            objNew.Value__c = objMap.get(strSetting);
        }
        lstSettings.add(objNew);
    }
}

system.debug('PaymentGatewaySetting__c lstSettings.size() ' + lstSettings.size());

if (lstSettings.size() >0) insert lstSettings;
public with sharing class EnrichPostCode implements Queueable, Database.AllowsCallouts {
    private Set<Id> leadIds;

    //We can support bulk, but right now we dont need to
    public EnrichPostCode(Set<Id> leadIds) {
        this.leadIds = leadIds;
    }

    // Overload constructor for single-record calls
    public EnrichPostCode(Id leadId) {
        this.leadIds = new Set<Id>{ leadId };
    }

    public void execute(QueueableContext context) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        List<Lead> leadsToEnrich = [
            SELECT Id, PostalCode 
            FROM Lead 
            WHERE Id IN :leadIds AND PostalCode != NULL
        ];

        if (leadsToEnrich.isEmpty()) {
            return;
        }

        List<Lead> leadsToUpdate = new List<Lead>();

        // Configure DML Options to trigger Lead Assignment Rules
        // We can let this then be handled declartively
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.useDefaultRule = true;

        for (Lead leadToEnrich : leadsToEnrich) {
            // Remove whitespace and encode URL to handle spaces safely
            //just in case the postcode was given spaces (wouldnt want to mess up our callout!)
            String sanitizedPostcode = EncodingUtil.urlEncode(leadToEnrich.PostalCode.deleteWhitespace(), 'UTF-8');

            Http http = new Http();
            HttpRequest request = new HttpRequest();
            // Note: Named Credentials should ideally be used here. but for the sake of speed I will just hardcode, I would NEVER usually do this!
            request.setEndpoint('https://api.postcodes.io/postcodes/' + sanitizedPostcode);
            request.setMethod('GET');
            request.setTimeout(10000);

            try {
                HttpResponse response = http.send(request);

                if (response.getStatusCode() == 200) {
                    Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Map<String, Object> resultData = (Map<String, Object>) responseData.get('result');

                    if (resultData != null) {
                        // postcodes.io returns admin_county for UK counties. Fallback to admin_district if null.
                        String county = (String) resultData.get('admin_county');
                        if (String.isBlank(county)) {
                            county = (String) resultData.get('admin_district');
                        }

                        leadToEnrich.City = (String) resultData.get('admin_district');
                        leadToEnrich.State__c = county; // Populating for Assignment Rule evaluation
                        leadToEnrich.Country__c = (String) resultData.get('country');
                        
                        // Attach assignment rule header to record
                        leadToEnrich.setOptions(dmlOpts);
                        leadsToUpdate.add(leadToEnrich);
                    }
                } else {
                    leadToEnrich.Postcode_Callout_Exception__c = 'Failed to enrich postcode. Status code: ' + response.getStatusCode();
                    leadsToUpdate.add(leadToEnrich);
                }
            } catch (Exception e) {
                leadToEnrich.Postcode_Callout_Exception__c = 'Error during postcode enrichment: ' + e.getMessage();
                leadsToUpdate.add(leadToEnrich);
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            Database.update(leadsToUpdate, dmlOpts, AccessLevel.SYSTEM_MODE);
        }
    }
}
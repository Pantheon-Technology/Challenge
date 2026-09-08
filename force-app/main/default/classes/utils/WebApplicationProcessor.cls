public inherited sharing class WebApplicationProcessor {

    //If time permitted, I would actually make this a custom mdt setting
    // to allow us to specify the value without updating the code
    private static final String LEAD_SOURCE_API_VALUE = 'Web';

    public void process(WebEnquiry webEnquiry) {
        createLead(webEnquiry);
    }

    //If time permitted, a better approach would be a repository layer for the lead
    //It'd handle our insert operation here as well as the dupe check query in utils
    private void createLead(WebEnquiry webEnquiry) {
        // webEnquiry has already passed its initial checks, so it's safe to attempt the insert here
        Lead newLead = new Lead(
            FirstName = webEnquiry.firstName,
            LastName = webEnquiry.lastName,
            Company = webEnquiry.companyName,
            Email = webEnquiry.email,
            Phone = webEnquiry.phone,
            PostalCode = webEnquiry.postcode,
            Title = webEnquiry.enquirySubject,
            Description = webEnquiry.enquiryDescription,
            LeadSource = LEAD_SOURCE,
            Budget__c = webEnquiry.estimatedBudget,
            External_Reference__c = webEnquiry.externalReference
        );

        try {
            //running in user mode to run in integration user context
            // We do this so we are enforcing good permission management
            database.insert(newLead, USER_MODE);
        } catch (DmlException e) {
            throw new DmlException('Failed to create Lead from web enquiry: ' + e.getMessage(), e);
        }
    }

    //future consideration is that we generate an account and contact
    // if they dont exist already
    // my logic for not automatically creating the accounts is because this is a lead
    // we wouldnt want to clog up the system, but if we convert a prior lead, we would for sure want
    // to link these back to the account and contact
    // of course the fields dont exist on lead, so it'd have to be made too
    private static Id getAccountId(string companyName) {
            return [SELECT Id FROM Account WHERE Name = :companyName LIMIT 1].Id ?? null;
    }

    private static Id getContactId(String email) {
       return [SELECT Id FROM Contact WHERE Email = :email LIMIT 1].Id ?? null;
    }
}
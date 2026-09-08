public inherited sharing class WebApplicationProcessor {
    public void process(WebEnquiry webEnquiry) {
        //logic for processing
        // firstly check if person exists in the system, checking on the email address/phone number is likely the most solid solution
        List<Lead> existingContacts = [
            SELECT Id, Email, Phone
            FROM Lead
            WHERE Email = :webEnquiry.email OR Phone = :webEnquiry.phone
            LIMIT 1
        ];

        if (!existingContacts.isEmpty()) {
            // if the contact exists, we can update their details with the new information from the web enquiry
            Lead existingContact = existingContacts[0];
            existingContact.FirstName = webEnquiry.firstName;
            existingContact.LastName = webEnquiry.lastName;
            existingContact.Email = webEnquiry.email;
            existingContact.Phone = webEnquiry.phone;
        } else {
            createLead(webEnquiry);
        }
    }

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
            LeadSource = 'Web',
            Budget__c = webEnquiry.estimatedBudget,
            External_Reference__c = webEnquiry.externalReference
        );

        try {
            insert newLead;
        } catch (DmlException dmlEx) {
            throw new DmlException('Failed to create Lead from web enquiry: ' + dmlEx.getMessage(), dmlEx);
        }
    }
}
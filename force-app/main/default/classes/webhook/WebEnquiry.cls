// apex object for taking in the generic request
public with sharing class WebEnquiry {
    public String externalReference;
    public String companyName;
    public String firstName;
    public String lastName;
    public String email;
    public String phone;
    public String postcode;
    public String enquirySubject;
    public String enquiryDescription;
    public Decimal estimatedBudget;

    public WebEnquiry() {

    }

    public static WebEnquiry construct(String jsonPayload) {
        WebEnquiry webEnquiry = (WebEnquiry) JSON.deserialize(jsonPayload, WebEnquiry.class);
        webEnquiry.validate();
        return webEnquiry;
    }

    public void validate() {
        if (String.isBlank(firstName)) {
            throw new WebEnquiryException('First name is required.');
        }
        if (String.isBlank(lastName)) {
            throw new WebEnquiryException('Last name is required.');
        }
        if (String.isBlank(email) || !email.contains('@')) {
            throw new WebEnquiryException('Valid email is required.');
        }
        if (String.isBlank(enquirySubject)) {
            throw new WebEnquiryException('Enquiry subject is required.');
        }
        if (String.isBlank(enquiryDescription)) {
            throw new WebEnquiryException('Enquiry description is required.');
        }
    }

}

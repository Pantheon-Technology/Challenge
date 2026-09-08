// takes in the web enquiry, builds a WebEnquiry object out of it then passes it on to the processor
@RestResource(urlMapping='/webenquiryprocessor/*')
public with sharing class WebEnquiryProcessor {
    @HttpPost
    public static void process() {
        RestRequest req = RestContext.request;

        if(req == null || req.requestBody == null) {
            throw new WebEnquiryException('Request body is required.');
        }

        String jsonPayload = req.requestBody.toString();
        WebEnquiry webEnquiry = WebEnquiry.construct(jsonPayload);

        try {
            validate(webEnquiry);
        } catch (WebEnquiryException e) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf(e.getMessage());
            return;
        }

        WebApplicationProcessor processor = new WebApplicationProcessor();
        processor.process(webEnquiry);
    }

    private void validate(WebEnquiry webEnquiry){
        webEnquiry.validate();
        duplicateRequestDetector dupeDetector = new DuplicateRequestDetector();
        dupeDetector.check(webEnquiry.externalReference);
    }
}
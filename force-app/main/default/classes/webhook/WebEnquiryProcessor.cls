//controller layer, takes in request, validates and passes to service layer
@RestResource(urlMapping='/webenquiryprocessor/*')
public with sharing class WebEnquiryProcessor {
  @HttpPost
  public static void process() {
    RestRequest req = RestContext.request;

    if (req == null || req.requestBody == null) {
      throw new WebEnquiryException('Request body is required.');
    }

    String jsonPayload = req.requestBody.toString();

    WebEnquiry webEnquiry;
    try {
      webEnquiry = WebEnquiry.construct(jsonPayload);
    } catch (Exception e) {
      throw new WebEnquiryException('Invalid JSON payload.');
    }

    try {
      duplicateRequestDetector dupeDetector = new DuplicateRequestDetector();
      dupeDetector.check(webEnquiry.externalReference);
    } catch (WebEnquiryException e) {
      RestContext.response.statusCode = 400;
      RestContext.response.responseBody = Blob.valueOf(e.getMessage());
      return;
    }

    WebApplicationProcessor processor = new WebApplicationProcessor();

    try {
      processor.process(webEnquiry);
      RestContext.response.statusCode = 200;
    } catch (Exception e) {
      RestContext.response.statusCode = 500;
      RestContext.response.responseBody = Blob.valueOf(
        'Failed to create Lead from web enquiry: ' + e.getMessage()
      );
      return;
    }
  }
}

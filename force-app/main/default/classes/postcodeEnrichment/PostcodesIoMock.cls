@IsTest
public class PostcodesIoMock implements HttpCalloutMock {
  private Integer statusCode;
  private String body;

  public PostcodesIoMock() {
    this.statusCode = 200;
    this.body = '{"status":200,"result":{"admin_district":"Westminster","admin_county":null,"country":"England"}}';
  }

  public PostcodesIoMock(Integer statusCode, String body) {
    this.statusCode = statusCode;
    this.body = body;
  }

  public HttpResponse respond(HttpRequest request) {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(statusCode);
    response.setBody(body);
    return response;
  }
}

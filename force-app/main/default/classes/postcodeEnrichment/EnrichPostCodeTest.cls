@IsTest
private class EnrichPostCodeTest {
  @IsTest
  static void successfulCalloutEnrichesLeadFields() {
    // given
    Test.setMock(HttpCalloutMock.class, new PostcodesIoMock());
    Lead lead = insertLead('SW1A 1AA');

    // when
    Test.startTest();
    System.enqueueJob(new EnrichPostCode(lead.Id));
    Test.stopTest();

    // then
    Lead enriched = [
      SELECT City, State__c, Country__c, Postcode_Callout_Exception__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    Assert.areEqual('Westminster', enriched.City);
    Assert.areEqual('Westminster', enriched.State__c); // falls back to admin_district when admin_county is null
    Assert.areEqual('England', enriched.Country__c);
    Assert.areEqual(null, enriched.Postcode_Callout_Exception__c);
  }

  @IsTest
  static void nonSuccessStatusCodeRecordsCalloutException() {
    // given
    Test.setMock(HttpCalloutMock.class, new PostcodesIoMock(404, '{}'));
    Lead lead = insertLead('SW1A 1AA');

    // when
    Test.startTest();
    System.enqueueJob(new EnrichPostCode(lead.Id));
    Test.stopTest();

    // then
    Lead enriched = [
      SELECT Postcode_Callout_Exception__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    Assert.isTrue(
      enriched.Postcode_Callout_Exception__c.contains('404'),
      'Expected the failure status code to be recorded, got: ' +
      enriched.Postcode_Callout_Exception__c
    );
  }

  @IsTest
  static void calloutExceptionIsCaughtAndRecorded() {
    // given
    Test.setMock(HttpCalloutMock.class, new ThrowingMock());
    Lead lead = insertLead('SW1A 1AA');

    // when
    Test.startTest();
    System.enqueueJob(new EnrichPostCode(lead.Id));
    Test.stopTest();

    // then
    Lead enriched = [
      SELECT Postcode_Callout_Exception__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    Assert.isTrue(
      enriched.Postcode_Callout_Exception__c.startsWith(
        'Error during postcode enrichment:'
      ),
      'Expected the callout exception to be recorded, got: ' +
      enriched.Postcode_Callout_Exception__c
    );
  }

  @IsTest
  static void leadsWithoutAPostalCodeAreSkipped() {
    // given
    Lead lead = insertLead(null);

    // when
    Test.startTest();
    System.enqueueJob(new EnrichPostCode(lead.Id));
    Test.stopTest();

    // then
    Lead unchanged = [
      SELECT City, State__c, Country__c, Postcode_Callout_Exception__c
      FROM Lead
      WHERE Id = :lead.Id
    ];

    Assert.areEqual(null, unchanged.City);
    Assert.areEqual(null, unchanged.State__c);
    Assert.areEqual(null, unchanged.Country__c);
    Assert.areEqual(null, unchanged.Postcode_Callout_Exception__c);
  }

  private static Lead insertLead(String postalCode) {
    Lead lead = new Lead(
      LastName = 'Smith',
      Company = 'Acme Rewards Ltd',
      PostalCode = postalCode
    );
    insert lead;
    return lead;
  }

  private class ThrowingMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      throw new CalloutException('Simulated timeout');
    }
  }
}

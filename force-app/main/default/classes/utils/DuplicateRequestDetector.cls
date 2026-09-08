public inherited sharing class DuplicateRequestDetector {
  @readonly
  public Boolean check(String externalReference) {
    Integer duplicateCount = [
      SELECT COUNT()
      FROM Lead
      WHERE External_Reference__c = :externalReference
      WITH SYSTEM_MODE
    ];

    if (duplicateCount > 0) {
      throw new WebEnquiryException(
        'A request with this external reference has already been processed.'
      );
    }

    return false;
  }
}

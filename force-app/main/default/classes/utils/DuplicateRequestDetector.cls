public inherited sharing class DuplicateRequestDetector {
  public Boolean check(String externalReference) {
    // SYSTEM_MODE is intentional: dedupe correctness can't depend on which Leads the
    // integration user happens to have visibility to under sharing rules - it needs to
    // see every existing Lead, otherwise a hidden record would let a real duplicate through.
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

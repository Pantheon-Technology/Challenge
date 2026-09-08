// given more time, I think a really good place for these notifications would be to something like slack or any similar
// company messaging service
public with sharing class LeadNotifier implements Queueable {
  //future improvement is to move these to custom mdt, then we can change the values
  //without ever updating the codebase
  private static final Decimal HIGH_VALUE_BUDGET_THRESHOLD = 10000;
  private static final Integer STANDARD_SLA_HOURS = 24;
  private static final Integer HIGH_VALUE_SLA_HOURS = 2;
  private static final String NOTIFICATION_TYPE_NAME = 'Lead_Follow_Up_Reminder';

  Set<Id> leadIds;

  //this time we can leave as bulkified
  public LeadNotifier(Set<Id> leadIds) {
    this.leadIds = leadIds;
  }

  public void execute(QueueableContext context) {
    if (leadIds == null || leadIds.isEmpty()) {
      return;
    }

    List<Lead> leadsToProcess = [
      SELECT Id, Company, Budget__c, OwnerId
      FROM Lead
      WHERE Id IN :leadIds
    ];

    if (leadsToProcess.isEmpty()) {
      return;
    }

    insertFollowUpTasks(leadsToProcess);
    notifyOwners(leadsToProcess);
  }

  // Task acts as the audit log of the SLA - proof a follow up was scheduled, whether or not the notification was seen/actioned
  private void insertFollowUpTasks(List<Lead> leadsToProcess) {
    List<Task> tasksToInsert = new List<Task>();

    for (Lead lead : leadsToProcess) {
      Integer slaHours = getSlaHours(lead);
      DateTime dueDateTime = DateTime.now().addHours(slaHours);

      tasksToInsert.add(
        new Task(
          WhatId = lead.Id,
          OwnerId = lead.OwnerId,
          Subject = 'Follow up on web enquiry',
          Description = 'Please follow up on the web enquiry within ' +
            slaHours +
            ' hour(s).',
          Priority = isHighValue(lead) ? 'High' : 'Normal',
          Status = 'Not Started',
          ActivityDate = dueDateTime.date(),
          IsReminderSet = true,
          ReminderDateTime = dueDateTime
        )
      );
    }

    if (!tasksToInsert.isEmpty()) {
      try {
        Database.insert(tasksToInsert, AccessLevel.SYSTEM_MODE, false);
      } catch (DmlException e) {
        //I felt that debugs were ok here because we had no other area to store the error, so this'd be a case
        //of checking through the logs
        System.debug('Failed to create tasks for leads: ' + e.getMessage());
      }
    }
  }

  private void notifyOwners(List<Lead> leadsToProcess) {
    //again, we could easily move the notification type to a custom mdt, but for now we will hardcode it
    List<CustomNotificationType> notificationTypes = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = :NOTIFICATION_TYPE_NAME
      LIMIT 1
    ];

    if (notificationTypes.isEmpty()) {
      System.debug(
        'Custom notification type "' +
          NOTIFICATION_TYPE_NAME +
          '" is not configured.'
      );
      return;
    }

    Id notificationTypeId = notificationTypes[0].Id;
    Map<Id, Id> ownerIdToManagerId = getManagerIdsForHighValueOwners(
      leadsToProcess
    );

    for (Lead lead : leadsToProcess) {
      if (lead.OwnerId == null) {
        continue;
      }

      Integer slaHours = getSlaHours(lead);

      // high value leads also page the owner's line manager
      Set<String> recipientIds = new Set<String>{ lead.OwnerId };
      if (ownerIdToManagerId.containsKey(lead.OwnerId)) {
        recipientIds.add(ownerIdToManagerId.get(lead.OwnerId));
      }

      Messaging.CustomNotification notification = new Messaging.CustomNotification();
      notification.setTitle('New web enquiry lead assigned');
      notification.setBody(
        lead.Company + ' needs a follow up within ' + slaHours + ' hour(s).'
      );
      notification.setNotificationTypeId(notificationTypeId);
      notification.setTargetId(lead.Id);

      try {
        notification.send(recipientIds);
      } catch (Exception e) {
        System.debug(
          'Failed to send notification for lead ' +
            lead.Id +
            ': ' +
            e.getMessage()
        );
      }
    }
  }

  // only high value leads owned by an actual User (not a Queue) have a line manager to notify
  private Map<Id, Id> getManagerIdsForHighValueOwners(
    List<Lead> leadsToProcess
  ) {
    Set<Id> highValueUserOwnerIds = new Set<Id>();
    for (Lead lead : leadsToProcess) {
      if (
        isHighValue(lead) &&
        lead.OwnerId != null &&
        lead.OwnerId.getSObjectType() == User.SObjectType
      ) {
        highValueUserOwnerIds.add(lead.OwnerId);
      }
    }

    Map<Id, Id> ownerIdToManagerId = new Map<Id, Id>();
    if (highValueUserOwnerIds.isEmpty()) {
      return ownerIdToManagerId;
    }

    for (User owner : [
      SELECT Id, ManagerId
      FROM User
      WHERE Id IN :highValueUserOwnerIds AND ManagerId != NULL
    ]) {
      ownerIdToManagerId.put(owner.Id, owner.ManagerId);
    }

    return ownerIdToManagerId;
  }

  private Boolean isHighValue(Lead lead) {
    return lead.Budget__c != null &&
      lead.Budget__c > HIGH_VALUE_BUDGET_THRESHOLD;
  }

  private Integer getSlaHours(Lead lead) {
    return isHighValue(lead) ? HIGH_VALUE_SLA_HOURS : STANDARD_SLA_HOURS;
  }
}

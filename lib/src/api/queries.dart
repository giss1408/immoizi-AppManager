const managerQuery = r'''
query ManagerDashboard($search: String) {
  myLandlordProperties(first: 20, search: $search) { id title city district rooms surfaceM2 price listingStatus category { title } isTestData description mainImageUrl galleryImageUrls galleryImageSlots hasVideo videoUrl }
  leases { property { title } startDate rentAmount status }
  propertyDocuments { id property { id title } title documentType visibility file createdAt }
  rentPayments { lease { property { title } } amount status }
  maintenanceRequests { id property { title } title description priority status }
  notifications { id title message isRead createdAt property { title } interestRequest { message } }
  propertyInterestRequests { id property { title } status profession salaryRange employer occupantsCount leaseStartDate message }
}
''';

const deleteNotificationMutation = r'''
mutation DeleteNotification($notificationId: ID!) {
  deleteNotification(notificationId: $notificationId) {
    deletedNotificationId
  }
}
''';

const updatePropertyListingMutation = r'''
mutation UpdatePropertyListing($propertyId: ID!, $price: Int, $description: String) {
  updatePropertyListing(propertyId: $propertyId, price: $price, description: $description) {
    property { id price description }
  }
}
''';

const updateMaintenanceMutation = r'''
mutation UpdateMaintenance($id: ID!, $title: String, $description: String, $priority: String, $status: String) {
  updateMaintenanceRequest(id: $id, title: $title, description: $description, priority: $priority, status: $status) {
    maintenanceRequest { id title description priority status }
  }
}
''';

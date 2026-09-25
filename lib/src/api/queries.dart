/// Every Property field the manager app reads (see Property.fromJson).
const propertyFields =
    'id title city district rooms surfaceM2 price listingStatus category { title } isTestData description mainImageUrl galleryImageUrls galleryImageSlots hasVideo videoUrl';

const managerQuery = '''
query ManagerDashboard(\$search: String) {
  myLandlordProperties(first: 20, search: \$search) { $propertyFields }
  categories { id title }
  leases { property { title } startDate rentAmount status }
  propertyDocuments { id property { id title } title documentType visibility file createdAt }
  rentPayments { lease { property { title } } amount status }
  maintenanceRequests { id property { title } title description priority status }
  notifications { id title message isRead createdAt property { title } interestRequest { id message } }
  propertyInterestRequests { id property { title } status isExpired applicantName profession salaryRange employer occupantsCount leaseStartDate message createdAt }
}
''';

const deleteNotificationMutation = r'''
mutation DeleteNotification($notificationId: ID!) {
  deleteNotification(notificationId: $notificationId) {
    deletedNotificationId
  }
}
''';

const createPropertyListingMutation = '''
mutation CreatePropertyListing(\$title: String!, \$categoryId: ID!, \$city: String!, \$district: String!, \$rooms: Int!, \$price: Int!, \$surfaceM2: Int, \$description: String, \$listingStatus: String) {
  createPropertyListing(title: \$title, categoryId: \$categoryId, city: \$city, district: \$district, rooms: \$rooms, price: \$price, surfaceM2: \$surfaceM2, description: \$description, listingStatus: \$listingStatus) {
    property { $propertyFields }
  }
}
''';

const updatePropertyListingMutation = '''
mutation UpdatePropertyListing(\$propertyId: ID!, \$title: String, \$categoryId: ID, \$city: String, \$district: String, \$rooms: Int, \$surfaceM2: Int, \$price: Int, \$description: String, \$listingStatus: String) {
  updatePropertyListing(propertyId: \$propertyId, title: \$title, categoryId: \$categoryId, city: \$city, district: \$district, rooms: \$rooms, surfaceM2: \$surfaceM2, price: \$price, description: \$description, listingStatus: \$listingStatus) {
    property { $propertyFields }
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

const respondToInterestMutation = r'''
mutation RespondToInterest($id: ID!, $accept: Boolean!, $message: String) {
  respondToPropertyInterest(interestRequestId: $id, accept: $accept, message: $message) {
    interestRequest { id status }
  }
}
''';

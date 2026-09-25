import 'package:immoizi_core/immoizi_core.dart';

class ManagerDashboard {
  ManagerDashboard(this.properties, this.leases, this.documents, this.payments,
      this.maintenance, this.notifications, this.interestRequests);

  final List<Property> properties;
  final List<LeaseItem> leases;
  final List<DocumentItem> documents;
  final List<Payment> payments;
  final List<Maintenance> maintenance;
  final List<NotificationItem> notifications;
  final List<InterestRequestItem> interestRequests;

  factory ManagerDashboard.fromJson(Map<String, dynamic> json) =>
      ManagerDashboard(
        jsonItems(json['myLandlordProperties']).map(Property.fromJson).toList(),
        jsonItems(json['leases']).map(LeaseItem.fromJson).toList(),
        jsonItems(json['propertyDocuments'])
            .map(DocumentItem.fromJson)
            .toList(),
        jsonItems(json['rentPayments']).map(Payment.fromJson).toList(),
        jsonItems(json['maintenanceRequests'])
            .map(Maintenance.fromJson)
            .toList(),
        jsonItems(json['notifications'])
            .map(NotificationItem.fromJson)
            .toList(),
        jsonItems(json['propertyInterestRequests'])
            .map(InterestRequestItem.fromJson)
            .toList(),
      );

  factory ManagerDashboard.demo() => ManagerDashboard(
        [
          Property(
            'Villa de prestige',
            'Residence',
            'Abidjan',
            'Cocody',
            5,
            220,
            920000,
            status: 'Disponible',
            isTestData: true,
            description:
                'Villa moderne avec piscine, jardin paysager et garage double.',
            mainImageUrl: 'https://placehold.co/600x400',
            hasVideo: true,
            videoUrl: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
          ),
          Property('Appartement duplex', 'Residence', 'Abidjan', 'Yopougon', 4,
              170, 710000,
              status: 'Loué',
              isTestData: true,
              description:
                  'Duplex lumineux avec balcon panoramique sur la lagune.'),
          Property('Studio meublé', 'Residence', 'Yamoussoukro', 'Centre', 1,
              42, 195000,
              status: 'Disponible',
              isTestData: true,
              description:
                  'Studio compact et meublé, idéal pour étudiant ou jeune actif.'),
          Property('Bureau commercial', 'Business', 'Abidjan', 'Plateau', 2, 98,
              480000,
              status: 'Occupé',
              isTestData: true,
              description:
                  'Espace de bureaux climatisé, proche des institutions financières.'),
          Property('Local commercial passant', 'Commerce', 'Yamoussoukro',
              'Centre', 1, 60, 260000,
              status: 'Disponible',
              isTestData: true,
              description:
                  'Local en rez-de-chaussée avec forte visibilité et grand accès client.'),
          Property('Entrepôt logistique', 'Industrie', 'Abidjan', 'Vridi', 1,
              540, 1150000,
              status: 'Disponible',
              isTestData: true,
              description:
                  'Entrepôt sécurisé avec quai de chargement et bureaux annexes.'),
        ],
        [
          LeaseItem('Villa de prestige', '01/09/2026', '920000', 'Actif'),
          LeaseItem('Appartement duplex', '15/08/2026', '710000', 'Actif'),
        ],
        [],
        [
          Payment('Villa de prestige', '920000', 'Payé'),
          Payment('Appartement duplex', '710000', 'En attente'),
        ],
        [
          Maintenance('1', 'Villa de prestige', 'Remplacement plomberie',
              'Fuite dans la salle de bain.', 'Moyenne', 'Planifiée'),
          Maintenance('2', 'Appartement duplex', 'Nettoyage toiture',
              'Entretien préventif de la toiture.', 'Faible', 'En cours'),
        ],
        [],
        [],
      );
}

class LeaseItem {
  LeaseItem(this.propertyTitle, this.startDate, this.rentAmount, this.status);

  final String propertyTitle;
  final String startDate;
  final String rentAmount;
  final String status;

  factory LeaseItem.fromJson(Map<String, dynamic> json) => LeaseItem(
        nestedTitle(json['property']),
        json['startDate'] as String? ?? '-',
        '${json['rentAmount'] ?? '-'}',
        json['status'] as String? ?? '-',
      );
}

class Payment {
  Payment(this.propertyTitle, this.amount, this.status);

  final String propertyTitle;
  final String amount;
  final String status;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        nestedTitle((json['lease'] as Map<String, dynamic>?)?['property']),
        '${json['amount'] ?? '-'}',
        json['status'] as String? ?? '-',
      );
}

class Maintenance {
  Maintenance(this.id, this.propertyTitle, this.title, this.description,
      this.priority, this.status);

  final String id;
  final String propertyTitle;
  final String title;
  final String description;
  final String priority;
  final String status;

  factory Maintenance.fromJson(Map<String, dynamic> json) => Maintenance(
        json['id'] as String? ?? '',
        nestedTitle(json['property']),
        json['title'] as String? ?? '-',
        json['description'] as String? ?? '',
        _maintenancePriority(json['priority']),
        _maintenanceStatus(json['status']),
      );
}

class DocumentItem {
  DocumentItem(this.id, this.propertyId, this.propertyTitle, this.title,
      this.type, this.fileUrl);

  final String id;
  final String propertyId;
  final String propertyTitle;
  final String title;
  final String type;
  final String? fileUrl;

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        json['id'] as String? ?? '',
        (json['property'] as Map<String, dynamic>?)?['id'] as String? ?? '',
        nestedTitle(json['property']),
        json['title'] as String? ?? '-',
        json['documentType'] as String? ?? '-',
        json['file'] as String?,
      );
}

class NotificationItem {
  NotificationItem(this.id, this.title, this.message, this.propertyTitle,
      this.interestMessage, this.isRead, this.createdAt);

  final String id;
  final String title;
  final String message;
  final String propertyTitle;
  final String interestMessage;
  final bool isRead;
  final String createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        json['id'] as String? ?? '',
        json['title'] as String? ?? 'Notification',
        json['message'] as String? ?? '',
        nestedTitle(json['property']),
        ((json['interestRequest'] as Map<String, dynamic>?)?['message']
                as String?) ??
            '',
        json['isRead'] as bool? ?? false,
        json['createdAt'] as String? ?? '',
      );
}

class InterestRequestItem {
  InterestRequestItem(
      this.id,
      this.propertyTitle,
      this.status,
      this.profession,
      this.salaryRange,
      this.employer,
      this.occupantsCount,
      this.leaseStartDate,
      this.message);

  final String id;
  final String propertyTitle;
  final String status;
  final String profession;
  final String salaryRange;
  final String employer;
  final int occupantsCount;
  final String leaseStartDate;
  final String message;

  factory InterestRequestItem.fromJson(Map<String, dynamic> json) =>
      InterestRequestItem(
        json['id'] as String? ?? '',
        nestedTitle(json['property']),
        json['status'] as String? ?? '-',
        json['profession'] as String? ?? '-',
        json['salaryRange'] as String? ?? '-',
        json['employer'] as String? ?? '',
        jsonInt(json['occupantsCount']),
        json['leaseStartDate'] as String? ?? '-',
        json['message'] as String? ?? '',
      );
}

String _maintenancePriority(Object? value) {
  final normalized = '${value ?? ''}'.toLowerCase().replaceAll(' ', '_');
  return const {
        'low': 'low',
        'faible': 'low',
        'normal': 'normal',
        'normale': 'normal',
        'high': 'high',
        'haute': 'high',
        'urgent': 'urgent',
        'urgente': 'urgent',
      }[normalized] ??
      'normal';
}

String _maintenanceStatus(Object? value) {
  final normalized = '${value ?? ''}'.toLowerCase().replaceAll(' ', '_');
  return const {
        'open': 'open',
        'ouverte': 'open',
        'in_progress': 'in_progress',
        'en_cours': 'in_progress',
        'resolved': 'resolved',
        'resolue': 'resolved',
        'cancelled': 'cancelled',
        'annulee': 'cancelled',
      }[normalized] ??
      'open';
}

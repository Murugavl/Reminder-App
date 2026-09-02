import '../data/local/database.dart';

class CustomerWithHistory {
  const CustomerWithHistory({required this.customer, required this.serviceRecords});

  final Customer customer;
  final List<ServiceRecord> serviceRecords;
}

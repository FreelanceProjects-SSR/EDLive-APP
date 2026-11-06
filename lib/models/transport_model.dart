class Transport {
  final int id;
  final String busNumber;
  final String routeName;
  final String stopName;
  final String arrivalTime;
  final String driverName;
  final String driverContact;
  final String? managerName;
  final String? managerContact;

  Transport({
    required this.id,
    required this.busNumber,
    required this.routeName,
    required this.stopName,
    required this.arrivalTime,
    required this.driverName,
    required this.driverContact,
    this.managerName,
    this.managerContact,
  });

  factory Transport.fromJson(Map<String, dynamic> json) {
    return Transport(
      id: _readInt(json['id']),
      busNumber: _readString(json['bus_number']),
      routeName: _readString(json['route_name']),
      stopName: _readString(json['stop_name']),
      arrivalTime: _readString(json['arrival_time']),
      driverName: _readString(json['driver_name']),
      driverContact: _readString(json['driver_contact']),
      managerName: _readNullableString(json['manager_name']),
      managerContact: _readNullableString(json['manager_contact']),
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _readString(dynamic value) {
  return value?.toString() ?? '';
}

String? _readNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

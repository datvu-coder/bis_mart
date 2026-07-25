class LeaveRequest {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? storeCode;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveType;
  final String? reason;
  final String status; // pending | approved | rejected
  final String? requestedAt;
  final String? approvedByName;
  final String? approvedAt;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.storeCode,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.reason,
    this.status = 'pending',
    this.requestedAt,
    this.approvedByName,
    this.approvedAt,
  });

  int get dayCount => endDate.difference(startDate).inDays + 1;

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      employeeName: json['employeeName'] as String?,
      storeCode: json['storeCode'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      leaveType: json['leaveType'] as String? ?? 'Nghỉ phép năm',
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      requestedAt: json['requestedAt'] as String?,
      approvedByName: json['approvedByName'] as String?,
      approvedAt: json['approvedAt'] as String?,
    );
  }
}

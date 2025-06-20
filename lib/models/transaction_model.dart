class Transaction {
  final String id;
  final String type;
  final String userId;
  final double amount;
  final String status;
  final String description;
  final String? reference;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.type,
    required this.userId,
    required this.amount,
    required this.status,
    required this.description,
    this.reference,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      type: map['type'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String,
      description: map['description'] as String,
      reference: map['reference'] as String?,
      transactionId: map['transaction_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'user_id': userId,
      'amount': amount,
      'status': status,
      'description': description,
      'reference': reference,
      'transaction_id': transactionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? type,
    String? userId,
    double? amount,
    String? status,
    String? description,
    String? reference,
    String? transactionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 
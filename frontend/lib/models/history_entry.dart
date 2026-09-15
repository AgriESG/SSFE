/// A single basket analysis, recorded on-device so a shopper can see how
/// their baskets and swaps add up over time. There is no backend account —
/// the API is deliberately stateless (see README, "Why there is no
/// database") — so this lives in SharedPreferences via HistoryStore, one
/// device deep.
class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final int itemCount;
  final List<String> itemNames;
  final double totalCost;
  final double totalCarbon;

  // Populated once the user has reviewed swaps on the Optimised Basket
  // screen; zero until then, which reads correctly as "no swaps accepted
  // yet" rather than as a missing value.
  final int swapsAccepted;
  final double costSaved;
  final double carbonSaved;

  HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.itemCount,
    required this.itemNames,
    required this.totalCost,
    required this.totalCarbon,
    this.swapsAccepted = 0,
    this.costSaved = 0,
    this.carbonSaved = 0,
  });

  HistoryEntry copyWith({
    int? swapsAccepted,
    double? costSaved,
    double? carbonSaved,
  }) {
    return HistoryEntry(
      id: id,
      timestamp: timestamp,
      itemCount: itemCount,
      itemNames: itemNames,
      totalCost: totalCost,
      totalCarbon: totalCarbon,
      swapsAccepted: swapsAccepted ?? this.swapsAccepted,
      costSaved: costSaved ?? this.costSaved,
      carbonSaved: carbonSaved ?? this.carbonSaved,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'itemCount': itemCount,
        'itemNames': itemNames,
        'totalCost': totalCost,
        'totalCarbon': totalCarbon,
        'swapsAccepted': swapsAccepted,
        'costSaved': costSaved,
        'carbonSaved': carbonSaved,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        itemCount: (j['itemCount'] ?? 0) as int,
        itemNames: (j['itemNames'] as List? ?? []).map((e) => e.toString()).toList(),
        totalCost: (j['totalCost'] ?? 0).toDouble(),
        totalCarbon: (j['totalCarbon'] ?? 0).toDouble(),
        swapsAccepted: (j['swapsAccepted'] ?? 0) as int,
        costSaved: (j['costSaved'] ?? 0).toDouble(),
        carbonSaved: (j['carbonSaved'] ?? 0).toDouble(),
      );
}

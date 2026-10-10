/// One train ride inside a journey.
class JourneyLeg {
  const JourneyLeg({
    required this.trainNumber,
    required this.boardCode,
    required this.alightCode,
  });

  factory JourneyLeg.fromJson(Map<String, Object?> json) => JourneyLeg(
    trainNumber: json['train']! as String,
    boardCode: json['board']! as String,
    alightCode: json['alight']! as String,
  );

  final String trainNumber;
  final String boardCode;
  final String alightCode;

  Map<String, Object?> toJson() => {
    'train': trainNumber,
    'board': boardCode,
    'alight': alightCode,
  };
}

/// A passenger journey: one train, or several trains with changes.
class Journey {
  const Journey({required this.id, required this.legs});

  factory Journey.fromJson(Map<String, Object?> json) => Journey(
    id: json['id']! as String,
    legs: [
      for (final leg in json['legs']! as List)
        JourneyLeg.fromJson((leg as Map).cast()),
    ],
  );

  final String id;
  final List<JourneyLeg> legs;

  String get originCode => legs.first.boardCode;
  String get destinationCode => legs.last.alightCode;
  Set<String> get trainNumbers => {for (final leg in legs) leg.trainNumber};

  Map<String, Object?> toJson() => {
    'id': id,
    'legs': [for (final leg in legs) leg.toJson()],
  };
}

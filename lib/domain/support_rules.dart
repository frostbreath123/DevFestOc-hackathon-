import 'train_status.dart';

/// An official railway source the passenger can open.
class OfficialResource {
  const OfficialResource({
    required this.id,
    required this.url,
    required this.title,
    required this.useFor,
    this.phone,
  });

  final String id;
  final Uri url;
  final String title;

  /// One short sentence: when to use this source.
  final String useFor;
  final String? phone;
}

/// What the refund rules suggest for the passenger's current situation.
enum RefundHint {
  /// A train on the journey is cancelled.
  trainCancelled,

  /// The delay passes the rule threshold.
  delayOverThreshold,

  /// The delay is below the threshold.
  delayBelowThreshold,

  /// We have no status to check.
  unknown,
}

/// Rule data for passenger support.
///
/// These values summarise public Indian Railways rules. They are NOT verified
/// by the project team yet. The app shows them as "may apply" and always links
/// to the official source. See [verifiedOn].
abstract final class SupportRules {
  /// Date the team last checked these rules against the official source.
  /// `null` means they have not been checked. Fill this in after a check.
  static const String? verifiedOn = null;

  /// Delay, in minutes, above which the delay-refund rule may apply.
  static const delayRefundThresholdMinutes = 180;

  static final resources = <OfficialResource>[
    OfficialResource(
      id: 'ntes',
      url: Uri.parse('https://enquiry.indianrail.gov.in/ntes/'),
      title: 'National Train Enquiry System (NTES)',
      useFor: 'Check the running status of a train.',
    ),
    OfficialResource(
      id: 'irctc',
      url: Uri.parse('https://www.irctc.co.in/'),
      title: 'IRCTC',
      useFor: 'Book tickets, cancel tickets and file a refund request (TDR).',
    ),
    OfficialResource(
      id: 'railmadad',
      url: Uri.parse('https://railmadad.indianrailways.gov.in/'),
      title: 'RailMadad',
      useFor: 'Make a complaint or ask for help.',
      phone: '139',
    ),
    OfficialResource(
      id: 'indianrailways',
      url: Uri.parse('https://indianrailways.gov.in/'),
      title: 'Indian Railways',
      useFor: 'Read official rules and notices.',
    ),
  ];

  static OfficialResource resource(String id) =>
      resources.firstWhere((r) => r.id == id);

  /// Deterministic check. It never decides that a refund is guaranteed.
  static RefundHint refundHint(TrainStatus? status) {
    if (status == null) return RefundHint.unknown;
    if (status.cancelled) return RefundHint.trainCancelled;
    if (status.delayMinutes >= delayRefundThresholdMinutes) {
      return RefundHint.delayOverThreshold;
    }
    return RefundHint.delayBelowThreshold;
  }
}

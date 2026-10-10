import '../domain/alert.dart';
import '../domain/connection.dart';
import '../domain/journey_view.dart';
import '../domain/support_rules.dart';
import 'clock.dart';

/// Languages the app can show.
///
/// Add a language only when its text can be checked by a fluent reader. Train
/// numbers, times and platform numbers are never translated.
enum AppLanguage {
  en('English'),
  hi('हिन्दी');

  const AppLanguage(this.nativeName);

  final String nativeName;
}

/// Passenger-facing text.
///
/// Sentences are short. They say what happened, what it means and what to do.
/// The Hindi text is a first draft and needs a review by a fluent reader.
class L10n {
  const L10n(this.language);

  final AppLanguage language;

  bool get isEnglish => language == AppLanguage.en;

  String _t(String en, String hi) => isEnglish ? en : hi;

  // --- Navigation and common --------------------------------------------

  String get appName => 'Railocity';
  String get navHome => _t('Home', 'होम');
  String get navJourney => _t('My Journey', 'मेरी यात्रा');
  String get navAlerts => _t('Alerts', 'अलर्ट');
  String get navAssistant => _t('Assistant', 'सहायक');
  String get navSettings => _t('Settings', 'सेटिंग्स');

  String get refresh => _t('Refresh', 'ताज़ा करें');
  String get retry => _t('Try again', 'फिर कोशिश करें');
  String get cancel => _t('Cancel', 'रद्द करें');
  String get remove => _t('Remove', 'हटाएं');
  String get save => _t('Save journey', 'यात्रा सहेजें');

  // --- Data source and freshness ----------------------------------------

  String get demoBannerTitle => _t('Demo data', 'डेमो डेटा');
  String get demoBannerBody => _t(
    'These trains and times are simulated. They are not live railway information.',
    'ये ट्रेनें और समय नकली (सिमुलेटेड) हैं। ये लाइव रेलवे जानकारी नहीं हैं।',
  );

  String updatedLine(DateTime updatedAt, DateTime now, String source) {
    final age = now.difference(updatedAt).inMinutes;
    final when = age < 1 ? _t('just now', 'अभी') : ago(age);
    return _t(
      'Updated ${formatClock(updatedAt)} ($when) · Source: $source',
      'अपडेट ${formatClock(updatedAt)} ($when) · स्रोत: $source',
    );
  }

  String ago(int minutes) =>
      _t('${duration(minutes)} ago', '${duration(minutes)} पहले');

  String get noStatusYet => _t(
    'No train status has been loaded yet.',
    'अभी तक ट्रेन की स्थिति लोड नहीं हुई है।',
  );

  String staleBanner(DateTime updatedAt, DateTime now) {
    final age = now.difference(updatedAt).inMinutes;
    return _t(
      'We last got train status ${duration(age)} ago. The times below may have changed. Check an official source before you travel.',
      'हमें ट्रेन की स्थिति आखिरी बार ${duration(age)} पहले मिली थी। नीचे दिए समय बदल सकते हैं। यात्रा से पहले आधिकारिक स्रोत देखें।',
    );
  }

  String get refreshFailed => _t(
    'We could not load the latest train status. Check your internet connection and try again. The times below may be out of date.',
    'हम ट्रेन की ताज़ा स्थिति लोड नहीं कर सके। अपना इंटरनेट देखें और फिर कोशिश करें। नीचे दिए समय पुराने हो सकते हैं।',
  );

  String get refreshing =>
      _t('Loading the latest train status…', 'ताज़ा स्थिति लोड हो रही है…');

  // --- Durations ---------------------------------------------------------

  /// Example: `1 h 30 min`.
  String duration(int minutes) {
    final m = minutes.abs();
    final h = m ~/ 60;
    final r = m % 60;
    if (isEnglish) {
      if (h == 0) return '$m min';
      if (r == 0) return '$h h';
      return '$h h $r min';
    }
    if (h == 0) return '$m मिनट';
    if (r == 0) return '$h घंटे';
    return '$h घंटे $r मिनट';
  }

  // --- Home --------------------------------------------------------------

  String get homeEmptyTitle => _t('Add your journey', 'अपनी यात्रा जोड़ें');
  String get homeEmptyBody => _t(
    'Enter your train number. We will tell you when something changes and what you can do.',
    'अपनी ट्रेन का नंबर डालें। कुछ बदलने पर हम बताएंगे और आप क्या कर सकते हैं यह भी बताएंगे।',
  );
  String get addJourney => _t('Add a journey', 'यात्रा जोड़ें');

  String healthHeadline(JourneyHealth health, int delayMinutes) =>
      switch (health) {
        JourneyHealth.onTrack => _t(
          'Your journey is on time',
          'आपकी यात्रा समय पर है',
        ),
        JourneyHealth.delayed => _t(
          'Your train is about ${duration(delayMinutes)} late',
          'आपकी ट्रेन लगभग ${duration(delayMinutes)} देर से है',
        ),
        JourneyHealth.atRisk => _t(
          'Your connection is at risk',
          'आपका कनेक्शन छूटने का जोखिम है',
        ),
        JourneyHealth.likelyMissed => _t(
          'You may miss your connection',
          'आपका कनेक्शन छूट सकता है',
        ),
        JourneyHealth.cancelled => _t(
          'A train on your journey is cancelled',
          'आपकी यात्रा की एक ट्रेन रद्द है',
        ),
        JourneyHealth.unknown => _t(
          'We cannot confirm your journey status',
          'हम आपकी यात्रा की स्थिति की पुष्टि नहीं कर सकते',
        ),
      };

  /// The plain meaning of the status, in one or two sentences.
  String healthDetail(JourneyView view, {required L10nNames names}) {
    final connection = view.worstConnection;
    switch (view.health) {
      case JourneyHealth.onTrack:
        return _t(
          'Your trains are running to the timetable.',
          'आपकी ट्रेनें समय सारणी के अनुसार चल रही हैं।',
        );
      case JourneyHealth.delayed:
        if (connection != null &&
            connection.verdict == ConnectionVerdict.feasible) {
          return _t(
            'Your connection should still work. We will tell you if this changes.',
            'आपका कनेक्शन अब भी मिल सकता है। कुछ बदला तो हम बताएंगे।',
          );
        }
        return _t(
          'Check the new time before you leave for the station.',
          'स्टेशन के लिए निकलने से पहले नया समय देखें।',
        );
      case JourneyHealth.atRisk:
      case JourneyHealth.likelyMissed:
      case JourneyHealth.cancelled:
      case JourneyHealth.unknown:
        if (connection == null) {
          return view.health == JourneyHealth.cancelled
              ? _t(
                  'Look at your options and the official refund guidance.',
                  'अपने विकल्प और रिफंड का आधिकारिक मार्गदर्शन देखें।',
                )
              : _t(
                  'Check train status on an official source.',
                  'किसी आधिकारिक स्रोत पर ट्रेन की स्थिति देखें।',
                );
        }
        return connectionDetail(connection, names: names);
    }
  }

  String nextStep(JourneyHealth health) => switch (health) {
    JourneyHealth.onTrack => _t(
      'No action is needed now. We will tell you if something changes.',
      'अभी कुछ करने की ज़रूरत नहीं है। कुछ बदला तो हम बताएंगे।',
    ),
    JourneyHealth.delayed => _t(
      'Check the new time before you leave for the station.',
      'स्टेशन के लिए निकलने से पहले नया समय देखें।',
    ),
    JourneyHealth.atRisk => _t(
      'Look at the other trains now, so you can decide quickly.',
      'अभी दूसरी ट्रेनें देखें, ताकि आप जल्दी फैसला कर सकें।',
    ),
    JourneyHealth.likelyMissed => _t(
      'Look at the other trains and the official guidance for missed connections.',
      'दूसरी ट्रेनें और छूटे कनेक्शन का आधिकारिक मार्गदर्शन देखें।',
    ),
    JourneyHealth.cancelled => _t(
      'Look at your options and the official refund guidance.',
      'अपने विकल्प और रिफंड का आधिकारिक मार्गदर्शन देखें।',
    ),
    JourneyHealth.unknown => _t(
      'Check train status on an official source.',
      'किसी आधिकारिक स्रोत पर ट्रेन की स्थिति देखें।',
    ),
  };

  String get seeAlternatives => _t('See other trains', 'दूसरी ट्रेनें देखें');
  String get askAssistant => _t('Ask the assistant', 'सहायक से पूछें');
  String get officialHelp => _t('Official help', 'आधिकारिक सहायता');
  String get needsYourAction => _t('Needs your action', 'आपकी कार्रवाई चाहिए');
  String get otherUpdates => _t('Other updates', 'अन्य अपडेट');
  String get seeAllAlerts => _t('See all alerts', 'सभी अलर्ट देखें');
  String get noAlerts => _t(
    'No alerts. We will tell you if something changes.',
    'कोई अलर्ट नहीं। कुछ बदला तो हम बताएंगे।',
  );

  // --- Connection explanation -------------------------------------------

  String connectionDetail(ConnectionAssessment a, {required L10nNames names}) {
    final station = names.station(a.stationCode);
    final arr = names.train(a.arrivingTrain);
    final dep = names.train(a.departingTrain);

    if (a.verdict == ConnectionVerdict.cancelled) {
      final cancelled = names.train(a.cancelledTrain ?? a.arrivingTrain);
      return _t(
        'Train $cancelled is cancelled. You cannot make this connection.',
        'ट्रेन $cancelled रद्द है। आप यह कनेक्शन नहीं पकड़ सकते।',
      );
    }
    final expArr = a.expectedArrival;
    final expDep = a.expectedDeparture;
    final window = a.windowMinutes;
    if (a.verdict == ConnectionVerdict.unknown ||
        expArr == null ||
        expDep == null ||
        window == null) {
      return _t(
        'We do not have enough current data to check this connection. Check the official sources.',
        'इस कनेक्शन को जांचने के लिए हमारे पास पर्याप्त ताज़ा डेटा नहीं है। आधिकारिक स्रोत देखें।',
      );
    }
    final arrTime = formatClock(expArr);
    final depTime = formatClockWithDay(expDep, expArr);
    final head = _t(
      'Train $arr should reach $station at about $arrTime. Train $dep leaves at $depTime.',
      'ट्रेन $arr लगभग $arrTime बजे $station पहुंचेगी। ट्रेन $dep $depTime बजे छूटती है।',
    );
    final transfer = a.transferMinutes;
    final slack = a.slackMinutes;

    switch (a.verdict) {
      case ConnectionVerdict.feasible:
        if (transfer != null && slack != null) {
          return '$head ${_t('You need about ${duration(transfer)} to change trains, so you have about ${duration(slack)} to spare.', 'ट्रेन बदलने में लगभग ${duration(transfer)} लगते हैं, इसलिए आपके पास लगभग ${duration(slack)} बचते हैं।')}';
        }
        return '$head ${_t('That is about ${duration(window)} between the trains. We do not have the walking time for this station.', 'दोनों ट्रेनों के बीच लगभग ${duration(window)} है। इस स्टेशन पर चलने का समय हमारे पास नहीं है।')}';
      case ConnectionVerdict.atRisk:
        if (transfer != null && slack != null) {
          return '$head ${_t('You need about ${duration(transfer)} to change trains. You have about ${duration(slack)} to spare. This is tight.', 'ट्रेन बदलने में लगभग ${duration(transfer)} लगते हैं। आपके पास लगभग ${duration(slack)} बचते हैं। यह बहुत कम है।')}';
        }
        return '$head ${_t('That is about ${duration(window)} between the trains. We do not know how long you need to change trains. This may be tight.', 'दोनों ट्रेनों के बीच लगभग ${duration(window)} है। ट्रेन बदलने में कितना समय लगेगा, यह हमें नहीं पता। समय कम हो सकता है।')}';
      case ConnectionVerdict.likelyMissed:
        final wait = _t(
          'Do not count on the train waiting.',
          'ट्रेन के रुकने पर भरोसा न करें।',
        );
        if (window <= 0) {
          return '$head ${_t('Train $dep is expected to leave before train $arr arrives. $wait', 'ट्रेन $dep, ट्रेन $arr के आने से पहले छूटने वाली है। $wait')}';
        }
        if (transfer != null && slack != null) {
          return '$head ${_t('You need about ${duration(transfer)} to change trains, but there is only about ${duration(window)} between the trains. You are short by about ${duration(-slack)}. $wait', 'ट्रेन बदलने में लगभग ${duration(transfer)} लगते हैं, पर दोनों ट्रेनों के बीच केवल लगभग ${duration(window)} है। लगभग ${duration(-slack)} कम पड़ रहे हैं। $wait')}';
        }
        return '$head ${_t('There is only about ${duration(window)} between the trains. That is very little time. $wait', 'दोनों ट्रेनों के बीच केवल लगभग ${duration(window)} है। यह बहुत कम समय है। $wait')}';
      case ConnectionVerdict.cancelled:
      case ConnectionVerdict.unknown:
        return head;
    }
  }

  String get verdictFeasible => _t('Enough time', 'पर्याप्त समय');
  String get verdictAtRisk => _t('Tight', 'समय कम');
  String get verdictLikelyMissed => _t('Likely missed', 'छूटने की संभावना');
  String get verdictCancelled => _t('Cancelled', 'रद्द');
  String get verdictUnknown => _t('Unknown', 'पता नहीं');

  String verdictLabel(ConnectionVerdict v) => switch (v) {
    ConnectionVerdict.feasible => verdictFeasible,
    ConnectionVerdict.atRisk => verdictAtRisk,
    ConnectionVerdict.likelyMissed => verdictLikelyMissed,
    ConnectionVerdict.cancelled => verdictCancelled,
    ConnectionVerdict.unknown => verdictUnknown,
  };

  // --- Journey -----------------------------------------------------------

  String get journeyTitle => _t('My Journey', 'मेरी यात्रा');
  String get noJourneys =>
      _t('You have no saved journeys.', 'आपकी कोई यात्रा सहेजी नहीं गई है।');
  String get scheduled => _t('Timetable', 'समय सारणी');
  String get expected => _t('Expected', 'अनुमानित');
  String get platformLabel => _t('Platform', 'प्लेटफॉर्म');
  String get platformUnknown => _t(
    'Not known yet. Check the station board.',
    'अभी पता नहीं। स्टेशन बोर्ड देखें।',
  );
  String get onTime => _t('On time', 'समय पर');
  String delayedBy(int minutes) =>
      _t('About ${duration(minutes)} late', 'लगभग ${duration(minutes)} देर से');
  String get cancelledLabel => _t('Cancelled', 'रद्द');
  String get statusUnknown => _t('Status not available', 'स्थिति उपलब्ध नहीं');
  String get changeTrains => _t('Change trains', 'ट्रेन बदलें');
  String changeAt(String station) =>
      _t('Change trains at $station', '$station पर ट्रेन बदलें');
  String get timeBetweenTrains =>
      _t('Time between trains', 'ट्रेनों के बीच समय');
  String get timeToChange =>
      _t('Time you need to change', 'ट्रेन बदलने में लगने वाला समय');
  String get spareTime => _t('Spare time', 'बचा हुआ समय');
  String get notKnown => _t('Not known', 'पता नहीं');
  String get removeJourney => _t('Remove journey', 'यात्रा हटाएं');
  String get removeJourneyTitle =>
      _t('Remove this journey?', 'यह यात्रा हटाएं?');
  String get removeJourneyBody => _t(
    'You will stop getting alerts for it.',
    'इसके लिए आपको अलर्ट मिलना बंद हो जाएगा।',
  );

  // --- Add journey -------------------------------------------------------

  String get addJourneyTitle => _t('Add a journey', 'यात्रा जोड़ें');
  String get firstTrainLabel => _t('First train number', 'पहली ट्रेन का नंबर');
  String get secondTrainLabel => _t(
    'Connecting train number (optional)',
    'कनेक्टिंग ट्रेन का नंबर (वैकल्पिक)',
  );
  String get trainNumberHelp => _t('5 digits', '5 अंक');
  String get checkJourney => _t('Check journey', 'यात्रा जांचें');
  String get useDemoJourney =>
      _t('Use the demo journey', 'डेमो यात्रा इस्तेमाल करें');
  String get invalidTrainNumber =>
      _t('Enter a 5-digit train number.', '5 अंकों का ट्रेन नंबर डालें।');
  String trainNotFound(String number) => _t(
    'We could not find train $number. Check the number and try again.',
    'हमें ट्रेन $number नहीं मिली। नंबर जांचें और फिर कोशिश करें।',
  );
  String get trainsDoNotMeet => _t(
    'These two trains do not stop at the same station in the right order. Check both numbers.',
    'ये दो ट्रेनें सही क्रम में एक ही स्टेशन पर नहीं रुकतीं। दोनों नंबर जांचें।',
  );
  String get lookupFailed => _t(
    'We could not load train information. Check your internet connection and try again.',
    'हम ट्रेन की जानकारी लोड नहीं कर सके। अपना इंटरनेट देखें और फिर कोशिश करें।',
  );
  String get checkingTrains =>
      _t('Checking the trains…', 'ट्रेनें जांच रहे हैं…');
  String get yourJourney => _t('Your journey', 'आपकी यात्रा');

  // --- Alerts ------------------------------------------------------------

  String get alertsTitle => _t('Alerts', 'अलर्ट');
  String get markAllRead =>
      _t('Mark all as read', 'सभी को पढ़ा हुआ चिह्नित करें');
  String get markRead => _t('Mark as read', 'पढ़ा हुआ चिह्नित करें');
  String get showOriginal =>
      _t('Show original (English)', 'मूल अंग्रेज़ी देखें');
  String get showTranslation => _t('Show translation', 'अनुवाद देखें');
  String get fromRailwayData => _t('From railway data', 'रेलवे डेटा से');
  String get calculatedByRailocity =>
      _t('Calculated by Railocity', 'Railocity द्वारा गणना');
  String get unreadLabel => _t('Unread', 'अपठित');

  String alertTitle(RailAlert a) {
    final station = a.stationName ?? '';
    switch (a.type) {
      case AlertType.cancellation:
        return _t(
          'Train ${a.trainName} (${a.trainNumber}) is cancelled',
          'ट्रेन ${a.trainName} (${a.trainNumber}) रद्द है',
        );
      case AlertType.delay:
        return _t(
          'Train ${a.trainName} is about ${duration(a.delayMinutes ?? 0)} late',
          'ट्रेन ${a.trainName} लगभग ${duration(a.delayMinutes ?? 0)} देर से है',
        );
      case AlertType.platformChange:
        return _t(
          'Platform change at $station: train ${a.trainName} now uses platform ${a.platform}',
          '$station पर प्लेटफॉर्म बदला: ट्रेन ${a.trainName} अब प्लेटफॉर्म ${a.platform} पर आएगी',
        );
      case AlertType.connectionRisk:
        return a.verdict == ConnectionVerdict.likelyMissed
            ? _t(
                'You may miss your connection at $station',
                '$station पर आपका कनेक्शन छूट सकता है',
              )
            : _t(
                'Your connection at $station is at risk',
                '$station पर आपका कनेक्शन छूटने का जोखिम है',
              );
      case AlertType.boardingReminder:
        return _t(
          'Train ${a.trainName} leaves soon',
          'ट्रेन ${a.trainName} जल्द छूटेगी',
        );
    }
  }

  String alertBody(RailAlert a) {
    final station = a.stationName ?? '';
    final other = a.relatedTrainName ?? '';
    switch (a.type) {
      case AlertType.cancellation:
        return _t(
          'Your journey is affected. Look at your options and the official refund guidance.',
          'आपकी यात्रा प्रभावित है। अपने विकल्प और रिफंड का आधिकारिक मार्गदर्शन देखें।',
        );
      case AlertType.delay:
        return switch (a.verdict) {
          ConnectionVerdict.atRisk || ConnectionVerdict.likelyMissed => _t(
            'Your connection with train $other may be affected. Check your connection and the other trains.',
            'ट्रेन $other के साथ आपका कनेक्शन प्रभावित हो सकता है। अपना कनेक्शन और दूसरी ट्रेनें देखें।',
          ),
          ConnectionVerdict.feasible => _t(
            'Your connection should still work. We will tell you if this changes.',
            'आपका कनेक्शन अब भी मिल सकता है। कुछ बदला तो हम बताएंगे।',
          ),
          _ => _t(
            'Check the new time before you leave for the station.',
            'स्टेशन के लिए निकलने से पहले नया समय देखें।',
          ),
        };
      case AlertType.platformChange:
        final was = a.previousPlatform == null
            ? ''
            : _t(
                'It was platform ${a.previousPlatform}. ',
                'पहले यह प्लेटफॉर्म ${a.previousPlatform} था। ',
              );
        return '$was${_t('Check the station board before you go to the platform.', 'प्लेटफॉर्म पर जाने से पहले स्टेशन बोर्ड देखें।')}';
      case AlertType.connectionRisk:
        final dontCount = a.verdict == ConnectionVerdict.likelyMissed
            ? _t(
                ' Do not count on the train waiting.',
                ' ट्रेन के रुकने पर भरोसा न करें।',
              )
            : '';
        return _t(
          'Train $other may leave before you can change trains at $station.$dontCount Look at the other trains and the official guidance.',
          'आप $station पर ट्रेन बदल पाएं, इससे पहले ट्रेन $other छूट सकती है।$dontCount दूसरी ट्रेनें और आधिकारिक मार्गदर्शन देखें।',
        );
      case AlertType.boardingReminder:
        final time = a.eventTime == null ? '' : formatClock(a.eventTime!);
        final plat = a.platform == null
            ? ''
            : _t(' Platform ${a.platform}.', ' प्लेटफॉर्म ${a.platform}।');
        return _t(
          'It leaves $station at $time.$plat',
          'यह $station से $time बजे छूटती है।$plat',
        );
    }
  }

  // --- Alternatives ------------------------------------------------------

  String get alternativesTitle => _t('Other trains', 'दूसरी ट्रेनें');
  String get alternativesNote => _t(
    'This is not a booking. Seat availability is not checked. Check availability on the official booking site.',
    'यह बुकिंग नहीं है। सीट की उपलब्धता नहीं जांची गई है। आधिकारिक बुकिंग साइट पर उपलब्धता देखें।',
  );
  String get noAlternatives => _t(
    'We found no later train that you can reach in time. Check an official source for more options.',
    'हमें ऐसी कोई बाद की ट्रेन नहीं मिली जिसे आप समय पर पकड़ सकें। और विकल्पों के लिए आधिकारिक स्रोत देखें।',
  );
  String leavesAt(String station, String time) =>
      _t('Leaves $station at $time', '$station से $time बजे छूटती है');
  String arrivesAt(String station, String time) =>
      _t('Arrives at $station at $time', '$station पर $time बजे पहुंचती है');
  String get journeyTime => _t('Journey time', 'यात्रा का समय');
  String get timetableOnly => _t(
    'Live status is not available. These times come from the timetable.',
    'लाइव स्थिति उपलब्ध नहीं है। ये समय समय सारणी से हैं।',
  );
  String get alternativesBasis => _t(
    'Based on your expected arrival and the time you need to change trains.',
    'आपके अनुमानित पहुंचने के समय और ट्रेन बदलने में लगने वाले समय के आधार पर।',
  );
  String get checkAvailability =>
      _t('Check availability on IRCTC', 'IRCTC पर उपलब्धता देखें');

  // --- Support -----------------------------------------------------------

  String get supportTitle => _t('Official help', 'आधिकारिक सहायता');
  String get supportYourSituation => _t('Your situation', 'आपकी स्थिति');
  String get supportSources => _t('Official sources', 'आधिकारिक स्रोत');
  String get supportLimits => _t(
    'Railocity cannot file complaints, cancel tickets or process refunds. Use the official sources below.',
    'Railocity शिकायत दर्ज नहीं कर सकता, टिकट रद्द नहीं कर सकता और रिफंड प्रोसेस नहीं कर सकता। नीचे दिए आधिकारिक स्रोत इस्तेमाल करें।',
  );
  String get supportVerify => SupportRules.verifiedOn == null
      ? _t(
          'These rule summaries have not been checked by the Railocity team yet. Confirm them on the official site before you act.',
          'इन नियमों का सार Railocity टीम ने अभी जांचा नहीं है। कार्रवाई से पहले आधिकारिक साइट पर इनकी पुष्टि करें।',
        )
      : _t(
          'Rule summaries last checked on ${SupportRules.verifiedOn}. Confirm them on the official site before you act.',
          'नियमों का सार आखिरी बार ${SupportRules.verifiedOn} को जांचा गया। कार्रवाई से पहले आधिकारिक साइट पर पुष्टि करें।',
        );

  String refundHint(RefundHint hint) => switch (hint) {
    RefundHint.trainCancelled => _t(
      'Your train is cancelled. Indian Railways rules say you may be able to get a refund for a cancelled train. Check how this applies to your ticket on the official site.',
      'आपकी ट्रेन रद्द है। भारतीय रेल के नियमों के अनुसार रद्द ट्रेन के लिए आपको रिफंड मिल सकता है। आपके टिकट पर यह कैसे लागू होता है, आधिकारिक साइट पर देखें।',
    ),
    RefundHint.delayOverThreshold => _t(
      'Your train is more than ${duration(SupportRules.delayRefundThresholdMinutes)} late. Indian Railways rules say you may be able to cancel and ask for a refund when a train is this late. Rules can differ by ticket type. Check the official site.',
      'आपकी ट्रेन ${duration(SupportRules.delayRefundThresholdMinutes)} से ज़्यादा देर से है। भारतीय रेल के नियमों के अनुसार इतनी देरी पर आप टिकट रद्द करके रिफंड मांग सकते हैं। नियम टिकट के प्रकार के अनुसार अलग हो सकते हैं। आधिकारिक साइट देखें।',
    ),
    RefundHint.delayBelowThreshold => _t(
      'Your train is not late enough for the delay-refund rule. If your plans change, check the official cancellation rules.',
      'आपकी ट्रेन देरी-रिफंड नियम के लिए पर्याप्त देर से नहीं है। योजना बदले तो रद्द करने के आधिकारिक नियम देखें।',
    ),
    RefundHint.unknown => _t(
      'We cannot check your train right now. Use the official sources to check the rules.',
      'हम अभी आपकी ट्रेन जांच नहीं सकते। नियम जांचने के लिए आधिकारिक स्रोत इस्तेमाल करें।',
    ),
  };

  String resourceTitle(OfficialResource r) => r.title;

  String resourceUseFor(OfficialResource r) => switch (r.id) {
    'ntes' => _t(
      'Check the running status of a train.',
      'ट्रेन की चलती स्थिति देखें।',
    ),
    'irctc' => _t(
      'Book tickets, cancel tickets and file a refund request (TDR).',
      'टिकट बुक करें, टिकट रद्द करें और रिफंड का अनुरोध (TDR) करें।',
    ),
    'railmadad' => _t(
      'Make a complaint or ask for help.',
      'शिकायत करें या सहायता मांगें।',
    ),
    'indianrailways' => _t(
      'Read official rules and notices.',
      'आधिकारिक नियम और सूचनाएं पढ़ें।',
    ),
    _ => r.useFor,
  };

  String get openLink => _t('Open', 'खोलें');
  String openFailed(String url) => _t(
    'We could not open the link. The address is: $url',
    'हम लिंक नहीं खोल सके। पता: $url',
  );
  String helpline(String number) =>
      _t('Helpline: $number', 'हेल्पलाइन: $number');

  // --- Settings ----------------------------------------------------------

  String get settingsTitle => _t('Settings', 'सेटिंग्स');
  String get languageSection => _t('Language', 'भाषा');
  String get translationNote => _t(
    'Train numbers, times and platforms are never translated. Hindi text is a draft.',
    'ट्रेन नंबर, समय और प्लेटफॉर्म कभी अनुवादित नहीं होते। हिन्दी पाठ एक प्रारंभिक मसौदा है।',
  );
  String get notificationsSection => _t('Alerts', 'अलर्ट');
  String get delayAlerts => _t('Delay alerts', 'देरी के अलर्ट');
  String get platformAlerts =>
      _t('Platform change alerts', 'प्लेटफॉर्म बदलने के अलर्ट');
  String get reminderAlerts =>
      _t('Boarding reminders', 'चढ़ने की याद दिलाने वाले अलर्ट');
  String get minDelay =>
      _t('Smallest delay to tell you about', 'कितनी देरी पर बताएं (न्यूनतम)');
  String get alwaysOn => _t(
    'Cancellation and missed-connection alerts are always on.',
    'रद्द ट्रेन और छूटे कनेक्शन के अलर्ट हमेशा चालू रहते हैं।',
  );
  String get aboutDataSection => _t('About the data', 'डेटा के बारे में');
  String dataSourceInfo(String label, {required bool simulated}) => simulated
      ? _t(
          'Source: $label. This data is made up for the prototype. It is not live railway information.',
          'स्रोत: $label। यह डेटा प्रोटोटाइप के लिए बनाया गया है। यह लाइव रेलवे जानकारी नहीं है।',
        )
      : _t('Source: $label.', 'स्रोत: $label।');
  String aiStatus({required bool connected}) => connected
      ? _t(
          'AI explanations are on. The AI only sees verified journey data. We check its text before we show it.',
          'AI स्पष्टीकरण चालू हैं। AI केवल सत्यापित यात्रा डेटा देखता है। दिखाने से पहले हम उसका पाठ जांचते हैं।',
        )
      : _t(
          'AI explanations are off. The assistant uses Railocity\'s built-in explanations.',
          'AI स्पष्टीकरण बंद हैं। सहायक Railocity के अपने स्पष्टीकरण इस्तेमाल करता है।',
        );
  String get demoControlsSection => _t('Demo controls', 'डेमो नियंत्रण');
  String get demoControlsBody => _t(
    'Use these to simulate a disruption. They change demo data only.',
    'इनसे बाधा का अनुकरण करें। ये केवल डेमो डेटा बदलते हैं।',
  );

  // --- Assistant ---------------------------------------------------------

  String get assistantTitle => _t('Assistant', 'सहायक');
  String get assistantIntro => _t(
    'Ask about your journey. I use verified train data and calculations. I do not make up train times, platforms or refund rules.',
    'अपनी यात्रा के बारे में पूछें। मैं सत्यापित ट्रेन डेटा और गणनाओं का उपयोग करता हूं। मैं ट्रेन के समय, प्लेटफॉर्म या रिफंड के नियम अपनी ओर से नहीं बनाता।',
  );
  String get askHint => _t('Ask a question', 'प्रश्न पूछें');
  String get send => _t('Send', 'भेजें');
  String get thinking =>
      _t('Checking the latest data…', 'ताज़ा डेटा जांच रहे हैं…');
  String get suggestConnection =>
      _t('Will I make my connection?', 'क्या मेरा कनेक्शन मिलेगा?');
  String get suggestOptions =>
      _t('What are my options?', 'मेरे पास क्या विकल्प हैं?');
  String get suggestRefund =>
      _t('Can I get a refund?', 'क्या मुझे रिफंड मिल सकता है?');
  String get suggestPlatform => _t('Which platform?', 'कौन सा प्लेटफॉर्म?');

  String get sectionVerified =>
      _t('Verified railway data', 'सत्यापित रेलवे डेटा');
  String get sectionCalculated =>
      _t('Calculated by Railocity', 'Railocity द्वारा गणना');
  String get sectionAi => _t('AI explanation', 'AI स्पष्टीकरण');
  String get sectionSummary => _t('Summary', 'सारांश');
  String get sectionNext =>
      _t('What you can do next', 'आप आगे क्या कर सकते हैं');
  String get badgeVerified => _t('Verified data', 'सत्यापित डेटा');
  String get badgeDemo => _t('Demo data', 'डेमो डेटा');
  String get badgeCalculated => _t('Calculated', 'गणना');
  String get badgeAi => _t('AI-generated', 'AI द्वारा बनाया');
  String get badgeRailocity =>
      _t('Written by Railocity, not AI', 'Railocity ने लिखा, AI ने नहीं');

  String get noticeAiOff => _t(
    'AI explanations are not connected. Railocity wrote this summary from the data above.',
    'AI स्पष्टीकरण जुड़े नहीं हैं। यह सारांश Railocity ने ऊपर के डेटा से लिखा है।',
  );
  String get noticeAiUnavailable => _t(
    'The AI service did not answer. Railocity wrote this summary from the data above.',
    'AI सेवा ने जवाब नहीं दिया। यह सारांश Railocity ने ऊपर के डेटा से लिखा है।',
  );
  String get noticeAiRejected => _t(
    'We did not show the AI text because it did not match the verified data. Railocity wrote this summary instead.',
    'हमने AI का पाठ नहीं दिखाया, क्योंकि वह सत्यापित डेटा से मेल नहीं खाता था। इसके बदले Railocity ने यह सारांश लिखा है।',
  );
  String get noJourneyReply => _t(
    'Add a journey first. Then I can check your connection.',
    'पहले एक यात्रा जोड़ें। फिर मैं आपका कनेक्शन जांच सकता हूं।',
  );
  String get unknownQuestion => _t(
    'I can help with your connection, your other options, platforms and refunds. Choose a question below.',
    'मैं आपके कनेक्शन, दूसरे विकल्पों, प्लेटफॉर्म और रिफंड में मदद कर सकता हूं। नीचे से एक प्रश्न चुनें।',
  );
  String get assistantDataProblem => _t(
    'We could not load the latest train status, so this answer uses the last data we saved. Check an official source before you act.',
    'हम ताज़ा ट्रेन स्थिति लोड नहीं कर सके, इसलिए यह उत्तर हमारे आखिरी सहेजे डेटा पर आधारित है। कार्रवाई से पहले आधिकारिक स्रोत देखें।',
  );

  String get platformAdvice => _t(
    'Platforms can change at short notice. Check the station board before you go to the platform.',
    'प्लेटफॉर्म अचानक बदल सकते हैं। प्लेटफॉर्म पर जाने से पहले स्टेशन बोर्ड देखें।',
  );

  String get singleTrainNoConnection => _t(
    'Your journey has one train, so there is no connection to check.',
    'आपकी यात्रा में एक ही ट्रेन है, इसलिए जांचने के लिए कोई कनेक्शन नहीं है।',
  );

  String alternativeLine({
    required String train,
    required String departs,
    required String arrives,
    required int minutes,
    required ConnectionVerdict verdict,
  }) => _t(
    '$train: leaves at $departs, arrives at $arrives, journey time ${duration(minutes)}. ${verdictLabel(verdict)}.',
    '$train: $departs बजे छूटती है, $arrives बजे पहुंचती है, यात्रा का समय ${duration(minutes)}। ${verdictLabel(verdict)}।',
  );

  String factTrainStatus(
    String train, {
    int? delay,
    bool cancelled = false,
    bool known = true,
  }) {
    if (!known) {
      return _t(
        'Train $train: status not available.',
        'ट्रेन $train: स्थिति उपलब्ध नहीं।',
      );
    }
    if (cancelled) {
      return _t('Train $train: cancelled.', 'ट्रेन $train: रद्द।');
    }
    if ((delay ?? 0) <= 0) {
      return _t('Train $train: on time.', 'ट्रेन $train: समय पर।');
    }
    return _t(
      'Train $train: about ${duration(delay!)} late.',
      'ट्रेन $train: लगभग ${duration(delay)} देर से।',
    );
  }

  String factScheduled(String station, String time, {required bool arrival}) =>
      arrival
      ? _t(
          'Timetable arrival at $station: $time.',
          'समय सारणी के अनुसार $station पर पहुंचना: $time।',
        )
      : _t(
          'Timetable departure from $station: $time.',
          'समय सारणी के अनुसार $station से छूटना: $time।',
        );

  String factPlatform(String train, String station, String? platform) =>
      platform == null
      ? _t(
          'Platform for train $train at $station: not known yet. Check the station board.',
          '$station पर ट्रेन $train का प्लेटफॉर्म: अभी पता नहीं। स्टेशन बोर्ड देखें।',
        )
      : _t(
          'Platform for train $train at $station: $platform.',
          '$station पर ट्रेन $train का प्लेटफॉर्म: $platform।',
        );

  String calcExpected(
    String station,
    String time,
    int delay,
    String scheduled, {
    required bool arrival,
  }) => arrival
      ? _t(
          'Expected arrival at $station: $time (timetable $scheduled plus ${duration(delay)} delay).',
          '$station पर अनुमानित पहुंच: $time (समय सारणी $scheduled और ${duration(delay)} देरी)।',
        )
      : _t(
          'Expected departure from $station: $time (timetable $scheduled plus ${duration(delay)} delay).',
          '$station से अनुमानित प्रस्थान: $time (समय सारणी $scheduled और ${duration(delay)} देरी)।',
        );

  String calcWindow(int minutes) => minutes >= 0
      ? _t(
          'Time between the two trains: ${duration(minutes)}.',
          'दोनों ट्रेनों के बीच का समय: ${duration(minutes)}।',
        )
      : _t(
          'Train 2 leaves ${duration(minutes)} before train 1 arrives.',
          'ट्रेन 2, ट्रेन 1 के पहुंचने से ${duration(minutes)} पहले छूटती है।',
        );

  String calcTransfer(int? minutes) => minutes == null
      ? _t(
          'Time you need to change trains: not known for this station.',
          'ट्रेन बदलने में लगने वाला समय: इस स्टेशन के लिए पता नहीं।',
        )
      : _t(
          'Time you need to change trains: ${duration(minutes)}.',
          'ट्रेन बदलने में लगने वाला समय: ${duration(minutes)}।',
        );

  String calcSlack(int slack) => slack >= 0
      ? _t(
          'Spare time: ${duration(slack)}.',
          'बचा हुआ समय: ${duration(slack)}।',
        )
      : _t(
          'Short by: ${duration(slack)}.',
          'कम पड़ रहा समय: ${duration(slack)}।',
        );
}

/// Looks up the names used in sentences. It keeps [L10n] free of data lookups.
abstract interface class L10nNames {
  /// Example: `Demo Express (90101)`.
  String train(String number);
  String station(String code);
}

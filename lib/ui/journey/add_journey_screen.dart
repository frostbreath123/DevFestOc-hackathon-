import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../widgets/common.dart';

/// Enter one train, or two trains with a change. The journey is checked
/// before it is saved.
class AddJourneyScreen extends StatefulWidget {
  const AddJourneyScreen({super.key});

  @override
  State<AddJourneyScreen> createState() => _AddJourneyScreenState();
}

class _AddJourneyScreenState extends State<AddJourneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _scroll = ScrollController();

  bool _busy = false;
  AddJourneyPreview? _preview;
  AddJourneyException? _problem;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the result and the save button into view on small screens.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _check() async {
    final controller = AppScope.read(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _problem = null;
      _preview = null;
    });
    try {
      final preview = await controller.previewJourney(
        firstTrain: _first.text,
        secondTrain: _second.text,
      );
      if (!mounted) return;
      setState(() => _preview = preview);
      _scrollToEnd();
    } on AddJourneyException catch (error) {
      if (!mounted) return;
      setState(() => _problem = error);
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final controller = AppScope.read(context);
    final preview = _preview;
    if (preview == null) return;
    setState(() => _busy = true);
    await controller.addJourney(preview);
    if (mounted) Navigator.of(context).pop();
  }

  void _useDemo() {
    setState(() {
      _first.text = '90101';
      _second.text = '90202';
      _preview = null;
      _problem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = controller.l10n;
    final demo = controller.data.isSimulated;

    String? validate(String? value, {required bool optional}) {
      final text = (value ?? '').trim();
      if (text.isEmpty && optional) return null;
      return RegExp(r'^\d{5}$').hasMatch(text) ? null : l10n.invalidTrainNumber;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addJourneyTitle)),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(Space.m),
        children: [
          if (demo) ...[
            DemoBanner(l10n: l10n),
            const SizedBox(height: Space.m),
          ],
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _first,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.firstTrainLabel,
                    helperText: l10n.trainNumberHelp,
                  ),
                  validator: (v) => validate(v, optional: false),
                  onChanged: (_) => setState(() {
                    _preview = null;
                    _problem = null;
                  }),
                ),
                const SizedBox(height: Space.m),
                TextFormField(
                  controller: _second,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.secondTrainLabel,
                    helperText: l10n.trainNumberHelp,
                  ),
                  validator: (v) => validate(v, optional: true),
                  onChanged: (_) => setState(() {
                    _preview = null;
                    _problem = null;
                  }),
                ),
              ],
            ),
          ),
          if (demo)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _useDemo,
                child: Text(l10n.useDemoJourney),
              ),
            ),
          const SizedBox(height: Space.m),
          FilledButton(
            onPressed: _busy ? null : _check,
            child: Text(l10n.checkJourney),
          ),
          if (_busy) ...[
            const SizedBox(height: Space.m),
            Semantics(
              liveRegion: true,
              label: l10n.checkingTrains,
              child: const LinearProgressIndicator(),
            ),
          ],
          if (_problem != null) ...[
            const SizedBox(height: Space.m),
            NoticePanel(
              error: true,
              icon: Icons.error_outline,
              message: _problemText(_problem!, controller),
            ),
          ],
          if (_preview != null) ...[
            SectionTitle(l10n.yourJourney),
            _PreviewCard(preview: _preview!, controller: controller),
            const SizedBox(height: Space.m),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(l10n.save),
            ),
          ],
        ],
      ),
    );
  }

  String _problemText(AddJourneyException error, AppController controller) {
    final l10n = controller.l10n;
    return switch (error.problem) {
      AddJourneyProblem.invalidNumber => l10n.invalidTrainNumber,
      AddJourneyProblem.notFound => l10n.trainNotFound(error.train ?? ''),
      AddJourneyProblem.doNotMeet => l10n.trainsDoNotMeet,
      AddJourneyProblem.unavailable => l10n.lookupFailed,
    };
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview, required this.controller});

  final AddJourneyPreview preview;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = controller.l10n;
    String stationName(String code) {
      for (final schedule in preview.schedules.values) {
        final stop = schedule.stopAt(code);
        if (stop != null) return stop.station.name;
      }
      return code;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < preview.journey.legs.length; i++) ...[
              if (i > 0) ...[
                const Divider(height: Space.l),
                Row(
                  children: [
                    const Icon(Icons.transfer_within_a_station, size: 20),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text(
                        l10n.changeAt(
                          stationName(preview.journey.legs[i].boardCode),
                        ),
                        style: context.text.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const Divider(height: Space.l),
              ],
              Text(
                preview
                    .schedules[preview.journey.legs[i].trainNumber]!
                    .displayName,
                style: context.text.titleMedium,
              ),
              Text(
                '${stationName(preview.journey.legs[i].boardCode)} → '
                '${stationName(preview.journey.legs[i].alightCode)}',
                style: context.text.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

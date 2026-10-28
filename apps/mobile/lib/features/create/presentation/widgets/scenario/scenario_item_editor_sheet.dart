import 'package:flutter/material.dart';

import '../../../../../core/localization/l10n_context.dart';
import '../../../../../core/parsing/input_parsers.dart';

class ScenarioTimeBlockDraft {
  const ScenarioTimeBlockDraft({
    required this.title,
    required this.durationMinutes,
  });

  final String title;
  final int durationMinutes;
}

class ScenarioCustomStopDraft {
  const ScenarioCustomStopDraft({
    required this.title,
    required this.durationMinutes,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final int durationMinutes;
  final double latitude;
  final double longitude;
}

Future<ScenarioTimeBlockDraft?> showScenarioTimeBlockEditor(
  BuildContext context,
) async {
  final TextEditingController title = TextEditingController();
  final TextEditingController duration = TextEditingController(text: '60');
  final ScenarioTimeBlockDraft? result =
      await showModalBottomSheet<ScenarioTimeBlockDraft>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.createScenarioAddTimeBlock,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.createScenarioTitle,
                  hintText: context.l10n.createScenarioTimeBlockHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration, minutes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final int? minutes = int.tryParse(duration.text.trim());
                  if (title.text.trim().isEmpty ||
                      minutes == null ||
                      minutes <= 0) {
                    return;
                  }
                  Navigator.pop(
                    context,
                    ScenarioTimeBlockDraft(
                      title: title.text.trim(),
                      durationMinutes: minutes,
                    ),
                  );
                },
                child: Text(context.l10n.createScenarioAddScenario),
              ),
            ],
          ),
        ),
      );
  title.dispose();
  duration.dispose();
  return result;
}

Future<ScenarioCustomStopDraft?> showScenarioCustomStopEditor(
  BuildContext context,
) async {
  final TextEditingController title = TextEditingController();
  final TextEditingController duration = TextEditingController(text: '60');
  final TextEditingController latitude = TextEditingController();
  final TextEditingController longitude = TextEditingController();
  final ScenarioCustomStopDraft?
  result = await showModalBottomSheet<ScenarioCustomStopDraft>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.l10n.createScenarioAddCustomStop,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(context.l10n.createScenarioUseCoordinatesAnyLocationLatviaStop),
          const SizedBox(height: 12),
          TextField(
            controller: title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.createScenarioTitle,
              hintText: 'Park, viewpoint, private address…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration, minutes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('scenario-custom-stop-latitude'),
                  controller: latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.createFormLatitudeRequired,
                    hintText: '56.946',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('scenario-custom-stop-longitude'),
                  controller: longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.createFormLongitudeRequired,
                    hintText: '24.105',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final int? minutes = int.tryParse(duration.text.trim());
              final double? lat = _coordinate(latitude.text);
              final double? lng = _coordinate(longitude.text);
              if (title.text.trim().isEmpty ||
                  minutes == null ||
                  minutes <= 0 ||
                  lat == null ||
                  lng == null ||
                  lat < -90 ||
                  lat > 90 ||
                  lng < -180 ||
                  lng > 180) {
                return;
              }
              Navigator.pop(
                context,
                ScenarioCustomStopDraft(
                  title: title.text.trim(),
                  durationMinutes: minutes,
                  latitude: lat,
                  longitude: lng,
                ),
              );
            },
            child: Text(context.l10n.createScenarioAddCustomStop),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  duration.dispose();
  latitude.dispose();
  longitude.dispose();
  return result;
}

double? _coordinate(String value) {
  return parseLocaleDecimalInput(value);
}

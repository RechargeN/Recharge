import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_query.dart';
import '../../application/smart_search_parser.dart';
import '../../domain/entities/smart_search_history_entity.dart';

class SmartSearchPage extends ConsumerStatefulWidget {
  const SmartSearchPage({
    super.key,
    this.seedParameters = const <String, String>{},
  });

  final Map<String, String> seedParameters;

  @override
  ConsumerState<SmartSearchPage> createState() => _SmartSearchPageState();
}

class _SmartSearchPageState extends ConsumerState<SmartSearchPage> {
  static const List<_PromptSuggestion> _popularPrompts = <_PromptSuggestion>[
    _PromptSuggestion(
      icon: Icons.local_bar_outlined,
      label: 'Хочу спокойный вечер рядом',
    ),
    _PromptSuggestion(
      icon: Icons.auto_awesome_outlined,
      label: 'Найди что-то интересное на 2 часа',
    ),
    _PromptSuggestion(
      icon: Icons.group_outlined,
      label: 'Куда сходить вдвоём недалеко',
    ),
  ];

  late final TextEditingController _promptController;
  SmartSearchParseResult? _parseResult;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final String prompt = widget.seedParameters['prompt']?.trim() ?? '';
    _promptController = TextEditingController(text: prompt);
    _parseResult = prompt.isEmpty ? null : parseSmartSearch(prompt);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoverFeedControllerProvider).ensureSmartSearchHistoryLoaded();
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DiscoverFeedController controller = ref.watch(
      discoverFeedControllerProvider,
    );
    final List<SmartSearchHistoryEntity> history =
        controller.state.smartSearchHistory;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Smart Search'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Как работает Smart Search',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('smart-search-input'),
            controller: _promptController,
            minLines: 2,
            maxLines: 3,
            textInputAction: TextInputAction.search,
            onChanged: _parsePrompt,
            onSubmitted: (_) => _startSearch(controller),
            decoration: InputDecoration(
              hintText: 'Напишите или скажите,\nчто хотите найти',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Icon(Icons.search_rounded),
              ),
              suffixIcon: IconButton(
                tooltip: 'Голосовой запрос',
                onPressed: _showVoicePromptSheet,
                icon: const Icon(Icons.mic_none_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ExampleHint(
            onTap: () => _usePrompt(
              'Хочу сегодня вечером что-то спокойное рядом, до 20 EUR',
            ),
          ),
          if (_parseResult != null) ...<Widget>[
            const SizedBox(height: 12),
            _UnderstoodParameters(parseResult: _parseResult!),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _QuickPromptChip(
                  icon: Icons.near_me_outlined,
                  label: 'Рядом сейчас',
                  onPressed: () => _usePrompt('Что-то интересное рядом сейчас'),
                ),
                _QuickPromptChip(
                  icon: Icons.group_outlined,
                  label: 'Для двоих',
                  onPressed: () => _usePrompt('Куда сходить вдвоём'),
                ),
                _QuickPromptChip(
                  icon: Icons.nightlight_outlined,
                  label: 'Спокойный вечер',
                  onPressed: () => _usePrompt('Хочу спокойный вечер'),
                ),
                _QuickPromptChip(
                  icon: Icons.schedule_outlined,
                  label: '1–2 часа',
                  onPressed: () => _usePrompt('Найди план на 2 часа'),
                ),
                _QuickPromptChip(
                  icon: Icons.payments_outlined,
                  label: 'До €20',
                  onPressed: () => _usePrompt('Найди что-то до 20 EUR'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Популярные запросы',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < _popularPrompts.length;
                  index++
                ) ...<Widget>[
                  ListTile(
                    leading: Icon(
                      _popularPrompts[index].icon,
                      color: colorScheme.primary,
                    ),
                    title: Text(_popularPrompts[index].label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _usePrompt(_popularPrompts[index].label),
                  ),
                  if (index != _popularPrompts.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          if (history.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            Text(
              'Недавние Smart Search',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final SmartSearchHistoryEntity item in history.take(3))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(item.prompt, maxLines: 2),
                  trailing: IconButton(
                    tooltip: 'Удалить запрос',
                    onPressed: () =>
                        controller.deleteSmartSearchPrompt(item.id),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  onTap: () => _usePrompt(item.prompt),
                ),
              ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _submitting ? null : () => _startSearch(controller),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Начать поиск'),
            ),
          ),
        ],
      ),
    );
  }

  void _parsePrompt(String value) {
    setState(() {
      _parseResult = value.trim().isEmpty ? null : parseSmartSearch(value);
    });
  }

  void _usePrompt(String value) {
    _promptController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _parsePrompt(value);
  }

  Future<void> _startSearch(DiscoverFeedController controller) async {
    final String prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напишите или скажите, что найти')),
      );
      return;
    }

    final SmartSearchParseResult parsed = parseSmartSearch(prompt);
    final _DateWindow? window = switch (parsed.datePreset) {
      SmartSearchDatePreset.today => _todayWindow(),
      SmartSearchDatePreset.tonight => _tonightWindow(),
      null => null,
    };
    setState(() {
      _submitting = true;
      _parseResult = parsed;
    });
    await controller.applySearchConditions(
      queryText: parsed.queryText,
      selectedCategoryIds: parsed.selectedCategoryIds,
      freeOnly: parsed.freeOnly ?? false,
      budgetMax: parsed.budgetMax,
      clearBudgetMin: true,
      clearBudgetMax: parsed.budgetMax == null,
      dateFrom: window?.from,
      clearDateFrom: window == null,
      dateTo: window?.to,
      clearDateTo: window == null,
      radiusMeters: parsed.radiusMeters,
      unlimitedRadius: parsed.unlimitedRadius,
    );
    await controller.saveSmartSearchPrompt(
      prompt: parsed.originalText,
      query: controller.state.appliedQuery,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    context.go(_resultsLocation(controller.state.appliedQuery));
  }

  Future<void> _showVoicePromptSheet() async {
    final String? prompt = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.mic_none_rounded, size: 36),
              const SizedBox(height: 8),
              Text(
                'Скажите, что хотите найти',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final _PromptSuggestion suggestion in _popularPrompts)
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: Text(suggestion.label),
                  onTap: () => Navigator.of(context).pop(suggestion.label),
                ),
            ],
          ),
        ),
      ),
    );
    if (prompt != null) _usePrompt(prompt);
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Как работает Smart Search'),
        content: const Text(
          'Введите текстовый запрос или используйте '
          'голосовой ввод. Recharge разберёт время, место, '
          'бюджет и настроение и покажет подходящие варианты.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}

class _ExampleHint extends StatelessWidget {
  const _ExampleHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(Icons.lightbulb_outline_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Например: «Хочу сегодня вечером\n'
                  'что-то спокойное рядом, до 20 €»',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnderstoodParameters extends StatelessWidget {
  const _UnderstoodParameters({required this.parseResult});

  final SmartSearchParseResult parseResult;

  @override
  Widget build(BuildContext context) {
    final List<String> chips = parseResult.explanationChips.isEmpty
        ? <String>['Текстовый запрос']
        : parseResult.explanationChips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Понятые параметры',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips
              .map(
                (String chip) => Chip(
                  avatar: const Icon(Icons.check_rounded, size: 16),
                  label: Text(chip),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class _PromptSuggestion {
  const _PromptSuggestion({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _DateWindow {
  const _DateWindow(this.from, this.to);

  final DateTime from;
  final DateTime to;
}

_DateWindow _todayWindow() {
  final DateTime now = DateTime.now();
  final DateTime from = DateTime(now.year, now.month, now.day).toUtc();
  return _DateWindow(from, from.add(const Duration(days: 1)));
}

_DateWindow _tonightWindow() {
  final DateTime now = DateTime.now();
  final DateTime from = DateTime(now.year, now.month, now.day, 17).toUtc();
  return _DateWindow(from, from.add(const Duration(hours: 8)));
}

String _resultsLocation(DiscoverQuery query) {
  return Uri(
    path: RouteNames.discoverResults,
    queryParameters: <String, String>{
      'source': 'smart_search',
      'q': query.queryText,
      'category': query.selectedCategoryIds.join(','),
      'free': query.freeOnly ? '1' : '0',
      if (query.budgetMax != null)
        'budgetMax': query.budgetMax!.toStringAsFixed(0),
      if (query.dateFrom != null) 'dateFrom': query.dateFrom!.toIso8601String(),
      if (query.dateTo != null) 'dateTo': query.dateTo!.toIso8601String(),
      'radius': query.radiusMeters.round().toString(),
      'unlimited': query.unlimitedRadius ? '1' : '0',
    },
  ).toString();
}

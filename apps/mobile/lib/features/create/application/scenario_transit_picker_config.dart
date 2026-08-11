class ScenarioTransitPickerConfig {
  const ScenarioTransitPickerConfig({
    this.pickerEnabled = true,
    this.networkRefreshEnabled = true,
    this.stopSearchDebounce = const Duration(milliseconds: 300),
    this.minimumStopQueryLength = 2,
    this.stopResultLimit = 20,
    this.serviceResultLimit = 20,
  });

  final bool pickerEnabled;
  final bool networkRefreshEnabled;
  final Duration stopSearchDebounce;
  final int minimumStopQueryLength;
  final int stopResultLimit;
  final int serviceResultLimit;

  bool get isValid =>
      !stopSearchDebounce.isNegative &&
      minimumStopQueryLength >= 1 &&
      minimumStopQueryLength <= 100 &&
      stopResultLimit >= 1 &&
      stopResultLimit <= 100 &&
      serviceResultLimit >= 1 &&
      serviceResultLimit <= 100;
}

const scenarioTransitPickerConfig = ScenarioTransitPickerConfig(
  pickerEnabled: true,
);

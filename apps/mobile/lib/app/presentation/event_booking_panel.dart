import 'package:flutter/material.dart';

import '../../features/booking/application/event_booking_controller.dart';
import '../../features/booking/presentation/event_booking_section.dart';
import '../../features/discover/domain/entities/event_occurrence.dart';
import '../di/event_booking_composition.dart';

/// Hosts the Booking section inside Event Details. It shows nothing unless the
/// default-off test entry builds a controller: for the B2 fixture Event
/// ([target] null) or for the exact occurrence a Content Event references.
class EventBookingPanel extends StatefulWidget {
  const EventBookingPanel({super.key, this.target});

  final EventBookingRef? target;

  @override
  State<EventBookingPanel> createState() => _EventBookingPanelState();
}

class _EventBookingPanelState extends State<EventBookingPanel> {
  late final Future<EventBookingController?> _controller;
  EventBookingController? _created;

  @override
  void initState() {
    super.initState();
    final EventBookingRef? target = widget.target;
    final Future<EventBookingController?> created = target == null
        ? createEventBookingController()
        : createEventBookingControllerFor(
            eventId: target.eventId,
            occurrenceId: target.occurrenceId,
            channel: target.channel,
          );
    _controller = created.then((controller) {
      _created = controller;
      controller?.load();
      return controller;
    });
  }

  @override
  void dispose() {
    _created?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventBookingController?>(
      future: _controller,
      builder:
          (BuildContext context, AsyncSnapshot<EventBookingController?> s) {
            final EventBookingController? controller = s.data;
            if (controller == null) return const SizedBox.shrink();
            return EventBookingSection(controller: controller);
          },
    );
  }
}

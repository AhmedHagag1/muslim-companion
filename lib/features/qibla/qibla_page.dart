import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/location_service.dart';
import 'qibla_calculator.dart';
import 'qibla_controller.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key, required this.controller});

  final QiblaController controller;

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> with WidgetsBindingObserver {
  double _displayRelativeAngle = 0;
  double _displayNorthAngle = 0;
  double? _lastRelativeAngle;
  double? _lastHeading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    widget.controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      widget.controller.stop();
    }
  }

  void _onControllerChanged() {
    final relative = widget.controller.relativeQiblaAngle;
    if (relative != null) {
      if (_lastRelativeAngle == null) {
        _displayRelativeAngle = relative;
      } else {
        _displayRelativeAngle += QiblaCalculator.shortestDelta(
          _lastRelativeAngle!,
          relative,
        );
      }
      _lastRelativeAngle = relative;
    }

    final heading = widget.controller.deviceHeading;
    if (heading != null) {
      if (_lastHeading == null) {
        _displayNorthAngle = -heading;
      } else {
        _displayNorthAngle -= QiblaCalculator.shortestDelta(
          _lastHeading!,
          heading,
        );
      }
      _lastHeading = heading;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.appBackground,
    appBar: AppBar(
      title: const Text('القبلة'),
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            _bearingHeader(),
            const SizedBox(height: 28),
            Center(child: _compass()),
            const SizedBox(height: 28),
            _statusArea(),
          ],
        ),
      ),
    ),
  );

  Widget _bearingHeader() {
    final bearing = widget.controller.qiblaBearingDegrees;
    return Semantics(
      label: bearing == null
          ? 'اتجاه القبلة غير متاح حتى تحديد الموقع'
          : 'اتجاه القبلة ${bearing.round()} درجة من الشمال',
      child: Column(
        children: [
          Text(
            bearing == null ? '—' : '${bearing.round()}°',
            key: const ValueKey('qibla-bearing'),
            style: const TextStyle(
              color: AppColors.accentGold,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'من اتجاه الشمال',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (bearing != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'تم تحديد الموقع بنجاح',
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'تم تحديد الموقع',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compass() {
    final controller = widget.controller;
    final sensorAvailable =
        controller.compassAvailability == CompassAvailability.available;
    final mediaSize = MediaQuery.sizeOf(context);
    final size = math
        .min(mediaSize.shortestSide, mediaSize.height * 0.48)
        .clamp(230.0, 390.0);
    return Semantics(
      container: true,
      label: _compassSemanticLabel(),
      child: SizedBox.square(
        key: const ValueKey('qibla-compass'),
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _CompassDialPainter(aligned: controller.isAligned),
            ),
            AnimatedRotation(
              key: const ValueKey('qibla-north-ring'),
              turns: _displayNorthAngle / 360,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: SizedBox.square(
                dimension: size * 0.82,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            AnimatedRotation(
              key: const ValueKey('qibla-direction-arrow'),
              turns: sensorAvailable ? _displayRelativeAngle / 360 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: SizedBox.square(
                dimension: size * 0.68,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: _QiblaArrow(),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: controller.isAligned
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.surfaceRaised,
                border: Border.all(
                  color: controller.isAligned
                      ? AppColors.success
                      : AppColors.accentGold,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (controller.isAligned
                                ? AppColors.success
                                : AppColors.accentGold)
                            .withValues(alpha: 0.2),
                    blurRadius: controller.isAligned ? 28 : 14,
                  ),
                ],
              ),
              child: const Center(child: _KaabaMarker()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusArea() {
    final controller = widget.controller;
    if (controller.locationLoading) {
      return const _QiblaMessage(
        key: ValueKey('qibla-location-loading'),
        icon: Icons.location_searching_rounded,
        title: 'جارٍ تحديد موقعك',
        message: 'يُستخدم الموقع لحساب الاتجاه فقط.',
        progress: true,
      );
    }
    if (controller.locationFailure != null) {
      return _locationFailure(controller.locationFailure!);
    }
    if (controller.compassAvailability == CompassAvailability.unavailable) {
      return const _QiblaMessage(
        key: ValueKey('qibla-compass-unavailable'),
        icon: Icons.sensors_off_rounded,
        title: 'حساس البوصلة غير متاح',
        message:
            'يمكنك رؤية زاوية القبلة، لكن تدوير السهم المباشر يحتاج حساسًا مغناطيسيًا مدعومًا.',
      );
    }
    if (controller.compassAvailability == CompassAvailability.checking) {
      return const _QiblaMessage(
        key: ValueKey('qibla-compass-checking'),
        icon: Icons.sensors_rounded,
        title: 'جارٍ قراءة البوصلة',
        message: 'ضع الهاتف بشكل مستوٍ للحظات.',
        progress: true,
      );
    }
    if (controller.isAligned) {
      return const _QiblaMessage(
        key: ValueKey('qibla-aligned'),
        icon: Icons.check_circle_outline_rounded,
        title: 'أنت بمحاذاة القبلة',
        message: 'ثبت اتجاه الهاتف بهدوء.',
        success: true,
      );
    }
    return const _QiblaMessage(
      key: ValueKey('qibla-calibration-guidance'),
      icon: Icons.screen_rotation_alt_rounded,
      title: 'حرّك الهاتف بشكل رقم 8 عند الحاجة',
      message: 'أبعد الهاتف عن المعادن أو الأجهزة المغناطيسية لتحسين القراءة.',
    );
  }

  Widget _locationFailure(LocationFailureType failure) {
    final (title, message) = switch (failure) {
      LocationFailureType.serviceDisabled => (
        'خدمة الموقع متوقفة',
        'فعّل خدمة الموقع لحساب اتجاه القبلة.',
      ),
      LocationFailureType.permissionDenied => (
        'إذن الموقع مطلوب',
        'اسمح بالموقع عند إعادة المحاولة لحساب اتجاه القبلة.',
      ),
      LocationFailureType.permissionDeniedForever => (
        'إذن الموقع محظور',
        'اسمح بالموقع من إعدادات التطبيق ثم أعد المحاولة.',
      ),
      LocationFailureType.unavailable => (
        'تعذر تحديد الموقع',
        'تحقق من إشارة الموقع ثم أعد المحاولة.',
      ),
    };
    final settingsLabel = failure == LocationFailureType.serviceDisabled
        ? 'فتح إعدادات الموقع'
        : failure == LocationFailureType.permissionDeniedForever
        ? 'فتح إعدادات التطبيق'
        : null;
    return Semantics(
      label: 'الموقع غير متاح. $title. $message',
      child: Column(
        key: const ValueKey('qibla-location-unavailable'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _QiblaMessage(
            icon: Icons.location_off_rounded,
            title: title,
            message: message,
          ),
          if (settingsLabel != null)
            FilledButton.icon(
              key: const ValueKey('qibla-open-settings'),
              onPressed: widget.controller.openRelevantSettings,
              icon: const Icon(Icons.settings_rounded),
              label: Text(settingsLabel),
            ),
          TextButton.icon(
            key: const ValueKey('qibla-retry-location'),
            onPressed: widget.controller.retryLocation,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  String _compassSemanticLabel() {
    final controller = widget.controller;
    if (controller.compassAvailability == CompassAvailability.unavailable) {
      return 'حساس البوصلة غير متاح';
    }
    final heading = controller.deviceHeading;
    final bearing = controller.qiblaBearingDegrees;
    if (heading == null || bearing == null) {
      return 'اتجاه الهاتف أو موقع القبلة غير متاح حاليًا';
    }
    return 'اتجاه الهاتف ${heading.round()} درجة، اتجاه القبلة '
        '${bearing.round()} درجة، ${controller.isAligned ? 'محاذٍ للقبلة' : 'غير محاذٍ للقبلة'}';
  }
}

class _QiblaArrow extends StatelessWidget {
  const _QiblaArrow();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.navigation_rounded,
        color: AppColors.accentGold,
        size: 54,
      ),
      Container(
        width: 2,
        height: 48,
        color: AppColors.accentGold.withValues(alpha: 0.8),
      ),
    ],
  );
}

class _KaabaMarker extends StatelessWidget {
  const _KaabaMarker();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'علامة الكعبة المشرفة',
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF171713),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.accentGold, width: 1.4),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 9,
            left: 0,
            right: 0,
            child: Container(height: 5, color: AppColors.accentGold),
          ),
          Positioned(
            right: 8,
            bottom: 0,
            child: Container(
              width: 9,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QiblaMessage extends StatelessWidget {
  const _QiblaMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.progress = false,
    this.success = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool progress;
  final bool success;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '$title. $message',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress)
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            icon,
            color: success ? AppColors.success : AppColors.accentGold,
            size: 30,
          ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: success ? AppColors.success : AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    ),
  );
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter({required this.aligned});

  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = aligned ? 3 : 2
      ..color = (aligned ? AppColors.success : AppColors.accentGold).withValues(
        alpha: 0.72,
      );
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.divider.withValues(alpha: 0.85);
    canvas.drawCircle(center, radius - 3, border);
    canvas.drawCircle(center, radius * 0.78, inner);
    canvas.drawCircle(center, radius * 0.55, inner);

    final tick = Paint()
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accentGold.withValues(alpha: 0.58);
    for (var index = 0; index < 24; index++) {
      final angle = index * math.pi / 12 - math.pi / 2;
      final major = index % 6 == 0;
      tick.strokeWidth = major ? 2.5 : 1;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 14),
        center.dy + math.sin(angle) * (radius - 14),
      );
      final innerPoint = Offset(
        center.dx + math.cos(angle) * (radius - (major ? 34 : 25)),
        center.dy + math.sin(angle) * (radius - (major ? 34 : 25)),
      );
      canvas.drawLine(innerPoint, outer, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.aligned != aligned;
}

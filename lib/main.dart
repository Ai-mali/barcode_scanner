import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daikin Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ScannerScreen(),
    );
  }
}

class ScannedItem {
  final int itemNumber;
  final String model;
  final String serial;
  final DateTime scannedAt;
  ScannedItem({
    required this.itemNumber,
    required this.model,
    required this.serial,
    required this.scannedAt,
  });
}

enum ScanStage { model, modelReview, serial, serialReview }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    cameraResolution: const Size(800, 400),
    torchEnabled: false,
  );

  final List<ScannedItem> _items = [];
  int _nextItemNumber = 1;
  ScanStage _stage = ScanStage.model;
  String? _currentModel;
  String? _pending;
  String? _lastSeen;
  bool _torchOn = false;
  double _zoomScale = 0.0;

  static final _serialRegex = RegExp(r'K\d+');
  static final _trackingRegex = RegExp(r'^\d{3,}-\d{2,}$');
  static final _modelRegex = RegExp(r'^[A-Z]{2,}[A-Z0-9]+$');
  static final _qrSplitter = RegExp(r'[\s,;:|/=&\n\r\t]+');
  static final _linearSplitter = RegExp(r'\s+');

  static const Color kTeal = Color(0xFFB2EBF2);
  static const Color kPurple = Color(0xFF7E57C2);
  static const Color kGreen = Color(0xFF8BC34A);
  static const Color kRed = Color(0xFFE53935);
  static const Color kPanel = Color(0xFF2E2E2E);
  static const Color kCircle = Color(0xFF607D8B);

  bool _isModelStage() => _stage == ScanStage.model;
  bool _isSerialStage() => _stage == ScanStage.serial;
  bool _isReviewStage() =>
      _stage == ScanStage.modelReview || _stage == ScanStage.serialReview;
  bool _isScanning() => _isModelStage() || _isSerialStage();
  bool _isModelSide() =>
      _stage == ScanStage.model || _stage == ScanStage.modelReview;

    int get _currentItemNumber => _nextItemNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _controller.start();
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.start().catchError((_) {});
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop().catchError((_) {});
    }
  }

  Iterable<String> _tokens(String raw, BarcodeFormat fmt) {
    final splitter =
        fmt == BarcodeFormat.qrCode ? _qrSplitter : _linearSplitter;
    return raw.split(splitter).where((t) => t.isNotEmpty);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isReviewStage()) return;

    final ordered = capture.barcodes.toList()
      ..sort((a, b) {
        final aRank = a.format == BarcodeFormat.qrCode ? 0 : 1;
        final bRank = b.format == BarcodeFormat.qrCode ? 0 : 1;
        return aRank.compareTo(bRank);
      });

    String? sawThisFrame;
    for (final barcode in ordered) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      sawThisFrame = raw;

      for (final token in _tokens(raw, barcode.format)) {
        if (_isModelStage()) {
          if (_trackingRegex.hasMatch(token)) continue;
          if (_serialRegex.firstMatch(token) != null) continue;
          if (!_modelRegex.hasMatch(token)) continue;
          _capturePending(token, ScanStage.modelReview);
          return;
        }
        if (_isSerialStage()) {
          final m = _serialRegex.firstMatch(token);
          if (m == null) continue;
          _capturePending(m.group(0)!, ScanStage.serialReview);
          return;
        }
      }
    }
    if (sawThisFrame != null) {
      setState(() => _lastSeen = sawThisFrame);
    }
  }

  void _capturePending(String value, ScanStage nextStage) {
    setState(() {
      _pending = value;
      _stage = nextStage;
    });
  }

  Future<void> _confirm() async {
    if (_stage == ScanStage.modelReview) {
      setState(() {
        _currentModel = _pending;
        _pending = null;
        _lastSeen = null;
        _stage = ScanStage.serial;
      });
      await _resetZoom();
        } else if (_stage == ScanStage.serialReview) {
      final newItem = ScannedItem(
        itemNumber: _nextItemNumber,
        model: _currentModel!,
        serial: _pending!,
        scannedAt: DateTime.now(),
      );
      setState(() {
        _items.add(newItem);
        _nextItemNumber += 1;
        _currentModel = null;
        _pending = null;
        _lastSeen = null;
        _stage = ScanStage.model;
      });
      await _resetZoom();
    }
  }

  Future<void> _rescan() async {
    final next = _stage == ScanStage.modelReview
        ? ScanStage.model
        : ScanStage.serial;
    setState(() {
      _pending = null;
      _stage = next;
    });
    await _resetZoom();
  }

  Future<void> _backToModel() async {
    setState(() {
      _pending = null;
      _currentModel = null;
      _stage = ScanStage.model;
    });
    await _resetZoom();
  }

  Future<void> _setZoom(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    setState(() => _zoomScale = clamped);
    try {
      await _controller.setZoomScale(clamped);
    } catch (_) {}
  }

  Future<void> _resetZoom() async {
    await _setZoom(0.0);
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  Future<void> _keyInValue() async {
    final isModel = _isModelSide();
    final label = isModel ? 'Model' : 'Serial';
    final hint = isModel ? 'e.g. RKF25AV1' : 'e.g. K003086';
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Key in $label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    setState(() {
      _pending = value;
      _stage = isModel ? ScanStage.modelReview : ScanStage.serialReview;
    });
  }

    void _showScannedList() {
    final today = _fmtDateOnly(DateTime.now());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'SCANNED ITEM (${_items.length})',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '($today)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('No items scanned yet'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (c, i) {
                    final it = _items[i];
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${it.itemNumber}:',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                                children: [
                                  TextSpan(
                                    text: it.model,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '  /  ',
                                    style:
                                        TextStyle(color: Colors.black45),
                                  ),
                                  TextSpan(text: it.serial),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () {
                              setState(() => _items.removeAt(i));
                              Navigator.pop(ctx);
                              _showScannedList();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  
  }
     String _fmtDateOnly(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)}';
  }

  String _fmtDate(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }

  Future<void> _onFinish() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items scanned yet')),
      );
      return;
    }
    final csv = StringBuffer('No,Model,Serial,DateTime\n');
    for (final it in _items) {
      csv.writeln(
          '${it.itemNumber},${it.model},${it.serial},${_fmtDate(it.scannedAt)}');
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Finish — ${_items.length} item(s)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              csv.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv.toString()));
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmClearAll();
            },
            child: const Text('Clear all',
                style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all items?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _items.clear());
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Widget _purpleBtn(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 2,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _zoomSlider() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 10, top: 12, bottom: 12),
        child: SizedBox(
          width: 44,
          height: 260,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.25), blurRadius: 4)
                  ],
                ),
                child: Text(
                  '${(_zoomScale * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbColor: Colors.amberAccent,
                      overlayColor: Colors.amber.withOpacity(0.18),
                      activeTrackColor: Colors.amberAccent,
                      inactiveTrackColor: Colors.white38,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _zoomScale,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) => _setZoom(v),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewOverlay() {
    final isModelReview = _stage == ScanStage.modelReview;
    final question =
        isModelReview ? 'Is this the Model?' : 'Is this the Serial?';
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            question,
            style: const TextStyle(fontSize: 22, color: Colors.black87),
          ),
          const SizedBox(height: 14),
          Text(
            _pending ?? '',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              if (!isModelReview) ...[
                Expanded(child: _purpleBtn('Back to Model', _backToModel)),
                const SizedBox(width: 8),
              ],
              Expanded(child: _purpleBtn('Rescan', _rescan)),
              const SizedBox(width: 8),
              Expanded(child: _purpleBtn('Confirm', _confirm)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _cameraControlsStrip() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _controlButton(
            icon: _torchOn ? Icons.flash_on : Icons.flash_off,
            label: _torchOn ? 'TORCH ON' : 'TORCH OFF',
            onTap: _toggleTorch,
          ),
          const SizedBox(width: 48),
          _controlButton(
            icon: Icons.cameraswitch_outlined,
            label: 'FLIP CAM',
            onTap: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    int? badge,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 76,
                height: 76,
                decoration:
                    BoxDecoration(color: background, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
            ),
            if (badge != null && badge > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _bottomPanel() {
    final hasCompleted = _items.isNotEmpty;
    final int displayItemNum;
    final String? displayModel;
    final String? displaySerial;

    if (hasCompleted) {
      final last = _items.last;
      displayItemNum = last.itemNumber;
      displayModel = last.model;
      displaySerial = last.serial;
    } else {
      displayItemNum = _currentItemNumber;
      displayModel = _currentModel ??
          (_stage == ScanStage.modelReview ? _pending : null);
      displaySerial = _stage == ScanStage.serialReview ? _pending : null;
    }

    final keyInLabel = _isModelSide() ? 'KEY IN MODEL' : 'KEY IN SERIAL';

    return Container(
      color: kPanel,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ITEM $displayItemNum',
            style: const TextStyle(
              color: kGreen,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Model: ${displayModel ?? "..."}',
                  style: const TextStyle(color: kGreen, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('/', style: TextStyle(color: Colors.white54)),
              ),
              Expanded(
                child: Text(
                  'Serial: ${displaySerial ?? "..."}',
                  style: const TextStyle(color: kGreen, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _bottomAction(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'SCANNED',
                  badge: _items.length,
                  background: kCircle,
                  onTap: _showScannedList,
                ),
              ),
              Expanded(
                child: _bottomAction(
                  icon: Icons.touch_app_outlined,
                  label: keyInLabel,
                  background: kCircle,
                  onTap: _keyInValue,
                ),
              ),
              Expanded(
                child: _bottomAction(
                  icon: Icons.check,
                  label: 'FINISH',
                  background: kRed,
                  onTap: _onFinish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kTeal,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'SCANNING ITEM $_currentItemNumber',
          style: const TextStyle(
            color: kGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                                if (_isScanning())
                  const IgnorePointer(
                    child: _ScanFrameOverlay(
                      widthFactor: 0.85,
                      height: 180,
                      dimOpacity: 0.55,
                    ),
                  ),
                if (_isScanning()) _zoomSlider(),
                if (_isScanning() && _lastSeen != null)
                  Positioned(
                    left: 8,
                    right: 60,
                    bottom: 8,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Last seen: $_lastSeen',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                if (_isReviewStage())
                  Positioned.fill(
                    child: _reviewOverlay(),
                  ),
              ],
            ),
          ),
          _cameraControlsStrip(),
          _bottomPanel(),
        ],
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  final double widthFactor;
  final double height;
  final double dimOpacity;
  const _ScanFrameOverlay({
    this.widthFactor = 0.85,
    this.height = 180,
    this.dimOpacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final frameWidth = w * widthFactor;
        final frameHeight = height;
        final left = (w - frameWidth) / 2;
        final top = (h - frameHeight) / 2;
        final rect = Rect.fromLTWH(left, top, frameWidth, frameHeight);
        return CustomPaint(
          size: Size(w, h),
          painter: _ScanFrameOverlayPainter(
            frame: rect,
            dimOpacity: dimOpacity,
          ),
        );
      },
    );
  }
}

class _ScanFrameOverlayPainter extends CustomPainter {
  final Rect frame;
  final double dimOpacity;
  _ScanFrameOverlayPainter({required this.frame, required this.dimOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(frame, const Radius.circular(16));

    // 1) Dim everything outside the scan frame
    final dimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withOpacity(dimOpacity),
    );

    // 2) Dashed white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final borderPath = Path()..addRRect(rrect);
    const dashLength = 10.0;
    const gapLength = 6.0;
    for (final metric in borderPath.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength) > metric.length
            ? metric.length
            : distance + dashLength;
        canvas.drawPath(metric.extractPath(distance, end), borderPaint);
        distance = end + gapLength;
      }
    }

    // 3) Small center dot
    canvas.drawCircle(
      frame.center,
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFrameOverlayPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.dimOpacity != dimOpacity;
}
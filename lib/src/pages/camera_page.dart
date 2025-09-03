import 'dart:async';
import 'dart:io';

//import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import 'package:librecamera/main.dart';
import 'package:librecamera/src/widgets/format.dart';
import 'package:librecamera/src/widgets/resolution.dart';
import 'package:librecamera/src/widgets/timer.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
// import 'package:permission_handler/permission_handler.dart';
//import 'package:qr_code_scanner/qr_code_scanner.dart' as qr;

import 'package:librecamera/src/pages/settings_page.dart';
import 'package:librecamera/src/utils/preferences.dart';
import 'package:librecamera/src/widgets/exposure.dart';
import 'package:librecamera/src/widgets/flash.dart';
import 'package:librecamera/src/widgets/focus.dart';
import 'package:librecamera/src/widgets/capture_control.dart';
import 'package:librecamera/src/lut/lut_preview_manager.dart';
import 'package:librecamera/src/lut/lut_mix_control.dart';
import 'package:librecamera/src/widgets/lut_selector.dart';
import 'package:librecamera/src/provider/lut_provider.dart';
import 'package:provider/provider.dart';

/// Camera example home widget.
class CameraPage extends StatefulWidget {
  /// Default Constructor
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() {
    return _CameraPageState();
  }
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  //Controllers
  File? capturedFile;
  CameraController? controller;

  //Zoom
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  int _pointers = 0;

  //Exposure
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;

  //Current camera
  bool isRearCameraSelected = Preferences.getStartWithRearCamera();
  bool takingPicture = false;

  //Circle position
  double _circlePosX = 0, _circlePosY = 0;
  bool _circleEnabled = false;
  final Tween<double> _scaleTween = Tween<double>(begin: 1, end: 0.75);

  //Photo capture timer
  final Stopwatch _timerStopwatch = Stopwatch();

  //Orientation
  DateTime _timeOfLastChange = DateTime.now();

  //Volume buttons
  StreamSubscription<HardwareButton>? volumeSubscription;
  bool canPressVolume = true;

  //LUT controls
  bool _showLutMixControl = false;

  //QR Code
  /*final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  qr.Barcode? result;
  qr.QRViewController? qrController;*/

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    /*final methodChannel = AndroidMethodChannel();
    methodChannel.disableIntentCamera(disable: true);*/

    if (!Preferences.getIsCaptureOrientationLocked()) {
      _subscribeOrientationChangeStream();
    }

    // 初始化LUT预览管理器
    _initializeLutPreviewManager();

    // 初始化LUT Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LutProvider>(context, listen: false).initializeLuts();
    });

    onNewCameraSelected(cameras[Preferences.getStartWithRearCamera() ? 0 : 1]);
  }

  Future<void> _initializeLutPreviewManager() async {
    try {
      final manager = LutPreviewManager.instance;
      await manager.initializeFromPreferences();
      final defaultLutPath = await manager.getDefaultLutPath();
      await manager.setCurrentLut(defaultLutPath);
    } catch (e) {
      print('初始化LUT预览管理器失败: $e');
    }
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  /*@override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      qrController!.pauseCamera();
    }
  }*/

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // 停止图像流并处理相机控制器
    LutPreviewManager.instance.stopImageStream();
    controller?.dispose();
    controller = null;

    //qrController?.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // 停止图像流
      LutPreviewManager.instance.stopImageStream();
      cameraController.dispose();
      controller = null; // Set to null after disposing
      //qrController?.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(cameraController.description);
      //qrController?.resumeCamera();
    }
  }

  void _subscribeVolumeButtons() {
    volumeSubscription =
        FlutterAndroidVolumeKeydown.stream.listen((event) async {
      if (canPressVolume) {
        onTakePictureButtonPressed();
        canPressVolume = false;
        await Future.delayed(const Duration(seconds: 1));
        canPressVolume = true;
      }
    });
  }

  void _stopVolumeButtons() => volumeSubscription?.cancel();

  void checkVolumeButtons() => Preferences.getCaptureAtVolumePress()
      ? _subscribeVolumeButtons()
      : _stopVolumeButtons();

  /*void _onQRViewCreated(qr.QRViewController qrController) {
    this.qrController = qrController;
    qrController.pauseCamera();
    qrController.resumeCamera();

    qrController.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
  }*/

  void _subscribeOrientationChangeStream() {
    NativeDeviceOrientationCommunicator nativeDeviceOrientationCommunicator =
        NativeDeviceOrientationCommunicator();
    Stream<NativeDeviceOrientation> onOrientationChangedStream =
        nativeDeviceOrientationCommunicator.onOrientationChanged(
            useSensor: true);

    onOrientationChangedStream.listen((event) {
      Future<NativeDeviceOrientation> orientation =
          nativeDeviceOrientationCommunicator.orientation(useSensor: true);

      _timeOfLastChange = DateTime.now();
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (DateTime.now().difference(_timeOfLastChange).inMilliseconds > 500) {
          if (await orientation == NativeDeviceOrientation.portraitUp) {
            await SystemChrome.setPreferredOrientations(
                [DeviceOrientation.portraitUp]);
          } else if (await orientation ==
              NativeDeviceOrientation.landscapeLeft) {
            await SystemChrome.setPreferredOrientations(
                [DeviceOrientation.landscapeLeft]);
          } else if (await orientation ==
              NativeDeviceOrientation.landscapeRight) {
            await SystemChrome.setPreferredOrientations(
                [DeviceOrientation.landscapeRight]);
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraPreview(context),
    );
  }

  Widget _cameraPreview(context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          /*qr.QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),*/
          _previewWidget(),
          _shutterBorder(),
          //?TODO when in QR-Code mode: enable, _previewWidget disable
          /*Center(
            child: (result != null)
                ? Container(
                    color: Colors.black54,
                    height: 200,
                    padding: const EdgeInsets.all(8.0),
                    child: SelectableText('Link: ${result!.code}',
                        style: const TextStyle(color: Colors.white)),
                  )
                : const Text('Scan a code',
                    style: TextStyle(color: Colors.white)),
          ),*/
          _timerWidget(),
          _topControlsWidget(),
          _zoomWidget(context),
          _bottomControlsWidget(),
          _circleWidget(),
          // 紧凑的LUT选择器 - 显示在底部
          Positioned(
            bottom: 180,
            left: 16,
            child: Consumer<LutProvider>(
              builder: (context, lutProvider, child) {
                if (!lutProvider.hasLuts || _timerStopwatch.elapsedTicks > 1) {
                  return const SizedBox.shrink();
                }
                return const CompactLutSelector();
              },
            ),
          ),
          // LUT混合控制组件
          if (_showLutMixControl)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: LutMixControl(
                isVisible: _showLutMixControl,
                onDismiss: () {
                  setState(() {
                    _showLutMixControl = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _shutterBorder() {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
              color: takingPicture
                  ? const Color(0xFFFFFFFF)
                  : const Color.fromARGB(0, 255, 255, 255),
              width: 4.0,
              style: BorderStyle.solid), //Border.all
        ),
      ),
    );
  }

  Widget _timerWidget() {
    var minuteAmount =
        (Preferences.getTimerDuration() - _timerStopwatch.elapsed.inSeconds) /
            60;
    var minute = minuteAmount.floor();

    return Duration(seconds: Preferences.getTimerDuration()).inSeconds > 0 &&
            _timerStopwatch.elapsedTicks > 1
        ? Center(
            child: IgnorePointer(
              child: Text(
                Preferences.getTimerDuration() -
                            _timerStopwatch.elapsed.inSeconds <
                        60
                    ? '${Preferences.getTimerDuration() - _timerStopwatch.elapsed.inSeconds}s'
                    : '${minute}m ${(Preferences.getTimerDuration() - _timerStopwatch.elapsed.inSeconds) % 60}s',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 64.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        : Container();
  }

  Widget _previewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController != null && cameraController.value.isInitialized) {
      return Center(
        child: Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers--,
          child: LutPreviewManager.instance.createPreviewWidget(
            cameraController,
            isRearCamera: isRearCameraSelected,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onTapDown: (TapDownDetails details) =>
                      _onViewFinderTap(details, constraints),
                );
              },
            ),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _topControlsWidget() {
    final leftHandedMode = Preferences.getLeftHandedMode() &&
        MediaQuery.of(context).orientation == Orientation.landscape;

    final left = leftHandedMode ? null : 0.0;
    final right = leftHandedMode ? 0.0 : null;

    return Positioned(
      top: 0,
      left: left,
      right: MediaQuery.of(context).orientation == Orientation.portrait
          ? 0
          : right,
      bottom:
          MediaQuery.of(context).orientation == Orientation.portrait ? null : 0,
      child: RotatedBox(
        quarterTurns:
            MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 3,
        child: Container(
          color: Colors.black12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TimerButton(enabled: _timerStopwatch.elapsedTicks <= 1),
              FlashModeWidget(
                controller: controller,
                isRearCameraSelected: isRearCameraSelected,
                isVideoCameraSelected: false,
              ),
              ResolutionButton(
                isDense: true,
                onNewCameraSelected: _initializeCameraController,
                isRearCameraSelected: isRearCameraSelected,
                enabled: _timerStopwatch.elapsedTicks <= 1,
              ),
              _lutSelectorWidget(
                enabled: _timerStopwatch.elapsedTicks <= 1,
              ),
              _settingsWidget(
                enabled: _timerStopwatch.elapsedTicks <= 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoomWidget(context) {
    final leftHandedMode = Preferences.getLeftHandedMode() &&
        MediaQuery.of(context).orientation == Orientation.landscape;

    final left = leftHandedMode ? null : 0.0;
    final right = leftHandedMode ? 0.0 : null;

    return Positioned(
      top:
          MediaQuery.of(context).orientation == Orientation.portrait ? 0 : null,
      right: MediaQuery.of(context).orientation == Orientation.portrait
          ? 0
          : right,
      left: MediaQuery.of(context).orientation == Orientation.portrait
          ? null
          : left,
      bottom:
          MediaQuery.of(context).orientation == Orientation.portrait ? null : 0,
      child: RotatedBox(
        quarterTurns:
            MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //_settingsWidget(),
              //_cameraSwitchWidget(),
              //const SizedBox(height: 10.0),
              //_thumbnailPreviewWidget(),
              if (!leftHandedMode) const SizedBox(height: 64.0),
              if (Preferences.getEnableZoomSlider())
                RotatedBox(
                    quarterTurns: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? 0
                        : 2,
                    child: _zoomSlider(update: false)),
              if (leftHandedMode) const SizedBox(height: 64.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsWidget({required bool enabled}) {
    return AnimatedRotation(
      duration: const Duration(milliseconds: 400),
      turns:
          MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 0.25,
      child: SettingsButton(
        onPressed: enabled
            ? () {
                _stopVolumeButtons();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      controller: controller,
                      onNewCameraSelected: _initializeCameraController,
                    ),
                  ),
                );
              }
            : null,
        controller: controller,
      ),
    );
  }

  Widget _lutSelectorWidget({required bool enabled}) {
    return AnimatedRotation(
      duration: const Duration(milliseconds: 400),
      turns: MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 0.25,
      child: enabled
          ? const LutSelector()
          : Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: const Icon(
                Icons.photo_filter,
                color: Colors.white24,
                size: 36,
              ),
            ),
    );
  }

  Widget _thumbnailPreviewWidget() {
    return _timerStopwatch.elapsedTicks > 1
        ? const SizedBox(height: 60, width: 60)
        : AnimatedRotation(
            duration: const Duration(milliseconds: 400),
            turns: MediaQuery.of(context).orientation == Orientation.portrait
                ? 0
                : 0.25,
            child: Tooltip(
              message: AppLocalizations.of(context)!.openCapturedPictureOrVideo,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: GestureDetector(
                    onTap: () async {
                      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
                      AndroidDeviceInfo androidInfo =
                          await deviceInfo.androidInfo;
                      int sdkInt = androidInfo.version.sdkInt;

                      final String mimeType;
                      switch (getCompressFormat()) {
                        case CompressFormat.jpeg:
                          mimeType = 'image/jpeg';
                          break;
                        case CompressFormat.png:
                          mimeType = 'image/png';
                          break;
                        case CompressFormat.webp:
                          mimeType = 'image/webp';
                          break;
                        default:
                          mimeType = 'image/jpeg';
                      }

                      final methodChannel = AndroidMethodChannel();
                      await methodChannel.openItem(
                        file: capturedFile!,
                        mimeType: mimeType,
                        openInGallery: sdkInt > 27 ? false : true,
                      );
                    },
                    child: _thumbnailWidget(),
                  ),
                ),
              ),
            ),
          );
  }

  Widget _bottomControlsWidget() {
    final leftHandedMode = Preferences.getLeftHandedMode() &&
        MediaQuery.of(context).orientation == Orientation.landscape;

    final cameraControls = <Widget>[
      if (Preferences.getEnableModeRow()) _cameraModesWidget(),
      if (Preferences.getEnableModeRow()) const Divider(color: Colors.blue),
      if (Preferences.getEnableExposureSlider())
        ExposureSlider(
          setExposureOffset: _setExposureOffset,
          currentExposureOffset: _currentExposureOffset,
          minAvailableExposureOffset: _minAvailableExposureOffset,
          maxAvailableExposureOffset: _maxAvailableExposureOffset,
        ),
      if (Preferences.getEnableExposureSlider())
        const Divider(color: Colors.blue),
      Container(
        padding: const EdgeInsets.fromLTRB(0, 8.0, 0, 8.0),
        child: CaptureControlWidget(
          controller: controller,
          onTakePictureButtonPressed: onTakePictureButtonPressed,
          onNewCameraSelected: onNewCameraSelected,
          /*flashWidget: FlashModeControlRowWidget(
                controller: controller,
                isRearCameraSelected: isRearCameraSelected,
              ),*/
          leadingWidget: _thumbnailPreviewWidget(),
          isRearCameraSelected: getIsRearCameraSelected(),
          setIsRearCameraSelected: setIsRearCameraSelected,
        ),
      ),
    ];

    final bottomControls = <Widget>[
      Container(
        color: Colors.black12,
        child: Column(
          children: leftHandedMode
              ? cameraControls.reversed.toList()
              : cameraControls,
        ),
      ),
    ];

    return RotatedBox(
      quarterTurns:
          MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 3,
      child: Column(
        mainAxisAlignment:
            leftHandedMode ? MainAxisAlignment.start : MainAxisAlignment.end,
        children:
            leftHandedMode ? bottomControls.reversed.toList() : bottomControls,
      ),
    );
  }

  Widget _cameraModesWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        ExposureModeControlWidget(controller: controller),
        FocusModeControlWidget(controller: controller),
      ],
    );
  }

  //Selecting camera
  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      // 切换摄像头前先停止图像流
      await LutPreviewManager.instance.stopImageStream();
      
      try {
        await controller!.setDescription(cameraDescription);
        
        // 通知LutProvider摄像头控制器已更改
        if (mounted) {
          Provider.of<LutProvider>(context, listen: false).onCameraControllerChanged();
        }
        
        // 延迟重新启动图像流，确保摄像头切换完成
        Future.delayed(const Duration(milliseconds: 300), () {
          LutPreviewManager.instance.resumeImageStream();
        });
      } catch (e) {
        print('切换摄像头时出错: $e');
        // 即使出错也要尝试恢复图像流
        LutPreviewManager.instance.resumeImageStream();
      }
    } else {
      return _initializeCameraController(cameraDescription);
    }
  }

  Future<void> _initializeCameraController(
      CameraDescription cameraDescription) async {
    // 停止当前的图像流以避免冲突
    await LutPreviewManager.instance.stopImageStream();
    
    // 如果存在旧的控制器，先清理它
    if (controller != null) {
      try {
        await controller!.dispose();
      } catch (e) {
        print('清理旧控制器时出错: $e');
      }
      controller = null;
    }
    
    final flashMode = getFlashMode();
    final resolution = getResolution();

    final CameraController cameraController = CameraController(
      cameraDescription,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // 改为YUV420以支持LUT预览
    );

    controller = cameraController;

    try {
      await cameraController.initialize();
      await Future.wait(<Future<Object?>>[
        cameraController.setFlashMode(flashMode),
        cameraController
            .getMinExposureOffset()
            .then((double value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((double value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((double value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((double value) => _minAvailableZoom = value),
      ]);
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          print('You have denied camera access.');
          break;
        case 'AudioAccessDenied':
          print('You have denied audio access.');
          break;
        default:
          print('$e: ${e.description}');
          break;
      }
      
      // 即使初始化失败也要尝试恢复图像流
      LutPreviewManager.instance.resumeImageStream();
      return; // 提前返回，避免重复调用resumeImageStream
    } catch (e) {
      print('初始化相机控制器时发生未知错误: $e');
      // 即使发生未知错误也要尝试恢复图像流
      LutPreviewManager.instance.resumeImageStream();
      return; // 提前返回，避免重复调用resumeImageStream
    }

    if (mounted) {
      await _refreshGalleryImages();

      setState(() {});
      
      // 通知LutProvider摄像头控制器已更改
      Provider.of<LutProvider>(context, listen: false).onCameraControllerChanged();
      
      // 延迟重新启动图像流，确保相机完全初始化
      Future.delayed(const Duration(milliseconds: 300), () {
        LutPreviewManager.instance.resumeImageStream();
      });
    }

    checkVolumeButtons();

    /*startCameraProcessing();

    cameraController.startImageStream((image) async {
      CodeResult result = await processCameraImage(image);
      if (result.isValidBool) {
        print('QR: ${result.textString}');
      }
      return null;
    });*/
  }

  bool getIsRearCameraSelected() {
    return isRearCameraSelected;
  }

  void setIsRearCameraSelected() {
    setState(() => isRearCameraSelected = !isRearCameraSelected);
  }

  //Camera button functions
  void onTakePictureButtonPressed() {
    takePicture().then((XFile? file) {
      if (mounted) {
        setState(() {});
      }
    }).catchError((error) {
      print('拍照过程中发生错误: $error');
      // 确保即使出错也恢复图像流
      LutPreviewManager.instance.resumeImageStream();
      if (mounted) {
        setState(() {});
      }
    });
  }

  //Camera controls
  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      print('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already going on, return
      return null;
    }

    // 停止图像流以避免冲突
    await LutPreviewManager.instance.stopImageStream();

    setState(() {
      Timer.periodic(
        const Duration(milliseconds: 500),
        (Timer t) => setState(() {}),
      );
      _timerStopwatch.start();
    });

    await Future.delayed(Duration(seconds: Preferences.getTimerDuration()));

    setState(() {
      _timerStopwatch.stop();
      _timerStopwatch.reset();
    });

    try {
      final XFile file = await cameraController.takePicture();
      takingPicture = true;

      if (!Preferences.getDisableShutterSound()) {
        var methodChannel = AndroidMethodChannel();
        methodChannel.shutterSound();
      }

      capturedFile = File(file.path);

      final directory = Preferences.getSavePath();

      //String fileFormat = capturedFile!.path.split('.').last;
      final CompressFormat format = getCompressFormat();
      final String fileFormat;
      switch (getCompressFormat()) {
        case CompressFormat.jpeg:
          fileFormat = 'jpg';
          break;
        case CompressFormat.png:
          fileFormat = 'png';
          break;
        case CompressFormat.webp:
          fileFormat = 'webp';
          break;
        default:
          fileFormat = 'jpg';
      }

      String path = '$directory/IMG_${timestamp()}.$fileFormat';

      if (!isRearCameraSelected && Preferences.getFlipFrontCameraPhoto()) {
        final imageBytes = await capturedFile!.readAsBytes();
        img.Image? originalImage = img.decodeImage(imageBytes);
        img.Image fixedImage = img.flipHorizontal(originalImage!);

        await capturedFile!.writeAsBytes(
          img.encodeJpg(fixedImage),
          flush: true,
        );
      }

      /*final resolutionString = Preferences.getResolution();
      ResolutionPreset resolution = ResolutionPreset.high;
      for (var res in ResolutionPreset.values) {
        if (res.name == resolutionString) resolution = res;
      }*/

      Uint8List? newFileBytes = await FlutterImageCompress.compressWithFile(
        capturedFile!.path,
        quality: Preferences.getCompressQuality(),
        keepExif: Preferences.getKeepEXIFMetadata(),
        format: format,
      );

      //var tempFile = capturedFile!.copySync('$directory/IMG_${timestamp()}.$fileFormat');
      try {
        final tempFile = capturedFile!.copySync(path);
        await tempFile.writeAsBytes(newFileBytes!);

        final methodChannel = AndroidMethodChannel();
        await methodChannel.updateItem(file: tempFile);
        capturedFile = File(path);
      } catch (e) {
        if (mounted) showSnackbar(text: e.toString());
      }

      /*Uint8List? newFileBytes = await FlutterImageCompress.compressWithFile(
          capturedFile!.path,
          quality: Preferences.getCompressQuality(),
          keepExif: Preferences.getKeepEXIFMetadata());
      File? newFile = await File(path).create();
      newFile.writeAsBytesSync(newFileBytes!);*/

      /*Directory? finalPath = await getExternalStorageDirectory();
      await FlutterImageCompress.compressAndGetFile(
          capturedFile!.path, finalPath!.path,
          quality: Preferences.getCompressQuality(),
          keepExif: Preferences.getKeepEXIFMetadata());*/

      //OLD without compression and removal of EXIF data: await capturedFile!.copy(path);

      print('Picture saved to $path');

      takingPicture = false;

      await _refreshGalleryImages();

      await File(file.path).delete();

      // 恢复图像流
      await LutPreviewManager.instance.resumeImageStream();

      return file;
    } on CameraException catch (e) {
      print('$e: ${e.description}');
      // 即使发生错误也要恢复图像流
      await LutPreviewManager.instance.resumeImageStream();
      return null;
    } catch (e) {
      print('拍照时发生未知错误: $e');
      // 即使发生错误也要恢复图像流
      await LutPreviewManager.instance.resumeImageStream();
      return null;
    }
  }

  //Zoom
  Widget _zoomSlider({required bool update}) {
    if (mounted && update) {
      setState(() {});
    }

    if (_currentScale > _maxAvailableZoom) {
      _currentScale = _maxAvailableZoom;
    }

    return RotatedBox(
      quarterTurns: 3,
      child: SliderTheme(
        data: SliderThemeData(
          showValueIndicator: ShowValueIndicator.onDrag,
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: Slider(
          value: _currentScale,
          min: _minAvailableZoom,
          max: _maxAvailableZoom,
          label: _currentScale.toStringAsFixed(2),
          onChanged: ((value) async {
            setState(() {
              _currentScale = value;
            });
            await controller!.setZoomLevel(value);
          }),
        ),
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  void _onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    _circlePosX = details.localPosition.dx;
    _circlePosY = details.localPosition.dy;

    _displayCircle();

    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  void _displayCircle() async {
    setState(() {
      _circleEnabled = true;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _circleEnabled = false;
    });
  }

  Widget _circleWidget() {
    return Positioned(
      top: _circlePosY - 20.0,
      left: _circlePosX - 20.0,
      child: _circleEnabled
          ? TweenAnimationBuilder(
              tween: _scaleTween,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.circle,
                  color: Colors.transparent,
                  size: 42.0,
                ),
              ),
            )
          : Container(),
    );
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    _zoomSlider(update: true);

    await controller!.setZoomLevel(_currentScale);
  }

  //Exposure
  Future<void> _setExposureOffset(double offset) async {
    if (controller == null) {
      return;
    }

    setState(() {
      _currentExposureOffset = offset;
    });
    try {
      offset = await controller!.setExposureOffset(offset);
    } on CameraException catch (e) {
      print('$e: ${e.description}');
      rethrow;
    }
  }

  //Thumbnail
  Widget _thumbnailWidget() {
    if (capturedFile == null) {
      return const Center(child: null);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7.0),
        image: DecorationImage(
          fit: BoxFit.cover,
          image: FileImage(
            File(capturedFile!.path),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshGalleryImages() async {
    List<File> allFileList = [];

    final directory = Directory(Preferences.getSavePath());

    List<FileSystemEntity> fileList = [];
    try {
      fileList = await directory.list().toList();
    } catch (e) {
      showSnackbar(text: e.toString());
      return;
    }

    List<String> fileNames = [];
    List<DateTime> dateTimes = [];

    String recentFileName = '';

    for (var file in fileList) {
      if (file.path.contains('.jpg') ||
          file.path.contains('.png') ||
          file.path.contains('.webp')) {
        allFileList.add(File(file.path));
        String name = file.path.split('/').last; //.split('.').first;
        final stat = FileStat.statSync(file.path);

        dateTimes.add(stat.modified);

        fileNames.add(name);
      }
    }

    if (fileNames.isNotEmpty) {
      for (var name in fileNames) {
        final now = DateTime.now();
        final mostRecentDateTimeToNow = dateTimes.reduce((a, b) =>
            a.difference(now).abs() < b.difference(now).abs() ? a : b);

        final file = File('${directory.path}/$name');

        final stat = FileStat.statSync(file.path);
        if (stat.changed.isAtSameMomentAs(mostRecentDateTimeToNow)) {
          recentFileName = name;
        }
      }

      capturedFile = File('${directory.path}/$recentFileName');
    }
  }

  //Misc
  String timestamp() {
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss');
    final String formatted = formatter.format(now);
    return formatted;
  }

  void showSnackbar({required String text}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 5),
    ));
  }
}

class AndroidMethodChannel {
  static const _channel = MethodChannel('media_store');

  Future<void> updateItem({required File file}) async {
    await _channel.invokeMethod('updateItem', {
      'path': file.path,
    });
  }

  Future<void> openItem({
    required File file,
    required String mimeType,
    required bool openInGallery,
  }) async {
    await _channel.invokeMethod('openItem', {
      'path': file.path,
      'mimeType': mimeType,
      'openInGallery': openInGallery,
    });
  }

  Future<void> disableIntentCamera({required bool disable}) async {
    await _channel.invokeMethod('disableIntentCamera', {
      'disable': disable,
    });
  }

  Future<void> shutterSound() async {
    await _channel.invokeMethod('shutterSound', {});
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:librecamera/src/widgets/resolution.dart';
import 'package:librecamera/src/widgets/timer.dart';
// import 'package:permission_handler/permission_handler.dart';
//import 'package:qr_code_scanner/qr_code_scanner.dart' as qr;

import 'package:librecamera/src/pages/settings_page.dart';
import 'package:librecamera/src/utils/preferences.dart';
import 'package:librecamera/src/widgets/exposure.dart';
import 'package:librecamera/src/widgets/flash.dart';
import 'package:librecamera/src/widgets/focus.dart';
import 'package:librecamera/src/widgets/capture_control.dart';
import 'package:librecamera/src/lut/lut_preview_manager.dart';
import 'package:librecamera/src/lut/cube_loader.dart';
import 'package:librecamera/src/lut/software_lut_processor.dart';
import 'package:librecamera/src/lut/gpu_lut_still_renderer.dart';
import 'package:librecamera/src/widgets/lut_controls.dart';

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

  //Volume buttons
  StreamSubscription<HardwareButton>? volumeSubscription;
  bool canPressVolume = true;

  //LUT controls 已迁移为顶部模式行中的二级菜单样式

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

    // 固定为横向模式
    _subscribeOrientationChangeStream();

    // 初始化LUT预览管理器
    _initializeLutPreviewManager();

    onNewCameraSelected(cameras[Preferences.getStartWithRearCamera() ? 0 : 1]);
  }

  Future<void> _initializeLutPreviewManager() async {
    try {
      final manager = LutPreviewManager.instance;
      await manager.initializeFromPreferences();
      final enabled = Preferences.getLutEnabled();
      if (!enabled) {
        manager.disableLut();
      } else {
        final savedPath = Preferences.getSelectedLutPath();
        if (savedPath.isNotEmpty) {
          await manager.setCurrentLut(savedPath);
        } else {
          final defaultLutPath = await manager.getDefaultLutPath();
          await manager.setCurrentLut(defaultLutPath);
        }
      }
    } catch (e) {
      debugPrint('初始化LUT预览管理器失败: $e');
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
    // 固定为横向模式，不再根据设备方向变化
    Future.delayed(const Duration(milliseconds: 100), () async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight
      ]);
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
          // 已移除：旧的 LUT 弹层组件
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
      // 获取屏幕详细信息
      final size = MediaQuery.sizeOf(context);                    // 逻辑分辨率：dp
      final dpr = MediaQuery.devicePixelRatioOf(context);         // 设备像素比
      final px = Size(size.width * dpr, size.height * dpr);       // 物理分辨率：px
      final ar = size.aspectRatio;                                // 宽高比
      final pads = MediaQuery.viewPaddingOf(context);            // 刘海/系统条安全区

      // 计算可用空间（扣除安全区域）
      final availableWidth = size.width;
      final availableHeight = size.height - pads.top - pads.bottom;
      
      debugPrint('[Camera] Logical size: ${size.width}x${size.height} dp');
      debugPrint('[Camera] Physical size: ${px.width}x${px.height} px (DPR: $dpr)');
      debugPrint('[Camera] Aspect ratio: $ar');
      debugPrint('[Camera] Safe area padding: top=${pads.top}, bottom=${pads.bottom}');
      debugPrint('[Camera] Available space: ${availableWidth}x$availableHeight dp');
      
      return Center(
        child: Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers--,
          child: AnimatedBuilder(
            // Rebuild preview when LUT state changes
            animation: LutPreviewManager.instance,
            builder: (context, _) {
              return LutPreviewManager.instance.createPreviewWidget(
                cameraController,
                isRearCamera: isRearCameraSelected,
                screenWidth: availableWidth,
                screenHeight: availableHeight,
                physicalWidth: px.width,
                physicalHeight: px.height,
                devicePixelRatio: dpr,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onTapDown: (TapDownDetails details) =>
                      _onViewFinderTap(details, BoxConstraints(
                        maxWidth: availableWidth,
                        maxHeight: availableHeight,
                      )),
                ),
              );
            },
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _topControlsWidget() {
    final leftHandedMode = Preferences.getLeftHandedMode();

    final left = leftHandedMode ? null : 0.0;
    final right = leftHandedMode ? 0.0 : null;

    return Positioned(
      top: 0,
      left: left,
      right: right,
      bottom: 0,
      child: RotatedBox(
        quarterTurns: 3,
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
              // 已移除：LUT 选择按钮（后续重构）
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
    final leftHandedMode = Preferences.getLeftHandedMode();

    final left = leftHandedMode ? null : 0.0;
    final right = leftHandedMode ? 0.0 : null;

    return Positioned(
      top: null,
      right: right,
      left: left,
      bottom: 0,
      child: RotatedBox(
        quarterTurns: 3,
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
                    quarterTurns: 2,
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
      turns: 0.25,
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

  // 已移除：_lutSelectorWidget（后续重构）

  Widget _thumbnailPreviewWidget() {
    return _timerStopwatch.elapsedTicks > 1
        ? const SizedBox(height: 60, width: 60)
        : AnimatedRotation(
            duration: const Duration(milliseconds: 400),
            turns: 0.25,
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

                      const String mimeType = 'image/jpeg';

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
    final leftHandedMode = Preferences.getLeftHandedMode();

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
      // 已移除：旧的 LUT 预设/强度按钮与分割线
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
      quarterTurns: 3,
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
        const LutControlWidget(),
      ],
    );
  }

  //Selecting camera
  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    // 始终通过重新初始化控制器来切换摄像头（相机插件不提供 setDescription）
    await _initializeCameraController(cameraDescription);
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
        debugPrint('清理旧控制器时出错: $e');
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
          debugPrint('You have denied camera access.');
          break;
        case 'AudioAccessDenied':
          debugPrint('You have denied audio access.');
          break;
        default:
          debugPrint('$e: ${e.description}');
          break;
      }
      
      // 即使初始化失败也要尝试恢复图像流
      LutPreviewManager.instance.resumeImageStream();
      return; // 提前返回，避免重复调用resumeImageStream
    } catch (e) {
      debugPrint('初始化相机控制器时发生未知错误: $e');
      // 即使发生未知错误也要尝试恢复图像流
      LutPreviewManager.instance.resumeImageStream();
      return; // 提前返回，避免重复调用resumeImageStream
    }

    if (mounted) {
      await _refreshGalleryImages();

      setState(() {});
      
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
        debugPrint('QR: ${result.textString}');
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
      debugPrint('拍照过程中发生错误: $error');
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
      debugPrint('Error: select a camera first.');
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
      const CompressFormat format = CompressFormat.jpeg;
      const String fileFormat = 'jpg';

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

      Uint8List? newFileBytes;
      try {
        final manager = LutPreviewManager.instance;
        if (manager.isEnabled && manager.mixStrength > 0.0 && manager.currentLutPath != null) {
          // 读取当前文件并应用 LUT（优先 GPU 全分辨率渲染，失败则回退到软件）
          final srcBytes = await capturedFile!.readAsBytes();
          try {
            newFileBytes = await GpuLutStillRenderer.processJpegWithLut(
              jpegBytes: srcBytes,
              lutPath: manager.currentLutPath!,
              mixStrength: manager.mixStrength,
              jpegQuality: Preferences.getCompressQuality(),
            );
            if (Preferences.getKeepEXIFMetadata()) {
              newFileBytes = _injectJpegExif(newFileBytes!, srcBytes);
            }
          } catch (_) {
            newFileBytes = await _applyLutToImageBytes(
              srcBytes: srcBytes,
              lutPath: manager.currentLutPath!,
              mixStrength: manager.mixStrength,
              format: format,
              quality: Preferences.getCompressQuality(),
            );
          }
        } else {
          // 未启用 LUT，按原路径压缩保存
          newFileBytes = await FlutterImageCompress.compressWithFile(
            capturedFile!.path,
            quality: Preferences.getCompressQuality(),
            keepExif: Preferences.getKeepEXIFMetadata(),
            format: format,
          );
        }
      } catch (e) {
        // 回退到原有压缩路径
        newFileBytes = await FlutterImageCompress.compressWithFile(
          capturedFile!.path,
          quality: Preferences.getCompressQuality(),
          keepExif: Preferences.getKeepEXIFMetadata(),
          format: format,
        );
      }

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

      debugPrint('Picture saved to $path');

      takingPicture = false;

      await _refreshGalleryImages();

      await File(file.path).delete();

      // 恢复图像流
      await LutPreviewManager.instance.resumeImageStream();

      return file;
    } on CameraException catch (e) {
      debugPrint('$e: ${e.description}');
      // 即使发生错误也要恢复图像流
      await LutPreviewManager.instance.resumeImageStream();
      return null;
    } catch (e) {
      debugPrint('拍照时发生未知错误: $e');
      // 即使发生错误也要恢复图像流
      await LutPreviewManager.instance.resumeImageStream();
      return null;
    }
  }

  /// 将 LUT 应用于整张图片字节，并按目标格式编码
  Future<Uint8List> _applyLutToImageBytes({
    required Uint8List srcBytes,
    required String lutPath,
    required double mixStrength,
    required CompressFormat format,
    required int quality,
  }) async {
    // 解码图片
    final img.Image? decoded = img.decodeImage(srcBytes);
    if (decoded == null) return srcBytes;

    // 修正方向：将 EXIF Orientation 烘焙到像素，避免竖图被逆时针旋转90°
    final img.Image oriented = img.bakeOrientation(decoded);

    final int w = oriented.width;
    final int h = oriented.height;
    // 获取 RGBA 像素
    final Uint8List rgba = Uint8List.fromList(
      oriented.getBytes(order: img.ChannelOrder.rgba),
    );

    // 载入 LUT
    ByteData lutData;
    if (lutPath.startsWith('assets/')) {
      lutData = await rootBundle.load(lutPath);
    } else {
      final bytes = await File(lutPath).readAsBytes();
      lutData = ByteData.sublistView(bytes);
    }
    final lut = await loadCubeLut(lutData);
    final processor = SoftwareLutProcessor(lut);

    // 应用 LUT
    final Uint8List mixed = processor.processImageData(rgba, w, h, mixStrength);
    // 重建图像
    final img.Image processed = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: mixed.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    // 按目标格式编码
    Uint8List out;
    switch (format) {
      case CompressFormat.jpeg:
        out = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
        break;
      case CompressFormat.png:
        out = Uint8List.fromList(img.encodePng(processed));
        break;
      case CompressFormat.webp:
        // Fallback: encode as PNG when WebP encoder is unavailable
        out = Uint8List.fromList(img.encodePng(processed));
        break;
      default:
        out = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
        break;
    }
    // 可选：迁移 EXIF 到 JPEG
    if (format == CompressFormat.jpeg && Preferences.getKeepEXIFMetadata()) {
      try {
        out = _injectJpegExif(out, srcBytes);
      } catch (_) {}
    }
    return out;
  }

  /// 从原始 JPEG 中提取 EXIF (APP1) 段并注入到新 JPEG（若存在）
  Uint8List _injectJpegExif(Uint8List newJpeg, Uint8List originalBytes) {
    // 检查 SOI
    if (newJpeg.length < 4 || originalBytes.length < 4) return newJpeg;
    if (!(newJpeg[0] == 0xFF && newJpeg[1] == 0xD8)) return newJpeg;
    if (!(originalBytes[0] == 0xFF && originalBytes[1] == 0xD8)) return newJpeg;

    // 在原图中寻找 APP1 Exif 段
    int i = 2;
    while (i + 4 < originalBytes.length) {
      if (originalBytes[i] != 0xFF) { i++; continue; }
      // 跳过填充 FF
      while (i < originalBytes.length && originalBytes[i] == 0xFF) { i++; }
      if (i >= originalBytes.length) break;
      final marker = originalBytes[i++];
      if (marker == 0xD9 || marker == 0xDA) {
        break; // EOI or SOS
      }
      if (i + 1 >= originalBytes.length) break;
      final len = (originalBytes[i] << 8) | originalBytes[i + 1];
      final segStart = i - 2; // includes 0xFF marker already consumed? adjust back 2 bytes
      final dataStart = i + 2;
      final segEnd = dataStart + len;
      if (segEnd > originalBytes.length) break;

      // APP1 Exif
      if (marker == 0xE1 && len >= 6) {
        // Check Exif header
        if (originalBytes[dataStart] == 0x45 && // 'E'
            originalBytes[dataStart + 1] == 0x78 && // 'x'
            originalBytes[dataStart + 2] == 0x69 && // 'i'
            originalBytes[dataStart + 3] == 0x66 && // 'f'
            originalBytes[dataStart + 4] == 0x00 &&
            originalBytes[dataStart + 5] == 0x00) {
          final exifSeg = originalBytes.sublist(segStart, segEnd);
          // 将 EXIF 插入新 JPEG 的 SOI 之后
          final out = BytesBuilder();
          out.add([0xFF, 0xD8]);
          out.add(exifSeg);
          // 剩余新图从索引2开始加入
          out.add(newJpeg.sublist(2));
          return out.toBytes();
        }
      }
      i = segEnd;
    }
    return newJpeg;
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
      debugPrint('$e: ${e.description}');
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

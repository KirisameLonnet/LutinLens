import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:librecamera/main.dart';

class CaptureControlWidget extends StatefulWidget {
  const CaptureControlWidget({
    Key? key,
    required this.controller,
    required this.onTakePictureButtonPressed,
    required this.onNewCameraSelected,
    required this.leadingWidget,
    required this.isRearCameraSelected,
    required this.setIsRearCameraSelected,
  }) : super(key: key);

  final CameraController? controller;
  final VoidCallback onTakePictureButtonPressed;
  final Function(CameraDescription) onNewCameraSelected;
  final Widget leadingWidget;
  final bool isRearCameraSelected;
  final Function() setIsRearCameraSelected;

  @override
  State<CaptureControlWidget> createState() => _CaptureControlWidgetState();
}

class _CaptureControlWidgetState extends State<CaptureControlWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  @override
  void initState() {
    animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  Widget captureButton() {
    return AnimatedRotation(
      duration: const Duration(milliseconds: 400),
      turns:
          MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 0.25,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => widget.onTakePictureButtonPressed(),
        icon: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.circle,
              color: Colors.white38,
              size: 80,
            ),
            const Icon(
              Icons.circle,
              color: Colors.white,
              size: 65,
            ),
            Icon(
              Icons.camera_alt,
              color: Colors.grey.shade800,
              size: 32,
            ),
          ],
        ),
        tooltip: AppLocalizations.of(context)!.takePicture,
        iconSize: 80,
      ),
    );
  }

  Widget switchButton() {
    return AnimatedRotation(
      duration: const Duration(milliseconds: 400),
      turns:
          MediaQuery.of(context).orientation == Orientation.portrait ? 0 : 0.25,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          widget.onNewCameraSelected(
              cameras[widget.isRearCameraSelected ? 1 : 0]);
          widget.setIsRearCameraSelected();

          animationController.reset();
          animationController.forward();
        },
        icon: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.circle,
              color: Colors.black38,
              size: 60,
            ),
            AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(animationController.value * 6),
                  child: child,
                );
              },
              child: Icon(
                widget.isRearCameraSelected
                    ? Icons.camera_front
                    : Icons.camera_rear,
                color: Colors.white,
                size: 30,
              ),
            ),
          ],
        ),
        tooltip: widget.isRearCameraSelected
            ? AppLocalizations.of(context)!.flipToFrontCamera
            : AppLocalizations.of(context)!.flipToRearCamera,
        iconSize: 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        widget.leadingWidget,
        captureButton(),
        FutureBuilder(
          future: deviceInfo.androidInfo,
          builder: (context, snapshot) {
            return switchButton();
          },
        ),
      ],
    );
  }
}

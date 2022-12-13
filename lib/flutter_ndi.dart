import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'dart:isolate';
import 'package:tuple/tuple.dart';
import 'dart:core';

import 'dart:io';

import 'libndi_bindings.dart';

final DynamicLibrary libNDI_dynamicLib = Platform.isAndroid
    ? DynamicLibrary.open("libndi.so")
    : DynamicLibrary.process();

NativeLibrary libNDI = new NativeLibrary(libNDI_dynamicLib);

class NDISource {
  String name;
  String address;

  NDISource({required this.name, required this.address});
}

class VideoFrameData {
  int width;
  int height;
  Uint8List data;

  VideoFrameData(
      {required this.width, required this.height, required this.data});
}

abstract class FlutterNdi {
  static bool isLoaded = false;

  static const MethodChannel _channel = const MethodChannel('flutter_ndi');

  // // TODO: Remove
  // static Future<String?> get platformVersion async {
  //   // instance = libNDI.NDIlib_send_create();
  //   // if (!instance) {
  //   //   error
  //   // }

  //   // onframe
  //   // libNDI.NDIlib_send_send_video_v2(instance, p_video_data)

  //   final String? version = await _channel.invokeMethod('getPlatformVersion');
  //   return version;
  // }

  static Future<bool> initPlugin() async {
    if (isLoaded) return isLoaded;
    await _channel.invokeMethod('init_os');
    // libNDI = new NativeLibrary(libNDI_dynamicLib);
    if (libNDI.NDIlib_initialize()) return true;
    if (!libNDI.NDIlib_is_supported_CPU()) {
      throw Exception("CPU incompatible with NDI");
    } else {
      throw Exception("Unable to initialise NDI");
    }
  }

  static Pointer<NDIlib_send_instance_type> createSendHandle(
      String sourceName) {
    final source_data = calloc<NDIlib_send_create_t>();
    source_data.ref.p_ndi_name = sourceName.toNativeUtf8().cast<Char>();

    return libNDI.NDIlib_send_create(source_data);
  }

  static Pointer<NDIlib_find_instance_type> createSourceFinder() {
    final finder_data = calloc<NDIlib_find_create_t>();
    finder_data.ref.show_local_sources = true;
    var result = libNDI.NDIlib_find_create_v2(finder_data);
    return result;
    // calloc.free(finder_data);
  }

  static Map<String, Tuple2<NDISource, DateTime>> historicalSources = new Map();

  static List<NDISource> getDiscoveredSources() {
    var minDiscoveryTime = DateTime.now().subtract(Duration(minutes: 1));
    return historicalSources.values
        .where((tup) => tup.item2.isAfter(minDiscoveryTime))
        .map((e) => e.item1)
        .toList();
  }

  static List<NDISource> findSources(
      {Pointer<NDIlib_find_instance_type>? sourceFinder,
      bool ignorePrevious = false}) {
    var __orig_sourceFinder = sourceFinder;
    if (sourceFinder == null) sourceFinder = createSourceFinder();

    debugPrint("Searching for NDI sources");
    libNDI.NDIlib_find_wait_for_sources(sourceFinder, 2000);

    List<NDISource> discoveredSources = [];
    Pointer<Uint32> numSources = malloc<Uint32>();
    Pointer<NDIlib_source_t> sources =
        libNDI.NDIlib_find_get_current_sources(sourceFinder, numSources);

    debugPrint("Found ${numSources.value} sources");

    bool isValidAddress(String str) {
      final splitIdx = str.lastIndexOf(":");
      if (splitIdx == -1) return false;

      // ipv4 rn
      try {
        Uri.parseIPv4Address(str.substring(0, splitIdx));
      } catch (ex) {
        debugPrint("Failed to parse ${ex.toString()}");
        return false;
      }

      final port = int.tryParse(str.substring(splitIdx + 1));
      if (port == null || port < 1 || port > 65535) return false;

      return true;
    }

    for (var i = 0; i < numSources.value; i++) {
      try {
        NDIlib_source_t source_t = sources.elementAt(i).ref;
        var sourceName = source_t.p_ndi_name.cast<Utf8>().toDartString();
        var sourceAddress = source_t.p_url_address.cast<Utf8>().toDartString();

        // debugPrint("Original source address :: ${sourceAddress}");
        if (!isValidAddress(sourceAddress)) {
          // debugPrint("Fixing bad source resolution");
          final _sourceName = sourceName;
          sourceName = sourceAddress;
          sourceAddress = _sourceName;
        }

        final source = NDISource(name: sourceName, address: sourceAddress);

/**
  I/flutter ( 6731): Searching for NDI sources
  I/flutter ( 6731): Found 4 sources
  I/flutter ( 6731): Discovered: RND-ANDREW (Intel UHD Graphics 620 1) @ 10.13.11.38:5962
  I/flutter ( 6731): Discovered: 10.13.11.38:5963 @ RND-ANDREW (Intel UHD Graphics 620 3)
  I/flutter ( 6731): Discovered: RND-ANDREW (Webcam NDI) @ 10.13.11.38:5961
  I/flutter ( 6731): Couldn't unpack source 
 */
        debugPrint("Discovered: ${source.name} @ ${source.address}");

        historicalSources[sourceAddress] = new Tuple2(source, DateTime.now());
        if (ignorePrevious) discoveredSources.add(source);
      } catch (ex) {
        debugPrint("Couldn't unpack source");
      }
    }

    malloc.free(numSources);
    // malloc.free(sources); // TODO: Free a few more than that...

    // Destroy the source finder if created from this function
    if (__orig_sourceFinder == null) {
      libNDI.NDIlib_find_destroy(sourceFinder);
      // calloc.free(sourceFinder);
    }

    return ignorePrevious ? discoveredSources : getDiscoveredSources();
  }

  static ReceivePort listenToFrameData(NDISource source) {
    debugPrint("listenToFrameData :: ${source.name}");

    final source_t = calloc<NDIlib_source_t>();
    source_t.ref.p_ndi_name = source.name.toNativeUtf8().cast<Char>();
    // source_t.ref.p_url_address = source.address.toNativeUtf8().cast<Char>();

    var recvDescription = calloc<NDIlib_recv_create_v3_t>();
    recvDescription.ref.source_to_connect_to = source_t.ref;
    recvDescription.ref.color_format =
        // NDIlib_recv_color_format_e.NDIlib_recv_color_format_RGBX_RGBA;
        (NDIlib_recv_color_format_e.NDIlib_recv_color_format_UYVY_RGBA << 32) |
            NDIlib_recv_color_format_e.NDIlib_recv_color_format_UYVY_RGBA;
    recvDescription.ref.bandwidth =
        NDIlib_recv_bandwidth_e.NDIlib_recv_bandwidth_lowest;
    // NDIlib_recv_bandwidth_e.NDIlib_recv_bandwidth_highest;

    recvDescription.ref.allow_video_fields = false;

    recvDescription.ref.p_ndi_recv_name =
        "Channel 1".toNativeUtf8().cast<Char>();

    debugPrint("Creating receiver instance");

    NDIlib_recv_instance_t Receiver =
        libNDI.NDIlib_recv_create_v4(recvDescription, nullptr);

    debugPrint("Created instance");

    if (Receiver.address == 0) {
      throw Exception("Could not create NDI receiver instance");
    }

    ReceivePort _receivePort = new ReceivePort();
    ReceivePort _controlPort = new ReceivePort();

    // eye-so-let
    Isolate.spawn(_receiverThread, {
      'port': _receivePort.sendPort,
      'controlPort': _controlPort.sendPort,
      'receiver': Receiver.address,
    }).then((isolate) {
      activeThreads[_receivePort] = () {
        activeThreads.remove(_receivePort);
        _receivePort.close();
        _controlPort.first.then((value) => (value as SendPort).send(null));
      };
    });

    return _receivePort;
  }

  static void stopListen(ReceivePort port) {
    activeThreads[port]?.call();
  }

  static Map<ReceivePort, Function> activeThreads = Map();

  // Isolate _videoFrameReceiver;
  // final receivePort = ReceivePort();
  //https://gist.github.com/jebright/a7086adc305615aa3a655c6d8bd90264
  //http://a5.ua/blog/how-use-isolates-flutter
  // https://api.flutter.dev/flutter/dart-isolate/Isolate-class.html

  static void _receiverThread(Map map) {
    NDIlib_recv_instance_t Receiver =
        NDIlib_recv_instance_t.fromAddress(map['receiver']);
    SendPort emitter = map['port'];

    bool active = true;

    // Can't send ReceivePorts over Isolate messages
    // So instead we send a SendPort, which sends back a reply SendPort
    // When the reply SendPort is called, then set active to false;
    SendPort control = map['controlPort'];
    ReceivePort stopSignal = new ReceivePort();
    control.send(stopSignal.sendPort);
    stopSignal.first.then((value) => () {
          debugPrint("Stop signal received");
          active = false;
        });

    // NDIlib_send_is_keyframe_required

    var vFrame = malloc<NDIlib_video_frame_v2_t>();
    // var aFrame = malloc<NDIlib_audio_frame_v2_t>();
    var mFrame = malloc<NDIlib_metadata_frame_t>();

    while (active) {
      // What if multiple types were received? memory leak?
      switch (libNDI.NDIlib_recv_capture_v3(
          Receiver, vFrame, nullptr, mFrame, 1000)) {
        case NDIlib_frame_type_e.NDIlib_frame_type_none:
          debugPrint("Got empty frame");
          break;

        case NDIlib_frame_type_e.NDIlib_frame_type_video:
          debugPrint("Got video frame");

          switch (vFrame.ref.FourCC) {
            case NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_BGRX:
              debugPrint("FourCC :: BGRX");
              break;
            default:
              debugPrint("FourCC :: ${vFrame.ref.FourCC} (unresolved)");
          }

          int yres = vFrame.ref.yres;
          int xres = vFrame.ref.xres;

// TODO: Only emit if ready

          emitter.send(VideoFrameData(
              width: xres,
              height: yres,
              data: Uint8List.fromList(vFrame.ref.p_data
                  .asTypedList(yres * vFrame.ref.line_stride_in_bytes))));

          libNDI.NDIlib_recv_free_video_v2(Receiver, vFrame);
          break;

        // case NDIlib_frame_type_e.NDIlib_frame_type_audio:
        //   debugPrint("Got audio frame");
        //   libNDI.NDIlib_recv_free_audio_v2(Receiver, aFrame);
        //   break;

        case NDIlib_frame_type_e.NDIlib_frame_type_metadata:
          debugPrint("Got metadata frame");
          libNDI.NDIlib_recv_free_metadata(Receiver, mFrame);
          break;

        case NDIlib_frame_type_e.NDIlib_frame_type_error:
          debugPrint("Got error frame");
          break;

        case NDIlib_frame_type_e.NDIlib_frame_type_status_change:
          debugPrint("Got status change frame");
          break;
      }
    }

    malloc.free(vFrame);
    // malloc.free(aFrame);
    malloc.free(mFrame);

    libNDI.NDIlib_recv_destroy(Receiver);
    malloc.free(Receiver);
  }
}

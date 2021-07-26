import 'dart:async';

import 'package:flutter/services.dart';

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'dart:io';

import 'libndi_bindings.dart';

final DynamicLibrary libNDI_dynamicLib = Platform.isAndroid
    ? DynamicLibrary.open("libndi.so")
    : DynamicLibrary.process();

abstract class FlutterNdi {
  static bool isLoaded = false;

  static const MethodChannel _channel = const MethodChannel('flutter_ndi');
  static NativeLibrary libNDI = null as NativeLibrary;

  // TODO: Remove
  static Future<String?> get platformVersion async {
    // instance = libNDI.NDIlib_send_create();
    // if (!instance) {
    //   error
    // }

    // onframe
    // libNDI.NDIlib_send_send_video_v2(instance, p_video_data)

    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> initPlugin() async {
    if (isLoaded) return isLoaded;
    await _channel.invokeMethod('init_os');
    libNDI = new NativeLibrary(libNDI_dynamicLib);
    if (libNDI.NDIlib_initialize()) return true;
    if (!libNDI.NDIlib_is_supported_CPU()) {
      throw Exception("CPU incompatible with NDI");
    } else {
      throw Exception("Unable to initialise NDI");
    }
  }

  static Pointer<Void> createSendHandle(String sourceName) {
    final source_data = calloc<NDIlib_send_create_t>();
    source_data.ref.p_ndi_name = sourceName.toNativeUtf8().cast<Int8>();

    return libNDI.NDIlib_send_create(source_data);
  }

  static Pointer<Void> createSourceFinder() {
    final finder_data = calloc<NDIlib_find_create_t>();
    finder_data.ref.show_local_sources = true_1;
    return libNDI.NDIlib_find_create_v2(finder_data);
  }

  static List<String> findSources() =>
      findSourcesExplicit(createSourceFinder());
  static List<String> findSourcesExplicit(Pointer<Void> SourceFinder) {
    List<String> result = [];
    if (libNDI.NDIlib_find_wait_for_sources(SourceFinder, 5000)) {
      Pointer<Uint32> numSources = malloc<Uint32>();
      Pointer<NDIlib_source_t> sources =
          libNDI.NDIlib_find_get_current_sources(SourceFinder, numSources);
      for (var i = 0; i < numSources.value; i++) {
        result.add(
            sources.elementAt(i).ref.p_ndi_name.cast<Utf8>().toDartString());
      }
    }

    return result;
  }
}

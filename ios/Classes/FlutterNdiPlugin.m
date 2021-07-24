#import "FlutterNdiPlugin.h"
#if __has_include(<flutter_ndi/flutter_ndi-Swift.h>)
#import <flutter_ndi/flutter_ndi-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_ndi-Swift.h"
#endif

@implementation FlutterNdiPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterNdiPlugin registerWithRegistrar:registrar];
}
@end

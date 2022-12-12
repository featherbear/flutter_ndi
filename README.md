# flutter-ndi

Foreign Function Interface bindings for NewTek NDI.

> Read more: https://featherbear.cc/blog/post/andi-ndi-tools-for-android/

## Setup

Because of licensing, I'm not allowed to include some of the NDI SDK components inside this repository, so you'll have to source it yourself!

0) Install Dart/Flutter and [LLVM](https://pub.dev/packages/ffigen#installing-llvm)  
1) Download the [NDI SDK](https://www.ndi.tv/sdk/) (for Android)  
2) Add the library files into their respective `android/src/main/jniLibs/<architecture>` directory  
   * See _Expected Structure_ below
3) Remove `union` references in `lib/ndi/includes/Processing.NDI.structs.h`  
4) `dart run ffigen`  


<details><summary>Expected Structure</summary>

```
\---jniLibs
    +---arm64-v8a
    |       libndi.so
    |       libndi_bonjour_license.txt
    |       libndi_licenses.txt
    |
    +---armeabi-v7a
    |       libndi.so
    |       libndi_bonjour_license.txt
    |       libndi_licenses.txt
    |
    +---x86
    |       libndi.so
    |       libndi_bonjour_license.txt
    |       libndi_licenses.txt
    |
    \---x86_64
            libndi.so
            libndi_bonjour_license.txt
            libndi_licenses.txt
```

</details>



### Advanced SDK Functionality

To use the advanced functionality of the NDI Advanced SDK, you will need to copy some header files into the `lib/ndi/includes` directory.  
Also modify the `pubspec.yaml` file `ffigen.headers.entry-points` entry to point to `lib/ndi/includes/Processing.NDI.Advanced.h`.  
Then run `dart run ffigen` and you should be set up

---

## Usage

This is a _library_ and not a standalone application - and is intendeded to be used as a dependency for other projects.  
See [aNDI](https://github.com/featherbear/aNDI)

---

## License

This software is licensed under the MIT license, as can be viewed [here](LICENSE.md).  

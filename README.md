# flutter-ndi

Foreign Function Interface bindings for NewTek NDI.

> Read more: https://featherbear.cc/blog/post/andi-ndi-tools-for-android/

## Setup

Because of licensing, I believe I'm not allowed to include some of the NDI SDK components inside this repository, so you'll have to source it yourself!

1) Download the [NDI 5 Advanced SDK](https://www.ndi.tv/sdk/) (for Android)  
2) Add the library files into their respective `android/src/main/jniLibs/<architecture>` directory  
3) `dart run ffigen`  

### Advanced SDK Functionality

To use the advanced functionality of the NDI Advanced SDK, you will need to copy some header files into the `lib/ndi/includes` directory.  
Also modify the `pubspec.yaml` file `ffigen.headers.entry-points` entry to point to `lib/ndi/includes/Processing.NDI.Advanced.h`.  
Then run `dart run ffigen` and you should be set up

---

## License

This software is licensed under the MIT license, as can be viewed [here](LICENSE.md).  

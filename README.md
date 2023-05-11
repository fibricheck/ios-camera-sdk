# FibriCheck iOS Camera SDK
![CI Status](https://github.com/fibricheck/ios-camera-sdk/actions/workflows/ci.yml/badge.svg)

The iOS Camera SDK allows developers to integrate FibriCheck's heart rhythm analysis technology into their own application. The SDK interfaces with the smartphone's camera and generates a raw PPG signal and a rough heartrate estimation in beats per minute.

This SDK should be used in conjunction with the FibriCheck Cloud. It only implements data acquisition and does not offer any stand-alone rate or rhythm diagnostic capabilities.

**Important Compliance Notice!** This is an alpha release of the standalone FibriCheck Camera SDK for iOS. This repository is not yet certified within our quality management systems to be used in production environments. It can currently only be used for development/testing purposes.

## How to install 
To use the SDK in your project, follow these instructions:

### Swift Package Manager

1. Open your Swift project
2. Go to File > Swift Packages > Add Package Dependency
3. In the "Choose Package Repository" dialog, enter the URL of this repository (`https://github.com/fibricheck/ios-camera-sdk`)
4. Select the version or branch of the library you want to use
5. Choose the target where you want to add the library and click Finish

### CocoaPods
1. Open your terminal and navigate to your project directory
2. Run the command `pod init` to create a Podfile
3. Open the Podfile with a text editor
4. Add the following line to the Podfile: `pod 'FibriCheckCameraSDK', :git => 'git@github.com:fibricheck/ios-camera-sdk.git', :tag => 'v0.1.3'`. Verify that you're pointing to the correct version.  <!-- x-release-please-version -->
5. Save and close the Podfile
6. Run the command `pod install` to download and install the library
7. Open the `.xcworkspace` file generated by CocoaPods and start using the library in your Swift project


## Usage with Swift

You can simply import the SDK package in your code using the `import` statement:

```swift
import FibriCheckCameraSDK
```

**Important!** The FibriCheck Camera SDK requires access to the camera to perform a PPG measurement. iOS requires the following usage description to be added and filled for your app in `Info.plist`:
* `NSCameraUsageDescription (Privacy - Camera Usage Description)`


The `examples` folder contains two example iOS projects that use the SDK.  
For more information on how to integrate FibriCheck in your application, see the [FibriCheck Developer Documentation](https://docs.fibricheck.com/introduction/)

## License
This SDK is proprietary. See `LICENCE` for more information.
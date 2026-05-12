# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-05-12

### Added
- Added custom settings and logging (FCRN-2108) ([1343f02](https://github.com/fibricheck/ios-camera-sdk/commit/1343f02a97805a960f5b9df53abaff9da99180d8))
- UDI label added (FCS-79) ([bdb8880](https://github.com/fibricheck/ios-camera-sdk/commit/bdb88806487d12a217b3af730a28eed48fd96518))
- New release process ([dc35022](https://github.com/fibricheck/ios-camera-sdk/commit/dc35022182cb240a801e85738e41a293adf2348c))
- Implement test sequence ([4f0b01d](https://github.com/fibricheck/ios-camera-sdk/commit/4f0b01da0c2b44fb75746d4c0a2ecd1e370d1aeb))
- Added hdr config (FCS-84) ([53bd199](https://github.com/fibricheck/ios-camera-sdk/commit/53bd199f10ebe1bdd23396df9516094454e9ba41))
- Camera preview ([41e460e](https://github.com/fibricheck/ios-camera-sdk/commit/41e460e51154bd3587a4123c5c9de5cc03ddcf83))

### Changed
- Updated testcases to cover the test sequencer ([91107fa](https://github.com/fibricheck/ios-camera-sdk/commit/91107fa6ab6a43636b85912b3104952c7fce1c63))
- Hdr and logging (FCS-84) ([8f2ec67](https://github.com/fibricheck/ios-camera-sdk/commit/8f2ec67fa14b46e1931e0e157d36eaca1e74d502))
- Added log section to readme (FCS-84) ([acac897](https://github.com/fibricheck/ios-camera-sdk/commit/acac89778a20eb208f2118a9ba9ddf660182c9aa))
- Updated defaults (FCS-85) ([e5be98c](https://github.com/fibricheck/ios-camera-sdk/commit/e5be98c0d2ace8b7d779a9b228c8f07faa7b5edd))
- Updated Changelog generation ([f9120ea](https://github.com/fibricheck/ios-camera-sdk/commit/f9120ea87480881b41aa97a8e8c3e9a80f20376a))
- HDR Logging (FCS-85) ([63e146b](https://github.com/fibricheck/ios-camera-sdk/commit/63e146b070d3af0d067e25ef77cf43f355f0d0c0))
- Rename internal camera settings (FCS-85) ([90f66da](https://github.com/fibricheck/ios-camera-sdk/commit/90f66da717f774546149517361fd12816248b283))
- Validate output (FCS-85) ([39a5dc5](https://github.com/fibricheck/ios-camera-sdk/commit/39a5dc5dd00eea6112bbba141e97023923e22739))
- Remove outdated ppg array ([766242a](https://github.com/fibricheck/ios-camera-sdk/commit/766242a7e0050e6467f5d1b7f78d05159de0a02e))
- Updated hdr & focus logging + sequence tester (FCS-85) ([cec8c1e](https://github.com/fibricheck/ios-camera-sdk/commit/cec8c1eb3d561868c802318dc219e748d57185ad))
- Add getLabel() information to test sequence app ([18df714](https://github.com/fibricheck/ios-camera-sdk/commit/18df7147f3a09077a8f03d35444d3b89e25fe63b))
- Updated Release workflow ([40e1f33](https://github.com/fibricheck/ios-camera-sdk/commit/40e1f33e8073eb264addb90c6f071c54c291ef97))
- Camera preview hardening from fda branch ([c1008ba](https://github.com/fibricheck/ios-camera-sdk/commit/c1008ba82a2a660af4d221d5d88426767bb321ef))
- Bump publish workflow ([89231e0](https://github.com/fibricheck/ios-camera-sdk/commit/89231e02458fbe4bf9899794380f5c4e41775806))
- Symlink the release data ([cae8dc7](https://github.com/fibricheck/ios-camera-sdk/commit/cae8dc7c8352f3674077471ca136cb0850a003b3))
- Update test runner ([96080cb](https://github.com/fibricheck/ios-camera-sdk/commit/96080cbfb43541f7c5c6df01c97b059c83038b1e))
- Hard link git-cliff ([859c549](https://github.com/fibricheck/ios-camera-sdk/commit/859c54939dfa4947cba061eb31d9b3eba8f104c3))
- Make sdk compatible for cocoapods ([499b693](https://github.com/fibricheck/ios-camera-sdk/commit/499b693389a218645659de1beec4033b17e153ac))

### Fixed
- Unit tests on CI ([698993c](https://github.com/fibricheck/ios-camera-sdk/commit/698993c201a5f8608dea9a4bdbb2afdeaa13cd43))
- CI release bump ([9ec4c8d](https://github.com/fibricheck/ios-camera-sdk/commit/9ec4c8ddb8ab38b6a4ad37c5794ba3d409d9b3df))
- FCS-79 Update IFU URL to correct (generic) link ([01ba9c8](https://github.com/fibricheck/ios-camera-sdk/commit/01ba9c86300cbab2a0406bc8436740fa74b774c3))
- Swift Testing Errors ([6f025b0](https://github.com/fibricheck/ios-camera-sdk/commit/6f025b03315e13c0ad57c27413140915b8f7fc10))
- Pr comments ([ace2776](https://github.com/fibricheck/ios-camera-sdk/commit/ace27767cd61f41aa5159a364423ba59f1cb30e0))
- Version number ssot ([82acf97](https://github.com/fibricheck/ios-camera-sdk/commit/82acf971230f5e5eccb0e9887d2e70d694e4ca9b))
- FingerDetectionExpiryTime & skippedPulseDetection sync ([3fc1d01](https://github.com/fibricheck/ios-camera-sdk/commit/3fc1d0142ecb9fa3f15495b518ddf3daf4d8a2fa))
- Finger & pulse detection timeouts ([a7e1fe6](https://github.com/fibricheck/ios-camera-sdk/commit/a7e1fe64072b61fcb1f093a2a231ec7010e1aa68))
- Default timeouts update ([a334f9e](https://github.com/fibricheck/ios-camera-sdk/commit/a334f9e768425017cefbf633b1321205b265ea6c))
- Release PR creation process ([5f3e75c](https://github.com/fibricheck/ios-camera-sdk/commit/5f3e75c7d6ff3b1ec09361a63079042787ad8603))

## [1.0.2] - 2024-12-11

### Fixed
- Filter naming update to prevent incorrect linking ([351684d](https://github.com/fibricheck/ios-camera-sdk/commit/351684d8660731e0e939b25ae56c39e4b3fc5bb8))

## [1.0.1] - 2023-11-30

### Changed
- Regulatory Documentation added ([395ce68](https://github.com/fibricheck/ios-camera-sdk/commit/395ce68c7a602a17a19cc2cb44006341c2f307aa))
- Update readme to include the release process ([0624e97](https://github.com/fibricheck/ios-camera-sdk/commit/0624e974052e3411a9a13e0fe5a1b38433f2c46a))
- Add quadrant uniqueness validation to example project for testing [FCS-52] ([ae21e71](https://github.com/fibricheck/ios-camera-sdk/commit/ae21e71f1dae13568b04a25dae11497b48822e7c))

### Fixed
- Quadrant bugfix FCS-52 ([fbf4170](https://github.com/fibricheck/ios-camera-sdk/commit/fbf4170d179f0c2ee36ef4edcab4087053cc2d5c))

## [1.0.0] - 2023-09-25

### Added
- Add regulory documentation (#8) ([ad86c45](https://github.com/fibricheck/ios-camera-sdk/commit/ad86c45aaf25b1629e364b544a5d4ac0abcc29ee))
- FCS-37 Add technical camera details to measurement (#10) ([091b0ab](https://github.com/fibricheck/ios-camera-sdk/commit/091b0ab50f67f32855a19375e4fac9f3047347ec))

### Changed
- Add diagnostic warning on rate or rhythm diagnostic capabilities (#7) ([aac8ac4](https://github.com/fibricheck/ios-camera-sdk/commit/aac8ac4ad51e4036b5ca04e6c6759964148df23b))
- Update regulatory docs (#12) ([dae569d](https://github.com/fibricheck/ios-camera-sdk/commit/dae569db4ea268135ec4642404cb3ba835c7d7f4))
- Update release-please configuration ([bdb1c32](https://github.com/fibricheck/ios-camera-sdk/commit/bdb1c32964d0d597f199eff2a6119e81ada8e554))
- Remove compliance notice ahead of v1.0 release ([b100ecc](https://github.com/fibricheck/ios-camera-sdk/commit/b100ecc006b30ce80f1ba4c2b35424d44039f36b))

### Fixed
- Return measurement_timestamp in measurement result (#11) ([d0bdb3d](https://github.com/fibricheck/ios-camera-sdk/commit/d0bdb3dc874a6e61b5843afb143141887b63f396))

## [0.1.3] - 2023-05-11

### Changed
- Add release please release automation ([393d6a4](https://github.com/fibricheck/ios-camera-sdk/commit/393d6a4db378c7d3b320acedc9279a0f96c79338))
- Be more specific on when to run ci/cd build pipelines ([077b5f9](https://github.com/fibricheck/ios-camera-sdk/commit/077b5f9fc31ee1bf42c2f1316f23f15b3a44d7d1))
- Add compliance notice ([5a68de7](https://github.com/fibricheck/ios-camera-sdk/commit/5a68de7ab3ad093fdeb5b3a6ef14ebfe6fcb9c5e))

## [0.1.0] - 2023-04-13


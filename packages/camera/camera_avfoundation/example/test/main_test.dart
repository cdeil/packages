// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:camera_example/main.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getCameraLensIcon returns icons for all known directions', () {
    expect(getCameraLensIcon(CameraLensDirection.back), Icons.camera_rear);
    expect(getCameraLensIcon(CameraLensDirection.front), Icons.camera_front);
    expect(getCameraLensIcon(CameraLensDirection.external), Icons.camera);
  });
}

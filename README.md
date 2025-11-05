# 🧘 Smart Yoga Mat App Prototype (Flutter)

## 🌟 1. Project Objective and Overview

This repository contains a **Proof-of-Concept (POC) mobile application** built with **Flutter** and **Dart**. The project successfully demonstrates robust, cross-protocol Bluetooth communication with a simulated **ESP32 Smart Yoga Mat** device, focusing on **connection stability** and **graceful error handling**.

### Core Requirements Demonstrated:

  * **Dual Protocol Support:** Reliable device discovery, pairing, and connection using both **Bluetooth Low Energy (BLE)** GATT services and **Classic Bluetooth (SPP)** streaming.
  * **Robust Connection Wrapper:** Implements a central state machine (`ConnectionWrapper`) to manage connection lifecycle, including **automatic reconnection** upon unexpected drops, connection **retries**, and **time-outs**.
  * **End-to-End Functionality:** Simple console UIs verify the exchange of sensor data (BLE Notify/Write) and text stream data (Classic SPP).

-----

## 📽️ 2. Submission Assets and Proof

The core proof of this assignment is the functionality demonstrated in the video and the executable APK file.

### Video Reference

| Asset | Link |
| :--- | :--- |
| **Demo Video (≤ 3 min)** | **(https://github.com/Mr-Srinu/smart_yoga_mat/blob/main/smart_yoga_mat/Screenrecorder-2025-11-05-23-13-25-849.mp4)** |

### APK Download

| Asset | Link |
| :--- | :--- |
| **Latest Debug APK (Android)** | **[Download Latest APK (For Internal Testing)]([https://drive.google.com/file/d/1Ad6UHmeXwvDvO5hTJg7uEcv3lnhr_Cxl/view?usp=drive_link]))** |

Download from here: "https://drive.google.com/file/d/1Ad6UHmeXwvDvO5hTJg7uEcv3lnhr_Cxl/view?usp=drive_link"

-----

## 🛠️ 3. Installation and Setup Guide

Use the following command sequence to clean the project, build the auto-signed Debug APK, and install it on your connected Android device via ADB.

### Prerequisites:

  * Flutter SDK installed.
  * Android device connected with **USB Debugging** enabled.
  * ADB (Android Debug Bridge) is in your system PATH.

### Installation Commands (Copy-Paste Sequence)

Execute the following commands from the project root directory (`smart_yoga_mat/`):

```bash
# 1. Clean build files and fetch dependencies
flutter clean
flutter pub get

# 2. Build the auto-signed Debug APK (The fastest way to install for testing)
flutter build apk --debug

# 3. Verify ADB connection
adb devices

# 4. Install the generated APK onto the connected device
# NOTE: The path is relative to the project root.
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 5. Optional: Launch the application after installation
adb shell am start -n [YOUR_PACKAGE_NAME]/[YOUR_PACKAGE_NAME].MainActivity
```

-----

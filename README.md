# aStorageEnum
Android application local storage enum.

Used to fetch interesting files within an application's Data Directory from an Android device (rooted or via run-as). It downloads the application's data files to your local machine, extracts strings, finds Base64 encoded values (e.g., JWTs), and runs keyword searches to fetch potentially sensitive information.

## Requirements
* Windows (PowerShell)
* `adb` installed and accessible in your PATH.
* `grepwords.txt` containing keywords you want to search for.

## Installation
Just `git clone` this repo and you're good to go!

`git clone https://github.com/itsAgasthya/AndroidStorageEnum.git`

## Usage (Android)

Connect your Android device via USB and ensure USB Debugging is enabled. 

Run the script in PowerShell:

```powershell
.\aStorageEnum.ps1 -PackageName com.example.app
```

Or just run the script and it will prompt you for the package name:

```powershell
.\aStorageEnum.ps1
```

## Features
- Extracts application data over ADB (using `su` if rooted, or `run-as` if debuggable).
- Converts files to readable strings automatically.
- Identifies and extracts Base64 values automatically.
- Uses `grepwords.txt` to search for user-defined keywords (like tokens, passwords, keys).
- Outputs organized results for easy viewing.

## Credits
This tool is heavily based on and inspired by [iStorageEnumV2](https://github.com/shibinbshaji/iStorageEnumV2.git) by Shibin B. Shaji.

#!/bin/bash
device=$1
if [ -z "$device" ]; then
    echo "Usage: $0 <device_id>"
    exit 1;
fi
rm -f integration_test/goldens/{ios,macos,windows,android}/*.png
flutter drive --driver=test_driver/integration_test_update_goldens.dart  -d $1 --target=integration_test/plugin_integration_test.dart       

#!/bin/bash
# Quick script to disable debug performance settings that slow indexing

echo "Disabling debug performance stats generation..."

# Comment out the debug settings in Package.swift
sed -i.bak 's/^let debugPerformanceSettings/\/\/ let debugPerformanceSettings/' Package.swift

# Or set to empty array
# This will prevent the .build/stats directory from filling up with files Xcode tries to index

echo "Done! Restart Xcode for changes to take effect."
echo ""
echo "To re-enable, uncomment the debugPerformanceSettings definition in Package.swift"

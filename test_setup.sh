#!/bin/bash

echo "=== GStreamer Stitching Benchmark - Quick Test ==="
echo ""

# Check system information
echo "System Information:"
if command -v nvidia-smi &> /dev/null; then
    echo "✓ NVIDIA GPU detected"
    nvidia-smi --query-gpu=name,driver_version,cuda_version --format=csv,noheader | while read -r name driver cuda; do
        echo "  - $name (Driver: $driver, CUDA: $cuda)"
    done
else
    echo "⚠ No NVIDIA GPU detected"
fi

# Check if required tools are installed
echo "Checking prerequisites..."

if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed"
    echo "   Install it with: sudo apt-get install jq (Ubuntu/Debian)"
else
    echo "✓ jq is installed"
fi

if ! command -v gst-inspect-1.0 &> /dev/null; then
    echo "❌ GStreamer is not installed"
    echo "   Run ./install_gstreamer.sh to install it"
else
    echo "✓ GStreamer is installed"
fi

if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    echo "❌ Neither wget nor curl are installed"
else
    echo "✓ Download tools available (wget or curl)"
fi

# Check if wget and curl are available
if command -v wget &> /dev/null; then
    echo "✓ wget is installed"
else
    echo "⚠ wget not found"
    echo "   Install it with: sudo apt-get install wget (Ubuntu/Debian)"
fi

if command -v curl &> /dev/null; then
    echo "✓ curl is available as fallback"
else
    echo "⚠ curl not found"
    echo "   Install it with: sudo apt-get install curl (Ubuntu/Debian)"
fi

# Check configuration
echo ""
echo "Checking configuration..."

if [ -f "config.json" ]; then
    echo "✓ config.json found"
    
    # Validate JSON
    if jq empty config.json &> /dev/null; then
        echo "✓ config.json is valid JSON"
    else
        echo "❌ config.json has invalid JSON"
    fi
else
    echo "❌ config.json not found"
fi

# Check input videos
echo ""
echo "Checking input videos..."

if [ -d "input_videos" ] && [ $(ls -1 input_videos/ 2>/dev/null | wc -l) -ge 4 ]; then
    echo "✓ Input videos directory has $(( $(ls -1 input_videos/ 2>/dev/null | wc -l) )) videos"
else
    echo "⚠ No input videos found (expected in input_videos/)"
fi

echo ""
echo "=== Test Summary ==="
echo "Ready to run: ./run_benchmark.sh"
echo "Or test a single resolution: ./run_single_benchmark.sh 8k"

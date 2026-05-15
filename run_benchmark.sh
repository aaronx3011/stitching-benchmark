#!/bin/bash
set -e

echo "=== GStreamer Video Stitching Benchmark ==="
echo "Starting at: $(date)"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    echo "On Ubuntu/Debian: sudo apt-get install jq"
    exit 1
fi

# Load configuration
CONFIG_FILE="config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found!"
    exit 1
fi

echo "Loading configuration from $CONFIG_FILE..."
CONFIG=$(cat "$CONFIG_FILE" | jq -r '@json')

# Create directories if they don't exist
mkdir -p results
mkdir -p plugins
mkdir -p input_videos

echo "=== Step 1: Installing GStreamer and dependencies ==="
./install_gstreamer.sh

echo ""
echo "=== Step 2: Downloading test videos ==="
./download_videos.sh

echo ""
echo "=== Step 3: Running HLS multi-resolution benchmark ==="

echo "------------------------------------------------------------------"
echo "Running benchmark (all resolutions: 8K H.265, 4K H.265, 2K H.264, 1K H.264)..."
echo "------------------------------------------------------------------"
./run_single_benchmark.sh "8k"
echo ""

echo "=== Benchmark completed successfully! ==="
echo "Results saved in results/ directory"
echo "Finished at: $(date)"

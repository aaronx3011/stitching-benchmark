#!/bin/bash
set -e

echo "=== Downloading test videos ==="

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
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

# Create input_videos directory if it doesn't exist
mkdir -p input_videos

# Extract video URLs from config
VIDEO_URLS=$(echo "$CONFIG" | jq -r '.input.video_urls[]')

if [ -z "$VIDEO_URLS" ]; then
    echo "Error: No video URLs found in configuration!"
    exit 1
fi

# Download each video
count=0
for url in $VIDEO_URLS; do
    count=$((count + 1))
    filename="input_videos/video_${count}.mp4"
    
    echo "Downloading video ${count}/4 from $url..."
    
    # Use wget with retry logic
    if ! wget -q --show-progress --progress=bar:force:noscroll -O "$filename" "$url"; then
        echo "Error: Failed to download video from $url"
        echo "Trying again with curl..."
        
        if ! curl -L -o "$filename" "$url"; then
            echo "Error: Both wget and curl failed to download the video!"
            rm -f "$filename"
            exit 1
        fi
    fi
    
    # Verify file was downloaded
    if [ ! -f "$filename" ]; then
        echo "Error: Video file not found after download!"
        exit 1
    fi
    
    filesize=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null || wc -c < "$filename")
    echo "Successfully downloaded ${count}/4 (${filesize} bytes)"
done

# Verify all videos are present
video_count=$(ls input_videos/ | wc -l)
expected_count=4

if [ "$video_count" -ne "$expected_count" ]; then
    echo "Error: Expected $expected_count videos but found $video_count!"
    exit 1
fi

echo "All test videos downloaded successfully!"
echo "Videos saved in input_videos/ directory"

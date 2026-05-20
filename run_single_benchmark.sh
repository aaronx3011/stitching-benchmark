#!/bin/bash
set -e

echo "=== Running GStreamer Stitching Benchmark ==="

# Load system information
SYSTEM_INFO=$(bash get_system_info.sh)

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Check arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <resolution>"
    echo "Example: $0 8k"
    exit 1
fi

TARGET_RESOLUTION="$1"

echo "Target resolution: $TARGET_RESOLUTION"

# Load configuration
CONFIG_FILE="config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found!"
    exit 1
fi

echo "Loading configuration from $CONFIG_FILE..."
CONFIG=$(cat "$CONFIG_FILE" | jq -r '@json')

# Get resolution details
RES_WIDTH=$(echo "$CONFIG" | jq -r ".output_resolutions[] | select(.name == \"$TARGET_RESOLUTION\") | .width")
RES_HEIGHT=$(echo "$CONFIG" | jq -r ".output_resolutions[] | select(.name == \"$TARGET_RESOLUTION\") | .height")

if [ -z "$RES_WIDTH" ] || [ -z "$RES_HEIGHT" ]; then
    echo "Error: Resolution $TARGET_RESOLUTION not found in configuration!"
    exit 1
fi

echo "Output resolution: ${RES_WIDTH}x${RES_HEIGHT}"

# Get benchmark duration
DURATION=$(echo "$CONFIG" | jq -r '.benchmark.duration_seconds')
WARMUP=$(echo "$CONFIG" | jq -r '.benchmark.warmup_seconds')

echo "Benchmark duration: ${DURATION}s (warmup: ${WARMUP}s)"

# Download calibration file if needed
CALIBRATION_FILE=$(echo "$CONFIG" | jq -r '.input.calibration_file // empty')
if [ -n "$CALIBRATION_FILE" ] && [ "$CALIBRATION_FILE" != "null" ]; then
    echo "Downloading calibration file from $CALIBRATION_FILE..."
    wget -O "calibration.pts" "$CALIBRATION_FILE"
fi

# Create results directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results/${TARGET_RESOLUTION}_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

# Create HLS output subdirectories
mkdir -p "${RESULTS_DIR}/high" "${RESULTS_DIR}/low"

echo "Results will be saved to: $RESULTS_DIR"

# Build GStreamer pipeline (HLS multi-resolution with filesrc mp4 inputs)
PIPELINE=""

# Calibration argument for stitcher
CALIB_ARG=""
if [ -f "calibration.pts" ]; then
    CALIB_ARG="template=calibration.pts"
fi

# Input sources (4x 4K videos) + stitching + HLS multi-resolution output
PIPELINE+="filesrc location=input_videos/video_1.mp4 ! qtdemux name=demux1 demux1.video ! queue ! h264parse ! nvh264dec ! video/x-raw(memory:GLMemory) ! glcolorconvert ! video/x-raw(memory:GLMemory),format=RGBA ! "
PIPELINE+="mix. filesrc location=input_videos/video_2.mp4 ! qtdemux name=demux2 demux2.video ! queue ! h264parse ! nvh264dec ! video/x-raw(memory:GLMemory) ! glcolorconvert ! video/x-raw(memory:GLMemory),format=RGBA ! "
PIPELINE+="mix. filesrc location=input_videos/video_3.mp4 ! qtdemux name=demux3 demux3.video ! queue ! h264parse ! nvh264dec ! video/x-raw(memory:GLMemory) ! glcolorconvert ! video/x-raw(memory:GLMemory),format=RGBA ! "
PIPELINE+="mix. filesrc location=input_videos/video_4.mp4 ! qtdemux name=demux4 demux4.video ! queue ! h264parse ! nvh264dec ! video/x-raw(memory:GLMemory) ! glcolorconvert ! video/x-raw(memory:GLMemory),format=RGBA ! "
PIPELINE+="mix. gldmdstitcher name=mix client=vrinsitu1 ${CALIB_ARG} crop-left=-90 crop-right=90 crop-bottom=-45 crop-top=45 ! video/x-raw(memory:GLMemory),format=RGBA,width=7680,height=4320 ! "
PIPELINE+="tee name=t t. ! queue ! nvh265enc preset=1 ! h265parse ! queue ! "
PIPELINE+="mpegtsmux name=mux0 ! hlssink target-duration=15 location=${RESULTS_DIR}/high/8k_%05d.ts playlist-location=${RESULTS_DIR}/high/8k.m3u8 "
PIPELINE+="t. ! queue ! glcolorscale ! video/x-raw(memory:GLMemory),width=3840,height=2160 ! nvh265enc preset=1 ! h265parse ! "
PIPELINE+="mpegtsmux name=mux1 ! hlssink target-duration=15 location=${RESULTS_DIR}/high/4k_%05d.ts playlist-location=${RESULTS_DIR}/high/4k.m3u8 "
PIPELINE+="t. ! queue ! glcolorscale ! video/x-raw(memory:GLMemory),width=2560,height=1440 ! nvh264enc preset=1 ! h264parse ! "
PIPELINE+="mpegtsmux name=mux2 ! hlssink target-duration=15 location=${RESULTS_DIR}/low/2k_%05d.ts playlist-location=${RESULTS_DIR}/low/2k.m3u8 "
PIPELINE+="t. ! queue ! glcolorscale ! video/x-raw(memory:GLMemory),width=2600,height=900 ! nvh264enc preset=1 ! h264parse ! "
PIPELINE+="mpegtsmux name=mux3 ! hlssink target-duration=15 location=${RESULTS_DIR}/low/1k_%05d.ts playlist-location=${RESULTS_DIR}/low/1k.m3u8"

echo "GStreamer pipeline:"
echo "$PIPELINE"

# Run benchmark with timing
START_TIME=$(date +%s.%N)
echo "Starting benchmark at $(date)..."

# Warmup phase
echo "Running warmup for ${WARMUP}s..."
gst-launch-1.0 -v $PIPELINE 2>&1 | head -n 50 || true
sleep $WARMUP

# Actual benchmark
echo "Starting actual benchmark..."
OUTPUT=$(gst-launch-1.0 -v $PIPELINE 2>&1)
END_TIME=$(date +%s.%N)

# Calculate metrics
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
FPS=$(echo "$DURATION / $ELAPSED * 1" | bc)
PROCESSING_TIME_MS=$(echo "1000 / $FPS" | bc)

# Create JSON results
cat > "${RESULTS_DIR}/metrics.json" << EOF
{
  "benchmark": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "input": {
      "count": 4,
      "resolution": "3840x2160",
      "format": "H.264"
    },
    "output": {
      "type": "HLS multi-resolution",
      "streams": [
        {"name": "8k", "width": 7680, "height": 4320, "codec": "H.265", "path": "${RESULTS_DIR}/high/8k.m3u8"},
        {"name": "4k", "width": 3840, "height": 2160, "codec": "H.265", "path": "${RESULTS_DIR}/high/4k.m3u8"},
        {"name": "2k", "width": 2560, "height": 1440, "codec": "H.264", "path": "${RESULTS_DIR}/low/2k.m3u8"},
        {"name": "1k", "width": 2600, "height": 900, "codec": "H.264", "path": "${RESULTS_DIR}/low/1k.m3u8"}
      ]
    },
    "metrics": {
      "fps": $FPS,
      "processing_time_per_frame_ms": $PROCESSING_TIME_MS,
      "total_duration_seconds": $ELAPSED,
      "gstreamer_pipeline": "$PIPELINE"
    },
    "system_info": $SYSTEM_INFO
  }
}
EOF

echo "Benchmark completed!"
echo "Results saved to: ${RESULTS_DIR}/metrics.json"
echo "HLS playlists saved to: ${RESULTS_DIR}/high/ (8K, 4K) and ${RESULTS_DIR}/low/ (2K, 1K)"
echo ""
echo "Metrics:"
echo "  FPS: $FPS"
echo "  Processing time per frame: ${PROCESSING_TIME_MS}ms"
echo "  Total duration: ${ELAPSED}s"

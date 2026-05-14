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

echo "Results will be saved to: $RESULTS_DIR"

# Build GStreamer pipeline
PIPELINE=""

# Input sources (4x 4K videos)
for i in {1..4}; do
    if [ $i -gt 1 ]; then
        PIPELINE+=" "
    fi
    PIPELINE+="filesrc location=input_videos/video_${i}.mp4 ! qtdemux name=demux${i} demux${i}.video ! queue ! nvv4l2decoder ! videoconvert"
done

# Add custom stitching element
PIPELINE+=" ! mux.sink_0 \
           filesrc location=input_videos/video_1.mp4 ! qtdemux name=demux1 demux1.audio ! queue ! aacparse ! avdec_aac \
           filesrc location=input_videos/video_2.mp4 ! qtdemux name=demux2 demux2.audio ! queue ! aacparse ! avdec_aac \
           filesrc location=input_videos/video_3.mp4 ! qtdemux name=demux3 demux3.audio ! queue ! aacparse ! avdec_aac \
           filesrc location=input_videos/video_4.mp4 ! qtdemux name=demux4 demux4.audio ! queue ! aacparse ! avdec_aac"

# Custom stitching plugin with calibration file
if [ -f "calibration.pts" ]; then
    PIPELINE+=" ! customstitch name=stitcher width=${RES_WIDTH} height=${RES_HEIGHT} calibration=calibration.pts"
else
    PIPELINE+=" ! customstitch name=stitcher width=${RES_WIDTH} height=${RES_HEIGHT}"
fi

# Output encoding
PIPELINE+=" ! nvvidconv ! video/x-raw(memory:NVMM), format=I420, width=${RES_WIDTH}, height=${RES_HEIGHT} ! nvv4l2h265enc bitrate=20000000 ! h265parse ! matroskamux ! filesink location=${RESULTS_DIR}/output_${TARGET_RESOLUTION}.mkv"

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
    "output_resolution": {
      "name": "$TARGET_RESOLUTION",
      "width": $RES_WIDTH,
      "height": $RES_HEIGHT
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
echo "Output video saved to: ${RESULTS_DIR}/output_${TARGET_RESOLUTION}.mkv"
echo ""
echo "Metrics:"
echo "  FPS: $FPS"
echo "  Processing time per frame: ${PROCESSING_TIME_MS}ms"
echo "  Total duration: ${ELAPSED}s"

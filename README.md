# GStreamer Video Stitching Benchmark

A benchmark tool for testing video stitching performance using GStreamer with NVIDIA hardware acceleration and custom plugins.

## Overview

This repository provides a complete solution for benchmarking video stitching pipelines that:
- Accept 4x 4K input videos (3840x2160)
- Stitch them into multiple output resolutions: 8K, 6K, 4K, 2K, and 1080p
- Use NVIDIA decoders/encoders for hardware acceleration
- Support custom GStreamer plugins
- Measure performance metrics (FPS, processing time per frame, total duration)
- Output structured JSON results

## Repository Structure

```
stitching-benchmark/
├── README.md                  # This file
├── requirements.txt           # Python dependencies
├── install_gstreamer.sh       # GStreamer installation script
├── download_videos.sh         # Video download script
├── run_benchmark.sh           # Main benchmark execution
├── config.json                # Configuration file
├── results/                   # Benchmark results directory
└── plugins/                   # Custom plugin directory
```

## Prerequisites

- Linux system with NVIDIA GPU
- NVIDIA drivers installed
- Internet connection for downloads
- Bash 4.0+ (for associative arrays)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/aaronx3011/stitching-benchmark.git
cd stitching-benchmark
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure your setup by editing `config.json`:
   - Set S3 video URLs or direct download links
   - Specify custom plugin path/URL
   - Configure any additional parameters

## Usage

### Quick Start
Run the complete benchmark pipeline:
```bash
./run_benchmark.sh
```

This will:
1. Install GStreamer with NVIDIA plugins and OpenGL support
2. Download test videos from your S3 bucket
3. Run benchmarks for all output resolutions
4. Save results in JSON format

### Individual Steps

1. **Install GStreamer**:
```bash
./install_gstreamer.sh
```

2. **Download Test Videos**:
```bash
./download_videos.sh
```

3. **Run Benchmark for Specific Resolution**:
```bash
./run_single_benchmark.sh 8k
```

## Configuration

Edit `config.json` to customize your setup:

```json
{
  "input": {
    "video_urls": [
      "https://vrinsitu-aaron-bucket.s3.amazonaws.com/cloudTesting/origin_1.mp4",
      "https://vrinsitu-aaron-bucket.s3.amazonaws.com/cloudTesting/origin_2.mp4",
      "https://vrinsitu-aaron-bucket.s3.amazonaws.com/cloudTesting/origin_3.mp4",
      "https://vrinsitu-aaron-bucket.s3.amazonaws.com/cloudTesting/origin_4.mp4"
    ],
    "resolution": "3840x2160",
    "format": "H.264",
    "calibration_file": "https://vrinsitu-aaron-bucket.s3.amazonaws.com/cloudTesting/TestTitan4LensV2.pts"
  },
  "custom_plugin": {
    "url": "https://vrinsitu-aaron-bucket.s3.amazonaws.com/cloudTesting/libgldmdstitcher.so",
    "install_path": "./plugins/"
  },
  "output_resolutions": [
    {"name": "8k", "width": 7680, "height": 4320},
    {"name": "6k", "width": 6400, "height": 3600},
    {"name": "4k", "width": 3840, "height": 2160},
    {"name": "2k", "width": 2560, "height": 1440},
    {"name": "1080p", "width": 1920, "height": 1080}
  ],
  "benchmark": {
    "duration_seconds": 120,
    "warmup_seconds": 10
  }
}
```

## Output Format

Results are saved in `results/{timestamp}/metrics.json` with this structure:

```json
{
  "benchmark": {
    "timestamp": "2024-05-14T10:30:00Z",
    "input": {
      "count": 4,
      "resolution": "3840x2160",
      "format": "H.264"
    },
    "output_resolution": {
      "name": "8k",
      "width": 7680,
      "height": 4320
    },
    "metrics": {
      "fps": 30.5,
      "processing_time_per_frame_ms": 32.8,
      "total_duration_seconds": 120.5,
      "gstreamer_pipeline": "nvdec ! ... ! customstitch ! nvenc ! ..."
    },
    "system_info": {
      "os": {
        "name": "Linux",
        "version": "5.15.0-86-generic",
        "architecture": "x86_64"
      },
      "cpu": {
        "model": "Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz",
        "cores": 28
      },
      "memory": {
        "total_bytes": 137438917120
      },
      "gpu": [
        {
          "index": 0,
          "name": "NVIDIA GeForce RTX 3090",
          "driver_version": 515.65.01,
          "cuda_version": 11.7,
          "memory_total_mb": 24576
        }
      ],
      "gstreamer": {
        "version": "1.20.3"
      }
    }
  }
}
```

## Performance Metrics

The benchmark measures:
- **FPS**: Frames per second processed
- **Processing Time Per Frame**: Milliseconds to process each frame
- **Total Duration**: Actual time taken for the test run
- **GStreamer Pipeline**: Exact pipeline used for reference

## Custom Plugin Integration

1. Place your custom plugin binary in the `plugins/` directory
2. Ensure it's built for your system architecture
3. The installation script will set up the GStreamer plugin path

## Troubleshooting

### Common Issues

**NVIDIA plugins not found**:
- Verify NVIDIA drivers are installed: `nvidia-smi`
- Check CUDA toolkit version compatibility

**Video download failures**:
- Verify S3 bucket permissions
- Check internet connectivity
- Try with `--retry` flag on download script

**Performance issues**:
- Monitor GPU utilization with `nvidia-smi -l 1`
- Check CPU load during benchmark
- Ensure no other GPU-intensive processes are running

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

[Specify your license here]

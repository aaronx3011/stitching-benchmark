# GStreamer Stitching Benchmark - Quick Reference

## 🚀 Get Started in 3 Steps

### 1️⃣ Configure Your Setup
```bash
nano config.json
```
Update:
- `input.video_urls` with your S3 video links
- `custom_plugin.url` with your plugin download URL
- Adjust benchmark duration if needed

### 2️⃣ Test the Environment
```bash
./test_setup.sh
```
This checks all prerequisites and configuration.

### 3️⃣ Run Benchmarks!
```bash
./run_benchmark.sh
```
This does everything:
- Installs GStreamer with NVIDIA plugins ✓
- Downloads test videos ✓
- Runs benchmarks for all resolutions ✓
- Saves results in JSON format ✓

## 🎯 Common Commands

### Install Only
```bash
./install_gstreamer.sh
```

### Download Videos Only
```bash
./download_videos.sh
```

### Benchmark Single Resolution
```bash
./run_single_benchmark.sh 8k
# Try: 6k, 4k, 2k, or 1080p
```

### Check Results
```bash
ls -la results/
cat results/8k_*/metrics.json
```

Results now include detailed system information:
- OS, CPU, and memory specs
- GPU model, driver version, and CUDA version
- GStreamer version

## 📊 Expected Output Structure

```
results/
├── 8k_20240514_103000/
│   ├── metrics.json      # Performance data
│   └── output_8k.mkv     # Stitched video
├── 6k_20240514_103500/
│   ├── metrics.json
│   └── output_6k.mkv
└── ...
```

## 💡 Pro Tips

### Monitor GPU During Benchmark
```bash
watch -n 1 nvidia-smi
```

### Run Specific Resolution Multiple Times
```bash
for i in {1..3}; do ./run_single_benchmark.sh 8k; done
```

### Compare Results
```bash
jq '.benchmark.metrics.fps' results/*/metrics.json
```

## 📝 Need Help?

- Read `README.md` for detailed documentation
- Check `IMPLEMENTATION_SUMMARY.md` for technical details
- Run `./test_setup.sh` to diagnose issues

## ✅ Next Steps

1. Update `config.json` with your actual URLs
2. Run `./run_benchmark.sh`
3. Analyze results in the `results/` directory
4. Compare performance across resolutions

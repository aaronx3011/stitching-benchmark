#!/bin/bash
set -e

echo "=== Installing GStreamer with NVIDIA plugins ==="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Warning: Running as root. This is not recommended."
fi

# Detect OS and architecture
OS=""
ARCH=""

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    ARCH=$(uname -m)
else
    echo "Error: Could not detect Linux distribution"
    exit 1
fi

echo "Detected OS: $OS"
echo "Detected Architecture: $ARCH"

# Install dependencies based on OS
case $OS in
    ubuntu|debian)
        echo "Installing dependencies for Ubuntu/Debian..."
        sudo apt-get update
        sudo apt-get install -y \
            curl \
            wget \
            build-essential \
            git \
            pkg-config \
            libglib2.0-dev \
            libgstreamer1.0-dev \
            libgstreamer-plugins-base1.0-dev \
            gstreamer1.0-plugins-good \
            gstreamer1.0-plugins-bad \
            gstreamer1.0-plugins-ugly \
            gstreamer1.0-libav \
            libgstrtspserver-1.0-dev
        
        # Install NVIDIA drivers and CUDA if not present
        if ! nvidia-smi &> /dev/null; then
            echo "NVIDIA drivers not found. Please install them first."
            echo "You can install them from: https://www.nvidia.com/Download/index.aspx"
            exit 1
        fi
        
        # Install GStreamer NVIDIA plugins
        echo "Installing GStreamer NVIDIA plugins..."
        sudo apt-get install -y \
            gstreamer1.0-libav \
            gstreamer1.0-nice \
            gstreamer1.0-plugins-bad \
            gstreamer1.0-plugins-base \
            gstreamer1.0-plugins-good \
            gstreamer1.0-plugins-ugly \
            gstreamer1.0-tools \
            libgstrtspserver-1.0-0
        
        
        
        ;;
    centos|rhel)
        echo "Installing dependencies for CentOS/RHEL..."
        sudo yum install -y \
            epel-release \
            curl \
            wget \
            gcc \
            gcc-c++ \
            make \
            git \
            pkgconfig \
            glib2-devel \
            gstreamer1-devel \
            gstreamer1-plugins-base-devel \
            gstreamer1-plugins-good \
            gstreamer1-plugins-bad-free \
            gstreamer1-plugins-ugly-free \
            gstreamer1-libav
        
        # Install NVIDIA drivers and CUDA if not present
        if ! nvidia-smi &> /dev/null; then
            echo "NVIDIA drivers not found. Please install them first."
            exit 1
        fi
        
        # Install GStreamer NVIDIA plugins
        echo "Installing GStreamer NVIDIA plugins..."
        sudo yum install -y \
            gstreamer1-nvcodec \
            gstreamer1-nvtoolbox
        
        # Install OpenGL support
        echo "Installing OpenGL support..."
        sudo yum install -y \
            mesa-libGL-devel \
            mesa-libGLU-devel \
            freeglut-devel \
            mesa-libGLw-devel
        
        ;;
    *)
        echo "Error: Unsupported Linux distribution: $OS"
        exit 1
        ;;
esac

# Install custom plugin from config
if [ -f "config.json" ]; then
    PLUGIN_URL=$(jq -r '.custom_plugin.url' config.json)
    PLUGIN_PATH=$(jq -r '.custom_plugin.install_path' config.json)
    
    if [ -n "$PLUGIN_URL" ] && [ "$PLUGIN_URL" != "null" ]; then
        echo "Downloading custom plugin from $PLUGIN_URL..."
        mkdir -p "$PLUGIN_PATH"
        wget -O "${PLUGIN_PATH}/libgldmdstitcher.so" "$PLUGIN_URL"
        
        # Make plugin executable
        chmod +x "${PLUGIN_PATH}"/*.so

        # Install to system GStreamer plugins directory
        sudo cp "${PLUGIN_PATH}/libgldmdstitcher.so" /usr/lib/x86_64-linux-gnu/gstreamer-1.0/
    fi
fi

# Set up GStreamer plugin path
export GST_PLUGIN_PATH="${PLUGIN_PATH}:${GST_PLUGIN_PATH}"
echo "GStreamer plugin path set to: $GST_PLUGIN_PATH"

# Verify installation
echo "Verifying GStreamer installation..."
gst-inspect-1.0 --version

# Check for NVIDIA plugins
echo "Checking for NVIDIA plugins..."
gst-inspect-1.0 | grep -i nvidia || echo "Warning: No NVIDIA plugins found"

# Check for OpenGL support
echo "Checking for OpenGL support..."
gst-inspect-1.0 | grep -i opengl || echo "Warning: No OpenGL plugins found"

echo "GStreamer installation completed successfully!"

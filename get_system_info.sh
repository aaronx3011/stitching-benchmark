#!/bin/bash

# Function to get system information
get_system_info() {
    local info=""
    
    # OS Information
    info+="{\"os\": {"
    info+="  \"name\": \"$(uname -s)\","
    info+="  \"version\": \"$(uname -r)\","
    info+="  \"architecture\": \"$(uname -m)\""
    
    # CPU Information
    if command -v lscpu &> /dev/null; then
        CPU_MODEL=$(lscpu | grep "Model name" | awk -F': ' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
        CPU_CORES=$(lscpu | grep "^CPU(s)" | awk '{print $2}')
        info+=",\"cpu\": {\"model\": \"$CPU_MODEL\", \"cores\": $CPU_CORES}"
    else
        info+=",\"cpu\": {\"model\": \"$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")\", \"cores\": $(sysctl -n hw.ncpu 2>/dev/null || echo "1")}"
    fi
    
    # Memory Information
    if command -v free &> /dev/null; then
        TOTAL_MEM=$(free -b | awk '/^Mem:/ {print $2}')
        info+=",\"memory\": {\"total_bytes\": $TOTAL_MEM}"
    elif command -v sysctl &> /dev/null; then
        TOTAL_MEM=$(sysctl -n hw.memsize)
        info+=",\"memory\": {\"total_bytes\": $TOTAL_MEM}"
    else
        info+=",\"memory\": {\"total_bytes\": 0}"
    fi
    
    # NVIDIA GPU Information
    if command -v nvidia-smi &> /dev/null; then
        info+=",\"gpu\": ["
        
        local gpus=$(nvidia-smi --query-gpu=index,name,driver_version,cuda_version,memory.total --format=csv,noheader,nounits)
        local first=true
        while IFS=',' read -r index name driver cuda mem; do
            if [ ! "$first" ]; then
                info+=","
            fi
            first=false
            info+="{\"index\": $index, \"name\": \"$name\", \"driver_version\": \"$driver\", \"cuda_version\": \"$cuda\", \"memory_total_mb\": $mem}"
        done <<< "$gpus"
        
        info+="]"
    else
        info+=",\"gpu\": []"
    fi
    
    # GStreamer Information
    if command -v gst-inspect-1.0 &> /dev/null; then
        GST_VERSION=$(gst-inspect-1.0 --version | awk '{print $3}')
        info+=",\"gstreamer\": {\"version\": \"$GST_VERSION\"}"
    else
        info+=",\"gstreamer\": {\"version\": \"Not installed\"}"
    fi
    
    info+="}}"
    echo "$info"
}

# Call the function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_system_info
fi
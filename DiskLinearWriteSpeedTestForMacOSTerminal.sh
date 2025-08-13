#!/bin/zsh

TEST_FILE="disk_benchmark_temp_file.tmp"
RAW_DATA_LOG="benchmark_data_raw.log"
FITTED_DATA_LOG="benchmark_data_fitted.log"
BLOCK_SIZE="1048576"

install_dependencies() {
    echo "⚙️  正在检查并安装依赖项..."
    
    # 检查并安装 Homebrew
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew 未安装。正在尝试自动安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ $? -ne 0 ]; then
            echo "❌ 自动安装 Homebrew 失败。请手动安装后再运行此脚本。"
            exit 1
        fi
        echo "✅ Homebrew 安装成功。"
    fi
    
    # 检查并安装 gnuplot
    if ! command -v gnuplot &> /dev/null; then
        echo "❌ gnuplot 未安装。正在使用 Homebrew 安装..."
        brew install gnuplot
        if [ $? -ne 0 ]; then
            echo "❌ 安装 gnuplot 失败。请检查 Homebrew 配置。"
            exit 1
        fi
        echo "✅ gnuplot 安装成功。"
    fi

    echo "✅ 所有依赖项已准备就绪。"
}

get_time() {
    gdate +%s.%N 2>/dev/null || date +%s.%N || date +%s
}

# --- 主程序开始 ---
clear
echo "==================================================="
echo "    macOS 硬盘写入性能一键测试工具 (v1.0)    "
echo "==================================================="

install_dependencies

echo "---------------------------------------------------"

# 获取硬盘设备标识
disk_device=$(df . | tail -1 | awk '{print $1}' | sed 's/s[0-9]*$//' | sed 's/s[0-9]*p[0-9]*$//')

if [ -z "$disk_device" ]; then
    echo "❌ 无法确定当前硬盘的设备标识符。"
    exit 1
fi
echo "🎯 将在设备 $disk_device 上进行测试。"
echo "---------------------------------------------------"

# 用户输入测试名称和文件大小
read -p "请输入本次测试的名称 (例如: Samsung_T7_Test): " test_name
read -p "请输入要创建的测试文件大小 (GB): " file_size_gb
if ! [[ "$file_size_gb" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "❌ 错误：请输入一个有效的数字。"
    exit 1
fi

# 初始化变量和文件
count=$(echo "$file_size_gb * 1024" | bc | cut -d. -f1)
last_size=0
start_time=$(get_time)
last_time=$start_time

[ -f "$TEST_FILE" ] && rm -f "$TEST_FILE"
[ -f "$RAW_DATA_LOG" ] && rm -f "$RAW_DATA_LOG"
[ -f "$FITTED_DATA_LOG" ] && rm -f "$FITTED_DATA_LOG"

# 开始写入测试
echo "🚀 测试开始：正在写入一个 ${file_size_gb}GB 的文件..."
echo "测试文件: $(pwd)/${TEST_FILE}"

dd if=/dev/zero of="$TEST_FILE" bs="$BLOCK_SIZE" count="$count" &> /dev/null &
dd_pid=$!

echo "# Time(s) Speed(MB/s)" > "$RAW_DATA_LOG"
printf "%-10s | %-15s\n" "时间 (秒)" "速度 (MB/s)"
printf "------------------------------\n"

# 监控循环
while kill -0 "$dd_pid" 2>/dev/null; do
    current_size=$(stat -f %z "$TEST_FILE" 2>/dev/null || stat -c %s "$TEST_FILE" 2>/dev/null)
    current_time=$(get_time)
    time_diff=$(echo "$current_time - $last_time" | bc)
    size_diff=$(echo "$current_size - $last_size" | bc)

    if (( $(echo "$time_diff > 0.001" | bc -l) )); then
        speed=$(echo "scale=2; $size_diff / $time_diff / 1024 / 1024" | bc)
        elapsed_seconds=$(printf "%.3f" $(echo "$current_time - $start_time" | bc))
        printf -- "\r%-10s | %-15s" "$elapsed_seconds" "$speed"
        echo "$elapsed_seconds $speed" >> "$RAW_DATA_LOG"
        last_size=$current_size
        last_time=$current_time
    fi
    sleep 0.001
done

wait "$dd_pid"
echo "\n--------------------------------------------------"
echo "✅ 文件写入完成。"

# 数据拟合与统计
echo "📈 正在分析和拟合数据..."
if [ $(grep -v '#' "$RAW_DATA_LOG" | wc -l) -lt 2 ]; then
    echo "❌ 数据记录失败，未能收集到足够的数据。"
    rm -f "$RAW_DATA_LOG"
    exit 1
fi

# 数据拟合（0.1s 平均值）
awk '
    BEGIN {
        sum_speed = 0;
        count = 0;
        current_time_group = 0.1;
    }
    !/^#/ {
        time = $1;
        speed = $2;
        
        while (time >= current_time_group) {
            if (count > 0) {
                printf "%.2f %.2f\n", current_time_group - 0.05, sum_speed / count;
            }
            sum_speed = 0;
            count = 0;
            current_time_group += 0.1;
        }
        sum_speed += speed;
        count++;
    }
    END {
        if (count > 0) {
            printf "%.2f %.2f\n", current_time_group - 0.05, sum_speed / count;
        }
    }
' "$RAW_DATA_LOG" > "$FITTED_DATA_LOG"

# 计算总体的平均值、最大值和最小值
awk_results=$(awk '
    BEGIN {sum=0; count=0; min=1e100; max=-1e100}
    !/^#/ {
        speed = $2;
        if (speed > max) max = speed;
        sum += speed;
        count++;
        
        # 仅在时间大于0.05秒后才开始计算最低速度
        if ($1 > 0.05) {
            if (speed < min) min = speed;
        }
    }
    END {
        if (count > 0) {
            printf "%.2f %.2f %.2f", sum/count, max, min;
        }
    }
' "$RAW_DATA_LOG")

avg_speed=$(echo "$awk_results" | awk '{print $1}')
peak_speed=$(echo "$awk_results" | awk '{print $2}')
min_speed=$(echo "$awk_results" | awk '{print $3}')

# 清理临时文件
echo "🧹 正在清理临时文件..."
rm -f "$TEST_FILE"
echo "✅ 清理完毕。"
echo "---------------------------------------------------"

# 生成图表
output_image="${test_name// /_}.png"
echo "🎨 正在生成图表: $output_image"

gnuplot <<- EOF
    set terminal pngcairo size 1600,900 font "Arial,12"
    set output '$output_image'
    
    set title "硬盘写入性能测试 - ${test_name}\n平均速度: ${avg_speed} MB/s | 峰值速度: ${peak_speed} MB/s | 最低速度: ${min_speed} MB/s"
    set xlabel "时间 (秒)"
    set ylabel "写入速度 (MB/s)"
    
    set xrange [0:*]
    set xtics auto
    set ytics nomirror
    
    set grid
    set key top left
    set border 3
    set style data lines
    
    plot '$FITTED_DATA_LOG' using 1:2 with linespoints title "速度" lw 2 lc rgb "#0072B2"
EOF

# 清理日志文件
rm -f "$RAW_DATA_LOG"
rm -f "$FITTED_DATA_LOG"

if [ -f "$output_image" ] && [ $(stat -f %z "$output_image") -gt 0 ]; then
    echo "🎉 图表生成成功！已保存为: $(pwd)/$output_image"
else
    echo "❌ 生成图表失败。请检查 gnuplot 输出信息。"
fi

echo "==================================================="
echo "            测试已完成。           "
echo "==================================================="
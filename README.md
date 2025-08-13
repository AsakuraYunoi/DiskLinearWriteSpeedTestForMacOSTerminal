# DiskLinearWriteSpeedTestForMacOSTerminal

### 适用于 macOS 的全盘写入性能测试工具

这是一个专为 macOS 设计的终端脚本，用于全面测试磁盘的写入性能和稳定性。

该工具能够：

  * **全盘写入测试**：模拟真实场景，测试整个磁盘的写入稳定性。
  * **详细性能报告**：自动生成包含**平均值**、**峰值**和**最低值**的详细性能数据。
  * **可视化折线图**：通过 **gnuplot** 绘制直观的速度变化折线图，让你清晰地看到性能波动。
  * **一键启动**：脚本会自动检测并安装所有必需的依赖项（**Homebrew** 和 **gnuplot**），让你无需手动配置。

-----

## 💻 使用方法

**请确保您的 Mac 连接到稳定的网络，以便自动安装所需的依赖项。**

1.  **导航到目标目录**：打开终端，使用 `cd` 命令进入你想要测试的硬盘或分区的目录。

    ```bash
    cd /Volumes/你的磁盘名称
    ```

2.  **一键运行脚本**：在终端中粘贴并执行以下命令即可启动测试。

    ```bash
    curl -sS https://raw.githubusercontent.com/AsakuraYunoi/DiskLinearWriteSpeedTestForMacOSTerminal/main/DiskLinearWriteSpeedTestForMacOSTerminal.sh | bash
    ```

3.  **按照提示操作**：脚本启动后会显示提示信息，请根据提示完成后续步骤。

-----


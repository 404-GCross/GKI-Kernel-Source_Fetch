# Kernel-Source_Pull

**自动化拉取 GKI 内核源码**

[![GitHub Release](https://img.shields.io/github/v/release/404-GCross/Kernel-Source_Pull?style=flat-square)](https://github.com/404-GCross/Kernel-Source_Pull/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)

---

## 📖 项目简介

本项目基于 [GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 项目修改而来，将其内核构建流程简化为 **内核源码拉取** 。


---

## 🚀 快速开始

在 Linux 机器上运行以下命令即可拉取内核源码：

### 方式一：直连 GitHub

```bash
bash <(curl -sSL https://github.com/404-GCross/Kernel-Source_Pull/releases/download/all-kernel-sources-1/fetch_kernel_source.sh)

### 方式二：GitHub 镜像源

```bash
bash <(curl -sSL https://gh.ddlc.top/https://github.com/404-GCross/Kernel-Source_Pull/releases/download/all-kernel-sources-1/fetch_kernel_source.sh)

# Kernel-Source_Pull

**自动化拉取 GKI 内核源码 | 基于 GKI_KernelSU_SUSFS 项目修改**

[![GitHub Release](https://img.shields.io/github/v/release/404-GCross/Kernel-Source_Pull?style=flat-square)](https://github.com/404-GCross/Kernel-Source_Pull/releases)
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg?style=flat-square)](LICENSE)

---

## 📖 项目简介

本项目基于 [GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 项目修改而来，将其内核构建流程简化为 **GKI源码拉取与发布** 工具。

原项目是一个自动化构建 GKI 内核的项目，集成了 KernelSU / MKSU / SukiSU / ReSukiSU / KernelSU-Next + SUSFS 等特性，并支持 Droidspaces 容器、ZRAM 增强、BBG 防格机等功能。本 Fork 项目专注于 **一键拉取 Google 官方 GKI 内核源码**，并将其打包发布至 GitHub Release，方便开发者直接下载使用。

---

## 🚀 快速开始

在 Linux 机器上运行以下命令即可从release中拉取内核源码到本地：


方式一：直连 GitHub
```bash
bash <(curl -sSL https://github.com/404-GCross/Kernel-Source_Pull/releases/download/all-kernel-sources-1/fetch_kernel_source.sh)
```
方式二：镜像加速（国内推荐，直连失败时使用）
```bash
bash <(curl -sSL https://gh.ddlc.top/https://github.com/404-GCross/Kernel-Source_Pull/releases/download/all-kernel-sources-1/fetch_kernel_source.sh)
```

## 📥 下载源码包

所有 GKI 内核源码分卷均可在 Releases 页面 直接下载。

## 🛠 脚本功能

交互式脚本提供以下功能：

版本选择：支持 Android 12 ~ 16，内核版本 5.10 / 5.15 / 6.1 / 6.6 / 6.12

镜像加速：内置多个国内可用的 GitHub 镜像源

测速择优：自动测试各镜像下载速度，按速度排序供选择

自定义镜像：支持手动输入任意镜像 URL

自动校验：下载后自动 SHA256 校验，确保文件完整性

合并解压：将分卷文件合并为一个完整的 tar.gz 包并解压

## 📊 支持的内核版本
Android 12	5.10	66 / 81 / 101 / 110 / 198 / 246 等 22 个版本

Android 13	5.15	74 / 78 / 94 / 104 / 170 / 194 等 20 个版本

Android 14	6.1	25 / 43 / 57 / 68 / 129 / 162 等 23 个版本

Android 15	6.6	50 / 56 / 57 / 58 / 77 / 127 等 15 个版本

Android 16	6.12	23 / 30 / 38 / 58

包含 lts 长期支持版本（小版本号标记为 X）。

## 🔗 相关链接
原项目：[GKI_KernelSU_SUSFS - 自动化构建 GKI 内核 | 集成 KernelSU + SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS)



## 📄 License
本项目基于 GNU General Public License v2.0 开源。详见 LICENSE 文件。

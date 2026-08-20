# GKI-Kernel-Source_Fetch

**自动化拉取 GKI 内核源码 | 基于 GKI_KernelSU_SUSFS 项目修改**

[![GitHub Release](https://img.shields.io/github/v/release/404-GCross/Kernel-Source_Pull?style=flat-square)](https://github.com/404-GCross/Kernel-Source_Pull/releases)
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg?style=flat-square)](LICENSE)

---

## 📖 项目简介

本项目基于 [GKI_KernelSU_SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS) 项目修改而来，将其内核构建流程简化为 **GKI源码拉取与发布** 工具。

原项目是一个自动化构建 GKI 内核的项目，集成了 KernelSU / MKSU / SukiSU / ReSukiSU / KernelSU-Next + SUSFS 等特性，并支持 Droidspaces 容器、ZRAM 增强、BBG 防格机等功能。本 Fork 项目专注于 **一键拉取 Google 官方 GKI 内核源码**，并将其打包发布至 GitHub Release，方便开发者直接下载使用。

一键拉取全部完整源码：手动触发后会按 `data/` 中记录的全部版本拉取完整 AOSP kernel manifest 工作树，并分包推送到 Release。

---

## 🚀 快速开始

在 Linux 机器上运行以下命令即可从release中拉取内核源码到本地：

脚本启动后的第一步会选择语言（中文 / English）。如需在自动化环境中跳过语言选择，可设置 `SCRIPT_LANG=zh` 或 `SCRIPT_LANG=en`。

方式一：直连 GitHub
```bash
bash <(curl -sSL https://raw.githubusercontent.com/404-GCross/Kernel-Source_Pull/refs/heads/main/fetch_kernel_source.sh)
```
如果不想要解压
```bash
bash <(curl -sSL https://raw.githubusercontent.com/404-GCross/Kernel-Source_Pull/refs/heads/main/fetch_kernel_source_no-extract.sh)
```
方式二：镜像加速（国内推荐，直连失败时使用）
```bash
bash <(curl -sSL https://gh-proxy.com/https://raw.githubusercontent.com/404-GCross/Kernel-Source_Pull/refs/heads/main/fetch_kernel_source.sh)
```
如果不想要解压
```bash
bash <(curl -sSL https://gh-proxy.com/https://raw.githubusercontent.com/404-GCross/Kernel-Source_Pull/refs/heads/main/fetch_kernel_source_no-extract.sh)
```

脚本使用deepseek生成，测试暂无问题，有问题欢迎反馈

## 📥 下载源码包

所有 GKI 内核源码分卷均可在 Releases 页面 直接下载。

## ⚙️ Actions 分工

- `一键拉取全部完整源码并推送 Release`：手动触发，按 `data/` 中记录的全部版本拉取完整 AOSP kernel manifest 工作树（源码、构建脚本、prebuilts/toolchain 等），压缩分卷后上传到指定 GitHub Release。
- 一键全量 Release 上传完成后，会自动更新 `fetch_kernel_source.sh` 与 `fetch_kernel_source_no-extract.sh` 中的 `REPO` / `TAG`，让下载脚本指向最新 Release。
- `完整源码环境分包发布` / `完整源码环境发布-*` / `完整源码环境发布-自定义`：手动触发单个版本或单个 Android/kernel 系列，拉取完整源码环境并上传 Release，方便补包或重跑失败版本。
- `每月同步内核源码目录 (common/)`：唯一仅获取 `common/` 内核源码目录的 workflow，可手动触发，也会每月 1 日自动执行并推送到对应分支。

## 🛠 脚本功能

交互式脚本提供以下功能：

版本选择：支持 Android 12 ~ 17，内核版本 5.10 / 5.15 / 6.1 / 6.6 / 6.12 / 6.18

镜像加速：内置多个国内可用的 GitHub 镜像源

测速择优：自动测试各镜像下载速度，按速度排序供选择

自定义镜像：支持手动输入任意镜像 URL

自动校验：下载后自动 SHA256 校验，确保文件完整性

合并解压：将分卷文件合并为一个完整的 tar.gz 包并解压

## 📊 支持的内核版本
Android 12	5.10	43 / 66 / 81 / 101 / 198 / 246 / 256 等版本

Android 13	5.15	41 / 74 / 78 / 94 / 170 / 194 / 207 等版本

Android 14	6.1	25 / 43 / 57 / 68 / 129 / 162 / 172 / 173 等版本

Android 15	6.6	50 / 56 / 57 / 58 / 77 / 127 / 139 等版本

Android 16	6.12	23 / 30 / 38 / 58 / 69 / 81 等版本

Android 17	6.18	21 等版本

包含 LTS 长期支持版本（小版本号标记为 X），当前数据记录的 LTS 为 5.10.264 / 5.15.211 / 6.1.176 / 6.6.142 / 6.12.92 / 6.18.32。

## 🔗 相关链接
原项目：[GKI_KernelSU_SUSFS - 自动化构建 GKI 内核 | 集成 KernelSU + SUSFS](https://github.com/zzh20188/GKI_KernelSU_SUSFS)



## 📄 License
本项目基于 GNU General Public License v2.0 开源。详见 LICENSE 文件。

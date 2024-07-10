# aurumOS live image generator and installer

## Overview

This repository contains several utilities:

* [*mklive.sh*](#mklivesh) - The Void Linux live image generator for x86
* [*build-x86-images.sh*](#build-x86-imagessh) - Wrapper script to generate bootable
  and installable live images for x86
* [*mkrootfs.sh*](#mkrootfssh) - The Void Linux rootfs generator for all platforms
* [*mkplatformfs.sh*](#mkplatformfssh) - The Void Linux filesystem tool to produce
  a rootfs for a particular platform
* [*mkimage.sh*](#mkimagesh) - The Void Linux image generator for ARM platforms
* [*mknet.sh*](#mknetsh) - Script to generate netboot tarballs for Void
* *installer.sh* - The Void Linux el-cheapo installer for x86
* *release.sh* - interacts with GitHub CI to generate and sign images for releases

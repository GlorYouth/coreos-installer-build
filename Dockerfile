# =========================================================================
# STAGE 1: Builder - 使用 rust:alpine 作为构建环境
#
# 这个阶段负责编译 Rust 项目。它现在支持多架构构建。
# =========================================================================
FROM rust:alpine AS builder

# 声明 TARGETARCH 构建参数。
# 这是由 Docker BuildKit 自动提供的，用于识别目标架构 (例如 'amd64', 'arm64')。
ARG TARGETARCH

# 1. 安装构建依赖
# 增加了 zstd-static 和 openssl-static 以支持静态链接
# - git: 用于从 GitHub 克隆源代码。
# - build-base: 包含了 gcc, make 等基础编译工具。
# - pkgconf: 是 Alpine 下的 pkg-config 实现。
# - openssl-dev & zstd-dev: 提供动态库和头文件。
# - zstd-static & openssl-static: 提供静态库 (.a 文件) 以供链接器使用。
# - clang: 用于 C/C++ 代码的编译，通常与 Rust 配合良好。
RUN apk add --no-cache git build-base clang pkgconf openssl-dev zstd-dev zstd-static openssl-static

# 2. 设置工作目录
WORKDIR /usr/src/app

# 3. 设置环境变量以进行优化和静态链接
# 这些变量对于所有架构都是通用的。
ENV CARGO_PROFILE_RELEASE_OPT_LEVEL="z" \
    CARGO_PROFILE_RELEASE_LTO="fat" \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS="1" \
    CARGO_PROFILE_RELEASE_PANIC="abort" \
    CARGO_PROFILE_RELEASE_STRIP="symbols" \
    OPENSSL_STATIC="1" \
    ZSTD_SYS_STATIC="1" \
    RUSTFLAGS="-C target-feature=+crt-static"

# 4. 从 GitHub 克隆源代码
# `--depth 1` 表示只拉取最近一次提交，以减小体积。
# `.` 表示将仓库内容克隆到当前工作目录 (/usr/src/app)。
RUN git clone --depth 1 https://github.com/coreos/coreos-installer.git .

# 5. 根据目标架构编译项目
# 这个单一的 RUN 指令处理了所有与架构相关的逻辑。
RUN set -eux; \
    # 根据 $TARGETARCH 设置 Rust 编译目标变量
    case ${TARGETARCH} in \
        "amd64") RUST_TARGET="x86_64-unknown-linux-musl" ;; \
        "arm64") RUST_TARGET="aarch64-unknown-linux-musl" ;; \
        *) echo "不支持的架构: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    # 安装对应的 Rust 目标工具链
    echo "为 ${TARGETARCH} 安装 Rust 目标: ${RUST_TARGET}"; \
    rustup target add ${RUST_TARGET}; \
    \
    # 执行编译
    cargo build --locked --release --target ${RUST_TARGET}; \
    \
    # 将编译产物移动到一个固定的、与架构无关的路径，方便下一阶段拷贝
    cp "target/${RUST_TARGET}/release/coreos-installer" /usr/local/bin/final-binary;

# =========================================================================
# STAGE 2: Final - 创建最终的轻量级镜像
#
# 这个阶段保持不变，但现在可以接收来自不同架构构建的产物。
# =========================================================================
FROM alpine:latest

# 为二进制文件设置一个标签，方便识别其来源
LABEL maintainer="GlorYouth <admin@gloryouth.com>" \
      description="Statically compiled coreos-installer for multi-arch (x86_64, aarch64) from git"

# 从 builder 阶段的固定路径拷贝编译好的可执行文件。
# 这个命令现在是与架构无关的。
COPY --from=builder /usr/local/bin/final-binary /usr/local/bin/coreos-installer

# 设置当容器启动时要执行的默认命令。
ENTRYPOINT ["coreos-installer"]

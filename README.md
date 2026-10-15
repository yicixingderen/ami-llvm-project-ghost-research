# LLVM Compiler with Control-Flow Linearization using Architectural Mimicry (AMi)

[English](#english) | [中文](#中文)

## English

This repository is an LLVM 16 fork for the AMi (Architectural Mimicry) hardware-software countermeasure. It adds secrecy labels in Clang and automatic control-flow linearization in the RISC-V backend. The research change models a Ghost load as a store-forward-only operation: the encoded `rd` field is preserved and the Ghost value is represented as an input operand in MachineInstr. The change matches the companion [AMi hardware research fork](https://github.com/yicixingderen/ami-ghost-research).

The current research branch is based on commit `f160e224b5f040b340b3ae0693b41dacc0458ef0` and includes the regression test [`llvm/test/CodeGen/RISCV/ami-ghost-store-forward.ll`](llvm/test/CodeGen/RISCV/ami-ghost-store-forward.ll). The original AMi architecture is described in the [IEEE S&P 2024 paper](https://mici.hu/papers/winderix24ami.pdf), and the control-flow-linearization design is described in [Daan Vanoverloop's thesis](https://daan.vanoverloop.xyz/masters-thesis-ami-pcfl.pdf).

### Reproducible build and installation

The supported path below was written for a fresh 64-bit Ubuntu 22.04 or later installation. The Makefile builds only the LLVM, Clang, and LLD projects for the RISC-V target and installs them into this repository's `install/` directory.

#### 1. Install host dependencies

```sh
sudo apt-get update
sudo apt-get install -y \
  git make build-essential cmake ninja-build clang lld python3 \
  zlib1g-dev libzstd-dev libxml2-dev
```

The bootstrap compiler is the system `clang`/`clang++`; the Makefile uses those names explicitly. Check them before configuring:

```sh
clang --version
clang++ --version
cmake --version
ninja --version
```

#### 2. Checkout a fixed source revision

```sh
git clone --filter=blob:none \
  https://github.com/yicixingderen/ami-llvm-project-ghost-research.git
cd ami-llvm-project-ghost-research
git checkout 3e026d4c63a3ab15db1455784b73fdd773288122
```

#### 3. Configure, build, and install

```sh
make JOBS="$(nproc)" configure-build
make JOBS="$(nproc)" build
make install
```

The default build type is `Debug`, the generator is Ninja, and the install prefix is `./install`. For a smaller optimized build, use `BUILD_TYPE=Release` consistently for both `configure-build` and `build`. The resulting tools include `install/bin/clang`, `install/bin/llc`, `install/bin/ld.lld`, `install/bin/llvm-objcopy`, and `install/bin/llvm-nm`.

```sh
export PATH="$PWD/install/bin:$PATH"
clang --version
llc --version
```

#### 4. Run the focused regression test

```sh
build/llvm/bin/llvm-lit -v llvm/test/CodeGen/RISCV/ami-ghost-store-forward.ll
```

The test checks that AMi linearization emits an `ADDI`, a Ghost load, and the directly dependent store, without a second ordinary Ghost-load definition. The AMi options used by the test are:

| Option | Default | Purpose |
| --- | --- | --- |
| `-riscv-enable-ami-linearization` | `false` | Enable AMi control-flow linearization. |
| `-riscv-enable-molnar-linearization` | `false` | Enable Molnar-style linearization. |
| `-riscv-ami-general-linearization` | `false` | Linearize general reducible control flow when AMi is enabled. |

#### 5. Compile an annotated program

Use `clang::annotate_type("secret")` for secret values and pass the AMi options explicitly:

```sh
cat >/tmp/ami-example.c <<'EOF'
#define _secret_ [[clang::annotate_type("secret")]]

static int v;

[[clang::noinline, clang::mimicable]]
static void foo(int i) {
  v += i;
}

int _secret_ ifthenloop(int _secret_ a, int b) {
  v = 0;
  if (a < b) {
    int i;
    #pragma clang loop unroll(disable)
    for (i = 0; i < 3; i++)
      foo(i);
  }
  return v;
}

int main(void) {
  (void)ifthenloop(1, 2);
  (void)ifthenloop(2, 1);
  return 0;
}
EOF

install/bin/clang -nostdlib -O3 --target=riscv32 -march=rv32im -std=c2x \
  -mllvm -riscv-enable-ami-linearization=true \
  -mllvm -riscv-ami-general-linearization=true \
  -S /tmp/ami-example.c -o /tmp/ami-example.s
```

The same options can be passed to `llc` when starting from LLVM IR:

```sh
install/bin/llc -march=riscv32 \
  -riscv-enable-ami-linearization=true \
  -riscv-ami-general-linearization=true \
  example.ll -o example.s
```

For the complete annotated C example, see the original AMi compiler README history or the source and test files linked above. General LLVM build details are maintained in the [official Getting Started guide](https://llvm.org/docs/GettingStarted.html).

## 中文

本仓库是面向 AMi（Architectural Mimicry，架构拟态）软硬件协同防护机制的 LLVM 16 分支，包含 Clang 保密性标签和 RISC-V 后端的自动控制流线性化。本研究分支将 Ghost load 建模为只向 store 转发的操作：保留编码中的 `rd` 字段，并在 MachineInstr 中将 Ghost 值作为输入操作数处理。该行为与配套的 [AMi 硬件研究分支](https://github.com/yicixingderen/ami-ghost-research)保持一致。

当前研究代码基于提交 `f160e224b5f040b340b3ae0693b41dacc0458ef0`，并包含回归测试 [`llvm/test/CodeGen/RISCV/ami-ghost-store-forward.ll`](llvm/test/CodeGen/RISCV/ami-ghost-store-forward.ll)。原始 AMi 架构见 [IEEE S&P 2024 论文](https://mici.hu/papers/winderix24ami.pdf)，控制流线性化设计见 [Daan Vanoverloop 的论文](https://daan.vanoverloop.xyz/masters-thesis-ami-pcfl.pdf)。

### 可复现的构建与安装

以下步骤适用于全新的 64 位 Ubuntu 22.04 或更高版本环境。Makefile 只构建面向 RISC-V 的 LLVM、Clang 和 LLD，并把结果安装到本仓库的 `install/` 目录。

#### 1. 安装主机构建依赖

```sh
sudo apt-get update
sudo apt-get install -y \
  git make build-essential cmake ninja-build clang lld python3 \
  zlib1g-dev libzstd-dev libxml2-dev
```

Makefile 明确使用主机上的 `clang`/`clang++` 作为引导编译器。配置前请检查：

```sh
clang --version
clang++ --version
cmake --version
ninja --version
```

#### 2. 获取固定版本源码

```sh
git clone --filter=blob:none \
  https://github.com/yicixingderen/ami-llvm-project-ghost-research.git
cd ami-llvm-project-ghost-research
git checkout 3e026d4c63a3ab15db1455784b73fdd773288122
```

#### 3. 配置、构建并安装

```sh
make JOBS="$(nproc)" configure-build
make JOBS="$(nproc)" build
make install
```

默认构建类型为 `Debug`，生成器为 Ninja，安装前缀为 `./install`。如果需要较小的优化版本，请在 `configure-build` 和 `build` 两步都使用 `BUILD_TYPE=Release`。构建结果包括 `install/bin/clang`、`install/bin/llc`、`install/bin/ld.lld`、`install/bin/llvm-objcopy` 和 `install/bin/llvm-nm`。

```sh
export PATH="$PWD/install/bin:$PATH"
clang --version
llc --version
```

#### 4. 运行定向回归测试

```sh
build/llvm/bin/llvm-lit -v llvm/test/CodeGen/RISCV/ami-ghost-store-forward.ll
```

该测试检查 AMi 线性化是否生成 `ADDI`、Ghost load 和紧邻的依赖 store，同时不再生成第二个普通 Ghost-load 定义。测试使用的 AMi 选项如下：

| 选项 | 默认值 | 作用 |
| --- | --- | --- |
| `-riscv-enable-ami-linearization` | `false` | 启用 AMi 控制流线性化。 |
| `-riscv-enable-molnar-linearization` | `false` | 启用 Molnar 风格线性化。 |
| `-riscv-ami-general-linearization` | `false` | AMi 启用时线性化一般可约控制流。 |

#### 5. 编译带标注的程序

保密数据使用 `clang::annotate_type("secret")` 标注，并显式传入 AMi 选项：

```sh
cat >/tmp/ami-example.c <<'EOF'
#define _secret_ [[clang::annotate_type("secret")]]

static int v;

[[clang::noinline, clang::mimicable]]
static void foo(int i) {
  v += i;
}

int _secret_ ifthenloop(int _secret_ a, int b) {
  v = 0;
  if (a < b) {
    int i;
    #pragma clang loop unroll(disable)
    for (i = 0; i < 3; i++)
      foo(i);
  }
  return v;
}

int main(void) {
  (void)ifthenloop(1, 2);
  (void)ifthenloop(2, 1);
  return 0;
}
EOF

install/bin/clang -nostdlib -O3 --target=riscv32 -march=rv32im -std=c2x \
  -mllvm -riscv-enable-ami-linearization=true \
  -mllvm -riscv-ami-general-linearization=true \
  -S /tmp/ami-example.c -o /tmp/ami-example.s
```

如果输入的是 LLVM IR，也可以直接调用 `llc`：

```sh
install/bin/llc -march=riscv32 \
  -riscv-enable-ami-linearization=true \
  -riscv-ami-general-linearization=true \
  example.ll -o example.s
```

完整的带标注 C 示例见原始 AMi 编译器 README 历史版本以及上面链接的源码和测试文件。通用 LLVM 构建说明见[官方 Getting Started 文档](https://llvm.org/docs/GettingStarted.html)。

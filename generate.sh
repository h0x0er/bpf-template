#!/bin/bash

PROJECT_NAME="$1"
WORK_DIR="${2:-$PWD}"

ROOT="$WORK_DIR/$PROJECT_NAME"
BPF_ROOT="$ROOT/bpf"
GO_PKG="$ROOT/pkg"

BPF_INCLUDES="$BPF_ROOT/includes"
BPF_LIB="$BPF_ROOT/lib"
BPF_GEN="$GO_PKG/bpfgen"

SCRIPTS="$ROOT/scripts"
DOCS="$ROOT/docs"

VMLINUX="$BPF_ROOT/includes/vmlinux.h"
BPF_MAIN="$BPF_ROOT/$PROJECT_NAME.c"

log() {
    printf "$(date) [%s] %s\n" "$1" "$2"
}

log "info" "workdir=$WORK_DIR project_name=$PROJECT_NAME"

template_bpfgen="package bpfgen\n
//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -target amd64,arm64 Bpf ../../bpf/$PROJECT_NAME.c -- -I../../bpf/includes -I../../bpf/lib
\n"

template_common_h="#if !defined(__COMMON_H__)
#define __COMMON_H__

#include \"vmlinux.h\"
#include <bpf/bpf_core_read.h>
#include <bpf/bpf_endian.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

#define FUNC_INLINE static __always_inline

#endif // __COMMON_H__
"

template_bpf_main="#include \"common.h\"

char __license[] SEC(\"license\") = \"Dual MIT/GPL\";
"

template_gen_sh="#!/bin/bash

set -x
cd pkg/bpfgen && go generate .
"

template_configure_sh="#!/bin/bash

sudo apt-get update
sudo apt-get install --yes build-essential pkgconf libelf-dev libbpf-dev llvm-14 clang-14 linux-tools-common linux-tools-generic
for tool in \"clang\" \"llc\" \"llvm-strip\"; do
    sudo rm -f /usr/bin/\$tool
    sudo ln -s /usr/bin/\$tool-14 /usr/bin/\$tool
done
"

gen-paths() {

    log "info" "creating subfolders"

    mkdir -p "$BPF_ROOT"
    mkdir -p "$BPF_INCLUDES"
    mkdir -p "$BPF_LIB"

    mkdir -p "$GO_PKG"
    mkdir -p "$BPF_GEN"

    mkdir -p "$SCRIPTS"
    mkdir -p "$DOCS"

    log "info" "creating subfiles"

    printf "$template_common_h" >"$BPF_INCLUDES/common.h"

    printf "$template_bpfgen" >"$BPF_GEN/gen.go"

    printf "$template_bpf_main" >"$BPF_MAIN"

    printf "$template_gen_sh" >"$SCRIPTS/generate-bpf.sh"

    printf "$template_configure_sh" >"$SCRIPTS/configure.sh"

    printf "BasedOnStyle: LLVM\nIndentWidth: 4\nColumnLimit: 80\n" >"$ROOT/.clang-format"
    printf "# $PROJECT_NAME"> "$ROOT/README.md"

    touch "$ROOT/main.go"
    touch "$ROOT/Makefile"
    touch "$DOCS/notes.md"
    

}

gen-vmlinux() {
    if [[ ! -e $VMLINUX ]]; then
        bpftool btf dump file /sys/kernel/btf/vmlinux format c >"$VMLINUX"
        log "info" "vmlinux created"
    fi

}

main() {

    log "info" "setting up: $PROJECT_NAME"

    if [ ! -e "$ROOT" ]; then
        mkdir -p "$ROOT"
    else
        log "info" "'$ROOT' already exists"
    fi

    gen-paths
    gen-vmlinux

    log "info" "perform: go mod init <full_project_name>"

}

if [ -z "$1" ]; then
    log "sample1" "generate.sh experiment1"
    log "sample2" "generate.sh experiment1 /tmp"
    exit 1
fi

main

#!/bin/bash

project_name="$1"
workdir="${PWD:-$2}"

log() {
    printf "$(date) [%s] %s\n" "$1" "$2"
}

log "info" "workdir=$workdir project_name=$project_name"

project_path="$workdir/$project_name"
VMLINUX="$project_path/bpf/includes/vmlinux.h"

bpf_main="bpf/$project_name.c"

template_bpfgen="package bpfgen\n
//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -target amd64 -type internal_event Bpf ../$bpf_main -- -I../bpf/includes -I../bpf/lib
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

template_bpf_main="
char __license[] SEC(\"license\") = \"Dual MIT/GPL\";
"

gen-paths() {

    log "info" "creating subfolders"

    mkdir -p "$project_path/bpf/includes"
    mkdir -p "$project_path/bpf/lib"
    mkdir -p "$project_path/bpfgen"

    mkdir -p "$project_path/$project_name"
    mkdir -p "$project_path/scripts"
    mkdir -p "$project_path/docs"

    log "info" "creating subfiles"

    printf "$template_common_h" >"$project_path/bpf/includes/common.h"

    printf "$template_bpfgen" >"$project_path/bpfgen/gen.go"

    printf "$template_bpf_main" >"$project_path/$bpf_main"

    printf "BasedOnStyle: LLVM\nIndentWidth: 4\nColumnLimit: 80\n" >"$project_path/.clang-format"

    touch "$project_path/main.go"
    touch "$project_path/Makefile"

}

gen-vmlinux() {
    if [[ ! -e $VMLINUX ]]; then
        bpftool btf dump file /sys/kernel/btf/vmlinux format c >$VMLINUX
        log "info" "vmlinux created"
    fi

}

main() {

    log "info" "setting up $project_name"

    if [ ! -e "$project_path" ]; then
        mkdir -p "$project_path"
    else
        log "info" "'$project_path' already exists"
    fi

    gen-paths
    gen-vmlinux

    log "info" "perform: go mod init <full_project_name>"

}

if [ -z $1 ]; then
    log "help" "bpf_project_gen.sh <req:project_name> <opt:project_dir>"
    log "sample1" "bpf_project_gen.sh experiment1"
    log "sample2" "bpf_project_gen.sh experiment1 /tmp"
    exit 1
fi

main

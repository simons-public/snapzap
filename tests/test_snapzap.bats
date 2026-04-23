#!/usr/bin/env bats

setup() {
    TESTDIR=$(mktemp -d)
    IMG="$TESTDIR/zpool.img"
    dd if=/dev/zero of="$IMG" bs=1M count=200 >/dev/null 2>&1

    sudo zpool create -f testpool "$IMG"
    sudo zfs create testpool/fs
}

teardown() {
    sudo zpool destroy -f testpool >/dev/null 2>&1 || true
    rm -rf "$TESTDIR"
}

@test "lists snapshots" {
    sudo zfs snapshot testpool/fs@snap1
    sudo zfs snapshot testpool/fs@snap2

    run ./snaplist testpool/fs

    [ "$status" -eq 0 ]
    [[ "$output" == *"testpool/fs@snap1"* ]]
    [[ "$output" == *"testpool/fs@snap2"* ]]
}

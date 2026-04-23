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

    run ./snapzap testpool/fs

    [ "$status" -eq 0 ]
    [[ "$output" == *"testpool/fs@snap1"* ]]
    [[ "$output" == *"testpool/fs@snap2"* ]]
}

@test "filters snapshots with --before" {
    # Create snapshots with known timestamps
    sudo zfs snapshot testpool/fs@old
    sleep 2
    NOW=$(date +%s)
    sudo zfs snapshot testpool/fs@new

    run ./snapzap testpool/fs --before="$NOW"

    [ "$status" -eq 0 ]
    [[ "$output" == *"testpool/fs@old"* ]]
    [[ "$output" != *"testpool/fs@new"* ]]
}

@test "filters snapshots with --after" {
    sudo zfs snapshot testpool/fs@old
    sleep 2
    NOW=$(date +%s)
    sudo zfs snapshot testpool/fs@new

    run ./snapzap testpool/fs --after="$NOW"

    [ "$status" -eq 0 ]
    [[ "$output" != *"testpool/fs@old"* ]]
    [[ "$output" == *"testpool/fs@new"* ]]
}

@test "filters by user property" {
    sudo zfs snapshot testpool/fs@s1
    sudo zfs snapshot testpool/fs@s2

    sudo zfs set snapzap:tag=keep testpool/fs@s1
    sudo zfs set snapzap:tag=drop testpool/fs@s2

    run ./snapzap testpool/fs --filter=snapzap:tag=keep

    [ "$status" -eq 0 ]
    [[ "$output" == *"testpool/fs@s1"* ]]
    [[ "$output" != *"testpool/fs@s2"* ]]
}

@test "deletes snapshots with --delete" {
    sudo zfs snapshot testpool/fs@deleteme

    run ./snapzap testpool/fs --delete --filter=name=deleteme

    [ "$status" -eq 0 ]
    ! sudo zfs list -t snapshot | grep -q "deleteme"
}

@test "recursively deletes snapshots with --delete --recursive" {
    sudo zfs create testpool/fs/child
    sudo zfs snapshot testpool/fs@snap
    sudo zfs snapshot testpool/fs/child@snap

    run ./snapzap testpool/fs --delete --recursive

    [ "$status" -eq 0 ]
    ! sudo zfs list -t snapshot | grep -q "testpool/fs@snap"
    ! sudo zfs list -t snapshot | grep -q "testpool/fs/child@snap"
}

@test "quiet mode suppresses output" {
    sudo zfs snapshot testpool/fs@snap1

    run ./snapzap testpool/fs --quiet

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}


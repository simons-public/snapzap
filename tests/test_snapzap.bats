#!/usr/bin/env bats

setup() {
    TESTDIR=$(mktemp -d)
    IMG="$TESTDIR/zpool.img"
    dd if=/dev/zero of="$IMG" bs=1M count=200 >/dev/null 2>&1

    sudo zpool create -f testpool-${BATS_SUITE_TEST_NUMBER} "$IMG"
    sudo zfs create testpool-${BATS_SUITE_TEST_NUMBER}/fs
}

teardown() {
    sudo zpool destroy -f testpool-${BATS_SUITE_TEST_NUMBER} >/dev/null 2>&1 || true
    rm -rf "$TESTDIR"
}

@test "lists snapshots" {
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@snap1
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@snap2

    run ./snapzap testpool-${BATS_SUITE_TEST_NUMBER}/fs

    [ "$status" -eq 0 ]
    [[ "$output" == *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@snap1"* ]]
    [[ "$output" == *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@snap2"* ]]
}

@test "filters snapshots with --before" {
    # Create snapshots with known timestamps
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@old
    sleep 2
    NOW=$(date +%s)
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@new

    run ./snapzap testpool-${BATS_SUITE_TEST_NUMBER}/fs --before="$NOW"

    [ "$status" -eq 0 ]
    [[ "$output" == *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@old"* ]]
    [[ "$output" != *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@new"* ]]
}

@test "filters snapshots with --after" {
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@old
    sleep 2
    NOW=$(date +%s)
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@new

    run ./snapzap testpool-${BATS_SUITE_TEST_NUMBER}/fs --after="$NOW"

    [ "$status" -eq 0 ]
    [[ "$output" != *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@old"* ]]
    [[ "$output" == *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@new"* ]]
}

@test "filters by user property" {
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@s1
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@s2

    sudo zfs set snapzap:tag=keep testpool-${BATS_SUITE_TEST_NUMBER}/fs@s1
    sudo zfs set snapzap:tag=drop testpool-${BATS_SUITE_TEST_NUMBER}/fs@s2

    run ./snapzap testpool-${BATS_SUITE_TEST_NUMBER}/fs --filter=snapzap:tag=keep

    [ "$status" -eq 0 ]
    [[ "$output" == *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@s1"* ]]
    [[ "$output" != *"testpool-${BATS_SUITE_TEST_NUMBER}/fs@s2"* ]]
}

@test "deletes snapshots with --delete" {
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@deleteme

    run ./snapzap testpool-${BATS_SUITE_TEST_NUMBER}/fs --delete --filter=name=deleteme

    [ "$status" -eq 0 ]
    ! sudo zfs list -t snapshot | grep -q "deleteme"
}

@test "recursively deletes snapshots with --delete --recursive" {
    sudo zfs create testpool-${BATS_SUITE_TEST_NUMBER}/fs/child
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@snap
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs/child@snap

    run ./snapzap testpool-${BATS_SUITE_TEST_NUMBER}/fs --delete --recursive

    [ "$status" -eq 0 ]
    ! sudo zfs list -t snapshot | grep -q "testpool-${BATS_SUITE_TEST_NUMBER}/fs@snap"
    ! sudo zfs list -t snapshot | grep -q "testpool-${BATS_SUITE_TEST_NUMBER}/fs/child@snap"
}

@test "quiet mode suppresses output" {
    sudo zfs snapshot testpool-${BATS_SUITE_TEST_NUMBER}/fs@snap1

    run ./snapzap testpool-${BATS_SUITE_TEST_NUMBER}/fs --quiet

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}


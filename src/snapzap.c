/* snaplist -- list snapshots with filters

Copyright (c) 2024 Chris Simons

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

/* Written by Chris Simons <chris@simons.network> */

#include <getopt.h>
#include <libnvpair.h>
#include <libzfs.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Macro for debug print
#ifdef DEBUG
#define DEBUG_PRINT(fmt, ...) fprintf(stderr, fmt, ##__VA_ARGS__)
#else
#define DEBUG_PRINT(fmt, ...) // Do nothing
#endif

typedef enum
{
    QUIET_FLAG = 1 << 0,   // 1
    RECURSE_FLAG = 1 << 1, //
    DELETE_FLAG = 1 << 7   // 128
} ActionFlags;

typedef struct Filter
{
    char *property;
    char *value;
} filter_t;

typedef struct SnapshotParams
{
    char *dataset_name;
    uint8_t action_flags;
    filter_t filters[256];
    int filter_count;
} snapshot_params_t;

static int
snapshot_iter_func(zfs_handle_t *zhp, void *data)
{
    // cast void back to params
    snapshot_params_t *params = (snapshot_params_t *)data;

    DEBUG_PRINT("Inside snapshot_iter_func\n");
    if (zhp == NULL)
    {
        DEBUG_PRINT("zhp is NULL\n");
        return 0;
    }
    DEBUG_PRINT("Snapshot handle: %p\n", (void *)zhp);

    if (params->filter_count == 0)
    {
        DEBUG_PRINT("filters is NULL\n");
        // return 0;
    }

    // Check if the snapshot matches all filters
    for (int i = 0; i < params->filter_count; i++)
    {
        const filter_t *filter = &params->filters[i];
        DEBUG_PRINT("Filter %d: Name: %s, Value: %s\n", i, filter->property,
                    filter->value); // Debug print modified

        if (filter->property == NULL)
        {
            DEBUG_PRINT("Error parsing filter\n");
            return 0;
        }

        // Filter snapshots older than before date
        if (strcmp(filter->property, "before") == 0)
        {
            time_t created_time = zfs_prop_get_int(zhp, ZFS_PROP_CREATION);
            DEBUG_PRINT("Created at: %ld\n", created_time);
            if (created_time >= atol(filter->value))
            {
                return 0; // Filter does not match
            }
        }

        // Filter snapshots newer than after date
        else if (strcmp(filter->property, "after") == 0)
        {
            time_t created_time = zfs_prop_get_int(zhp, ZFS_PROP_CREATION);
            DEBUG_PRINT("Created at: %ld\n", created_time);
            if (created_time <= atol(filter->value))
            {
                return 0; // Filter does not match
            }
        }

        // User properties don't work with zfs_prop_get
        else if (strchr(filter->property, ':') != NULL)
        {
            DEBUG_PRINT("Snapshot property: %s is user property\n",
                        filter->property);
            int match_flag = 0;
            nvlist_t *user_props;
            user_props = zfs_get_user_props(zhp);

            nvpair_t *user_prop_pairs;
            user_prop_pairs = nvlist_next_nvpair(user_props, NULL);

            while (user_prop_pairs)
            {
                if (strcmp(nvpair_name(user_prop_pairs), filter->property) == 0)
                {
                    DEBUG_PRINT("property match: %s\n",
                                nvpair_name(user_prop_pairs));
                    nvlist_t *user_prop_pair_list;
                    nvpair_value_nvlist(user_prop_pairs, &user_prop_pair_list);

                    nvpair_t *user_prop_pair;
                    user_prop_pair =
                        nvlist_next_nvpair(user_prop_pair_list, NULL);

                    while (user_prop_pair)
                    {
                        if (strcmp(nvpair_name(user_prop_pair), "value") == 0)
                        {
                            DEBUG_PRINT("value match: %s\n",
                                        fnvpair_value_string(user_prop_pair));
                            if (strcmp(fnvpair_value_string(user_prop_pair),
                                       filter->value) == 0)
                            {
                                // Filter matches
                                match_flag = 1;
                            }
                        }
                        user_prop_pair = nvlist_next_nvpair(user_prop_pair_list,
                                                            user_prop_pair);
                    }
                }
                user_prop_pairs =
                    nvlist_next_nvpair(user_props, user_prop_pairs);
            }

            if (match_flag != 1)
            {
                // Filter not matched
                return 0;
            }
        }
        else
        {
            // Get the value of the specified property
            char prop_value_actual[ZFS_MAXPROPLEN];
            zprop_source_t prop_source;
            int err = zfs_prop_get(zhp, zfs_name_to_prop(filter->property),
                                   prop_value_actual, sizeof(prop_value_actual),
                                   &prop_source, NULL, 0, B_FALSE);
            if (err != 0)
            {
                fprintf(stderr, "Failed to retrieve property '%s': %s\n",
                        filter->property, strerror(err));
                return 0;
            }
            DEBUG_PRINT("Snapshot property: %s, Value: %s\n", filter->property,
                        prop_value_actual);
            if (strcmp(prop_value_actual, filter->value) != 0)
            {
                // Filter not matched
                return 0;
            }
        }
    }

    // All filters match, print the snapshot name if not quiet
    if (!(params->action_flags & QUIET_FLAG))
    {
        printf("%s\n", zfs_get_name(zhp));
    }

    // Delete and recurse set, destroy all similar snaps
    if ((params->action_flags & DELETE_FLAG) &&
        (params->action_flags & RECURSE_FLAG))
    {
        char *snapname = strchr(zfs_get_name(zhp), '@') + 1;

        // A dataset handle must be used for zfs_destroy_snaps
        zfs_handle_t *dataset_handle =
            zfs_open(libzfs_init(), params->dataset_name, ZFS_TYPE_DATASET);
        int err = zfs_destroy_snaps(dataset_handle, snapname, B_FALSE);
        if (err != 0)
        {
            fprintf(stderr, "Failed to delete snapshot %s recursively\n",
                    snapname);
            return 1;
        }
    }

    // Delete flag set, destroy snapshot
    if ((params->action_flags & DELETE_FLAG) &&
        !(params->action_flags & RECURSE_FLAG))
    {
        int err = zfs_destroy(zhp, B_FALSE);
        if (err != 0)
        {
            fprintf(stderr, "Failed to delete snapshot %s\n",
                    zfs_get_name(zhp));
            return 1;
        }
    }
    return 0;
}

void
list_snapshots_with_filters(snapshot_params_t *params)
{
    // Initialize libzfs handle
    libzfs_handle_t *zfs_handle = libzfs_init();

    if (zfs_handle == NULL)
    {
        fprintf(stderr, "Failed to initialize libzfs handle\n");
        return;
    }

    // Open the dataset
    zfs_handle_t *dataset_handle =
        zfs_open(zfs_handle, params->dataset_name, ZFS_TYPE_DATASET);
    if (dataset_handle == NULL)
    {
        fprintf(stderr, "Failed to open dataset %s\n", params->dataset_name);
        libzfs_fini(zfs_handle);
        return;
    }

    // Iterate over all snapshots
    uint8_t iter_flags = 0;
    iter_flags |= ZFS_ITER_RECURSE;
    zfs_iter_snapshots_v2(dataset_handle, iter_flags, snapshot_iter_func,
                          params, 0, UINT64_MAX);

    // Cleanup
    zfs_close(dataset_handle);
    libzfs_fini(zfs_handle);
}

void
print_usage(const char *argv[])
{
    printf("\n");
    printf("Usage: %s <dataset> [options]\n", argv[0]);
    printf("Options:\n");
    printf("  --filter=<property=value>    Filter by ZFS property\n");
    printf("  --before=<epoch timestamp>   Filter snapshots created before "
           "the "
           "timestamp\n");
    printf("  --after=<epoch timestamp>    Filter snapshots created after the "
           "timestamp\n");
    printf("  --delete                     Delete matching snapshots\n");
    printf("Subshells with the `date` command can be used for epoch "
           "timestamps:\n");
    printf("\t--after=$(date -d 'jan 1 2024' +%%s)\n");
    printf("\t--before=$(date -d 'today -30 days' +%%s)\n");
    printf("\n");
}

int
main(int argc, char *argv[])
{
    int opt;
    snapshot_params_t params = {0};

    static const struct option long_options[] = {
        {"filter", required_argument, 0, 'f'},
        {"before", required_argument, 0, 'b'},
        {"after", required_argument, 0, 'a'},
        {"quiet", no_argument, 0, 'q'},
        {"delete", no_argument, 0, 'd'},
        {"recursive", no_argument, 0, 'r'},
        {0, 0, 0, 0}};

    int option_index = 0;
    while ((opt = getopt_long(argc, argv, "f:b:a:qdr", long_options,
                              &option_index)) != -1)
    {
        switch (opt)
        {
        case 'f':
        {
            char *property = strtok(optarg, "=");
            char *value = strtok(NULL, "=");
            params.filters[params.filter_count].property = property;
            params.filters[params.filter_count].value = value;
            params.filter_count++;
            break;
        }
        case 'b':
            params.filters[params.filter_count].property = "before";
            params.filters[params.filter_count].value = optarg;
            params.filter_count++;
            break;
        case 'a':
            params.filters[params.filter_count].property = "after";
            params.filters[params.filter_count].value = optarg;
            params.filter_count++;
            break;
        case 'q':
            params.action_flags |= QUIET_FLAG;
            break;
        case 'd':
            params.action_flags |= DELETE_FLAG;
            break;
        case 'r':
            params.action_flags |= RECURSE_FLAG;
            break;
        default:
            print_usage((const char **)argv);
            return 1;
        }
    }

    // Check if dataset argument is provided
    if (optind < argc)
    {
        params.dataset_name = argv[optind];
    }
    else
    {
        print_usage((const char **)argv);
        return 1;
    }

    // List or delete snapshots based on user-specified filters
    list_snapshots_with_filters(&params);

    return 0;
}

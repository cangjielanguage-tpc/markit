#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct fswatch_linux_event {
    int32_t event_type;
    uint32_t mask;
    bool is_directory;
    char *path;
    char *old_path;
} fswatch_linux_event_t;

typedef struct fswatch_watch_path {
    char *path;
    bool recursive;
    struct fswatch_watch_path *next;
} fswatch_watch_path_t;

typedef struct fswatch_watch_entry {
    int wd;
    char *path;
    bool recursive;
    struct fswatch_watch_entry *next;
} fswatch_watch_entry_t;

typedef struct fswatch_move_record {
    uint32_t cookie;
    char *old_path;
    bool is_directory;
    struct fswatch_move_record *next;
} fswatch_move_record_t;

typedef struct fswatch_queued_event {
    fswatch_linux_event_t event;
    struct fswatch_queued_event *next;
} fswatch_queued_event_t;

/*
 * Native side monitor state:
 * - watch_paths keeps the declarative roots registered from Cangjie.
 * - watch_entries keeps the concrete inotify wd -> path mapping.
 * - move_records bridges IN_MOVED_FROM and IN_MOVED_TO by cookie.
 * - queue_* buffers normalized events until the runtime polls them.
 */
typedef struct fswatch_linux_monitor {
    int inotify_fd;
    fswatch_watch_path_t *watch_paths;
    fswatch_watch_entry_t *watch_entries;
    fswatch_move_record_t *move_records;
    fswatch_queued_event_t *queue_head;
    fswatch_queued_event_t *queue_tail;
    char error[256];
} fswatch_linux_monitor_t;

enum {
    FSWATCH_EVENT_CREATED = 1,
    FSWATCH_EVENT_MODIFIED = 2,
    FSWATCH_EVENT_DELETED = 3,
    FSWATCH_EVENT_MOVED = 4,
    FSWATCH_EVENT_ATTRIBUTE_CHANGED = 5
};

static char *fswatch_strdup(const char *value) {
    if (value == NULL) {
        return NULL;
    }

    size_t length = strlen(value);
    char *copy = (char *)malloc(length + 1);
    if (copy == NULL) {
        return NULL;
    }

    memcpy(copy, value, length + 1);
    return copy;
}

static void fswatch_linux_set_error(fswatch_linux_monitor_t *monitor, const char *message) {
    if (monitor == NULL) {
        return;
    }

    if (message == NULL) {
        monitor->error[0] = '\0';
        return;
    }

    snprintf(monitor->error, sizeof(monitor->error), "%s", message);
}

static void fswatch_linux_set_errno_error(fswatch_linux_monitor_t *monitor, const char *prefix) {
    char buffer[256];
    if (prefix == NULL) {
        snprintf(buffer, sizeof(buffer), "%s", strerror(errno));
    } else {
        snprintf(buffer, sizeof(buffer), "%s: %s", prefix, strerror(errno));
    }
    fswatch_linux_set_error(monitor, buffer);
}

static void fswatch_linux_free_event(fswatch_linux_event_t *event) {
    if (event == NULL) {
        return;
    }

    free(event->path);
    free(event->old_path);
    event->path = NULL;
    event->old_path = NULL;
}

static void fswatch_linux_clear_queue(fswatch_linux_monitor_t *monitor) {
    fswatch_queued_event_t *current = monitor->queue_head;
    while (current != NULL) {
        fswatch_queued_event_t *next = current->next;
        fswatch_linux_free_event(&current->event);
        free(current);
        current = next;
    }
    monitor->queue_head = NULL;
    monitor->queue_tail = NULL;
}

static void fswatch_linux_clear_move_records(fswatch_linux_monitor_t *monitor) {
    fswatch_move_record_t *current = monitor->move_records;
    while (current != NULL) {
        fswatch_move_record_t *next = current->next;
        free(current->old_path);
        free(current);
        current = next;
    }
    monitor->move_records = NULL;
}

static fswatch_watch_entry_t *fswatch_linux_find_entry_by_wd(fswatch_linux_monitor_t *monitor, int wd) {
    fswatch_watch_entry_t *current = monitor->watch_entries;
    while (current != NULL) {
        if (current->wd == wd) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

static fswatch_watch_entry_t *fswatch_linux_find_entry_by_path(fswatch_linux_monitor_t *monitor, const char *path) {
    fswatch_watch_entry_t *current = monitor->watch_entries;
    while (current != NULL) {
        if (strcmp(current->path, path) == 0) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

static void fswatch_linux_remove_entry_by_wd(fswatch_linux_monitor_t *monitor, int wd) {
    fswatch_watch_entry_t *previous = NULL;
    fswatch_watch_entry_t *current = monitor->watch_entries;
    while (current != NULL) {
        if (current->wd == wd) {
            if (previous == NULL) {
                monitor->watch_entries = current->next;
            } else {
                previous->next = current->next;
            }
            free(current->path);
            free(current);
            return;
        }
        previous = current;
        current = current->next;
    }
}

static bool fswatch_linux_enqueue_event(
    fswatch_linux_monitor_t *monitor,
    int32_t event_type,
    uint32_t mask,
    bool is_directory,
    char *path,
    char *old_path
) {
    fswatch_queued_event_t *node = (fswatch_queued_event_t *)calloc(1, sizeof(fswatch_queued_event_t));
    if (node == NULL) {
        free(path);
        free(old_path);
        fswatch_linux_set_error(monitor, "Failed to allocate filesystem event");
        return false;
    }

    node->event.event_type = event_type;
    node->event.mask = mask;
    node->event.is_directory = is_directory;
    node->event.path = path;
    node->event.old_path = old_path;

    if (monitor->queue_tail == NULL) {
        monitor->queue_head = node;
        monitor->queue_tail = node;
    } else {
        monitor->queue_tail->next = node;
        monitor->queue_tail = node;
    }
    return true;
}

/*
 * Build a stable full path from the watched directory and the event name.
 * For self events such as IN_DELETE_SELF, inotify does not provide a name,
 * so the watched directory path itself becomes the event path.
 */
static char *fswatch_linux_join_path(const char *dir_path, const char *name) {
    if (name == NULL || name[0] == '\0') {
        return fswatch_strdup(dir_path);
    }

    size_t dir_len = strlen(dir_path);
    size_t name_len = strlen(name);
    bool needs_separator = dir_len > 0 && dir_path[dir_len - 1] != '/';
    size_t total = dir_len + (needs_separator ? 1 : 0) + name_len + 1;

    char *buffer = (char *)malloc(total);
    if (buffer == NULL) {
        return NULL;
    }

    snprintf(buffer, total, needs_separator ? "%s/%s" : "%s%s", dir_path, name);
    return buffer;
}

static bool fswatch_linux_add_single_watch(
    fswatch_linux_monitor_t *monitor,
    const char *path,
    bool recursive
) {
    fswatch_watch_entry_t *existing = fswatch_linux_find_entry_by_path(monitor, path);
    if (existing != NULL) {
        if (recursive) {
            existing->recursive = true;
        }
        return true;
    }

    uint32_t mask = IN_CREATE | IN_MODIFY | IN_ATTRIB | IN_DELETE | IN_DELETE_SELF |
        IN_MOVED_FROM | IN_MOVED_TO | IN_MOVE_SELF | IN_CLOSE_WRITE;
    int wd = inotify_add_watch(monitor->inotify_fd, path, mask);
    if (wd < 0) {
        fswatch_linux_set_errno_error(monitor, path);
        return false;
    }

    fswatch_watch_entry_t *entry = (fswatch_watch_entry_t *)calloc(1, sizeof(fswatch_watch_entry_t));
    if (entry == NULL) {
        inotify_rm_watch(monitor->inotify_fd, wd);
        fswatch_linux_set_error(monitor, "Failed to allocate watch entry");
        return false;
    }

    entry->wd = wd;
    entry->path = fswatch_strdup(path);
    entry->recursive = recursive;
    if (entry->path == NULL) {
        inotify_rm_watch(monitor->inotify_fd, wd);
        free(entry);
        fswatch_linux_set_error(monitor, "Failed to copy watch path");
        return false;
    }

    entry->next = monitor->watch_entries;
    monitor->watch_entries = entry;
    return true;
}

static bool fswatch_linux_add_directory_recursive(
    fswatch_linux_monitor_t *monitor,
    const char *path,
    bool recursive
) {
    struct stat info;
    if (stat(path, &info) != 0) {
        fswatch_linux_set_errno_error(monitor, path);
        return false;
    }

    if (!S_ISDIR(info.st_mode)) {
        return fswatch_linux_add_single_watch(monitor, path, recursive);
    }

    if (!fswatch_linux_add_single_watch(monitor, path, recursive)) {
        return false;
    }

    if (!recursive) {
        return true;
    }

    /*
     * inotify does not automatically follow future subdirectories, so we
     * eagerly walk the current tree and register each directory as its own wd.
     */
    DIR *directory = opendir(path);
    if (directory == NULL) {
        fswatch_linux_set_errno_error(monitor, path);
        return false;
    }

    struct dirent *entry = NULL;
    while ((entry = readdir(directory)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        char *child_path = fswatch_linux_join_path(path, entry->d_name);
        if (child_path == NULL) {
            closedir(directory);
            fswatch_linux_set_error(monitor, "Failed to allocate child watch path");
            return false;
        }

        struct stat child_info;
        if (stat(child_path, &child_info) == 0 && S_ISDIR(child_info.st_mode)) {
            if (!fswatch_linux_add_directory_recursive(monitor, child_path, true)) {
                free(child_path);
                closedir(directory);
                return false;
            }
        }
        free(child_path);
    }

    closedir(directory);
    return true;
}

static void fswatch_linux_clear_native_watches(fswatch_linux_monitor_t *monitor) {
    fswatch_watch_entry_t *current = monitor->watch_entries;
    while (current != NULL) {
        if (monitor->inotify_fd >= 0) {
            inotify_rm_watch(monitor->inotify_fd, current->wd);
        }
        fswatch_watch_entry_t *next = current->next;
        free(current->path);
        free(current);
        current = next;
    }
    monitor->watch_entries = NULL;
}

static void fswatch_linux_clear_watch_paths(fswatch_linux_monitor_t *monitor) {
    fswatch_watch_path_t *current = monitor->watch_paths;
    while (current != NULL) {
        fswatch_watch_path_t *next = current->next;
        free(current->path);
        free(current);
        current = next;
    }
    monitor->watch_paths = NULL;
}

static char *fswatch_linux_take_move_record(
    fswatch_linux_monitor_t *monitor,
    uint32_t cookie,
    bool *is_directory
) {
    fswatch_move_record_t *previous = NULL;
    fswatch_move_record_t *current = monitor->move_records;
    while (current != NULL) {
        if (current->cookie == cookie) {
            if (previous == NULL) {
                monitor->move_records = current->next;
            } else {
                previous->next = current->next;
            }

            char *old_path = current->old_path;
            if (is_directory != NULL) {
                *is_directory = current->is_directory;
            }
            free(current);
            return old_path;
        }
        previous = current;
        current = current->next;
    }
    return NULL;
}

static bool fswatch_linux_store_move_record(
    fswatch_linux_monitor_t *monitor,
    uint32_t cookie,
    char *old_path,
    bool is_directory
) {
    fswatch_move_record_t *record = (fswatch_move_record_t *)calloc(1, sizeof(fswatch_move_record_t));
    if (record == NULL) {
        free(old_path);
        fswatch_linux_set_error(monitor, "Failed to allocate move record");
        return false;
    }

    record->cookie = cookie;
    record->old_path = old_path;
    record->is_directory = is_directory;
    record->next = monitor->move_records;
    monitor->move_records = record;
    return true;
}

static bool fswatch_linux_handle_native_event(
    fswatch_linux_monitor_t *monitor,
    const struct inotify_event *native_event
) {
    if ((native_event->mask & IN_Q_OVERFLOW) != 0) {
        fswatch_linux_set_error(monitor, "inotify event queue overflow");
        return false;
    }

    fswatch_watch_entry_t *entry = fswatch_linux_find_entry_by_wd(monitor, native_event->wd);
    if (entry == NULL) {
        return true;
    }

    if ((native_event->mask & IN_IGNORED) != 0) {
        fswatch_linux_remove_entry_by_wd(monitor, native_event->wd);
        return true;
    }

    bool is_directory = (native_event->mask & IN_ISDIR) != 0;
    char *full_path = fswatch_linux_join_path(entry->path, native_event->len > 0 ? native_event->name : NULL);
    if (full_path == NULL) {
        fswatch_linux_set_error(monitor, "Failed to allocate event path");
        return false;
    }

    /*
     * A rename arrives as two records. We cache MOVED_FROM here and stitch it
     * back onto MOVED_TO later so the runtime can expose oldPath cleanly.
     */
    if ((native_event->mask & IN_MOVED_FROM) != 0 && native_event->cookie != 0) {
        return fswatch_linux_store_move_record(monitor, native_event->cookie, full_path, is_directory);
    }

    if ((native_event->mask & IN_MOVED_TO) != 0) {
        bool old_is_directory = false;
        char *old_path = NULL;
        if (native_event->cookie != 0) {
            old_path = fswatch_linux_take_move_record(monitor, native_event->cookie, &old_is_directory);
            if (old_path != NULL) {
                is_directory = old_is_directory;
            }
        }

        /*
         * When a directory is moved into a recursive watch tree, it needs its
         * own watches immediately; otherwise later children under that subtree
         * would never surface from inotify.
         */
        if (is_directory && entry->recursive) {
            if (!fswatch_linux_add_directory_recursive(monitor, full_path, true)) {
                free(full_path);
                free(old_path);
                return false;
            }
        }
        return fswatch_linux_enqueue_event(
            monitor,
            FSWATCH_EVENT_MOVED,
            native_event->mask,
            is_directory,
            full_path,
            old_path
        );
    }

    if ((native_event->mask & IN_CREATE) != 0) {
        /*
         * Same rule as above for brand new directories created after start:
         * recursive mode is maintained by attaching watches on demand.
         */
        if (is_directory && entry->recursive) {
            if (!fswatch_linux_add_directory_recursive(monitor, full_path, true)) {
                free(full_path);
                return false;
            }
        }
        return fswatch_linux_enqueue_event(
            monitor,
            FSWATCH_EVENT_CREATED,
            native_event->mask,
            is_directory,
            full_path,
            NULL
        );
    }

    if ((native_event->mask & IN_DELETE) != 0 || (native_event->mask & IN_DELETE_SELF) != 0) {
        return fswatch_linux_enqueue_event(
            monitor,
            FSWATCH_EVENT_DELETED,
            native_event->mask,
            is_directory,
            full_path,
            NULL
        );
    }

    if ((native_event->mask & IN_ATTRIB) != 0) {
        return fswatch_linux_enqueue_event(
            monitor,
            FSWATCH_EVENT_ATTRIBUTE_CHANGED,
            native_event->mask,
            is_directory,
            full_path,
            NULL
        );
    }

    if ((native_event->mask & IN_MOVE_SELF) != 0) {
        return fswatch_linux_enqueue_event(
            monitor,
            FSWATCH_EVENT_MOVED,
            native_event->mask,
            is_directory,
            full_path,
            NULL
        );
    }

    if ((native_event->mask & IN_MODIFY) != 0 || (native_event->mask & IN_CLOSE_WRITE) != 0) {
        return fswatch_linux_enqueue_event(
            monitor,
            FSWATCH_EVENT_MODIFIED,
            native_event->mask,
            is_directory,
            full_path,
            NULL
        );
    }

    free(full_path);
    return true;
}

static int32_t fswatch_linux_fill_queue(fswatch_linux_monitor_t *monitor) {
    if (monitor == NULL || monitor->inotify_fd < 0) {
        return -1;
    }

    /*
     * One read may contain many variable-length inotify_event records.
     * We normalize all of them into queue nodes before returning to Cangjie.
     */
    char buffer[16384];
    ssize_t bytes_read = read(monitor->inotify_fd, buffer, sizeof(buffer));
    if (bytes_read < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0;
        }
        fswatch_linux_set_errno_error(monitor, "Failed to read inotify events");
        return -1;
    }

    ssize_t offset = 0;
    while (offset < bytes_read) {
        const struct inotify_event *native_event =
            (const struct inotify_event *)(buffer + offset);
        if (!fswatch_linux_handle_native_event(monitor, native_event)) {
            return -1;
        }
        offset += (ssize_t)sizeof(struct inotify_event) + native_event->len;
    }

    return monitor->queue_head != NULL ? 1 : 0;
}

void *fswatch_linux_create(void) {
    fswatch_linux_monitor_t *monitor =
        (fswatch_linux_monitor_t *)calloc(1, sizeof(fswatch_linux_monitor_t));
    if (monitor == NULL) {
        return NULL;
    }

    monitor->inotify_fd = -1;
    monitor->error[0] = '\0';
    return monitor;
}

int32_t fswatch_linux_clear_watches(void *handle) {
    fswatch_linux_monitor_t *monitor = (fswatch_linux_monitor_t *)handle;
    if (monitor == NULL) {
        return -1;
    }

    fswatch_linux_clear_watch_paths(monitor);
    fswatch_linux_clear_native_watches(monitor);
    fswatch_linux_clear_move_records(monitor);
    fswatch_linux_clear_queue(monitor);
    fswatch_linux_set_error(monitor, NULL);
    return 0;
}

int32_t fswatch_linux_add_watch(void *handle, const char *path, int32_t recursive) {
    fswatch_linux_monitor_t *monitor = (fswatch_linux_monitor_t *)handle;
    if (monitor == NULL || path == NULL) {
        return -1;
    }

    fswatch_watch_path_t *current = monitor->watch_paths;
    while (current != NULL) {
        if (strcmp(current->path, path) == 0) {
            if (recursive != 0) {
                current->recursive = true;
            }
            return 0;
        }
        current = current->next;
    }

    fswatch_watch_path_t *watch_path = (fswatch_watch_path_t *)calloc(1, sizeof(fswatch_watch_path_t));
    if (watch_path == NULL) {
        fswatch_linux_set_error(monitor, "Failed to allocate watch path");
        return -1;
    }

    watch_path->path = fswatch_strdup(path);
    watch_path->recursive = recursive != 0;
    if (watch_path->path == NULL) {
        free(watch_path);
        fswatch_linux_set_error(monitor, "Failed to copy watch path");
        return -1;
    }

    watch_path->next = monitor->watch_paths;
    monitor->watch_paths = watch_path;
    return 0;
}

int32_t fswatch_linux_start(void *handle) {
    fswatch_linux_monitor_t *monitor = (fswatch_linux_monitor_t *)handle;
    if (monitor == NULL) {
        return -1;
    }

    fswatch_linux_set_error(monitor, NULL);

    if (monitor->inotify_fd >= 0) {
        return 0;
    }

    monitor->inotify_fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (monitor->inotify_fd < 0) {
        fswatch_linux_set_errno_error(monitor, "Failed to initialize inotify");
        return -1;
    }

    /*
     * Register all declarative watch roots only after inotify is ready.
     * This keeps add_watch cheap before start and makes reload logic simple.
     */
    fswatch_watch_path_t *current = monitor->watch_paths;
    while (current != NULL) {
        if (!fswatch_linux_add_directory_recursive(monitor, current->path, current->recursive)) {
            close(monitor->inotify_fd);
            monitor->inotify_fd = -1;
            fswatch_linux_clear_native_watches(monitor);
            return -1;
        }
        current = current->next;
    }

    return 0;
}

int32_t fswatch_linux_stop(void *handle) {
    fswatch_linux_monitor_t *monitor = (fswatch_linux_monitor_t *)handle;
    if (monitor == NULL) {
        return -1;
    }

    fswatch_linux_clear_queue(monitor);
    fswatch_linux_clear_move_records(monitor);
    fswatch_linux_clear_native_watches(monitor);

    if (monitor->inotify_fd >= 0) {
        close(monitor->inotify_fd);
        monitor->inotify_fd = -1;
    }

    fswatch_linux_set_error(monitor, NULL);
    return 0;
}

int32_t fswatch_linux_poll_event(void *handle, fswatch_linux_event_t *event) {
    fswatch_linux_monitor_t *monitor = (fswatch_linux_monitor_t *)handle;
    if (monitor == NULL || event == NULL) {
        return -1;
    }

    /*
     * The runtime consumes one normalized event at a time. If the queue is
     * empty, refill it from inotify first, then pop a single event out.
     */
    if (monitor->queue_head == NULL) {
        int32_t fill_result = fswatch_linux_fill_queue(monitor);
        if (fill_result < 0) {
            return -1;
        }
        if (fill_result == 0 && monitor->queue_head == NULL) {
            return 0;
        }
    }

    fswatch_queued_event_t *node = monitor->queue_head;
    if (node == NULL) {
        return 0;
    }

    monitor->queue_head = node->next;
    if (monitor->queue_head == NULL) {
        monitor->queue_tail = NULL;
    }

    *event = node->event;
    free(node);
    return 1;
}

void fswatch_linux_release_event(fswatch_linux_event_t *event) {
    fswatch_linux_free_event(event);
}

const char *fswatch_linux_last_error(void *handle) {
    fswatch_linux_monitor_t *monitor = (fswatch_linux_monitor_t *)handle;
    if (monitor == NULL) {
        return NULL;
    }
    return monitor->error;
}

void fswatch_linux_destroy(void *handle) {
    fswatch_linux_monitor_t *monitor = (fswatch_linux_monitor_t *)handle;
    if (monitor == NULL) {
        return;
    }

    fswatch_linux_stop(handle);
    fswatch_linux_clear_watch_paths(monitor);
    free(monitor);
}

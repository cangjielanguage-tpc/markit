#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <dlfcn.h>
#import <pthread.h>
#import <stdbool.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

enum {
    FSWATCH_EVENT_OTHER = 0,
    FSWATCH_EVENT_CREATED = 1,
    FSWATCH_EVENT_MODIFIED = 2,
    FSWATCH_EVENT_DELETED = 3,
    FSWATCH_EVENT_MOVED = 4,
    FSWATCH_EVENT_ATTRIBUTE_CHANGED = 5,
};

typedef struct {
    int32_t event_type;
    uint64_t flags;
    bool is_directory;
    uint8_t *path;
    uint8_t *old_path;
} fswatch_macos_event_t;

typedef struct fswatch_watch_path {
    char *path;
} fswatch_watch_path_t;

typedef struct fswatch_queued_event {
    int32_t event_type;
    uint64_t flags;
    bool is_directory;
    char *path;
    char *old_path;
    struct fswatch_queued_event *next;
} fswatch_queued_event_t;

typedef struct {
    void *core_foundation_handle;
    void *core_services_handle;
    bool ready;
    char error[512];

    CFMutableArrayRef (*cf_array_create_mutable)(CFAllocatorRef, CFIndex, const CFArrayCallBacks *);
    void (*cf_array_append_value)(CFMutableArrayRef, const void *);
    CFIndex (*cf_array_get_count)(CFArrayRef);
    CFStringRef (*cf_string_create_with_cstring)(CFAllocatorRef, const char *, CFStringEncoding);
    CFTypeRef (*cf_retain)(CFTypeRef);
    void (*cf_release)(CFTypeRef);
    CFRunLoopRef (*cf_run_loop_get_current)(void);
    void (*cf_run_loop_run)(void);
    void (*cf_run_loop_stop)(CFRunLoopRef);
    void (*cf_run_loop_wake_up)(CFRunLoopRef);

    FSEventStreamRef (*fs_event_stream_create)(
        CFAllocatorRef,
        FSEventStreamCallback,
        const FSEventStreamContext *,
        CFArrayRef,
        FSEventStreamEventId,
        CFTimeInterval,
        FSEventStreamCreateFlags
    );
    void (*fs_event_stream_schedule_with_run_loop)(FSEventStreamRef, CFRunLoopRef, CFRunLoopMode);
    Boolean (*fs_event_stream_start)(FSEventStreamRef);
    void (*fs_event_stream_stop)(FSEventStreamRef);
    void (*fs_event_stream_invalidate)(FSEventStreamRef);
    void (*fs_event_stream_release)(FSEventStreamRef);
} fswatch_macos_runtime_t;

typedef struct {
    pthread_mutex_t lock;
    fswatch_watch_path_t *paths;
    size_t path_count;
    size_t path_capacity;
    // Native side owns a FIFO queue so Cangjie can poll events instead of
    // receiving cross-language callbacks from the FSEvents worker thread.
    fswatch_queued_event_t *queue_head;
    fswatch_queued_event_t *queue_tail;
    FSEventStreamRef stream;
    CFRunLoopRef run_loop;
    CFStringRef run_loop_mode;
    pthread_t worker;
    bool running;
    bool worker_started;
    bool stop_requested;
    char last_error[512];
} fswatch_macos_monitor_t;

static fswatch_macos_runtime_t fswatch_runtime = {0};
static pthread_mutex_t fswatch_runtime_lock = PTHREAD_MUTEX_INITIALIZER;
static const CFArrayCallBacks fswatch_cf_array_callbacks = {0, NULL, NULL, NULL, NULL};

static void fswatch_set_error(fswatch_macos_monitor_t *monitor, const char *message) {
    if (monitor == NULL) {
        return;
    }
    if (message == NULL) {
        monitor->last_error[0] = '\0';
        return;
    }
    snprintf(monitor->last_error, sizeof(monitor->last_error), "%s", message);
}

static char *fswatch_strdup(const char *value) {
    if (value == NULL) {
        return NULL;
    }
    size_t size = strlen(value) + 1;
    char *copy = (char *)malloc(size);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, value, size);
    return copy;
}

static void fswatch_set_runtime_error(const char *message) {
    if (message == NULL) {
        fswatch_runtime.error[0] = '\0';
        return;
    }
    snprintf(fswatch_runtime.error, sizeof(fswatch_runtime.error), "%s", message);
}

static void *fswatch_load_symbol(void *handle, const char *symbol) {
    void *value = dlsym(handle, symbol);
    if (value == NULL) {
        snprintf(
            fswatch_runtime.error,
            sizeof(fswatch_runtime.error),
            "Failed to load symbol '%s': %s",
            symbol,
            dlerror()
        );
    }
    return value;
}

static bool fswatch_runtime_ensure_loaded(void) {
    pthread_mutex_lock(&fswatch_runtime_lock);
    if (fswatch_runtime.ready) {
        pthread_mutex_unlock(&fswatch_runtime_lock);
        return true;
    }

    fswatch_set_runtime_error(NULL);
    fswatch_runtime.core_foundation_handle = dlopen(
        "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
        RTLD_LAZY | RTLD_LOCAL
    );
    if (fswatch_runtime.core_foundation_handle == NULL) {
        fswatch_set_runtime_error(dlerror());
        pthread_mutex_unlock(&fswatch_runtime_lock);
        return false;
    }

    fswatch_runtime.core_services_handle = dlopen(
        "/System/Library/Frameworks/CoreServices.framework/CoreServices",
        RTLD_LAZY | RTLD_LOCAL
    );
    if (fswatch_runtime.core_services_handle == NULL) {
        fswatch_set_runtime_error(dlerror());
        pthread_mutex_unlock(&fswatch_runtime_lock);
        return false;
    }

    fswatch_runtime.cf_array_create_mutable = (CFMutableArrayRef (*)(CFAllocatorRef, CFIndex, const CFArrayCallBacks *))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFArrayCreateMutable");
    fswatch_runtime.cf_array_append_value = (void (*)(CFMutableArrayRef, const void *))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFArrayAppendValue");
    fswatch_runtime.cf_array_get_count = (CFIndex (*)(CFArrayRef))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFArrayGetCount");
    fswatch_runtime.cf_string_create_with_cstring = (CFStringRef (*)(CFAllocatorRef, const char *, CFStringEncoding))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFStringCreateWithCString");
    fswatch_runtime.cf_retain = (CFTypeRef (*)(CFTypeRef))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFRetain");
    fswatch_runtime.cf_release = (void (*)(CFTypeRef))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFRelease");
    fswatch_runtime.cf_run_loop_get_current = (CFRunLoopRef (*)(void))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFRunLoopGetCurrent");
    fswatch_runtime.cf_run_loop_run = (void (*)(void))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFRunLoopRun");
    fswatch_runtime.cf_run_loop_stop = (void (*)(CFRunLoopRef))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFRunLoopStop");
    fswatch_runtime.cf_run_loop_wake_up = (void (*)(CFRunLoopRef))
        fswatch_load_symbol(fswatch_runtime.core_foundation_handle, "CFRunLoopWakeUp");

    fswatch_runtime.fs_event_stream_create = (FSEventStreamRef (*)(
        CFAllocatorRef,
        FSEventStreamCallback,
        const FSEventStreamContext *,
        CFArrayRef,
        FSEventStreamEventId,
        CFTimeInterval,
        FSEventStreamCreateFlags
    ))fswatch_load_symbol(fswatch_runtime.core_services_handle, "FSEventStreamCreate");
    fswatch_runtime.fs_event_stream_schedule_with_run_loop = (void (*)(FSEventStreamRef, CFRunLoopRef, CFRunLoopMode))
        fswatch_load_symbol(fswatch_runtime.core_services_handle, "FSEventStreamScheduleWithRunLoop");
    fswatch_runtime.fs_event_stream_start = (Boolean (*)(FSEventStreamRef))
        fswatch_load_symbol(fswatch_runtime.core_services_handle, "FSEventStreamStart");
    fswatch_runtime.fs_event_stream_stop = (void (*)(FSEventStreamRef))
        fswatch_load_symbol(fswatch_runtime.core_services_handle, "FSEventStreamStop");
    fswatch_runtime.fs_event_stream_invalidate = (void (*)(FSEventStreamRef))
        fswatch_load_symbol(fswatch_runtime.core_services_handle, "FSEventStreamInvalidate");
    fswatch_runtime.fs_event_stream_release = (void (*)(FSEventStreamRef))
        fswatch_load_symbol(fswatch_runtime.core_services_handle, "FSEventStreamRelease");

    fswatch_runtime.ready =
        fswatch_runtime.cf_array_create_mutable != NULL &&
        fswatch_runtime.cf_array_append_value != NULL &&
        fswatch_runtime.cf_array_get_count != NULL &&
        fswatch_runtime.cf_string_create_with_cstring != NULL &&
        fswatch_runtime.cf_retain != NULL &&
        fswatch_runtime.cf_release != NULL &&
        fswatch_runtime.cf_run_loop_get_current != NULL &&
        fswatch_runtime.cf_run_loop_run != NULL &&
        fswatch_runtime.cf_run_loop_stop != NULL &&
        fswatch_runtime.cf_run_loop_wake_up != NULL &&
        fswatch_runtime.fs_event_stream_create != NULL &&
        fswatch_runtime.fs_event_stream_schedule_with_run_loop != NULL &&
        fswatch_runtime.fs_event_stream_start != NULL &&
        fswatch_runtime.fs_event_stream_stop != NULL &&
        fswatch_runtime.fs_event_stream_invalidate != NULL &&
        fswatch_runtime.fs_event_stream_release != NULL;

    pthread_mutex_unlock(&fswatch_runtime_lock);
    return fswatch_runtime.ready;
}

static void fswatch_clear_queue_locked(fswatch_macos_monitor_t *monitor) {
    fswatch_queued_event_t *current = monitor->queue_head;
    while (current != NULL) {
        fswatch_queued_event_t *next = current->next;
        free(current->path);
        free(current->old_path);
        free(current);
        current = next;
    }
    monitor->queue_head = NULL;
    monitor->queue_tail = NULL;
}

static void fswatch_queue_event(
    fswatch_macos_monitor_t *monitor,
    int32_t event_type,
    uint64_t flags,
    bool is_directory,
    const char *path,
    const char *old_path
) {
    if (monitor == NULL || path == NULL) {
        return;
    }

    fswatch_queued_event_t *event = (fswatch_queued_event_t *)calloc(1, sizeof(fswatch_queued_event_t));
    if (event == NULL) {
        fswatch_set_error(monitor, "Failed to allocate event queue node");
        return;
    }

    event->event_type = event_type;
    event->flags = flags;
    event->is_directory = is_directory;
    event->path = fswatch_strdup(path);
    event->old_path = fswatch_strdup(old_path);
    if (event->path == NULL) {
        free(event->old_path);
        free(event);
        fswatch_set_error(monitor, "Failed to allocate event path");
        return;
    }

    pthread_mutex_lock(&monitor->lock);
    if (monitor->queue_tail == NULL) {
        monitor->queue_head = event;
        monitor->queue_tail = event;
    } else {
        monitor->queue_tail->next = event;
        monitor->queue_tail = event;
    }
    pthread_mutex_unlock(&monitor->lock);
}

static int32_t fswatch_map_event_type(FSEventStreamEventFlags flags) {
    if ((flags & kFSEventStreamEventFlagItemCreated) != 0) {
        return FSWATCH_EVENT_CREATED;
    }
    if ((flags & kFSEventStreamEventFlagItemRemoved) != 0) {
        return FSWATCH_EVENT_DELETED;
    }
    if ((flags & kFSEventStreamEventFlagItemRenamed) != 0) {
        return FSWATCH_EVENT_MOVED;
    }
    if ((flags & kFSEventStreamEventFlagItemModified) != 0) {
        return FSWATCH_EVENT_MODIFIED;
    }
    if ((flags & (kFSEventStreamEventFlagItemInodeMetaMod |
                  kFSEventStreamEventFlagItemFinderInfoMod |
                  kFSEventStreamEventFlagItemChangeOwner |
                  kFSEventStreamEventFlagItemXattrMod)) != 0) {
        return FSWATCH_EVENT_ATTRIBUTE_CHANGED;
    }
    return FSWATCH_EVENT_OTHER;
}

static void fswatch_fsevents_callback(
    ConstFSEventStreamRef stream_ref,
    void *client_info,
    size_t event_count,
    void *event_paths,
    const FSEventStreamEventFlags event_flags[],
    const FSEventStreamEventId event_ids[]
) {
    (void)stream_ref;
    (void)event_ids;

    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)client_info;
    if (monitor == NULL) {
        return;
    }

    char **paths = (char **)event_paths;
    for (size_t index = 0; index < event_count; index++) {
        const char *path = paths[index];
        FSEventStreamEventFlags flags = event_flags[index];
        bool is_directory = (flags & kFSEventStreamEventFlagItemIsDir) != 0;
        int32_t event_type = fswatch_map_event_type(flags);
        fswatch_queue_event(monitor, event_type, (uint64_t)flags, is_directory, path, NULL);
    }
}

static bool fswatch_build_stream(fswatch_macos_monitor_t *monitor) {
    if (!fswatch_runtime_ensure_loaded()) {
        fswatch_set_error(monitor, fswatch_runtime.error);
        return false;
    }

    CFMutableArrayRef watch_paths = fswatch_runtime.cf_array_create_mutable(NULL, 0, &fswatch_cf_array_callbacks);
    if (watch_paths == NULL) {
        fswatch_set_error(monitor, "Failed to allocate watch path array");
        return false;
    }

    pthread_mutex_lock(&monitor->lock);
    size_t path_count = monitor->path_count;
    CFStringRef *path_values = path_count == 0 ? NULL : (CFStringRef *)calloc(path_count, sizeof(CFStringRef));
    if (path_count > 0 && path_values == NULL) {
        pthread_mutex_unlock(&monitor->lock);
        fswatch_runtime.cf_release(watch_paths);
        fswatch_set_error(monitor, "Failed to allocate watch path buffer");
        return false;
    }

    size_t created_count = 0;
    for (size_t index = 0; index < monitor->path_count; index++) {
        CFStringRef value = fswatch_runtime.cf_string_create_with_cstring(
            NULL,
            monitor->paths[index].path,
            kCFStringEncodingUTF8
        );
        if (value != NULL) {
            path_values[created_count] = value;
            created_count += 1;
            fswatch_runtime.cf_array_append_value(watch_paths, value);
        }
    }
    pthread_mutex_unlock(&monitor->lock);

    if (fswatch_runtime.cf_array_get_count(watch_paths) == 0) {
        for (size_t index = 0; index < created_count; index++) {
            fswatch_runtime.cf_release(path_values[index]);
        }
        free(path_values);
        fswatch_runtime.cf_release(watch_paths);
        return true;
    }

    FSEventStreamContext context = {0};
    context.info = monitor;
    monitor->stream = fswatch_runtime.fs_event_stream_create(
        NULL,
        &fswatch_fsevents_callback,
        &context,
        watch_paths,
        kFSEventStreamEventIdSinceNow,
        0.05,
        kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
    );

    for (size_t index = 0; index < created_count; index++) {
        fswatch_runtime.cf_release(path_values[index]);
    }
    free(path_values);
    fswatch_runtime.cf_release(watch_paths);

    if (monitor->stream == NULL) {
        fswatch_set_error(monitor, "Failed to create FSEvents stream");
        return false;
    }

    monitor->run_loop = fswatch_runtime.cf_run_loop_get_current();
    fswatch_runtime.cf_retain(monitor->run_loop);
    monitor->run_loop_mode = fswatch_runtime.cf_string_create_with_cstring(
        NULL,
        "kCFRunLoopDefaultMode",
        kCFStringEncodingUTF8
    );
    if (monitor->run_loop_mode == NULL) {
        fswatch_set_error(monitor, "Failed to create run loop mode");
        fswatch_runtime.fs_event_stream_invalidate(monitor->stream);
        fswatch_runtime.fs_event_stream_release(monitor->stream);
        monitor->stream = NULL;
        fswatch_runtime.cf_release(monitor->run_loop);
        monitor->run_loop = NULL;
        return false;
    }

    fswatch_runtime.fs_event_stream_schedule_with_run_loop(monitor->stream, monitor->run_loop, monitor->run_loop_mode);
    if (!fswatch_runtime.fs_event_stream_start(monitor->stream)) {
        fswatch_set_error(monitor, "Failed to start FSEvents stream");
        fswatch_runtime.fs_event_stream_invalidate(monitor->stream);
        fswatch_runtime.fs_event_stream_release(monitor->stream);
        monitor->stream = NULL;
        fswatch_runtime.cf_release(monitor->run_loop_mode);
        monitor->run_loop_mode = NULL;
        fswatch_runtime.cf_release(monitor->run_loop);
        monitor->run_loop = NULL;
        return false;
    }

    return true;
}

static void fswatch_destroy_stream(fswatch_macos_monitor_t *monitor) {
    if (!fswatch_runtime_ensure_loaded()) {
        return;
    }

    if (monitor->stream != NULL) {
        fswatch_runtime.fs_event_stream_stop(monitor->stream);
        fswatch_runtime.fs_event_stream_invalidate(monitor->stream);
        fswatch_runtime.fs_event_stream_release(monitor->stream);
        monitor->stream = NULL;
    }
    if (monitor->run_loop_mode != NULL) {
        fswatch_runtime.cf_release(monitor->run_loop_mode);
        monitor->run_loop_mode = NULL;
    }
    if (monitor->run_loop != NULL) {
        fswatch_runtime.cf_release(monitor->run_loop);
        monitor->run_loop = NULL;
    }
}

static void *fswatch_worker_main(void *context) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)context;
    if (monitor == NULL) {
        return NULL;
    }

    if (!fswatch_build_stream(monitor)) {
        pthread_mutex_lock(&monitor->lock);
        monitor->worker_started = false;
        monitor->running = false;
        pthread_mutex_unlock(&monitor->lock);
        return NULL;
    }

    // stop may arrive before the worker fully enters CFRunLoopRun.
    // Check once after stream construction so stop/join does not deadlock.
    pthread_mutex_lock(&monitor->lock);
    bool should_stop = monitor->stop_requested;
    pthread_mutex_unlock(&monitor->lock);
    if (should_stop) {
        fswatch_destroy_stream(monitor);
        pthread_mutex_lock(&monitor->lock);
        monitor->running = false;
        monitor->worker_started = false;
        pthread_mutex_unlock(&monitor->lock);
        return NULL;
    }

    fswatch_runtime.cf_run_loop_run();

    pthread_mutex_lock(&monitor->lock);
    monitor->running = false;
    pthread_mutex_unlock(&monitor->lock);

    fswatch_destroy_stream(monitor);

    pthread_mutex_lock(&monitor->lock);
    monitor->worker_started = false;
    pthread_mutex_unlock(&monitor->lock);
    return NULL;
}

void *fswatch_macos_create(void) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)calloc(1, sizeof(fswatch_macos_monitor_t));
    if (monitor == NULL) {
        return NULL;
    }

    if (pthread_mutex_init(&monitor->lock, NULL) != 0) {
        free(monitor);
        return NULL;
    }

    fswatch_set_error(monitor, NULL);
    return monitor;
}

int32_t fswatch_macos_clear_watches(void *handle) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)handle;
    if (monitor == NULL) {
        return -1;
    }

    pthread_mutex_lock(&monitor->lock);
    for (size_t index = 0; index < monitor->path_count; index++) {
        free(monitor->paths[index].path);
    }
    free(monitor->paths);
    monitor->paths = NULL;
    monitor->path_count = 0;
    monitor->path_capacity = 0;
    pthread_mutex_unlock(&monitor->lock);
    return 0;
}

int32_t fswatch_macos_add_watch(void *handle, const char *path) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)handle;
    if (monitor == NULL || path == NULL) {
        return -1;
    }

    pthread_mutex_lock(&monitor->lock);
    if (monitor->path_count == monitor->path_capacity) {
        size_t next_capacity = monitor->path_capacity == 0 ? 4 : monitor->path_capacity * 2;
        fswatch_watch_path_t *next_paths = (fswatch_watch_path_t *)realloc(
            monitor->paths,
            next_capacity * sizeof(fswatch_watch_path_t)
        );
        if (next_paths == NULL) {
            pthread_mutex_unlock(&monitor->lock);
            fswatch_set_error(monitor, "Failed to grow watch path storage");
            return -1;
        }
        monitor->paths = next_paths;
        monitor->path_capacity = next_capacity;
    }

    char *copied_path = fswatch_strdup(path);
    if (copied_path == NULL) {
        pthread_mutex_unlock(&monitor->lock);
        fswatch_set_error(monitor, "Failed to allocate watch path");
        return -1;
    }

    monitor->paths[monitor->path_count].path = copied_path;
    monitor->path_count += 1;
    pthread_mutex_unlock(&monitor->lock);
    return 0;
}

int32_t fswatch_macos_start(void *handle) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)handle;
    if (monitor == NULL) {
        return -1;
    }

    pthread_mutex_lock(&monitor->lock);
    if (monitor->running || monitor->worker_started) {
        pthread_mutex_unlock(&monitor->lock);
        return 0;
    }

    fswatch_set_error(monitor, NULL);
    monitor->stop_requested = false;
    fswatch_clear_queue_locked(monitor);
    monitor->running = true;
    if (monitor->path_count == 0) {
        pthread_mutex_unlock(&monitor->lock);
        return 0;
    }

    monitor->worker_started = true;
    pthread_mutex_unlock(&monitor->lock);

    // FSEvents must be driven from a thread with a live CFRunLoop.
    if (pthread_create(&monitor->worker, NULL, &fswatch_worker_main, monitor) != 0) {
        pthread_mutex_lock(&monitor->lock);
        monitor->running = false;
        monitor->worker_started = false;
        pthread_mutex_unlock(&monitor->lock);
        fswatch_set_error(monitor, "Failed to create FSEvents worker thread");
        return -1;
    }

    return 0;
}

int32_t fswatch_macos_stop(void *handle) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)handle;
    if (monitor == NULL) {
        return -1;
    }

    pthread_t worker;
    bool should_join = false;

    pthread_mutex_lock(&monitor->lock);
    monitor->running = false;
    monitor->stop_requested = true;
    if (monitor->run_loop != NULL && fswatch_runtime_ensure_loaded()) {
        // Wake the loop as well as stopping it so a sleeping worker exits fast.
        fswatch_runtime.cf_run_loop_stop(monitor->run_loop);
        fswatch_runtime.cf_run_loop_wake_up(monitor->run_loop);
    }
    if (monitor->worker_started) {
        worker = monitor->worker;
        should_join = true;
    }
    pthread_mutex_unlock(&monitor->lock);

    if (should_join) {
        pthread_join(worker, NULL);
    }

    pthread_mutex_lock(&monitor->lock);
    fswatch_clear_queue_locked(monitor);
    pthread_mutex_unlock(&monitor->lock);
    return 0;
}

int32_t fswatch_macos_poll_event(void *handle, fswatch_macos_event_t *event) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)handle;
    if (monitor == NULL || event == NULL) {
        return -1;
    }

    pthread_mutex_lock(&monitor->lock);
    fswatch_queued_event_t *head = monitor->queue_head;
    if (head == NULL) {
        pthread_mutex_unlock(&monitor->lock);
        return 0;
    }

    monitor->queue_head = head->next;
    if (monitor->queue_head == NULL) {
        monitor->queue_tail = NULL;
    }
    pthread_mutex_unlock(&monitor->lock);

    event->event_type = head->event_type;
    event->flags = head->flags;
    event->is_directory = head->is_directory;
    event->path = (uint8_t *)head->path;
    event->old_path = (uint8_t *)head->old_path;
    free(head);
    return 1;
}

void fswatch_macos_release_event(fswatch_macos_event_t *event) {
    if (event == NULL) {
        return;
    }
    free(event->path);
    free(event->old_path);
    event->path = NULL;
    event->old_path = NULL;
}

const char *fswatch_macos_last_error(void *handle) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)handle;
    if (monitor == NULL) {
        return "Invalid macOS monitor handle";
    }
    if (monitor->last_error[0] != '\0') {
        return monitor->last_error;
    }
    if (fswatch_runtime.error[0] != '\0') {
        return fswatch_runtime.error;
    }
    return "";
}

void fswatch_macos_destroy(void *handle) {
    fswatch_macos_monitor_t *monitor = (fswatch_macos_monitor_t *)handle;
    if (monitor == NULL) {
        return;
    }

    fswatch_macos_stop(handle);
    fswatch_macos_clear_watches(handle);

    pthread_mutex_lock(&monitor->lock);
    fswatch_clear_queue_locked(monitor);
    pthread_mutex_unlock(&monitor->lock);

    pthread_mutex_destroy(&monitor->lock);
    free(monitor);
}

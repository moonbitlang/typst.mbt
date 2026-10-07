// Operating-system hooks of the CLI (native backend): file I/O with errno
// reporting (for faithful `io::Error` mapping), ranged reads (for font
// discovery), binary standard streams, `realpath`, `isatty` and the local
// UTC offset. The MoonBit side lives in `platform_native.mbt`.

#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>

#ifdef _WIN32
#include <direct.h>
#include <fcntl.h>
#include <io.h>
#include <windows.h>
#else
#include <dirent.h>
#include <fcntl.h>
#include <sys/resource.h>
#include <unistd.h>
#endif

#include <moonbit.h>

static int typst_platform_errno = 0;

static moonbit_bytes_t typst_platform_empty(void) {
  return moonbit_make_bytes(0, 0);
}

// Copies data into fresh bytes; `len` must not exceed `INT32_MAX` (checked
// by the callers).
static moonbit_bytes_t typst_platform_copy(const void *data, size_t len) {
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(bytes, data, len);
  }
  return bytes;
}

MOONBIT_FFI_EXPORT
int typst_platform_last_error(void) { return typst_platform_errno; }

MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_platform_strerror(int code) {
  const char *msg = strerror(code);
  return typst_platform_copy(msg, strlen(msg));
}

// Reads everything from a stream into a malloc'd buffer.
static int typst_platform_slurp(FILE *f, size_t hint, unsigned char **out,
                                size_t *out_len) {
  size_t cap = hint > 0 ? hint + 1 : 8192;
  size_t len = 0;
  unsigned char *buf = (unsigned char *)malloc(cap);
  if (buf == NULL) {
    return ENOMEM;
  }
  for (;;) {
    if (len == cap) {
      size_t new_cap = cap * 2;
      unsigned char *grown = (unsigned char *)realloc(buf, new_cap);
      if (grown == NULL) {
        free(buf);
        return ENOMEM;
      }
      buf = grown;
      cap = new_cap;
    }
    size_t n = fread(buf + len, 1, cap - len, f);
    len += n;
    if (len > INT32_MAX) {
      free(buf);
      return EFBIG;
    }
    if (n == 0) {
      if (ferror(f)) {
        int err = errno != 0 ? errno : EIO;
        free(buf);
        return err;
      }
      break;
    }
  }
  *out = buf;
  *out_len = len;
  return 0;
}

// Reads a whole file (like Rust's `fs::read`). On failure, returns empty
// bytes and sets the last error.
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_platform_read_file(moonbit_bytes_t path) {
  typst_platform_errno = 0;
  errno = 0;
  FILE *f = fopen((const char *)path, "rb");
  if (f == NULL) {
    typst_platform_errno = errno != 0 ? errno : EIO;
    return typst_platform_empty();
  }
  size_t hint = 0;
  struct stat st;
  if (fstat(fileno(f), &st) == 0) {
    if (S_ISDIR(st.st_mode)) {
      fclose(f);
      typst_platform_errno = EISDIR;
      return typst_platform_empty();
    }
    if (st.st_size > 0) {
      hint = (size_t)st.st_size;
    }
  }
  unsigned char *buf = NULL;
  size_t len = 0;
  int err = typst_platform_slurp(f, hint, &buf, &len);
  fclose(f);
  if (err != 0) {
    typst_platform_errno = err;
    return typst_platform_empty();
  }
  moonbit_bytes_t bytes = typst_platform_copy(buf, len);
  free(buf);
  return bytes;
}

// Ranged reads (font discovery): a file is opened once and then read in
// pieces through its descriptor, without a stream and its buffer (a stream
// per piece cost an `open`, an `fstat`, a seek and a buffer each time).
//
// The file is read, not mapped: a mapping of a file that is truncated
// while it is mapped raises SIGBUS on access, whereas a read past the new
// end is a short read, which the caller sees as a missing piece.

// Opens a file for ranged reads. Returns a descriptor, or -1 and sets the
// last error. Directories are refused like in `typst_platform_read_file`.
MOONBIT_FFI_EXPORT
int typst_platform_ranged_open(moonbit_bytes_t path) {
  typst_platform_errno = 0;
  errno = 0;
#ifdef _WIN32
  int fd = _open((const char *)path, _O_RDONLY | _O_BINARY);
#else
  int fd = open((const char *)path, O_RDONLY | O_CLOEXEC);
#endif
  if (fd < 0) {
    typst_platform_errno = errno != 0 ? errno : EIO;
    return -1;
  }
  struct stat st;
  if (fstat(fd, &st) == 0 && S_ISDIR(st.st_mode)) {
#ifdef _WIN32
    _close(fd);
#else
    close(fd);
#endif
    typst_platform_errno = EISDIR;
    return -1;
  }
  return fd;
}

// The size of an open file, or -1 and the last error.
MOONBIT_FFI_EXPORT
int64_t typst_platform_ranged_size(int fd) {
  typst_platform_errno = 0;
  errno = 0;
#ifdef _WIN32
  struct _stat64 st;
  if (_fstat64(fd, &st) != 0) {
#else
  struct stat st;
  if (fstat(fd, &st) != 0) {
#endif
    typst_platform_errno = errno != 0 ? errno : EIO;
    return -1;
  }
  return (int64_t)st.st_size;
}

// Reads up to `len` bytes at `offset` of an open file; fewer only at the
// end of the file. The caller bounds `len` by the file's size. On failure,
// returns empty bytes and sets the last error.
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_platform_ranged_read(int fd, int64_t offset,
                                           int32_t len) {
  typst_platform_errno = 0;
  if (len < 0 || offset < 0) {
    typst_platform_errno = EINVAL;
    return typst_platform_empty();
  }
  if (len == 0) {
    return typst_platform_empty();
  }
#ifdef _WIN32
  errno = 0;
  if (_lseeki64(fd, offset, SEEK_SET) < 0) {
    typst_platform_errno = errno != 0 ? errno : EIO;
    return typst_platform_empty();
  }
#endif
  moonbit_bytes_t bytes = moonbit_make_bytes_raw(len);
  int32_t got = 0;
  while (got < len) {
    errno = 0;
#ifdef _WIN32
    int n = _read(fd, bytes + got, (unsigned int)(len - got));
#else
    ssize_t n = pread(fd, bytes + got, (size_t)(len - got),
                      (off_t)(offset + got));
#endif
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      typst_platform_errno = errno != 0 ? errno : EIO;
      moonbit_decref(bytes);
      return typst_platform_empty();
    }
    if (n == 0) {
      break;
    }
    got += (int32_t)n;
  }
  if (got == len) {
    return bytes;
  }
  // A short read (the range ends beyond the file).
  moonbit_bytes_t part = typst_platform_copy(bytes, (size_t)got);
  moonbit_decref(bytes);
  return part;
}

// Closes a descriptor of `typst_platform_ranged_open`.
MOONBIT_FFI_EXPORT
void typst_platform_ranged_close(int fd) {
#ifdef _WIN32
  _close(fd);
#else
  close(fd);
#endif
}

// The kind of file at `path`, following symlinks: 1 = file, 2 = directory,
// 3 = other, 0 = error (see the last error).
MOONBIT_FFI_EXPORT
int typst_platform_stat_kind(moonbit_bytes_t path) {
  typst_platform_errno = 0;
  struct stat st;
  if (stat((const char *)path, &st) != 0) {
    typst_platform_errno = errno != 0 ? errno : EIO;
    return 0;
  }
  if (S_ISREG(st.st_mode)) {
    return 1;
  }
  if (S_ISDIR(st.st_mode)) {
    return 2;
  }
  return 3;
}

// Whether two paths refer to the same file, i.e. to the same device and
// inode (the `same-file` crate): 1 or 0, -1 on error, -2 where this is not
// implemented.
MOONBIT_FFI_EXPORT
int typst_platform_same_file(moonbit_bytes_t path1, moonbit_bytes_t path2) {
  typst_platform_errno = 0;
#ifdef _WIN32
  return -2;
#else
  struct stat st1;
  struct stat st2;
  if (stat((const char *)path1, &st1) != 0 ||
      stat((const char *)path2, &st2) != 0) {
    typst_platform_errno = errno != 0 ? errno : EIO;
    return -1;
  }
  return st1.st_dev == st2.st_dev && st1.st_ino == st2.st_ino ? 1 : 0;
#endif
}

// Like `typst_platform_stat_kind`, but does not follow symlinks; a symlink
// is reported as 4.
MOONBIT_FFI_EXPORT
int typst_platform_lstat_kind(moonbit_bytes_t path) {
  typst_platform_errno = 0;
#ifdef _WIN32
  return typst_platform_stat_kind(path);
#else
  struct stat st;
  if (lstat((const char *)path, &st) != 0) {
    typst_platform_errno = errno != 0 ? errno : EIO;
    return 0;
  }
  if (S_ISLNK(st.st_mode)) {
    return 4;
  }
  if (S_ISREG(st.st_mode)) {
    return 1;
  }
  if (S_ISDIR(st.st_mode)) {
    return 2;
  }
  return 3;
#endif
}

// Lists a directory (Rust's `fs::read_dir`): for every entry but `.` and
// `..`, in the system's order, a byte for its kind and its name with a
// terminating NUL. The kind is what the directory says about the entry, as
// `typst_platform_lstat_kind` numbers it, or 0 if it does not say (some file
// systems; then `DirEntry::file_type` asks with `lstat`, and so does the
// caller). On failure, returns empty bytes and sets the last error; ENOSYS
// on Windows, where the caller lists the directory another way.
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_platform_read_dir(moonbit_bytes_t path) {
  typst_platform_errno = 0;
#ifdef _WIN32
  (void)path;
  typst_platform_errno = ENOSYS;
  return typst_platform_empty();
#else
  errno = 0;
  DIR *dir = opendir((const char *)path);
  if (dir == NULL) {
    typst_platform_errno = errno != 0 ? errno : EIO;
    return typst_platform_empty();
  }
  size_t cap = 4096;
  size_t len = 0;
  unsigned char *buf = (unsigned char *)malloc(cap);
  if (buf == NULL) {
    closedir(dir);
    typst_platform_errno = ENOMEM;
    return typst_platform_empty();
  }
  struct dirent *entry;
  while ((entry = readdir(dir)) != NULL) {
    const char *name = entry->d_name;
    if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
      continue;
    }
    size_t name_len = strlen(name);
    // The kind, the name and its NUL.
    size_t need = len + name_len + 2;
    if (need > (size_t)INT32_MAX) {
      free(buf);
      closedir(dir);
      typst_platform_errno = EFBIG;
      return typst_platform_empty();
    }
    if (need > cap) {
      size_t new_cap = cap * 2 > need ? cap * 2 : need;
      unsigned char *grown = (unsigned char *)realloc(buf, new_cap);
      if (grown == NULL) {
        free(buf);
        closedir(dir);
        typst_platform_errno = ENOMEM;
        return typst_platform_empty();
      }
      buf = grown;
      cap = new_cap;
    }
    unsigned char kind = 0;
#ifdef DT_UNKNOWN
    switch (entry->d_type) {
    case DT_UNKNOWN: kind = 0; break;
    case DT_REG: kind = 1; break;
    case DT_DIR: kind = 2; break;
    case DT_LNK: kind = 4; break;
    default: kind = 3; break;
    }
#endif
    buf[len] = kind;
    memcpy(buf + len + 1, name, name_len + 1);
    len = need;
  }
  closedir(dir);
  moonbit_bytes_t bytes = typst_platform_copy(buf, len);
  free(buf);
  return bytes;
#endif
}

// Canonicalizes a path (Rust's `fs::canonicalize`). On failure, returns
// empty bytes and sets the last error.
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_platform_realpath(moonbit_bytes_t path) {
  typst_platform_errno = 0;
#ifdef _WIN32
  char buf[_MAX_PATH];
  if (_fullpath(buf, (const char *)path, _MAX_PATH) == NULL) {
    typst_platform_errno = errno != 0 ? errno : ENOENT;
    return typst_platform_empty();
  }
  struct stat st;
  if (stat(buf, &st) != 0) {
    typst_platform_errno = errno != 0 ? errno : ENOENT;
    return typst_platform_empty();
  }
  return typst_platform_copy(buf, strlen(buf));
#else
  char *resolved = realpath((const char *)path, NULL);
  if (resolved == NULL) {
    typst_platform_errno = errno != 0 ? errno : ENOENT;
    return typst_platform_empty();
  }
  moonbit_bytes_t bytes = typst_platform_copy(resolved, strlen(resolved));
  free(resolved);
  return bytes;
#endif
}

// Writes a whole file (like Rust's `fs::write`). Returns 0 or an errno.
MOONBIT_FFI_EXPORT
int typst_platform_write_file(moonbit_bytes_t path, moonbit_bytes_t data) {
  errno = 0;
  FILE *f = fopen((const char *)path, "wb");
  if (f == NULL) {
    return errno != 0 ? errno : EIO;
  }
  size_t len = (size_t)Moonbit_array_length(data);
  size_t written = len > 0 ? fwrite(data, 1, len, f) : 0;
  int err = 0;
  if (written != len) {
    err = errno != 0 ? errno : EIO;
  }
  if (fclose(f) != 0 && err == 0) {
    err = errno != 0 ? errno : EIO;
  }
  return err;
}

// Creates a single directory. Returns 0 or an errno.
MOONBIT_FFI_EXPORT
int typst_platform_mkdir(moonbit_bytes_t path) {
#ifdef _WIN32
  int status = _mkdir((const char *)path);
#else
  int status = mkdir((const char *)path, 0777);
#endif
  return status == 0 ? 0 : (errno != 0 ? errno : EIO);
}

static FILE *typst_platform_stream(int fd) {
  return fd == 2 ? stderr : stdout;
}

// Writes bytes to stdout (1) or stderr (2). Returns 0 or an errno.
MOONBIT_FFI_EXPORT
int typst_platform_write_fd(int fd, moonbit_bytes_t data) {
  FILE *stream = typst_platform_stream(fd);
#ifdef _WIN32
  _setmode(_fileno(stream), _O_BINARY);
#endif
  size_t len = (size_t)Moonbit_array_length(data);
  if (len == 0) {
    return 0;
  }
  errno = 0;
  size_t written = fwrite(data, 1, len, stream);
  if (written != len) {
    int err = errno != 0 ? errno : EIO;
    clearerr(stream);
    // Like Rust's standard streams, writing to a closed stream succeeds.
    return err == EBADF ? 0 : err;
  }
  return 0;
}

MOONBIT_FFI_EXPORT
int typst_platform_flush(int fd) {
  FILE *stream = typst_platform_stream(fd);
  errno = 0;
  if (fflush(stream) == 0) {
    return 0;
  }
  int err = errno != 0 ? errno : EIO;
  clearerr(stream);
  // Like Rust's standard streams, writing to a closed stream succeeds.
  return err == EBADF ? 0 : err;
}

// Reads all of stdin. On failure, returns the data read so far and sets
// the last error.
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_platform_read_stdin(void) {
  typst_platform_errno = 0;
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);
#endif
  unsigned char *buf = NULL;
  size_t len = 0;
  int err = typst_platform_slurp(stdin, 0, &buf, &len);
  if (err != 0) {
    typst_platform_errno = err;
    return typst_platform_empty();
  }
  moonbit_bytes_t bytes = typst_platform_copy(buf, len);
  free(buf);
  return bytes;
}

MOONBIT_FFI_EXPORT
int typst_platform_isatty(int fd) {
#ifdef _WIN32
  return _isatty(fd) ? 1 : 0;
#else
  return isatty(fd) ? 1 : 0;
#endif
}

// The local UTC offset in seconds (east positive) at the given UNIX
// timestamp.
MOONBIT_FFI_EXPORT
int typst_platform_local_offset(int64_t timestamp) {
  time_t t = (time_t)timestamp;
#ifdef _WIN32
  struct tm local;
  struct tm utc;
  if (localtime_s(&local, &t) != 0 || gmtime_s(&utc, &t) != 0) {
    return 0;
  }
  utc.tm_isdst = local.tm_isdst;
  return (int)difftime(mktime(&local), mktime(&utc));
#else
  struct tm local;
  if (localtime_r(&t, &local) == NULL) {
    return 0;
  }
  return (int)local.tm_gmtoff;
#endif
}

// A monotonic clock in nanoseconds (Rust's `Instant`).
MOONBIT_FFI_EXPORT
int64_t typst_platform_monotonic_nanos(void) {
#ifdef _WIN32
  LARGE_INTEGER frequency;
  LARGE_INTEGER counter;
  QueryPerformanceFrequency(&frequency);
  QueryPerformanceCounter(&counter);
  int64_t seconds = counter.QuadPart / frequency.QuadPart;
  int64_t rest = counter.QuadPart % frequency.QuadPart;
  return seconds * 1000000000 + rest * 1000000000 / frequency.QuadPart;
#else
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0;
  }
  return (int64_t)ts.tv_sec * 1000000000 + (int64_t)ts.tv_nsec;
#endif
}

// Raises the soft limit of open file descriptors to the hard limit (on
// macOS at most `OPEN_MAX`, beyond which `setrlimit` fails).
MOONBIT_FFI_EXPORT
void typst_platform_raise_fd_limit(void) {
#ifndef _WIN32
  struct rlimit limit;
  if (getrlimit(RLIMIT_NOFILE, &limit) != 0) {
    return;
  }
  rlim_t wanted = limit.rlim_max;
#ifdef __APPLE__
  if (wanted > OPEN_MAX) {
    wanted = OPEN_MAX;
  }
#endif
  if (wanted != RLIM_INFINITY && limit.rlim_cur < wanted) {
    limit.rlim_cur = wanted;
    setrlimit(RLIMIT_NOFILE, &limit);
  }
#endif
}

// The operating system: 0 = other Unix (Linux, BSD, ...), 1 = macOS,
// 2 = Windows.
MOONBIT_FFI_EXPORT
int typst_platform_os(void) {
#if defined(_WIN32)
  return 2;
#elif defined(__APPLE__)
  return 1;
#else
  return 0;
#endif
}

// The CPU architecture: 0 = x86_64, 1 = aarch64, 2 = x86, 3 = arm,
// 4 = riscv64, 5 = other.
MOONBIT_FFI_EXPORT
int typst_platform_arch(void) {
#if defined(__x86_64__) || defined(_M_X64)
  return 0;
#elif defined(__aarch64__) || defined(_M_ARM64)
  return 1;
#elif defined(__i386__) || defined(_M_IX86)
  return 2;
#elif defined(__arm__) || defined(_M_ARM)
  return 3;
#elif defined(__riscv) && __riscv_xlen == 64
  return 4;
#else
  return 5;
#endif
}

// The `Debug` name of Rust's `io::ErrorKind` for an errno value (std's
// `decode_error_kind` on Unix).
MOONBIT_FFI_EXPORT
moonbit_bytes_t typst_platform_error_kind_name(int code) {
  const char *name = "Uncategorized";
  switch (code) {
#ifdef E2BIG
  case E2BIG: name = "ArgumentListTooLong"; break;
#endif
#ifdef EADDRINUSE
  case EADDRINUSE: name = "AddrInUse"; break;
#endif
#ifdef EADDRNOTAVAIL
  case EADDRNOTAVAIL: name = "AddrNotAvailable"; break;
#endif
#ifdef EBUSY
  case EBUSY: name = "ResourceBusy"; break;
#endif
#ifdef ECONNABORTED
  case ECONNABORTED: name = "ConnectionAborted"; break;
#endif
#ifdef ECONNREFUSED
  case ECONNREFUSED: name = "ConnectionRefused"; break;
#endif
#ifdef ECONNRESET
  case ECONNRESET: name = "ConnectionReset"; break;
#endif
#ifdef EDEADLK
  case EDEADLK: name = "Deadlock"; break;
#endif
#ifdef EDQUOT
  case EDQUOT: name = "QuotaExceeded"; break;
#endif
  case EEXIST: name = "AlreadyExists"; break;
  case EFBIG: name = "FileTooLarge"; break;
#ifdef EHOSTUNREACH
  case EHOSTUNREACH: name = "HostUnreachable"; break;
#endif
  case EINTR: name = "Interrupted"; break;
  case EINVAL: name = "InvalidInput"; break;
  case EISDIR: name = "IsADirectory"; break;
#ifdef ELOOP
  case ELOOP: name = "FilesystemLoop"; break;
#endif
  case ENOENT: name = "NotFound"; break;
  case ENOMEM: name = "OutOfMemory"; break;
  case ENOSPC: name = "StorageFull"; break;
#ifdef ENOSYS
  case ENOSYS: name = "Unsupported"; break;
#endif
  case EMLINK: name = "TooManyLinks"; break;
#ifdef ENAMETOOLONG
  case ENAMETOOLONG: name = "InvalidFilename"; break;
#endif
#ifdef ENETDOWN
  case ENETDOWN: name = "NetworkDown"; break;
#endif
#ifdef ENETUNREACH
  case ENETUNREACH: name = "NetworkUnreachable"; break;
#endif
#ifdef ENOTCONN
  case ENOTCONN: name = "NotConnected"; break;
#endif
  case ENOTDIR: name = "NotADirectory"; break;
#ifdef ENOTEMPTY
  case ENOTEMPTY: name = "DirectoryNotEmpty"; break;
#endif
  case EPIPE: name = "BrokenPipe"; break;
  case EROFS: name = "ReadOnlyFilesystem"; break;
  case ESPIPE: name = "NotSeekable"; break;
#ifdef ESTALE
  case ESTALE: name = "StaleNetworkFileHandle"; break;
#endif
#ifdef ETIMEDOUT
  case ETIMEDOUT: name = "TimedOut"; break;
#endif
#ifdef ETXTBSY
  case ETXTBSY: name = "ExecutableFileBusy"; break;
#endif
  case EXDEV: name = "CrossesDevices"; break;
#ifdef EINPROGRESS
  case EINPROGRESS: name = "InProgress"; break;
#endif
  case EACCES:
  case EPERM: name = "PermissionDenied"; break;
  default:
#if defined(EWOULDBLOCK) && EWOULDBLOCK != EAGAIN
    if (code == EWOULDBLOCK) { name = "WouldBlock"; break; }
#endif
    if (code == EAGAIN) { name = "WouldBlock"; }
    break;
  }
  return typst_platform_copy(name, strlen(name));
}

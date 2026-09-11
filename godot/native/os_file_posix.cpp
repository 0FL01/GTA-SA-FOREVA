#include <cassert>
#include <cstdint>
#include <cstdio>
#include <limits>
#include <mutex>
#include <string>

using int32 = int32_t;
using uint32 = uint32_t;
using int64 = int64_t;
using uint64 = uint64_t;

#ifndef __stdcall
#define __stdcall
#endif

#include "oswrapper/oswrapper.h"

namespace {

std::mutex s_PathMutex;
std::string s_BasePath;

std::string BuildPath(const char* file) {
    assert(file);
    std::lock_guard lock(s_PathMutex);
    if (file[0] == '/' || s_BasePath.empty()) {
        return file;
    }
    return s_BasePath + (s_BasePath.back() == '/' ? "" : "/") + file;
}

} // namespace

const char* OS_FileGetArchiveName(int32 archive) {
    (void)archive;
    return nullptr;
}

int32 OS_FileSize(void* file) {
    assert(file);
    auto* stream = static_cast<FILE*>(file);
    const off_t position = ftello(stream);
    if (position < 0 || fseeko(stream, 0, SEEK_END) != 0) {
        return -1;
    }
    const off_t size = ftello(stream);
    (void)fseeko(stream, position, SEEK_SET);
    if (size < 0 || size > std::numeric_limits<int32>::max()) {
        return -1;
    }
    return static_cast<int32>(size);
}

int32 OS_FileOpen(OSFileDataArea dataArea, void** output, const char* file, OSFileAccessType access) {
    (void)dataArea;
    assert(output && file);
    // This adapter is a read-only asset client even when the host mount is writable.
    *output = nullptr;
    if (access != FILE_ACCESS_READ) {
        return 1;
    }
    const std::string path = BuildPath(file);
    *output = std::fopen(path.c_str(), "rb");
    return *output ? 0 : 1;
}

int32 OS_FileClose(void* file) {
    assert(file);
    return std::fclose(static_cast<FILE*>(file));
}

int32 OS_FileDelete(const char* file) {
    assert(file);
    return 1; // Deletion is unsupported by the read-only adapter.
}

int32 OS_FileRead(void* file, void* destination, int32 size) {
    assert(file && size >= 0 && (destination || size == 0));
    const size_t read = std::fread(destination, 1, static_cast<size_t>(size), static_cast<FILE*>(file));
    return read == static_cast<size_t>(size) ? 0 : 3;
}

int32 OS_FileGetPosition(void* file) {
    assert(file);
    const off_t position = ftello(static_cast<FILE*>(file));
    return position >= 0 && position <= std::numeric_limits<int32>::max() ?
        static_cast<int32>(position) : -1;
}

void OS_FileSetPosition(void* file, int32 position) {
    assert(file && position >= 0);
    (void)fseeko(static_cast<FILE*>(file), position, SEEK_SET);
}

int32 OS_FileWrite(void* file, const void* source, int32 size) {
    assert(file && size >= 0 && (source || size == 0));
    return 3; // Writes are unsupported, never silently reported as successful.
}

void OS_SetFilePathOffset(const char* path) {
    std::lock_guard lock(s_PathMutex);
    s_BasePath = path ? path : "";
}

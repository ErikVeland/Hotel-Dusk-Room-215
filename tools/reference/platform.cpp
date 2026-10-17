// Verification-only frontend for melonDS. Not linked into the Swift app.
// SPDX-License-Identifier: GPL-3.0-or-later
#include "Platform.h"
#include <cstdio>
#include <cstdarg>
#include <filesystem>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <cstring>
#include <dlfcn.h>
namespace melonDS::Platform {
struct FileHandle { FILE* stream; };
struct Thread { std::thread thread; };
struct Mutex { std::mutex mutex; };
struct Semaphore { std::mutex mutex; std::condition_variable condition; unsigned count = 0; };
struct DynamicLibrary { void* handle; };
void SignalStop(StopReason reason, void*) { fprintf(stderr, "Reference stopped: %d\n", int(reason)); }
std::string GetLocalFilePath(const std::string& filename) { return filename; }
FileHandle* OpenFile(const std::string& path, FileMode mode) {
    bool write = mode & Write, read = mode & Read;
    if ((mode & NoCreate) && !std::filesystem::exists(path)) return nullptr;
    const char* flags = !write ? "rb" : (mode & Append) ? (read ? "a+b" : "ab") :
        (mode & Preserve) ? "r+b" : (read ? "w+b" : "wb");
    FILE* stream = fopen(path.c_str(), flags);
    if (!stream && write && (mode & Preserve) && !(mode & NoCreate)) stream = fopen(path.c_str(), "w+b");
    return stream ? new FileHandle{stream} : nullptr;
}
FileHandle* OpenLocalFile(const std::string& path, FileMode mode) { return OpenFile(path, mode); }
bool FileExists(const std::string& path) { return std::filesystem::exists(path); }
bool LocalFileExists(const std::string& path) { return FileExists(path); }
bool CloseFile(FileHandle* file) { int result = fclose(file->stream); delete file; return result == 0; }
bool CheckFileWritable(const std::string& path) { auto f = OpenFile(path, FileMode(Write | Preserve)); return f && CloseFile(f); }
bool CheckLocalFileWritable(const std::string& path) { return CheckFileWritable(path); }
bool IsEndOfFile(FileHandle* f) { return feof(f->stream); }
bool FileReadLine(char* s, int n, FileHandle* f) { return fgets(s,n,f->stream) != nullptr; }
u64 FilePosition(FileHandle* f) { return ftello(f->stream); }
bool FileSeek(FileHandle* f, s64 n, FileSeekOrigin o) { return fseeko(f->stream,n,o == FileSeekOrigin::Start ? SEEK_SET : o == FileSeekOrigin::Current ? SEEK_CUR : SEEK_END) == 0; }
void FileRewind(FileHandle* f) { rewind(f->stream); }
u64 FileRead(void* p,u64 s,u64 n,FileHandle* f) { return fread(p,s,n,f->stream); }
u64 FileWrite(const void* p,u64 s,u64 n,FileHandle* f) { return fwrite(p,s,n,f->stream); }
bool FileFlush(FileHandle* f) { return fflush(f->stream) == 0; }
u64 FileLength(FileHandle* f) { auto p=ftello(f->stream); fseeko(f->stream,0,SEEK_END); auto n=ftello(f->stream); fseeko(f->stream,p,SEEK_SET); return n; }
u64 FileWriteFormatted(FileHandle* f,const char* format,...) { va_list a;va_start(a,format); int n=vfprintf(f->stream,format,a);va_end(a); return n<0?0:n; }
void Log(LogLevel level,const char* format,...) { if(level<Warn)return; va_list a;va_start(a,format);vfprintf(stderr,format,a);va_end(a); }
Thread* Thread_Create(std::function<void()> fn) { return new Thread{std::thread(std::move(fn))}; }
void Thread_Wait(Thread* t) { if(t->thread.joinable()) t->thread.join(); }
void Thread_Free(Thread* t) { Thread_Wait(t);delete t; }
Mutex* Mutex_Create() { return new Mutex; }
void Mutex_Free(Mutex* m) { delete m; }
void Mutex_Lock(Mutex* m) { m->mutex.lock(); }
void Mutex_Unlock(Mutex* m) { m->mutex.unlock(); }
bool Mutex_TryLock(Mutex* m) { return m->mutex.try_lock(); }
Semaphore* Semaphore_Create() { return new Semaphore; }
void Semaphore_Free(Semaphore* s) { delete s; }
void Semaphore_Reset(Semaphore* s) { std::lock_guard<std::mutex> l(s->mutex);s->count=0; }
void Semaphore_Wait(Semaphore* s) { std::unique_lock<std::mutex> l(s->mutex);s->condition.wait(l,[&]{return s->count>0;});--s->count; }
bool Semaphore_TryWait(Semaphore* s,int ms) { std::unique_lock<std::mutex> l(s->mutex);if(!s->condition.wait_for(l,std::chrono::milliseconds(ms),[&]{return s->count>0;}))return false;--s->count;return true; }
void Semaphore_Post(Semaphore* s,int count) { { std::lock_guard<std::mutex> l(s->mutex);s->count+=count; }s->condition.notify_all(); }
void Sleep(u64 us) { std::this_thread::sleep_for(std::chrono::microseconds(us)); }
u64 GetUSCount() { return std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
u64 GetMSCount() { return GetUSCount()/1000; }
void WriteNDSSave(const u8* data,u32 length,u32,u32,void* user) { if(!user)return; auto path=static_cast<std::string*>(user); FILE* f=fopen(path->c_str(),"wb");if(f){fwrite(data,1,length,f);fclose(f);} }
void WriteGBASave(const u8*,u32,u32,u32,void*) {}
void WriteFirmware(const Firmware&,u32,u32,void*) {}
void WriteDateTime(int,int,int,int,int,int,void*) {}
void MP_Begin(void*) {} void MP_End(void*) {}
int MP_SendPacket(u8*,int,u64,void*) {return 0;} int MP_RecvPacket(u8*,u64*,void*) {return 0;}
int MP_SendCmd(u8*,int,u64,void*) {return 0;} int MP_SendReply(u8*,int,u64,u16,void*) {return 0;}
int MP_SendAck(u8*,int,u64,void*) {return 0;} int MP_RecvHostPacket(u8*,u64*,void*) {return 0;}
u16 MP_RecvReplies(u8*,u64,u16,void*) {return 0;}
int Net_SendPacket(u8*,int,void*) {return 0;} int Net_RecvPacket(u8*,void*) {return 0;}
void Camera_Start(int,void*) {} void Camera_Stop(int,void*) {}
void Camera_CaptureFrame(int,u32*,int,int,bool,void*) {}
void Mic_Start(void*) {} void Mic_Stop(void*) {}
int Mic_ReadInput(s16* data,int length,void*) { memset(data,0,length*sizeof(s16));return length; }
AACDecoder* AAC_Init() {return nullptr;} void AAC_DeInit(AACDecoder*) {}
bool AAC_Configure(AACDecoder*,int,int) {return false;}
bool AAC_DecodeFrame(AACDecoder*,const void*,int,void*,int) {return false;}
bool Addon_KeyDown(KeyType,void*) {return false;}
void Addon_RumbleStart(u32,void*) {} void Addon_RumbleStop(void*) {}
float Addon_MotionQuery(MotionQueryType,void*) {return 0;}
DynamicLibrary* DynamicLibrary_Load(const char* name) { auto handle=dlopen(name,RTLD_NOW);return handle?new DynamicLibrary{handle}:nullptr; }
void DynamicLibrary_Unload(DynamicLibrary* l) {dlclose(l->handle);delete l;}
void* DynamicLibrary_LoadFunction(DynamicLibrary* l,const char* name) {return dlsym(l->handle,name);}
}

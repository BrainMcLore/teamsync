"""Keep the parser and archive extractor inside an OS resource boundary."""
import os

_job=None

def constrain(active_processes=4):
    global _job
    if os.name!='nt':
        import resource
        resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
        resource.setrlimit(resource.RLIMIT_CPU,(420,420))
        return
    import ctypes
    from ctypes import wintypes
    class Basic(ctypes.Structure):
        _fields_=[('process_time',ctypes.c_longlong),('job_time',ctypes.c_longlong),('flags',wintypes.DWORD),('min_working',ctypes.c_size_t),('max_working',ctypes.c_size_t),('active_limit',wintypes.DWORD),('affinity',ctypes.c_size_t),('priority',wintypes.DWORD),('scheduling',wintypes.DWORD)]
    class Counters(ctypes.Structure):
        _fields_=[(name,ctypes.c_ulonglong) for name in ['read_ops','write_ops','other_ops','read_bytes','write_bytes','other_bytes']]
    class Extended(ctypes.Structure):
        _fields_=[('basic',Basic),('io',Counters),('process_memory',ctypes.c_size_t),('job_memory',ctypes.c_size_t),('peak_process',ctypes.c_size_t),('peak_job',ctypes.c_size_t)]
    api=ctypes.WinDLL('kernel32',use_last_error=True)
    api.CreateJobObjectW.argtypes=[ctypes.c_void_p,wintypes.LPCWSTR];api.CreateJobObjectW.restype=wintypes.HANDLE
    api.SetInformationJobObject.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD];api.SetInformationJobObject.restype=wintypes.BOOL
    api.GetCurrentProcess.restype=wintypes.HANDLE
    api.AssignProcessToJobObject.argtypes=[wintypes.HANDLE,wintypes.HANDLE];api.AssignProcessToJobObject.restype=wintypes.BOOL
    handle=api.CreateJobObjectW(None,None)
    info=Extended();info.basic.flags=0x100|0x2000|0x8;info.basic.active_limit=active_processes;info.process_memory=2*1024**3
    if not handle or not api.SetInformationJobObject(handle,9,ctypes.byref(info),ctypes.sizeof(info)) or not api.AssignProcessToJobObject(handle,api.GetCurrentProcess()):
        raise RuntimeError('worker_limits_unavailable')
    _job=handle

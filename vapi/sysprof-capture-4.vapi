[CCode (cheader_filename = "sysprof-capture.h")]
namespace Sysprof {
    [SimpleType]
    public struct Address : uint64 {
        public bool is_context_switch (out AddressContext context);
        public int compare (Sysprof.Address b);
    }

    [SimpleType]
    public struct CaptureAddress : uint64 {
        public int compare (Sysprof.CaptureAddress b);
    }

    namespace Collector {
        public void init ();
        public bool is_active ();
        public void allocate (Sysprof.CaptureAddress alloc_addr, int64 alloc_size, Sysprof.BacktraceFunc backtrace_func);
        public void sample (Sysprof.BacktraceFunc backtrace_func);
        public void mark (int64 time, int64 duration, string group, string mark, string? message = null);
        [ PrintfFormat ]
        public void mark_printf (int64 time, int64 duration, string group, string mark, string message_format, ...);
        public void mark_vprintf (int64 time, int64 duration, string group, string mark, string message_format, va_list args);
        public void log (int severity, string domain, string message);
        [ PrintfFormat ]
        public void log_printf (int severity, string domain, string message_format, ...);
        public uint request_counters (uint n_counters);
        public void define_counters (Sysprof.CaptureCounter[] counters);
        public void set_counters ([CCode (array_length = false)] uint[] counters_ids, Sysprof.CaptureCounterValue[] values);
    }

    [CCode (ref_function = "sysprof_capture_condition_ref", unref_function = "sysprof_capture_condition_unref", has_type_id = false)]
    public class CaptureCondition {
        public CaptureCondition.and (Sysprof.CaptureCondition left, Sysprof.CaptureCondition right);
        public CaptureCondition.or (Sysprof.CaptureCondition left, Sysprof.CaptureCondition right);
        public CaptureCondition.where_counter_in (uint[] counters);
        public CaptureCondition.where_file (string path);
        public CaptureCondition.where_pid_in (int32[] pids);
        public CaptureCondition.where_time_between (int64 begin_time, int64 end_time);
        public CaptureCondition.where_type_in (Sysprof.CaptureFrameType[] types);
        public Sysprof.CaptureCondition copy ();
        public bool match (Sysprof.CaptureFrame frame);
    }

    [CCode (ref_function = "sysprof_capture_cursor_ref", unref_function = "sysprof_capture_cursor_unref", has_type_id = false)]
    public class CaptureCursor {
        public CaptureCursor (Sysprof.CaptureReader reader);
        public unowned Sysprof.CaptureReader get_reader ();
        public void add_condition (Sysprof.CaptureCondition condition);
        public void @foreach (Sysprof.CaptureCursorCallback callback);
        public void reset ();
        public void reverse ();
    }

    [CCode (ref_function = "sysprof_capture_reader_ref", unref_function = "sysprof_capture_reader_unref", has_type_id = false)]
    public class CaptureReader {
        public CaptureReader (string filename);
        public CaptureReader.from_fd (int fd);
        public bool get_stat (out unowned Sysprof.CaptureStat st_buf);
        public bool peek_frame (out Sysprof.CaptureFrame frame);
        public bool peek_type (out Sysprof.CaptureFrameType type);
        public bool read_file_fd (string path, int fd);
        public bool reset ();
        public bool save_as (string filename);
        public bool skip ();
        public bool splice (Sysprof.CaptureWriter dest);
        public int64 get_end_time ();
        public int64 get_start_time ();
        public int get_byte_order ();
        public string get_filename ();
        public string get_time ();
        public string[] list_files ();
        public Sysprof.CaptureReader copy ();
        public unowned Sysprof.CaptureAllocation read_allocation ();
        public unowned Sysprof.CaptureCounterDefine read_counter_define ();
        public unowned Sysprof.CaptureCounterSet read_counter_set ();
        public unowned Sysprof.CaptureExit read_exit ();
        public unowned Sysprof.CaptureFileChunk find_file (string path);
        public unowned Sysprof.CaptureFileChunk read_file ();
        public unowned Sysprof.CaptureFork read_fork ();
        public unowned Sysprof.CaptureJitmap read_jitmap ();
        public unowned Sysprof.CaptureLog read_log ();
        public unowned Sysprof.CaptureMap read_map ();
        public unowned Sysprof.CaptureMark read_mark ();
        public unowned Sysprof.CaptureMetadata read_metadata ();
        public unowned Sysprof.CaptureProcess read_process ();
        public unowned Sysprof.CaptureSample read_sample ();
        public unowned Sysprof.CaptureTimestamp read_timestamp ();
        public void set_stat (Sysprof.CaptureStat st_buf);
    }

    [CCode (ref_function = "sysprof_capture_writer_ref", unref_function = "sysprof_capture_writer_unref", has_type_id = false)]
    public class CaptureWriter {
        public CaptureWriter (string filename, size_t buffer_size);
        public CaptureWriter.from_env (size_t buffer_size);
        public CaptureWriter.from_fd (int fd, size_t buffer_size);
        public bool add_allocation_copy (int64 time, int cpu, int32 pid, int32 tid, Sysprof.CaptureAddress[] alloc_addr, Sysprof.CaptureAddress[] addrs);
        public bool add_allocation (int64 time, int cpu, int32 pid, int32 tid, Sysprof.CaptureAddress[] alloc_addr, Sysprof.BacktraceFunc backtrace_func);
        public bool add_exit (int64 time, int cpu, int32 pid);
        public bool add_file_fd (int64 time, int cpu, int32 pid, string path, int fd);
        public bool add_file (int64 time, int cpu, int32 pid, string path, bool is_last, uint8[] data);
        public bool add_fork (int64 time, int cpu, int32 pid, int32 child_pid);
        public bool add_jitmap (string name);
        public bool add_log (int64 time, int cpu, int32 pid, int severity, string domain, string message);
        public bool add_map (int64 time, int cpu, int32 pid, uint64 start, uint64 end, uint64 offset, uint64 inode, string filename);
        public bool add_mark (int64 time, int cpu, int32 pid, uint64 duration, string group, string name, string message);
        public bool add_metadata (int64 time, int cpu, int32 pid, string id, string metadata, ssize_t metadata_len = -1);
        public bool add_process (int64 time, int cpu, int32 pid, string cmdline);
        public bool add_sample (int64 time, int cpu, int32 pid, int32 tid, Sysprof.CaptureAddress[] addrs);
        public bool add_timestamp (int64 time, int cpu, int32 pid);
        public bool cat (Sysprof.CaptureReader reader);
        public bool define_counters (int64 time, int cpu, int32 pid, Sysprof.CaptureCounter[] counters);
        public bool flush ();
        public bool save_as (string filename);
        public bool set_counters (int64 time, int cpu, int32 pid, Sysprof.CaptureCounter[] counters, Sysprof.CaptureCounterValue[] values);
        public bool splice (Sysprof.CaptureWriter dest);
        public size_t get_buffer_size ();
        public Sysprof.CaptureReader create_reader ();
        public uint request_counter (uint n_counters);
        public void stat (out Sysprof.CaptureStat stat);
    }

    [Compact]
    public class CaptureJitmapIter {
        void* p1;
        void* p2;
        uint u1;
        void* p3;
        void* p4;
        [CCode (cname="sysprof_capture_jitmap_iter_init")]
        public CaptureJitmapIter (Sysprof.CaptureJitmap jitmap);
        public bool next (ref Sysprof.CaptureAddress addr, out unowned string[] path);
    }

    public struct CaptureStat {
        size_t frame_count[16];
    }

    public struct CaptureCounterValue {
        int64 v64;
        double vdbl;
    }

    public struct CaptureFileHeader {
        uint32 magic;
        uint32 version;
        uint32 little_endian;
        uint32 padding;
        char capture_time[64];
        int64 time;
        int64 end_time;
        char suffix[168];
    }

    public struct CaptureFrame {
        uint16 len;
        int16  cpu;
        int32  pid;
        int64  time;
        uint32 type;
        uint32 padding1;
        uint32 padding2;
        uint8[] data;
    }

    public struct CaptureMap {
        Sysprof.CaptureFrame frame;
        uint64 start;
        uint64 end;
        uint64 offset;
        uint64 inode;
        char[] filename;
    }

    public struct CaptureJitmap {
        Sysprof.CaptureFrame frame;
        uint32 n_jitmaps;
        uint8[] data;
    }

    public struct CaptureProcess {
        Sysprof.CaptureFrame frame;
        char[] cmdline;
    }

    public struct CaptureSample {
        Sysprof.CaptureFrame frame;
        uint32 n_addrs;
        uint32 padding1;
        int32 tid;
        Sysprof.CaptureAddress[] addrs;
    }

    public struct CaptureFork {
        Sysprof.CaptureFrame frame;
        int32 child_pid;
    }

    public struct CaptureExit {
        Sysprof.CaptureFrame frame;
    }

    public struct CaptureTimestamp {
        Sysprof.CaptureFrame frame;
    }

    public struct CaptureCounter {
        char category[32];
        char name[32];
        char description[52];
        uint32 id;
        uint32 type;
    }

    public struct CaptureCounterDefine {
        Sysprof.CaptureFrame frame;
        uint32 n_counters;
        uint32 padding1;
        uint32 padding2;
        Sysprof.CaptureCounter[] counters;
    }

    public struct CaptureCounterValues {
        uint32 ids[8];
        Sysprof.CaptureCounterValue values[8];
    }

    public struct CaptureCounterSet {
        Sysprof.CaptureFrame frame;
        uint32 n_values;
        uint32 padding1;
        uint32 padding2;
        Sysprof.CaptureCounterValues[] values;
    }

    public struct CaptureMark {
        Sysprof.CaptureFrame frame;
        int64 duration;
        char group[24];
        char name[40];
        char[] message;
    }

    public struct CaptureMetadata {
        Sysprof.CaptureFrame frame;
        char id[40];
        char[] metadata;
    }

    public struct CaptureLog {
        Sysprof.CaptureFrame frame;
        uint32 severity;
        uint32 padding1;
        uint32 padding2;
        char domain[32];
        char[] message;
    }

    public struct CaptureFileChunk {
        Sysprof.CaptureFrame frame;
        uint32 is_last;
        uint32 padding1;
        uint32 len;
        char path[256];
        uint8[] data;
    }

    public struct CaptureAllocation {
        Sysprof.CaptureFrame frame;
        Sysprof.CaptureAddress alloc_addr;
        int64 alloc_size;
        int32 tid;
        uint32 n_addrs;
        uint32 padding1;
        Sysprof.CaptureAddress[] addrs;
    }

    public enum CaptureFrameType {
        TIMESTAMP,
        SAMPLE,
        MAP,
        PROCESS,
        FORK,
        EXIT,
        JITMAP,
        CTRDEF,
        CTRSET,
        MARK,
        METADATA,
        LOG,
        FILE_CHUNK,
        ALLOCATION,
    }

    public enum AddressContext {
        NONE,
        HYPERVISOR,
        KERNEL,
        USER,
        GUEST,
        GUEST_KERNEL,
        GUEST_USER;
        public unowned string to_string ();
    }

    [CCode (cheader_filename = "sysprof-capture.h", instance_pos = 2.9)]
    public delegate int BacktraceFunc (ref Sysprof.CaptureAddress[] addrs);
    [CCode (cheader_filename = "sysprof-capture.h", instance_pos = 1.9)]
    public delegate bool CaptureCursorCallback (Sysprof.CaptureFrame frame);
    [CCode (cname = "SYSPROF_CAPTURE_CURRENT_TIME")]
    public const int64 CAPTURE_CURRENT_TIME;
    [CCode (cname = "SYSPROF_CAPTURE_COUNTER_INT64")]
    public const uint32 CAPTURE_COUNTER_INT64;
    [CCode (cname = "SYSPROF_CAPTURE_COUNTER_DOUBLE")]
    public const uint32 CAPTURE_COUNTER_DOUBLE;
    [CCode (cname = "SYSPROF_CAPTURE_ADDRESS_FORMAT")]
    public const string CAPTURE_ADDRESS_FORMAT;
    [CCode (cname = "SYSPROF_CAPTURE_JITMAP_MARK")]
    public const uint64 CAPTURE_JITMAP_MARK;
    public static int memfd_create (string desc);
    [CCode (cname = "sysprof_getpagesize")]
    public static size_t get_page_size ();
}

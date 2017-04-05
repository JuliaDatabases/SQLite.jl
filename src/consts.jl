include("../deps/deps.jl")

#Macros
macro OK(func)
    :($(esc(func)) == SQLITE_OK)
end

macro CHECK(db,ex)
    esc(quote
        if !(@OK $ex)
            sqliteerror($db)
        end
        SQLITE_OK
    end)
end

const SQLNullPtrError = SQLiteException("Cannot operate on null pointer")
macro NULLCHECK(ptr)
    esc(quote
        if $ptr == C_NULL
            throw(SQLNullPtrError)
        end
    end)
end

#Return codes
const SQLITE_OK =           0   # /* Successful result */
const SQLITE_ERROR =        1   # /* SQL error or missing database */
const SQLITE_INTERNAL =     2   # /* Internal logic error in SQLite */
const SQLITE_PERM =         3   # /* Access permission denied */
const SQLITE_ABORT =        4   # /* Callback routine requested an abort */
const SQLITE_BUSY =         5   # /* The database file is locked */
const SQLITE_LOCKED =       6   # /* A table in the database is locked */
const SQLITE_NOMEM =        7   # /* A malloc() failed */
const SQLITE_READONLY =     8   # /* Attempt to write a readonly database */
const SQLITE_INTERRUPT =    9   # /* Operation terminated by sqlite3_interrupt()*/
const SQLITE_IOERR =       10   # /* Some kind of disk I/O error occurred */
const SQLITE_CORRUPT =     11   # /* The database disk image is malformed */
const SQLITE_NOTFOUND =    12   # /* Unknown opcode in sqlite3_file_control() */
const SQLITE_FULL =        13   # /* Insertion failed because database is full */
const SQLITE_CANTOPEN =    14   # /* Unable to open the database file */
const SQLITE_PROTOCOL =    15   # /* Database lock protocol error */
const SQLITE_EMPTY =       16   # /* Database is empty */
const SQLITE_SCHEMA =      17   # /* The database schema changed */
const SQLITE_TOOBIG =      18   # /* String or BLOB exceeds size limit */
const SQLITE_CONSTRAINT =  19   # /* Abort due to constraint violation */
const SQLITE_MISMATCH =    20   # /* Data type mismatch */
const SQLITE_MISUSE =      21   # /* Library used incorrectly */
const SQLITE_NOLFS =       22   # /* Uses OS features not supported on host */
const SQLITE_AUTH =        23   # /* Authorization denied */
const SQLITE_FORMAT =      24   # /* Auxiliary database format error */
const SQLITE_RANGE =       25   # /* 2nd parameter to sqlite3_bind out of range */
const SQLITE_NOTADB =      26   # /* File opened that is not a database file */
const SQLITE_NOTICE =      27   # /* Notifications from sqlite3_log() */
const SQLITE_WARNING =     28   # /* Warnings from sqlite3_log() */
const SQLITE_ROW =         100  # /* sqlite3_step() has another row ready */
const SQLITE_DONE =        101  # /* sqlite3_step() has finished executing */
#Extended Return codes
const SQLITE_IOERR_READ =              (SQLITE_IOERR | (1<<8))
const SQLITE_IOERR_SHORT_READ =        (SQLITE_IOERR | (2<<8))
const SQLITE_IOERR_WRITE =             (SQLITE_IOERR | (3<<8))
const SQLITE_IOERR_FSYNC =             (SQLITE_IOERR | (4<<8))
const SQLITE_IOERR_DIR_FSYNC =         (SQLITE_IOERR | (5<<8))
const SQLITE_IOERR_TRUNCATE =          (SQLITE_IOERR | (6<<8))
const SQLITE_IOERR_FSTAT =             (SQLITE_IOERR | (7<<8))
const SQLITE_IOERR_UNLOCK =            (SQLITE_IOERR | (8<<8))
const SQLITE_IOERR_RDLOCK =            (SQLITE_IOERR | (9<<8))
const SQLITE_IOERR_DELETE =            (SQLITE_IOERR | (10<<8))
const SQLITE_IOERR_BLOCKED =           (SQLITE_IOERR | (11<<8))
const SQLITE_IOERR_NOMEM =             (SQLITE_IOERR | (12<<8))
const SQLITE_IOERR_ACCESS =            (SQLITE_IOERR | (13<<8))
const SQLITE_IOERR_CHECKRESERVEDLOCK = (SQLITE_IOERR | (14<<8))
const SQLITE_IOERR_LOCK =              (SQLITE_IOERR | (15<<8))
const SQLITE_IOERR_CLOSE =             (SQLITE_IOERR | (16<<8))
const SQLITE_IOERR_DIR_CLOSE =         (SQLITE_IOERR | (17<<8))
const SQLITE_IOERR_SHMOPEN =           (SQLITE_IOERR | (18<<8))
const SQLITE_IOERR_SHMSIZE =           (SQLITE_IOERR | (19<<8))
const SQLITE_IOERR_SHMLOCK =           (SQLITE_IOERR | (20<<8))
const SQLITE_IOERR_SHMMAP =            (SQLITE_IOERR | (21<<8))
const SQLITE_IOERR_SEEK =              (SQLITE_IOERR | (22<<8))
const SQLITE_IOERR_DELETE_NOENT =      (SQLITE_IOERR | (23<<8))
const SQLITE_IOERR_MMAP =              (SQLITE_IOERR | (24<<8))
const SQLITE_LOCKED_SHAREDCACHE =      (SQLITE_LOCKED |  (1<<8))
const SQLITE_BUSY_RECOVERY =           (SQLITE_BUSY   |  (1<<8))
const SQLITE_CANTOPEN_NOTEMPDIR =      (SQLITE_CANTOPEN | (1<<8))
const SQLITE_CANTOPEN_ISDIR =          (SQLITE_CANTOPEN | (2<<8))
const SQLITE_CANTOPEN_FULLPATH =       (SQLITE_CANTOPEN | (3<<8))
const SQLITE_CORRUPT_VTAB =            (SQLITE_CORRUPT | (1<<8))
const SQLITE_READONLY_RECOVERY =       (SQLITE_READONLY | (1<<8))
const SQLITE_READONLY_CANTLOCK =       (SQLITE_READONLY | (2<<8))
const SQLITE_READONLY_ROLLBACK =       (SQLITE_READONLY | (3<<8))
const SQLITE_ABORT_ROLLBACK =          (SQLITE_ABORT | (2<<8))
const SQLITE_CONSTRAINT_CHECK =        (SQLITE_CONSTRAINT | (1<<8))
const SQLITE_CONSTRAINT_COMMITHOOK =   (SQLITE_CONSTRAINT | (2<<8))
const SQLITE_CONSTRAINT_FOREIGNKEY =   (SQLITE_CONSTRAINT | (3<<8))
const SQLITE_CONSTRAINT_FUNCTION =     (SQLITE_CONSTRAINT | (4<<8))
const SQLITE_CONSTRAINT_NOTNULL =      (SQLITE_CONSTRAINT | (5<<8))
const SQLITE_CONSTRAINT_PRIMARYKEY =   (SQLITE_CONSTRAINT | (6<<8))
const SQLITE_CONSTRAINT_TRIGGER =      (SQLITE_CONSTRAINT | (7<<8))
const SQLITE_CONSTRAINT_UNIQUE =       (SQLITE_CONSTRAINT | (8<<8))
const SQLITE_CONSTRAINT_VTAB =         (SQLITE_CONSTRAINT | (9<<8))
const SQLITE_NOTICE_RECOVER_WAL =      (SQLITE_NOTICE | (1<<8))
const SQLITE_NOTICE_RECOVER_ROLLBACK = (SQLITE_NOTICE | (2<<8))
#Text Encodings
const SQLITE_UTF8 =            1 #
const SQLITE_UTF16LE =         2 #
const SQLITE_UTF16BE =         3 #
const SQLITE_UTF16 =           4 #    /* Use native byte order */
const SQLITE_ANY =             5 #    /* DEPRECATED */
const SQLITE_UTF16_ALIGNED =   8 #    /* sqlite3_create_collation only */

#Fundamental Data Types
const SQLITE_INTEGER = 1
const SQLITE_FLOAT   = 2
const SQLITE_TEXT    = 3
const SQLITE_BLOB    = 4
const SQLITE_NULL    = 5

const SQLITE3_TEXT   = 3

#Checkpoint operation parameters
const SQLITE_CHECKPOINT_PASSIVE =  0 #
const SQLITE_CHECKPOINT_FULL =     1 #
const SQLITE_CHECKPOINT_RESTART =  2 #

#Configuration Options
const SQLITE_CONFIG_SINGLETHREAD =   1 #  /* nil */
const SQLITE_CONFIG_MULTITHREAD =    2 #  /* nil */
const SQLITE_CONFIG_SERIALIZED =     3 #  /* nil */
const SQLITE_CONFIG_MALLOC =         4 #  /* sqlite3_mem_methods* */
const SQLITE_CONFIG_GETMALLOC =      5 #  /* sqlite3_mem_methods* */
const SQLITE_CONFIG_SCRATCH =        6 #  /* void*, int sz, int N */
const SQLITE_CONFIG_PAGECACHE =      7 #  /* void*, int sz, int N */
const SQLITE_CONFIG_HEAP =           8 #  /* void*, int nByte, int min */
const SQLITE_CONFIG_MEMSTATUS =      9 #  /* boolean */
const SQLITE_CONFIG_MUTEX =         10 #  /* sqlite3_mutex_methods* */
const SQLITE_CONFIG_GETMUTEX =      11 #  /* sqlite3_mutex_methods* */
#/* previously SQLITE_CONFIG_CHUNKALLOC 12 which is now unused. */
const SQLITE_CONFIG_LOOKASIDE =     13 #  /* int int */
const SQLITE_CONFIG_PCACHE =        14 #  /* no-op */
const SQLITE_CONFIG_GETPCACHE =     15 #  /* no-op */
const SQLITE_CONFIG_LOG =           16 #  /* xFunc, void* */
const SQLITE_CONFIG_URI =           17 #  /* int */
const SQLITE_CONFIG_PCACHE2 =       18 #  /* sqlite3_pcache_methods2* */
const SQLITE_CONFIG_GETPCACHE2 =    19 #  /* sqlite3_pcache_methods2* */
const SQLITE_CONFIG_COVERING_INDEX_SCAN =  20 #  /* int */
const SQLITE_CONFIG_SQLLOG =        21 #  /* xSqllog, void* */
const SQLITE_CONFIG_MMAP_SIZE =     22 #  /* sqlite3_int64, sqlite3_int64 */

#Database Connection Configuration Options
const SQLITE_DBCONFIG_LOOKASIDE =        1001 #  /* void* int int */
const SQLITE_DBCONFIG_ENABLE_FKEY =      1002 #  /* int int* */
const SQLITE_DBCONFIG_ENABLE_TRIGGER =   1003 #  /* int int* */

#Status Parameters for database connections
const SQLITE_DBSTATUS_LOOKASIDE_USED =        0 #
const SQLITE_DBSTATUS_CACHE_USED =            1 #
const SQLITE_DBSTATUS_SCHEMA_USED =           2 #
const SQLITE_DBSTATUS_STMT_USED =             3 #
const SQLITE_DBSTATUS_LOOKASIDE_HIT =         4 #
const SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE =   5 #
const SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL =   6 #
const SQLITE_DBSTATUS_CACHE_HIT =             7 #
const SQLITE_DBSTATUS_CACHE_MISS =            8 #
const SQLITE_DBSTATUS_CACHE_WRITE =           9 #
const SQLITE_DBSTATUS_MAX =                   9 #   /* Largest defined DBSTATUS */

#Authorizer Return Codes
const SQLITE_DENY =    1 #   /* Abort the SQL statement with an error */
const SQLITE_IGNORE =  2 #   /* Don't allow access, but don't generate an error */

#Conflict resolution modes
const SQLITE_ROLLBACK =  1 #
#/* const SQLITE_IGNORE =  2 # // Also used by sqlite3_authorizer() callback */
const SQLITE_FAIL =      3 #
#/* const SQLITE_ABORT =  4 #  // Also an error code */
const SQLITE_REPLACE =   5 #

#Standard File Control Opcodes
const SQLITE_FCNTL_LOCKSTATE =                1 #
const SQLITE_GET_LOCKPROXYFILE =              2 #
const SQLITE_SET_LOCKPROXYFILE =              3 #
const SQLITE_LAST_ERRNO =                     4 #
const SQLITE_FCNTL_SIZE_HINT =                5 #
const SQLITE_FCNTL_CHUNK_SIZE =               6 #
const SQLITE_FCNTL_FILE_POINTER =             7 #
const SQLITE_FCNTL_SYNC_OMITTED =             8 #
const SQLITE_FCNTL_WIN32_AV_RETRY =           9 #
const SQLITE_FCNTL_PERSIST_WAL =             10 #
const SQLITE_FCNTL_OVERWRITE =               11 #
const SQLITE_FCNTL_VFSNAME =                 12 #
const SQLITE_FCNTL_POWERSAFE_OVERWRITE =     13 #
const SQLITE_FCNTL_PRAGMA =                  14 #
const SQLITE_FCNTL_BUSYHANDLER =             15 #
const SQLITE_FCNTL_TEMPFILENAME =            16 #
const SQLITE_FCNTL_MMAP_SIZE =               18 #

#Device Characteristics
const SQLITE_IOCAP_ATOMIC =                  0x00000001 #
const SQLITE_IOCAP_ATOMIC512 =               0x00000002 #
const SQLITE_IOCAP_ATOMIC1K =                0x00000004 #
const SQLITE_IOCAP_ATOMIC2K =                0x00000008 #
const SQLITE_IOCAP_ATOMIC4K =                0x00000010 #
const SQLITE_IOCAP_ATOMIC8K =                0x00000020 #
const SQLITE_IOCAP_ATOMIC16K =               0x00000040 #
const SQLITE_IOCAP_ATOMIC32K =               0x00000080 #
const SQLITE_IOCAP_ATOMIC64K =               0x00000100 #
const SQLITE_IOCAP_SAFE_APPEND =             0x00000200 #
const SQLITE_IOCAP_SEQUENTIAL =              0x00000400 #
const SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN =   0x00000800 #
const SQLITE_IOCAP_POWERSAFE_OVERWRITE =     0x00001000 #

#Run-Time Limit Categories
const SQLITE_LIMIT_LENGTH =                     0 #
const SQLITE_LIMIT_SQL_LENGTH =                 1 #
const SQLITE_LIMIT_COLUMN =                     2 #
const SQLITE_LIMIT_EXPR_DEPTH =                 3 #
const SQLITE_LIMIT_COMPOUND_SELECT =            4 #
const SQLITE_LIMIT_VDBE_OP =                    5 #
const SQLITE_LIMIT_FUNCTION_ARG =               6 #
const SQLITE_LIMIT_ATTACHED =                   7 #
const SQLITE_LIMIT_LIKE_PATTERN_LENGTH =        8 #
const SQLITE_LIMIT_VARIABLE_NUMBER =            9 #
const SQLITE_LIMIT_TRIGGER_DEPTH =             10 #

#File Locking Levels
const SQLITE_LOCK_NONE =           0 #
const SQLITE_LOCK_SHARED =         1 #
const SQLITE_LOCK_RESERVED =       2 #
const SQLITE_LOCK_PENDING =        3 #
const SQLITE_LOCK_EXCLUSIVE =      4 #

#Mutex Types
const SQLITE_MUTEX_FAST =              0 #
const SQLITE_MUTEX_RECURSIVE =         1 #
const SQLITE_MUTEX_STATIC_MASTER =     2 #
const SQLITE_MUTEX_STATIC_MEM =        3 #  /* sqlite3_malloc() */
const SQLITE_MUTEX_STATIC_MEM2 =       4 #  /* NOT USED */
const SQLITE_MUTEX_STATIC_OPEN =       4 #  /* sqlite3BtreeOpen() */
const SQLITE_MUTEX_STATIC_PRNG =       5 #  /* sqlite3_random() */
const SQLITE_MUTEX_STATIC_LRU =        6 #  /* lru page list */
const SQLITE_MUTEX_STATIC_LRU2 =       7 #  /* NOT USED */
const SQLITE_MUTEX_STATIC_PMEM =       7 #  /* sqlite3PageMalloc() */

#Flags for the xShmLock VFS method
const SQLITE_SHM_UNLOCK =        1 #
const SQLITE_SHM_LOCK =          2 #
const SQLITE_SHM_SHARED =        4 #
const SQLITE_SHM_EXCLUSIVE =     8 #

#Constants Defining Special Destructor Behavior
# typedef void (*sqlite3_destructor_type)(void*);
const SQLITE_STATIC = reinterpret(Ptr{Void},0)
const SQLITE_TRANSIENT = reinterpret(Ptr{Void},-1)

#Function Flags
const SQLITE_DETERMINISTIC = 0x800

#Maximum xShmLock index
const SQLITE_SHM_NLOCK =         8 #

#Status Parameters
const SQLITE_STATUS_MEMORY_USED =           0 #
const SQLITE_STATUS_PAGECACHE_USED =        1 #
const SQLITE_STATUS_PAGECACHE_OVERFLOW =    2 #
const SQLITE_STATUS_SCRATCH_USED =          3 #
const SQLITE_STATUS_SCRATCH_OVERFLOW =      4 #
const SQLITE_STATUS_MALLOC_SIZE =           5 #
const SQLITE_STATUS_PARSER_STACK =          6 #
const SQLITE_STATUS_PAGECACHE_SIZE =        7 #
const SQLITE_STATUS_SCRATCH_SIZE =          8 #
const SQLITE_STATUS_MALLOC_COUNT =          9 #

#Status Parameters for prepared statements
const SQLITE_STMTSTATUS_FULLSCAN_STEP =      1 #
const SQLITE_STMTSTATUS_SORT =               2 #
const SQLITE_STMTSTATUS_AUTOINDEX =          3 #

#Synchronization Type Flags
const SQLITE_SYNC_NORMAL =         0x00002 #
const SQLITE_SYNC_FULL =           0x00003 #
const SQLITE_SYNC_DATAONLY =       0x00010 #

#Testing Interface Operation Codes
const SQLITE_TESTCTRL_FIRST =                     5 #
const SQLITE_TESTCTRL_PRNG_SAVE =                 5 #
const SQLITE_TESTCTRL_PRNG_RESTORE =              6 #
const SQLITE_TESTCTRL_PRNG_RESET =                7 #
const SQLITE_TESTCTRL_BITVEC_TEST =               8 #
const SQLITE_TESTCTRL_FAULT_INSTALL =             9 #
const SQLITE_TESTCTRL_BENIGN_MALLOC_HOOKS =      10 #
const SQLITE_TESTCTRL_PENDING_BYTE =             11 #
const SQLITE_TESTCTRL_ASSERT =                   12 #
const SQLITE_TESTCTRL_ALWAYS =                   13 #
const SQLITE_TESTCTRL_RESERVE =                  14 #
const SQLITE_TESTCTRL_OPTIMIZATIONS =            15 #
const SQLITE_TESTCTRL_ISKEYWORD =                16 #
const SQLITE_TESTCTRL_SCRATCHMALLOC =            17 #
const SQLITE_TESTCTRL_LOCALTIME_FAULT =          18 #
const SQLITE_TESTCTRL_EXPLAIN_STMT =             19 #
const SQLITE_TESTCTRL_LAST =                     19 #

#Virtual Table Configuration Options
const SQLITE_VTAB_CONSTRAINT_SUPPORT =  1 #

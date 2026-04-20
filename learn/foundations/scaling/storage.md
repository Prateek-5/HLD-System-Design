# Storage — Block, File, Object, and When to Use Each

## A. Intuition First
"Storage" is overloaded — it means different things at different layers. For system design, learn the three user-facing models: **block, file, object** — and where each wins.

## B. Mental Model
- **Block**: raw disk-like chunks, accessed by address. Your OS/DB sees it as a disk. (EBS, on-prem SAN.)
- **File**: hierarchical paths, POSIX-ish. Multiple clients can mount it. (EFS, NFS, SMB.)
- **Object**: flat namespace of (key → blob + metadata) accessed via HTTP API. Virtually infinite. (S3.)

## C. Internal Working
### RAID (block-level redundancy)
- **RAID 0**: stripe (speed, no redundancy).
- **RAID 1**: mirror (redundancy, 50% cap).
- **RAID 5**: stripe + parity (good balance, 1-drive tolerance).
- **RAID 6**: stripe + double parity (2-drive tolerance).
- **RAID 10**: stripe + mirror (fast + redundant, 50% cap).

### HDFS / distributed filesystems
- Files split into 128 MB blocks.
- Each block replicated across 3 machines by default.
- NameNode holds metadata; DataNodes hold blocks.
- Designed for throughput over latency: append-only, batch-oriented.

## D. Visual Representation
```
Block   : [ raw bytes at addresses 0..N ]   ← DBs, OS disks
File    : /dir/subdir/file.txt               ← traditional apps, shared mounts
Object  : bucket.s3.amazonaws.com/key        ← web-scale, media, backups
```

## E. Tradeoffs
| Model | Latency | Scale | Use case |
|---|---|---|---|
| Block | Lowest | Per-volume | DB, OS |
| File | Low | Limited by filer | Shared mounts, legacy apps |
| Object | Higher (HTTP API) | Effectively unlimited | Static assets, backups, media |

- **NAS** (file access over network) vs **SAN** (block access over network): NAS is shared file mount; SAN presents a block device; SAN is faster for DBs, NAS is simpler for general file sharing.
- **Object storage** has eventual consistency on overwrite in some systems (S3 is now strongly consistent, but read docs).

## F. Interview Lens
- "Where do you store user avatars?" → **object storage (S3)**, served via CDN.
- "Database files?" → **block storage (EBS)** attached to the DB instance.
- "Shared log directory across 10 servers?" → **NAS/file (EFS)**.
- Pitfalls: using a DB to store large blobs (expensive, slow); using S3 for a DB (latency + consistency).

## G. Real-World Mapping
- **S3 / GCS / Azure Blob** — object.
- **EBS, Persistent Disk** — block, attached to a VM.
- **EFS, Filestore, Azure Files** — file.
- **HDFS** — distributed file (Hadoop, Spark).

## H. Questions
**Beginner**: What are the three storage types?
**Intermediate**:
1. Why does Postgres not run on S3?
2. When do you use file over object?
**Advanced**:
1. Design storage for a video platform (ingestion, processing, serving).
2. Tradeoffs of storing 10 TB of user PDFs in Postgres vs S3.

## I. Mini Design — "Storage for a photo-sharing app"
- **User photos**: object storage (S3) — massive scale, CDN-friendly.
- **Photo metadata** (owner, timestamps, tags): relational DB on block storage.
- **Thumbnails**: object storage, separate bucket.
- **Ingestion buffer**: a write-through caching tier + S3 multipart upload for large files.

## J. Cross-Topic Connections
- [CDN](cdn.md) — object storage + CDN is the canonical static-asset stack.
- [Databases](../../data/db-and-dbms.md) — DBs typically on block storage.

## K. Confidence Checklist
- [ ] I can pick block/file/object for a given use case.
- [ ] I know the RAID levels and tradeoffs.
- [ ] I know what HDFS is.
- [ ] I know S3 vs EBS vs EFS in AWS.

### Red flags
- ❌ Storing large blobs in a relational DB.
- ❌ Treating "storage" as one thing.

## L. Potential Gaps & Improvements
- Tiered storage (hot/warm/cold, e.g., S3 → Glacier) — not covered.
- Lifecycle policies, versioning, retention — missing.
- Erasure coding (Reed-Solomon) used by object stores — missing.

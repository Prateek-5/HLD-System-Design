# Distributed File System & Object Storage

> **📎 Prereqs** — If rusty:
> - [`learn/foundations/scaling/storage.md`](../learn/foundations/scaling/storage.md) — block vs file vs object.
> - Replication + erasure coding basics.
> - REST / HTTP (S3's API is HTTP).

### 🔹 1. What This Topic Actually Is
Storage systems that present files or objects across a cluster, replicated + sharded for durability and throughput. Examples: HDFS (big data), S3 (object), Ceph (block/file/object).

### 🔹 2. Why It Exists
- Local disks are limited + fail.
- Distributed file systems offer near-infinite scale + fault tolerance via replication / erasure coding.

### 🔹 3. Core Concepts (High Signal)
- **Object storage**: flat namespace, HTTP API, virtually unlimited, eventually/strongly consistent. S3 + Glacier for tiered.
- **Block storage**: raw blocks; attached like a disk (EBS).
- **File storage**: POSIX-ish mount (EFS, NFS, HDFS).
- **HDFS**: 128MB blocks, 3× replication, NameNode (metadata) + DataNodes.
- **S3**:
  - Multipart uploads for large files.
  - Durability 99.999999999% via cross-AZ replication + erasure coding.
  - Lifecycle policies for tiering to Glacier.
  - Strongly consistent since 2020.
- **Ceph**: unified block/file/object; uses CRUSH (pseudo-random placement).
- **Erasure coding**: Reed-Solomon chunks; saves storage vs 3× replication but costs CPU + recovery time.

### 🔹 4. Internal Working
**S3 PUT**: client → frontend → shard by key hash → write to 3+ AZs (sync) → ack. Strongly consistent read reflects last write.
**HDFS write**: client → NameNode (picks DataNodes) → pipeline write to 3 replicas → ack back.
**Read**: metadata lookup → parallel reads from replicas.

**Failure points:** metadata server (NameNode) SPOF → HA NameNode; hot object; cost of egress; slow cross-region replication.

### 🔹 5. Key Tradeoffs
- Object storage: infinite scale, HTTP latency (~10 ms), not POSIX.
- Block: low latency, single-attached; per-VM.
- File (NFS/EFS): shared POSIX, limited by filer throughput.
- Erasure coding vs replication: 50% storage vs 200% for same durability; recovery ≫ slower.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. What's object storage vs file vs block?
2. Why HDFS blocks are 128 MB?

**Intermediate 🟡**
1. How does S3 achieve 11 nines durability?
2. What's multipart upload for?

**Advanced 🔴**
1. Design S3-like service with 100 PB capacity.
2. Erasure coding vs replication — when each?

### 🔹 7. Real System Mapping
- **S3** (paper exists; performance blog posts).
- **HDFS** for Hadoop/Spark clusters.
- **Ceph** (open source unified).
- **Google Colossus** (successor to GFS).
- **Facebook Haystack** for photos.

### 🔹 8. What Most People Miss
- **Don't run a DB on S3** — latency + API semantics are wrong. Block storage or managed DB instead.
- **S3 partitions by key prefix historically** — random prefixes helped hot-spotting (mostly solved in modern S3).
- **Lifecycle + Intelligent-Tiering** can cut storage cost 80%+ for cold data.
- **Object versioning + object lock** for compliance / ransomware protection.
- **Erasure coding adds rebuild cost** — losing one chunk triggers CPU-heavy reconstruction; plan for it.

### 🔹 9. 30-Second Revision
Object (S3) = flat, HTTP, infinite. Block (EBS) = raw, low-latency, per-VM. File (EFS/HDFS) = POSIX, shared. HDFS: 128MB blocks, 3× replica, NameNode metadata. S3: 11 nines durability via cross-AZ + EC. Lifecycle policies save huge cost. Don't use S3 as a DB.

---

## 🔗 Cross-Topic Connections
- **CDN**: object storage + CDN is the canonical static-asset stack.
- **Databases**: use block storage.
- **Batch processing**: HDFS/S3 is the input+output store.
- **Video**: segments stored in object storage.

---

### Confidence Check
- [ ] Can I pick storage type per workload?
- [ ] Can I reason about durability vs cost?

### Gaps
- CRUSH algorithm in Ceph.
- S3 internals (Anna-like sharding).

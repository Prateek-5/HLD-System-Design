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
- **Tiered storage (hot / warm / cold)** — automatically moves rarely-read data to cheaper, slower media (e.g., AWS S3 standard → Glacier); matters because it cuts storage cost without deleting data.
- **Lifecycle policies** — rules that auto-transition or expire objects by age (e.g., move to cold tier after 30 days, delete after a year); key for controlling long-term storage spend.
- **Versioning** — keeps prior copies of an object when it is overwritten or deleted, so you can recover from mistakes; the backbone of accidental-delete protection.
- **Retention** — enforces how long data must (or must not) be kept, often for legal/compliance reasons; relevant to any "audit log" or regulated-data question.
- **Erasure coding (Reed-Solomon)** — splits data into chunks plus parity so the original survives losing some chunks, using far less space than full replication; how object stores get durability cheaply.

**🔧 How to close:** Run `aws s3api put-bucket-lifecycle-configuration` (or MinIO `mc ilm rule add`) on a local MinIO container to expire objects after 1 day, upload a file, then list it again to watch the policy take effect: `docker run -p 9000:9000 minio/minio server /data` and experiment with `mc`.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🌡️ Gap 1 — Storage Tiers & Lifecycle Policies
- 🔹 **What it is**: Automatically moving data between hot (fast, expensive), warm, and cold (slow, cheap) tiers based on age or access frequency, driven by declarative rules.
- 🔹 **Why it matters**: Storage cost is dominated by *where* data sits, not how much you have. A lifecycle rule that ages logs from S3 Standard → Glacier can cut a bill by 80% without deleting anything.
- 🔹 **Connection**: This file's Mini Design keeps photos in object storage forever; in reality rarely-viewed photos and thumbnails should drift to a colder tier. Lifecycle policies are how you operationalize that.
- 🔹 **When needed**: 🟢 **Foundational** — almost every cloud system uses lifecycle rules, and it is a cheap, high-signal answer to any cost-optimization question.
- 🔹 **Intuition**: Your kitchen counter (hot) holds today's food, the fridge (warm) holds this week's, and the chest freezer in the garage (cold) holds the bulk you rarely touch — same food, very different cost and reach-time.
- 🔹 **If you go deeper**: Read AWS S3 lifecycle configuration docs and the S3 Intelligent-Tiering and Glacier Deep Archive pages; compare with GCS storage classes (Standard/Nearline/Coldline/Archive).
- 🔹 **Interview hook**: *"We store 5 years of audit logs but only query the last 30 days — how do you cut cost?"* → Lifecycle rule transitioning objects to cold archive after 30 days, with restore-on-demand for the rare old query.

---

#### 🛡️ Gap 2 — Versioning & Retention (WORM / Object Lock)
- 🔹 **What it is**: Versioning keeps prior copies when an object is overwritten or deleted; retention (WORM — Write Once Read Many / Object Lock) makes data immutable for a fixed period so even an admin cannot alter it.
- 🔹 **Why it matters**: It is your defense against accidental deletes, ransomware, and the source of truth for compliance (SEC, HIPAA, GDPR audit trails). Interviewers probe this whenever "regulated data" or "audit log" comes up.
- 🔹 **Connection**: The Red flags warn against losing data; versioning + retention are the concrete mechanisms that make object storage a safe system of record, not just a blob dump.
- 🔹 **When needed**: 🟡 **Mid-level** — common in product and compliance-flavored design rounds once you are past the block/file/object basics.
- 🔹 **Intuition**: A bank safe-deposit box on a legal hold — once sealed for the retention period, not even the bank manager can open it, and every prior statement is kept on file.
- 🔹 **If you go deeper**: Read S3 Versioning + S3 Object Lock (Governance vs Compliance mode) docs; look at how legal holds suspend lifecycle expiration.
- 🔹 **Interview hook**: *"How do you guarantee 7 years of trade records can't be tampered with?"* → Object Lock in Compliance mode with a 7-year retention period, which overrides delete and overwrite.

---

#### 🧩 Gap 3 — Erasure Coding vs Replication for Durability
- 🔹 **What it is**: Splitting an object into *k* data chunks plus *m* parity chunks (Reed-Solomon) so it survives losing any *m* chunks, achieving high durability with far less storage overhead than keeping 3 full copies.
- 🔹 **Why it matters**: Replication of 3x means 200% overhead; erasure coding can hit the same durability at ~40-50% overhead. This is how object stores offer "11 nines" durability affordably.
- 🔹 **Connection**: Section C teaches RAID parity and HDFS's 3x replication — erasure coding is the web-scale generalization of both, trading CPU (encode/decode math) for cheaper storage.
- 🔹 **When needed**: 🔴 **Senior** — relevant for storage-infra and distributed-systems depth rounds; most app developers only need to know it exists.
- 🔹 **Intuition**: Instead of photocopying a document three times, you shred it into 10 strips plus 4 "checksum" strips; lose any 4 strips and you can still reconstruct the original from what's left.
- 🔹 **If you go deeper**: Read the original Reed-Solomon coding concept, then Facebook's "f4: Facebook's Warm BLOB Storage System" paper and the Azure Storage erasure-coding (LRC — Local Reconstruction Codes) USENIX paper.
- 🔹 **Interview hook**: *"Why don't large object stores just keep 3 replicas like HDFS?"* → Erasure coding gives equivalent durability at roughly a third of the storage cost, paying with extra CPU and reconstruction latency.

---

### 🏆 Start here if you have limited time
1. **Storage tiers & lifecycle policies** — the highest-leverage, broadly-applicable answer; shows up in nearly every cost-optimization discussion.
2. **Versioning & retention** — quick to grasp and the go-to answer for any compliance or accidental-delete question.

---

### 🧭 Suggested Deep Dive Order
1. **Storage tiers & lifecycle policies** (~30 min; immediate cost-optimization payoff and a reusable interview answer).
2. **Versioning & retention / Object Lock** (~45 min; unlocks compliance and data-safety questions).
3. **Erasure coding vs replication** (~1h; senior-infra durability signaling, ties RAID and HDFS together).

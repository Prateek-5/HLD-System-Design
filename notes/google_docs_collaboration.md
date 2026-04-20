# Google Docs — Real-Time Collaborative Editing

### 🔹 1. What This Topic Actually Is
Multiple users edit the same document simultaneously, all seeing each other's edits in near-real-time, with convergence + intent preservation guaranteed.

### 🔹 2. Why It Exists
- Naive "last write wins" on a shared doc loses edits; full locking kills collaboration.
- Need algorithms that merge concurrent edits deterministically.

### 🔹 3. Core Concepts (High Signal)
- **Operational Transformation (OT)**: each edit = an operation; server transforms incoming op against concurrent ops so all clients converge. Classic Google Wave / Docs algorithm.
- **CRDT (Conflict-free Replicated Data Types)**: data structures designed so any replica can apply ops in any order and converge (e.g., RGA, LSEQ for text). Simpler than OT, used by Figma, Riak, Yjs, Automerge.
- **Operation types (text)**: insert(pos, char), delete(pos, len).
- **Transform function**: given op A and op B, transforms op A such that applying A' after B is equivalent to applying A then B′.
- **Vector clocks / Lamport timestamps**: order concurrent ops causally.
- **Persistence**: store ops stream + periodic snapshots.
- **Intent preservation**: user's semantic intention (bold this word) survives concurrent edits.

### 🔹 4. Internal Working (OT in Docs)
1. Client generates op locally, applies to local doc, sends to server.
2. Server receives ops from all clients; maintains authoritative op stream.
3. On receiving op B while op A is outstanding, server transforms B against A, broadcasts transformed B to all clients.
4. Clients also transform received ops against local pending ops before applying.

**Failure points:** OT is notoriously hard to get right (papers + bugs span decades); CRDTs have space overhead; network partitions + merging; cursor position drift.

### 🔹 5. Key Tradeoffs
- **OT**: proven, central server, scales with a single authoritative server per doc.
- **CRDT**: decentralized, P2P-capable, but more memory per op.
- **Locking**: simple but defeats collaboration.

### 🔹 6. Interview Questions
**Beginner**
1. What problem does OT/CRDT solve?

**Intermediate**
1. OT vs CRDT — tradeoffs?
2. How do you handle an offline user's 100 pending ops on reconnect?

**Advanced**
1. Design Google Docs at 100 concurrent users per doc.
2. Design Figma (2D canvas) — why CRDT? (Easier semantics for arbitrary-typed objects, supports presence + offline.)

### 🔹 7. Real System Mapping
- **Google Docs / Wave**: OT.
- **Figma**: CRDT.
- **Apple Notes collaboration**: CRDT.
- **Yjs, Automerge**: open-source CRDT libs.

### 🔹 8. What Most People Miss
- **Docs-scale OT uses a central authority** — not pure P2P OT (which has known correctness issues).
- **Presence info (cursors, selections)** is ephemeral and handled out-of-band via pub-sub — not part of the doc state.
- **Offline support** is hard — long-pending ops must transform against N committed ops on reconnect. Server must keep history.
- **Scalability per doc**: 100+ concurrent editors becomes pathological for OT; chunk the doc or limit.
- **CRDTs add ~2× storage overhead** for tombstones and metadata.

### 🔹 9. 30-Second Revision
Real-time collaboration = OT (Google) or CRDT (Figma). OT = central server transforms ops to converge. CRDT = math-guaranteed merge, P2P-capable. Presence (cursors) is out-of-band pub-sub. Storage = op stream + snapshots. Hard to scale past ~100 concurrent editors per doc.

---

## 🔗 Cross-Topic Connections
- **Real-time push (WebSocket)**: ops transport.
- **Messaging**: event log of ops.
- **Databases**: persistent op log + snapshots.
- **Caching**: recent docs / presence cached.

---

### Confidence Check
- [ ] Can I pick OT vs CRDT for a given product?
- [ ] Can I reason about offline reconnect?

### Gaps
- Formal OT transform function correctness proofs.
- CRDT types beyond text (RGA, Lww-Set, ORSet).


# 🚀 SYSTEM: Hybrid RAG + Graph + Wiki Memory (Offline, Flutter)

---
ToStore package link https://pub.dev/packages/tostore/versions/3.1.0
# 1) 📥 DATA INGEST (When Note is Saved)

## Flow

```text
User saves note
   ↓
SaveNoteUseCase → Isar (raw note)
   ↓
EmbeddingService (MiniLM)
   ↓
Store embedding → Tostore
   ↓
Vector search → find top similar notes
   ↓
Gemma (LLM) → extract:
   - entities
   - relations
   - summary
   - concepts
   ↓
Store graph + memory (Isar)
```

---

# 2) 🧱 DATA STORAGE DESIGN

---

## A) Raw Notes (Isar)

```text
SavedNote
- id
- content
- createdAt
```

---

## B) Vector Store (Tostore)

```text
VectorIndex
- noteId
- embedding (384 dim)
```

👉 Used ONLY for similarity search

---

## C) Graph Storage (Isar)

### GraphNode

```text
- id (normalized key)
- name (e.g., "Isar")
- type (e.g., "Database", "Tech", "Concept")
```

---

### GraphEdge

```text
- id
- sourceId
- targetId
- relationType (normalized string)
```

---

## D) Wiki / Memory Layer (Isar)

### MemoryNode

```text
- noteId
- summary (2–4 lines)
- keyPoints (list)
- concepts (list)
- linkedNoteIds (list)
- updatedAt
```

👉 This is your **AI knowledge layer (wiki-like)**

---

# 3) 🧠 RELATION + MEMORY CREATION

---

## Step 1: Get similar notes

```text
new note → embedding
   ↓
Tostore → top 5 similar notes
```

---

## Step 2: LLM extraction (Gemma)

Input:

```text
- new note
- small context (top similar notes)
```

Output:

```json
{
  "summary": "...",
  "concepts": ["Flutter", "Isar"],
  "relations": [
    {"source": "App", "target": "Isar", "type": "uses_db"}
  ],
  "links": ["noteId1", "noteId2"]
}
```

---

## Step 3: Store

```text
→ GraphNode (entities)
→ GraphEdge (relations)
→ MemoryNode (summary + concepts + links)
```

---

# 4) 🔍 QUERY TIME PIPELINE

---

## Step 1: Query embedding

```text
user query → MiniLM → vector
```

---

## Step 2: Vector retrieval

```text
Tostore → top 3–5 notes
```

---

## Step 3: Graph expansion

```text
start from noteIds
   ↓
Isar → get neighbors (1 hop)
   ↓
max 5–8 nodes
```

---

## Step 4: Memory retrieval

```text
fetch MemoryNode for:
- top notes
- expanded nodes
```

---

## Step 5: Context building (IMPORTANT)

```text
User Query

Top Notes (3–5, short snippets)
+
Graph Relations (few)
+
Summaries (short)
```

👉 Keep it **small and relevant**

---

## Step 6: Final LLM call

```text
Gemma → answer generation
```

---

# 5) 🧠 CONTEXT RULES (VERY IMPORTANT)

* Max notes: **3–5**
* Graph depth: **1 hop**
* Graph nodes: **≤ 8**
* Summary length: **≤ 4 lines**

> Less context = better answers

---

# 6) 🔄 UPDATE STRATEGY

---

## On Note Save

* embedding created
* graph updated
* memory created

---

## Background Jobs (optional)

```text
- refine summaries
- merge duplicate concepts
- normalize relations
- update links
```

---

# 7) 🏗️ FINAL ARCHITECTURE

```text
                ┌──────────────┐
                │   User Query │
                └──────┬───────┘
                       ↓
                Embedding (MiniLM)
                       ↓
                Tostore (Vector Search)
                       ↓
              Top Relevant Notes
                       ↓
                Isar Graph Expand
                       ↓
              Memory (Summaries)
                       ↓
                Context Builder
                       ↓
                  Gemma LLM
                       ↓
                    Answer
```

---

# 8) 🔑 KEY DESIGN DECISIONS

---

## Why Tostore?

* fast vector search
* avoids full scan

---

## Why Isar for Graph + Wiki?

* local
* flexible
* fast for relations

---

## Why Gemma?

* relation extraction
* summary generation
* reasoning

---

## Why not only Wiki?

* loses detail
* not real-time

---

## Why not only RAG?

* no structure
* weak relationships

---

# 9) 🧾 FINAL SUMMARY

> **Your system combines:**

* Vector search → find relevant data
* Graph → understand relationships
* Wiki memory → structured knowledge
* LLM → reasoning

---

# 🔥 One-line system definition

> **“Hybrid GraphRAG + AI Memory system using Isar (graph), Tostore (vector), and Gemma (reasoning)”**

---
What you SHOULD implement
1) Dynamic context length (important)

Different models → different limits

small model → less context
big model → more context
Example config:
Gemma small → 2K tokens
Gemma large → 8K tokens
2) Context budget system (THIS is key)

Instead of percentages, use a token budget split

Total context = 100%
Recommended split:
User Query         → 5–10%
Recent Chat        → 20–25%
Top Notes (RAG)    → 30–40%
Graph Relations    → 15–20%
Summaries (Wiki)   → 10–20%

👉 This is much better than hardcoding counts.

3) Dynamic scaling

Instead of fixed numbers like:

top 5 notes

Do:

based on remaining tokens

Example:

if more space:
   include more notes
else:
   include fewer notes
4) Ranking priority (VERY IMPORTANT)

When trimming context:

Priority order:
1. User query (always)
2. Top 1–2 notes
3. Strong relations
4. Remaining notes
5. Old chat history


in future we will provide the api option also 
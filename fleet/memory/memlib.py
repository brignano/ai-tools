"""Shared pieces of fleet memory (proposals/fleet-memory.md, decisions/0006).

Standard library only: the loader runs at every session start, on any machine,
and the workflows run on a stock runner with no install step.
"""
import os
import re

MAX_CHARS = 500          # per memory body
MAX_LINES = 4            # per memory body
BUDGET_BYTES = 12 * 1024  # everything the loader prints

SLUG = re.compile(r"^[a-z0-9][a-z0-9-]{0,59}$")
PATH = re.compile(r"^memory/[a-z0-9][a-z0-9-]{0,59}\.md$")
TOPIC = re.compile(r"^[a-z0-9][a-z0-9-]{0,29}$")
SOURCE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(#\d+)?$")
SESSION = re.compile(r"^https://claude\.ai/\S+$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
KEYS = ("topic", "from", "session", "added")

# A memory that needs any of these is a rule, and rules wait for Anthony.
# Matched case-insensitively on word boundaries.
MARKERS = (
    "ignore", "disregard", "run", "execute", "curl", "wget", "token", "password",
    "secret", "api key", "credential", "always", "never", "you must",
    "system prompt", "instruction", "install", "download", "upload", "send to",
    "email to", "post to", "delete", "override",
)
MARKER_RE = re.compile(r"\b(" + "|".join(re.escape(m) for m in MARKERS) + r")\b", re.I)
LINK_RE = re.compile(r"(https?:|ftp:|www\.|://|\]\(|\[[^\]]*\]\s*\[|<\s*[a-z!/])", re.I)
CODE_RE = re.compile(r"[`]|^\s{4,}\S|^\s*```", re.M)


def split(text):
    """(frontmatter dict, body) of a memory file. Missing frontmatter -> ({}, text)."""
    text = text.replace("\r\n", "\n")
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    if not m:
        return {}, text.strip()
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip()
    return meta, m.group(2).strip()


def normalise(fact):
    """Lowercase, punctuation stripped, whitespace collapsed: for duplicate checks."""
    return " ".join(re.sub(r"[^a-z0-9 ]+", " ", (fact or "").lower()).split())


def body_problems(body):
    """Reasons a memory body can't merge on its own. Empty list = fine."""
    out = []
    if not body.strip():
        out.append("the fact is empty")
    if len(body) > MAX_CHARS:
        out.append(f"the fact is {len(body)} characters; the limit is {MAX_CHARS}")
    lines = [l for l in body.splitlines() if l.strip()]
    if len(lines) > MAX_LINES:
        out.append(f"the fact is {len(lines)} lines; the limit is {MAX_LINES}")
    if LINK_RE.search(body):
        out.append("the fact contains a link or HTML")
    if CODE_RE.search(body):
        out.append("the fact contains code or backticks")
    hits = sorted({h.lower() for h in MARKER_RE.findall(body)})
    if hits:
        out.append("the fact uses instruction words (" + ", ".join(hits) + "), so it reads as a rule")
    return out


def meta_problems(meta):
    out = []
    missing = [k for k in KEYS if not meta.get(k)]
    if missing:
        out.append("frontmatter is missing " + ", ".join(missing))
    checks = (("topic", TOPIC), ("from", SOURCE), ("session", SESSION), ("added", DATE))
    for key, rx in checks:
        if meta.get(key) and not rx.match(meta[key]):
            out.append(f"frontmatter `{key}` is not in the expected shape")
    extra = sorted(set(meta) - set(KEYS))
    if extra:
        out.append("frontmatter has unexpected keys: " + ", ".join(extra))
    return out


def render(meta, body):
    head = "\n".join(f"{k}: {meta[k]}" for k in KEYS)
    return f"---\n{head}\n---\n{body.strip()}\n"


def slugify(fact, taken=()):
    slug = ""
    for w in normalise(fact).split()[:8]:
        if len(slug) + len(w) + 1 > 50:
            break
        slug = f"{slug}-{w}" if slug else w
    slug = slug[:50] or "memory"
    base, n = slug, 2
    while slug in taken:
        slug = f"{base}-{n}"
        n += 1
    return slug


def read_folder(folder):
    """[(slug, meta, body)] for every memory file, README excluded."""
    out = []
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return out
    for name in names:
        if not name.endswith(".md") or not SLUG.match(name[:-3]):
            continue
        try:
            with open(os.path.join(folder, name), encoding="utf-8") as f:
                meta, body = split(f.read())
        except (OSError, UnicodeDecodeError):
            continue
        out.append((name[:-3], meta, body))
    return out


# ---- issue form ----------------------------------------------------------

FIELDS = {
    "fact": "Fact",
    "quote": "Anthony's words",
    "topic": "Topic",
    "from": "From",
    "session": "Session",
    "replaces": "Replaces",
}
REQUIRED = ("fact", "quote", "topic", "from", "session")


def parse_form(body):
    """Fields of a memory issue body, as rendered by .github/ISSUE_TEMPLATE/memory.yml
    (a `### Heading` per field; GitHub writes `_No response_` for blanks)."""
    sections, current = {}, None
    for line in (body or "").replace("\r\n", "\n").split("\n"):
        m = re.match(r"^###\s+(.+?)\s*$", line)
        if m:
            current = m.group(1).strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    out = {}
    for key, heading in FIELDS.items():
        raw = "\n".join(sections.get(heading, [])).strip()
        if raw == "_No response_":
            raw = ""
        out[key] = raw
    # The quote is a `>` block; keep only its words.
    out["quote"] = "\n".join(re.sub(r"^\s*>\s?", "", l) for l in out["quote"].splitlines()).strip()
    out["fact"] = " ".join(out["fact"].split())
    for key in ("topic", "from", "session", "replaces"):
        out[key] = out[key].split("\n")[0].strip()
    out["topic"] = out["topic"].lower()
    return out


def form_problems(form):
    """Missing or malformed fields. A forget request (Replaces + empty Fact) needs no Fact."""
    out = []
    forget = bool(form.get("replaces")) and not form.get("fact")
    for key in REQUIRED:
        if key == "fact" and forget:
            continue
        if not form.get(key):
            out.append(f"**{FIELDS[key]}** is empty")
    if form.get("topic") and not TOPIC.match(form["topic"]):
        out.append("**Topic** should be one short lowercase word, like `hosting`")
    if form.get("from") and not SOURCE.match(form["from"]):
        out.append("**From** should be `owner/repo#N` or `owner/repo`")
    if form.get("session") and not SESSION.match(form["session"]):
        out.append("**Session** should be a claude.ai session link")
    if form.get("replaces") and not SLUG.match(form["replaces"]):
        out.append("**Replaces** should be the slug of a file in `memory/` (no `.md`)")
    return out

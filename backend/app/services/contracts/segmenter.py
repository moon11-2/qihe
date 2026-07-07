"""Contract text segmenter – splits full contract text into structured blocks.

Identifies headings, clause numbers, and plain paragraphs.
Generates stable block_ids and preserves start_offset/end_offset.
"""

from __future__ import annotations

import hashlib
import re

from app.models.contracts import ContractBlock

# Patterns for clause numbering / headings
_CLAUSE_PATTERNS = [
    re.compile(r"^(第[一二三四五六七八九十百千0-9]+条)\s*(.*)"),       # 第X条
    re.compile(r"^(第[一二三四五六七八九十百千0-9]+章)\s*(.*)"),       # 第X章
    re.compile(r"^(第[一二三四五六七八九十百千0-9]+节)\s*(.*)"),       # 第X节
    re.compile(r"^([一二三四五六七八九十]+)[、，,]\s*(.*)"),            # 一、二、
    re.compile(r"^（([一二三四五六七八九十]+)）\s*(.*)"),              # （一）（二）
    re.compile(r"^(\d+)[.、)]\s*(.*)"),                             # 1. 2、3)
]

_EMPTY_LINE = re.compile(r"\n\s*\n")


def segment_text(text: str, document_id: str | None = None) -> list[ContractBlock]:
    """Split contract text into ordered blocks.

    Returns a list of ContractBlock with stable block_ids, titles,
    and character offsets.
    """
    if not text.strip():
        return []

    paragraphs = _split_paragraphs(text)
    blocks: list[ContractBlock] = []
    offset = 0

    for para in paragraphs:
        para_text = para.strip()
        if not para_text:
            continue

        start_offset = text.find(para_text, offset)
        if start_offset == -1:
            start_offset = offset
        end_offset = start_offset + len(para_text)

        block_type, title = _classify_paragraph(para_text)
        block_id = _make_block_id(document_id or "", para_text, len(blocks))

        blocks.append(
            ContractBlock(
                block_id=block_id,
                order=len(blocks),
                title=title,
                text=para_text,
                start_offset=start_offset,
                end_offset=end_offset,
                type=block_type,
            )
        )
        offset = end_offset + 1  # skip the newline after paragraph

    return blocks


def find_block_for_offset(
    blocks: list[ContractBlock],
    offset: int,
) -> ContractBlock | None:
    """Find the block that contains the given character offset."""
    for block in blocks:
        if block.start_offset is not None and block.end_offset is not None:
            if block.start_offset <= offset < block.end_offset:
                return block
    return None


def _split_paragraphs(text: str) -> list[str]:
    """Split text into logical paragraphs."""
    # Normalize line endings
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    # Split on empty lines or single newlines (keep numbered items together)
    raw = _EMPTY_LINE.split(text)
    result: list[str] = []
    for part in raw:
        part = part.strip()
        if not part:
            continue
        # Further split very long paragraphs on newlines
        lines = part.split("\n")
        if len(lines) > 1:
            # Try to keep related lines together but split on clear boundaries
            current: list[str] = []
            for line in lines:
                line = line.strip()
                if not line:
                    if current:
                        result.append("\n".join(current))
                        current = []
                    continue
                # Check if this line starts a new clause
                if current and _is_new_clause_start(line):
                    result.append("\n".join(current))
                    current = [line]
                else:
                    current.append(line)
            if current:
                result.append("\n".join(current))
        else:
            result.append(part)
    return result


def _is_new_clause_start(line: str) -> bool:
    """Check if a line looks like the start of a new clause/section."""
    for pattern in _CLAUSE_PATTERNS:
        if pattern.match(line):
            return True
    return False


def _classify_paragraph(text: str) -> tuple[str, str | None]:
    """Classify paragraph type and extract title if present."""
    for pattern in _CLAUSE_PATTERNS:
        match = pattern.match(text)
        if match:
            prefix = match.group(1)
            rest = match.group(2).strip() if match.lastindex and match.lastindex >= 2 else ""
            title = f"{prefix} {rest}" if rest else prefix
            return "clause", title

    return "general", None


def _make_block_id(document_id: str, text: str, order: int) -> str:
    """Generate a stable block_id."""
    digest = hashlib.sha256(f"{document_id}:{order}:{text[:80]}".encode()).hexdigest()[:12]
    return f"block_{digest}"

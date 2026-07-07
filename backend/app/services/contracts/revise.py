"""Apply and confirm revision suggestions for contract blocks."""

from __future__ import annotations

from uuid import uuid4

from app.models.contracts import ContractRevision


def create_revision(
    block_id: str,
    before_text: str,
    after_text: str,
    risk_id: str | None = None,
    source: str = "user",
) -> ContractRevision:
    """Create a new draft revision for a block."""
    return ContractRevision(
        revision_id=f"rev_{uuid4().hex[:12]}",
        block_id=block_id,
        risk_id=risk_id,
        before_text=before_text,
        after_text=after_text,
        source=source,  # type: ignore[arg-type]
        status="draft",
    )


def apply_revision_to_text(
    original_text: str,
    block_id: str,
    before_text: str,
    after_text: str,
    start_offset: int | None = None,
) -> tuple[str, ContractRevision]:
    """Apply a text change to a specific block and return new full text + revision record."""
    revision = create_revision(
        block_id=block_id,
        before_text=before_text,
        after_text=after_text,
        source="user",
    )

    if start_offset is not None and before_text in original_text:
        new_text = original_text.replace(before_text, after_text, 1)
    elif before_text in original_text:
        new_text = original_text.replace(before_text, after_text, 1)
    else:
        new_text = original_text + "\n" + after_text

    return new_text, revision


def confirm_revision(revision: ContractRevision) -> ContractRevision:
    """Confirm a draft revision."""
    return ContractRevision(
        revision_id=revision.revision_id,
        block_id=revision.block_id,
        risk_id=revision.risk_id,
        before_text=revision.before_text,
        after_text=revision.after_text,
        source=revision.source,
        status="confirmed",
    )

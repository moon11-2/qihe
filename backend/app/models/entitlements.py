"""Entitlement, credit, activation code, and StoreKit models."""

from __future__ import annotations

from pydantic import BaseModel, Field, field_validator


class CreditBalance(BaseModel):
    user_id: int
    balance: int
    created_at: str
    updated_at: str


class CreditTransaction(BaseModel):
    id: int | None = None
    user_id: int
    amount: int
    reason: str
    reference_id: str | None = None
    job_id: str | None = None
    created_at: str | None = None


class ActivateRequest(BaseModel):
    code: str = Field(min_length=1, max_length=128)

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str) -> str:
        return value.strip().upper()


class ActivateResponse(BaseModel):
    message: str
    credits_added: int
    balance: int


class StoreKitTransactionRequest(BaseModel):
    transaction_id: str
    product_id: str
    raw_payload: dict | None = None


class StoreKitTransactionResponse(BaseModel):
    message: str
    credits_added: int
    balance: int

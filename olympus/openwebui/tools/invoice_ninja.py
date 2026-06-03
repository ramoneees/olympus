"""
title: Invoice Ninja
description: Manage clients, invoices, and payments in Invoice Ninja.
author: OLYMPUS
version: 0.1.0
license: MIT
"""

import json
import requests
from pydantic import BaseModel, Field


class Tools:
    class Valves(BaseModel):
        base_url: str = Field(
            default="https://invoices.ramoneees.com",
            description="Invoice Ninja base URL",
        )
        api_token: str = Field(default="", description="Invoice Ninja API token")

    def __init__(self):
        self.valves = self.Valves()

    def _get(self, path: str, params: dict = None) -> dict:
        resp = requests.get(
            f"{self.valves.base_url.rstrip('/')}/api/v1/{path}",
            headers={"X-Api-Token": self.valves.api_token, "Accept": "application/json"},
            params=params or {},
            timeout=15,
        )
        resp.raise_for_status()
        return resp.json()

    def _post(self, path: str, body: dict) -> dict:
        resp = requests.post(
            f"{self.valves.base_url.rstrip('/')}/api/v1/{path}",
            headers={"X-Api-Token": self.valves.api_token, "Content-Type": "application/json"},
            json=body,
            timeout=15,
        )
        resp.raise_for_status()
        return resp.json()

    def list_clients(self, search: str = "") -> str:
        """
        List clients in Invoice Ninja.
        :param search: Optional search term to filter clients by name
        :return: List of clients with id, name, and email
        """
        if not self.valves.api_token:
            return "Error: API token not configured."
        params = {"filter": search} if search else {}
        data = self._get("clients", params)
        clients = data.get("data", [])
        if not clients:
            return "No clients found."
        lines = [f"Found {len(clients)} client(s):\n"]
        for c in clients[:20]:
            lines.append(f"- [{c['id']}] {c.get('display_name', 'N/A')} — {c.get('contacts', [{}])[0].get('email', 'no email')}")
        return "\n".join(lines)

    def list_invoices(self, status: str = "", client_id: str = "") -> str:
        """
        List invoices in Invoice Ninja.
        :param status: Filter by status: draft, sent, partial, paid, overdue
        :param client_id: Filter by client ID
        :return: List of invoices with id, number, client, amount, and status
        """
        if not self.valves.api_token:
            return "Error: API token not configured."
        params = {}
        if status:
            params["invoice_status"] = status
        if client_id:
            params["client_id"] = client_id
        data = self._get("invoices", params)
        invoices = data.get("data", [])
        if not invoices:
            return "No invoices found."
        lines = [f"Found {len(invoices)} invoice(s):\n"]
        for inv in invoices[:20]:
            lines.append(
                f"- [{inv['id']}] #{inv.get('number', 'N/A')} | "
                f"{inv.get('client', {}).get('display_name', 'unknown')} | "
                f"€{inv.get('amount', 0):.2f} | {inv.get('status_id', '?')}"
            )
        return "\n".join(lines)

    def create_invoice(self, client_id: str, line_items_json: str, due_date: str = "") -> str:
        """
        Create a new invoice in Invoice Ninja.
        :param client_id: The client ID to invoice
        :param line_items_json: JSON array of line items, e.g. [{"product_key": "Consulting", "notes": "Work done", "cost": 100, "quantity": 1}]
        :param due_date: Due date in YYYY-MM-DD format (optional)
        :return: Created invoice details
        """
        if not self.valves.api_token:
            return "Error: API token not configured."
        try:
            line_items = json.loads(line_items_json)
        except json.JSONDecodeError:
            return "Error: line_items_json must be valid JSON."
        body = {"client_id": client_id, "line_items": line_items}
        if due_date:
            body["due_date"] = due_date
        data = self._post("invoices", body)
        inv = data.get("data", {})
        return f"Invoice created: #{inv.get('number', 'N/A')} | ID: {inv.get('id')} | Amount: €{inv.get('amount', 0):.2f}"

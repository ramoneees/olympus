"""
title: n8n Workflow Trigger
description: Trigger n8n workflows via webhook. Useful for kicking off automations from chat.
author: OLYMPUS
version: 0.1.0
license: MIT
"""

import json
import requests
from pydantic import BaseModel, Field


class Tools:
    class Valves(BaseModel):
        n8n_base_url: str = Field(
            default="https://n8n.ramoneees.com",
            description="Base URL of your n8n instance",
        )
        webhook_auth_header: str = Field(
            default="",
            description="Optional auth header value for secured webhooks (e.g. Bearer token)",
        )

    def __init__(self):
        self.valves = self.Valves()

    def trigger_webhook(
        self,
        webhook_path: str,
        payload: str = "{}",
    ) -> str:
        """
        Trigger an n8n webhook workflow.
        :param webhook_path: Webhook path (e.g. 'my-workflow' or full path like 'webhook/abc123')
        :param payload: JSON string with data to send to the workflow
        :return: Response from n8n
        """
        # Normalise path
        path = webhook_path.lstrip("/")
        if not path.startswith("webhook"):
            path = f"webhook/{path}"

        url = f"{self.valves.n8n_base_url.rstrip('/')}/{path}"

        try:
            body = json.loads(payload)
        except json.JSONDecodeError:
            body = {"message": payload}

        headers = {"Content-Type": "application/json"}
        if self.valves.webhook_auth_header:
            headers["Authorization"] = self.valves.webhook_auth_header

        resp = requests.post(url, json=body, headers=headers, timeout=30)

        if resp.status_code in (200, 201):
            try:
                result = resp.json()
                return f"Workflow triggered successfully.\nResponse: {json.dumps(result, indent=2)}"
            except Exception:
                return f"Workflow triggered successfully. Status: {resp.status_code}"
        else:
            return f"Error triggering workflow. Status {resp.status_code}: {resp.text}"

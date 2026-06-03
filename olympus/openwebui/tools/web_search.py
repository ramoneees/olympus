"""
title: Web Search (Brave)
description: Search the web using Brave Search API. Returns top results with titles, URLs, and descriptions.
author: OLYMPUS
version: 0.1.0
license: MIT
"""

import requests
from pydantic import BaseModel, Field


class Tools:
    class Valves(BaseModel):
        brave_api_key: str = Field(default="", description="Brave Search API key")
        max_results: int = Field(default=5, description="Number of results to return (1-10)")

    def __init__(self):
        self.valves = self.Valves()

    def web_search(self, query: str) -> str:
        """
        Search the web for current information using Brave Search.
        :param query: The search query
        :return: Formatted search results with titles, URLs, and snippets
        """
        if not self.valves.brave_api_key:
            return "Error: Brave API key not configured. Set it in Admin → Tools → Web Search → Valves."

        resp = requests.get(
            "https://api.search.brave.com/res/v1/web/search",
            headers={
                "Accept": "application/json",
                "Accept-Encoding": "gzip",
                "X-Subscription-Token": self.valves.brave_api_key,
            },
            params={"q": query, "count": min(self.valves.max_results, 10)},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()

        results = data.get("web", {}).get("results", [])
        if not results:
            return f"No results found for: {query}"

        lines = [f"Search results for: {query}\n"]
        for i, r in enumerate(results, 1):
            lines.append(f"{i}. **{r.get('title', 'No title')}**")
            lines.append(f"   {r.get('url', '')}")
            lines.append(f"   {r.get('description', 'No description')}\n")

        return "\n".join(lines)

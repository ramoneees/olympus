"""
title: MiniMax Video Generation
author: OLYMPUS
description: Generate short videos using MiniMax Hailuo 2.3 (text-to-video). Provide a scene description.
version: 1.0.0
license: MIT
"""

import os
import time
import requests
from typing import Optional


class Tools:
    def __init__(self):
        pass

    def generate_video(
        self,
        prompt: str,
        duration: int = 6,
        resolution: str = "1080P",
    ) -> str:
        """
        Generate a short video using MiniMax Hailuo 2.3. Use this when the user asks to create or generate a video.
        This takes 1-3 minutes — the user should wait for the result.
        :param prompt: Scene description, up to 2000 characters. Example: 'A golden retriever runs through a sunlit meadow, slow motion'.
        :param duration: Length in seconds. Options: 6 or 10. Default 6.
        :param resolution: Video quality. Options: '1080P', '768P', '512P'. Default '1080P'.
        :return: A download link for the generated video, or an error message.
        """
        api_key = os.environ.get("MINIMAX_API_KEY", "")
        if not api_key:
            return "Error: MINIMAX_API_KEY is not configured."

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

        # Step 1: Submit the generation task
        try:
            resp = requests.post(
                "https://api.minimax.io/v1/video_generation",
                json={
                    "model": "MiniMax-Hailuo-2.3",
                    "prompt": prompt,
                    "duration": duration,
                    "resolution": resolution,
                    "prompt_optimizer": True,
                },
                headers=headers,
                timeout=30,
            )
            resp.raise_for_status()
            data = resp.json()
        except requests.RequestException as e:
            return f"Error submitting video task: {e}"

        if data.get("base_resp", {}).get("status_code", -1) != 0:
            msg = data.get("base_resp", {}).get("status_msg", "Unknown error")
            return f"MiniMax error: {msg}"

        task_id = data.get("task_id")
        if not task_id:
            return "Error: No task ID returned."

        # Step 2: Poll for completion (up to ~3 minutes, every 5s)
        file_id = None
        for _ in range(36):
            time.sleep(5)
            try:
                poll = requests.get(
                    "https://api.minimax.io/v1/query/video_generation",
                    params={"task_id": task_id},
                    headers=headers,
                    timeout=15,
                )
                poll.raise_for_status()
                result = poll.json()
            except requests.RequestException as e:
                return f"Error polling task status: {e}"

            status = result.get("status", "")
            if status == "Success":
                file_id = result.get("file_id")
                break
            elif status == "Fail":
                return "Video generation failed. Try rephrasing your prompt."
            # Preparing / Queueing / Processing — keep waiting

        if not file_id:
            return (
                f"Video is still processing (task_id: `{task_id}`). "
                "It may be ready in a few minutes — try asking me to check the status."
            )

        # Step 3: Retrieve the download URL
        try:
            file_resp = requests.get(
                "https://api.minimax.io/v1/files/retrieve",
                params={"file_id": file_id},
                headers=headers,
                timeout=15,
            )
            file_resp.raise_for_status()
            file_data = file_resp.json()
        except requests.RequestException as e:
            return f"Error retrieving file: {e}"

        download_url = file_data.get("file", {}).get("download_url", "")
        if not download_url:
            return f"Error: Could not get download URL (file_id: {file_id})."

        return (
            f"**Video ready!** ({duration}s, {resolution})\n\n"
            f"[Download Video]({download_url})\n\n"
            f"> The download link expires after a short time — save it quickly!"
        )

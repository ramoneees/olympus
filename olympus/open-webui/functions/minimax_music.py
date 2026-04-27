"""
title: MiniMax Music Generation
author: OLYMPUS
description: Generate music using MiniMax Music-2.6. Provide a style/mood prompt and optional lyrics.
version: 1.0.0
license: MIT
"""

import base64
import os
import requests
from typing import Optional


class Tools:
    def __init__(self):
        pass

    def generate_music(
        self,
        prompt: str,
        lyrics: Optional[str] = None,
        instrumental: bool = False,
    ) -> str:
        """
        Generate a song using MiniMax Music-2.6. Use this when the user asks to create, compose,
        or generate music or a song.
        :param prompt: Style and mood description. Example: 'Pop, upbeat, summer vibes, electric guitar'. Required, 10-2000 characters.
        :param lyrics: Optional song lyrics. Separate lines with \\n. Supports structure tags like [Verse], [Chorus], [Bridge], [Outro].
        :param instrumental: Set to True for instrumental-only music (no vocals). Default False.
        :return: An inline audio player with the generated music, or an error message.
        """
        api_key = os.environ.get("MINIMAX_API_KEY", "")
        if not api_key:
            return "Error: MINIMAX_API_KEY is not configured."

        payload = {
            "model": "music-2.6",
            "prompt": prompt,
            "audio_setting": {
                "sample_rate": 44100,
                "bitrate": 256000,
                "format": "mp3",
            },
        }

        if instrumental:
            payload["is_instrumental"] = True

        if lyrics:
            payload["lyrics"] = lyrics

        try:
            resp = requests.post(
                "https://api.minimax.io/v1/music_generation",
                json=payload,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                timeout=120,
            )
            resp.raise_for_status()
            data = resp.json()
        except requests.RequestException as e:
            return f"Error calling MiniMax API: {e}"

        base_resp = data.get("base_resp", {})
        if base_resp.get("status_code", -1) != 0:
            return f"MiniMax error {base_resp.get('status_code')}: {base_resp.get('status_msg', 'Unknown error')}"

        hex_audio = data.get("data", {}).get("audio", "")
        if not hex_audio:
            return "Error: No audio data returned from MiniMax."

        # hex → bytes → base64 data URI
        audio_bytes = bytes.fromhex(hex_audio)
        b64_audio = base64.b64encode(audio_bytes).decode("utf-8")

        duration_ms = data.get("extra_info", {}).get("music_duration", 0)
        duration_sec = round(duration_ms / 1000, 1)

        return (
            f"**Music generated!** ({duration_sec}s)\n\n"
            f'<audio controls style="width:100%;margin:8px 0">'
            f'<source src="data:audio/mpeg;base64,{b64_audio}" type="audio/mpeg">'
            f"Your browser does not support the audio element."
            f"</audio>"
        )

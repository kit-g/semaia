from typing import Any, Iterator

from google import genai

_ai = genai.Client()

_model = "gemini-2.5-flash"


def call(*, prompt: str, history: list[dict[str, Any]] = None) -> str:
    if history is None:
        history = []
    response = _ai.models.generate_content(
        model=_model,
        contents=[
            *history,
            {'role': 'user', 'parts': [{'text': prompt}]}
        ],
    )
    return response.text


def stream(*, prompt: str, history: list[dict[str, Any]] = None) -> Iterator[str]:
    if history is None:
        history = []
    response = _ai.models.generate_content_stream(
        model=_model,
        contents=[
            *history,
            {'role': 'user', 'parts': [{'text': prompt}]}
        ],
    )
    for index, chunk in enumerate(response, 1):
        print(f"Chunk {index}: {chunk.text}")
        yield chunk.text

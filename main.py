from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import os
import json
import re
from openai import OpenAI

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


class ChatRequest(BaseModel):
    user_id: int
    message: str


class FoodItem(BaseModel):
    name: str
    calories: int


class ChatResponse(BaseModel):
    reply: str
    food_suggestions: List[FoodItem]


OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "openai/gpt-4o-mini")

openai_client = None
if OPENAI_API_KEY:
    openai_client = OpenAI(api_key=OPENAI_API_KEY)

openrouter_client = None
if OPENROUTER_API_KEY:
    openrouter_client = OpenAI(base_url=OPENROUTER_BASE_URL, api_key=OPENROUTER_API_KEY)


def extract_json(s: str) -> dict | None:
    fence = re.search(r"```json\s*([\s\S]*?)```", s, re.IGNORECASE)
    if fence:
        try:
            return json.loads(fence.group(1).strip())
        except Exception:
            pass
    s = s.strip()
    if s.startswith("{"):
        try:
            return json.loads(s)
        except Exception:
            pass
    start = s.find("{")
    end = s.rfind("}")
    if start != -1 and end != -1 and end > start:
        snippet = s[start : end + 1]
        try:
            return json.loads(snippet)
        except Exception:
            return None
    return None


def parse_response(content: str) -> ChatResponse:
    parsed = extract_json(content) or {}
    reply_text = str(parsed.get("reply") or content)
    raw_food = parsed.get("food_suggestions") or []
    foods: List[FoodItem] = []
    for item in raw_food:
        try:
            foods.append(
                FoodItem(
                    name=str(item.get("name", "")),
                    calories=int(item.get("calories", 0)),
                )
            )
        except Exception:
            continue
    return ChatResponse(reply=reply_text, food_suggestions=foods)


def call_llm(message: str) -> ChatResponse:
    if not openai_client and not openrouter_client:
        return ChatResponse(
            reply="Сервер не настроен: нет ключей API (ни OpenAI, ни OpenRouter).",
            food_suggestions=[],
        )

    system_prompt = (
        "Ты Nathan, дружелюбный AI-диетолог. "
        "Твоя задача: из сообщения пользователя извлечь продукты, которые он УЖЕ съел, "
        "и оценить их калорийность. "
        "Отвечай строго в виде JSON объекта с полями "
        "`reply` (строка с ответом на естественном русском языке) и "
        "`food_suggestions` (массив объектов {\"name\": string, \"calories\": int}), "
        "где КАЖДЫЙ объект описывает только те продукты и порции, которые пользователь уже съел. "
        "ЕСЛИ хочешь предложить полезные альтернативы или план на будущее, "
        "описывай их ТОЛЬКО в тексте `reply` и НИКОГДА не добавляй их в `food_suggestions`. "
        "Не добавляй ничего вне JSON."
    )

    last_error = ""

    # 1. Try OpenAI
    if openai_client:
        try:
            completion = openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message},
                ],
                response_format={"type": "json_object"},
            )
            content = completion.choices[0].message.content
            return parse_response(content)
        except Exception as e:
            print(f"OpenAI error: {e}")
            last_error = f"OpenAI error: {e}"
            # Fallback continues below

    # 2. Try OpenRouter
    if openrouter_client:
        try:
            completion = openrouter_client.chat.completions.create(
                extra_headers={
                    "HTTP-Referer": "http://localhost",
                    "X-Title": "NathanApp",
                },
                model=OPENROUTER_MODEL,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message},
                ],
                response_format={"type": "json_object"},
            )
            content = completion.choices[0].message.content
            return parse_response(content)
        except Exception as e:
            print(f"OpenRouter error: {e}")
            last_error = f"OpenRouter error: {e}. Prev: {last_error}"

    return ChatResponse(
        reply=f"Не удалось получить ответ от нейросети. Детали: {last_error}",
        food_suggestions=[],
    )


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    return call_llm(req.message)

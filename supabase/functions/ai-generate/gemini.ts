import { type Model, type ModelOptions, providerTimeoutMs } from "./models.ts";

/** เพดานคำตอบ รวม token ที่ใช้คิด — เป็นตัวจำกัดค่าใช้จ่ายต่อคำขอ */
export const geminiMaxTokens = 2048;

type GeminiResponse = {
  candidates?: {
    finishReason?: string;
    content?: { parts?: { text?: string; thought?: boolean }[] };
  }[];
  promptFeedback?: { blockReason?: string };
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    thoughtsTokenCount?: number;
  };
};

/** Gemini API (ต้องเป็น key แบบเสียเงิน แบบฟรีนำข้อมูลไปปรับปรุงผลิตภัณฑ์) — ใช้ได้กับรุ่น 3.x ที่ตั้ง thinkingLevel ได้ */
export function geminiModel({ apiKey, model, fetch: fetcher = fetch }: ModelOptions): Model {
  return {
    name: model,
    async generate({ system, user, images }) {
      let response: Response;
      let json: GeminiResponse;
      try {
        response = await fetcher(
          `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
          {
            method: "POST",
            headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: system }] },
              contents: [{
                role: "user",
                parts: [
                  ...images.map((i) => ({ inlineData: { mimeType: i.mime, data: i.data } })),
                  { text: user },
                ],
              }],
              generationConfig: {
                responseMimeType: "application/json",
                maxOutputTokens: geminiMaxTokens,
                thinkingConfig: { thinkingLevel: "MINIMAL" },
              },
            }),
            signal: AbortSignal.timeout(providerTimeoutMs),
          },
        );
        if (!response.ok) {
          await response.body?.cancel();
          return {
            error: response.status === 400 || response.status === 413 ? "bad_input" : "provider_error",
            detail: `HTTP ${response.status}`,
          };
        }
        json = await response.json();
      } catch (e) {
        return { error: "provider_error", detail: (e as Error).name };
      }
      const meta = json.usageMetadata;
      const usage = {
        inputTokens: meta?.promptTokenCount ?? null,
        outputTokens: meta ? (meta.candidatesTokenCount ?? 0) + (meta.thoughtsTokenCount ?? 0) : null,
      };
      const candidate = json.candidates?.[0];
      const reason = candidate?.finishReason;
      if (reason === "MAX_TOKENS") return { error: "answer_too_long", usage };
      if (json.promptFeedback?.blockReason || (reason && reason !== "STOP")) {
        return { error: "refused", usage, detail: json.promptFeedback?.blockReason ?? reason };
      }
      const text = (candidate?.content?.parts ?? []).filter((p) => !p.thought).map((p) => p.text ?? "").join("");
      return text.trim() ? { text, usage } : { error: "empty_answer", usage };
    },
  };
}

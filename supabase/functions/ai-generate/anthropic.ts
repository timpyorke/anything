import Anthropic from "@anthropic-ai/sdk";

import { type Model, type ModelOptions, providerTimeoutMs } from "./models.ts";

/** เพดานคำตอบ รวม token ที่ใช้คิด — เป็นตัวจำกัดค่าใช้จ่ายต่อคำขอ */
export const anthropicMaxTokens = 4096;

export function anthropicModel({ apiKey, model, fetch }: ModelOptions): Model {
  // ไม่ retry: เวลารวมต้องไม่เกินที่แอปรอ ผู้ใช้กดลองใหม่เองได้
  const client = new Anthropic({ apiKey, fetch, maxRetries: 0, timeout: providerTimeoutMs });
  return {
    name: model,
    async generate({ system, user, images }) {
      let response: Anthropic.Message;
      try {
        response = await client.messages.create({
          model,
          max_tokens: anthropicMaxTokens,
          // งานนี้คือแปลงข้อความเป็น JSON: คิดน้อยที่สุดพอ ประหยัด token
          output_config: { effort: "low" },
          system,
          messages: [{
            role: "user",
            content: [
              ...images.map((image): Anthropic.ImageBlockParam => ({
                type: "image",
                source: {
                  type: "base64",
                  media_type: image.mime as Anthropic.Base64ImageSource["media_type"],
                  data: image.data,
                },
              })),
              { type: "text", text: user },
            ],
          }],
        });
      } catch (e) {
        const status = e instanceof Anthropic.APIError ? e.status : undefined;
        return {
          error: status === 400 || status === 413 ? "bad_input" : "provider_error",
          detail: `${(e as Error).constructor.name} ${status ?? ""}`.trim(),
        };
      }
      const usage = {
        inputTokens: response.usage.input_tokens,
        outputTokens: response.usage.output_tokens,
      };
      // ตรวจเหตุที่หยุดก่อนอ่านเนื้อหา: ปฏิเสธหรือถูกตัดกลางทางอาจมีข้อความไม่ครบ
      if (response.stop_reason === "refusal") return { error: "refused", usage };
      if (response.stop_reason !== "end_turn" && response.stop_reason !== "stop_sequence") {
        return { error: "answer_too_long", usage, detail: `${response.stop_reason}` };
      }
      const text = response.content.map((block) => block.type === "text" ? block.text : "").join("");
      return text.trim() ? { text, usage } : { error: "empty_answer", usage };
    },
  };
}

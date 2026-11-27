-- ผู้ให้บริการ AI เพิ่มเติมที่แอปบันทึกลง ai_logs (ต้องตรงกับ AiProviderKind.id ในแอป)
alter table public.ai_logs drop constraint ai_logs_provider_check;
alter table public.ai_logs add constraint ai_logs_provider_check
  check (provider in ('on_device', 'ai_studio', 'anthropic', 'openai', 'openrouter'));

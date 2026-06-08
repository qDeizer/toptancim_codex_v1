# LM Studio Handoff

Date: 2026-04-03

Current owner in this thread:
- UI chat reliability
- frontend/backend timeout handling
- debug logging for freezing screens
- financial transaction screen layout crash fix
- shopping screen diagnostics

What is already changed here:
- frontend AI requests now fail fast instead of waiting forever
- shop and transaction services/providers now emit debug/info/error logs
- financial transaction screen mobile layout no longer places Expanded directly under an unbounded Column path
- backend LocalLLMProvider now logs candidate endpoints and times out endpoint attempts

What the other agent should own:
- why LM Studio itself is not answering correctly
- protocol compatibility for `POST /api/v1/chat`
- payload shape expected by LM Studio versus what we send now
- model availability and endpoint health at `http://localhost:1234`
- whether auth or base URL normalization is still wrong in edge cases

Suggested files to inspect:
- `backend/services/ai/LocalLLMProvider.js`
- `backend/services/ai/index.js`
- `backend/controllers/aiController.js`
- `backend/config/ai-settings.local.json`
- `frontend/lib/screens/settings_screen.dart`

Please avoid changing these UI-focused files unless the LM Studio fix strictly requires it:
- `frontend/lib/screens/shop_screen.dart`
- `frontend/lib/screens/add_financial_transaction_screen.dart`
- `frontend/lib/providers/shop_provider.dart`
- `frontend/lib/providers/transaction_provider.dart`
- `frontend/lib/services/ai_service.dart`
- `frontend/lib/services/shop_service.dart`
- `frontend/lib/services/transaction_service.dart`

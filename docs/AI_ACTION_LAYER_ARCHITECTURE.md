# AI Action Layer foundation

The AI Action Layer is an execution boundary, not a chat or retrieval feature.
It accepts a pre-structured `AiIntent`, resolves its `name` only through the
immutable `AiToolRegistry` allow-list, then invokes the matching `AiTool`.

```
Intent -> Registry -> Tool -> Existing controller -> Repository -> Database
```

`AiTool` implementations must receive controllers through their constructors
and delegate all work to them. Tools must not import repositories, Drift, or
persistence APIs. Controller validation, authorization, accounting, inventory,
and transaction behavior remains authoritative.

`AiExecutionService` validates required tool parameters before invocation,
propagates `AiToolValidationException` as structured field errors, and maps
unexpected exceptions to a safe failure response. The response model supports
messages, tables, and UI actions without requiring a UI change.

## Adding a production tool

1. Implement `AiTool` in `lib/features/ai_assistant/tools/`.
2. Inject the applicable existing controller into its constructor.
3. Translate controller outcomes to `AiToolResult`; wrap recoverable input
   failures in `AiToolValidationException`.
4. Add the tool to the composition-root `AiToolRegistry` only after its
   controller dependency is available.
5. Test success, controller validation propagation, authorization, and errors.

Do not add natural-language parsing, direct repository access, database schema
changes, or accounting logic to this module.

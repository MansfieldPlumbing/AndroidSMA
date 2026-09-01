using System;
using System.Collections.Generic;
using System.Threading;

namespace Subsystem.Capabilities.Core
{
    // ITurnSource — projects a turn synchronously to a callback. The native DPX citizen is one;
    // a mounted foreign engine is one. The only shape they share.
    public interface ITurnSource : IDisposable
    {
        TurnFault? BringUp();
        void ProjectTurn(string prompt, byte[]? audioBytes, Action<TurnEvent> callback, CancellationToken ct = default);
        void ProjectTurn(string prompt, byte[]? audioBytes, byte[]? imageBytes, Action<TurnEvent> callback, CancellationToken ct = default)
            => ProjectTurn(prompt, audioBytes, callback, ct);
        bool IsAlive { get; }
        string BackendName { get; }
        Benchmark? GetBenchmark() => null;
    }

    // Per-turn decode counters (mirrors the Android head's Runtime.cs contract member-for-member).
    public sealed record Benchmark(double InitSeconds, double TimeToFirstTokenSeconds,
        int PrefillTokens, double PrefillTokensPerSecond, int DecodeTokens, double DecodeTokensPerSecond);

    // IGuestEngine — the GUEST contract. A foreign, boundary-crossing engine (LiteRT-LM, ONNX, GGML) signs this to
    // be mounted through the guest door. DPX IS NOT A RUNTIME — she is the native citizen, an ITurnSource.
    public interface IGuestEngine : ITurnSource
    {
    }

    public enum TurnEventKind
    {
        Token,
        Think,
        ToolCall,
        ToolResult,
        Error
    }

    public readonly record struct TurnEvent(TurnEventKind Kind, string Text, string? Name = null, TurnFault? Fault = null);

    public enum TurnFaultClass
    {
        AdmissionRefused,
        BringUpFailed,
        VerificationFailed,
        EngineReclaimed,
        ConversationDefunct,
        DecodeCancelled,
        DecodeFaulted,
        BackendUnavailable,
    }

    public sealed record TurnFault(TurnFaultClass Class, string UnitId, string Backend, string NativeDetail);

    public sealed class TurnFaultException : Exception
    {
        public TurnFault Fault { get; }
        public TurnFaultException(TurnFault fault)
            : base($"{fault.Class} [{fault.UnitId}/{fault.Backend}] {fault.NativeDetail}")
            => Fault = fault;
    }
}

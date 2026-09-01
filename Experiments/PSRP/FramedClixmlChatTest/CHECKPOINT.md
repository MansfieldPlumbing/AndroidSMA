# Framed CLIXML chat test checkpoint

## What this test was

A local-model chat fixture used to test whether PowerShell-shaped values and
state could cross a small custom session wire.

The wire is:

```text
four-byte network-order payload length
UTF-8 CLIXML payload produced by PSSerializer
small message vocabulary for open, invoke, stream, state, and close
```

It is not a general remoting implementation and does not belong in product
source.

## What passed

- A desktop PowerShell listener admitted one chat command.
- A client opened a logical session and invoked that command.
- Conversation state survived more than one request in the session.
- Output, error, and completion-shaped messages crossed the framed CLIXML wire.
- A phone chat fixture reached the desktop model, although that physical proof
  used ADB reverse and therefore did not prove the intended final wire.

## What did not pass

- AndroidSMA acting as the server for a Windows researcher.
- A USB AOA round trip.
- A no-ADB physical route.
- General command execution against AndroidSMA's retained runspace.
- Cancellation, concurrent commands, reconnect, or complete stream behavior.
- Compatibility with an external remoting standard.

## Artifact map

- `FramedClixmlWire.ps1` owns exact framing and `PSSerializer` calls.
- `FramedClixmlChatClient.ps1` is the narrow test client.
- `Listen-FramedClixmlChat.ps1` is the narrow desktop listener.
- `LocalModelChat.ps1` owns the local-model HTTP boundary.
- `PhoneChatFixture.ps1` is the interactive Android test surface.
- `PhoneChatSmoke.ps1` records the old physical-route smoke test.

These files remain together as archaeological test evidence. They never
graduate as a unit. A separately designed AndroidSMA session wire may reuse a
proven framing fact only after reproducing it with unlike consumers.

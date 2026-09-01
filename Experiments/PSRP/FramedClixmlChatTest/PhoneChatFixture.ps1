#requires -Version 7.0

# Small dogfood surface: Android views are the platform membrane; conversation
# and HTTP behavior live in LocalModelChat.ps1. This intentionally performs one
# synchronous turn per tap. It proves the bridge before we attach it to the
# packed-cell console and streaming presenter.

$privateRoot = $Activity.FilesDir.AbsolutePath
$ErrorActionPreference = 'Stop'
trap {
    $fault = "{0}`n{1}`n{2}" -f $_.Exception.GetType().FullName,
        $_.Exception.Message, $_.ScriptStackTrace
    [IO.File]::WriteAllText(
        [IO.Path]::Combine($privateRoot, 'bonsai-bridge-fault.txt'), $fault)
    [Android.Util.Log]::Error('BonsaiBridge', $fault)
    break
}
$bridgePath = [IO.Path]::Combine($privateRoot, 'LocalModelChat.ps1')
. ([scriptblock]::Create([IO.File]::ReadAllText($bridgePath)))

$script:Chat = New-LocalModelChat -Endpoint 'http://127.0.0.1:8080'

$layout = [Android.Widget.LinearLayout]::new($Activity)
$layout.Orientation = [Android.Widget.Orientation]::Vertical
$layout.SetPadding(24, 24, 24, 24)
$layout.SetBackgroundColor([Android.Graphics.Color]::Rgb(9, 12, 18))

$title = [Android.Widget.TextView]::new($Activity)
$title.Text = 'BONSAI / LOCAL'
$title.SetTextColor([Android.Graphics.Color]::Rgb(35, 209, 139))
$title.SetTextSize([Android.Util.ComplexUnitType]::Sp, 22)
$layout.AddView($title)

$script:Transcript = [Android.Widget.TextView]::new($Activity)
$script:Transcript.Text = "Bonsai is running on the P2000 through PC localhost.`nThe phone reaches it through adb reverse.`n"
$script:Transcript.SetTextColor([Android.Graphics.Color]::White)
$script:Transcript.SetTextIsSelectable($true)
$script:Transcript.SetTextSize([Android.Util.ComplexUnitType]::Sp, 16)

$scroll = [Android.Widget.ScrollView]::new($Activity)
$scroll.AddView($script:Transcript)
$scrollParams = [Android.Widget.LinearLayout+LayoutParams]::new(
    [Android.Views.ViewGroup+LayoutParams]::MatchParent, 0, 1.0)
$scrollParams.TopMargin = 16
$scrollParams.BottomMargin = 16
$layout.AddView($scroll, $scrollParams)

$script:Prompt = [Android.Widget.EditText]::new($Activity)
$script:Prompt.Hint = 'Say something...'
$script:Prompt.SetTextColor([Android.Graphics.Color]::White)
$script:Prompt.SetHintTextColor([Android.Graphics.Color]::Gray)
$script:Prompt.SetSingleLine($false)
$layout.AddView($script:Prompt)

$script:Send = [Android.Widget.Button]::new($Activity)
$script:Send.Text = 'SEND'
$script:Send.add_Click({
    $text = $script:Prompt.Text
    if ([string]::IsNullOrWhiteSpace($text)) { return }

    $script:Prompt.Text = ''
    $script:Send.Enabled = $false
    $script:Transcript.Append("`nYOU> $text`n")
    try {
        $reply = Send-LocalModelChat -Chat $script:Chat -Text $text
        $script:Transcript.Append("`nBONSAI> $($reply.Content)`n")
        if ($reply.Timings) {
            $script:Transcript.Append(('[{0:N1} prompt tok/s; {1:N1} decode tok/s]`n' -f
                $reply.Timings.PromptTokensPerSecond,
                $reply.Timings.PredictedTokensPerSecond))
        }
    } catch {
        $script:Transcript.Append("`nFAULT> $($_.Exception.Message)`n")
    } finally {
        $script:Send.Enabled = $true
        $scroll.Post({ $scroll.FullScroll([Android.Views.FocusSearchDirection]::Down) })
    }
})
$layout.AddView($script:Send)

$Activity.SetContentView($layout)

# Prove phone -> reversed loopback -> Windows llama-server exactly once for
# this deployment. Normal chat history starts clean after the probe.
$receiptPath = [IO.Path]::Combine($privateRoot, 'bonsai-bridge-receipt.txt')
if (-not [IO.File]::Exists($receiptPath)) {
    $probe = New-LocalModelChat -Endpoint 'http://127.0.0.1:8080'
    try {
        $proof = Send-LocalModelChat -Chat $probe -Text 'Reply with exactly: PHONE BONSAI BRIDGE ALIVE' -MaxTokens 32 -Temperature 0
        $receipt = @(
            [DateTimeOffset]::UtcNow.ToString('O')
            $proof.Content
            ('prompt_tok_s={0:N3}' -f $proof.Timings.PromptTokensPerSecond)
            ('decode_tok_s={0:N3}' -f $proof.Timings.PredictedTokensPerSecond)
        ) -join "`n"
        [IO.File]::WriteAllText($receiptPath, $receipt)
        $script:Transcript.Append("`n$receipt`n")
    } catch {
        $script:Transcript.Append("`nBOOT PROBE FAULT> $($_.Exception.Message)`n")
    } finally {
        Close-LocalModelChat $probe
    }
} else {
    $script:Transcript.Append("`n$([IO.File]::ReadAllText($receiptPath))`n")
}

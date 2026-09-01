@{
    SchemaVersion = 1
    Status = 'Experiment'
    AppliesTo = @('Arm64', 'Arm32')
    DefaultVerdict = 'FAIL_UNCLASSIFIED'

    # Product capabilities chosen deliberately. Every entry still needs the
    # named proof before it may appear in a release APK.
    Admit = @(
        @{ Name = 'AndroidSMA.Entry.dll'; Capability = 'Android entry and recovery'; Proof = 'Recovery parity matrix' }
        @{ Name = 'Mono.Android.dll'; Capability = '.NET Android public API'; Proof = 'Activity, views, intents, USB, files' }
        @{ Name = 'Mono.Android.Runtime.dll'; Capability = '.NET Android runtime bridge'; Proof = 'Cold boot on device' }
        @{ Name = 'Java.Interop.dll'; Capability = 'Managed Android object bridge'; Proof = 'Managed Android API calls' }
        @{ Name = 'System.Management.Automation.dll'; Capability = 'SMA language, AST, runspaces, pipelines, CLIXML'; Proof = 'Parse, execute, serialize, recover' }
        @{ Name = 'System.Linq.dll'; Capability = 'Causal object transforms'; Proof = 'Representative query pipeline' }
        @{ Name = 'System.Linq.Expressions.dll'; Capability = 'Expression lowering and dynamic execution'; Proof = 'Compile and invoke expression' }
        @{ Name = 'System.Reflection.Emit.dll'; Capability = 'Direct IL emission'; Proof = 'Emit and invoke typed method' }
        @{ Name = 'System.Reflection.Emit.ILGeneration.dll'; Capability = 'Direct IL generation'; Proof = 'Emit and invoke typed method' }
        @{ Name = 'System.Reflection.Emit.Lightweight.dll'; Capability = 'Dynamic method generation'; Proof = 'Emit and invoke DynamicMethod' }
        @{ Name = 'System.Reflection.Metadata.dll'; Capability = 'Persisted metadata inspection and emission'; Proof = 'Inspect emitted entry assembly' }
        @{ Name = 'System.Net.Http.dll'; Capability = 'Managed Internet client'; Proof = 'HTTPS request on Android' }
        @{ Name = 'System.Net.Sockets.dll'; Capability = 'Session and research wires'; Proof = 'Ordered duplex round trip' }
        @{ Name = 'System.Net.WebSockets.dll'; Capability = 'Managed streaming wire'; Proof = 'Duplex stream receipt or remove' }
        @{ Name = 'System.Private.Xml.dll'; Capability = 'CLIXML substrate'; Proof = 'PSSerializer round trip' }
        @{ Name = 'System.Xml.ReaderWriter.dll'; Capability = 'CLIXML substrate'; Proof = 'PSSerializer round trip' }
    )

    # These assemblies may appear only when static metadata proves they are in
    # the closure of an admitted capability and device omission testing proves
    # they cannot yet be removed. Closure does not grant product status.
    ClosureOnly = @(
        'System.Private.CoreLib.dll'
        'System.Runtime.dll'
        'netstandard.dll'
        'System.Collections.dll'
        'System.Collections.Concurrent.dll'
        'System.Collections.Immutable.dll'
        'System.Console.dll'
        'System.Dynamic.Runtime.dll'
        'System.Memory.dll'
        'System.ObjectModel.dll'
        'System.Private.Uri.dll'
        'System.Runtime.InteropServices.dll'
        'System.Runtime.Loader.dll'
        'System.Reflection.Primitives.dll'
        'System.Threading.dll'
        'System.Threading.Tasks.dll'
        'System.ComponentModel.dll'
        'System.ComponentModel.Primitives.dll'
        'System.ComponentModel.TypeConverter.dll'
        'System.Net.Primitives.dll'
        'System.Net.NameResolution.dll'
        'System.Net.Security.dll'
        'System.Security.Cryptography.dll'
        'System.Security.Cryptography.X509Certificates.dll'
        'System.Xml.XPath.dll'
        'System.Xml.XmlSerializer.dll'
        # PowerShell's dynamic binder may require this runtime assembly. It is
        # not Roslyn and does not compile C# source. Prove or remove it.
        'Microsoft.CSharp.dll'
        # SMA 7.7 directly references this assembly. AndroidSMA does not admit
        # JSON as a product wire or data contract; removal requires either an
        # SMA build without the reference or proof that metadata rewriting is
        # safe. Until then this is quarantined closure, not a chosen feature.
        'Newtonsoft.Json.dll'
    )

    # Exact assembly names refused from the product APK. A test fixture may
    # carry its own dependencies outside the product build.
    Refuse = @(
        'Microsoft.CodeAnalysis.dll'
        'Microsoft.CodeAnalysis.CSharp.dll'
        'System.CodeDom.dll'
        'Microsoft.PowerShell.ConsoleHost.dll'
        'Microsoft.PowerShell.Commands.Diagnostics.dll'
        'Microsoft.PowerShell.Commands.Management.dll'
        'Microsoft.PowerShell.Commands.Utility.dll'
        'Microsoft.PowerShell.MarkdownRender.dll'
        'Microsoft.WSMan.Management.dll'
        'Microsoft.WSMan.Runtime.dll'
        'System.Management.dll'
        'System.Diagnostics.EventLog.dll'
        'System.ServiceProcess.ServiceController.dll'
        'System.ServiceModel.dll'
        'System.ServiceModel.Http.dll'
        'System.ServiceModel.NetTcp.dll'
        'System.ServiceModel.Primitives.dll'
        'System.Text.Json.dll'
        'Microsoft.Win32.Registry.dll'
        'Microsoft.Win32.Registry.AccessControl.dll'
        'Microsoft.Win32.SystemEvents.dll'
        'System.Security.Principal.Windows.dll'
        'System.Windows.Extensions.dll'
    )

    RefuseNamePatterns = @(
        'Microsoft.CodeAnalysis.*'
        '*.resources.dll'
        'System.ServiceModel.*'
        'System.DirectoryServices.*'
        'System.Management.Automation.xml'
    )

    NativeAdmit = @(
        @{ Name = 'libcoreclr.so'; Capability = 'CoreCLR runtime'; Proof = 'Cold boot and execute PS1' }
        @{ Name = 'libclrjit.so'; Capability = 'RyuJIT'; Proof = 'JIT receipt on target ABI' }
        @{ Name = 'libhostpolicy.so'; Capability = 'CoreCLR host policy'; Proof = 'Cold boot' }
        @{ Name = 'libhostfxr.so'; Capability = 'CoreCLR host resolution'; Proof = 'Cold boot or prove pack does not require it' }
        @{ Name = 'libpsl-native.so'; Capability = 'Narrow PowerShell native compatibility'; Proof = 'Reproducible ABI-specific hash' }
    )

    Rules = @{
        OppositeAbiIsFatal = $true
        RoslynIsFatal = $true
        CSharpSourceIsFatal = $true
        EmbeddedRecoverySourceIsFatal = $true
        UnclassifiedAssemblyIsFatal = $true
        ClosureRequiresMetadataEvidence = $true
        ClosureRequiresOmissionReceipt = $true
    }
}

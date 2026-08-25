#nullable disable
using System;
using System.Runtime.InteropServices;

namespace AndroidSMA.Qnn
{
    // QNN-R002 specimen. This file intentionally does not refactor QnnMatMulProof.
    // It constructs exactly MatMul -> ElementWiseAdd and verifies the combined
    // result. The QNN-R001 source and receipt remain unchanged.
    public sealed unsafe class QnnMatMulAddProof
    {
        const int TypeAppWrite = 0, TypeAppRead = 1, TypeNative = 3, TypeStatic = 4;
        const int DataTypeFloat32 = 0x0232;
        const int DataFormatFlat = 0;
        const int MemTypeRaw = 0;
        const int TensorVersion1 = 1, OpConfigVersion1 = 1;
        const int EncodingUndefined = 0x7FFFFFFF;

        [StructLayout(LayoutKind.Sequential)]
        struct ClientBuffer { public IntPtr Data; public uint DataSize; }

        [StructLayout(LayoutKind.Sequential)]
        struct QuantizeParams
        {
            public int EncodingDefinition;
            public int Encoding;
            public long U0, U1, U2, U3;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct TensorV1
        {
            public uint Id;
            public IntPtr Name;
            public int Type;
            public uint DataFormat;
            public int DataType;
            public QuantizeParams Quant;
            public uint Rank;
            public IntPtr Dimensions;
            public int MemType;
            public ClientBuffer Buf;
        }

        // Qnn_Tensor_t is 144 bytes for the packaged QNN ABI. Array striding
        // depends on this full union size.
        [StructLayout(LayoutKind.Sequential, Size = 144)]
        struct Tensor { public int Version; public TensorV1 V1; }

        [StructLayout(LayoutKind.Sequential)]
        struct OpConfigV1
        {
            public IntPtr Name, PackageName, TypeName;
            public uint NumParams;
            public IntPtr Params;
            public uint NumInputs;
            public IntPtr Inputs;
            public uint NumOutputs;
            public IntPtr Outputs;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct OpConfig { public int Version; public OpConfigV1 V1; }

        const int FnBackendCreate = 1;
        const int FnContextCreate = 9;
        const int FnGraphCreate = 15;
        const int FnGraphAddNode = 18;
        const int FnGraphFinalize = 19;
        const int FnGraphExecute = 21;
        const int FnTensorCreateGraphTensor = 24;
        const int FnDeviceCreate = 40;
        const ulong QnnDeviceErrorUnsupportedFeature = 1000;

        static IntPtr AllocCString(string value) => Marshal.StringToHGlobalAnsi(value);

        static Tensor CreateTensor(string name, int type, uint* dimensions, IntPtr data, uint bytes)
        {
            var tensor = new Tensor { Version = TensorVersion1 };
            tensor.V1.Name = AllocCString(name);
            tensor.V1.Type = type;
            tensor.V1.DataFormat = DataFormatFlat;
            tensor.V1.DataType = DataTypeFloat32;
            tensor.V1.Quant.EncodingDefinition = EncodingUndefined;
            tensor.V1.Quant.Encoding = EncodingUndefined;
            tensor.V1.Rank = 2;
            tensor.V1.Dimensions = (IntPtr)dimensions;
            tensor.V1.MemType = MemTypeRaw;
            tensor.V1.Buf.Data = data;
            tensor.V1.Buf.DataSize = bytes;
            return tensor;
        }

        static IntPtr CreateNullConfigDevice(IntPtr* functions, out ulong result)
        {
            IntPtr device;
            result = ((delegate* unmanaged<IntPtr, IntPtr, IntPtr*, ulong>)functions[FnDeviceCreate])(
                IntPtr.Zero,
                IntPtr.Zero,
                &device);
            return result == 0 ? device : IntPtr.Zero;
        }

        static ulong AddNode(
            IntPtr* functions,
            IntPtr graph,
            string nodeName,
            string operationType,
            Tensor[] inputTensors,
            Tensor outputTensor,
            out IntPtr inputArray,
            out IntPtr outputArray)
        {
            inputArray = Marshal.AllocHGlobal(sizeof(Tensor) * inputTensors.Length);
            Tensor* inputPointer = (Tensor*)inputArray;
            for (int index = 0; index < inputTensors.Length; index++)
                inputPointer[index] = inputTensors[index];

            outputArray = Marshal.AllocHGlobal(sizeof(Tensor));
            ((Tensor*)outputArray)[0] = outputTensor;

            var operation = new OpConfig { Version = OpConfigVersion1 };
            operation.V1.Name = AllocCString(nodeName);
            operation.V1.PackageName = AllocCString("qti.aisw");
            operation.V1.TypeName = AllocCString(operationType);
            operation.V1.NumInputs = (uint)inputTensors.Length;
            operation.V1.Inputs = inputArray;
            operation.V1.NumOutputs = 1;
            operation.V1.Outputs = outputArray;

            return ((delegate* unmanaged<IntPtr, OpConfig, ulong>)functions[FnGraphAddNode])(
                graph,
                operation);
        }

        // Constructs and executes y = (x @ W) + bias. All numerical arrays are
        // supplied by the PowerShell caller. QNN handle teardown remains a
        // separate experiment, matching the already-frozen QNN-R001 lifetime.
        public string Execute(
            string backendLibrary,
            uint featureK,
            uint featureN,
            float[] weights,
            float[] input,
            float[] bias)
        {
            if (weights == null || weights.Length != featureK * featureN)
                return $"QnnMatMulAddProof: weights.Length={weights?.Length ?? 0} expected={featureK * featureN}";
            if (input == null || input.Length != featureK)
                return $"QnnMatMulAddProof: input.Length={input?.Length ?? 0} expected={featureK}";
            if (bias == null || bias.Length != featureN)
                return $"QnnMatMulAddProof: bias.Length={bias?.Length ?? 0} expected={featureN}";

            var reference = new float[featureN];
            var output = new float[featureN];
            double biasMaximumAbsolute = 0;
            for (int n = 0; n < featureN; n++)
            {
                double accumulator = bias[n];
                for (int k = 0; k < featureK; k++)
                    accumulator += (double)input[k] * weights[k * featureN + n];
                reference[n] = (float)accumulator;
                biasMaximumAbsolute = Math.Max(biasMaximumAbsolute, Math.Abs(bias[n]));
            }

            IntPtr library = NativeLibrary.Load(backendLibrary);
            var getProviders = (delegate* unmanaged<IntPtr*, uint*, ulong>)NativeLibrary.GetExport(
                library,
                "QnnInterface_getProviders");
            IntPtr providerList;
            uint providerCount;
            if (getProviders(&providerList, &providerCount) != 0 || providerCount < 1)
                return "QnnMatMulAddProof: no QNN provider";

            byte* table = (byte*)((IntPtr*)providerList)[0] + 40;
            IntPtr* functions = (IntPtr*)table;
            IntPtr backend;
            IntPtr context;
            IntPtr graph;
            ulong result;

            result = ((delegate* unmanaged<IntPtr, IntPtr, IntPtr*, ulong>)functions[FnBackendCreate])(
                IntPtr.Zero,
                IntPtr.Zero,
                &backend);
            if (result != 0) return $"QnnMatMulAddProof: backendCreate 0x{result:x}";

            IntPtr device = CreateNullConfigDevice(functions, out ulong deviceResult);
            string devicePath = device != IntPtr.Zero
                ? "nullConfig"
                : deviceResult == QnnDeviceErrorUnsupportedFeature
                    ? "nullConfig-unsupported(stock-ok)"
                    : $"nullConfig-failed(0x{deviceResult:x})";

            result = ((delegate* unmanaged<IntPtr, IntPtr, IntPtr, IntPtr*, ulong>)functions[FnContextCreate])(
                backend,
                device,
                IntPtr.Zero,
                &context);
            if (result != 0)
                return $"QnnMatMulAddProof: contextCreate dev={devicePath} 0x{result:x}";

            IntPtr graphName = AllocCString("matmul_add");
            result = ((delegate* unmanaged<IntPtr, byte*, IntPtr, IntPtr*, ulong>)functions[FnGraphCreate])(
                context,
                (byte*)graphName,
                IntPtr.Zero,
                &graph);
            if (result != 0) return $"QnnMatMulAddProof: graphCreate 0x{result:x}";

            uint* dimensionsX = (uint*)Marshal.AllocHGlobal(8);
            dimensionsX[0] = 1;
            dimensionsX[1] = featureK;
            uint* dimensionsW = (uint*)Marshal.AllocHGlobal(8);
            dimensionsW[0] = featureK;
            dimensionsW[1] = featureN;
            uint* dimensionsN = (uint*)Marshal.AllocHGlobal(8);
            dimensionsN[0] = 1;
            dimensionsN[1] = featureN;

            IntPtr weightMemory = Marshal.AllocHGlobal(weights.Length * sizeof(float));
            Marshal.Copy(weights, 0, weightMemory, weights.Length);
            IntPtr biasMemory = Marshal.AllocHGlobal(bias.Length * sizeof(float));
            Marshal.Copy(bias, 0, biasMemory, bias.Length);

            Tensor tensorX = CreateTensor("x", TypeAppWrite, dimensionsX, IntPtr.Zero, 0);
            Tensor tensorW = CreateTensor(
                "W",
                TypeStatic,
                dimensionsW,
                weightMemory,
                (uint)(weights.Length * sizeof(float)));
            Tensor tensorMatMulOutput = CreateTensor(
                "matmul_output",
                TypeNative,
                dimensionsN,
                IntPtr.Zero,
                0);
            Tensor tensorBias = CreateTensor(
                "bias",
                TypeStatic,
                dimensionsN,
                biasMemory,
                (uint)(bias.Length * sizeof(float)));
            Tensor tensorY = CreateTensor("y", TypeAppRead, dimensionsN, IntPtr.Zero, 0);

            var createTensor = (delegate* unmanaged<IntPtr, void*, ulong>)functions[FnTensorCreateGraphTensor];
            if ((result = createTensor(graph, &tensorX)) != 0) return $"QnnMatMulAddProof: tensor x 0x{result:x}";
            if ((result = createTensor(graph, &tensorW)) != 0) return $"QnnMatMulAddProof: tensor W 0x{result:x}";
            if ((result = createTensor(graph, &tensorMatMulOutput)) != 0) return $"QnnMatMulAddProof: tensor matmul_output 0x{result:x}";
            if ((result = createTensor(graph, &tensorBias)) != 0) return $"QnnMatMulAddProof: tensor bias 0x{result:x}";
            if ((result = createTensor(graph, &tensorY)) != 0) return $"QnnMatMulAddProof: tensor y 0x{result:x}";

            result = AddNode(
                functions,
                graph,
                "matmul0",
                "MatMul",
                new[] { tensorX, tensorW },
                tensorMatMulOutput,
                out IntPtr matMulInputs,
                out IntPtr matMulOutputs);
            if (result != 0) return $"QnnMatMulAddProof: add MatMul node 0x{result:x}";

            result = AddNode(
                functions,
                graph,
                "add0",
                "ElementWiseAdd",
                new[] { tensorMatMulOutput, tensorBias },
                tensorY,
                out IntPtr addInputs,
                out IntPtr addOutputs);
            if (result != 0) return $"QnnMatMulAddProof: add ElementWiseAdd node 0x{result:x}";

            result = ((delegate* unmanaged<IntPtr, IntPtr, IntPtr, ulong>)functions[FnGraphFinalize])(
                graph,
                IntPtr.Zero,
                IntPtr.Zero);
            if (result != 0) return $"QnnMatMulAddProof: finalize 0x{result:x}";

            IntPtr inputMemory = Marshal.AllocHGlobal((int)(featureK * sizeof(float)));
            Marshal.Copy(input, 0, inputMemory, (int)featureK);
            IntPtr outputMemory = Marshal.AllocHGlobal((int)(featureN * sizeof(float)));
            tensorX.V1.Buf.Data = inputMemory;
            tensorX.V1.Buf.DataSize = featureK * sizeof(float);
            tensorY.V1.Buf.Data = outputMemory;
            tensorY.V1.Buf.DataSize = featureN * sizeof(float);

            IntPtr executeInputMemory = Marshal.AllocHGlobal(sizeof(Tensor));
            ((Tensor*)executeInputMemory)[0] = tensorX;
            IntPtr executeOutputMemory = Marshal.AllocHGlobal(sizeof(Tensor));
            ((Tensor*)executeOutputMemory)[0] = tensorY;
            result = ((delegate* unmanaged<IntPtr, void*, uint, void*, uint, IntPtr, IntPtr, ulong>)functions[FnGraphExecute])(
                graph,
                (void*)executeInputMemory,
                1,
                (void*)executeOutputMemory,
                1,
                IntPtr.Zero,
                IntPtr.Zero);
            if (result != 0) return $"QnnMatMulAddProof: execute 0x{result:x}";

            Marshal.Copy(outputMemory, output, 0, (int)featureN);

            double maximumAbsoluteError = 0;
            double referenceMaximumAbsolute = 0;
            for (int n = 0; n < featureN; n++)
            {
                maximumAbsoluteError = Math.Max(
                    maximumAbsoluteError,
                    Math.Abs((double)output[n] - reference[n]));
                referenceMaximumAbsolute = Math.Max(
                    referenceMaximumAbsolute,
                    Math.Abs(reference[n]));
            }
            double maximumRelativeError = maximumAbsoluteError /
                (referenceMaximumAbsolute > 1e-9 ? referenceMaximumAbsolute : 1.0);

            Marshal.FreeHGlobal((IntPtr)dimensionsX);
            Marshal.FreeHGlobal((IntPtr)dimensionsW);
            Marshal.FreeHGlobal((IntPtr)dimensionsN);
            Marshal.FreeHGlobal(weightMemory);
            Marshal.FreeHGlobal(biasMemory);
            Marshal.FreeHGlobal(matMulInputs);
            Marshal.FreeHGlobal(matMulOutputs);
            Marshal.FreeHGlobal(addInputs);
            Marshal.FreeHGlobal(addOutputs);
            Marshal.FreeHGlobal(inputMemory);
            Marshal.FreeHGlobal(outputMemory);
            Marshal.FreeHGlobal(executeInputMemory);
            Marshal.FreeHGlobal(executeOutputMemory);

            string verdict = maximumRelativeError < 2e-2 ? "PASS" : "FAIL";
            return $"QnnMatMulAddProof.Execute: {backendLibrary} graph=MatMul,ElementWiseAdd K={featureK} N={featureN} biasMaxAbs={biasMaximumAbsolute:F5} maxRel={maximumRelativeError:F5} {verdict}";
        }
    }
}

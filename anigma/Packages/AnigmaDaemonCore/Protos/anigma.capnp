@0x8a1b2c3d4e5f6a7b; # Unique ID for this schema

using Swift = import "/swift.capnp";
$Swift.prefix("Anigma");

struct InferenceTask {
    requestId @0 :UInt64;
    modelId @1 :Text;
    prompt @2 :Text;
    parameters @3 :InferenceParams;
}

struct InferenceParams {
    temperature @0 :Float32;
    topK @1 :UInt32;
    topP @2 :Float32;
    maxTokens @3 :UInt32;
}

struct InferenceResult {
    requestId @0 :UInt64;
    text @1 :Text;
    status @2 :Status;
    
    enum Status {
        ok @0;
        error @1;
        partial @2;
    }
}

interface InferenceStream {
    submit @0 (task :InferenceTask) -> (result :InferenceResult);
    stream @1 (requestId :UInt64) -> (token :Text);
}

struct TensorHandoff {
    shmId @0 :Text;
    offset @1 :UInt64;
    length @2 :UInt64;
    shape @3 :List(UInt32);
    dtype @4 :DataType;

    enum DataType {
        float32 @0;
        float16 @1;
        uint8 @2;
        int32 @3;
    }
}

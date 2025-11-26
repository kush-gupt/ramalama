% ramalama-convert 1

## NAME
ramalama\-convert - convert AI Models from local storage to OCI Image or squashfs

## SYNOPSIS
**ramalama convert** [*options*] *model* [*target*]

## DESCRIPTION
Convert specified AI Model to an OCI Formatted AI Model or a squashfs image.

The model can be from RamaLama model storage in Huggingface, Ollama, or a local model stored on disk. Converting from an OCI model is not supported.

Note: The convert command must be run with containers. Use of the --nocontainer option is not allowed.

## OPTIONS

#### **--compression**=*gzip* | *lz4* | *zstd* | *xz*

Compression algorithm to use when creating squashfs images. Only applicable when `--type=squashfs` is specified.
The default is **zstd**.

#### **--gguf**=*Q2_K* | *Q3_K_S* | *Q3_K_M* | *Q3_K_L* | *Q4_0* | *Q4_K_S* | *Q4_K_M* | *Q5_0* | *Q5_K_S* | *Q5_K_M* | *Q6_K* | *Q8_0* 

Convert Safetensor models into a GGUF with the specified quantization format. To learn more about model quantization, read llama.cpp documentation:
https://github.com/ggml-org/llama.cpp/blob/master/tools/quantize/README.md

#### **--help**, **-h**
Print usage message

#### **--image**=IMAGE
Image to use for model quantization when converting to GGUF format (when the `--gguf` option has been specified). The image must have the
`llama-quantize` executable available on the `PATH`. Defaults to the appropriate `ramalama` image based on available accelerators. If no
accelerators are available, the current `quay.io/ramalama/ramalama` image will be used.

#### **--network**=*none*
sets the configuration for network namespaces when handling RUN instructions

#### **--pull**=*policy*
Pull image policy. The default is **missing**.

#### **--rag-image**=IMAGE
Image to use when converting to GGUF format (when then `--gguf` option has been specified). The image must have the `convert_hf_to_gguf.py` script
executable and available in the `PATH`. The script is available from the `llama.cpp` GitHub repo. Defaults to the current
`quay.io/ramalama/ramalama-rag` image.

#### **--type**=*raw* | *car* | *squashfs*

type of output format for the converted model.

| Type     | Description                                                       |
| -------- | ----------------------------------------------------------------- |
| car      | Includes base image with the model stored in a /models subdir     |
| raw      | Only the model and a link file model.file to it stored at /       |
| squashfs | Creates a compressed squashfs image file for efficient distribution |

## EXAMPLE

Generate an oci model out of an Ollama model.
```
$ ramalama convert ollama://tinyllama:latest oci://quay.io/rhatdan/tiny:latest
Building quay.io/rhatdan/tiny:latest...
STEP 1/2: FROM scratch
STEP 2/2: COPY sha256:2af3b81862c6be03c769683af18efdadb2c33f60ff32ab6f83e42c043d6c7816 /model
--> Using cache 69db4a10191c976d2c3c24da972a2a909adec45135a69dbb9daeaaf2a3a36344
COMMIT quay.io/rhatdan/tiny:latest
--> 69db4a10191c
Successfully tagged quay.io/rhatdan/tiny:latest
69db4a10191c976d2c3c24da972a2a909adec45135a69dbb9daeaaf2a3a36344
```

Generate and run an oci model with a quantized GGUF converted from Safetensors.
```
$ ramalama convert --gguf Q4_K_M hf://ibm-granite/granite-3.2-2b-instruct oci://quay.io/kugupta/granite-3.2-q4-k-m:latest
Converting /Users/kugupta/.local/share/ramalama/models/huggingface/ibm-granite/granite-3.2-2b-instruct to quay.io/kugupta/granite-3.2-q4-k-m:latest...
Building quay.io/kugupta/granite-3.2-q4-k-m:latest...
$ ramalama run oci://quay.io/kugupta/granite-3.2-q4-k-m:latest
```

Generate a squashfs image from an Ollama model using zstd compression.
```
$ ramalama convert --type=squashfs ollama://tinyllama:latest ./tinyllama.squashfs
Converting ollama://tinyllama:latest to squashfs...
Created squashfs image: /home/user/tinyllama.squashfs
```

Generate a squashfs image with lz4 compression from a HuggingFace model for faster decompression.
```
$ ramalama convert --type=squashfs --compression=lz4 hf://ibm-granite/granite-3.2-2b-instruct ./granite.squashfs
Converting hf://ibm-granite/granite-3.2-2b-instruct to squashfs...
Created squashfs image: /home/user/granite.squashfs
```

## SEE ALSO
**[ramalama(1)](ramalama.1.md)**, **[ramalama-push(1)](ramalama-push.1.md)**

## HISTORY
Aug 2024, Originally compiled by Eric Curtin <ecurtin@redhat.com>

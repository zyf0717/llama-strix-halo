# llama-strix-halo

## Repo Layout

```text
llama-strix-halo/
├─ README.md
├─ .env
├─ scripts/
│  ├─ 00-capture-env.sh
│  ├─ 10-fetch-llamacpp.sh
│  ├─ 20-build-vulkan.sh
│  ├─ 21-build-hip.sh
│  └─ 30-bench.sh
├─ prompts/
├─ models/          # symlinks only
├─ results/
└─ third_party/
   └─ llama.cpp/    # git submodule
```
# Local MCP Tools Setup (No API Key Required)

## ✅ Successfully Installed

### 1. Sentence-Transformers
- **Version**: 5.1.2
- **Model**: all-MiniLM-L6-v2 (384 dimensions)
- **Location**: `~/mcp_tools/mcp_env/`
- **Status**: ✅ Working

### 2. Configuration
- **Config File**: `/Users/user/Developer/GitHub/Anigma_clean/kontxt_local_config.json`
- **Settings**:
  - Local embedding model (no Gemini API needed)
  - Codebase path: `/Users/user/Developer/GitHub/Anigma_clean`
  - Index directory: `~/mcp_tools/kontxt_index`
  - Excludes: `.git`, `.build`, `node_modules`, `Pods`

### 3. Virtual Environment
- **Location**: `~/mcp_tools/mcp_env/`
- **Python**: 3.9.6
- **Pip**: 26.0.1
- **Activation**: `source ~/mcp_tools/mcp_env/bin/activate`

## 🚀 Usage Instructions

### Test Sentence-Transformers
```bash
source ~/mcp_tools/mcp_env/bin/activate
python -c "from sentence_transformers import SentenceTransformer; model = SentenceTransformer('all-MiniLM-L6-v2'); print('Working!')"
```

### Run Kontxt with Local Models
```bash
source ~/mcp_tools/mcp_env/bin/activate
cd ~/mcp_tools/kontxt
python3 kontxt_server.py --config /Users/user/Developer/GitHub/Anigma_clean/kontxt_local_config.json
```

### Run Cursor Local Indexing
```bash
source ~/mcp_tools/mcp_env/bin/activate
cd ~/mcp_tools/cursor-local-indexing
python3 cursor_server.py --config cursor_config.json
```

## 📊 Available Local Models

| Model Name | Dimensions | Use Case |
|------------|-----------|----------|
| `all-MiniLM-L6-v2` | 384 | General purpose |
| `multi-qa-mpnet-base-dot-v1` | 768 | Question answering |
| `paraphrase-multilingual-MiniLM-L12-v2` | 384 | Multilingual |
| `all-mpnet-base-v2` | 768 | High quality |

### Change Model in Config
```json
{
    "embedding_model": "multi-qa-mpnet-base-dot-v1",
    "use_gemini": false
}
```

## 🔧 Troubleshooting

### SSL Warning
If you see OpenSSL warnings:
```bash
# Safe to ignore - macOS uses LibreSSL
# Does not affect functionality
```

### Model Download
First run will download the model (~100MB)
Subsequent runs use cached model

### Permission Issues
```bash
# Ensure proper ownership
chown -R $(whoami):staff ~/mcp_tools
```

## 📚 Comparison: Gemini vs Local

| Feature | Gemini API | Local Models |
|---------|-----------|--------------|
| **API Key** | Required | ❌ Not needed |
| **Cost** | Free tier available | ✅ Free |
| **Privacy** | Cloud processing | ✅ Local only |
| **Quality** | Excellent | Good |
| **Speed** | Fast | ✅ Faster (local) |
| **Offline** | ❌ No | ✅ Yes |

## 🎯 Recommendations

1. **Start with local models** - No setup required
2. **Try different models** - Test which works best
3. **Monitor performance** - Local models are fast!
4. **Add Gemini later** - If you get API key

## 📖 References

- [Sentence-Transformers Docs](https://www.sbert.net/)
- [Local Model Hub](https://www.sbert.net/docs/pretrained_models.html)
- [Kontxt GitHub](https://github.com/reyneill/kontxt)

---

**Status**: ✅ Ready to use
**Next Step**: Start Kontxt server with local config

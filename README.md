# Inertia-Nanobot
**Origin:** Fork of [HKUDS/nanobot](https://github.com/HKUDS/nanobot)  
**Type:** Python / Batch Automation Tool  

**Description:**  
Inertia-Nanobot is a lightweight, local AI agent system integrated with Ollama, featuring model switching and RAG for efficient task automation. Drawing from Kenny Lee's 20+ years as a serial entrepreneur and industrial specialist in power systems, this tool applies physics-inspired optimization to AI workflows, making it accessible for workforce AI literacy. It supports the DOL framework by providing open-source means for engineers and non-coders to experiment with AI agents in manufacturing or drone contexts, toggling models for tailored education.

## What's Different from Upstream

This fork adds the following customizations on top of the original [HKUDS/nanobot](https://github.com/HKUDS/nanobot):

- **Batch Launchers:** Windows `.bat` files for easy start, stop, chat, and help (`run_nanobot.bat`, `nanobot_chat.bat`, `nanobot_help.bat`, `stop_nanobot.bat`)
- **Model Switching:** `switch_model.bat` / `switch_model.ps1` for toggling between models with different context lengths and capabilities
- **Skills Testing:** `test_skills_chat.ps1` for testing calculator, clipboard, and other skills with non-native models
- **Grant-Aligned Narrative:** Descriptions and documentation updated to support AI literacy workforce development

**Key Features:**  
- **Model Switching:** Presets for context lengths and tools, adapting to user skill levels.  
- **RAG Support:** Retrieves from workspace files for context-rich responses.  
- **Tool Use:** Flexible modes for native or text-based interactions.  
- **Safety:** "Hide JSON Mode" prevents leaks, ensuring ethical AI training.  

**How to Use:**  
1. Start Server: Run `run_nanobot.bat`.  
2. Chat: Run `nanobot_chat.bat`.  
3. Switch Models: Use `switch_model.bat`.  
4. Help: Run `nanobot_help.bat`.  
5. RAG: Add files to workspace for searchable context.  

**Alignment Note:** Enhances grant applications by showcasing adaptable AI tools for workforce upskilling, particularly in hardware-software integration for robotics.

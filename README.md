\# Claude Code Local Model Gateway



A lightweight local Anthropic-compatible gateway for using multiple AI providers from Claude Code.



\## Supported Models



| Claude Code model | Provider | Upstream model |

|---|---|---|

| `claude-glm-5-3-flash` | Z.AI | `glm-5.3-flash` |

| `claude-deepseek-v4-flash` | DeepSeek | `deepseek-v4-flash` |



\## Architecture



```text

Claude Code

&#x20;    |

&#x20;    v

127.0.0.1:4000

&#x20;    |

&#x20;    +-------------------------+

&#x20;    |                         |

&#x20;    v                         v

&#x20;  Z.AI                    DeepSeek

&#x20;    |                         |

&#x20;    v                         v

GLM-5.3-Flash             DeepSeek V4 Flash


/** 运行时环境配置（基址通过 .env 注入，不提交真实内网地址） */
export const env = {
  /** IA-server 基址（含 /api）；生产环境走 Nginx 反代时用相对路径 /api */
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || '/api',
  /** IA-AI 基址；生产环境留空时使用与页面同源的 /ai-api（Nginx 反代） */
  aiBaseUrl: import.meta.env.VITE_AI_BASE_URL || `${window.location.origin}/ai-api`,
}

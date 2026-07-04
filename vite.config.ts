import { defineConfig, loadEnv } from "vite";
import uni from "@dcloudio/vite-plugin-uni";

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const difyApiKey = env.DIFY_API_KEY;
  const difyBaseUrl = new URL(env.DIFY_API_BASE_URL || "https://api.dify.ai/v1");
  const difyTarget = `${difyBaseUrl.protocol}//${difyBaseUrl.host}`;
  const difyBasePath = difyBaseUrl.pathname.replace(/\/$/, "");
  const difyProxyPath = env.VITE_DIFY_PROXY_PATH || "/api/dify";
  const proxy = difyApiKey
    ? {
        [difyProxyPath]: {
          target: difyTarget,
          changeOrigin: true,
          secure: true,
          rewrite: (path: string) => `${difyBasePath}${path.replace(new RegExp(`^${difyProxyPath}`), "")}`,
          configure: (proxyServer: { on: (event: string, callback: (proxyReq: { setHeader: (name: string, value: string) => void }) => void) => void }) => {
            proxyServer.on("proxyReq", (proxyReq) => {
              proxyReq.setHeader("Authorization", `Bearer ${difyApiKey}`);
            });
          },
        },
      }
    : undefined;

  return {
    base: "./",
    plugins: [uni()],
    server: { proxy },
    preview: { proxy },
  };
});

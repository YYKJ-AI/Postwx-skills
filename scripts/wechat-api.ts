import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

interface WechatConfig {
  appId: string;
  appSecret: string;
}

interface AccessTokenResponse {
  access_token?: string;
  errcode?: number;
  errmsg?: string;
}

interface UploadResponse {
  media_id: string;
  url: string;
  errcode?: number;
  errmsg?: string;
}

interface PublishResponse {
  media_id?: string;
  errcode?: number;
  errmsg?: string;
}

type ArticleType = "news" | "newspic";

interface ArticleOptions {
  title: string;
  author?: string;
  digest?: string;
  content: string;
  thumbMediaId: string;
  articleType: ArticleType;
  imageMediaIds?: string[];
}

interface ImageGenConfig {
  apiKey: string;
  apiBase: string;
  model: string;
  size: string;
}

interface ImageGenResponse {
  data?: Array<{ url?: string; b64_json?: string }>;
  error?: { message: string };
}

const TOKEN_URL = "https://api.weixin.qq.com/cgi-bin/token";
const UPLOAD_URL = "https://api.weixin.qq.com/cgi-bin/material/add_material";
const DRAFT_URL = "https://api.weixin.qq.com/cgi-bin/draft/add";

function loadEnvFile(envPath: string): Record<string, string> {
  const env: Record<string, string> = {};
  if (!fs.existsSync(envPath)) return env;

  const content = fs.readFileSync(envPath, "utf-8");
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eqIdx = trimmed.indexOf("=");
    if (eqIdx > 0) {
      const key = trimmed.slice(0, eqIdx).trim();
      let value = trimmed.slice(eqIdx + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      env[key] = value;
    }
  }
  return env;
}

function loadConfig(): WechatConfig {
  const appId = process.env.WECHAT_APP_ID;
  const appSecret = process.env.WECHAT_APP_SECRET;

  if (!appId || !appSecret) {
    throw new Error(
      "Missing WECHAT_APP_ID or WECHAT_APP_SECRET.\n" +
        "Please configure credentials in the app settings.",
    );
  }

  return { appId, appSecret };
}

function loadImageGenConfig(): ImageGenConfig | null {
  const apiKey = process.env.IMAGE_API_KEY;

  if (!apiKey) return null;

  return {
    apiKey,
    apiBase: process.env.IMAGE_API_BASE || "https://api.tu-zi.com/v1",
    model: process.env.IMAGE_MODEL || "gpt-image-1",
    size: process.env.IMAGE_SIZE || "1024x1024",
  };
}

async function generateImage(
  prompt: string,
  config: ImageGenConfig,
): Promise<Buffer> {
  const url = `${config.apiBase.replace(/\/+$/, "")}/images/generations`;

  console.error(`[wechat-api] Generating image: ${prompt.slice(0, 80)}...`);

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.apiKey}`,
    },
    body: JSON.stringify({
      model: config.model,
      prompt,
      n: 1,
      size: config.size,
      response_format: "url",
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Image generation API error ${res.status}: ${errText}`);
  }

  const data = (await res.json()) as ImageGenResponse;

  if (data.error) {
    throw new Error(`Image generation failed: ${data.error.message}`);
  }

  if (!data.data || data.data.length === 0) {
    throw new Error("No image returned from API");
  }

  const imageData = data.data[0]!;

  if (imageData.b64_json) {
    return Buffer.from(imageData.b64_json, "base64");
  }

  if (imageData.url) {
    const imgRes = await fetch(imageData.url);
    if (!imgRes.ok) {
      throw new Error(`Failed to download generated image: ${imgRes.status}`);
    }
    return Buffer.from(await imgRes.arrayBuffer());
  }

  throw new Error("No url or b64_json in image generation response");
}

async function processGeneratedImages(
  html: string,
  accessToken: string,
): Promise<string> {
  const imageGenConfig = loadImageGenConfig();
  const genRegex = /<img[^>]*\ssrc=["']__generate:([^"']+)__["'][^>]*>/gi;
  const matches = [...html.matchAll(genRegex)];

  if (matches.length === 0) return html;

  if (!imageGenConfig) {
    console.error(
      "[wechat-api] WARNING: Found __generate: image placeholders but IMAGE_API_KEY not configured. Skipping generation.",
    );
    return html;
  }

  let updatedHtml = html;

  for (const match of matches) {
    const [fullTag, prompt] = match;
    if (!prompt) continue;

    try {
      const imageBuffer = await generateImage(prompt, imageGenConfig);
      const filename = `generated-${Date.now()}.png`;

      // 上传到微信素材库
      const boundary = `----WebKitFormBoundary${Date.now().toString(16)}`;
      const header = [
        `--${boundary}`,
        `Content-Disposition: form-data; name="media"; filename="${filename}"`,
        `Content-Type: image/png`,
        "",
        "",
      ].join("\r\n");
      const footer = `\r\n--${boundary}--\r\n`;

      const headerBuffer = Buffer.from(header, "utf-8");
      const footerBuffer = Buffer.from(footer, "utf-8");
      const body = Buffer.concat([headerBuffer, imageBuffer, footerBuffer]);

      const uploadUrl = `${UPLOAD_URL}?access_token=${accessToken}&type=image`;
      const uploadRes = await fetch(uploadUrl, {
        method: "POST",
        headers: {
          "Content-Type": `multipart/form-data; boundary=${boundary}`,
        },
        body,
      });

      const uploadData = (await uploadRes.json()) as UploadResponse;
      if (uploadData.errcode && uploadData.errcode !== 0) {
        throw new Error(
          `Upload failed ${uploadData.errcode}: ${uploadData.errmsg}`,
        );
      }

      let cdnUrl = uploadData.url;
      if (cdnUrl?.startsWith("http://")) {
        cdnUrl = cdnUrl.replace(/^http:\/\//i, "https://");
      }

      const newTag = fullTag.replace(
        /\ssrc=["']__generate:[^"']+__["']/,
        ` src="${cdnUrl}"`,
      );
      updatedHtml = updatedHtml.replace(fullTag, newTag);

      console.error(
        `[wechat-api] Generated and uploaded image for: ${prompt.slice(0, 50)}...`,
      );
    } catch (err) {
      console.error(
        `[wechat-api] Failed to generate image for "${prompt.slice(0, 50)}...":`,
        err,
      );
    }
  }

  return updatedHtml;
}

async function fetchAccessToken(
  appId: string,
  appSecret: string,
): Promise<string> {
  const url = `${TOKEN_URL}?grant_type=client_credential&appid=${appId}&secret=${appSecret}`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to fetch access token: ${res.status}`);
  }
  const data = (await res.json()) as AccessTokenResponse;
  if (data.errcode) {
    throw new Error(`Access token error ${data.errcode}: ${data.errmsg}`);
  }
  if (!data.access_token) {
    throw new Error("No access_token in response");
  }
  return data.access_token;
}

/** 根据 magic bytes 检测图片格式 */
function detectImageFormat(
  buf: Buffer,
): { mime: string; ext: string } | null {
  if (buf.length < 4) return null;
  // PNG: 89 50 4E 47
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47)
    return { mime: "image/png", ext: "png" };
  // JPEG: FF D8 FF
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff)
    return { mime: "image/jpeg", ext: "jpg" };
  // GIF: 47 49 46
  if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46)
    return { mime: "image/gif", ext: "gif" };
  // WebP: RIFF....WEBP
  if (
    buf.length >= 12 &&
    buf.slice(0, 4).toString("ascii") === "RIFF" &&
    buf.slice(8, 12).toString("ascii") === "WEBP"
  )
    return { mime: "image/webp", ext: "webp" };
  return null;
}

async function uploadImage(
  imagePath: string,
  accessToken: string,
  baseDir?: string,
): Promise<UploadResponse> {
  let fileBuffer: Buffer;
  let filename: string;
  let contentType: string;

  if (imagePath.startsWith("http://") || imagePath.startsWith("https://")) {
    const response = await fetch(imagePath);
    if (!response.ok) {
      throw new Error(`Failed to download image: ${imagePath}`);
    }
    const buffer = await response.arrayBuffer();
    if (buffer.byteLength === 0) {
      throw new Error(`Remote image is empty: ${imagePath}`);
    }
    fileBuffer = Buffer.from(buffer);
    contentType = response.headers.get("content-type") || "image/jpeg";

    // 从 URL 参数推断格式（微信 mmbiz URL 带 wx_fmt 参数）
    const urlObj = new URL(imagePath);
    const wxFmt = urlObj.searchParams.get("wx_fmt");

    // 根据 magic bytes 检测实际格式
    const detected = detectImageFormat(fileBuffer);
    if (detected) {
      contentType = detected.mime;
      filename = `image.${detected.ext}`;
    } else if (wxFmt) {
      const fmtMap: Record<string, { mime: string; ext: string }> = {
        png: { mime: "image/png", ext: "png" },
        jpeg: { mime: "image/jpeg", ext: "jpg" },
        jpg: { mime: "image/jpeg", ext: "jpg" },
        gif: { mime: "image/gif", ext: "gif" },
      };
      const fmt = fmtMap[wxFmt];
      if (fmt) {
        contentType = fmt.mime;
        filename = `image.${fmt.ext}`;
      } else {
        filename = `image.${wxFmt}`;
      }
    } else {
      const urlPath = imagePath.split("?")[0];
      filename = path.basename(urlPath) || "image.jpg";
      // 确保文件名有扩展名
      if (!path.extname(filename)) {
        const extFromMime: Record<string, string> = {
          "image/png": ".png",
          "image/jpeg": ".jpg",
          "image/gif": ".gif",
        };
        filename += extFromMime[contentType] || ".jpg";
      }
    }
  } else {
    const resolvedPath = path.isAbsolute(imagePath)
      ? imagePath
      : path.resolve(baseDir || process.cwd(), imagePath);

    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`Image not found: ${resolvedPath}`);
    }
    const stats = fs.statSync(resolvedPath);
    if (stats.size === 0) {
      throw new Error(`Local image is empty: ${resolvedPath}`);
    }
    fileBuffer = fs.readFileSync(resolvedPath);
    filename = path.basename(resolvedPath);
    const ext = path.extname(filename).toLowerCase();
    const mimeTypes: Record<string, string> = {
      ".jpg": "image/jpeg",
      ".jpeg": "image/jpeg",
      ".png": "image/png",
      ".gif": "image/gif",
      ".webp": "image/webp",
    };
    contentType = mimeTypes[ext] || "image/jpeg";
  }

  // 检测 webp 魔术字节并转换为 PNG（微信 API 不支持 webp）
  if (
    fileBuffer.length >= 12 &&
    fileBuffer.slice(0, 4).toString("ascii") === "RIFF" &&
    fileBuffer.slice(8, 12).toString("ascii") === "WEBP"
  ) {
    console.error("[wechat-api] Detected WebP image, converting to PNG...");
    const tmpWebp = path.join(os.tmpdir(), `postwx-${Date.now()}.webp`);
    const tmpPng = tmpWebp.replace(/\.webp$/, ".png");
    fs.writeFileSync(tmpWebp, fileBuffer);
    const sipsResult = spawnSync(
      "sips",
      ["-s", "format", "png", tmpWebp, "--out", tmpPng],
      {
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    if (sipsResult.status !== 0) {
      throw new Error(
        `WebP to PNG conversion failed: ${sipsResult.stderr?.toString()}`,
      );
    }
    fileBuffer = fs.readFileSync(tmpPng);
    filename = filename.replace(/\.webp$/i, ".png");
    contentType = "image/png";
  }

  const boundary = `----WebKitFormBoundary${Date.now().toString(16)}`;
  const header = [
    `--${boundary}`,
    `Content-Disposition: form-data; name="media"; filename="${filename}"`,
    `Content-Type: ${contentType}`,
    "",
    "",
  ].join("\r\n");
  const footer = `\r\n--${boundary}--\r\n`;

  const headerBuffer = Buffer.from(header, "utf-8");
  const footerBuffer = Buffer.from(footer, "utf-8");
  const body = Buffer.concat([headerBuffer, fileBuffer, footerBuffer]);

  const url = `${UPLOAD_URL}?access_token=${accessToken}&type=image`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
    },
    body,
  });

  const data = (await res.json()) as UploadResponse;
  if (data.errcode && data.errcode !== 0) {
    throw new Error(`Upload failed ${data.errcode}: ${data.errmsg}`);
  }

  if (data.url?.startsWith("http://")) {
    data.url = data.url.replace(/^http:\/\//i, "https://");
  }

  return data;
}

async function uploadImagesInHtml(
  html: string,
  accessToken: string,
  baseDir: string,
): Promise<{ html: string; firstMediaId: string; allMediaIds: string[] }> {
  const imgRegex = /<img[^>]*\ssrc=["']([^"']+)["'][^>]*>/gi;
  const matches = [...html.matchAll(imgRegex)];

  if (matches.length === 0) {
    return { html, firstMediaId: "", allMediaIds: [] };
  }

  let firstMediaId = "";
  let updatedHtml = html;
  const allMediaIds: string[] = [];

  for (const match of matches) {
    const [fullTag, src] = match;
    if (!src) continue;

    if (src.startsWith("https://mmbiz.qpic.cn")) {
      if (!firstMediaId) {
        firstMediaId = src;
      }
      continue;
    }

    const localPathMatch = fullTag.match(/data-local-path=["']([^"']+)["']/);
    const imagePath = localPathMatch ? localPathMatch[1]! : src;

    console.error(`[wechat-api] Uploading image: ${imagePath}`);
    try {
      const resp = await uploadImage(imagePath, accessToken, baseDir);
      const newTag = fullTag
        .replace(/\ssrc=["'][^"']+["']/, ` src="${resp.url}"`)
        .replace(/\sdata-local-path=["'][^"']+["']/, "");
      updatedHtml = updatedHtml.replace(fullTag, newTag);
      allMediaIds.push(resp.media_id);
      if (!firstMediaId) {
        firstMediaId = resp.media_id;
      }
    } catch (err) {
      console.error(`[wechat-api] Failed to upload ${imagePath}:`, err);
    }
  }

  return { html: updatedHtml, firstMediaId, allMediaIds };
}

async function publishToDraft(
  options: ArticleOptions,
  accessToken: string,
): Promise<PublishResponse> {
  const url = `${DRAFT_URL}?access_token=${accessToken}`;

  let article: Record<string, unknown>;

  if (options.articleType === "newspic") {
    if (!options.imageMediaIds || options.imageMediaIds.length === 0) {
      throw new Error("newspic requires at least one image");
    }
    article = {
      article_type: "newspic",
      title: options.title,
      content: options.content,
      need_open_comment: 1,
      only_fans_can_comment: 0,
      image_info: {
        image_list: options.imageMediaIds.map((id) => ({ image_media_id: id })),
      },
    };
    if (options.author) article.author = options.author;
  } else {
    article = {
      article_type: "news",
      title: options.title,
      content: options.content,
      thumb_media_id: options.thumbMediaId,
      need_open_comment: 1,
      only_fans_can_comment: 0,
    };
    if (options.author) article.author = options.author;
    if (options.digest) article.digest = options.digest;
  }

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ articles: [article] }),
  });

  const data = (await res.json()) as PublishResponse;
  if (data.errcode && data.errcode !== 0) {
    throw new Error(`Publish failed ${data.errcode}: ${data.errmsg}`);
  }

  return data;
}

function parseFrontmatter(content: string): {
  frontmatter: Record<string, string>;
  body: string;
} {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, body: content };

  const frontmatter: Record<string, string> = {};
  const lines = match[1]!.split("\n");
  for (const line of lines) {
    const colonIdx = line.indexOf(":");
    if (colonIdx > 0) {
      const key = line.slice(0, colonIdx).trim();
      let value = line.slice(colonIdx + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      frontmatter[key] = value;
    }
  }

  return { frontmatter, body: match[2]! };
}

function renderMarkdownToHtml(
  markdownPath: string,
  theme: string = "default",
  color?: string,
): string {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  const renderScript = path.join(__dirname, "md", "render.ts");
  const baseDir = path.dirname(markdownPath);

  const renderArgs = [
    "-y",
    "bun",
    renderScript,
    markdownPath,
    "--theme",
    theme,
  ];
  if (color) renderArgs.push("--color", color);

  console.error(
    `[wechat-api] Rendering markdown with theme: ${theme}${color ? `, color: ${color}` : ""}`,
  );
  const result = spawnSync("npx", renderArgs, {
    stdio: ["inherit", "pipe", "pipe"],
    cwd: baseDir,
  });

  if (result.status !== 0) {
    const stderr = result.stderr?.toString() || "";
    throw new Error(`Render failed: ${stderr}`);
  }

  const htmlPath = markdownPath.replace(/\.md$/i, ".html");
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`HTML file not generated: ${htmlPath}`);
  }

  return htmlPath;
}

function extractHtmlContent(htmlPath: string): string {
  const html = fs.readFileSync(htmlPath, "utf-8");
  const match = html.match(/<div id="output">([\s\S]*?)<\/div>\s*<\/body>/);
  if (match) {
    return match[1]!.trim();
  }
  const bodyMatch = html.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
  return bodyMatch ? bodyMatch[1]!.trim() : html;
}

function printUsage(): never {
  console.log(`Publish article to WeChat Official Account draft using API

Usage:
  npx -y bun wechat-api.ts <file> [options]

Arguments:
  file                Markdown (.md) or HTML (.html) file

Options:
  --type <type>       Article type: news (文章, default) or newspic (图文)
  --title <title>     Override title
  --author <name>     Author name (max 16 chars)
  --summary <text>    Article summary/digest (max 128 chars)
  --theme <name>      Theme name for markdown (default, grace, simple, modern). Default: default
  --color <name|hex>  Primary color (blue, green, vermilion, etc. or hex)
  --cover <path>      Cover image path (local or URL)
  --dry-run           Parse and render only, don't publish
  --help              Show this help

Frontmatter Fields (markdown):
  title               Article title
  author              Author name
  digest/summary      Article summary
  coverImage/featureImage/cover/image   Cover image path

Comments:
  Comments are enabled by default, open to all users.

Environment Variables:
  WECHAT_APP_ID       WeChat App ID
  WECHAT_APP_SECRET   WeChat App Secret
  IMAGE_API_KEY       API key for AI image generation (api.tu-zi.com)

Config File Locations (in priority order):
  1. Environment variables
  2. <cwd>/.baoyu-skills/.env
  3. ~/.baoyu-skills/.env

Example:
  npx -y bun wechat-api.ts article.md
  npx -y bun wechat-api.ts article.md --theme grace --cover cover.png
  npx -y bun wechat-api.ts article.md --author "Author Name" --summary "Brief intro"
  npx -y bun wechat-api.ts article.html --title "My Article"
  npx -y bun wechat-api.ts images/ --type newspic --title "Photo Album"
  npx -y bun wechat-api.ts article.md --dry-run
`);
  process.exit(0);
}

interface CliArgs {
  filePath: string;
  isHtml: boolean;
  articleType: ArticleType;
  title?: string;
  author?: string;
  summary?: string;
  theme: string;
  color?: string;
  cover?: string;
  dryRun: boolean;
}

function parseArgs(argv: string[]): CliArgs {
  if (argv.length === 0 || argv.includes("--help") || argv.includes("-h")) {
    printUsage();
  }

  const args: CliArgs = {
    filePath: "",
    isHtml: false,
    articleType: "news",
    theme: "default",
    dryRun: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]!;
    if (arg === "--type" && argv[i + 1]) {
      const t = argv[++i]!.toLowerCase();
      if (t === "news" || t === "newspic") {
        args.articleType = t;
      }
    } else if (arg === "--title" && argv[i + 1]) {
      args.title = argv[++i];
    } else if (arg === "--author" && argv[i + 1]) {
      args.author = argv[++i];
    } else if (arg === "--summary" && argv[i + 1]) {
      args.summary = argv[++i];
    } else if (arg === "--theme" && argv[i + 1]) {
      args.theme = argv[++i]!;
    } else if (arg === "--color" && argv[i + 1]) {
      args.color = argv[++i];
    } else if (arg === "--cover" && argv[i + 1]) {
      args.cover = argv[++i];
    } else if (arg === "--dry-run") {
      args.dryRun = true;
    } else if (
      arg.startsWith("--") &&
      argv[i + 1] &&
      !argv[i + 1]!.startsWith("-")
    ) {
      i++;
    } else if (!arg.startsWith("-")) {
      args.filePath = arg;
    }
  }

  if (!args.filePath) {
    console.error("Error: File path required");
    process.exit(1);
  }

  args.isHtml = args.filePath.toLowerCase().endsWith(".html");

  return args;
}

function extractHtmlTitle(html: string): string {
  const titleMatch = html.match(/<title>([^<]+)<\/title>/i);
  if (titleMatch) return titleMatch[1]!;
  const h1Match = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
  if (h1Match) return h1Match[1]!.replace(/<[^>]+>/g, "").trim();
  return "";
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  const filePath = path.resolve(args.filePath);
  if (!fs.existsSync(filePath)) {
    console.error(`Error: File not found: ${filePath}`);
    process.exit(1);
  }

  const baseDir = path.dirname(filePath);
  let title = args.title || "";
  let author = args.author || "";
  let digest = args.summary || "";
  let htmlPath: string;
  let htmlContent: string;
  let frontmatter: Record<string, string> = {};

  if (args.isHtml) {
    htmlPath = filePath;
    htmlContent = extractHtmlContent(htmlPath);
    const mdPath = filePath.replace(/\.html$/i, ".md");
    if (fs.existsSync(mdPath)) {
      const mdContent = fs.readFileSync(mdPath, "utf-8");
      const parsed = parseFrontmatter(mdContent);
      frontmatter = parsed.frontmatter;
      if (!title && frontmatter.title) title = frontmatter.title;
      if (!author) author = frontmatter.author || "";
      if (!digest)
        digest =
          frontmatter.digest ||
          frontmatter.summary ||
          frontmatter.description ||
          "";
    }
    if (!title) {
      title = extractHtmlTitle(fs.readFileSync(htmlPath, "utf-8"));
    }
    console.error(`[wechat-api] Using HTML file: ${htmlPath}`);
  } else {
    const content = fs.readFileSync(filePath, "utf-8");
    const parsed = parseFrontmatter(content);
    frontmatter = parsed.frontmatter;
    const body = parsed.body;

    title = title || frontmatter.title || "";
    if (!title) {
      const h1Match = body.match(/^#\s+(.+)$/m);
      if (h1Match) title = h1Match[1]!;
    }
    if (!author) author = frontmatter.author || "";
    if (!digest)
      digest =
        frontmatter.digest ||
        frontmatter.summary ||
        frontmatter.description ||
        "";

    // 预处理: 将 ![alt](__generate:prompt__) 转为 HTML img 标签，防止 __ 被渲染为粗体
    const generateImgRegex = /!\[([^\]]*)\]\(__generate:(.+?)__\)/g;
    let renderFilePath = filePath;
    if (generateImgRegex.test(body)) {
      const preprocessed = body.replace(
        /!\[([^\]]*)\]\(__generate:(.+?)__\)/g,
        '<img src="__generate:$2__" alt="$1">',
      );
      const tmpDir = os.tmpdir();
      const tmpFile = path.join(tmpDir, `postwx-${Date.now()}.md`);
      // 保留 frontmatter + 替换后的 body
      const originalContent = fs.readFileSync(filePath, "utf-8");
      const fmMatch = originalContent.match(/^(---\r?\n[\s\S]*?\r?\n---\r?\n)/);
      const fmPart = fmMatch ? fmMatch[1] : "";
      fs.writeFileSync(tmpFile, fmPart + preprocessed, "utf-8");
      renderFilePath = tmpFile;
    }

    console.error(
      `[wechat-api] Theme: ${args.theme}${args.color ? `, color: ${args.color}` : ""}`,
    );
    htmlPath = renderMarkdownToHtml(renderFilePath, args.theme, args.color);
    console.error(`[wechat-api] HTML generated: ${htmlPath}`);
    htmlContent = extractHtmlContent(htmlPath);
  }

  if (!title) {
    console.error(
      "Error: No title found. Provide via --title, frontmatter, or <title> tag.",
    );
    process.exit(1);
  }

  if (digest && digest.length > 120) {
    const truncated = digest.slice(0, 117);
    const lastPunct = Math.max(
      truncated.lastIndexOf("。"),
      truncated.lastIndexOf("，"),
      truncated.lastIndexOf("；"),
      truncated.lastIndexOf("、"),
    );
    digest =
      lastPunct > 80 ? truncated.slice(0, lastPunct + 1) : truncated + "...";
    console.error(`[wechat-api] Digest truncated to ${digest.length} chars`);
  }

  console.error(`[wechat-api] Title: ${title}`);
  if (author) console.error(`[wechat-api] Author: ${author}`);
  if (digest) console.error(`[wechat-api] Digest: ${digest.slice(0, 50)}...`);
  console.error(`[wechat-api] Type: ${args.articleType}`);

  if (args.dryRun) {
    console.log(
      JSON.stringify(
        {
          articleType: args.articleType,
          title,
          author: author || undefined,
          digest: digest || undefined,
          htmlPath,
          contentLength: htmlContent.length,
        },
        null,
        2,
      ),
    );
    return;
  }

  const config = loadConfig();
  console.error("[wechat-api] Fetching access token...");
  const accessToken = await fetchAccessToken(config.appId, config.appSecret);

  // 先处理 AI 生成图片占位符（__generate:prompt__）
  console.error("[wechat-api] Processing generated images...");
  htmlContent = await processGeneratedImages(htmlContent, accessToken);

  // 再上传所有图片（本地 + 远程 + 已生成的）
  console.error("[wechat-api] Uploading images...");
  const {
    html: processedHtml,
    firstMediaId,
    allMediaIds,
  } = await uploadImagesInHtml(htmlContent, accessToken, baseDir);
  htmlContent = processedHtml;

  let thumbMediaId = "";
  const rawCoverPath =
    args.cover ||
    frontmatter.coverImage ||
    frontmatter.featureImage ||
    frontmatter.cover ||
    frontmatter.image;
  const coverPath =
    rawCoverPath && !path.isAbsolute(rawCoverPath) && args.cover
      ? path.resolve(process.cwd(), rawCoverPath)
      : rawCoverPath;

  if (
    coverPath &&
    coverPath.startsWith("__generate:") &&
    coverPath.endsWith("__")
  ) {
    // AI 生成封面图
    const imageGenConfig = loadImageGenConfig();
    if (!imageGenConfig) {
      console.error(
        "Error: --cover uses __generate: but IMAGE_API_KEY not configured.",
      );
      process.exit(1);
    }
    const prompt = coverPath.slice("__generate:".length, -2);
    console.error(
      `[wechat-api] Generating cover image: ${prompt.slice(0, 80)}...`,
    );
    const imageBuffer = await generateImage(prompt, imageGenConfig);
    const tmpCover = path.join(os.tmpdir(), `postwx-cover-${Date.now()}.png`);
    fs.writeFileSync(tmpCover, imageBuffer);
    console.error(`[wechat-api] Uploading generated cover: ${tmpCover}`);
    const coverResp = await uploadImage(tmpCover, accessToken, baseDir);
    thumbMediaId = coverResp.media_id;
  } else if (coverPath) {
    console.error(`[wechat-api] Uploading cover: ${coverPath}`);
    const coverResp = await uploadImage(coverPath, accessToken, baseDir);
    thumbMediaId = coverResp.media_id;
  } else if (firstMediaId) {
    if (firstMediaId.startsWith("https://")) {
      console.error(
        `[wechat-api] Uploading first image as cover: ${firstMediaId}`,
      );
      const coverResp = await uploadImage(firstMediaId, accessToken, baseDir);
      thumbMediaId = coverResp.media_id;
    } else {
      thumbMediaId = firstMediaId;
    }
  }

  if (args.articleType === "news" && !thumbMediaId) {
    // 尝试自动生成封面图
    const imageGenConfig = loadImageGenConfig();
    if (imageGenConfig) {
      const coverPrompt = `Design a clean, modern cover image for an article titled "${title}". Minimalist style, suitable for WeChat Official Account.`;
      console.error(`[wechat-api] No cover image found, auto-generating from title...`);
      const imageBuffer = await generateImage(coverPrompt, imageGenConfig);
      const tmpCover = path.join(os.tmpdir(), `postwx-cover-${Date.now()}.png`);
      fs.writeFileSync(tmpCover, imageBuffer);
      console.error(`[wechat-api] Uploading auto-generated cover: ${tmpCover}`);
      const coverResp = await uploadImage(tmpCover, accessToken, baseDir);
      thumbMediaId = coverResp.media_id;
    } else {
      console.error(
        "Error: No cover image. Provide via --cover, frontmatter.coverImage, include an image in content, or configure IMAGE_API_KEY for auto-generation.",
      );
      process.exit(1);
    }
  }

  if (args.articleType === "newspic" && allMediaIds.length === 0) {
    console.error("Error: newspic requires at least one image in content.");
    process.exit(1);
  }

  console.error("[wechat-api] Publishing to draft...");
  const result = await publishToDraft(
    {
      title,
      author: author || undefined,
      digest: digest || undefined,
      content: htmlContent,
      thumbMediaId,
      articleType: args.articleType,
      imageMediaIds: args.articleType === "newspic" ? allMediaIds : undefined,
    },
    accessToken,
  );

  console.log(
    JSON.stringify(
      {
        success: true,
        media_id: result.media_id,
        title,
        articleType: args.articleType,
      },
      null,
      2,
    ),
  );

  console.error(
    `[wechat-api] Published successfully! media_id: ${result.media_id}`,
  );
}

await main().catch((err) => {
  console.error(`Error: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});

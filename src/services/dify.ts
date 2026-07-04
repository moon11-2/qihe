export type DifyIntent = "review" | "generate" | "consult";
export type DifyMode = DifyIntent | "auto";

export interface LocalUploadFile {
  name: string;
  path: string;
  size?: number;
  type?: string;
}

export interface ContractAnalysisPayload {
  mode: DifyMode;
  query: string;
  contractText: string;
  contractType: string;
  role: string;
  focusAreas: string[];
  requirements: string;
  jurisdiction?: string;
  outputStyle?: string;
  conversationId?: string;
  file?: LocalUploadFile | null;
}

export interface ContractResult {
  intent: DifyIntent;
  status?: "complete" | "need_input" | string;
  result_type?: string;
  title?: string;
  contract_title?: string;
  contract_type?: string;
  role?: string;
  score?: number;
  grade?: string;
  grade_label?: string;
  risk_level?: string;
  score_explanation?: string;
  summary?: string;
  topic?: string;
  markdown_report?: string;
  contract_markdown?: string;
  answer_markdown?: string;
  missing_fields?: string[];
  followup_questions?: string[];
  key_points?: Array<string | Record<string, unknown>>;
  practical_tips?: Array<string | Record<string, unknown>>;
  key_findings?: Array<Record<string, unknown>>;
  clause_reviews?: Array<Record<string, unknown>>;
  suggested_revisions?: Array<Record<string, unknown>>;
  suggested_actions?: Array<string | Record<string, unknown>>;
  risk_notes?: Array<string | Record<string, unknown>>;
  signing_checklist?: Array<string | Record<string, unknown>>;
  signature_checklist?: Array<string | Record<string, unknown>>;
  facts?: Record<string, unknown> | Array<Record<string, unknown>>;
  information_completeness?: Record<string, unknown>;
  legal_references?: Array<Record<string, unknown>>;
  recommended_mode?: DifyMode;
  disclaimer?: string;
  raw_answer?: string;
  parse_error?: string;
  [key: string]: unknown;
}

export interface ContractAnalysisResponse {
  result: ContractResult;
  conversationId: string;
  messageId: string;
  rawAnswer: string;
  source: "dify" | "mock";
}

interface DifyFileUploadResponse {
  id: string;
  name?: string;
  size?: number;
  extension?: string;
  mime_type?: string;
}

interface DifyChatResponse {
  answer?: string;
  conversation_id?: string;
  message_id?: string;
  task_id?: string;
}

const DIFY_ENABLED = import.meta.env.VITE_DIFY_ENABLED === "true";
const DIFY_PROXY_PATH = import.meta.env.VITE_DIFY_PROXY_PATH || "/api/dify";

export function isDifyEnabled() {
  return DIFY_ENABLED;
}

export function getServiceModeLabel() {
  return DIFY_ENABLED ? "Dify" : "Mock";
}

export async function runContractAnalysis(payload: ContractAnalysisPayload): Promise<ContractAnalysisResponse> {
  if (!DIFY_ENABLED) {
    return mockContractAnalysis(payload);
  }

  const user = getOrCreateUserId();
  const fileVariable = payload.file ? await uploadDifyFile(payload.file, user) : null;
  const inputs: Record<string, unknown> = {
    mode: payload.mode,
    contract_text: payload.contractText,
    contract_type: payload.contractType,
    role: payload.role,
    focus_areas: payload.focusAreas.join("，"),
    requirements: payload.requirements,
    jurisdiction: payload.jurisdiction || "中国大陆",
    output_style: payload.outputStyle || "普通用户可读",
  };

  if (fileVariable) {
    inputs.contract_file = {
      type: "document",
      transfer_method: "local_file",
      upload_file_id: fileVariable.id,
    };
  }

  const response = await request<DifyChatResponse>({
    url: `${DIFY_PROXY_PATH}/chat-messages`,
    method: "POST",
    data: {
      inputs,
      query: buildQuery(payload),
      response_mode: "blocking",
      conversation_id: payload.conversationId || "",
      user,
    },
  });

  const rawAnswer = response.answer || "";
  return {
    result: parseDifyAnswer(rawAnswer, payload.mode),
    conversationId: response.conversation_id || payload.conversationId || "",
    messageId: response.message_id || "",
    rawAnswer,
    source: "dify",
  };
}

async function uploadDifyFile(file: LocalUploadFile, user: string): Promise<DifyFileUploadResponse> {
  return new Promise((resolve, reject) => {
    uni.uploadFile({
      url: `${DIFY_PROXY_PATH}/files/upload`,
      filePath: file.path,
      name: "file",
      formData: { user },
      success: (res) => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`Dify 文件上传失败：HTTP ${res.statusCode}`));
          return;
        }
        try {
          resolve(JSON.parse(res.data || "{}") as DifyFileUploadResponse);
        } catch {
          reject(new Error("Dify 文件上传返回不是有效 JSON"));
        }
      },
      fail: (error) => reject(new Error(error.errMsg || "Dify 文件上传失败")),
    });
  });
}

function request<T>(options: UniApp.RequestOptions): Promise<T> {
  return new Promise((resolve, reject) => {
    uni.request({
      ...options,
      header: {
        "Content-Type": "application/json",
        ...(options.header || {}),
      },
      success: (res) => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          const detail = typeof res.data === "string" ? res.data : JSON.stringify(res.data || {});
          reject(new Error(`Dify 请求失败：HTTP ${res.statusCode} ${detail}`));
          return;
        }
        resolve(res.data as T);
      },
      fail: (error) => reject(new Error(error.errMsg || "Dify 请求失败")),
    });
  });
}

function buildQuery(payload: ContractAnalysisPayload) {
  const query = payload.query.trim();
  if (query) return query;
  if (payload.mode === "generate") return `请生成一份${payload.contractType}。${payload.contractText}`;
  if (payload.mode === "review") return `请审查这份${payload.contractType}。${payload.contractText.slice(0, 500)}`;
  return payload.contractText || payload.requirements || "请帮我处理合同相关问题。";
}

function parseDifyAnswer(answer: string, fallbackMode: DifyMode): ContractResult {
  const cleaned = cleanJsonText(answer);
  try {
    const parsed = JSON.parse(cleaned) as ContractResult;
    return normalizeDifyResult(parsed, fallbackMode, answer);
  } catch (error) {
    const intent = fallbackIntent(fallbackMode);
    const isConsultLike = intent === "consult";
    return {
      intent,
      status: "complete",
      result_type: "raw_answer",
      title: isConsultLike ? "合同咨询" : "契合结果",
      summary: isConsultLike ? "我可以帮你审查已有合同、生成合同草案，也可以先回答合同相关问题。" : "Dify 已返回结果，当前按原文整理展示。",
      answer_markdown: normalizeBrandText(answer) || "你可以直接粘贴合同让我审查，也可以描述想生成的合同。",
      raw_answer: answer,
      parse_error: error instanceof Error ? error.message : "parse_error",
    };
  }
}

function normalizeDifyResult(result: ContractResult, fallbackMode: DifyMode, rawAnswer: string, allowUnwrap = true): ContractResult {
  if (allowUnwrap) {
    const nested = extractNestedContractResult(result);
    if (nested) {
      const normalizedNested = normalizeDifyResult(nested, fallbackMode, rawAnswer, false);
      normalizedNested.raw_answer = rawAnswer;
      return normalizedNested;
    }
  }

  const normalized = normalizeBrandInResult(result);
  if (!isSupportedIntent(normalized.intent)) {
    normalized.intent = fallbackIntent(fallbackMode, normalized);
  }
  return normalized;
}

function extractNestedContractResult(result: ContractResult): ContractResult | null {
  if (typeof result.answer_markdown !== "string") return null;
  const summary = typeof result.summary === "string" ? result.summary : "";
  const looksLikeWrappedParseFallback = /标准\s*JSON|模型输出/.test(summary) || result.result_type === "raw_answer";
  if (!looksLikeWrappedParseFallback) return null;

  try {
    const nested = JSON.parse(cleanJsonText(result.answer_markdown)) as ContractResult;
    if (nested && typeof nested === "object") return nested;
  } catch {
    return null;
  }
  return null;
}

function normalizeBrandInResult(result: ContractResult): ContractResult {
  return normalizeBrandValue(result) as ContractResult;
}

function normalizeBrandValue(value: unknown): unknown {
  if (typeof value === "string") return normalizeBrandText(value);
  if (Array.isArray(value)) return value.map((item) => normalizeBrandValue(item));
  if (value && typeof value === "object") {
    const output: Record<string, unknown> = {};
    Object.entries(value as Record<string, unknown>).forEach(([key, item]) => {
      output[key] = normalizeBrandValue(item);
    });
    return output;
  }
  return value;
}

function normalizeBrandText(text: string) {
  return text.replace(/合同帮V1/g, "契合").replace(/合同帮/g, "契合");
}

function fallbackIntent(mode: DifyMode, result?: ContractResult): DifyIntent {
  if (mode === "consult") return "consult";
  if (mode === "generate") return "generate";
  if (mode === "review") return "review";
  if (result?.contract_markdown) return "generate";
  if (result?.markdown_report || result?.clause_reviews) return "review";
  if (result?.answer_markdown && !result?.markdown_report) return "consult";
  return "consult";
}

function isSupportedIntent(intent: unknown): intent is DifyIntent {
  return intent === "review" || intent === "generate" || intent === "consult";
}

function cleanJsonText(text: string) {
  const noThink = (text || "").replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
  const fenced = noThink.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  const body = fenced ? fenced[1].trim() : noThink;
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start >= 0 && end > start) {
    return body.slice(start, end + 1);
  }
  return body;
}

function getOrCreateUserId() {
  const key = "qihe-dify-user";
  const saved = uni.getStorageSync(key);
  if (typeof saved === "string" && saved) return saved;
  const user = `qihe-h5-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  uni.setStorageSync(key, user);
  return user;
}

async function mockContractAnalysis(payload: ContractAnalysisPayload): Promise<ContractAnalysisResponse> {
  await new Promise((resolve) => setTimeout(resolve, 520));
  const mode = resolveMockIntent(payload);
  const result = mode === "generate" ? mockGenerateResult(payload) : mode === "consult" ? mockConsultResult(payload) : mockReviewResult(payload);
  return {
    result,
    conversationId: `mock-${Date.now()}`,
    messageId: `mock-message-${Date.now()}`,
    rawAnswer: JSON.stringify(result),
    source: "mock",
  };
}

function resolveMockIntent(payload: ContractAnalysisPayload): DifyIntent {
  if (payload.mode !== "auto") return payload.mode;
  const text = `${payload.query}\n${payload.contractText}\n${payload.requirements}`;
  if (/生成|起草|草拟|拟一份|写一份|做个|做一份|合同模板|草案/.test(text)) return "generate";
  if (/审查|审核|检查|风险|能不能签|有没有问题|这份合同|甲方[:：]|乙方[:：]/.test(text)) return "review";
  return "consult";
}

function mockConsultResult(payload: ContractAnalysisPayload): ContractResult {
  const text = payload.query || payload.contractText || "合同问题咨询";
  return {
    intent: "consult",
    status: "complete",
    result_type: "contract_consultation",
    title: "合同咨询",
    topic: text.slice(0, 40),
    contract_type: payload.contractType || "不确定",
    role: payload.role || "未知",
    summary: "我可以帮你审查已有合同，也可以根据你的需求生成合同草案。",
    answer_markdown: "我可以帮你做两件事：\n\n1. 审查已有合同，指出风险和修改建议。\n2. 生成合同草案，并列出签署前需要补齐的信息。\n\n如果你已经有合同，直接粘贴或上传；如果要生成合同，说清合同类型、你的身份、金额、期限和特殊约定。",
    key_points: ["审查已有合同", "生成合同草案", "信息不足时先追问"],
    practical_tips: ["生成正式合同时不要编造姓名、身份证号、金额和日期。"],
    risk_notes: ["AI 辅助说明不替代律师意见，重要合同签署前仍建议复核。"],
    recommended_mode: "auto",
    followup_questions: ["你是想审查一份已有合同，还是生成一份新合同？"],
    suggested_actions: ["粘贴合同正文开始审查", "描述合同需求开始生成"],
    legal_references: [{ title: "法规知识库未连接", verification_status: "not_connected" }],
    disclaimer: "AI 辅助说明不构成律师法律意见；重要合同请交由专业律师复核。",
  };
}

function mockReviewResult(payload: ContractAnalysisPayload): ContractResult {
  const hasInput = Boolean(payload.contractText || payload.file);
  const focusText = payload.focusAreas.length ? payload.focusAreas.join("、") : "付款验收、违约责任和争议解决";
  return {
    intent: "review",
    status: hasInput ? "complete" : "need_input",
    result_type: "review_report",
    title: `${payload.contractType}审查报告`,
    contract_type: payload.contractType,
    role: payload.role,
    score: hasInput ? 76 : 0,
    grade: hasInput ? "C" : "E",
    grade_label: hasInput ? "中等风险，风险可控，但关键条款应修改后再使用" : "信息严重不足，暂不能完成可靠审查",
    risk_level: hasInput ? "medium" : "unknown",
    score_explanation: hasInput ? `主体和履行事项基本可识别，本次已优先检查${focusText}。` : "缺少合同正文，无法判断风险。",
    summary: hasInput ? `模拟审查结果：这份合同可以作为沟通基础，建议先处理${focusText}相关问题，再进入签署流程。` : "请先提供合同正文或上传合同文件。",
    markdown_report: hasInput
      ? `# 审查结论\n\n这份合同当前可作为沟通基础，但不建议直接签署。\n\n## 审查重点\n\n${focusText}\n\n## 合同安全分\n\n76 分，C 级。\n\n## 重点风险\n\n1. 付款节点和验收条件需要绑定。\n2. 违约责任需要明确计算方式和上限。\n3. 争议解决条款需要确认管辖地。\n\n## 建议修改\n\n建议补充交付验收标准、付款前置条件和解除终止机制。`
      : "请先提供合同正文。",
    key_findings: [
      { title: "付款条件不够明确", risk_level: "medium", suggestion: "补充付款节点、发票和验收前置条件。" },
      { title: "违约责任偏概括", risk_level: "medium", suggestion: "写明违约金比例、赔偿范围和免责边界。" },
    ],
    clause_reviews: hasInput
      ? [
          {
            clause_title: "付款与验收",
            risk_level: "medium",
            issue: "付款节点没有和交付验收结果绑定，可能出现对方未完成交付但仍主张付款的争议。",
            suggestion: "把付款触发条件写成“验收合格后 X 日内支付”，并补充发票、逾期付款和异议处理。",
            replacement_text: "甲方应在乙方交付成果并经甲方书面验收合格后 7 个工作日内支付对应款项；乙方应同步提供合法有效发票。",
          },
          {
            clause_title: "违约责任",
            risk_level: "medium",
            issue: "违约条款只写了概括性责任，没有约定违约金比例、补救期限和赔偿边界。",
            suggestion: "明确逾期履行、质量不合格、擅自解除等场景的计算方式。",
            replacement_text: "任一方违约的，守约方可要求违约方在 5 个工作日内补救；造成损失的，违约方应赔偿直接损失，违约金可按未履行部分价款的每日 0.05% 计算。",
          },
          {
            clause_title: "争议解决",
            risk_level: "low",
            issue: "争议解决条款未明确管辖法院，后续维权成本不确定。",
            suggestion: "优先约定与我方更便利、且有实际连接点的法院。",
            replacement_text: "因本合同产生的争议，双方应先协商；协商不成的，提交甲方住所地有管辖权的人民法院诉讼解决。",
          },
        ]
      : [],
    facts: hasInput
      ? {
          合同类型: payload.contractType,
          我方身份: payload.role || "未填写",
          审查重点: focusText,
          审查地区: payload.jurisdiction || "中国大陆",
          文本来源: payload.file ? "上传文件" : "粘贴文本",
        }
      : {},
    suggested_revisions: hasInput
      ? [
          { title: "补齐主体证照", detail: "签署前确认对方主体名称、统一社会信用代码和授权代表。" },
          { title: "绑定付款与验收", detail: "付款前置条件建议写成验收合格或书面确认。" },
        ]
      : [],
    missing_fields: hasInput ? ["对方主体证照信息", "明确签署日期"] : ["合同正文"],
    followup_questions: ["是否需要我把重点风险改成可直接替换的条款？"],
    legal_references: [{ title: "法规知识库未连接", verification_status: "not_connected" }],
    disclaimer: "AI 辅助审查，不构成律师法律意见；重要合同请交由专业律师复核。",
  };
}

function mockGenerateResult(payload: ContractAnalysisPayload): ContractResult {
  const hasInput = Boolean(payload.contractText || payload.requirements);
  const contractType = payload.contractType || "合同草案";
  const scenario = payload.contractText || payload.requirements || "相关事项";
  const clauseText = payload.focusAreas.length ? payload.focusAreas.join("、") : "双方信息、价款报酬、履行安排、违约责任";
  const isRental = /租房|租赁|房东|承租|押金|租金/.test(`${contractType}\n${scenario}`);
  const contractTitle = isRental ? "房屋租赁合同" : contractType;
  const purpose = isRental ? "房屋租赁事宜" : scenario;
  return {
    intent: "generate",
    status: hasInput ? "complete" : "need_input",
    result_type: "contract_draft",
    contract_title: contractTitle,
    contract_type: contractType,
    role: payload.role,
    score: hasInput ? 74 : 0,
    grade: hasInput ? "C" : "E",
    grade_label: hasInput ? "可作为初稿，但关键商业信息需补齐" : "信息严重不足，暂不能生成可靠合同",
    summary: `已按普通用户可读格式生成${contractTitle}草案，并覆盖${clauseText}；当前仍需补齐主体、金额和履行期限。`,
    missing_fields: isRental ? ["承租方姓名/证件号", "房屋地址和面积", "租金金额和付款日", "租期起止日"] : ["对方主体名称", "金额和付款日期", "履行期限"],
    followup_questions: isRental ? ["租金每月多少？", "租期从哪天到哪天？", "押金金额和退还条件是什么？"] : ["合同金额是多少？", "履行期限从哪天到哪天？", "是否需要押金、质保金或保证金？"],
    contract_markdown: `# ${contractTitle}\n\n甲方：${payload.role.includes("甲方") ? "[我方信息]" : "[待补充]"}\n\n乙方：[待补充]\n\n第一条 合同目的\n\n双方就${purpose}达成本合同，并确认本合同用于明确双方权利义务。\n\n第二条 合同标的\n\n${isRental ? "甲方同意将房屋出租给乙方使用，房屋地址、面积、附属设施及交付状态以双方确认清单为准。" : "具体内容、数量、质量标准和履行方式由双方确认后填写。"}\n\n第三条 价款与支付\n\n${isRental ? "租金、押金、付款周期和付款账户由双方在签署前补齐。乙方逾期付款的，甲方有权要求乙方限期补足。" : "合同价款、付款节点和发票安排均为 [待补充]。建议将付款条件与交付、验收结果绑定。"}\n\n第四条 交付与验收\n\n${isRental ? "甲方应按约交付房屋及钥匙，乙方应在交付时检查房屋和附属设施；双方可签署交接清单作为附件。" : "乙方应按约交付成果，甲方应在约定期限内完成验收。验收不合格的，乙方应在合理期限内整改。"}\n\n第五条 违约责任\n\n任何一方违反合同约定，应承担继续履行、采取补救措施或赔偿损失等责任。违约金比例、补救期限和责任上限应在正式签署前补齐。\n\n第六条 解除与终止\n\n出现严重违约、法定解除事由或双方协商一致的，守约方可解除合同。解除后，双方应结清已发生款项并返还应返还资料或物品。\n\n第七条 争议解决\n\n双方因本合同产生争议，应先友好协商；协商不成的，提交有管辖权的人民法院处理。\n\n签署栏\n\n甲方：__________\n\n乙方：__________\n\n签署日期：____年__月__日`,
    risk_notes: ["当前缺少关键商业信息，正式使用前必须补齐。", "正式签署前建议结合真实交易背景再做一次审查。"],
    signing_checklist: isRental ? ["确认双方身份信息", "补齐房屋地址和交接清单", "补齐租金、押金和退还条件", "明确维修责任和提前解约条件"] : ["确认双方主体", "补齐金额与付款节点", "补齐期限和交付标准"],
    legal_references: [{ title: "法规知识库未连接", verification_status: "not_connected" }],
    disclaimer: "AI 辅助起草，不构成律师法律意见；重要合同请交由专业律师复核。",
  };
}

<template>
  <view class="app-shell">
    <view v-if="screen === 'home'" class="screen home-screen">
      <scroll-view scroll-y class="home-scroll">
        <view class="home-tech-layer">
          <view class="tech-grid"></view>
          <view class="tech-circuit left">
            <view></view>
            <view></view>
            <view></view>
          </view>
          <view class="tech-circuit right">
            <view></view>
            <view></view>
            <view></view>
          </view>
        </view>

        <view class="brand-block">
          <view class="logo-mark">
            <view></view>
            <view></view>
            <view></view>
          </view>
          <text class="brand-name">契合</text>
          <text class="brand-subtitle">AI合同审查与生成助手</text>
        </view>

        <view v-if="messages.length" class="chat-thread">
          <view
            v-for="message in messages"
            :key="message.id"
            class="message-row"
            :class="message.role"
          >
            <view class="message-bubble" :class="message.kind">
              <view v-if="message.kind === 'thinking'" class="thinking-content">
                <view class="thinking-dots">
                  <view></view>
                  <view></view>
                  <view></view>
                </view>
                <text>{{ message.text }}</text>
              </view>
              <text v-else>{{ message.text }}</text>
              <view v-if="message.kind === 'clarify'" class="clarify-actions">
                <button @tap="goReview()">合同审查</button>
                <button @tap="goGenerate()">合同生成</button>
              </view>
            </view>
          </view>
        </view>

        <view v-if="pendingTask" class="task-confirm-card">
          <view class="confirm-top">
            <text class="confirm-kicker">已识别任务</text>
            <text class="confirm-pill">{{ pendingTask.mode === 'review' ? '合同审查' : '合同生成' }}</text>
          </view>
          <text class="confirm-title">{{ pendingTask.title }}</text>
          <text class="confirm-desc">{{ pendingTask.desc }}</text>
          <view class="confirm-meta">
            <view>
              <text>合同类型</text>
              <text>{{ pendingTask.contractType }}</text>
            </view>
            <view>
              <text>默认身份</text>
              <text>{{ pendingTask.role }}</text>
            </view>
          </view>
          <view class="confirm-actions">
            <button class="primary" :disabled="submitting" @tap="confirmPendingTask">
              {{ pendingTask.mode === 'review' ? '开始审查' : '开始生成' }}
            </button>
            <button @tap="editPendingTask">编辑信息</button>
          </view>
        </view>

        <view class="composer-card">
          <view class="input-card-head">
            <text>自由输入</text>
            <button v-if="hasHomeContent" class="clear-surface-action" @tap="clearHomeDraft">
              <uni-icons type="closeempty" size="15" color="#64748b" />
              <text>清空</text>
            </button>
          </view>
          <textarea
            v-model="draft"
            class="main-input"
            maxlength="20000"
            auto-height="false"
            placeholder="输入合同内容，或描述你想生成的合同"
            placeholder-class="placeholder"
          />
          <view class="composer-bottom">
            <view class="composer-actions">
              <button class="round-btn" @tap="pickFile">
                <uni-icons type="plusempty" size="22" color="#111827" />
              </button>
              <button class="send-btn" :disabled="submitting" @tap="sendHomeMessage">
                <uni-icons type="paperplane-filled" size="22" color="#ffffff" />
              </button>
            </view>
          </view>
        </view>

        <view class="primary-actions">
          <button @tap="goReview()">
            <uni-icons type="search" size="22" color="#2563eb" />
            <text>合同审查</text>
          </button>
          <button @tap="goGenerate()">
            <uni-icons type="compose" size="22" color="#2563eb" />
            <text>合同生成</text>
          </button>
        </view>

        <view class="recent-section">
          <view class="section-title-row">
            <text>最近记录</text>
            <button v-if="history.length > 3" class="section-toggle" @tap="showAllRecent = !showAllRecent">
              {{ showAllRecent ? '收起' : '展开' }}
            </button>
          </view>
          <view class="recent-list">
            <button
              v-for="record in visibleHistory"
              :key="record.id"
              class="recent-row"
              @tap="openRecord(record)"
            >
              <view class="record-type-dot" :class="record.type">
                <uni-icons :type="record.type === 'review' ? 'search' : 'compose'" size="17" color="#ffffff" />
              </view>
              <view class="record-main">
                <text class="record-title">{{ record.title }}</text>
                <text class="record-meta">{{ record.type === 'review' ? '审查完成' : '已生成' }} · {{ record.time }}</text>
              </view>
              <uni-icons type="right" size="16" color="#c4c9d4" />
            </button>
          </view>
        </view>
      </scroll-view>
    </view>

    <view v-if="screen === 'features'" class="screen tab-screen">
      <scroll-view scroll-y class="tab-scroll">
        <view class="feature-mode-switch">
          <button :class="{ active: featureMode === 'review' }" @tap="featureMode = 'review'">
            <uni-icons type="search" size="24" :color="featureMode === 'review' ? '#ffffff' : '#2563eb'" />
            <text>合同审查</text>
          </button>
          <button :class="{ active: featureMode === 'generate' }" @tap="featureMode = 'generate'">
            <uni-icons type="compose" size="24" :color="featureMode === 'generate' ? '#ffffff' : '#2563eb'" />
            <text>合同生成</text>
          </button>
        </view>

        <view v-if="featureMode === 'review'" class="feature-workbench">
          <view class="workbench-head">
            <view>
              <text class="section-kicker">合同审查</text>
              <text class="section-heading">识别风险并给出修改建议</text>
            </view>
            <view class="workbench-status pro">
              <text>专业AI审查</text>
              <text>链路分析总结</text>
            </view>
          </view>

          <view class="task-card feature-input-card">
            <view class="input-card-head">
              <text>合同内容</text>
              <button v-if="hasReviewContent" class="clear-surface-action" @tap="clearReviewDraft">
                <uni-icons type="closeempty" size="15" color="#64748b" />
                <text>清空</text>
              </button>
            </view>
            <view class="segmented">
              <button :class="{ active: reviewInputMode === 'text' }" @tap="reviewInputMode = 'text'">粘贴文本</button>
              <button :class="{ active: reviewInputMode === 'file' }" @tap="reviewInputMode = 'file'">上传文件</button>
            </view>

            <textarea
              v-if="reviewInputMode === 'text'"
              v-model="contractText"
              class="feature-textarea"
              maxlength="20000"
              placeholder="粘贴合同全文或关键条款，契合会检查付款、违约、解除、主体等风险。"
              placeholder-class="placeholder"
            />

            <button v-else class="feature-upload" @tap="pickFile(true)">
              <uni-icons type="upload" size="30" color="#2563eb" />
              <text>{{ selectedFile || '上传合同文件' }}</text>
              <text>支持 PDF / Word / TXT</text>
            </button>

            <view v-if="selectedFile && reviewInputMode === 'file'" class="upload-status" :class="uploadState">
              <view>
                <text>{{ uploadStatusTitle }}</text>
                <text>{{ uploadStatusDesc }}</text>
              </view>
              <button @tap.stop="removeSelectedFile">移除</button>
            </view>
          </view>

          <view class="review-context-panel">
            <button class="contract-type-select" :class="{ open: contractTypeDrawerOpen && contractTypeDrawerTarget === 'review' }" @tap="openContractTypeDrawer('review')">
              <view>
                <text class="contract-type-select-label">合同类型</text>
                <text class="contract-type-select-value">{{ displayContractTypeFor('review') }}</text>
              </view>
              <uni-icons type="bottom" size="18" color="#8a92a3" />
            </button>
            <input
              v-if="isCustomContractTypeFor('review')"
              v-model="reviewForm.customContractType"
              class="custom-contract-input"
              placeholder="输入你的合同类型，例如：主播合作协议"
              placeholder-class="placeholder"
            />
            <view class="role-strip">
              <button
                v-for="role in roles"
                :key="role"
                :class="{ active: reviewForm.role === role }"
                @tap="reviewForm.role = role"
              >
                {{ role }}
              </button>
            </view>
          </view>

          <view class="focus-selector feature-focus-section">
            <view class="focus-label">
              <text>审查重点</text>
              <text>可多选</text>
            </view>
            <view class="focus-chips">
              <button
                v-for="area in reviewFocusOptions"
                :key="area"
                class="focus-chip"
                :class="{ active: reviewForm.focusAreas.includes(area) }"
                @tap="toggleReviewFocus(area)"
              >
                {{ area }}
              </button>
            </view>
          </view>

          <view class="readiness-card">
            <view class="readiness-head">
              <view>
                <text>输入完整度</text>
                <text>{{ reviewReadiness.label }}</text>
              </view>
              <text>{{ reviewReadiness.score }}%</text>
            </view>
            <view class="readiness-bar">
              <view :style="{ width: reviewReadiness.score + '%' }"></view>
            </view>
            <view class="readiness-chips">
              <view v-for="item in reviewReadiness.items" :key="item.label" :class="{ ready: item.ready }">
                <text>{{ item.ready ? '✓' : '·' }}</text>
                <text>{{ item.label }}</text>
              </view>
            </view>
            <text class="readiness-tip">{{ reviewReadiness.tip }}</text>
          </view>

          <view v-if="formNotice && featureMode === 'review'" class="form-notice" :class="formNotice.type">
            <text>{{ formNotice.text }}</text>
            <view v-if="formNotice.type === 'error'" class="form-notice-actions">
              <button @tap="copyFormNotice">复制</button>
              <button @tap="clearFormNotice">关闭</button>
            </view>
          </view>

          <button class="feature-primary-action" :disabled="submitting" @tap="startReview">
            <view class="button-content">
              <view v-if="submitting" class="button-spinner"></view>
              <text>{{ submitting ? '正在审查...' : '开始合同审查' }}</text>
            </view>
          </button>

          <view class="feature-promo-grid feature-promo-after" :class="featureMode">
            <view v-for="item in featurePromos" :key="item.title">
              <text>{{ item.title }}</text>
              <text>{{ item.desc }}</text>
            </view>
          </view>
        </view>

        <view v-else class="feature-workbench generate">
          <view class="workbench-head">
            <view>
              <text class="section-kicker">合同生成</text>
              <text class="section-heading">把需求整理成合同草案</text>
            </view>
            <view class="workbench-status dark pro">
              <text>合同框架</text>
              <text>智能生成</text>
            </view>
          </view>

          <view class="task-card feature-input-card generate-step-card">
            <view class="simple-step-title input-card-head">
              <text>描述生成需求</text>
              <button v-if="hasGenerateContent" class="clear-surface-action" @tap="clearGenerateDraft">
                <uni-icons type="closeempty" size="15" color="#64748b" />
                <text>清空</text>
              </button>
            </view>
            <textarea
              v-model="generatePrompt"
              class="feature-textarea generate"
              maxlength="20000"
              placeholder="描述合同需求，例如：生成一份租房合同，我是房东，租期一年，押一付三，想保护出租方权益。"
              placeholder-class="placeholder"
            />
          </view>

          <view class="task-card feature-input-card generate-step-card">
            <view class="step-title-row">
              <text>2</text>
              <view>
                <text>合同框架</text>
                <text>先选类型和身份，再补充金额、期限、特殊约定</text>
              </view>
            </view>

            <view class="contract-type-picker">
              <button class="contract-type-select" :class="{ open: contractTypeDrawerOpen && contractTypeDrawerTarget === 'generate' }" @tap="openContractTypeDrawer('generate')">
                <view>
                  <text class="contract-type-select-label">合同类型</text>
                  <text class="contract-type-select-value">{{ displayContractTypeFor('generate') }}</text>
                </view>
                <uni-icons type="bottom" size="18" color="#8a92a3" />
              </button>
              <input
                v-if="isCustomContractTypeFor('generate')"
                v-model="generateForm.customContractType"
                class="custom-contract-input"
                placeholder="输入你的合同类型，例如：主播合作协议"
                placeholder-class="placeholder"
              />
            </view>

            <view class="role-strip">
              <button
                v-for="role in roles"
                :key="role"
                :class="{ active: generateForm.role === role }"
                @tap="generateForm.role = role"
              >
                {{ role }}
              </button>
            </view>

            <view class="focus-selector">
              <view class="focus-label">
                <text>生成条款</text>
                <text>可多选</text>
              </view>
              <view class="focus-chips">
                <button
                  v-for="area in generateClauseOptions"
                  :key="area"
                  class="focus-chip"
                  :class="{ active: generateForm.focusAreas.includes(area) }"
                  @tap="toggleGenerateClause(area)"
                >
                  {{ area }}
                </button>
              </view>
            </view>

            <view class="feature-field-grid">
              <input v-model="generateForm.requirements" placeholder="金额、期限、交付标准、特殊约定" placeholder-class="placeholder" />
            </view>
          </view>

          <view class="readiness-card">
            <view class="readiness-head">
              <view>
                <text>输入完整度</text>
                <text>{{ generateReadiness.label }}</text>
              </view>
              <text>{{ generateReadiness.score }}%</text>
            </view>
            <view class="readiness-bar">
              <view :style="{ width: generateReadiness.score + '%' }"></view>
            </view>
            <view class="readiness-chips">
              <view v-for="item in generateReadiness.items" :key="item.label" :class="{ ready: item.ready }">
                <text>{{ item.ready ? '✓' : '·' }}</text>
                <text>{{ item.label }}</text>
              </view>
            </view>
            <text class="readiness-tip">{{ generateReadiness.tip }}</text>
          </view>

          <view v-if="formNotice && featureMode === 'generate'" class="form-notice" :class="formNotice.type">
            <text>{{ formNotice.text }}</text>
            <view v-if="formNotice.type === 'error'" class="form-notice-actions">
              <button @tap="copyFormNotice">复制</button>
              <button @tap="clearFormNotice">关闭</button>
            </view>
          </view>

          <button class="feature-primary-action" :disabled="submitting" @tap="startGenerate">
            <view class="button-content">
              <view v-if="submitting" class="button-spinner"></view>
              <text>{{ submitting ? '正在生成...' : '开始合同生成' }}</text>
            </view>
          </button>

          <view class="feature-promo-grid feature-promo-after" :class="featureMode">
            <view v-for="item in featurePromos" :key="item.title">
              <text>{{ item.title }}</text>
              <text>{{ item.desc }}</text>
            </view>
          </view>
        </view>
      </scroll-view>
    </view>

    <view v-if="screen === 'history'" class="screen tab-screen">
      <scroll-view scroll-y class="tab-scroll">
        <view class="section-hero compact">
          <text class="section-kicker">历史</text>
          <text class="section-heading">本机历史记录</text>
        </view>

        <view class="search-box page-search">
          <uni-icons type="search" size="18" color="#9ca3af" />
          <input v-model="historyQuery" placeholder="搜索合同名称或记录" placeholder-class="placeholder" />
        </view>

        <view class="history-filter">
          <button
            v-for="item in historyFilters"
            :key="item.key"
            :class="{ active: historyFilter === item.key }"
            @tap="historyFilter = item.key"
          >
            <text>{{ item.label }}</text>
            <text>{{ historyFilterCount(item.key) }}</text>
          </button>
        </view>

        <view v-if="filteredHistory.length" class="history-page-list">
          <view
            v-for="record in filteredHistory"
            :key="record.id"
            class="history-card"
          >
            <button class="history-card-main" @tap="openRecord(record)">
              <view class="record-type-dot" :class="record.type">
                <uni-icons :type="record.type === 'review' ? 'search' : 'compose'" size="17" color="#ffffff" />
              </view>
              <view class="record-main">
                <text class="record-title">{{ record.title }}</text>
                <text class="record-meta">{{ record.type === 'review' ? '合同审查' : '合同生成' }} · {{ record.time }}</text>
                <text v-if="record.context" class="record-context">{{ recordContextLine(record) }}</text>
                <text class="record-preview">{{ record.contractText || record.result.summary || record.result.contract_markdown || '点击查看详情' }}</text>
              </view>
              <uni-icons type="right" size="18" color="#c4c9d4" />
            </button>
            <button class="history-delete" @tap.stop="deleteRecord(record.id)">
              <uni-icons type="trash" size="18" color="#e11d48" />
            </button>
          </view>
        </view>

        <view v-else class="empty-state">
          <uni-icons type="calendar" size="40" color="#c4c9d4" />
          <text>还没有历史记录</text>
          <text>完成一次审查或生成后，会自动保存在这里。</text>
        </view>
      </scroll-view>
    </view>

    <view v-if="screen === 'settings'" class="screen tab-screen">
      <scroll-view scroll-y class="tab-scroll">
        <view class="profile-card">
          <view class="avatar">契</view>
          <view class="profile-main">
            <text>个人中心</text>
            <text>本机使用 · 历史仅保存在本机</text>
          </view>
          <view class="profile-status-pill">本地使用</view>
        </view>

        <view class="settings-panel">
          <view class="settings-panel-head">
            <text>默认处理偏好</text>
            <text>这些设置会带入审查和生成请求</text>
          </view>

          <view class="setting-field">
            <view class="setting-copy">
              <text>默认身份</text>
              <text>用于生成立场和审查关注点</text>
            </view>
            <view class="settings-choice-row">
              <button
                v-for="role in roles"
                :key="role"
                :class="{ active: defaultRole === role }"
                @tap="setDefaultRole(role)"
              >
                {{ role }}
              </button>
            </view>
          </view>

          <view class="setting-field">
            <view class="setting-copy">
              <text>输出详略</text>
              <text>控制摘要、建议和合同正文的表达密度</text>
            </view>
            <view class="settings-choice-row three">
              <button
                v-for="style in outputStyleOptions"
                :key="style"
                :class="{ active: outputStyle === style }"
                @tap="setOutputStyle(style)"
              >
                {{ style }}
              </button>
            </view>
          </view>

          <view class="setting-toggle-row">
            <view class="setting-copy">
              <text>本地隐私模式</text>
              <text>历史记录仅保存在本机，后端接入前默认开启</text>
            </view>
            <switch :checked="privacyMode" color="#2563eb" @change="togglePrivacyMode" />
          </view>
        </view>

        <view class="settings-panel service-panel">
          <view class="settings-panel-head">
            <text>服务状态</text>
            <text>用于确认当前处理请求的连接状态</text>
          </view>
          <view class="service-status-row">
            <view class="service-pulse" :class="{ live: serviceEnabled }"></view>
            <view>
              <text>{{ serviceModeTitle }}</text>
              <text>{{ serviceModeDesc }}</text>
            </view>
          </view>
          <view class="service-metric-grid">
            <view v-for="item in serviceMetrics" :key="item.label">
              <text>{{ item.value }}</text>
              <text>{{ item.label }}</text>
            </view>
          </view>
        </view>

        <view class="settings-group">
          <button class="settings-row" @tap="clearHistory">
            <view class="settings-icon danger">
              <uni-icons type="trash" size="22" color="#e11d48" />
            </view>
            <view class="settings-copy">
              <text>清空历史记录</text>
              <text>只会清除本机保存的记录</text>
            </view>
            <uni-icons type="right" size="16" color="#c4c9d4" />
          </button>
        </view>
      </scroll-view>
    </view>

    <view v-if="screen === 'review'" class="screen task-screen">
      <view class="page-top">
        <button class="icon-btn" @tap="backToRoot">
          <uni-icons type="left" size="24" color="#111827" />
        </button>
        <text>合同审查</text>
        <view class="top-spacer"></view>
      </view>

      <scroll-view scroll-y class="task-scroll">
        <view class="task-card">
          <view class="input-card-head">
            <text>合同内容</text>
            <button v-if="hasReviewContent" class="clear-surface-action" @tap="clearReviewDraft">
              <uni-icons type="closeempty" size="15" color="#64748b" />
              <text>清空</text>
            </button>
          </view>
          <view class="segmented">
            <button :class="{ active: reviewInputMode === 'text' }" @tap="reviewInputMode = 'text'">粘贴文本</button>
            <button :class="{ active: reviewInputMode === 'file' }" @tap="reviewInputMode = 'file'">上传文件</button>
          </view>

          <textarea
            v-if="reviewInputMode === 'text'"
            v-model="contractText"
            class="task-textarea"
            maxlength="20000"
            placeholder="粘贴合同全文或关键条款，契合会提取风险、主体和修改建议。"
            placeholder-class="placeholder"
          />

          <button v-else class="upload-box" @tap="pickFile">
            <uni-icons type="upload" size="34" color="#2563eb" />
            <text>{{ selectedFile || '上传合同文件' }}</text>
            <text>支持 PDF / Word / TXT</text>
          </button>

          <view v-if="selectedFile && reviewInputMode === 'file'" class="upload-status" :class="uploadState">
            <view>
              <text>{{ uploadStatusTitle }}</text>
              <text>{{ uploadStatusDesc }}</text>
            </view>
            <button @tap.stop="removeSelectedFile">移除</button>
          </view>
        </view>

        <view class="collapse-card">
          <button class="collapse-head" @tap="showReviewMore = !showReviewMore">
            <text>更多信息（可选）</text>
            <uni-icons :type="showReviewMore ? 'arrow-up' : 'arrow-down'" size="18" color="#9ca3af" />
          </button>
          <view v-if="showReviewMore" class="optional-panel">
            <view class="contract-type-picker compact">
              <button class="contract-type-select" :class="{ open: contractTypeDrawerOpen && contractTypeDrawerTarget === 'review' }" @tap="openContractTypeDrawer('review')">
                <view>
                  <text class="contract-type-select-label">合同类型</text>
                  <text class="contract-type-select-value">{{ displayContractTypeFor('review') }}</text>
                </view>
                <uni-icons type="bottom" size="18" color="#8a92a3" />
              </button>
              <input
                v-if="isCustomContractTypeFor('review')"
                v-model="reviewForm.customContractType"
                class="custom-contract-input"
                placeholder="输入你的合同类型，例如：房屋租赁合同"
                placeholder-class="placeholder"
              />
            </view>
            <view class="choice-row">
              <button
                v-for="role in roles"
                :key="role"
                :class="{ active: reviewForm.role === role }"
                @tap="reviewForm.role = role"
              >
                {{ role }}
              </button>
            </view>
            <view class="focus-selector compact">
              <view class="focus-label">
                <text>审查重点</text>
                <text>可多选</text>
              </view>
              <view class="focus-chips">
                <button
                  v-for="area in reviewFocusOptions"
                  :key="area"
                  class="focus-chip"
                  :class="{ active: reviewForm.focusAreas.includes(area) }"
                  @tap="toggleReviewFocus(area)"
                >
                  {{ area }}
                </button>
              </view>
            </view>
            <input v-model="reviewForm.requirements" placeholder="补充说明，例如对方主体、签约背景" placeholder-class="placeholder" />
          </view>
        </view>

        <view class="readiness-card task-readiness">
          <view class="readiness-head">
            <view>
              <text>输入完整度</text>
              <text>{{ reviewReadiness.label }}</text>
            </view>
            <text>{{ reviewReadiness.score }}%</text>
          </view>
          <view class="readiness-bar">
            <view :style="{ width: reviewReadiness.score + '%' }"></view>
          </view>
          <view class="readiness-chips">
            <view v-for="item in reviewReadiness.items" :key="item.label" :class="{ ready: item.ready }">
              <text>{{ item.ready ? '✓' : '·' }}</text>
              <text>{{ item.label }}</text>
            </view>
          </view>
          <text class="readiness-tip">{{ reviewReadiness.tip }}</text>
        </view>

        <view v-if="formNotice" class="form-notice task-notice" :class="formNotice.type">
          <text>{{ formNotice.text }}</text>
          <view v-if="formNotice.type === 'error'" class="form-notice-actions">
            <button @tap="copyFormNotice">复制</button>
            <button @tap="clearFormNotice">关闭</button>
          </view>
        </view>
      </scroll-view>

      <view class="fixed-action">
        <button :disabled="submitting" @tap="startReview">
          <view class="button-content">
            <view v-if="submitting" class="button-spinner"></view>
            <text>{{ submitting ? '正在审查...' : '开始审查' }}</text>
          </view>
        </button>
      </view>
    </view>

    <view v-if="screen === 'generate'" class="screen task-screen">
      <view class="page-top">
        <button class="icon-btn" @tap="backToRoot">
          <uni-icons type="left" size="24" color="#111827" />
        </button>
        <text>合同生成</text>
        <view class="top-spacer"></view>
      </view>

      <scroll-view scroll-y class="task-scroll">
        <view class="task-card">
          <view class="input-card-head">
            <text>生成需求</text>
            <button v-if="hasGenerateContent" class="clear-surface-action" @tap="clearGenerateDraft">
              <uni-icons type="closeempty" size="15" color="#64748b" />
              <text>清空</text>
            </button>
          </view>
          <textarea
            v-model="generatePrompt"
            class="task-textarea generate-area"
            maxlength="20000"
            placeholder="描述你想生成的合同，例如：生成一份租房合同，我是房东，想保护出租方权益。"
            placeholder-class="placeholder"
          />
        </view>

        <view class="collapse-card">
          <button class="collapse-head" @tap="showGenerateMore = !showGenerateMore">
            <text>补充要求（可选）</text>
            <uni-icons :type="showGenerateMore ? 'arrow-up' : 'arrow-down'" size="18" color="#9ca3af" />
          </button>
          <view v-if="showGenerateMore" class="optional-panel">
            <view class="contract-type-picker compact">
              <button class="contract-type-select" :class="{ open: contractTypeDrawerOpen && contractTypeDrawerTarget === 'generate' }" @tap="openContractTypeDrawer('generate')">
                <view>
                  <text class="contract-type-select-label">合同类型</text>
                  <text class="contract-type-select-value">{{ displayContractTypeFor('generate') }}</text>
                </view>
                <uni-icons type="bottom" size="18" color="#8a92a3" />
              </button>
              <input
                v-if="isCustomContractTypeFor('generate')"
                v-model="generateForm.customContractType"
                class="custom-contract-input"
                placeholder="输入你的合同类型，例如：服务合同"
                placeholder-class="placeholder"
              />
            </view>
            <view class="choice-row">
              <button
                v-for="role in roles"
                :key="role"
                :class="{ active: generateForm.role === role }"
                @tap="generateForm.role = role"
              >
                {{ role }}
              </button>
            </view>
            <view class="focus-selector compact">
              <view class="focus-label">
                <text>生成条款</text>
                <text>可多选</text>
              </view>
              <view class="focus-chips">
                <button
                  v-for="area in generateClauseOptions"
                  :key="area"
                  class="focus-chip"
                  :class="{ active: generateForm.focusAreas.includes(area) }"
                  @tap="toggleGenerateClause(area)"
                >
                  {{ area }}
                </button>
              </view>
            </view>
            <input v-model="generateForm.requirements" placeholder="金额、期限、交付标准、特殊约定等" placeholder-class="placeholder" />
          </view>
        </view>

        <view class="readiness-card task-readiness">
          <view class="readiness-head">
            <view>
              <text>输入完整度</text>
              <text>{{ generateReadiness.label }}</text>
            </view>
            <text>{{ generateReadiness.score }}%</text>
          </view>
          <view class="readiness-bar">
            <view :style="{ width: generateReadiness.score + '%' }"></view>
          </view>
          <view class="readiness-chips">
            <view v-for="item in generateReadiness.items" :key="item.label" :class="{ ready: item.ready }">
              <text>{{ item.ready ? '✓' : '·' }}</text>
              <text>{{ item.label }}</text>
            </view>
          </view>
          <text class="readiness-tip">{{ generateReadiness.tip }}</text>
        </view>

        <view v-if="formNotice" class="form-notice task-notice" :class="formNotice.type">
          <text>{{ formNotice.text }}</text>
          <view v-if="formNotice.type === 'error'" class="form-notice-actions">
            <button @tap="copyFormNotice">复制</button>
            <button @tap="clearFormNotice">关闭</button>
          </view>
        </view>
      </scroll-view>

      <view class="fixed-action">
        <button :disabled="submitting" @tap="startGenerate">
          <view class="button-content">
            <view v-if="submitting" class="button-spinner"></view>
            <text>{{ submitting ? '正在生成...' : '生成合同' }}</text>
          </view>
        </button>
      </view>
    </view>

    <view v-if="screen === 'reviewResult'" class="screen result-screen">
      <view class="page-top">
        <button class="icon-btn" @tap="backToRoot">
          <uni-icons type="left" size="24" color="#111827" />
        </button>
        <view class="result-tabs">
          <button :class="{ active: resultTab === 'original' }" @tap="resultTab = 'original'">原文</button>
          <button :class="{ active: resultTab === 'risks' }" @tap="resultTab = 'risks'">风险</button>
          <button :class="{ active: resultTab === 'parties' }" @tap="resultTab = 'parties'">主体</button>
        </view>
        <button class="icon-btn" @tap="exportResult">
          <uni-icons type="download" size="23" color="#2563eb" />
        </button>
      </view>

      <scroll-view scroll-y class="result-scroll">
        <view v-if="resultTab === 'risks'" class="result-stack">
          <view class="summary-card">
            <text class="summary-kicker">审查摘要</text>
            <text class="summary-title">发现 {{ riskItems.length }} 个重点风险</text>
            <view class="score-strip">
              <view>
                <text>{{ currentResult?.score || '-' }}</text>
                <text>安全分</text>
              </view>
              <view>
                <text>{{ currentResult?.grade || '-' }}</text>
                <text>等级</text>
              </view>
              <view>
                <text>{{ riskLevelText }}</text>
                <text>风险</text>
              </view>
            </view>
            <text class="summary-copy">{{ currentResult?.summary }}</text>
          </view>

          <view v-if="currentTaskContext" class="context-card">
            <view v-for="item in currentContextRows" :key="item.label">
              <text>{{ item.label }}</text>
              <text>{{ item.value }}</text>
            </view>
          </view>

          <view v-for="risk in riskItems" :key="risk.title" class="risk-card">
            <view class="risk-head">
              <view class="risk-mark" :class="risk.levelClass"></view>
              <text>{{ risk.title }}</text>
            </view>
            <text class="risk-copy">{{ risk.desc }}</text>
            <button @tap="expandedRisk = expandedRisk === risk.title ? '' : risk.title">
              {{ expandedRisk === risk.title ? '收起建议' : '查看建议' }}
            </button>
            <view v-if="expandedRisk === risk.title" class="replacement-box">
              <text>建议替换条款</text>
              <text>{{ risk.replacement }}</text>
              <view class="replacement-actions">
                <button @tap="copyRiskSuggestion(risk)">复制建议</button>
                <button @tap="askAboutRisk(risk)">继续追问</button>
              </view>
            </view>
          </view>
        </view>

        <view v-if="resultTab === 'original'" class="document-card">
          <text class="document-title">合同原文</text>
          <text class="document-copy">{{ contractText || '当前是文件审查模拟，原文将在真实解析后展示。' }}</text>
        </view>

        <view v-if="resultTab === 'parties'" class="document-card">
          <text class="document-title">主体信息</text>
          <view v-for="fact in factRows" :key="fact.label" class="fact-row">
            <text>{{ fact.label }}</text>
            <text>{{ fact.value }}</text>
          </view>
          <text v-if="factRows.length === 0" class="empty-small">未识别到完整主体信息</text>
        </view>

        <view class="followup-card">
          <view class="followup-head">
            <view>
              <text>继续追问</text>
              <text>{{ followupModeDesc }}</text>
            </view>
            <button v-if="resultFollowups.length" @tap="clearResultFollowups">清空</button>
          </view>
          <view v-if="resultFollowups.length" class="followup-thread">
            <view v-for="item in resultFollowups" :key="item.id" class="followup-item">
              <text>{{ item.question }}</text>
              <text>{{ item.answer }}</text>
            </view>
          </view>
          <textarea
            v-model="resultFollowupDraft"
            class="followup-input"
            maxlength="1200"
            auto-height="false"
            placeholder="例如：这个风险为什么重要？应该怎么改更保护我？"
            placeholder-class="placeholder"
          />
          <button class="followup-send" :disabled="submitting" @tap="sendResultFollowup">发送追问</button>
        </view>
      </scroll-view>
    </view>

    <view v-if="screen === 'generateResult'" class="screen result-screen">
      <view class="page-top">
        <button class="icon-btn" @tap="backToRoot">
          <uni-icons type="left" size="24" color="#111827" />
        </button>
        <text>生成结果</text>
        <button class="icon-btn" @tap="exportResult">
          <uni-icons type="download" size="23" color="#2563eb" />
        </button>
      </view>

      <scroll-view scroll-y class="result-scroll">
        <view class="summary-card generate-summary">
          <text class="summary-kicker">生成摘要</text>
          <text class="summary-title">{{ currentResult?.grade_label || '合同草案已生成' }}</text>
          <text class="summary-copy">{{ currentResult?.summary }}</text>
        </view>

        <view v-if="currentTaskContext" class="context-card">
          <view v-for="item in currentContextRows" :key="item.label">
            <text>{{ item.label }}</text>
            <text>{{ item.value }}</text>
          </view>
        </view>

        <view class="document-card draft-card">
          <text class="document-title">{{ currentResult?.contract_title || '合同草案' }}</text>
          <text class="document-copy">{{ currentResult?.contract_markdown || '暂无合同草案。' }}</text>
        </view>

        <view class="info-card">
          <text>待补充信息</text>
          <view v-for="item in missingFields" :key="item" class="bullet-row missing-row">
            <text>{{ item }}</text>
            <button @tap="fillMissingField(item)">补充</button>
          </view>
          <view class="refine-box">
            <textarea
              v-model="refinementText"
              maxlength="2000"
              auto-height="false"
              placeholder="补充金额、期限、交付方式等信息后，可在当前草案基础上重新生成。"
              placeholder-class="placeholder"
            />
            <button :disabled="submitting" @tap="regenerateWithRefinement">
              {{ submitting ? '正在重新生成...' : '补充后重新生成' }}
            </button>
          </view>
        </view>

        <view class="info-card">
          <text>签署前清单</text>
          <view v-for="item in signingChecklist" :key="item" class="bullet-row">{{ item }}</view>
        </view>

        <view class="followup-card">
          <view class="followup-head">
            <view>
              <text>继续修改</text>
              <text>{{ followupModeDesc }}</text>
            </view>
            <button v-if="resultFollowups.length" @tap="clearResultFollowups">清空</button>
          </view>
          <view v-if="resultFollowups.length" class="followup-thread">
            <view v-for="item in resultFollowups" :key="item.id" class="followup-item">
              <text>{{ item.question }}</text>
              <text>{{ item.answer }}</text>
            </view>
          </view>
          <textarea
            v-model="resultFollowupDraft"
            class="followup-input"
            maxlength="1200"
            auto-height="false"
            placeholder="例如：帮我改得更保护甲方，或者解释待补信息要怎么填。"
            placeholder-class="placeholder"
          />
          <button class="followup-send" :disabled="submitting" @tap="sendResultFollowup">发送追问</button>
        </view>

        <text class="disclaimer">{{ currentResult?.disclaimer }}</text>
      </scroll-view>

      <view class="result-actions-fixed">
        <button @tap="copyResult">复制全文</button>
        <button @tap="exportResult">导出</button>
        <button class="primary" @tap="continueEdit">继续修改</button>
      </view>
    </view>

    <view
      v-if="contractTypeDrawerOpen"
      class="type-drawer-mask"
      :class="{ closing: contractTypeDrawerClosing }"
      @tap="closeContractTypeDrawer"
    ></view>
    <view
      v-if="contractTypeDrawerOpen"
      class="type-drawer"
      :class="{ closing: contractTypeDrawerClosing }"
      @tap.stop
    >
      <view class="type-drawer-handle"></view>
      <view class="type-drawer-head">
        <view>
          <text>选择合同类型</text>
          <text>默认不确定时，契合会根据描述自动判断。</text>
        </view>
        <button @tap="closeContractTypeDrawer">
          <uni-icons type="closeempty" size="22" color="#6b7280" />
        </button>
      </view>
      <scroll-view scroll-y class="type-drawer-list">
        <button
          v-for="(item, index) in contractTypeOptions"
          :key="item.value"
          class="type-drawer-row"
          :class="{ active: activeDrawerContractType === item.value }"
          @tap="selectContractType(item.value)"
        >
          <view class="type-drawer-row-main">
            <text>{{ item.label }}</text>
            <text>{{ item.desc }}</text>
          </view>
          <view class="type-drawer-check" :class="{ active: activeDrawerContractType === item.value }">
            <uni-icons v-if="activeDrawerContractType === item.value" type="checkmarkempty" size="17" color="#ffffff" />
          </view>
        </button>
      </scroll-view>
    </view>

    <view v-if="exportPreviewOpen" class="type-drawer-mask" @tap="closeExportPreview"></view>
    <view v-if="exportPreviewOpen" class="export-sheet" @tap.stop>
      <view class="type-drawer-handle"></view>
      <view class="export-sheet-head">
        <view>
          <text>导出预览</text>
          <text>{{ exportPreviewTitle }} 已复制，可在 iOS 中手动粘贴保存。</text>
        </view>
        <button @tap="closeExportPreview">
          <uni-icons type="closeempty" size="22" color="#6b7280" />
        </button>
      </view>
      <textarea
        v-model="exportPreviewText"
        class="export-preview-text"
        maxlength="-1"
        auto-height="false"
        disabled
      />
      <view class="export-sheet-actions">
        <button @tap="copyExportPreview">复制 Markdown</button>
        <button class="primary" @tap="closeExportPreview">完成</button>
      </view>
    </view>

    <view v-if="processingMode" class="processing-mask">
      <view class="processing-card">
        <view class="processing-orbit">
          <view></view>
          <view></view>
        </view>
        <text class="processing-title">{{ processingMode === 'review' ? '正在审查合同' : '正在生成合同' }}</text>
        <text class="processing-desc">{{ processingCurrentStep.desc }}</text>
        <view class="processing-progress">
          <view :style="{ width: processingProgress + '%' }"></view>
        </view>
        <text class="processing-meta">{{ processingCurrentStep.title }} · {{ processingProgress }}%</text>
        <view class="processing-steps">
          <view
            v-for="(step, index) in processingSteps"
            :key="step.title"
            :class="{ active: index === processingStepIndex, done: index < processingStepIndex }"
          >
            <view>{{ index + 1 }}</view>
            <text>{{ step.title }}</text>
          </view>
        </view>
      </view>
    </view>

    <view v-if="isRootScreen" class="bottom-tabs">
      <button
        v-for="tab in rootTabs"
        :key="tab.key"
        @tap="switchRootTab(tab.key)"
      >
        <view class="tab-item" :class="{ active: screen === tab.key }">
          <uni-icons :type="tab.icon" size="23" :color="screen === tab.key ? '#2563eb' : '#8a92a3'" />
          <text>{{ tab.label }}</text>
        </view>
      </button>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref } from "vue";
import {
  getServiceModeLabel,
  isDifyEnabled,
  runContractAnalysis,
  type ContractResult,
  type DifyMode,
  type LocalUploadFile,
} from "../../services/dify";

type RootScreen = "home" | "features" | "history" | "settings";
type Screen = RootScreen | "review" | "generate" | "reviewResult" | "generateResult";
type Mode = "auto" | "review" | "generate";
type TaskMode = Exclude<Mode, "auto">;
type HistoryType = "review" | "generate";
type HistoryFilter = "all" | HistoryType;
type UploadState = "idle" | "selected" | "uploading" | "ready" | "error";
type NoticeType = "info" | "success" | "error";
type OutputStyle = "简洁" | "标准" | "详细";

interface ReadinessItem {
  label: string;
  ready: boolean;
}

interface ReadinessState {
  score: number;
  label: string;
  tip: string;
  items: ReadinessItem[];
}

interface ProcessingStep {
  title: string;
  desc: string;
}

interface ChatMessage {
  id: string;
  role: "user" | "assistant";
  text: string;
  kind?: "normal" | "clarify" | "thinking";
}

interface HistoryRecord {
  id: string;
  type: HistoryType;
  title: string;
  time: string;
  result: ContractResult;
  contractText?: string;
  context?: TaskContextSnapshot;
}

interface ResultFollowup {
  id: string;
  question: string;
  answer: string;
}

interface RiskView {
  title: string;
  desc: string;
  replacement: string;
  levelClass: "high" | "medium" | "low";
}

interface PendingTask {
  mode: TaskMode;
  title: string;
  desc: string;
  text: string;
  contractType: string;
  role: string;
}

interface FormNotice {
  type: NoticeType;
  text: string;
}

interface ContractTypeOption {
  label: string;
  value: string;
  desc: string;
}

interface TaskFormState {
  contractType: string;
  customContractType: string;
  role: string;
  requirements: string;
  focusAreas: string[];
}

interface TaskContextSnapshot {
  contractType: string;
  role: string;
  focusAreas: string[];
  requirements: string;
  outputStyle: OutputStyle;
  serviceMode: string;
}

interface AppSettings {
  defaultRole: string;
  outputStyle: OutputStyle;
  privacyMode: boolean;
}

const screen = ref<Screen>("home");
const lastRootScreen = ref<RootScreen>("home");
const activeMode = ref<Mode>("auto");
const featureMode = ref<Exclude<Mode, "auto">>("review");
const draft = ref("");
const messages = ref<ChatMessage[]>([]);
const pendingTask = ref<PendingTask | null>(null);
const history = ref<HistoryRecord[]>([]);
const historyOpen = ref(false);
const historyQuery = ref("");
const historyFilter = ref<HistoryFilter>("all");
const showAllRecent = ref(false);
const submitting = ref(false);
const reviewInputMode = ref<"text" | "file">("text");
const contractText = ref("");
const generatePrompt = ref("");
const selectedFile = ref("");
const selectedUploadFile = ref<LocalUploadFile | null>(null);
const uploadState = ref<UploadState>("idle");
const contractTypeDrawerOpen = ref(false);
const contractTypeDrawerClosing = ref(false);
const contractTypeDrawerTarget = ref<TaskMode>("generate");
const DEFAULT_REVIEW_FOCUS = ["付款风险", "违约责任", "争议解决"];
const DEFAULT_GENERATE_CLAUSES = ["双方信息", "价款报酬", "履行安排", "违约责任"];
const reviewForm = reactive<TaskFormState>({
  contractType: "不确定",
  customContractType: "",
  role: "甲方",
  requirements: "",
  focusAreas: [...DEFAULT_REVIEW_FOCUS],
});
const generateForm = reactive<TaskFormState>({
  contractType: "不确定",
  customContractType: "",
  role: "甲方",
  requirements: "",
  focusAreas: [...DEFAULT_GENERATE_CLAUSES],
});
const formNotice = ref<FormNotice | null>(null);
const showReviewMore = ref(false);
const showGenerateMore = ref(false);
const currentResult = ref<ContractResult | null>(null);
const currentConversationId = ref("");
const resultTab = ref<"original" | "risks" | "parties">("risks");
const expandedRisk = ref("");
const refinementText = ref("");
const resultFollowupDraft = ref("");
const resultFollowups = ref<ResultFollowup[]>([]);
const exportPreviewOpen = ref(false);
const exportPreviewText = ref("");
const exportPreviewTitle = ref("");
const processingMode = ref<Exclude<Mode, "auto"> | null>(null);
const processingStepIndex = ref(0);
const currentTaskContext = ref<TaskContextSnapshot | null>(null);
const defaultRole = ref("甲方");
const outputStyle = ref<OutputStyle>("标准");
const privacyMode = ref(true);
let processingTimer: ReturnType<typeof setInterval> | null = null;
let contractTypeDrawerCloseTimer: ReturnType<typeof setTimeout> | null = null;

const roles = ["甲方", "乙方", "中立", "未知"];
const CUSTOM_CONTRACT_TYPE = "自定义";
const MIN_PROCESSING_MS = 900;
const SETTINGS_KEY = "qihe-settings";
const outputStyleOptions: OutputStyle[] = ["简洁", "标准", "详细"];
const rootTabs: Array<{ key: RootScreen; label: string; icon: string }> = [
  { key: "home", label: "主页", icon: "home" },
  { key: "features", label: "功能", icon: "list" },
  { key: "history", label: "历史", icon: "calendar" },
  { key: "settings", label: "设置", icon: "gear" },
];
const historyFilters: Array<{ key: HistoryFilter; label: string }> = [
  { key: "all", label: "全部" },
  { key: "review", label: "审查" },
  { key: "generate", label: "生成" },
];
const reviewProcessingSteps: ProcessingStep[] = [
  { title: "识别合同", desc: "正在判断合同类型、角色和文本结构。" },
  { title: "抽取条款", desc: "正在提取主体、付款、违约、解除和争议解决信息。" },
  { title: "评估风险", desc: "正在按风险等级整理问题和影响。" },
  { title: "生成建议", desc: "正在组织摘要、修改条款和签署前提示。" },
];
const generateProcessingSteps: ProcessingStep[] = [
  { title: "理解需求", desc: "正在识别合同类型、你的身份和关键约定。" },
  { title: "搭建框架", desc: "正在生成合同结构和基础条款。" },
  { title: "补全条款", desc: "正在按立场补充付款、交付、违约和解除条款。" },
  { title: "整理草案", desc: "正在输出合同正文、待补信息和签署清单。" },
];
const contractTypeOptions: ContractTypeOption[] = [
  { label: "不确定", value: "不确定", desc: "交给AI判断" },
  { label: "买卖采购", value: "买卖/采购合同", desc: "商品交易" },
  { label: "租赁房屋", value: "房屋租赁合同", desc: "租房设备" },
  { label: "服务委托", value: "服务/委托合同", desc: "外包咨询" },
  { label: "技术软件", value: "技术/软件合同", desc: "开发许可" },
  { label: "劳动用工", value: "劳动/用工合同", desc: "雇佣劳务" },
  { label: "工程装修", value: "工程/装修合同", desc: "施工承揽" },
  { label: "借款担保", value: "借款/担保合同", desc: "借贷保证" },
  { label: "合伙合作", value: "合伙/合作合同", desc: "共同经营" },
  { label: "自定义", value: CUSTOM_CONTRACT_TYPE, desc: "自己填写" },
];
const reviewFocusOptions = ["付款风险", "交付验收", "违约责任", "解除终止", "签约主体", "争议解决"];
const generateClauseOptions = ["双方信息", "价款报酬", "履行安排", "交付验收", "违约责任", "争议解决"];
const reviewPromos = [
  { title: "专业AI审查", desc: "链路分析总结" },
  { title: "风险定位", desc: "付款违约解除" },
  { title: "主体核验", desc: "识别甲乙方信息" },
  { title: "修改建议", desc: "给出可替换条款" },
];
const generatePromos = [
  { title: "结构完整", desc: "自动组织条款" },
  { title: "立场保护", desc: "按身份调整表达" },
  { title: "待补信息", desc: "提醒签署前补齐" },
  { title: "继续修改", desc: "生成后可追改" },
];
const isRootScreen = computed(() => {
  return ["home", "features", "history", "settings"].includes(screen.value);
});

const featurePromos = computed(() => {
  return featureMode.value === "review" ? reviewPromos : generatePromos;
});

const activeDrawerContractType = computed(() => {
  return taskForm(contractTypeDrawerTarget.value).contractType;
});

const reviewReadiness = computed<ReadinessState>(() => {
  const form = taskForm("review");
  const hasContent = reviewInputMode.value === "file" ? Boolean(selectedFile.value) : contractText.value.trim().length >= 20;
  const hasType = displayContractTypeFor("review") !== "不确定";
  const hasRole = Boolean(form.role);
  const hasFocus = form.focusAreas.length > 0 || Boolean(form.requirements.trim());
  const items = [
    { label: reviewInputMode.value === "file" ? "合同文件" : "合同文本", ready: hasContent },
    { label: "合同类型", ready: hasType },
    { label: "你的身份", ready: hasRole },
    { label: "关注点", ready: hasFocus },
  ];
  return buildReadinessState(items, hasContent ? "信息足够开始审查，可补充关注点让建议更聚焦。" : "先粘贴合同正文，或上传 PDF / Word / TXT。");
});

const generateReadiness = computed<ReadinessState>(() => {
  const form = taskForm("generate");
  const hasPrompt = generatePrompt.value.trim().length >= 12;
  const hasType = displayContractTypeFor("generate") !== "不确定";
  const hasRole = Boolean(form.role);
  const hasTerms = form.focusAreas.length > 0 || Boolean(form.requirements.trim());
  const items = [
    { label: "生成需求", ready: hasPrompt },
    { label: "合同类型", ready: hasType },
    { label: "你的身份", ready: hasRole },
    { label: "条款约定", ready: hasTerms },
  ];
  return buildReadinessState(items, hasPrompt ? "可以生成初稿；补齐金额、期限、特殊约定会减少待补字段。" : "先用一句话说明要生成什么合同、你是哪一方。");
});

const processingSteps = computed(() => {
  return processingMode.value === "review" ? reviewProcessingSteps : generateProcessingSteps;
});

const processingCurrentStep = computed(() => {
  return processingSteps.value[Math.min(processingStepIndex.value, processingSteps.value.length - 1)] || processingSteps.value[0];
});

const processingProgress = computed(() => {
  const total = Math.max(1, processingSteps.value.length);
  return Math.round(((processingStepIndex.value + 1) / total) * 100);
});

const serviceEnabled = isDifyEnabled();
const serviceModeTitle = serviceEnabled ? "在线服务" : "演示服务";
const serviceModeDesc = serviceEnabled
  ? "请求会通过本地代理转发，前端不保存密钥。"
  : "当前使用本地示例数据，适合继续打磨交互与 iOS 包装。";
const serviceMetrics = computed(() => [
  { label: "历史保存", value: "本机" },
  { label: "文件处理", value: serviceEnabled ? "在线" : "示例" },
  { label: "会话状态", value: currentConversationId.value ? "已建立" : "未建立" },
]);

const hasHomeContent = computed(() => {
  return Boolean(draft.value.trim() || messages.value.length || pendingTask.value);
});

const hasReviewContent = computed(() => {
  return Boolean(
    contractText.value.trim()
    || selectedFile.value
    || reviewForm.requirements.trim()
    || reviewForm.customContractType.trim()
    || reviewForm.contractType !== "不确定"
    || reviewInputMode.value !== "text"
    || showReviewMore.value,
  );
});

const hasGenerateContent = computed(() => {
  return Boolean(
    generatePrompt.value.trim()
    || generateForm.requirements.trim()
    || generateForm.customContractType.trim()
    || generateForm.contractType !== "不确定"
    || showGenerateMore.value,
  );
});

const followupModeDesc = computed(() => {
  if (serviceEnabled) {
    return currentConversationId.value ? "会带上当前会话继续请求在线服务" : "会先建立会话，再进入后续追问";
  }
  return "当前为本地追问建议，接入在线服务后会复用会话";
});

const uploadStatusTitle = computed(() => {
  if (!selectedFile.value) return "尚未选择文件";
  if (uploadState.value === "uploading") return "正在上传并解析";
  if (uploadState.value === "ready") return "文件已完成解析";
  if (uploadState.value === "error") return "文件处理失败";
  return "已选择文件";
});

const uploadStatusDesc = computed(() => {
  if (!selectedUploadFile.value) return "支持 PDF / Word / TXT";
  const size = formatFileSize(selectedUploadFile.value.size);
  if (uploadState.value === "uploading") return `${selectedFile.value}${size ? ` · ${size}` : ""}`;
  if (uploadState.value === "ready") return "结果已生成，真实后端接入后会展示解析后的原文。";
  if (uploadState.value === "error") return "请重新选择文件，或改用粘贴文本。";
  return `开始审查时会上传解析${size ? ` · ${size}` : ""}`;
});

const visibleHistory = computed(() => {
  return showAllRecent.value ? history.value : history.value.slice(0, 3);
});

const filteredHistory = computed(() => {
  const query = historyQuery.value.trim();
  return history.value.filter((item) => {
    if (historyFilter.value !== "all" && item.type !== historyFilter.value) return false;
    if (!query) return true;
    const searchable = [
      item.title,
      item.contractText || "",
      item.context ? recordContextLine(item) : "",
      item.result.summary || "",
      item.result.contract_markdown || "",
      item.result.markdown_report || "",
    ].join("\n");
    return searchable.includes(query);
  });
});

const riskItems = computed<RiskView[]>(() => {
  const result = currentResult.value;
  const reviews = result && Array.isArray(result.clause_reviews) ? result.clause_reviews : [];
  if (reviews.length) {
    return reviews.slice(0, 5).map((item, index) => {
      const riskLevel = `${item.risk_level || ""}`;
      const levelClass: RiskView["levelClass"] = riskLevel.includes("高") || riskLevel.includes("high") ? "high" : riskLevel.includes("低") || riskLevel.includes("low") ? "low" : "medium";
      return {
        title: toText(item.clause_title || item.title || item.focus_area || `风险 ${index + 1}`),
        desc: toText(item.issue || item.impact || item.suggestion || item),
        replacement: toText(item.replacement_text || item.suggestion || "建议补充明确条款，降低后续争议。"),
        levelClass,
      };
    });
  }
  return [
    {
      title: "付款条件不够明确",
      desc: "付款节点、验收条件和发票安排缺少绑定，可能导致款项支付争议。",
      replacement: "建议写明每一笔付款的触发条件、付款期限、发票要求和逾期处理方式。",
      levelClass: "medium",
    },
    {
      title: "违约责任偏概括",
      desc: "违约金比例、赔偿范围和免责边界未充分说明，实际执行时容易产生争议。",
      replacement: "建议列明违约金计算方式、损失赔偿范围、通知补救期限和责任上限。",
      levelClass: "medium",
    },
  ];
});

const factRows = computed(() => {
  const facts = currentResult.value?.facts;
  if (!facts || typeof facts !== "object" || Array.isArray(facts)) return [];
  return Object.entries(facts)
    .slice(0, 8)
    .map(([label, value]) => ({ label, value: toText(value) }));
});

const missingFields = computed(() => {
  const result = currentResult.value;
  return result && Array.isArray(result.missing_fields) ? result.missing_fields : [];
});

const signingChecklist = computed(() => {
  const list = currentResult.value?.signing_checklist || currentResult.value?.signature_checklist;
  return Array.isArray(list) ? list.map(toText) : [];
});

const riskLevelText = computed(() => {
  const level = `${currentResult.value?.risk_level || ""}`.toLowerCase();
  if (level.includes("high") || level.includes("高")) return "高风险";
  if (level.includes("low") || level.includes("低")) return "低风险";
  if (level.includes("medium") || level.includes("中")) return "中风险";
  return "待判断";
});

const currentContextRows = computed(() => {
  const context = currentTaskContext.value;
  if (!context) return [];
  return [
    { label: "类型", value: context.contractType || "不确定" },
    { label: "身份", value: context.role || "未知" },
    { label: currentResult.value?.intent === "review" ? "重点" : "条款", value: context.focusAreas.join("、") || "未选择" },
    { label: "输出", value: context.outputStyle },
  ];
});

onMounted(() => {
  const saved = uni.getStorageSync("qihe-history");
  if (Array.isArray(saved)) {
    history.value = saved as HistoryRecord[];
  }

  const savedSettings = uni.getStorageSync(SETTINGS_KEY);
  if (savedSettings && typeof savedSettings === "object" && !Array.isArray(savedSettings)) {
    applySettings(savedSettings as Partial<AppSettings>);
  }
});

onUnmounted(() => {
  stopProcessing();
  if (contractTypeDrawerCloseTimer) {
    clearTimeout(contractTypeDrawerCloseTimer);
    contractTypeDrawerCloseTimer = null;
  }
});

function newConversation() {
  activeMode.value = "auto";
  draft.value = "";
  messages.value = [];
  pendingTask.value = null;
  formNotice.value = null;
  refinementText.value = "";
  resultFollowupDraft.value = "";
  resultFollowups.value = [];
  exportPreviewOpen.value = false;
  currentResult.value = null;
  currentConversationId.value = "";
  currentTaskContext.value = null;
  lastRootScreen.value = "home";
  screen.value = "home";
}

function clearHomeDraft() {
  draft.value = "";
  messages.value = [];
  pendingTask.value = null;
  activeMode.value = "auto";
  currentConversationId.value = "";
  formNotice.value = null;
  uni.showToast({ title: "已清空", icon: "none" });
}

function clearReviewDraft() {
  contractText.value = "";
  selectedFile.value = "";
  selectedUploadFile.value = null;
  uploadState.value = "idle";
  reviewInputMode.value = "text";
  showReviewMore.value = false;
  resetTaskForm("review");
  clearTaskRuntimeState();
  uni.showToast({ title: "已清空", icon: "none" });
}

function clearGenerateDraft() {
  generatePrompt.value = "";
  showGenerateMore.value = false;
  resetTaskForm("generate");
  clearTaskRuntimeState();
  uni.showToast({ title: "已清空", icon: "none" });
}

function resetTaskForm(mode: TaskMode) {
  const form = taskForm(mode);
  form.contractType = "不确定";
  form.customContractType = "";
  form.role = defaultRole.value;
  form.requirements = "";
  form.focusAreas = mode === "review" ? [...DEFAULT_REVIEW_FOCUS] : [...DEFAULT_GENERATE_CLAUSES];
}

function clearTaskRuntimeState() {
  formNotice.value = null;
  currentConversationId.value = "";
  currentTaskContext.value = null;
  refinementText.value = "";
  resultFollowupDraft.value = "";
  resultFollowups.value = [];
}

function switchRootTab(tab: RootScreen) {
  lastRootScreen.value = tab;
  screen.value = tab;
  if (tab !== "history") historyQuery.value = "";
}

function backToRoot() {
  screen.value = lastRootScreen.value;
}

function goReview(prefill = "") {
  if (isRootScreen.value) lastRootScreen.value = screen.value as RootScreen;
  pendingTask.value = null;
  formNotice.value = null;
  activeMode.value = "review";
  contractText.value = prefill || draft.value || contractText.value;
  screen.value = "review";
}

function goGenerate(prefill = "") {
  if (isRootScreen.value) lastRootScreen.value = screen.value as RootScreen;
  pendingTask.value = null;
  formNotice.value = null;
  activeMode.value = "generate";
  generatePrompt.value = prefill || draft.value || generatePrompt.value;
  screen.value = "generate";
}

function inferMode(text: string): Mode | "clarify" {
  if (/解释|什么意思|怎么理解|为什么|怎么改|注意什么|能不能讲讲|怎么看/.test(text) && !/甲方[:：]|乙方[:：]|合同全文|以下合同|附件|上传/.test(text)) return "auto";
  if (/生成|起草|草拟|拟一份|写一份|做个|做一份|模板|草案|协议/.test(text)) return "generate";
  if (/甲方[:：]|乙方[:：]|出租方|承租方|本合同|双方约定|违约责任|租金|押金|签订/.test(text) && text.length > 40) return "review";
  if (/审查|审核|检查|风险|能不能签|有没有问题|看看|上传|文件|合同内容|条款/.test(text)) return "review";
  if (/合同|协议|租房|租赁|服务/.test(text)) return "clarify";
  return "auto";
}

async function sendHomeMessage() {
  const text = draft.value.trim();
  if (!text) {
    uni.showToast({ title: "请输入内容", icon: "none" });
    return;
  }
  messages.value.push({ id: `${Date.now()}-u`, role: "user", text });
  draft.value = "";
  pendingTask.value = null;

  if (serviceEnabled) {
    await sendHomeOnlineFallback(text);
    return;
  }

  const mode = activeMode.value === "auto" ? inferMode(text) : activeMode.value;
  if (mode === "review") {
    contractText.value = text;
    pendingTask.value = createPendingTask("review", text);
    messages.value.push({
      id: `${Date.now()}-a`,
      role: "assistant",
      text: "我判断这是合同审查。确认后我会提取重点条款、风险等级和可替换修改建议。",
    });
    return;
  }
  if (mode === "generate") {
    generatePrompt.value = text;
    pendingTask.value = createPendingTask("generate", text);
    messages.value.push({
      id: `${Date.now()}-a`,
      role: "assistant",
      text: "我判断这是合同生成。确认后我会按合同框架生成草案，并标出签署前待补信息。",
    });
    return;
  }
  if (mode === "clarify") {
    messages.value.push({
      id: `${Date.now()}-a`,
      role: "assistant",
      kind: "clarify",
      text: "我需要先确认你要做哪件事：审查已有合同，还是生成一份新合同？",
    });
    return;
  }
  messages.value.push({
    id: `${Date.now()}-a`,
    role: "assistant",
    text: buildLocalChatReply(text),
  });
}

async function sendHomeOnlineFallback(text: string) {
  submitting.value = true;
  const predictedMode = inferMode(text);
  const processingModeForHome = predictedMode === "review" || predictedMode === "generate" ? predictedMode : null;
  const processingStartedAt = Date.now();
  const thinkingId = addHomeThinkingMessage(homeThinkingText(processingModeForHome));
  if (processingModeForHome) {
    startProcessing(processingModeForHome);
  }
  try {
    const response = await runContractAnalysis({
      mode: "auto",
      query: text,
      contractText: text,
      contractType: inferContractType(text),
      role: defaultRole.value,
      focusAreas: [],
      requirements: withOutputPreference("首页自由输入：请在 Dify 内部按 review / generate / consult 三分支判断；普通闲聊和合同知识咨询走 consult 兜底。"),
      jurisdiction: "中国大陆",
      outputStyle: outputStylePrompt(),
      conversationId: currentConversationId.value,
      file: null,
    });
    currentConversationId.value = response.conversationId || currentConversationId.value;
    if (response.result.intent === "review" || response.result.intent === "generate") {
      const taskMode = response.result.intent;
      if (hasCompleteTaskResult(response.result, taskMode)) {
        removeHomeMessage(thinkingId);
        let resultProcessingStartedAt = processingStartedAt;
        if (!processingModeForHome) {
          startProcessing(taskMode);
          resultProcessingStartedAt = Date.now();
        }
        await keepProcessingVisible(resultProcessingStartedAt);
        openHomeOnlineResult(taskMode, text, response.result);
        return;
      }
      pendingTask.value = createPendingTask(taskMode, text);
      updateHomeMessage(thinkingId, response.result.summary || (taskMode === "review" ? "我判断这是合同审查。确认后我会检查风险并给出修改建议。" : "我判断这是合同生成。确认后我会生成草案并列出待补信息。"));
      return;
    }
    updateHomeMessage(thinkingId, formatHomeReply(response.result.answer_markdown || response.result.summary || response.rawAnswer || buildLocalChatReply(text)));
  } catch (error) {
    const message = error instanceof Error ? error.message : "在线服务暂时不可用";
    updateHomeMessage(thinkingId, `${buildLocalChatReply(text)}\n\n在线服务暂时没有连通：${message}`);
  } finally {
    stopProcessing();
    submitting.value = false;
  }
}

function hasCompleteTaskResult(result: ContractResult, mode: TaskMode) {
  if (`${result.status || ""}`.toLowerCase() === "need_input") return false;
  if (mode === "generate") return Boolean(result.contract_markdown);
  return Boolean(result.markdown_report || result.clause_reviews?.length || result.key_findings?.length || result.summary);
}

function addHomeThinkingMessage(text: string) {
  const id = `${Date.now()}-thinking`;
  messages.value.push({ id, role: "assistant", kind: "thinking", text });
  return id;
}

function updateHomeMessage(id: string, text: string, kind: ChatMessage["kind"] = "normal") {
  const target = messages.value.find((message) => message.id === id);
  if (!target) {
    messages.value.push({ id: `${Date.now()}-a`, role: "assistant", kind, text });
    return;
  }
  target.text = text;
  target.kind = kind;
}

function removeHomeMessage(id: string) {
  messages.value = messages.value.filter((message) => message.id !== id);
}

function homeThinkingText(mode: TaskMode | null) {
  if (mode === "review") return "正在识别合同内容，准备进入审查流程";
  if (mode === "generate") return "正在理解生成需求，准备搭建合同草案";
  return "正在理解你的问题";
}

function openHomeOnlineResult(mode: TaskMode, text: string, result: ContractResult) {
  const typeText = result.contract_type || effectiveContractType(text, mode);
  const form = taskForm(mode);
  form.contractType = contractTypeOptions.some((item) => item.value === typeText) ? typeText : form.contractType;
  form.role = result.role || form.role || defaultRole.value;
  if (mode === "review") {
    contractText.value = text;
  } else {
    generatePrompt.value = text;
  }
  const context = taskContextSnapshot(mode, typeText);
  currentTaskContext.value = context;
  currentResult.value = result;
  resultTab.value = "risks";
  refinementText.value = "";
  resultFollowupDraft.value = "";
  resultFollowups.value = [];
  saveRecord(mode, result, context);
  screen.value = mode === "review" ? "reviewResult" : "generateResult";
}

function formatHomeReply(text: string) {
  return text
    .replace(/^#{1,6}\s*/gm, "")
    .replace(/\*\*/g, "")
    .replace(/^\s*[-*]\s+/gm, "· ")
    .trim()
    .slice(0, 1200);
}

function buildLocalChatReply(text: string) {
  if (/你好|hello|嗨|在吗/.test(text)) {
    return "你好，我是契合。你可以直接粘贴合同让我审查，也可以描述需求让我生成合同草案。";
  }
  if (/违约金|赔偿|违约责任/.test(text)) {
    return "违约责任通常要看三点：违约行为是否明确、违约金或赔偿范围是否可计算、是否留了通知和补救期限。你可以把相关条款发来，我会先帮你定位风险。";
  }
  if (/押金|定金|保证金/.test(text)) {
    return "押金、定金和保证金的用途不同，合同里最好写清金额、扣除条件、退还时间和争议处理。涉及具体条款时，把原文发来会更准确。";
  }
  if (/解除|终止|退租|提前结束/.test(text)) {
    return "解除条款建议写明可解除情形、提前通知期限、费用结算、资料或房屋交接，以及违约解除后的赔偿边界。";
  }
  if (/管辖|法院|仲裁|争议/.test(text)) {
    return "争议解决条款要明确选择法院或仲裁机构，并尽量写到具体地点或机构名称。没有写清时，后续维权成本会更不确定。";
  }
  return "我可以先做合同相关的解释，也可以进入正式处理。需要审查时直接粘贴合同内容；需要生成时说清合同类型、你的身份、金额期限和特殊约定。";
}

function createPendingTask(mode: Exclude<Mode, "auto">, text: string): PendingTask {
  const typeText = effectiveContractType(text, mode);
  const preview = previewText(text, 52);
  return {
    mode,
    text,
    contractType: typeText,
    role: taskForm(mode).role || defaultRole.value,
    title: mode === "review" ? "审查这份合同" : `生成${typeText === "不确定" ? "合同草案" : typeText}`,
    desc: mode === "review"
      ? `将基于这段内容检查付款、违约、解除、主体等风险：${preview}`
      : `将把你的需求整理为完整草案，并列出待补充信息：${preview}`,
  };
}

async function confirmPendingTask() {
  const task = pendingTask.value;
  if (!task) return;
  pendingTask.value = null;
  activeMode.value = task.mode;
  applyPendingTaskToForm(task);
  if (task.mode === "review") {
    contractText.value = task.text;
  } else {
    generatePrompt.value = task.text;
  }
  await runTask(task.mode);
}

function editPendingTask() {
  const task = pendingTask.value;
  if (!task) return;
  pendingTask.value = null;
  activeMode.value = task.mode;
  applyPendingTaskToForm(task);
  if (task.mode === "review") {
    goReview(task.text);
    return;
  }
  goGenerate(task.text);
}

async function startReview() {
  formNotice.value = null;
  if (reviewInputMode.value === "text" && !contractText.value.trim()) {
    setFormNotice("error", "请先粘贴合同内容，或切换到上传文件。");
    return;
  }
  if (reviewInputMode.value === "file" && !selectedFile.value) {
    setFormNotice("error", "请先上传 PDF / Word / TXT 文件。");
    return;
  }
  await runTask("review");
}

async function startGenerate() {
  formNotice.value = null;
  if (!generatePrompt.value.trim()) {
    setFormNotice("error", "请先描述合同生成需求，例如合同类型、身份、金额或期限。");
    return;
  }
  await runTask("generate");
}

function toggleReviewFocus(area: string) {
  reviewForm.focusAreas = toggleSelectedValue(reviewForm.focusAreas, area);
}

function toggleGenerateClause(area: string) {
  generateForm.focusAreas = toggleSelectedValue(generateForm.focusAreas, area);
}

function toggleSelectedValue(items: string[], value: string) {
  return items.includes(value) ? items.filter((item) => item !== value) : [...items, value];
}

function selectedFocusAreas(mode: Exclude<Mode, "auto">) {
  return [...taskForm(mode).focusAreas];
}

function structuredRequirements(mode: Exclude<Mode, "auto">) {
  const manual = taskForm(mode).requirements.trim();
  const areas = selectedFocusAreas(mode);
  const selectedLine = areas.length
    ? mode === "review"
      ? `审查重点：${areas.join("、")}`
      : `需包含条款：${areas.join("、")}`
    : "";
  const manualLine = manual
    ? mode === "review"
      ? `补充说明：${manual}`
      : `补充约定：${manual}`
    : "";
  return [selectedLine, manualLine].filter(Boolean).join("\n");
}

async function runTask(mode: Exclude<Mode, "auto">) {
  if (submitting.value) return;
  submitting.value = true;
  formNotice.value = null;
  const processingStartedAt = Date.now();
  startProcessing(mode);
  if (mode === "review" && selectedUploadFile.value) {
    uploadState.value = "uploading";
  }
  await waitForUiFrame();
  try {
    const queryText = mode === "review" ? contractText.value : generatePrompt.value;
    const typeText = effectiveContractType(queryText, mode);
    const context = taskContextSnapshot(mode, typeText);
    const focusAreas = selectedFocusAreas(mode);
    currentTaskContext.value = context;
    const response = await runContractAnalysis({
      mode: mode as DifyMode,
      query: queryText,
      contractText: queryText,
      contractType: typeText,
      role: context.role,
      focusAreas: [...focusAreas],
      requirements: withOutputPreference(structuredRequirements(mode)),
      jurisdiction: "中国大陆",
      outputStyle: outputStylePrompt(),
      conversationId: currentConversationId.value,
      file: selectedUploadFile.value,
    });
    await keepProcessingVisible(processingStartedAt);
    if (mode === "review" && selectedUploadFile.value) {
      uploadState.value = "ready";
    }
    currentResult.value = response.result;
    currentConversationId.value = response.conversationId;
    resultTab.value = "risks";
    refinementText.value = "";
    resultFollowupDraft.value = "";
    resultFollowups.value = [];
    saveRecord(mode, response.result, context);
    screen.value = mode === "review" ? "reviewResult" : "generateResult";
  } catch (error) {
    if (mode === "review" && selectedUploadFile.value) {
      uploadState.value = "error";
    }
    const message = error instanceof Error ? error.message : "处理失败";
    await keepProcessingVisible(processingStartedAt);
    setFormNotice("error", message);
    uni.showToast({ title: message.slice(0, 24), icon: "none" });
  } finally {
    stopProcessing();
    submitting.value = false;
  }
}

function keepProcessingVisible(startedAt: number) {
  const remaining = MIN_PROCESSING_MS - (Date.now() - startedAt);
  if (remaining <= 0) return Promise.resolve();
  return new Promise<void>((resolve) => {
    setTimeout(resolve, remaining);
  });
}

function waitForUiFrame() {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, 16);
  });
}

function saveRecord(type: HistoryType, result: ContractResult, context: TaskContextSnapshot) {
  const title = type === "review"
    ? result.title || `${result.contract_type || "合同"}审查`
    : result.contract_title || `${result.contract_type || "合同"}草案`;
  const sourceText = type === "review" ? contractText.value : generatePrompt.value;
  const record: HistoryRecord = {
    id: `${Date.now()}`,
    type,
    title,
    time: formatRecordTime(),
    result,
    contractText: sourceText,
    context,
  };
  history.value = [record, ...history.value].slice(0, 30);
  uni.setStorageSync("qihe-history", history.value);
}

function openRecord(record: HistoryRecord) {
  currentResult.value = record.result;
  if (record.type === "review") {
    contractText.value = record.contractText || contractText.value;
  } else {
    generatePrompt.value = record.contractText || generatePrompt.value;
  }
  if (record.context) {
    applyContextToForm(record.type, record.context);
    currentTaskContext.value = record.context;
  } else {
    currentTaskContext.value = null;
  }
  resultTab.value = "risks";
  resultFollowupDraft.value = "";
  resultFollowups.value = [];
  historyOpen.value = false;
  lastRootScreen.value = "history";
  screen.value = record.type === "review" ? "reviewResult" : "generateResult";
}

function clearHistory() {
  uni.showModal({
    title: "清空历史记录",
    content: "只会删除本机保存的审查和生成记录，无法恢复。",
    confirmText: "清空",
    confirmColor: "#e11d48",
    success: (res) => {
      if (!res.confirm) return;
      history.value = [];
      uni.removeStorageSync("qihe-history");
      historyOpen.value = false;
      uni.showToast({ title: "已清空", icon: "none" });
    },
  });
}

function deleteRecord(id: string) {
  uni.showModal({
    title: "删除记录",
    content: "只删除这一条本机历史记录。",
    confirmText: "删除",
    confirmColor: "#e11d48",
    success: (res) => {
      if (!res.confirm) return;
      history.value = history.value.filter((item) => item.id !== id);
      uni.setStorageSync("qihe-history", history.value);
      uni.showToast({ title: "已删除", icon: "none" });
    },
  });
}

function historyFilterCount(filter: HistoryFilter) {
  if (filter === "all") return history.value.length;
  return history.value.filter((item) => item.type === filter).length;
}

function recordContextLine(record: HistoryRecord) {
  const context = record.context;
  if (!context) return "";
  const areas = context.focusAreas.length ? context.focusAreas.join("、") : "未选择";
  return `${context.contractType || "不确定"} · ${context.role || "未知"} · ${areas}`;
}

function setDefaultRole(role: string) {
  defaultRole.value = role;
  reviewForm.role = role;
  generateForm.role = role;
  saveSettings();
}

function setOutputStyle(style: OutputStyle) {
  outputStyle.value = style;
  saveSettings();
}

function togglePrivacyMode(event: Event) {
  const detail = (event as unknown as { detail?: { value?: boolean } }).detail;
  privacyMode.value = Boolean(detail?.value);
  saveSettings();
}

function applySettings(settings: Partial<AppSettings>) {
  if (settings.defaultRole && roles.includes(settings.defaultRole)) {
    defaultRole.value = settings.defaultRole;
    reviewForm.role = settings.defaultRole;
    generateForm.role = settings.defaultRole;
  }
  if (settings.outputStyle && outputStyleOptions.includes(settings.outputStyle)) {
    outputStyle.value = settings.outputStyle;
  }
  if (typeof settings.privacyMode === "boolean") {
    privacyMode.value = settings.privacyMode;
  }
}

function saveSettings() {
  const settings: AppSettings = {
    defaultRole: defaultRole.value,
    outputStyle: outputStyle.value,
    privacyMode: privacyMode.value,
  };
  uni.setStorageSync(SETTINGS_KEY, settings);
}

function outputStylePrompt() {
  return "普通用户可读";
}

function outputStyleInstruction() {
  if (outputStyle.value === "简洁") return "简洁摘要，优先给结论和关键修改点";
  if (outputStyle.value === "详细") return "详细说明，包含原因、风险后果和可替换条款";
  return "普通用户可读，结构清晰，兼顾摘要和细节";
}

function withOutputPreference(requirements: string) {
  return [requirements.trim(), `输出偏好：${outputStyleInstruction()}`].filter(Boolean).join("\n");
}

function taskForm(mode: TaskMode) {
  return mode === "review" ? reviewForm : generateForm;
}

function isCustomContractTypeFor(mode: TaskMode) {
  return taskForm(mode).contractType === CUSTOM_CONTRACT_TYPE;
}

function displayContractTypeFor(mode: TaskMode) {
  const form = taskForm(mode);
  if (isCustomContractTypeFor(mode)) return form.customContractType.trim() || "自定义";
  return form.contractType || "不确定";
}

function applyPendingTaskToForm(task: PendingTask) {
  const form = taskForm(task.mode);
  form.role = task.role || defaultRole.value;
  if (task.contractType && task.contractType !== "不确定") {
    form.contractType = task.contractType;
  }
}

function taskContextSnapshot(mode: TaskMode, contractTypeText: string): TaskContextSnapshot {
  const form = taskForm(mode);
  return {
    contractType: contractTypeText,
    role: form.role || defaultRole.value,
    focusAreas: [...form.focusAreas],
    requirements: form.requirements.trim(),
    outputStyle: outputStyle.value,
    serviceMode: getServiceModeLabel(),
  };
}

function applyContextToForm(mode: TaskMode, context: TaskContextSnapshot) {
  const form = taskForm(mode);
  form.contractType = contractTypeOptions.some((item) => item.value === context.contractType)
    ? context.contractType
    : context.contractType
      ? CUSTOM_CONTRACT_TYPE
      : "不确定";
  form.customContractType = form.contractType === CUSTOM_CONTRACT_TYPE ? context.contractType : form.customContractType;
  form.role = context.role || defaultRole.value;
  form.focusAreas = [...context.focusAreas];
  form.requirements = context.requirements || "";
}

function openContractTypeDrawer(mode: TaskMode) {
  if (contractTypeDrawerCloseTimer) {
    clearTimeout(contractTypeDrawerCloseTimer);
    contractTypeDrawerCloseTimer = null;
  }
  contractTypeDrawerTarget.value = mode;
  contractTypeDrawerClosing.value = false;
  contractTypeDrawerOpen.value = true;
}

function closeContractTypeDrawer() {
  if (!contractTypeDrawerOpen.value || contractTypeDrawerClosing.value) return;
  contractTypeDrawerClosing.value = true;
  contractTypeDrawerCloseTimer = setTimeout(() => {
    contractTypeDrawerOpen.value = false;
    contractTypeDrawerClosing.value = false;
    contractTypeDrawerCloseTimer = null;
  }, 180);
}

function selectContractType(value: string) {
  taskForm(contractTypeDrawerTarget.value).contractType = value;
  closeContractTypeDrawer();
}

function pickFile(stayInCurrentScreen = false) {
  const chooseFile = (uni as unknown as { chooseFile?: (options: Record<string, unknown>) => void }).chooseFile;
  if (!chooseFile) {
    setSelectedUploadFile({
      name: "合同文件.docx",
      path: "合同文件.docx",
      type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    });
    reviewInputMode.value = "file";
    activeMode.value = "review";
    if (!stayInCurrentScreen) screen.value = "review";
    return;
  }
  chooseFile({
    count: 1,
    extension: [".pdf", ".doc", ".docx", ".txt"],
    success: (res: { tempFiles?: Array<{ name?: string; path?: string; size?: number; type?: string }>; tempFilePaths?: string[] }) => {
      const file = res.tempFiles?.[0];
      const path = file?.path || res.tempFilePaths?.[0] || "";
      setSelectedUploadFile({
        name: file?.name || "合同文件.docx",
        path,
        size: file?.size,
        type: file?.type,
      });
      reviewInputMode.value = "file";
      activeMode.value = "review";
      if (!stayInCurrentScreen) screen.value = "review";
    },
    fail: () => uni.showToast({ title: "未选择文件", icon: "none" }),
  });
}

function setSelectedUploadFile(file: LocalUploadFile) {
  selectedFile.value = file.name;
  selectedUploadFile.value = file;
  uploadState.value = "selected";
  formNotice.value = null;
}

function removeSelectedFile() {
  selectedFile.value = "";
  selectedUploadFile.value = null;
  uploadState.value = "idle";
}

function continueEdit() {
  screen.value = "generate";
  showGenerateMore.value = true;
  generatePrompt.value = generatePrompt.value || "请在上一版基础上继续优化合同。";
}

function copyResult() {
  const text = resultPrimaryText();
  copyText(text, "已复制");
}

function exportResult() {
  const text = buildExportMarkdown();
  if (!text.trim()) {
    uni.showToast({ title: "暂无可导出内容", icon: "none" });
    return;
  }
  const filename = `${safeFileName(resultDisplayTitle())}.md`;
  if (shouldUseExportPreview() || !downloadMarkdown(text, filename)) {
    openExportPreview(text, filename);
    return;
  }
  uni.showToast({ title: "已导出 Markdown", icon: "none" });
}

function downloadMarkdown(text: string, filename: string) {
  if (typeof document === "undefined" || typeof Blob === "undefined" || typeof URL === "undefined") return false;
  try {
    const blob = new Blob([text], { type: "text/markdown;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    link.style.display = "none";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    return true;
  } catch {
    return false;
  }
}

function shouldUseExportPreview() {
  if (typeof navigator === "undefined") return true;
  const userAgent = navigator.userAgent || "";
  const isIos = /iPhone|iPad|iPod/i.test(userAgent);
  const isStandaloneWebView = isIos && !/Safari/i.test(userAgent);
  return isIos || isStandaloneWebView;
}

function openExportPreview(text: string, filename: string) {
  exportPreviewText.value = text;
  exportPreviewTitle.value = filename;
  exportPreviewOpen.value = true;
  copyText(text, "已复制 Markdown");
}

function closeExportPreview() {
  exportPreviewOpen.value = false;
}

function copyExportPreview() {
  copyText(exportPreviewText.value, "已复制 Markdown");
}

function copyRiskSuggestion(risk: RiskView) {
  copyText(risk.replacement, "建议已复制");
}

function askAboutRisk(risk: RiskView) {
  const question = `请解释「${risk.title}」这个风险，并告诉我应该怎么改。`;
  appendResultFollowup(question, buildRiskFollowupAnswer(risk));
  uni.showToast({ title: "已添加追问", icon: "none" });
}

async function sendResultFollowup() {
  const question = resultFollowupDraft.value.trim();
  if (!question) {
    uni.showToast({ title: "请输入追问内容", icon: "none" });
    return;
  }
  if (!serviceEnabled || !currentResult.value) {
    appendResultFollowup(question, buildResultFollowupAnswer(question));
    resultFollowupDraft.value = "";
    return;
  }
  const mode = currentResult.value.intent === "generate" ? "generate" : "review";
  const context = currentTaskContext.value || taskContextSnapshot(mode, effectiveContractType(resultSourceText(mode), mode));
  submitting.value = true;
  startProcessing(mode);
  try {
    const response = await runContractAnalysis({
      mode,
      query: question,
      contractText: resultSourceText(mode),
      contractType: context.contractType,
      role: context.role,
      focusAreas: [...context.focusAreas],
      requirements: withOutputPreference([
        context.requirements,
        currentResult.value.summary ? `当前结果摘要：${currentResult.value.summary}` : "",
        `用户追问：${question}`,
      ].filter(Boolean).join("\n")),
      jurisdiction: "中国大陆",
      outputStyle: outputStylePrompt(),
      conversationId: currentConversationId.value,
      file: null,
    });
    currentConversationId.value = response.conversationId;
    appendResultFollowup(question, response.result.answer_markdown || response.result.summary || response.rawAnswer || buildResultFollowupAnswer(question));
    resultFollowupDraft.value = "";
  } catch (error) {
    const message = error instanceof Error ? error.message : "追问失败";
    appendResultFollowup(question, `追问暂时失败：${message}`);
    uni.showToast({ title: message.slice(0, 24), icon: "none" });
  } finally {
    stopProcessing();
    submitting.value = false;
  }
}

function clearResultFollowups() {
  resultFollowups.value = [];
  resultFollowupDraft.value = "";
}

function appendResultFollowup(question: string, answer: string) {
  resultFollowups.value = [
    ...resultFollowups.value,
    {
      id: `${Date.now()}-${resultFollowups.value.length}`,
      question,
      answer,
    },
  ].slice(-6);
}

function buildRiskFollowupAnswer(risk: RiskView) {
  return `这条风险的核心是：${risk.desc} 建议优先把条款改成可执行、可举证、可计算。可直接参考这版替换文本：${risk.replacement}`;
}

function buildResultFollowupAnswer(question: string) {
  const result = currentResult.value;
  if (!result) return "当前没有可追问的结果。";
  if (result.intent === "review") return buildReviewFollowupAnswer(question);
  return buildGenerateFollowupAnswer(question);
}

function buildReviewFollowupAnswer(question: string) {
  const firstRisk = riskItems.value[0];
  if (/怎么改|修改|替换|保护/.test(question) && firstRisk) {
    return `建议先改优先级最高的「${firstRisk.title}」。可以把条款改成：${firstRisk.replacement}`;
  }
  if (/为什么|原因|重要|影响/.test(question) && firstRisk) {
    return `主要原因是「${firstRisk.title}」会影响实际履行和举证。${firstRisk.desc} 如果不改，后续发生争议时很难判断谁违约、怎么赔。`;
  }
  if (/能不能签|是否可以签|建议签/.test(question)) {
    return `当前判断是 ${riskLevelText.value}。如果这是重要合同，建议至少先处理 ${riskItems.value.length} 个重点风险，再签署或交给律师复核。`;
  }
  return `基于当前审查结果，优先关注：${riskItems.value.map((item) => item.title).join("、") || "主体、付款、违约、解除条款"}。你可以继续问某一条风险，我会按普通用户可理解的方式拆开解释。`;
}

function buildGenerateFollowupAnswer(question: string) {
  if (/待补|缺失|补充|怎么填/.test(question)) {
    const fields = missingFields.value.length ? missingFields.value.join("、") : "主体信息、金额期限、签署日期";
    return `当前最需要补齐的是：${fields}。补齐后可以在上方“待补充信息”区域重新生成，草案会更接近可签版本。`;
  }
  if (/保护甲方|甲方/.test(question)) {
    return "如果要更保护甲方，建议强化付款前置条件、乙方交付验收、违约补救期限、责任上限和解除权。可以在“继续修改”里补充“更保护甲方”，再重新生成。";
  }
  if (/保护乙方|乙方/.test(question)) {
    return "如果要更保护乙方，建议补充甲方付款期限、逾期付款责任、验收默认通过规则、变更确认机制和合理免责条款。可以把这些作为补充要求重新生成。";
  }
  if (/能不能用|是否可签|可以签/.test(question)) {
    return "这份草案可以作为沟通初稿，但还不建议直接签署。先补齐待补信息，并确认主体、金额、期限、违约责任和争议解决条款。";
  }
  return "可以继续围绕这份草案追问结构、条款含义、待补信息或改写方向。需要真正改正文时，把具体改写要求填到“待补充信息”区域后重新生成。";
}

function resultSourceText(mode: TaskMode) {
  return mode === "review"
    ? contractText.value || currentResult.value?.markdown_report || currentResult.value?.summary || ""
    : generatePrompt.value || currentResult.value?.contract_markdown || currentResult.value?.summary || "";
}

function fillMissingField(item: string) {
  const line = `${item}：`;
  if (refinementText.value.includes(line)) return;
  refinementText.value = refinementText.value ? `${refinementText.value}\n${line}` : line;
}

async function regenerateWithRefinement() {
  const extra = refinementText.value.trim();
  if (!extra) {
    uni.showToast({ title: "请先补充信息", icon: "none" });
    return;
  }
  generateForm.requirements = mergeText(generateForm.requirements, extra);
  generatePrompt.value = mergeText(
    generatePrompt.value || currentResult.value?.contract_title || "请继续优化上一版合同草案。",
    `补充信息：\n${extra}\n请在上一版基础上重新生成合同草案。`,
  );
  await runTask("generate");
}

function copyText(text: string, title: string) {
  if (!text.trim()) {
    uni.showToast({ title: "暂无可复制内容", icon: "none" });
    return;
  }
  uni.setClipboardData({
    data: text,
    success: () => uni.showToast({ title, icon: "none" }),
  });
}

function clearFormNotice() {
  formNotice.value = null;
}

function copyFormNotice() {
  copyText(formNotice.value?.text || "", "错误信息已复制");
}

function resultPrimaryText() {
  return currentResult.value?.contract_markdown || currentResult.value?.markdown_report || currentResult.value?.summary || "";
}

function resultDisplayTitle() {
  const result = currentResult.value;
  return result?.contract_title || result?.title || `${result?.contract_type || "契合"}结果`;
}

function buildExportMarkdown() {
  const result = currentResult.value;
  if (!result) return "";
  const lines: string[] = [`# ${resultDisplayTitle()}`, ""];
  if (currentTaskContext.value) {
    lines.push(
      "## 处理条件",
      `- 合同类型：${currentTaskContext.value.contractType || "不确定"}`,
      `- 用户身份：${currentTaskContext.value.role || "未知"}`,
      `- ${result.intent === "review" ? "审查重点" : "生成条款"}：${currentTaskContext.value.focusAreas.join("、") || "未选择"}`,
      `- 输出详略：${currentTaskContext.value.outputStyle}`,
      "",
    );
  }
  if (result.summary) {
    lines.push("## 摘要", result.summary, "");
  }
  if (result.intent === "review") {
    lines.push("## 风险概览", `- 安全分：${result.score || "-"}`, `- 等级：${result.grade || "-"}`, `- 风险：${riskLevelText.value}`, "");
    if (riskItems.value.length) {
      lines.push("## 重点风险");
      riskItems.value.forEach((risk, index) => {
        lines.push(`${index + 1}. ${risk.title}`, `   - 问题：${risk.desc}`, `   - 建议：${risk.replacement}`);
      });
      lines.push("");
    }
    const original = contractText.value.trim();
    if (original) {
      lines.push("## 合同原文", original, "");
    }
  } else {
    if (result.contract_markdown) {
      lines.push("## 合同草案", result.contract_markdown, "");
    }
    if (missingFields.value.length) {
      lines.push("## 待补充信息", ...missingFields.value.map((item) => `- ${item}`), "");
    }
    if (signingChecklist.value.length) {
      lines.push("## 签署前清单", ...signingChecklist.value.map((item) => `- ${item}`), "");
    }
  }
  if (result.disclaimer) {
    lines.push("## 提示", result.disclaimer, "");
  }
  return lines.join("\n").trim();
}

function safeFileName(name: string) {
  return (name || "契合结果").replace(/[\\/:*?"<>|]/g, "-").replace(/\s+/g, " ").trim().slice(0, 48) || "契合结果";
}

function inferContractType(text: string) {
  if (/租房|租赁|房东|承租|押金/.test(text)) return "房屋租赁合同";
  if (/软件|开发|技术|系统|源码/.test(text)) return "技术/软件合同";
  if (/劳动|用工|工资|社保/.test(text)) return "劳动/用工合同";
  if (/采购|买卖|货物|商品/.test(text)) return "买卖/采购合同";
  if (/装修|工程|施工/.test(text)) return "工程/装修合同";
  if (/借款|担保|保证/.test(text)) return "借款/担保合同";
  if (/合作|合伙|分成/.test(text)) return "合伙/合作合同";
  if (/服务|委托|外包|咨询/.test(text)) return "服务/委托合同";
  return "不确定";
}

function effectiveContractType(text: string, mode: TaskMode) {
  const form = taskForm(mode);
  if (isCustomContractTypeFor(mode)) return form.customContractType.trim() || "自定义合同";
  if (form.contractType && form.contractType !== "不确定") return form.contractType;
  return inferContractType(text);
}

function buildReadinessState(items: ReadinessItem[], fallbackTip: string): ReadinessState {
  const readyCount = items.filter((item) => item.ready).length;
  const score = Math.round((readyCount / Math.max(1, items.length)) * 100);
  const missing = items.find((item) => !item.ready);
  return {
    score,
    label: score >= 100 ? "信息完整" : score >= 75 ? "可以开始" : score >= 50 ? "仍可补充" : "信息不足",
    tip: missing ? `建议补充：${missing.label}` : fallbackTip,
    items,
  };
}

function startProcessing(mode: Exclude<Mode, "auto">) {
  stopProcessing();
  processingMode.value = mode;
  processingStepIndex.value = 0;
  processingTimer = setInterval(() => {
    const maxIndex = processingSteps.value.length - 1;
    if (processingStepIndex.value < maxIndex) {
      processingStepIndex.value += 1;
    }
  }, 620);
}

function stopProcessing() {
  if (processingTimer) {
    clearInterval(processingTimer);
    processingTimer = null;
  }
  processingMode.value = null;
  processingStepIndex.value = 0;
}

function setFormNotice(type: NoticeType, text: string) {
  formNotice.value = { type, text };
}

function previewText(text: string, maxLength: number) {
  const cleaned = text.replace(/\s+/g, " ").trim();
  if (cleaned.length <= maxLength) return cleaned;
  return `${cleaned.slice(0, maxLength)}...`;
}

function mergeText(base: string, addition: string) {
  const left = base.trim();
  const right = addition.trim();
  if (!left) return right;
  if (!right || left.includes(right)) return left;
  return `${left}\n${right}`;
}

function formatFileSize(size?: number) {
  if (!size || Number.isNaN(size)) return "";
  if (size < 1024) return `${size}B`;
  if (size < 1024 * 1024) return `${Math.round(size / 1024)}KB`;
  return `${(size / 1024 / 1024).toFixed(1)}MB`;
}

function formatRecordTime(date = new Date()) {
  const hours = `${date.getHours()}`.padStart(2, "0");
  const minutes = `${date.getMinutes()}`.padStart(2, "0");
  return `今日 ${hours}:${minutes}`;
}

function toText(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return `${value}`;
  if (typeof value === "object") {
    const item = value as Record<string, unknown>;
    return toText(item.text || item.title || item.name || item.content || item.value || JSON.stringify(value));
  }
  return `${value}`;
}
</script>

<style scoped>
.app-shell {
  width: 100%;
  height: 100vh;
  min-height: 100vh;
  height: 100dvh;
  min-height: 100dvh;
  background: #f7f8fb;
  color: #111827;
  overflow: hidden;
  -webkit-font-smoothing: antialiased;
  -webkit-tap-highlight-color: transparent;
  touch-action: manipulation;
}

.app-shell,
.app-shell * {
  box-sizing: border-box;
}

.screen {
  height: 100vh;
  min-height: 0;
  height: 100dvh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background:
    radial-gradient(circle at 50% 8%, rgba(37, 99, 235, 0.08), transparent 34%),
    #f7f8fb;
  animation: screen-enter 180ms ease-out;
}

.topbar,
.page-top {
  flex: 0 0 auto;
  height: calc(108rpx + constant(safe-area-inset-top));
  height: calc(108rpx + env(safe-area-inset-top));
  padding: calc(12rpx + constant(safe-area-inset-top)) 28rpx 0;
  padding: calc(12rpx + env(safe-area-inset-top)) 28rpx 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: rgba(247, 248, 251, 0.92);
  backdrop-filter: blur(18rpx);
  -webkit-backdrop-filter: blur(18rpx);
}

.page-top {
  position: relative;
  justify-content: center;
}

.page-top > text {
  flex: 0 0 auto;
  max-width: calc(100% - 180rpx);
  font-size: 34rpx;
  font-weight: 700;
  color: #111827;
  text-align: center;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.top-spacer {
  display: none;
}

.icon-btn {
  width: 88rpx;
  height: 88rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent !important;
  border: 0 !important;
  border-radius: 50%;
  box-shadow: none !important;
}

.page-top > .icon-btn {
  position: absolute;
  top: calc(12rpx + constant(safe-area-inset-top));
  top: calc(12rpx + env(safe-area-inset-top));
  z-index: 2;
}

.page-top > .icon-btn:first-child {
  left: 18rpx;
}

.page-top > .icon-btn:last-child {
  right: 18rpx;
}

.icon-btn::after {
  border: 0 !important;
}

.home-scroll {
  position: relative;
  flex: 1;
  min-height: 0;
  height: auto;
  padding: calc(22rpx + constant(safe-area-inset-top)) 32rpx calc(170rpx + constant(safe-area-inset-bottom));
  padding: calc(22rpx + env(safe-area-inset-top)) 32rpx calc(170rpx + env(safe-area-inset-bottom));
}

.home-tech-layer {
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 420rpx;
  pointer-events: none;
  overflow: hidden;
}

.tech-grid {
  position: absolute;
  inset: 0;
  opacity: 0.58;
  background:
    linear-gradient(90deg, rgba(37, 99, 235, 0.08) 1rpx, transparent 1rpx),
    linear-gradient(180deg, rgba(37, 99, 235, 0.06) 1rpx, transparent 1rpx);
  background-size: 56rpx 56rpx;
  mask-image: linear-gradient(180deg, #000000 0%, transparent 82%);
  -webkit-mask-image: linear-gradient(180deg, #000000 0%, transparent 82%);
}

.tech-circuit {
  position: absolute;
  top: 78rpx;
  width: 180rpx;
  height: 116rpx;
  opacity: 0.72;
}

.tech-circuit.left {
  left: 36rpx;
}

.tech-circuit.right {
  right: 36rpx;
  transform: scaleX(-1);
}

.tech-circuit view {
  position: absolute;
  height: 3rpx;
  border-radius: 999rpx;
  background: linear-gradient(90deg, rgba(37, 99, 235, 0), rgba(37, 99, 235, 0.48));
}

.tech-circuit view:nth-child(1) {
  left: 0;
  top: 10rpx;
  width: 132rpx;
}

.tech-circuit view:nth-child(2) {
  left: 42rpx;
  top: 54rpx;
  width: 106rpx;
}

.tech-circuit view:nth-child(3) {
  left: 18rpx;
  top: 98rpx;
  width: 154rpx;
}

.brand-block {
  position: relative;
  z-index: 1;
  min-height: 350rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.tab-scroll {
  flex: 1;
  min-height: 0;
  height: auto;
  padding: calc(34rpx + constant(safe-area-inset-top)) 32rpx calc(174rpx + constant(safe-area-inset-bottom));
  padding: calc(34rpx + env(safe-area-inset-top)) 32rpx calc(174rpx + env(safe-area-inset-bottom));
}

.section-hero {
  margin-bottom: 30rpx;
}

.section-hero.compact {
  margin-bottom: 22rpx;
}

.section-kicker {
  display: block;
  font-size: 25rpx;
  font-weight: 800;
  color: #2563eb;
}

.section-heading {
  display: block;
  margin-top: 10rpx;
  font-size: 42rpx;
  line-height: 1.18;
  font-weight: 850;
  color: #111827;
}

.section-desc {
  display: block;
  margin-top: 14rpx;
  font-size: 27rpx;
  line-height: 1.55;
  color: #687385;
}

.feature-mode-switch {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
  margin-bottom: 24rpx;
}

.feature-mode-switch button,
.feature-mode-switch uni-button {
  width: 100%;
  height: 106rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 22rpx;
  border-radius: 8rpx;
  background: #ffffff;
  border: 1rpx solid #dce4f1;
  color: #111827;
  font-size: 31rpx;
  font-weight: 850;
  box-shadow: 0 10rpx 28rpx rgba(15, 23, 42, 0.045);
  transition: transform 160ms ease, background-color 160ms ease, color 160ms ease;
}

.feature-mode-switch text {
  color: #111827;
  line-height: 1;
}

.feature-mode-switch button.active,
.feature-mode-switch uni-button.active {
  background: linear-gradient(135deg, #2563eb, #0f172a);
  color: #ffffff;
  border-color: transparent;
  box-shadow: 0 18rpx 42rpx rgba(37, 99, 235, 0.24);
}

.feature-mode-switch button.active text,
.feature-mode-switch uni-button.active text {
  color: #ffffff;
}

.feature-mode-switch button::after,
.feature-mode-switch uni-button::after {
  display: none !important;
}

.feature-promo-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 14rpx;
}

.feature-promo-after {
  position: relative;
  z-index: 1;
  margin-top: 22rpx;
}

.feature-promo-grid view {
  min-height: 92rpx;
  padding: 16rpx 18rpx;
  border-radius: 8rpx;
  background: rgba(255, 255, 255, 0.76);
  border: 1rpx solid #e3eaf5;
  box-shadow: 0 8rpx 24rpx rgba(15, 23, 42, 0.035);
}

.feature-promo-grid text:first-child {
  display: block;
  font-size: 26rpx;
  font-weight: 820;
  color: #111827;
}

.feature-promo-grid text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 22rpx;
  line-height: 1.35;
  color: #7b8494;
}

.feature-promo-grid.generate view {
  background: rgba(248, 250, 252, 0.88);
}

.feature-workbench {
  position: relative;
  padding: 28rpx;
  border-radius: 8rpx;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.96), rgba(255, 255, 255, 0.9)),
    linear-gradient(135deg, rgba(37, 99, 235, 0.14), rgba(20, 184, 166, 0.08));
  box-shadow: 0 18rpx 48rpx rgba(15, 23, 42, 0.07);
  overflow: hidden;
}

.feature-workbench::before {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 4rpx;
  background: linear-gradient(90deg, #67d8ff, #2563eb, #14b8a6);
}

.feature-workbench.generate::before {
  background: linear-gradient(90deg, #111827, #2563eb, #67d8ff);
}

.workbench-head {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: space-between;
  gap: 20rpx;
  margin-bottom: 24rpx;
}

.workbench-head .section-heading {
  font-size: 36rpx;
}

.workbench-status {
  width: 140rpx;
  min-height: 92rpx;
  flex: 0 0 auto;
  padding: 14rpx;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  border-radius: 8rpx;
  background: #eef4ff;
}

.workbench-status.pro {
  width: 178rpx;
  min-height: 104rpx;
  background:
    linear-gradient(180deg, rgba(238, 244, 255, 0.96), rgba(255, 255, 255, 0.86)),
    #eef4ff;
  border: 1rpx solid #d9e6ff;
}

.workbench-status.dark {
  background: #f1f3f6;
}

.workbench-status text:first-child {
  font-size: 27rpx;
  font-weight: 850;
  color: #2563eb;
}

.workbench-status.pro text:first-child {
  font-size: 25rpx;
  line-height: 1.2;
}

.workbench-status.dark text:first-child {
  color: #111827;
}

.workbench-status text:last-child {
  margin-top: 6rpx;
  font-size: 20rpx;
  color: #7b8494;
}

.workbench-status.pro text:last-child {
  font-size: 21rpx;
  line-height: 1.28;
}

.feature-input-card {
  position: relative;
  z-index: 1;
  padding: 22rpx;
  box-shadow: none;
  border: 1rpx solid #e6ecf5;
}

.feature-textarea {
  width: 100%;
  min-height: 300rpx;
  padding: 18rpx;
  border-radius: 8rpx;
  background: #f8fafc;
  color: #111827;
  font-size: 28rpx;
  line-height: 1.55;
}

.feature-textarea.generate {
  min-height: 300rpx;
}

.feature-upload {
  height: 300rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 14rpx;
  border-radius: 8rpx;
  border: 2rpx dashed #9dbaff;
  background: #f8fbff;
}

.feature-upload text:nth-child(2) {
  font-size: 30rpx;
  font-weight: 800;
  color: #111827;
}

.feature-upload text:nth-child(3) {
  font-size: 24rpx;
  color: #8a92a3;
}

.upload-status {
  margin-top: 16rpx;
  padding: 18rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  border: 1rpx solid #e5ebf4;
}

.upload-status.ready {
  background: #f0fdf4;
  border-color: #bbf7d0;
}

.upload-status.uploading {
  background: #eef4ff;
  border-color: #bfdbfe;
}

.upload-status.error {
  background: #fff1f2;
  border-color: #fecdd3;
}

.upload-status view {
  flex: 1;
  min-width: 0;
}

.upload-status text:first-child {
  display: block;
  font-size: 27rpx;
  font-weight: 820;
  color: #111827;
}

.upload-status text:last-child {
  display: block;
  margin-top: 6rpx;
  font-size: 23rpx;
  line-height: 1.35;
  color: #7b8494;
}

.upload-status button,
.upload-status uni-button {
  min-width: 92rpx;
  height: 60rpx;
  flex: 0 0 auto;
  border-radius: 8rpx;
  background: #ffffff;
  color: #2563eb;
  font-size: 24rpx;
  font-weight: 800;
}

.upload-status button::after,
.upload-status uni-button::after {
  display: none !important;
}

.form-notice {
  margin-top: 18rpx;
  padding: 18rpx 20rpx;
  border-radius: 8rpx;
  background: #eef4ff;
  border: 1rpx solid #d9e6ff;
}

.form-notice text {
  font-size: 26rpx;
  line-height: 1.45;
  color: #2563eb;
}

.form-notice.error {
  background: #fff1f2;
  border-color: #fecdd3;
}

.form-notice.error text {
  color: #e11d48;
}

.form-notice.success {
  background: #f0fdf4;
  border-color: #bbf7d0;
}

.form-notice.success text {
  color: #15803d;
}

.task-notice {
  position: fixed;
  left: 32rpx;
  right: 32rpx;
  bottom: calc(154rpx + constant(safe-area-inset-bottom));
  bottom: calc(154rpx + env(safe-area-inset-bottom));
  z-index: 32;
  margin-top: 0;
  box-shadow: 0 18rpx 44rpx rgba(15, 23, 42, 0.12);
  animation: notice-rise 160ms ease-out;
}

.form-notice-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12rpx;
  margin-top: 14rpx;
}

.form-notice-actions button,
.form-notice-actions uni-button {
  min-width: 104rpx;
  height: 56rpx;
  border-radius: 8rpx;
  background: #ffffff;
  color: #2563eb;
  font-size: 24rpx;
  font-weight: 800;
}

.form-notice-actions button::after,
.form-notice-actions uni-button::after {
  display: none !important;
}

.readiness-card {
  position: relative;
  z-index: 1;
  margin-top: 18rpx;
  padding: 20rpx;
  border-radius: 8rpx;
  background: rgba(248, 250, 252, 0.92);
  border: 1rpx solid #e3eaf5;
}

.task-readiness {
  margin-top: 24rpx;
  background: #ffffff;
  box-shadow: 0 12rpx 30rpx rgba(15, 23, 42, 0.045);
}

.readiness-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18rpx;
}

.readiness-head view {
  flex: 1;
  min-width: 0;
}

.readiness-head view text:first-child {
  display: block;
  font-size: 28rpx;
  font-weight: 850;
  color: #111827;
}

.readiness-head view text:last-child {
  display: block;
  margin-top: 6rpx;
  font-size: 23rpx;
  color: #7b8494;
}

.readiness-head > text {
  font-size: 32rpx;
  font-weight: 880;
  color: #2563eb;
}

.readiness-bar {
  height: 10rpx;
  margin-top: 16rpx;
  border-radius: 999rpx;
  background: #e9eef6;
  overflow: hidden;
}

.readiness-bar view {
  height: 100%;
  min-width: 8rpx;
  border-radius: 999rpx;
  background: linear-gradient(90deg, #67d8ff, #2563eb);
  transition: width 180ms ease;
}

.readiness-chips {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10rpx;
  margin-top: 16rpx;
}

.readiness-chips view {
  min-height: 54rpx;
  padding: 0 12rpx;
  display: flex;
  align-items: center;
  gap: 8rpx;
  border-radius: 8rpx;
  background: #ffffff;
  color: #7b8494;
  font-size: 23rpx;
  font-weight: 760;
}

.readiness-chips view.ready {
  background: #eef4ff;
  color: #2563eb;
}

.readiness-chips text:first-child {
  width: 24rpx;
  flex: 0 0 auto;
  text-align: center;
  font-weight: 900;
}

.readiness-chips text:last-child {
  min-width: 0;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.readiness-tip {
  display: block;
  margin-top: 14rpx;
  font-size: 23rpx;
  line-height: 1.4;
  color: #7b8494;
}

.feature-field-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 14rpx;
  margin-top: 16rpx;
}

.feature-field-grid input {
  min-height: 78rpx;
  padding: 0 18rpx;
  border-radius: 8rpx;
  background: #f4f7fb;
  font-size: 26rpx;
}

.review-context-panel {
  position: relative;
  z-index: 1;
  margin-top: 18rpx;
  padding: 18rpx;
  border-radius: 8rpx;
  background: rgba(248, 250, 252, 0.92);
  border: 1rpx solid #e3eaf5;
}

.focus-selector {
  margin-top: 18rpx;
}

.feature-focus-section {
  position: relative;
  z-index: 1;
  padding: 18rpx;
  border-radius: 8rpx;
  background: rgba(248, 250, 252, 0.92);
  border: 1rpx solid #e3eaf5;
}

.focus-selector.compact {
  margin: 2rpx 0 16rpx;
}

.focus-label {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
  margin-bottom: 12rpx;
}

.focus-label text:first-child {
  font-size: 26rpx;
  font-weight: 820;
  color: #111827;
}

.focus-label text:last-child {
  font-size: 22rpx;
  color: #8a92a3;
}

.focus-chips {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10rpx;
}

.focus-chip,
.focus-chip uni-button {
  min-width: 0;
  min-height: 64rpx;
  padding: 0 10rpx;
  border-radius: 8rpx;
  border: 1rpx solid #e2e8f0;
  background: #ffffff;
  color: #4b5563;
  font-size: 24rpx;
  font-weight: 760;
  white-space: nowrap;
}

.focus-chip.active,
.focus-chip.active uni-button {
  border-color: #bfdbfe;
  background: #eef4ff;
  color: #2563eb;
}

.focus-chip::after,
.focus-chip uni-button::after {
  display: none !important;
}

.generate-step-card + .generate-step-card {
  margin-top: 18rpx;
}

.step-title-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 18rpx;
}

.step-title-row > text {
  width: 48rpx;
  height: 48rpx;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8rpx;
  background: #eef4ff;
  color: #2563eb;
  font-size: 26rpx;
  font-weight: 850;
}

.step-title-row view {
  flex: 1;
  min-width: 0;
}

.step-title-row view text:first-child {
  display: block;
  font-size: 29rpx;
  font-weight: 850;
  color: #111827;
}

.step-title-row view text:last-child {
  display: block;
  margin-top: 6rpx;
  font-size: 23rpx;
  line-height: 1.35;
  color: #7b8494;
}

.simple-step-title {
  margin-bottom: 18rpx;
}

.simple-step-title > text {
  display: block;
  font-size: 31rpx;
  font-weight: 850;
  color: #111827;
}

.contract-type-picker {
  margin-top: 2rpx;
}

.contract-type-picker.compact {
  margin: 0 0 16rpx;
}

.contract-type-select {
  width: 100%;
  min-height: 90rpx;
  padding: 0 20rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
  border-radius: 8rpx;
  background: #f8fafc;
  border: 1rpx solid #e2e8f0;
  text-align: left;
  transition: background-color 180ms ease, border-color 180ms ease, box-shadow 180ms ease;
}

.contract-type-select::after {
  display: none !important;
}

.contract-type-select.open {
  background: #f5f8ff;
  border-color: #bfceff;
  box-shadow: 0 10rpx 24rpx rgba(37, 99, 235, 0.08);
}

.contract-type-select uni-icons {
  flex: 0 0 auto;
  transition: transform 180ms ease;
}

.contract-type-select.open uni-icons {
  transform: rotate(180deg);
}

.contract-type-select view,
.contract-type-select uni-view {
  flex: 1;
  min-width: 0;
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.contract-type-select view text,
.contract-type-select uni-view uni-text {
  display: block;
  width: 100%;
  white-space: nowrap;
}

.contract-type-select-label {
  font-size: 24rpx;
  font-weight: 760;
  color: #7b8494;
}

.contract-type-select-value {
  width: 100%;
  margin-top: 6rpx;
  font-size: 29rpx;
  font-weight: 840;
  color: #111827;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.custom-contract-input {
  min-height: 78rpx;
  padding: 0 18rpx;
  margin-top: 8rpx;
  border-radius: 8rpx;
  background: #f4f7fb;
  font-size: 26rpx;
}

.role-strip {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10rpx;
  margin-top: 18rpx;
}

.role-strip button,
.role-strip uni-button {
  min-height: 72rpx;
  border-radius: 8rpx;
  background: #ffffff;
  color: #4b5563;
  font-size: 25rpx;
  font-weight: 750;
}

.role-strip button.active,
.role-strip uni-button.active {
  background: #eef4ff;
  color: #2563eb;
}

.capability-grid {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 14rpx;
  margin-top: 18rpx;
}

.capability-grid view {
  min-height: 104rpx;
  padding: 18rpx;
  border-radius: 8rpx;
  background: rgba(248, 250, 252, 0.92);
  border: 1rpx solid #e7edf5;
}

.capability-grid text:first-child {
  display: block;
  font-size: 26rpx;
  font-weight: 820;
  color: #111827;
}

.capability-grid text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 22rpx;
  line-height: 1.35;
  color: #7b8494;
}

.feature-primary-action {
  position: relative;
  z-index: 1;
  width: 100%;
  min-height: 92rpx;
  margin-top: 22rpx;
  border-radius: 8rpx;
  background: #2563eb;
  color: #ffffff;
  font-size: 30rpx;
  font-weight: 850;
}

.button-content {
  width: 100%;
  min-height: inherit;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
}

.button-content text {
  color: inherit;
}

.button-spinner {
  width: 28rpx;
  height: 28rpx;
  border-radius: 50%;
  border: 3rpx solid rgba(255, 255, 255, 0.42);
  border-top-color: #ffffff;
  animation: processing-spin 760ms linear infinite;
}

.feature-workbench.generate .feature-primary-action {
  background: #111827;
}

.feature-card:active,
.feature-mode-switch button:active,
.history-card:active,
.settings-row:active,
.bottom-tabs button:active {
  transform: scale(0.98);
}

.feature-icon,
.settings-icon {
  width: 72rpx;
  height: 72rpx;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8rpx;
  background: #eef4ff;
}

.feature-icon.dark {
  background: #f1f3f6;
}

.feature-copy,
.settings-copy,
.profile-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.feature-copy text:first-child,
.settings-copy text:first-child,
.profile-main text:first-child {
  font-size: 31rpx;
  line-height: 1.25;
  font-weight: 800;
  color: #111827;
}

.feature-copy text:last-child,
.settings-copy text:last-child,
.profile-main text:last-child {
  margin-top: 8rpx;
  font-size: 25rpx;
  line-height: 1.45;
  color: #7b8494;
  text-align: left;
}

.page-search {
  margin-bottom: 16rpx;
}

.history-filter {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12rpx;
  margin-bottom: 20rpx;
}

.history-filter button,
.history-filter uni-button {
  min-height: 72rpx;
  padding: 0 14rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
  border-radius: 8rpx;
  background: #ffffff;
  color: #5f697a;
  font-size: 25rpx;
  font-weight: 780;
  border: 1rpx solid #e6ecf5;
}

.history-filter button.active,
.history-filter uni-button.active {
  background: #eef4ff;
  color: #2563eb;
  border-color: #bdd4ff;
}

.history-filter text:last-child {
  min-width: 34rpx;
  height: 34rpx;
  padding: 0 8rpx;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 999rpx;
  background: #f1f4f8;
  color: #7b8494;
  font-size: 21rpx;
  font-weight: 850;
}

.history-filter button.active text:last-child,
.history-filter uni-button.active uni-text:last-child {
  background: #ffffff;
  color: #2563eb;
}

.history-filter button::after,
.history-filter uni-button::after {
  display: none !important;
}

.history-page-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.history-card {
  width: 100%;
  min-height: 136rpx;
  display: flex;
  align-items: center;
  gap: 10rpx;
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 12rpx 30rpx rgba(15, 23, 42, 0.045);
  transition: transform 160ms ease;
  overflow: hidden;
}

.history-card-main {
  flex: 1;
  min-width: 0;
  min-height: 136rpx;
  padding: 22rpx 6rpx 22rpx 22rpx;
  display: flex;
  align-items: center;
  gap: 18rpx;
  background: transparent !important;
  text-align: left;
}

.history-card-main::after {
  display: none !important;
}

.history-delete {
  width: 68rpx;
  height: 68rpx;
  min-height: 68rpx;
  margin-right: 18rpx;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #fff1f2;
  border-radius: 8rpx;
}

.history-delete::after {
  display: none !important;
}

.record-preview {
  width: 100%;
  margin-top: 10rpx;
  font-size: 24rpx;
  line-height: 1.4;
  color: #9aa2b0;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  text-align: left;
}

.record-context {
  display: block;
  width: 100%;
  margin-top: 8rpx;
  font-size: 23rpx;
  line-height: 1.35;
  color: #2563eb;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  text-align: left;
}

.empty-state {
  min-height: 420rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.empty-state text:nth-child(2) {
  margin-top: 20rpx;
  font-size: 31rpx;
  font-weight: 800;
  color: #111827;
}

.empty-state text:nth-child(3) {
  width: 70%;
  margin-top: 10rpx;
  font-size: 25rpx;
  line-height: 1.45;
  color: #8a92a3;
}

.profile-card,
.settings-group {
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 14rpx 36rpx rgba(15, 23, 42, 0.05);
}

.profile-card {
  min-height: 150rpx;
  padding: 28rpx;
  display: flex;
  align-items: center;
  gap: 22rpx;
  margin-bottom: 24rpx;
}

.avatar {
  width: 88rpx;
  height: 88rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: linear-gradient(135deg, #67d8ff, #3167f6);
  color: #ffffff;
  font-size: 34rpx;
  font-weight: 850;
}

.profile-status-pill {
  min-width: 112rpx;
  height: 64rpx;
  padding: 0 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8rpx;
  background: #eef4ff;
  color: #2563eb;
  font-size: 26rpx;
  font-weight: 800;
}

.settings-panel {
  padding: 28rpx;
  margin-bottom: 24rpx;
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 14rpx 36rpx rgba(15, 23, 42, 0.05);
}

.settings-panel-head {
  margin-bottom: 24rpx;
}

.settings-panel-head text:first-child {
  display: block;
  font-size: 34rpx;
  font-weight: 850;
  color: #111827;
}

.settings-panel-head text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 25rpx;
  color: #7b8494;
}

.setting-field {
  padding: 22rpx 0;
  border-top: 1rpx solid #eef1f6;
}

.setting-toggle-row {
  min-height: 104rpx;
  padding-top: 22rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20rpx;
  border-top: 1rpx solid #eef1f6;
}

.setting-copy {
  min-width: 0;
}

.setting-copy text:first-child {
  display: block;
  font-size: 29rpx;
  font-weight: 820;
  color: #111827;
}

.setting-copy text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.4;
  color: #7b8494;
}

.settings-choice-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10rpx;
  margin-top: 18rpx;
}

.settings-choice-row.three {
  grid-template-columns: repeat(3, 1fr);
}

.settings-choice-row button,
.settings-choice-row uni-button {
  min-height: 70rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  color: #4b5563;
  font-size: 25rpx;
  font-weight: 760;
}

.settings-choice-row button.active,
.settings-choice-row uni-button.active {
  background: #eef4ff;
  color: #2563eb;
}

.service-panel {
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.98), rgba(248, 251, 255, 0.96)),
    #ffffff;
}

.service-status-row {
  display: flex;
  align-items: center;
  gap: 18rpx;
  padding: 20rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
}

.service-pulse {
  position: relative;
  width: 20rpx;
  height: 20rpx;
  flex: 0 0 auto;
  border-radius: 50%;
  background: #64748b;
}

.service-pulse.live {
  background: #16a34a;
}

.service-pulse::after {
  content: "";
  position: absolute;
  inset: -8rpx;
  border-radius: 50%;
  border: 2rpx solid rgba(100, 116, 139, 0.18);
  animation: pulse-ring 1400ms ease-out infinite;
}

.service-pulse.live::after {
  border-color: rgba(22, 163, 74, 0.2);
}

.service-status-row view:last-child {
  min-width: 0;
}

.service-status-row view:last-child text:first-child {
  display: block;
  font-size: 30rpx;
  font-weight: 850;
  color: #111827;
}

.service-status-row view:last-child text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.45;
  color: #7b8494;
}

.service-metric-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12rpx;
  margin-top: 16rpx;
}

.service-metric-grid view {
  min-height: 84rpx;
  padding: 14rpx 8rpx;
  border-radius: 8rpx;
  background: #f8fafc;
  text-align: center;
}

.service-metric-grid text:first-child {
  display: block;
  font-size: 26rpx;
  font-weight: 850;
  color: #111827;
}

.service-metric-grid text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 21rpx;
  color: #8a92a3;
}

.settings-choice-row button::after,
.settings-choice-row uni-button::after {
  display: none !important;
}

.settings-group {
  margin-bottom: 24rpx;
  overflow: hidden;
}

.settings-row {
  width: 100%;
  min-height: 112rpx;
  padding: 20rpx 24rpx;
  display: flex;
  align-items: center;
  gap: 18rpx;
  border-bottom: 1rpx solid #eef1f6;
  background: #ffffff;
  transition: transform 160ms ease;
}

.settings-row:last-child {
  border-bottom: 0;
}

.settings-icon {
  width: 64rpx;
  height: 64rpx;
}

.settings-icon.danger {
  background: #fff1f2;
}

.logo-mark {
  width: 70rpx;
  height: 58rpx;
  margin-bottom: 18rpx;
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.logo-mark view {
  height: 14rpx;
  border-radius: 6rpx;
  background: linear-gradient(90deg, #67d8ff, #3167f6);
}

.logo-mark view:nth-child(2) {
  width: 82%;
}

.logo-mark view:nth-child(3) {
  width: 46%;
  background: linear-gradient(90deg, #5eead4, #9ca3af);
}

.brand-name {
  font-size: 56rpx;
  font-weight: 800;
  letter-spacing: 0;
  color: #171717;
}

.brand-subtitle {
  margin-top: 10rpx;
  font-size: 26rpx;
  color: #7b8190;
}

.chat-thread {
  padding: 24rpx 0;
}

.message-row {
  display: flex;
  margin-bottom: 22rpx;
}

.message-row.user {
  justify-content: flex-end;
}

.message-row.assistant {
  justify-content: flex-start;
}

.message-bubble {
  max-width: 78%;
  padding: 24rpx 28rpx;
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 12rpx 30rpx rgba(15, 23, 42, 0.05);
}

.message-row.user .message-bubble {
  background: #2563eb;
  color: #ffffff;
}

.message-bubble text {
  font-size: 30rpx;
  line-height: 1.55;
}

.message-bubble.thinking {
  background: rgba(255, 255, 255, 0.92);
  border: 1rpx solid rgba(203, 213, 225, 0.78);
}

.thinking-content {
  display: flex;
  align-items: center;
  gap: 18rpx;
}

.thinking-dots {
  display: flex;
  align-items: center;
  gap: 8rpx;
  flex-shrink: 0;
}

.thinking-dots view {
  width: 9rpx;
  height: 9rpx;
  border-radius: 999rpx;
  background: #2563eb;
  opacity: 0.42;
  animation: thinking-dot 900ms ease-in-out infinite;
}

.thinking-dots view:nth-child(2) {
  animation-delay: 120ms;
}

.thinking-dots view:nth-child(3) {
  animation-delay: 240ms;
}

.clarify-actions {
  display: flex;
  gap: 16rpx;
  margin-top: 22rpx;
}

.clarify-actions button,
.clarify-actions uni-button {
  flex: 1;
  height: 70rpx;
  border-radius: 8rpx;
  background: #eef4ff;
  color: #2563eb;
  font-size: 26rpx;
  font-weight: 700;
}

.task-confirm-card {
  position: relative;
  z-index: 1;
  padding: 26rpx;
  margin-bottom: 24rpx;
  border-radius: 8rpx;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.98), rgba(248, 251, 255, 0.96)),
    #ffffff;
  border: 1rpx solid #dbe8ff;
  box-shadow: 0 16rpx 40rpx rgba(37, 99, 235, 0.09);
  animation: screen-enter 180ms ease-out;
}

.confirm-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
  margin-bottom: 14rpx;
}

.confirm-kicker {
  font-size: 24rpx;
  font-weight: 800;
  color: #2563eb;
}

.confirm-pill {
  padding: 8rpx 14rpx;
  border-radius: 8rpx;
  background: #eef4ff;
  color: #2563eb;
  font-size: 22rpx;
  font-weight: 800;
}

.confirm-title {
  display: block;
  font-size: 34rpx;
  font-weight: 850;
  color: #111827;
}

.confirm-desc {
  display: block;
  margin-top: 12rpx;
  font-size: 27rpx;
  line-height: 1.55;
  color: #5f697a;
}

.confirm-meta {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12rpx;
  margin-top: 20rpx;
}

.confirm-meta view {
  min-width: 0;
  padding: 16rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
}

.confirm-meta text:first-child {
  display: block;
  font-size: 22rpx;
  color: #8a92a3;
}

.confirm-meta text:last-child {
  display: block;
  margin-top: 6rpx;
  font-size: 26rpx;
  font-weight: 800;
  color: #111827;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.confirm-actions {
  display: grid;
  grid-template-columns: 1.25fr 1fr;
  gap: 14rpx;
  margin-top: 22rpx;
}

.confirm-actions button,
.confirm-actions uni-button {
  min-height: 78rpx;
  border-radius: 8rpx;
  background: #eef4ff;
  color: #2563eb;
  font-size: 27rpx;
  font-weight: 800;
}

.confirm-actions button.primary,
.confirm-actions uni-button.primary {
  background: #2563eb;
  color: #ffffff;
}

.confirm-actions button::after,
.confirm-actions uni-button::after,
.clarify-actions button::after,
.clarify-actions uni-button::after {
  display: none !important;
}

.composer-card {
  padding: 30rpx;
  border: 1rpx solid #dbe4f0;
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 18rpx 45rpx rgba(15, 23, 42, 0.052);
}

.input-card-head {
  min-height: 46rpx;
  margin-bottom: 18rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
}

.input-card-head > text {
  flex: 1;
  min-width: 0;
  font-size: 27rpx;
  line-height: 1.2;
  font-weight: 800;
  color: #111827;
}

.clear-surface-action,
.clear-surface-action.uni-button {
  width: auto;
  min-width: 104rpx;
  height: 48rpx;
  min-height: 48rpx;
  padding: 0 16rpx;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6rpx;
  flex: 0 0 auto;
  border: 1rpx solid #e1e7f0;
  border-radius: 999rpx;
  background: #f8fafc !important;
  color: #64748b;
  box-shadow: none;
}

.clear-surface-action text {
  font-size: 23rpx;
  font-weight: 750;
  color: #64748b;
  line-height: 1;
}

.clear-surface-action::after,
.clear-surface-action.uni-button::after {
  display: none !important;
}

.main-input {
  width: 100%;
  height: 180rpx;
  font-size: 31rpx;
  line-height: 1.5;
  color: #111827;
}

.placeholder {
  color: #a3a8b3;
}

.composer-bottom {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  margin-top: 18rpx;
}

.composer-actions {
  display: flex;
  align-items: center;
  gap: 18rpx;
}

.round-btn,
.send-btn {
  width: 88rpx;
  height: 88rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
}

.round-btn {
  border: 2rpx solid #d8e2ef;
  background: #ffffff;
}

.send-btn {
  background: #2563eb;
}

.primary-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20rpx;
  margin: 34rpx 0 42rpx;
}

.primary-actions button,
.primary-actions uni-button {
  height: 108rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  border-radius: 8rpx;
  background: #ffffff;
  border: 1rpx solid #e6e8ef;
  box-shadow: 0 10rpx 26rpx rgba(15, 23, 42, 0.04);
}

.primary-actions text {
  font-size: 31rpx;
  font-weight: 700;
  color: #111827;
}

.section-title-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 18rpx;
  gap: 16rpx;
}

.section-title-row text {
  font-size: 32rpx;
  font-weight: 800;
  color: #111827;
}

.section-title-row .section-toggle {
  width: auto;
  min-width: 112rpx;
  height: 62rpx;
  margin: 0 0 0 auto;
  padding: 0 22rpx;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
  border-radius: 8rpx;
  border: 1rpx solid #dbe3ef;
  font-size: 25rpx;
  font-weight: 800;
  color: #2563eb;
  background: #ffffff !important;
  box-shadow: 0 8rpx 20rpx rgba(15, 23, 42, 0.04);
}

.section-title-row .section-toggle::after {
  display: none !important;
}

.recent-list {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.drawer-list {
  display: flex;
  flex-direction: column;
}

.recent-row,
.drawer-record {
  width: 100%;
  min-height: 96rpx;
  padding: 20rpx 0;
  display: flex;
  align-items: center;
  gap: 18rpx;
  border-bottom: 1rpx solid #edf0f5;
}

.recent-row,
.recent-row.uni-button {
  min-height: 124rpx;
  padding: 22rpx 22rpx;
  border: 1rpx solid #e3e8f1;
  border-radius: 8rpx;
  background: rgba(255, 255, 255, 0.86) !important;
  box-shadow: 0 10rpx 28rpx rgba(15, 23, 42, 0.035);
}

.recent-row::after,
.recent-row.uni-button::after {
  display: none !important;
}

.record-type-dot {
  width: 60rpx;
  height: 60rpx;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 15rpx;
  overflow: hidden;
  border: 1rpx solid rgba(255, 255, 255, 0.78);
  background: linear-gradient(145deg, #55a9ff, #2563eb);
  box-shadow:
    0 10rpx 20rpx rgba(37, 99, 235, 0.18),
    inset 0 1rpx 0 rgba(255, 255, 255, 0.42);
}

.record-type-dot :deep(.uni-icons) {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
}

.record-type-dot.generate {
  background: linear-gradient(145deg, #2dd4bf, #0f8b7e);
  box-shadow:
    0 10rpx 20rpx rgba(15, 118, 110, 0.18),
    inset 0 1rpx 0 rgba(255, 255, 255, 0.42);
}

.record-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.record-title {
  max-width: 100%;
  font-size: 29rpx;
  font-weight: 700;
  color: #1f2937;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.record-meta {
  margin-top: 6rpx;
  font-size: 24rpx;
  color: #8a92a3;
}

.task-screen,
.result-screen {
  padding-bottom: 0;
}

.task-scroll,
.result-scroll {
  flex: 1;
  min-height: 0;
  height: auto;
  padding: 28rpx 32rpx calc(176rpx + constant(safe-area-inset-bottom));
  padding: 28rpx 32rpx calc(176rpx + env(safe-area-inset-bottom));
}

.task-card,
.collapse-card,
.document-card,
.summary-card,
.risk-card,
.info-card {
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 14rpx 36rpx rgba(15, 23, 42, 0.05);
}

.task-card {
  padding: 24rpx;
}

.segmented {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10rpx;
  padding: 8rpx;
  border-radius: 8rpx;
  background: #f2f4f8;
  margin-bottom: 24rpx;
}

.segmented button,
.segmented uni-button {
  min-height: 88rpx;
  border-radius: 8rpx;
  font-size: 28rpx;
  font-weight: 700;
  color: #667085;
}

.segmented button.active,
.segmented uni-button.active {
  background: #ffffff;
  color: #111827;
  box-shadow: 0 6rpx 18rpx rgba(15, 23, 42, 0.06);
}

.task-textarea {
  width: 100%;
  min-height: 430rpx;
  padding: 20rpx;
  border-radius: 8rpx;
  background: #f9fafc;
  font-size: 30rpx;
  line-height: 1.55;
  color: #111827;
}

.generate-area {
  min-height: 520rpx;
}

.upload-box {
  height: 360rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16rpx;
  border-radius: 8rpx;
  border: 2rpx dashed #93b4ff;
  background: #f8fbff;
}

.upload-box text:nth-child(2) {
  font-size: 32rpx;
  font-weight: 700;
  color: #111827;
}

.upload-box text:nth-child(3) {
  font-size: 25rpx;
  color: #8a92a3;
}

.collapse-card {
  margin-top: 24rpx;
  overflow: hidden;
}

.collapse-head {
  width: 100%;
  height: 96rpx;
  padding: 0 26rpx;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.collapse-head text {
  font-size: 29rpx;
  font-weight: 700;
  color: #111827;
}

.optional-panel {
  padding: 0 26rpx 26rpx;
}

.optional-panel input {
  min-height: 88rpx;
  padding: 0 22rpx;
  margin-bottom: 16rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  font-size: 27rpx;
}

.choice-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12rpx;
  margin-bottom: 16rpx;
}

.choice-row button,
.choice-row uni-button {
  min-height: 88rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  color: #4b5563;
  font-size: 26rpx;
}

.choice-row button.active,
.choice-row uni-button.active {
  color: #2563eb;
  background: #eef4ff;
}

.fixed-action,
.result-actions-fixed {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 30;
  padding: 20rpx 32rpx calc(20rpx + constant(safe-area-inset-bottom));
  padding: 20rpx 32rpx calc(20rpx + env(safe-area-inset-bottom));
  background: linear-gradient(180deg, rgba(247, 248, 251, 0), #f7f8fb 28%);
}

.fixed-action button,
.fixed-action uni-button {
  width: 100%;
  height: 92rpx;
  border-radius: 8rpx;
  background: #2563eb;
  color: #ffffff;
  font-size: 31rpx;
  font-weight: 800;
}

.result-tabs {
  flex: 0 0 auto;
  max-width: calc(100% - 180rpx);
  display: flex;
  justify-content: center;
  gap: 46rpx;
}

.result-tabs button,
.result-tabs uni-button {
  position: relative;
  min-width: 88rpx;
  height: 88rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent !important;
  border-radius: 0;
  font-size: 30rpx;
  color: #4b5563;
}

.result-tabs button::after,
.result-tabs uni-button::after {
  display: none !important;
}

.result-tabs button.active,
.result-tabs uni-button.active {
  color: #2563eb;
  font-weight: 800;
}

.result-tabs button.active::after,
.result-tabs uni-button.active::after {
  content: "";
  display: block !important;
  position: absolute;
  left: 18rpx;
  right: 18rpx;
  bottom: 0;
  height: 5rpx;
  border: 0 !important;
  border-radius: 999rpx;
  background: #2563eb;
}

.result-stack {
  display: flex;
  flex-direction: column;
  gap: 22rpx;
}

.summary-card,
.risk-card,
.document-card,
.info-card {
  padding: 28rpx;
}

.context-card {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12rpx;
  padding: 18rpx;
  margin-bottom: 24rpx;
  border-radius: 8rpx;
  background: #ffffff;
  border: 1rpx solid #e6ecf5;
  box-shadow: 0 12rpx 30rpx rgba(15, 23, 42, 0.04);
}

.context-card view {
  min-width: 0;
  min-height: 64rpx;
  padding: 10rpx 12rpx;
  border-radius: 8rpx;
  background: #f8fafc;
}

.context-card text:first-child {
  display: block;
  font-size: 21rpx;
  color: #8a92a3;
}

.context-card text:last-child {
  display: -webkit-box;
  margin-top: 6rpx;
  font-size: 24rpx;
  font-weight: 800;
  color: #111827;
  overflow: hidden;
  white-space: normal;
  text-overflow: ellipsis;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.summary-kicker {
  font-size: 24rpx;
  color: #2563eb;
  font-weight: 700;
}

.summary-title,
.document-title,
.info-card > text {
  display: block;
  margin-top: 8rpx;
  font-size: 34rpx;
  font-weight: 800;
  color: #111827;
}

.summary-copy,
.risk-copy,
.document-copy,
.disclaimer {
  display: block;
  margin-top: 18rpx;
  font-size: 29rpx;
  line-height: 1.65;
  color: #5c6678;
  white-space: pre-wrap;
}

.generate-summary {
  margin-bottom: 24rpx;
}

.score-strip {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12rpx;
  margin-top: 20rpx;
}

.score-strip view {
  min-height: 92rpx;
  padding: 14rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  border: 1rpx solid #e7edf5;
}

.score-strip text:first-child {
  display: block;
  font-size: 31rpx;
  line-height: 1.2;
  font-weight: 850;
  color: #111827;
}

.score-strip text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 22rpx;
  color: #7b8494;
}

.risk-head {
  display: flex;
  align-items: center;
  gap: 14rpx;
}

.risk-head text {
  font-size: 31rpx;
  font-weight: 800;
  color: #111827;
}

.risk-mark {
  width: 8rpx;
  height: 36rpx;
  border-radius: 8rpx;
  background: #f97316;
}

.risk-mark.high {
  background: #ef4444;
}

.risk-mark.low {
  background: #16a34a;
}

.risk-card button,
.risk-card uni-button {
  width: auto;
  min-height: 64rpx;
  display: inline-flex;
  align-items: center;
  justify-content: flex-start;
  margin-top: 18rpx;
  background: transparent !important;
  border-radius: 0;
  color: #2563eb;
  font-size: 27rpx;
  font-weight: 700;
  text-align: left;
}

.risk-card button::after,
.risk-card uni-button::after {
  display: none !important;
}

.replacement-box {
  margin-top: 20rpx;
  padding: 22rpx;
  border-radius: 8rpx;
  background: #f6f8ff;
}

.replacement-box text {
  display: block;
  font-size: 27rpx;
  line-height: 1.6;
  color: #3f4858;
}

.replacement-box text:first-child {
  margin-bottom: 10rpx;
  color: #2563eb;
  font-weight: 800;
}

.replacement-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12rpx;
  margin-top: 18rpx;
}

.replacement-actions button,
.replacement-actions uni-button {
  width: 100%;
  min-height: 68rpx;
  margin-top: 0;
  justify-content: center;
  border-radius: 8rpx;
  background: #ffffff !important;
  color: #2563eb;
  font-size: 25rpx;
  font-weight: 800;
}

.fact-row {
  display: flex;
  justify-content: space-between;
  gap: 24rpx;
  padding: 22rpx 0;
  border-bottom: 1rpx solid #edf0f5;
}

.fact-row text:first-child {
  color: #8a92a3;
}

.fact-row text:last-child {
  flex: 1;
  text-align: right;
  color: #111827;
  font-weight: 700;
}

.draft-card {
  margin-bottom: 24rpx;
}

.info-card {
  margin-bottom: 24rpx;
}

.bullet-row {
  position: relative;
  padding-left: 28rpx;
  margin-top: 18rpx;
  font-size: 28rpx;
  color: #4b5563;
}

.bullet-row::before {
  content: "";
  position: absolute;
  left: 0;
  top: 12rpx;
  width: 8rpx;
  height: 8rpx;
  border-radius: 50%;
  background: #2563eb;
}

.missing-row {
  min-height: 64rpx;
  padding-right: 136rpx;
}

.missing-row text {
  font-size: 28rpx;
  line-height: 1.45;
  color: #4b5563;
}

.missing-row button,
.missing-row uni-button {
  position: absolute;
  right: 0;
  top: -8rpx;
  width: 116rpx;
  height: 58rpx;
  border-radius: 8rpx;
  background: #eef4ff;
  color: #2563eb;
  font-size: 24rpx;
  font-weight: 800;
  white-space: nowrap;
}

.missing-row button::after,
.missing-row uni-button::after {
  display: none !important;
}

.refine-box {
  margin-top: 24rpx;
  padding: 20rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
}

.refine-box textarea {
  width: 100%;
  height: 156rpx;
  font-size: 27rpx;
  line-height: 1.55;
  color: #111827;
}

.refine-box button,
.refine-box uni-button {
  width: 100%;
  min-height: 78rpx;
  margin-top: 16rpx;
  border-radius: 8rpx;
  background: #111827;
  color: #ffffff;
  font-size: 27rpx;
  font-weight: 820;
}

.refine-box button::after,
.refine-box uni-button::after {
  display: none !important;
}

.followup-card {
  padding: 28rpx;
  margin-bottom: 24rpx;
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 14rpx 36rpx rgba(15, 23, 42, 0.05);
}

.followup-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20rpx;
  margin-bottom: 18rpx;
}

.followup-head view {
  flex: 1;
  min-width: 0;
}

.followup-head view text:first-child {
  display: block;
  font-size: 34rpx;
  font-weight: 850;
  color: #111827;
}

.followup-head view text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.4;
  color: #7b8494;
}

.followup-head button,
.followup-head uni-button {
  width: 104rpx;
  height: 58rpx;
  flex: 0 0 auto;
  border-radius: 8rpx;
  background: #f6f8fb;
  color: #7b8494;
  font-size: 23rpx;
  font-weight: 780;
  white-space: nowrap;
}

.followup-head button::after,
.followup-head uni-button::after {
  display: none !important;
}

.followup-thread {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  margin-bottom: 18rpx;
}

.followup-item {
  padding: 18rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
}

.followup-item text:first-child {
  display: block;
  font-size: 26rpx;
  line-height: 1.45;
  font-weight: 820;
  color: #111827;
}

.followup-item text:last-child {
  display: block;
  margin-top: 10rpx;
  font-size: 26rpx;
  line-height: 1.55;
  color: #5f697a;
}

.followup-input {
  width: 100%;
  height: 156rpx;
  padding: 18rpx;
  border-radius: 8rpx;
  background: #f8fafc;
  font-size: 27rpx;
  line-height: 1.55;
  color: #111827;
}

.followup-send {
  width: 100%;
  min-height: 80rpx;
  margin-top: 16rpx;
  border-radius: 8rpx;
  background: #2563eb;
  color: #ffffff;
  font-size: 27rpx;
  font-weight: 820;
}

.followup-send::after,
.followup-send uni-button::after {
  display: none !important;
}

.result-actions-fixed {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 14rpx;
}

.result-actions-fixed button,
.result-actions-fixed uni-button {
  min-height: 88rpx;
  border-radius: 8rpx;
  background: #ffffff;
  color: #111827;
  font-size: 27rpx;
  font-weight: 700;
  box-shadow: 0 10rpx 26rpx rgba(15, 23, 42, 0.05);
}

.result-actions-fixed button.primary,
.result-actions-fixed uni-button.primary {
  background: #2563eb;
  color: #ffffff;
}

.bottom-tabs {
  position: fixed;
  left: 22rpx;
  right: 22rpx;
  bottom: calc(14rpx + constant(safe-area-inset-bottom));
  bottom: calc(14rpx + env(safe-area-inset-bottom));
  z-index: 30;
  height: 104rpx;
  padding: 8rpx;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 4rpx;
  border: 1rpx solid rgba(218, 223, 232, 0.84);
  border-radius: 8rpx;
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 18rpx 50rpx rgba(15, 23, 42, 0.12);
  backdrop-filter: blur(24rpx);
  -webkit-backdrop-filter: blur(24rpx);
}

.bottom-tabs button,
.bottom-tabs uni-button {
  min-width: 0;
  height: 88rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8rpx;
  background: transparent !important;
  transition: background-color 160ms ease, color 160ms ease, transform 160ms ease;
}

.bottom-tabs uni-button.button-hover,
.bottom-tabs button.button-hover {
  background: transparent !important;
}

.bottom-tabs button::after,
.bottom-tabs uni-button::after {
  display: none !important;
}

.tab-item {
  width: 100%;
  height: 88rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6rpx;
  border-radius: 8rpx;
  color: #8a92a3;
  font-size: 21rpx;
  font-weight: 700;
  transition: color 160ms ease, transform 160ms ease;
  background: transparent !important;
}

.tab-item.active {
  color: #2563eb;
  background: #eef4ff !important;
}

.tab-item text {
  line-height: 1;
}

.drawer-mask {
  position: fixed;
  inset: 0;
  z-index: 20;
  background: rgba(17, 24, 39, 0.45);
}

.type-drawer-mask {
  position: fixed;
  inset: 0;
  z-index: 70;
  background: rgba(17, 24, 39, 0.38);
  animation: mask-in 180ms ease-out both;
}

.type-drawer-mask.closing {
  pointer-events: none;
  animation: mask-out 160ms ease-in both;
}

.type-drawer {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 80;
  box-sizing: border-box;
  width: 100%;
  max-height: 72vh;
  max-height: 72dvh;
  padding: 16rpx 32rpx calc(28rpx + constant(safe-area-inset-bottom));
  padding: 16rpx 32rpx calc(28rpx + env(safe-area-inset-bottom));
  border-radius: 8rpx 8rpx 0 0;
  background: #ffffff;
  box-shadow: 0 -24rpx 60rpx rgba(15, 23, 42, 0.18);
  transform: translate3d(0, 0, 0);
  transform-origin: center bottom;
  backface-visibility: hidden;
  will-change: transform, opacity;
  animation: drawer-in 240ms cubic-bezier(0.22, 1, 0.36, 1) both;
}

.type-drawer.closing {
  pointer-events: none;
  animation: drawer-out 170ms cubic-bezier(0.4, 0, 1, 1) both;
}

.type-drawer-handle {
  width: 74rpx;
  height: 8rpx;
  margin: 0 auto 18rpx;
  border-radius: 999rpx;
  background: #d5dbe6;
}

.type-drawer-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20rpx;
  padding-bottom: 18rpx;
  border-bottom: 1rpx solid #edf1f6;
}

.type-drawer-head view {
  flex: 1;
  min-width: 0;
}

.type-drawer-head text:first-child {
  display: block;
  font-size: 34rpx;
  font-weight: 850;
  color: #111827;
}

.type-drawer-head text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.38;
  color: #7b8494;
}

.type-drawer-head button,
.type-drawer-head uni-button {
  width: 64rpx;
  height: 64rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
  border-radius: 50%;
  background: #f4f6fa;
}

.type-drawer-head button::after,
.type-drawer-head uni-button::after {
  display: none !important;
}

.type-drawer-list {
  height: 560rpx;
  max-height: 48vh;
  max-height: 48dvh;
  padding: 12rpx 0 6rpx;
}

.type-drawer-row {
  width: 100%;
  min-height: 108rpx;
  margin: 8rpx 0;
  padding: 0 18rpx 0 20rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18rpx;
  border-radius: 14rpx;
  background: #ffffff;
  border: 1rpx solid #edf1f6;
  text-align: left;
  transform: translate3d(0, 0, 0);
  transition: transform 140ms ease, background-color 180ms ease, border-color 180ms ease, box-shadow 180ms ease;
}

.type-drawer-row::after {
  display: none !important;
}

.type-drawer-row-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.type-drawer-row-main text:first-child {
  font-size: 29rpx;
  font-weight: 830;
  color: #111827;
}

.type-drawer-row-main text:last-child {
  margin-top: 8rpx;
  font-size: 24rpx;
  color: #8a92a3;
}

.type-drawer-row:active {
  transform: translate3d(0, 2rpx, 0);
  background: #f8fbff;
}

.type-drawer-row.active {
  background: linear-gradient(180deg, #f4f8ff 0%, #eef4ff 100%);
  border-color: #b8c9ff;
  box-shadow: 0 12rpx 26rpx rgba(37, 99, 235, 0.08);
}

.type-drawer-row.active .type-drawer-row-main text:first-child {
  color: #2563eb;
}

.type-drawer-check {
  width: 42rpx;
  height: 42rpx;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 999rpx;
  opacity: 0;
  transform: scale(0.82);
  transition: opacity 160ms ease, transform 160ms ease, background-color 160ms ease;
}

.type-drawer-check.active {
  opacity: 1;
  transform: scale(1);
  background: #2563eb;
  box-shadow: 0 8rpx 18rpx rgba(37, 99, 235, 0.18);
}

.export-sheet {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 82;
  max-height: 78vh;
  max-height: 78dvh;
  padding: 16rpx 32rpx calc(28rpx + constant(safe-area-inset-bottom));
  padding: 16rpx 32rpx calc(28rpx + env(safe-area-inset-bottom));
  border-radius: 8rpx 8rpx 0 0;
  background: #ffffff;
  box-shadow: 0 -24rpx 60rpx rgba(15, 23, 42, 0.18);
  animation: drawer-up 220ms ease-out;
}

.export-sheet-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20rpx;
  padding-bottom: 18rpx;
  border-bottom: 1rpx solid #edf1f6;
}

.export-sheet-head view {
  flex: 1;
  min-width: 0;
}

.export-sheet-head text:first-child {
  display: block;
  font-size: 34rpx;
  font-weight: 850;
  color: #111827;
}

.export-sheet-head text:last-child {
  display: block;
  margin-top: 8rpx;
  font-size: 24rpx;
  line-height: 1.38;
  color: #7b8494;
}

.export-sheet-head button,
.export-sheet-head uni-button {
  width: 64rpx;
  height: 64rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
  border-radius: 50%;
  background: #f4f6fa;
}

.export-sheet-head button::after,
.export-sheet-head uni-button::after {
  display: none !important;
}

.export-preview-text {
  width: 100%;
  height: 430rpx;
  margin-top: 18rpx;
  padding: 18rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  color: #4b5563;
  font-size: 24rpx;
  line-height: 1.55;
}

.export-sheet-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14rpx;
  margin-top: 18rpx;
}

.export-sheet-actions button,
.export-sheet-actions uni-button {
  min-height: 82rpx;
  border-radius: 8rpx;
  background: #eef4ff;
  color: #2563eb;
  font-size: 27rpx;
  font-weight: 820;
}

.export-sheet-actions button.primary,
.export-sheet-actions uni-button.primary {
  background: #2563eb;
  color: #ffffff;
}

.export-sheet-actions button::after,
.export-sheet-actions uni-button::after {
  display: none !important;
}

.processing-mask {
  position: fixed;
  inset: 0;
  z-index: 120;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 44rpx;
  background: rgba(15, 23, 42, 0.28);
  backdrop-filter: blur(10rpx);
  -webkit-backdrop-filter: blur(10rpx);
  animation: mask-fade 160ms ease-out;
}

.processing-card {
  width: 100%;
  max-width: 620rpx;
  padding: 34rpx;
  border-radius: 8rpx;
  background: #ffffff;
  box-shadow: 0 28rpx 80rpx rgba(15, 23, 42, 0.22);
  animation: processing-enter 180ms ease-out;
}

.processing-orbit {
  position: relative;
  width: 92rpx;
  height: 92rpx;
  margin: 0 auto 24rpx;
  border-radius: 50%;
  border: 2rpx solid #dbeafe;
}

.processing-orbit view:first-child {
  position: absolute;
  inset: 12rpx;
  border-radius: 50%;
  background: linear-gradient(135deg, #67d8ff, #2563eb);
  animation: processing-breathe 1100ms ease-in-out infinite;
}

.processing-orbit view:last-child {
  position: absolute;
  left: 50%;
  top: -5rpx;
  width: 14rpx;
  height: 14rpx;
  border-radius: 50%;
  background: #14b8a6;
  transform-origin: 0 51rpx;
  animation: processing-spin 1200ms linear infinite;
}

.processing-title {
  display: block;
  text-align: center;
  font-size: 34rpx;
  font-weight: 880;
  color: #111827;
}

.processing-desc {
  display: block;
  margin-top: 10rpx;
  text-align: center;
  font-size: 25rpx;
  line-height: 1.45;
  color: #6b7280;
}

.processing-progress {
  height: 10rpx;
  margin-top: 22rpx;
  border-radius: 999rpx;
  background: #e6ecf5;
  overflow: hidden;
}

.processing-progress view {
  height: 100%;
  min-width: 10rpx;
  border-radius: 999rpx;
  background: linear-gradient(90deg, #67d8ff, #2563eb);
  transition: width 180ms ease;
}

.processing-meta {
  display: block;
  margin-top: 10rpx;
  text-align: center;
  font-size: 22rpx;
  font-weight: 780;
  color: #2563eb;
}

.processing-steps {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  margin-top: 26rpx;
}

.processing-steps > view {
  min-height: 62rpx;
  padding: 0 14rpx;
  display: flex;
  align-items: center;
  gap: 14rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  color: #8a92a3;
}

.processing-steps > view > view {
  width: 36rpx;
  height: 36rpx;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: #e6ecf5;
  color: #7b8494;
  font-size: 20rpx;
  font-weight: 880;
}

.processing-steps > view text {
  font-size: 25rpx;
  font-weight: 780;
}

.processing-steps > view.active {
  background: #eef4ff;
  color: #2563eb;
}

.processing-steps > view.active > view {
  background: #2563eb;
  color: #ffffff;
}

.processing-steps > view.done {
  color: #16a34a;
}

.processing-steps > view.done > view {
  background: #dcfce7;
  color: #16a34a;
}

.history-drawer {
  width: 82vw;
  max-width: 680rpx;
  height: 100vh;
  height: 100dvh;
  padding: calc(28rpx + constant(safe-area-inset-top)) 28rpx calc(24rpx + constant(safe-area-inset-bottom));
  padding: calc(28rpx + env(safe-area-inset-top)) 28rpx calc(24rpx + env(safe-area-inset-bottom));
  display: flex;
  flex-direction: column;
  background: #ffffff;
}

.drawer-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 28rpx;
}

.drawer-title {
  display: block;
  font-size: 36rpx;
  font-weight: 800;
  color: #111827;
}

.drawer-subtitle {
  display: block;
  margin-top: 6rpx;
  font-size: 24rpx;
  color: #8a92a3;
}

.search-box {
  min-height: 88rpx;
  padding: 0 20rpx;
  display: flex;
  align-items: center;
  gap: 14rpx;
  border-radius: 8rpx;
  background: #f6f8fb;
  margin-bottom: 20rpx;
}

.search-box input {
  flex: 1;
  min-height: 88rpx;
  font-size: 27rpx;
}

.drawer-list {
  flex: 1;
  min-height: 0;
  height: auto;
}

.empty-small {
  padding: 34rpx 0;
  text-align: center;
  color: #a3a8b3;
  font-size: 26rpx;
}

.clear-history {
  width: 100%;
  min-height: 88rpx;
  border-radius: 8rpx;
  background: #fff1f2;
  color: #e11d48;
  font-size: 27rpx;
  font-weight: 700;
}

@media (min-width: 520px) {
  .app-shell {
    max-width: 430px;
    margin: 0 auto;
    box-shadow: 0 24px 80px rgba(15, 23, 42, 0.16);
  }

  .fixed-action,
  .result-actions-fixed,
  .drawer-mask,
  .type-drawer-mask,
  .bottom-tabs {
    left: 50%;
    right: auto;
    width: 430px;
    transform: translateX(-50%);
  }

  .type-drawer {
    left: calc(50% - 215px);
    right: auto;
    width: 430px;
  }

  .export-sheet {
    left: calc(50% - 215px);
    right: auto;
    width: 430px;
  }

  .bottom-tabs {
    width: 386px;
  }
}

@keyframes mask-fade {
  from {
    opacity: 0;
  }

  to {
    opacity: 1;
  }
}

@keyframes mask-in {
  from {
    opacity: 0;
  }

  to {
    opacity: 1;
  }
}

@keyframes mask-out {
  from {
    opacity: 1;
  }

  to {
    opacity: 0;
  }
}

@keyframes drawer-up {
  from {
    transform: translateY(42rpx);
  }

  to {
    transform: translateY(0);
  }
}

@keyframes drawer-in {
  from {
    opacity: 0.96;
    transform: translate3d(0, 44rpx, 0);
  }

  to {
    opacity: 1;
    transform: translate3d(0, 0, 0);
  }
}

@keyframes drawer-out {
  from {
    opacity: 1;
    transform: translate3d(0, 0, 0);
  }

  to {
    opacity: 0.98;
    transform: translate3d(0, 34rpx, 0);
  }
}

@keyframes screen-enter {
  from {
    opacity: 0.72;
    transform: translateY(10rpx);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes notice-rise {
  from {
    opacity: 0;
    transform: translateY(12rpx);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes pulse-ring {
  from {
    opacity: 0.9;
    transform: scale(0.72);
  }

  to {
    opacity: 0;
    transform: scale(1.55);
  }
}

@keyframes processing-enter {
  from {
    opacity: 0.76;
    transform: translateY(16rpx) scale(0.98);
  }

  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes processing-breathe {
  0%,
  100% {
    transform: scale(0.92);
    opacity: 0.82;
  }

  50% {
    transform: scale(1);
    opacity: 1;
  }
}

@keyframes processing-spin {
  from {
    transform: rotate(0deg);
  }

  to {
    transform: rotate(360deg);
  }
}

@keyframes thinking-dot {
  0%,
  80%,
  100% {
    transform: translateY(0);
    opacity: 0.34;
  }

  40% {
    transform: translateY(-5rpx);
    opacity: 1;
  }
}
</style>

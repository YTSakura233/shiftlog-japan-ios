const translations = {
  zh: {
    skip: "跳到主要内容", brand: "在日工作助手", menu: "打开菜单", navFeatures: "功能", navPrivacy: "隐私", navScreens: "界面", navDownload: "下载",
    eyebrow: "为在日本工作的你而做", heroTitle: "多份工作，<br>一本清楚的账。", heroLead: "把班次、工资和每周工时，安心放在一个地方。专为在日留学生与外国劳动者设计。",
    iosSmall: "iPhone 版", iosSoon: "即将上线", learnMore: "了解它能做什么", trustLocal: "数据本地保存", trustLanguages: "中・日・英三语", trustNoAccount: "无需注册账号",
    nextShift: "下一次班次", shiftExample: "便利店 · 周二 21:00", weekHours: "本周工时", heroFoot: "从下一次上班，到月底到账，都心里有数。",
    manifestoKicker: "为什么做它", manifestoTitle: "在异国生活已经够复杂。<br>工作记录不该也是。", manifestoBody: "一份在餐厅，一份在便利店；计划班次、实际工时、深夜加薪、交通费和到账金额常常散落各处。在日工作助手把这些信息放回你自己手里，用熟悉的语言，清楚地呈现。",
    featuresKicker: "核心功能", featuresTitle: "真正理解多份工作的管理方式", featuresIntro: "不只是记录时间，也帮你看懂收入、核对工资，并在接近自设工时上限时提前提醒。",
    f1Title: "所有班次，一眼看清", f1Body: "月、周、日、年视图自由切换，多份工作用颜色区分。跨日班次、重复排班和多段休息都能准确记录。",
    f2Title: "工资怎么算，明明白白", f2Body: "按日、周、月或工资周期估算，分开显示基本工资、深夜加成、交通费和扣减，再与工资单和实际到账核对。", estimated: "本月计划预计",
    f3Title: "工时上限，提前留意", f3Body: "把多份工作的工时合并计算，按你自己的许可条件设置每周上限、提醒阈值和连续 7 天辅助检查。", weekProgress: "本周进度", riskNote: "接近你设置的每周工时上限",
    f4Title: "重要资料，留在身边", f4Body: "工资单、合同和排班表可保存在 App 私有空间。设备端文字识别只生成草稿，不把文件发往服务器。",
    privacyKicker: "隐私，不是附加选项", privacyTitle: "你的工作与工资，<br>只属于你。", privacyBody: "默认不连接开发者服务器，不要求注册，不内置分析或追踪。班次、工资、证件提醒与资料优先保存在你的设备上。", privacyLink: "阅读隐私说明",
    p1Title: "本地优先", p1Body: "离线也能完整使用", p2Title: "无需账号", p2Body: "打开 App 就能开始", p3Title: "无行为追踪", p3Body: "不建立广告画像", p4Title: "可选隐私锁", p4Body: "Face ID 或设备密码保护",
    screensKicker: "真实 App 界面", screensTitle: "复杂的事，也可以很清楚", screensIntro: "沿用 iPhone 熟悉的交互方式，让信息密度与使用负担保持平衡。",
    screen1: "日历与下一班", screen2: "当天安排", screen3: "收入统计", screen4: "多工作管理", screen5: "工时与隐私设置", dragHint: "横向滑动查看更多 · 点击放大",
    languageKicker: "熟悉的语言，更少的误解", languageTitle: "中文 · 日本語 · English", languageBody: "从首次设置到工资单常见词汇，界面支持三种语言。你可以随时切换，不必重新开始。",
    downloadKicker: "开发进度", downloadTitle: "把每一份努力，认真记下来。", downloadBody: "iPhone 版正在为首次发布做准备。Android 版已列入正式开发计划。", iosPreparing: "首发准备中", soonBadge: "即将上线", androidDeveloping: "正在开发", planBadge: "开发计划",
    footerNote: "记录、估算与风险提醒工具，不构成法律、税务或行政建议。", footerPrivacy: "隐私说明", footerSupport: "支持与帮助", footerGithub: "GitHub", madeFor: "为在日本的生活与工作而做。"
  },
  ja: {
    skip: "メインコンテンツへ", brand: "バイトログ", menu: "メニューを開く", navFeatures: "機能", navPrivacy: "プライバシー", navScreens: "画面", navDownload: "ダウンロード",
    eyebrow: "日本で働くあなたのために", heroTitle: "複数の仕事を、<br>ひとつの見通しへ。", heroLead: "シフト、給与、週の労働時間を、安心してひとつの場所に。留学生と外国人労働者のために設計しました。",
    iosSmall: "iPhone 版", iosSoon: "近日公開", learnMore: "できることを見る", trustLocal: "データは端末に保存", trustLanguages: "中・日・英の3言語", trustNoAccount: "アカウント登録不要",
    nextShift: "次のシフト", shiftExample: "コンビニ · 火曜 21:00", weekHours: "今週の時間", heroFoot: "次のシフトから月末の入金まで、すっきり把握。",
    manifestoKicker: "つくった理由", manifestoTitle: "海外での暮らしは、もう十分複雑。<br>仕事の記録まで複雑にしない。", manifestoBody: "飲食店とコンビニ。予定、実績、深夜手当、交通費、振込額は別々になりがちです。バイトログはその情報をあなたの手元に戻し、慣れた言葉で分かりやすく整理します。",
    featuresKicker: "主な機能", featuresTitle: "複数の仕事を、本当に分かりやすく", featuresIntro: "時間の記録だけでなく、収入の把握、給与の照合、自分で設定した上限への接近も知らせます。",
    f1Title: "すべてのシフトを、ひと目で", f1Body: "月・週・日・年表示を切り替え、仕事ごとに色分け。日をまたぐシフト、繰り返し、複数の休憩も正確に記録できます。",
    f2Title: "給与の内訳を、明快に", f2Body: "日・週・月・給与期間で見積もり、基本給、深夜加算、交通費、控除を分けて表示。給与明細や入金額とも照合できます。", estimated: "今月の予定見込",
    f3Title: "上限に近づく前に気づく", f3Body: "複数の仕事の時間を合算し、自分の許可条件に合わせて週の上限、注意値、連続7日間の確認を設定できます。", weekProgress: "今週の進捗", riskNote: "設定した週の上限に近づいています",
    f4Title: "大切な書類を、手元に", f4Body: "給与明細、契約書、シフト表をアプリのプライベート領域に保存。端末内OCRは下書きだけを作り、サーバーへ送りません。",
    privacyKicker: "プライバシーは標準機能", privacyTitle: "仕事と給与の情報は、<br>あなただけのもの。", privacyBody: "開発者サーバーへの接続、登録、分析、追跡は標準でありません。シフト、給与、期限のリマインダー、書類は端末を優先して保存します。", privacyLink: "プライバシーについて",
    p1Title: "ローカル優先", p1Body: "オフラインでも使える", p2Title: "アカウント不要", p2Body: "すぐに始められる", p3Title: "行動追跡なし", p3Body: "広告プロファイルを作らない", p4Title: "任意のロック", p4Body: "Face ID／端末パスコード",
    screensKicker: "実際のアプリ画面", screensTitle: "複雑なことも、すっきりと", screensIntro: "iPhoneで慣れた操作を活かし、情報量と使いやすさのバランスを整えています。",
    screen1: "カレンダーと次のシフト", screen2: "一日の予定", screen3: "収入の集計", screen4: "複数の仕事", screen5: "時間とプライバシー", dragHint: "横にスワイプ · タップで拡大",
    languageKicker: "慣れた言葉で、誤解を減らす", languageTitle: "中文 · 日本語 · English", languageBody: "初期設定から給与明細の用語まで3言語に対応。いつでも切り替えられ、やり直す必要はありません。",
    downloadKicker: "開発状況", downloadTitle: "ひとつひとつの頑張りを、丁寧に記録。", downloadBody: "iPhone版は初回リリースに向けて準備中です。Android版も正式な開発計画に含まれています。", iosPreparing: "公開準備中", soonBadge: "近日公開", androidDeveloping: "開発中", planBadge: "開発予定",
    footerNote: "記録・見積もり・リスク通知のためのツールであり、法律・税務・行政上の助言ではありません。", footerPrivacy: "プライバシー", footerSupport: "サポート", footerGithub: "GitHub", madeFor: "日本での暮らしと仕事のために。"
  },
  en: {
    skip: "Skip to main content", brand: "ShiftLog Japan", menu: "Open menu", navFeatures: "Features", navPrivacy: "Privacy", navScreens: "Screens", navDownload: "Get the app",
    eyebrow: "Made for your working life in Japan", heroTitle: "More than one job.<br>One clear picture.", heroLead: "Keep shifts, pay, and weekly hours together with confidence. Designed for international students and foreign workers in Japan.",
    iosSmall: "For iPhone", iosSoon: "Coming soon", learnMore: "See what it can do", trustLocal: "Data stays local", trustLanguages: "Chinese · Japanese · English", trustNoAccount: "No account required",
    nextShift: "Next shift", shiftExample: "Convenience store · Tue 21:00", weekHours: "This week", heroFoot: "From your next shift to payday, know where you stand.",
    manifestoKicker: "Why we made it", manifestoTitle: "Life abroad is complex enough.<br>Tracking work shouldn't be.", manifestoBody: "A restaurant job, a convenience-store shift—planned hours, actual time, night premiums, transit costs, and deposits often live in different places. ShiftLog Japan puts that information back in your hands, clearly and in familiar language.",
    featuresKicker: "Core features", featuresTitle: "Built around the reality of multiple jobs", featuresIntro: "It goes beyond time tracking to explain earnings, reconcile pay, and warn you before you approach your own weekly limit.",
    f1Title: "Every shift at a glance", f1Body: "Switch between month, week, day, and year views, with a color for each job. Overnight shifts, repeats, and multiple breaks are all handled accurately.",
    f2Title: "Understand every yen", f2Body: "Estimate by day, week, month, or pay period. See base pay, night premiums, travel costs, and deductions separately, then compare against your payslip and deposit.", estimated: "Planned this month",
    f3Title: "See the limit before you reach it", f3Body: "Combine hours across all jobs and set weekly limits, warning thresholds, and a rolling seven-day check around your own permission conditions.", weekProgress: "This week", riskNote: "Approaching your weekly limit",
    f4Title: "Keep important documents close", f4Body: "Store payslips, contracts, and schedules in the app's private space. On-device text recognition creates drafts without sending files to a server.",
    privacyKicker: "Privacy is not an add-on", privacyTitle: "Your work and pay<br>belong to you.", privacyBody: "No developer server, sign-up, analytics, or tracking by default. Shifts, earnings, expiry reminders, and documents are stored on your device first.", privacyLink: "Read our privacy note",
    p1Title: "Local first", p1Body: "Works fully offline", p2Title: "No account", p2Body: "Open and get started", p3Title: "No tracking", p3Body: "No advertising profile", p4Title: "Optional privacy lock", p4Body: "Face ID or device passcode",
    screensKicker: "Real app screens", screensTitle: "Complex things, made clear", screensIntro: "Familiar iPhone patterns keep rich information easy to understand and comfortable to use.",
    screen1: "Calendar & next shift", screen2: "Day detail", screen3: "Earnings", screen4: "Multiple jobs", screen5: "Hours & privacy", dragHint: "Swipe for more · Tap to enlarge",
    languageKicker: "Familiar language, fewer misunderstandings", languageTitle: "中文 · 日本語 · English", languageBody: "From setup to common payslip terms, the interface supports three languages. Switch any time without starting over.",
    downloadKicker: "Development status", downloadTitle: "Give every hour of effort a clear record.", downloadBody: "The iPhone version is preparing for its first release. Android is officially on the product roadmap.", iosPreparing: "Preparing for launch", soonBadge: "Coming soon", androidDeveloping: "In development", planBadge: "On the roadmap",
    footerNote: "A tool for records, estimates, and risk reminders—not legal, tax, or administrative advice.", footerPrivacy: "Privacy", footerSupport: "Support", footerGithub: "GitHub", madeFor: "Made for life and work in Japan."
  }
};

const languageNames = { zh: "zh-CN", ja: "ja-JP", en: "en" };
const titleMap = { zh: "在日工作助手 · ShiftLog Japan", ja: "バイトログ · ShiftLog Japan", en: "ShiftLog Japan · Work and pay, clearly" };

function setLanguage(language) {
  const lang = translations[language] ? language : "zh";
  document.documentElement.lang = languageNames[lang];
  document.title = titleMap[lang];
  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const value = translations[lang][element.dataset.i18n];
    if (value !== undefined) element.innerHTML = value;
  });
  document.querySelectorAll("[data-lang]").forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.lang === lang));
  });
  try { localStorage.setItem("shiftlog-language", lang); } catch (_) {}
}

document.querySelectorAll("[data-lang]").forEach((button) => button.addEventListener("click", () => setLanguage(button.dataset.lang)));

let initialLanguage = "zh";
try {
  initialLanguage = localStorage.getItem("shiftlog-language") || (navigator.language.startsWith("ja") ? "ja" : navigator.language.startsWith("en") ? "en" : "zh");
} catch (_) {}
setLanguage(initialLanguage);

const header = document.querySelector("[data-header]");
const toggle = document.querySelector("[data-nav-toggle]");
const nav = document.querySelector("[data-nav]");
const closeNav = () => {
  nav?.classList.remove("is-open");
  toggle?.setAttribute("aria-expanded", "false");
  document.body.classList.remove("nav-open");
};

toggle?.addEventListener("click", () => {
  const open = toggle.getAttribute("aria-expanded") !== "true";
  toggle.setAttribute("aria-expanded", String(open));
  nav.classList.toggle("is-open", open);
  document.body.classList.toggle("nav-open", open);
});
nav?.querySelectorAll("a").forEach((link) => link.addEventListener("click", closeNav));
const updateHeader = () => header?.classList.toggle("scrolled", window.scrollY > 20);
updateHeader();
window.addEventListener("scroll", updateHeader, { passive: true });
window.addEventListener("resize", () => { if (window.innerWidth > 980) closeNav(); }, { passive: true });

const revealObserver = "IntersectionObserver" in window ? new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add("is-visible");
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.12 }) : null;
document.querySelectorAll(".reveal").forEach((element) => revealObserver ? revealObserver.observe(element) : element.classList.add("is-visible"));

const dialog = document.querySelector("[data-image-dialog]");
const dialogImage = dialog?.querySelector("img");
document.querySelectorAll("[data-image]").forEach((button) => button.addEventListener("click", () => {
  dialogImage.src = button.dataset.image;
  dialogImage.alt = button.dataset.alt || "App screenshot";
  dialog.showModal();
}));
document.querySelector("[data-dialog-close]")?.addEventListener("click", () => dialog.close());
dialog?.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });
document.querySelector("[data-year]").textContent = new Date().getFullYear();

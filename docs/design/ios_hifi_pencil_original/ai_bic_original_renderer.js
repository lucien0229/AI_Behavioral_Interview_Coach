/**
 * @schema 2.10
 * @input screen: string = "launch"
 */

const W = pencil.width;
const H = pencil.height;
const screen = String(pencil.input.screen || "launch");
let seq = 0;

const C = {
  canvas: "#F5F5F7",
  surface: "#FFFFFF",
  surfaceMuted: "#FAFAFC",
  text: "#1D1D1F",
  text80: "#4A4A4D",
  text48: "#7C7C80",
  line: "#D2D2D7",
  blue: "#0071E3",
  linkBlue: "#0066CC",
  dark: "#000000",
  darkPanel: "#272729",
  darkPanel2: "#2A2A2D",
  darkText: "#FFFFFF",
  darkMuted: "#B8B8BD",
  overlay: "#00000066",
  transparent: "#FFFFFF00",
};

function nextId(kind) {
  seq += 1;
  return `${screen}_${kind}_${seq}`;
}

function rect(x, y, width, height, fill, radius = 0, stroke) {
  const node = { id: nextId("rect"), type: "rectangle", x, y, width, height, fill, cornerRadius: radius };
  if (stroke) node.stroke = stroke;
  return node;
}

function line(x, y, width, fill = C.line) {
  return rect(x, y, width, 1, fill, 0);
}

function txt(x, y, width, content, size, weight = "400", fill = C.text, lineHeight = 1.2, align = "left") {
  return {
    id: nextId("text"),
    type: "text",
    x,
    y,
    width,
    textGrowth: "fixed-width",
    content,
    fontFamily: size >= 20 ? "SF Pro Display" : "SF Pro Text",
    fontSize: size,
    fontWeight: weight,
    letterSpacing: 0,
    lineHeight,
    textAlign: align,
    fill,
  };
}

function icon(x, y, name, fill = C.text, size = 22) {
  return {
    id: nextId("icon"),
    type: "icon_font",
    x,
    y,
    width: size,
    height: size,
    iconFontFamily: "lucide",
    iconFontName: name,
    weight: 500,
    fill,
  };
}

function frame(x, y, width, height, options = {}, children = []) {
  return {
    id: nextId("frame"),
    type: "frame",
    x,
    y,
    width,
    height,
    layout: options.layout || "none",
    gap: options.gap,
    padding: options.padding,
    justifyContent: options.justifyContent,
    alignItems: options.alignItems,
    fill: options.fill,
    cornerRadius: options.cornerRadius,
    stroke: options.stroke,
    clip: options.clip,
    children,
  };
}

function stroke(fill = C.line, thickness = 1) {
  return { align: "inside", thickness, fill };
}

function statusBar(dark = false) {
  const fill = dark ? C.darkText : C.text;
  return [
    txt(24, 15, 64, "9:41", 15, "600", fill, 1),
    icon(252, 14, "signal", fill, 15),
    icon(278, 14, "wifi", fill, 15),
    rect(306, 18, 17, 10, C.transparent, 2, { align: "inside", thickness: 1.3, fill }),
    rect(324, 21, 2, 4, fill, 1),
    rect(309, 21, 10, 4, fill, 1),
  ];
}

function homeIndicator(dark = false) {
  return rect(129, 834, 134, 5, dark ? "#FFFFFF66" : "#000000", 3);
}

function baseLight() {
  return [rect(0, 0, W, H, C.canvas), ...statusBar(false), homeIndicator(false)];
}

function baseDark() {
  return [rect(0, 0, W, H, C.dark), ...statusBar(true), homeIndicator(true)];
}

function nav(title, dark = false, rightIcon = null) {
  const fill = dark ? C.darkText : C.text;
  const nodes = [
    icon(18, 54, "chevron-left", fill, 24),
    txt(54, 56, 248, title, 17, "600", fill, 1.12),
  ];
  if (rightIcon) nodes.push(icon(350, 54, rightIcon, fill, 22));
  return nodes;
}

function header(subtitle = "Resume-grounded practice") {
  return [
    txt(24, 56, 280, "Interview Coach", 27, "700", C.text, 1.04),
    txt(24, 90, 270, subtitle, 14, "400", C.text48, 1.25),
    rect(337, 54, 36, 36, C.surface, 8, stroke(C.line)),
    icon(344, 61, "settings", C.text, 22),
  ];
}

function primaryButton(x, y, width, label, dark = false) {
  return frame(x, y, width, 50, {
    layout: "horizontal",
    justifyContent: "center",
    alignItems: "center",
    fill: dark ? C.darkText : C.blue,
    cornerRadius: 8,
    padding: [0, 16],
  }, [txt(0, 0, width - 32, label, 17, "500", dark ? C.dark : C.darkText, 1, "center")]);
}

function secondaryButton(x, y, width, label, dark = false, border = false) {
  return frame(x, y, width, 46, {
    layout: "horizontal",
    justifyContent: "center",
    alignItems: "center",
    fill: C.transparent,
    cornerRadius: 8,
    stroke: border ? stroke(dark ? "#FFFFFF55" : C.blue) : undefined,
    padding: [0, 6],
  }, [txt(0, 0, width - 12, label, 16, "500", dark ? "#2997FF" : C.linkBlue, 1, "center")]);
}

function recordingSecondaryButton(x, y, width, label) {
  return frame(x, y, width, 50, {
    layout: "horizontal",
    justifyContent: "center",
    alignItems: "center",
    fill: "#303033",
    cornerRadius: 8,
    stroke: stroke("#FFFFFF42"),
    padding: [0, 12],
  }, [txt(0, 0, width - 24, label, 16, "500", "#2997FF", 1, "center")]);
}

function row(x, y, width, title, detail, leading = null, trailing = true) {
  const nodes = [
    rect(x, y, width, 66, C.surface, 8, stroke(C.line)),
  ];
  const tx = leading ? x + 48 : x + 16;
  if (leading) icon(x + 16, y + 22, leading, C.text48, 20);
  if (leading) nodes.push(icon(x + 16, y + 22, leading, C.text48, 20));
  nodes.push(txt(tx, y + 13, width - (leading ? 92 : 62), title, 15, "500", C.text, 1.12));
  if (detail) nodes.push(txt(tx, y + 37, width - (leading ? 92 : 62), detail, 12, "400", C.text48, 1.15));
  if (trailing) nodes.push(icon(x + width - 34, y + 23, "chevron-right", C.text48, 18));
  return nodes;
}

function tag(x, y, label, selected = false, width = null, dark = false) {
  const w = width || Math.max(78, label.length * 7 + 22);
  return frame(x, y, w, 32, {
    layout: "horizontal",
    justifyContent: "center",
    alignItems: "center",
    fill: selected ? (dark ? C.darkText : C.surface) : (dark ? C.darkPanel : C.surfaceMuted),
    cornerRadius: 8,
    stroke: stroke(selected ? (dark ? C.darkText : C.blue) : (dark ? "#FFFFFF22" : C.line)),
  }, [txt(0, 0, w - 16, label, 12, "500", selected ? (dark ? C.dark : C.blue) : (dark ? C.darkText : C.text80), 1, "center")]);
}

function sectionTitle(x, y, label, dark = false) {
  return txt(x, y, 310, label, 13, "600", dark ? C.darkMuted : C.text48, 1.1);
}

function assessmentLine(y, label, status) {
  let fill = C.surfaceMuted;
  let textFill = C.text80;
  let border = C.line;
  if (status === "Strong") {
    fill = C.text;
    textFill = C.darkText;
    border = C.text;
  }
  if (status === "Weak") {
    fill = C.surface;
    textFill = C.text;
    border = C.line;
  }
  return [
    txt(24, y, 220, label, 14, "500", C.text, 1.1),
    frame(270, y - 7, 87, 28, {
      layout: "horizontal",
      justifyContent: "center",
      alignItems: "center",
      fill,
      cornerRadius: 6,
      stroke: stroke(border),
    }, [txt(0, 0, 75, status, 12, "600", textFill, 1, "center")]),
  ];
}

function recordingCard(y, label, state = "idle") {
  const buttonFill = state === "recording" ? C.darkText : C.blue;
  const iconFill = state === "recording" ? C.dark : C.darkText;
  const timer = state === "review" ? "01:42" : state === "recording" ? "00:38" : "00:00";
  const primaryLabel = state === "review" ? "Submit answer" : state === "recording" ? "Stop" : "Start recording";
  const secondaryLabel = state === "review" ? "Re-record" : "Back";
  return [
    frame(24, y, 345, 170, { fill: C.darkPanel, cornerRadius: 8, stroke: stroke("#FFFFFF22") }, []),
    txt(44, y + 20, 178, label, 14, "500", C.darkMuted, 1.18),
    txt(44, y + 58, 150, timer, 38, "700", C.darkText, 1),
    rect(281, y + 30, 64, 64, buttonFill, 32),
    icon(302, y + 51, state === "recording" ? "square" : "mic", iconFill, 22),
    primaryButton(44, y + 106, 184, primaryLabel, true),
    recordingSecondaryButton(240, y + 106, 109, secondaryLabel),
  ];
}

function launch() {
  return [
    ...baseDark(),
    txt(54, 346, 286, "Interview Coach", 34, "700", C.darkText, 1.05, "center"),
    txt(68, 398, 256, "Preparing your practice space", 17, "400", C.darkMuted, 1.35, "center"),
    rect(96, 480, 201, 5, "#FFFFFF28", 3),
    rect(96, 480, 86, 5, C.darkText, 3),
  ];
}

function homeNoResume() {
  return [
    ...baseLight(),
    ...header("Resume required to begin"),
    txt(24, 150, 328, "Upload your resume to start", 34, "700", C.text, 1.05),
    txt(24, 238, 318, "Your practice questions will be based on your real experience.", 17, "400", C.text80, 1.38),
    primaryButton(24, 306, 345, "Upload resume"),
    secondaryButton(24, 364, 345, "Privacy"),
    ...row(24, 452, 345, "Resume", "No active resume", "file-text", false),
    ...row(24, 530, 345, "Practice credits", "2 free rounds available", "circle-dollar-sign", false),
    ...row(24, 608, 345, "History", "Complete a round to see summaries", "clock", true),
  ];
}

function homeReady() {
  return [
    ...baseLight(),
    ...header("Your next round is ready"),
    txt(24, 146, 326, "Ready for a practice round", 34, "700", C.text, 1.05),
    txt(24, 232, 320, "One question, one follow-up, and focused feedback.", 17, "400", C.text80, 1.38),
    primaryButton(24, 302, 345, "Start training"),
    secondaryButton(24, 360, 345, "Choose focus"),
    ...row(24, 438, 345, "alex_pm_resume.pdf", "Ready · 3 anchor experiences", "file-check-2", true),
    tag(24, 518, "Ownership"),
    tag(112, 518, "Prioritization"),
    tag(226, 518, "Influence"),
    ...row(24, 570, 345, "Practice credits", "2 free rounds available", "circle-dollar-sign", false),
    ...row(24, 648, 345, "Last practice", "Prioritization · Redo skipped · Mixed", "message-square", true),
    ...row(24, 726, 345, "View all history", "Recent practice summaries", "clock", true),
  ];
}

function homeActive() {
  return [
    ...baseLight(),
    ...header("Continue where you left off"),
    tag(24, 142, "Active session", true, 124),
    txt(24, 190, 320, "Practice in progress", 34, "700", C.text, 1.05),
    txt(24, 276, 320, "Feedback is ready. Complete the redo step or skip it to finish.", 17, "400", C.text80, 1.38),
    primaryButton(24, 354, 345, "Continue session"),
    ...row(24, 442, 345, "Current step", "Redo available", "repeat-2", false),
    ...row(24, 520, 345, "Current focus", "Cross-functional Influence", "target", false),
    ...row(24, 598, 345, "Practice credits", "1 free round available", "circle-dollar-sign", false),
    ...row(24, 676, 345, "View all history", "Recent practice summaries", "clock", true),
  ];
}

function homeProcessing() {
  return [
    ...baseLight(),
    ...header("Resume preparation"),
    txt(24, 150, 320, "Reading your resume", 34, "700", C.text, 1.05),
    txt(24, 236, 320, "We'll let you know when personalized practice is ready.", 17, "400", C.text80, 1.38),
    primaryButton(24, 306, 345, "View status"),
    secondaryButton(24, 364, 345, "Cancel resume"),
    ...row(24, 452, 345, "alex_pm_resume.pdf", "Parsing · usually under a minute", "file-text", true),
    ...row(24, 530, 345, "Practice credits", "2 free rounds available", "circle-dollar-sign", false),
    ...row(24, 608, 345, "Last practice", "Available while resume is processing", "message-square", true),
  ];
}

function homeOutCredits() {
  return [
    ...baseLight(),
    ...header("Personalized practice is ready"),
    txt(24, 150, 320, "You're out of practice credits", 32, "700", C.text, 1.06),
    txt(24, 236, 320, "Buy a Sprint Pack to continue personalized practice.", 17, "400", C.text80, 1.38),
    primaryButton(24, 306, 345, "Buy Sprint Pack"),
    secondaryButton(24, 364, 345, "Restore purchase"),
    ...row(24, 452, 345, "alex_pm_resume.pdf", "Ready for practice", "file-check-2", true),
    ...row(24, 530, 345, "Available credits", "0 practice rounds remaining", "circle-dollar-sign", false),
    ...row(24, 608, 345, "View all history", "Recent practice summaries", "clock", true),
  ];
}

function resumeUpload() {
  return [
    ...baseLight(),
    ...nav("Upload resume"),
    txt(24, 112, 330, "Upload your resume", 30, "700", C.text, 1.06),
    txt(24, 154, 300, "PDF or DOCX, up to 5 MB", 17, "400", C.text80, 1.3),
    frame(24, 224, 345, 234, { fill: C.surface, cornerRadius: 8, stroke: { align: "inside", thickness: 1.4, dashPattern: [6, 5], fill: C.line } }, []),
    icon(174, 292, "file-up", C.text, 42),
    txt(58, 358, 276, "Choose a resume file", 22, "600", C.text, 1.1, "center"),
    txt(62, 392, 270, "English resumes work best in this version.", 14, "400", C.text48, 1.25, "center"),
    primaryButton(24, 498, 345, "Choose file"),
    frame(24, 594, 345, 98, { fill: C.surface, cornerRadius: 8, stroke: stroke(C.line) }, []),
    icon(44, 618, "shield-check", C.text48, 22),
    txt(78, 615, 254, "Your resume is used to make practice questions personal.", 14, "400", C.text80, 1.3),
    secondaryButton(24, 720, 345, "Privacy notice"),
  ];
}

function resumeReady() {
  return [
    ...baseLight(),
    ...nav("Resume"),
    txt(24, 108, 320, "Resume ready", 32, "700", C.text, 1.05),
    txt(24, 156, 320, "Product manager with launch, roadmap, and stakeholder alignment experience.", 17, "400", C.text80, 1.32),
    sectionTitle(24, 230, "Anchor experiences"),
    ...row(24, 258, 345, "3 recommended practice cues", "Prioritization, influence, ambiguity", "list-checks", false),
    sectionTitle(24, 354, "Strength signals"),
    tag(24, 384, "Ownership"),
    tag(126, 384, "Prioritization"),
    tag(250, 384, "Influence"),
    frame(24, 454, 345, 86, { fill: C.surface, cornerRadius: 8, stroke: stroke(C.line) }, []),
    icon(44, 480, "info", C.text48, 21),
    txt(78, 474, 254, "No raw resume text or source snippets are shown in this app surface.", 14, "400", C.text80, 1.28),
    primaryButton(24, 590, 345, "Start training"),
    secondaryButton(24, 650, 345, "Upload better resume", false, true),
    secondaryButton(24, 710, 345, "Delete resume"),
  ];
}

function resumeUnusable() {
  return [
    ...baseLight(),
    ...nav("Resume"),
    txt(24, 112, 326, "This resume needs more detail", 30, "700", C.text, 1.06),
    txt(24, 196, 320, "We couldn't find enough concrete experience to build useful practice.", 17, "400", C.text80, 1.36),
    frame(24, 292, 345, 118, { fill: C.surface, cornerRadius: 8, stroke: stroke(C.line) }, []),
    sectionTitle(44, 314, "What is missing"),
    txt(44, 344, 286, "Add ownership, decisions, constraints, results, or measurable outcomes for at least one role.", 15, "400", C.text, 1.28),
    primaryButton(24, 464, 345, "Upload another resume"),
    secondaryButton(24, 524, 345, "Delete resume"),
  ];
}

function focusPicker() {
  return [
    ...homeReady(),
    rect(0, 0, W, H, C.overlay),
    frame(0, 312, W, 540, { fill: C.surface, cornerRadius: [24, 24, 0, 0] }, []),
    rect(157, 326, 79, 5, C.line, 3),
    txt(24, 360, 320, "Choose a practice focus", 28, "700", C.text, 1.08),
    txt(24, 410, 320, "Pick one signal to guide the question, or start without a focus.", 15, "400", C.text80, 1.32),
    tag(24, 482, "Ownership", true, 160),
    tag(208, 482, "Prioritization", false, 160),
    tag(24, 530, "Cross-functional Influence", false, 344),
    tag(24, 578, "Conflict Handling", false, 160),
    tag(208, 578, "Failure / Learning", false, 160),
    tag(24, 626, "Ambiguity", false, 160),
    primaryButton(24, 704, 345, "Start training"),
    secondaryButton(24, 760, 345, "Start without a focus"),
  ];
}

function processing() {
  return [
    ...baseDark(),
    ...nav("Practice", true),
    rect(24, 112, 78, 4, C.darkText, 2),
    rect(112, 112, 78, 4, "#FFFFFF33", 2),
    rect(200, 112, 78, 4, "#FFFFFF33", 2),
    rect(288, 112, 78, 4, "#FFFFFF33", 2),
    txt(42, 292, 308, "Preparing your personalized question", 28, "700", C.darkText, 1.08, "center"),
    txt(58, 420, 276, "We're using your resume to choose a relevant prompt.", 17, "400", C.darkMuted, 1.38, "center"),
    rect(92, 536, 210, 5, "#FFFFFF24", 3),
    rect(92, 536, 84, 5, C.darkText, 3),
    frame(24, 626, 345, 82, { fill: C.darkPanel, cornerRadius: 8, stroke: stroke("#FFFFFF22") }, []),
    icon(44, 650, "clock", C.darkMuted, 21),
    txt(78, 642, 252, "This is taking longer than usual. You can come back later.", 14, "400", C.darkMuted, 1.3),
    secondaryButton(24, 724, 345, "Back home", true),
  ];
}

function firstAnswer() {
  return [
    ...baseDark(),
    ...nav("Question", true),
    tag(24, 116, "Ownership", false, 104, true),
    txt(24, 168, 320, "Based on your launch work,", 15, "400", C.darkMuted, 1.25),
    txt(24, 214, 332, "Tell me about a time you had to make a high-stakes prioritization decision with incomplete information.", 31, "700", C.darkText, 1.12),
    ...recordingCard(548, "Start when you're ready.", "idle"),
  ];
}

function firstAnswerReview() {
  return [
    ...baseDark(),
    ...nav("Question", true),
    tag(24, 116, "Ownership", false, 104, true),
    txt(24, 168, 320, "Based on your launch work,", 15, "400", C.darkMuted, 1.25),
    txt(24, 214, 332, "Tell me about a time you had to make a high-stakes prioritization decision with incomplete information.", 31, "700", C.darkText, 1.12),
    ...recordingCard(548, "Ready to submit", "review"),
  ];
}

function transcriptFailure() {
  return [
    ...baseDark(),
    ...nav("Question", true),
    tag(24, 116, "Ownership", false, 104, true),
    txt(24, 166, 330, "Tell me about a time you had to make a high-stakes prioritization decision with incomplete information.", 29, "700", C.darkText, 1.12),
    frame(24, 454, 345, 86, { fill: C.darkPanel, cornerRadius: 8, stroke: stroke("#FFFFFF22") }, []),
    icon(44, 480, "volume-x", C.darkMuted, 21),
    txt(78, 474, 250, "We couldn't hear enough audio. Record again when you're ready.", 14, "400", C.darkMuted, 1.3),
    ...recordingCard(572, "Record again", "idle"),
  ];
}

function followupAnswer() {
  return [
    ...baseDark(),
    ...nav("Follow-up", true),
    frame(24, 116, 345, 86, { fill: C.darkPanel, cornerRadius: 8, stroke: stroke("#FFFFFF22") }, []),
    sectionTitle(44, 136, "Original question", true),
    txt(44, 164, 286, "A prioritization decision with incomplete information", 15, "500", C.darkText, 1.2),
    txt(24, 258, 330, "What specific decision did you personally make at that point?", 34, "700", C.darkText, 1.1),
    ...recordingCard(548, "Answer the follow-up", "idle"),
  ];
}

function feedback() {
  return [
    ...baseLight(),
    ...nav("Feedback"),
    txt(24, 94, 320, "Biggest gap", 13, "600", C.text48, 1.1),
    txt(24, 120, 328, "You still did not make your personal ownership explicit enough.", 23, "700", C.text, 1.12),
    line(24, 204, 345),
    sectionTitle(24, 224, "Why it matters"),
    txt(24, 250, 330, "Interviewers must see what you personally decided or drove.", 15, "400", C.text, 1.28),
    sectionTitle(24, 334, "Redo priority"),
    txt(24, 360, 330, "Name your decision, tradeoff, and result before adding team context.", 15, "500", C.text, 1.25),
    sectionTitle(24, 432, "Redo outline"),
    txt(24, 458, 330, "1. Set context in one sentence.\n2. State the decision you owned.\n3. Explain the tradeoff.\n4. Close with the result.", 13, "400", C.text, 1.22),
    sectionTitle(24, 558, "Strongest signal"),
    txt(24, 584, 330, "You picked a relevant example with real business context.", 14, "500", C.text, 1.22),
    sectionTitle(24, 622, "Assessment"),
    ...assessmentLine(644, "Answered the question", "Strong"),
    ...assessmentLine(666, "Story fit", "Strong"),
    ...assessmentLine(688, "Personal ownership", "Weak"),
    ...assessmentLine(710, "Evidence and outcome", "Mixed"),
    ...assessmentLine(732, "Holds up under follow-up", "Weak"),
    frame(0, 766, W, 86, { fill: C.canvas }, []),
    primaryButton(24, 776, 214, "Redo this answer"),
    secondaryButton(248, 778, 121, "Skip redo"),
    homeIndicator(false),
  ];
}

function redoAnswer() {
  return [
    ...baseDark(),
    ...nav("Redo", true),
    txt(24, 112, 320, "Redo priority", 13, "600", C.darkMuted, 1.1),
    txt(24, 144, 330, "Focus on the decision you personally made.", 29, "700", C.darkText, 1.12),
    frame(24, 238, 345, 146, { fill: C.darkPanel, cornerRadius: 8, stroke: stroke("#FFFFFF22") }, []),
    sectionTitle(44, 260, "Outline", true),
    txt(44, 292, 284, "1. Context\n2. Your decision\n3. Tradeoff\n4. Result", 17, "500", C.darkText, 1.34),
    sectionTitle(24, 422, "Original question", true),
    txt(24, 454, 330, "Tell me about a high-stakes prioritization decision with incomplete information.", 17, "500", C.darkText, 1.3),
    ...recordingCard(582, "One guided redo", "idle"),
  ];
}

function completed() {
  return [
    ...baseLight(),
    ...nav("Result"),
    txt(24, 104, 320, "Practice complete", 31, "700", C.text, 1.05),
    sectionTitle(24, 166, "Redo review"),
    txt(24, 196, 210, "Partially improved", 24, "700", C.text, 1.1),
    txt(24, 244, 330, "Your decision was clearer and reduced the team-level vagueness.", 16, "400", C.text, 1.32),
    line(24, 314, 345),
    sectionTitle(24, 342, "Still missing"),
    txt(24, 372, 330, "The result needs one metric or business outcome to be fully convincing.", 17, "400", C.text, 1.32),
    sectionTitle(24, 472, "Next attempt"),
    txt(24, 502, 330, "Add one measurable outcome on the next practice round.", 17, "500", C.text, 1.32),
    frame(24, 610, 345, 92, { fill: C.surface, cornerRadius: 8, stroke: stroke(C.line) }, []),
    icon(44, 636, "check-circle-2", C.text48, 22),
    txt(78, 628, 252, "Your original feedback is saved in History.", 14, "400", C.text80, 1.3),
    primaryButton(24, 728, 345, "Start next"),
    secondaryButton(24, 786, 345, "Back home"),
  ];
}

function completedUnavailable() {
  return [
    ...baseLight(),
    ...nav("Result"),
    txt(24, 104, 320, "Practice complete", 31, "700", C.text, 1.05),
    frame(24, 164, 345, 104, { fill: C.surface, cornerRadius: 8, stroke: stroke(C.line) }, []),
    icon(44, 190, "info", C.text48, 22),
    txt(78, 184, 252, "Redo review is unavailable. Your original feedback is saved.", 14, "400", C.text80, 1.3),
    sectionTitle(24, 312, "Original feedback"),
    txt(24, 342, 330, "Biggest gap: personal ownership was not explicit enough. Redo priority: name your decision, tradeoff, and measurable result.", 17, "400", C.text, 1.32),
    primaryButton(24, 728, 345, "Start next"),
    secondaryButton(24, 786, 345, "Back home"),
  ];
}

function historyList() {
  return [
    ...baseLight(),
    ...nav("History"),
    txt(24, 110, 320, "Recent practice", 31, "700", C.text, 1.05),
    ...row(24, 170, 345, "Prioritization decision", "Apr 21 · Ownership · Partially improved", "message-square", true),
    ...row(24, 248, 345, "Conflict with a partner", "Apr 19 · Conflict Handling · Redo skipped", "message-square", true),
    ...row(24, 326, 345, "Failed launch learning", "Apr 17 · Failure / Learning · Mixed", "message-square", true),
    ...row(24, 404, 345, "Ambiguous roadmap call", "Apr 15 · Ambiguity · Strong", "message-square", true),
    primaryButton(24, 566, 345, "Start training"),
  ];
}

function historyDetail() {
  return [
    ...baseLight(),
    ...nav("Practice detail"),
    txt(24, 104, 330, "Prioritization decision", 27, "700", C.text, 1.05),
    txt(24, 144, 300, "Apr 21 · Ownership · Partially improved", 13, "400", C.text48, 1.2),
    sectionTitle(24, 200, "Question"),
    txt(24, 230, 330, "Tell me about a difficult prioritization decision with multiple stakeholders.", 17, "500", C.text, 1.3),
    sectionTitle(24, 324, "Follow-up"),
    txt(24, 354, 330, "What exactly did you personally decide?", 17, "500", C.text, 1.3),
    line(24, 426, 345),
    sectionTitle(24, 456, "Feedback"),
    txt(24, 486, 330, "Biggest gap: personal ownership was not explicit enough. Redo priority: decision, tradeoff, measurable result.", 16, "400", C.text, 1.32),
    sectionTitle(24, 610, "Redo review"),
    txt(24, 640, 330, "Partially improved. Still missing one concrete metric.", 16, "500", C.text, 1.32),
    secondaryButton(24, 744, 345, "Delete practice round"),
  ];
}

function paywall() {
  return [
    ...homeOutCredits(),
    rect(0, 0, W, H, C.overlay),
    frame(0, 292, W, 560, { fill: C.surface, cornerRadius: [24, 24, 0, 0] }, []),
    rect(157, 306, 79, 5, C.line, 3),
    icon(350, 330, "x", C.text48, 22),
    txt(24, 360, 320, "Continue personalized practice", 28, "700", C.text, 1.08),
    txt(24, 430, 320, "You have 0 practice credits.", 16, "400", C.text80, 1.3),
    frame(24, 492, 345, 132, { fill: C.surfaceMuted, cornerRadius: 8, stroke: stroke(C.line) }, []),
    txt(44, 518, 220, "Sprint Pack", 24, "700", C.text, 1.05),
    txt(44, 556, 260, "5 personalized practice rounds", 15, "400", C.text80, 1.3),
    tag(260, 528, "One-time", false, 86),
    primaryButton(24, 668, 345, "Buy Sprint Pack"),
    secondaryButton(24, 726, 345, "Restore purchase"),
    txt(44, 790, 304, "Purchases are verified with Apple before credits appear.", 12, "400", C.text48, 1.25, "center"),
  ];
}

function settings() {
  return [
    ...baseLight(),
    ...nav("Settings"),
    txt(24, 108, 320, "Data & privacy", 31, "700", C.text, 1.05),
    sectionTitle(24, 176, "Practice data"),
    ...row(24, 204, 345, "Manage resume", "alex_pm_resume.pdf", "file-text", true),
    ...row(24, 282, 345, "Restore purchase", "Refresh Sprint Pack credits", "refresh-ccw", true),
    sectionTitle(24, 388, "Privacy and deletion"),
    ...row(24, 416, 345, "Privacy notice", "How v1 uses training data", "shield", true),
    ...row(24, 494, 345, "Delete all app data", "Resume, audio, transcripts, feedback, history", "trash-2", true),
    sectionTitle(24, 634, "App version"),
    txt(24, 664, 280, "1.0.0 validation build", 15, "400", C.text48, 1.2),
  ];
}

function deleteSheet() {
  return [
    ...resumeReady(),
    rect(0, 0, W, H, C.overlay),
    frame(0, 352, W, 500, { fill: C.surface, cornerRadius: [24, 24, 0, 0] }, []),
    rect(157, 366, 79, 5, C.line, 3),
    txt(24, 404, 320, "Delete resume", 28, "700", C.text, 1.08),
    txt(24, 462, 320, "Your original resume will be removed. Choose what happens to linked practice content.", 16, "400", C.text80, 1.32),
    ...row(24, 552, 345, "Delete resume only", "Keep redacted history summaries", "file-x", true),
    ...row(24, 630, 345, "Delete resume and linked training", "Remove related practice content and audio", "trash-2", true),
    secondaryButton(24, 746, 345, "Cancel"),
  ];
}

function offline() {
  return [
    ...baseLight(),
    icon(180, 274, "wifi-off", C.text48, 36),
    txt(44, 370, 304, "You're offline", 31, "700", C.text, 1.06, "center"),
    txt(52, 432, 288, "You can view the latest saved state, but new actions need a connection.", 17, "400", C.text80, 1.36, "center"),
    primaryButton(54, 556, 285, "Retry"),
  ];
}

function privacy() {
  return [
    ...baseLight(),
    ...nav("Privacy"),
    txt(24, 108, 320, "Privacy notice", 31, "700", C.text, 1.05),
    sectionTitle(24, 176, "What we use"),
    txt(24, 206, 330, "Resume file, practice audio, transcripts, AI feedback, and purchase entitlement.", 17, "400", C.text, 1.32),
    line(24, 300, 345),
    sectionTitle(24, 330, "Why we use it"),
    txt(24, 360, 330, "To create resume-based practice and manage credits.", 17, "400", C.text, 1.32),
    line(24, 444, 345),
    sectionTitle(24, 474, "What we do not do in v1"),
    txt(24, 504, 330, "No public profile, no resume rewriting product, and no required account signup before practice.", 17, "400", C.text, 1.32),
    line(24, 622, 345),
    sectionTitle(24, 652, "Your controls"),
    txt(24, 682, 330, "Delete resume, delete a practice round, or delete all app data.", 17, "400", C.text, 1.32),
    primaryButton(24, 770, 345, "Manage data"),
  ];
}

function micPermission() {
  return [
    ...firstAnswer(),
    rect(0, 0, W, H, "#00000099"),
    frame(0, 430, W, 422, { fill: C.surface, cornerRadius: [24, 24, 0, 0] }, []),
    rect(157, 444, 79, 5, C.line, 3),
    icon(180, 504, "mic", C.text, 34),
    txt(24, 594, 345, "Allow microphone access", 28, "700", C.text, 1.08, "center"),
    txt(48, 654, 296, "Answer out loud for this version. Text input is not the main path.", 16, "400", C.text80, 1.32, "center"),
    primaryButton(24, 740, 345, "Continue"),
  ];
}

const screens = {
  launch,
  home_no_resume: homeNoResume,
  home_ready: homeReady,
  home_active: homeActive,
  home_processing: homeProcessing,
  home_out_credits: homeOutCredits,
  resume_upload: resumeUpload,
  resume_ready: resumeReady,
  resume_unusable: resumeUnusable,
  focus_picker: focusPicker,
  processing,
  first_answer: firstAnswer,
  first_answer_review: firstAnswerReview,
  transcript_failure: transcriptFailure,
  followup_answer: followupAnswer,
  feedback,
  redo_answer: redoAnswer,
  completed,
  completed_unavailable: completedUnavailable,
  history_list: historyList,
  history_detail: historyDetail,
  paywall,
  settings,
  delete_sheet: deleteSheet,
  offline,
  privacy,
  mic_permission: micPermission,
};

return (screens[screen] || launch)();

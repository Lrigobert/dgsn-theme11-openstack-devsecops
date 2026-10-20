// Convertit docs/rapport.md en docs/rapport.docx (docx-js). Usage : node md2docx.js <rapport.md> <figures> <sortie.docx>
// Gère : titres #..####, paragraphes, **gras**, `code`, [liens](url), listes - / 1., tableaux GFM, blocs ```,
// diagrammes ```mermaid (remplacés par figures/fig-N.png), séparateurs ---.
const fs = require("fs");
const path = require("path");
const d = require("docx");
const [, , MD, FIG, OUT] = process.argv;

const FONT = "Calibri", MONO = "Consolas";
const PAGE_W = 11906, MARGIN = 1134, CONTENT_W = PAGE_W - 2 * MARGIN;       // A4, marges 2 cm
const BORDER = { style: d.BorderStyle.SINGLE, size: 4, color: "B8C2CC" };

// --- Texte en ligne : **gras**, `code`, [texte](url)
function runs(text, base = {}) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|\*[^*\s][^*]*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))/g;
  let last = 0, m;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(new d.TextRun({ text: text.slice(last, m.index), font: FONT, ...base }));
    const t = m[0];
    if (t.startsWith("**")) out.push(new d.TextRun({ text: t.slice(2, -2), bold: true, font: FONT, ...base }));
    else if (t.startsWith("*")) out.push(new d.TextRun({ text: t.slice(1, -1), italics: true, font: FONT, ...base }));
    else if (t.startsWith("`")) out.push(new d.TextRun({ text: t.slice(1, -1), font: MONO, size: 19, color: "374151", ...base }));
    else {
      const [, label, url] = t.match(/\[([^\]]+)\]\(([^)]+)\)/);
      out.push(/^https?:/.test(url)
        ? new d.ExternalHyperlink({ link: url, children: [new d.TextRun({ text: label, style: "Hyperlink", font: FONT, ...base })] })
        : new d.TextRun({ text: label, font: FONT, ...base }));
    }
    last = m.index + t.length;
  }
  if (last < text.length) out.push(new d.TextRun({ text: text.slice(last), font: FONT, ...base }));
  return out;
}

function table(lines) {
  const rows = lines.filter((l, i) => i !== 1).map(l => l.trim().replace(/^\||\|$/g, "").split("|").map(c => c.trim()));
  const n = rows[0].length;
  // Largeurs proportionnelles à la longueur max du contenu (bornées), en DXA, somme = largeur utile
  const len = Array.from({ length: n }, (_, j) => Math.min(Math.max(...rows.map(r => (r[j] || "").length), 4), 60));
  const tot = len.reduce((a, b) => a + b, 0);
  const widths = len.map(l => Math.floor(CONTENT_W * l / tot));
  widths[n - 1] += CONTENT_W - widths.reduce((a, b) => a + b, 0);
  return new d.Table({
    width: { size: CONTENT_W, type: d.WidthType.DXA },
    columnWidths: widths,
    rows: rows.map((r, i) => new d.TableRow({
      tableHeader: i === 0,
      children: Array.from({ length: n }, (_, j) => new d.TableCell({
        width: { size: widths[j], type: d.WidthType.DXA },
        borders: { top: BORDER, bottom: BORDER, left: BORDER, right: BORDER },
        shading: i === 0 ? { type: d.ShadingType.CLEAR, color: "auto", fill: "1F3A5F" } : (i % 2 === 0 ? { type: d.ShadingType.CLEAR, color: "auto", fill: "F3F6F9" } : undefined),
        margins: { top: 60, bottom: 60, left: 90, right: 90 },
        children: [new d.Paragraph({ spacing: { before: 0, after: 0 }, children: runs(r[j] || "", i === 0 ? { bold: true, color: "FFFFFF", size: 19 } : { size: 19 }) })],
      })),
    })),
  });
}

function image(n) {
  const f = path.join(FIG, `fig-${n}.png`);
  const buf = fs.readFileSync(f);
  // dimensions PNG (IHDR) ; captures faites à l'échelle ×2 -> taille naturelle = moitié
  const w = buf.readUInt32BE(16) / 2, h = buf.readUInt32BE(20) / 2;
  const maxW = 620, scale = Math.min(1, maxW / w);
  return new d.Paragraph({
    alignment: d.AlignmentType.CENTER, spacing: { before: 120, after: 60 },
    children: [new d.ImageRun({ type: "png", data: buf, transformation: { width: Math.round(w * scale), height: Math.round(h * scale) } })],
  });
}

// --- Analyse du Markdown
const src = fs.readFileSync(MD, "utf8").replace(/\r/g, "").split("\n");
const body = [];
let i = 0, fig = 0, title = "", subtitle = [], numInstance = 0, lastWasNum = false;
const H = { 1: d.HeadingLevel.HEADING_1, 2: d.HeadingLevel.HEADING_1, 3: d.HeadingLevel.HEADING_2, 4: d.HeadingLevel.HEADING_3 };
while (i < src.length) {
  const l = src[i];
  if (l.trim() && !/^\s*\d+\. /.test(l)) lastWasNum = false;               // toute autre ligne clôt une liste numérotée
  if (!title && l.startsWith("# ")) { title = l.slice(2); i++; continue; }
  if (/^## Sommaire/.test(l)) { while (i + 1 < src.length && !/^---\s*$/.test(src[i + 1]) && !/^## /.test(src[i + 1])) i++; i++; continue; } // remplacé par la TDM
  if (!body.length && title && /^\*\*.*\*\*$|^Date/.test(l.trim())) { subtitle.push(l.replace(/\*\*/g, "").trim()); i++; continue; }
  if (/^```mermaid/.test(l)) { fig++; while (!/^```\s*$/.test(src[++i])); body.push(image(fig)); body.push(new d.Paragraph({ alignment: d.AlignmentType.CENTER, spacing: { after: 200 }, children: [new d.TextRun({ text: `Figure ${fig}`, italics: true, size: 18, color: "6B7280", font: FONT })] })); i++; continue; }
  if (/^```/.test(l)) {
    const code = []; while (!/^```\s*$/.test(src[++i])) code.push(src[i]); i++;
    code.forEach(c => body.push(new d.Paragraph({ spacing: { before: 0, after: 0 }, shading: { type: d.ShadingType.CLEAR, color: "auto", fill: "F3F4F6" }, children: [new d.TextRun({ text: c || " ", font: MONO, size: 18 })] })));
    body.push(new d.Paragraph({ spacing: { after: 120 }, children: [] }));
    continue;
  }
  const h = l.match(/^(#{1,4}) (.*)/);
  if (h) {
    const lvl = h[1].length;
    if (lvl <= 2 && body.length) body.push(new d.Paragraph({ children: [new d.PageBreak()] }));
    body.push(new d.Paragraph({ heading: H[lvl], children: runs(h[2]) }));
    i++; continue;
  }
  if (/^\|/.test(l)) { const t = []; while (i < src.length && /^\|/.test(src[i])) t.push(src[i++]); body.push(table(t)); body.push(new d.Paragraph({ spacing: { after: 120 }, children: [] })); continue; }
  if (/^---\s*$/.test(l)) { i++; continue; }
  // Lignes de continuation d'un élément de liste : indentées, non vides, pas un nouvel élément
  const cont = (txt) => { i++; while (i < src.length && /^\s+\S/.test(src[i]) && !/^\s*([-*]|\d+\.) /.test(src[i]) && !/^\s*```/.test(src[i])) txt += " " + src[i++].trim(); return txt; };
  const b = l.match(/^(\s*)[-*] (.*)/);
  if (b) { const lvl = Math.min(Math.floor(b[1].length / 2), 2); body.push(new d.Paragraph({ numbering: { reference: "puces", level: lvl }, spacing: { after: 40 }, children: runs(cont(b[2])) })); continue; }
  const o = l.match(/^(\s*)\d+\. (.*)/);
  if (o) {
    if (!lastWasNum) numInstance++;                                          // nouvelle liste -> renumérotation à 1
    body.push(new d.Paragraph({ numbering: { reference: "numeros", level: 0, instance: numInstance }, spacing: { after: 40 }, children: runs(cont(o[2])) }));
    lastWasNum = true; continue;
  }
  if (/^<!--/.test(l.trim()) || !l.trim()) { i++; continue; }
  // Paragraphe : lignes consécutives fusionnées
  const p = [l.trim()]; i++;
  while (i < src.length && src[i].trim() && !/^(#|\||```|\s*[-*] |\s*\d+\. |---)/.test(src[i])) p.push(src[i++].trim());
  body.push(new d.Paragraph({ spacing: { after: 120 }, alignment: d.AlignmentType.JUSTIFIED, children: runs(p.join(" ")) }));
}

const cover = [
  new d.Paragraph({ spacing: { before: 2400, after: 240 }, children: [new d.TextRun({ text: "Direction Générale de la Sûreté Nationale — Thème 11", size: 24, color: "6B7280", font: FONT })] }),
  new d.Paragraph({ spacing: { after: 360 }, border: { bottom: { style: d.BorderStyle.SINGLE, size: 12, color: "1F3A5F", space: 8 } }, children: [new d.TextRun({ text: title, bold: true, size: 48, color: "1F3A5F", font: FONT })] }),
  ...subtitle.map(s => new d.Paragraph({ spacing: { after: 120 }, children: [new d.TextRun({ text: s, size: 26, font: FONT })] })),
  new d.Paragraph({ spacing: { before: 600 }, children: [new d.TextRun({ text: "OpenStack 2025.1 · Kolla-Ansible · Terraform · Ansible · GitLab CI · Vault · Prometheus/Grafana · OpenSCAP · k3s", size: 20, color: "374151", font: FONT })] }),
  new d.Paragraph({ children: [new d.PageBreak()] }),
  new d.Paragraph({ heading: d.HeadingLevel.HEADING_1, children: [new d.TextRun("Sommaire")] }),
  new d.TableOfContents("Sommaire", { hyperlink: true, headingStyleRange: "1-2" }),
  new d.Paragraph({ children: [new d.TextRun({ text: "(Si le sommaire est vide : clic droit → Mettre à jour les champs.)", italics: true, size: 18, color: "6B7280" })] }),
];

const doc = new d.Document({
  creator: "Projet Thème 11 DGSN", title, description: "Rapport de réalisation et de tests",
  features: { updateFields: true },
  styles: {
    default: { document: { run: { font: FONT, size: 21 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 32, bold: true, color: "1F3A5F", font: FONT }, paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 26, bold: true, color: "2C5282", font: FONT }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true, run: { size: 22, bold: true, color: "374151", font: FONT }, paragraph: { spacing: { before: 180, after: 80 }, outlineLevel: 2 } },
    ],
  },
  numbering: { config: [
    { reference: "puces", levels: [0, 1, 2].map(lv => ({ level: lv, format: d.LevelFormat.BULLET, text: ["•", "◦", "▪"][lv], alignment: d.AlignmentType.LEFT, style: { paragraph: { indent: { left: 360 * (lv + 1), hanging: 260 } } } })) },
    { reference: "numeros", levels: [{ level: 0, format: d.LevelFormat.DECIMAL, text: "%1.", alignment: d.AlignmentType.LEFT, style: { paragraph: { indent: { left: 360, hanging: 260 } } } }] },
  ] },
  sections: [{
    properties: { page: { size: { width: PAGE_W, height: 16838 }, margin: { top: MARGIN, bottom: MARGIN, left: MARGIN, right: MARGIN } } },
    headers: { default: new d.Header({ children: [new d.Paragraph({ alignment: d.AlignmentType.RIGHT, children: [new d.TextRun({ text: "Thème 11 — Cloud privé OpenStack + DevSecOps — DGSN", size: 16, color: "9CA3AF" })] })] }) },
    footers: { default: new d.Footer({ children: [new d.Paragraph({ alignment: d.AlignmentType.CENTER, children: [new d.TextRun({ children: ["Page ", d.PageNumber.CURRENT, " / ", d.PageNumber.TOTAL_PAGES], size: 16, color: "6B7280" })] })] }) },
    children: [...cover, ...body],
  }],
});
d.Packer.toBuffer(doc).then(buf => { fs.writeFileSync(OUT, buf); console.log(`${OUT} : ${buf.length} octets, ${fig} figures, ${body.length} blocs`); });

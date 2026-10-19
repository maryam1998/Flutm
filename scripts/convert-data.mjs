// scripts/convert-data.mjs
//
// این اسکریپت فایل‌های .js پروژه‌ی React را به JSON تبدیل می‌کند
// تا Flutter بتواند از assets بخواند.
//
// اجرا: node scripts/convert-data.mjs
// ورودی: hope-data/*.js  (فایل‌های خام پروژه‌ی Hope)
// خروجی: assets/data/*.json

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

const ROOT = process.cwd();
const INPUT_DIR = join(ROOT, 'hope_data');
const OUTPUT_DIR = join(ROOT, 'assets', 'data');

if (!existsSync(OUTPUT_DIR)) mkdirSync(OUTPUT_DIR, { recursive: true });

/// یک فایل .js با ساختار `export const NAME = [...]` را می‌خواند
/// و آرایه‌ی خالص برمی‌گرداند.
function parseExportArray(filePath, exportName) {
  const src = readFileSync(filePath, 'utf8');
  const startRe = new RegExp(`export\\s+const\\s+${exportName}\\s*=\\s*\\[`);
  const sm = startRe.exec(src);
  if (!sm) throw new Error(`Could not find ${exportName} in ${filePath}`);
  const arrStart = sm.index + sm[0].length - 1; // محل '['
  // پایانِ آرایه: اولین «]» که در ابتدای خط و با «;» آمده (امن برای آرایه‌های تودرتو)
  const endRe = /\n\];/g;
  endRe.lastIndex = arrStart;
  const em = endRe.exec(src);
  if (!em) throw new Error(`Could not find end of ${exportName} in ${filePath}`);
  const text = src.slice(arrStart, em.index + 2); // تا و با «]»
  // ارزیابی امن — داده‌ی ثابت است، نه کد اجرایی
  return Function(`"use strict"; return (${text});`)();
}

function writeJson(name, data) {
  const out = join(OUTPUT_DIR, name);
  writeFileSync(out, JSON.stringify(data), 'utf8');
  const sizeKb = (Buffer.byteLength(JSON.stringify(data)) / 1024).toFixed(1);
  console.log(`✓ ${name}  (${sizeKb} KB)`);
}

// ═══════════════════════════════════════════════════════════════════
// DAILY_CONVERSATIONS + THEMATIC_CONVERSATIONS
// ═══════════════════════════════════════════════════════════════════
try {
  const dailyPath = join(INPUT_DIR, 'DAILY_CONVERSATIONS.js');
  const daily = parseExportArray(dailyPath, 'DAILY_CONVERSATIONS');
  const thematic = parseExportArray(dailyPath, 'THEMATIC_CONVERSATIONS');
  writeJson('daily_conversations.json', daily);
  writeJson('thematic_conversations.json', thematic);
} catch (e) {
  console.warn('⚠ daily conversations skipped:', e.message);
}

// ═══════════════════════════════════════════════════════════════════
// DAILY_WORDS
// ═══════════════════════════════════════════════════════════════════
try {
  const wordsPath = join(INPUT_DIR, 'DAILY_WORDS.js');
  const words = parseExportArray(wordsPath, 'DAILY_WORDS');
  writeJson('daily_words.json', words);
} catch (e) {
  console.warn('⚠ daily words skipped:', e.message);
}

// ═══════════════════════════════════════════════════════════════════
// SLANG_WORDS  (تب اصطلاحات عامیانه)
// ═══════════════════════════════════════════════════════════════════
try {
  const slang = parseExportArray(join(INPUT_DIR, 'SLANG_WORDS.js'), 'SLANG_WORDS');
  writeJson('slang_words.json', slang.map((w) => ({
    id: w.id, level: w.level, pos: w.pos || 'slang', en: w.en, fa: w.fa,
  })));
} catch (e) {
  console.warn('⚠ slang words skipped:', e.message);
}

// ═══════════════════════════════════════════════════════════════════
// VOCAB_IN_USE_UNITS → لیستِ تخت (مثل VOCAB_IN_USE_WORDS در dataPools.js)
// ═══════════════════════════════════════════════════════════════════
const LEVEL_TO_CEFR = {
  elementary: 'A2', 'pre-intermediate': 'A2', preintermediate: 'A2',
  intermediate: 'B1', 'upper-intermediate': 'B2', upperintermediate: 'B2',
  advanced: 'C1', proficiency: 'C2',
};
function normLevel(raw) {
  if (!raw) return 'B1';
  const key = String(raw).trim().toLowerCase();
  if (/^[abc][12]$/.test(key)) return key.toUpperCase();
  return LEVEL_TO_CEFR[key] || 'B1';
}
try {
  const units = parseExportArray(
    join(INPUT_DIR, 'vocabularyInUseData.js'), 'VOCAB_IN_USE_UNITS');
  let n = 0;
  const flat = [];
  for (const unit of units) {
    for (const w of unit.words || []) {
      flat.push({
        id: 200000 + n++,
        level: normLevel(unit.level),
        pos: 'other',
        en: w.en,
        fa: w.fa,
        example: w.example || '',
        collocation: w.collocation || '',
        category: unit.topicFa || unit.topic || '',
      });
    }
  }
  writeJson('vocab_in_use_words.json', flat);
} catch (e) {
  console.warn('⚠ vocab in use skipped:', e.message);
}

console.log('\n✅ Done — output in assets/data/');

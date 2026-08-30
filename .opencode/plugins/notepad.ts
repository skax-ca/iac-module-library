import { type Plugin, tool } from "@opencode-ai/plugin"
import { readFile, writeFile, mkdir } from "node:fs/promises"
import { join, dirname } from "node:path"

// 2026-08-30: MANUAL은 별도 파일(.omc/notepad-manual.md)로 분리됐다(Claude Code 세션에서
// notepad.md가 pre-commit 150KB 경고에 상시 걸려 실행). notepad.md 안의 "## MANUAL"은 그
// 파일을 가리키는 포인터 한 줄만 유지한다 — 이 배열엔 그대로 남겨 splitSections/rebuild가
// Working Memory 경계와 포인터 라인을 계속 정확히 인식·보존하게 하되, notepad_read/
// notepad_write_manual은 아래에서 이 배열을 거치지 않고 별도 파일을 직접 다룬다.
const SECTIONS = ["Priority Context", "Working Memory", "MANUAL"] as const
type Section = (typeof SECTIONS)[number]

const DEFAULT_CONTENT = `# Notepad — iac-module-library

## Priority Context

## Working Memory

## MANUAL

.omc/notepad-manual.md 참조 — 별도 파일로 분리됨(2026-08-30), 자동 로드 안 됨.
`

const DEFAULT_MANUAL = `# Notepad MANUAL Archive — iac-module-library

> 자동 로드되지 않는 영구 보관 아카이브. 필요할 때만 조회한다.
`

const notepadPath = (directory: string) => join(directory, ".omc", "notepad.md")
const manualPath = (directory: string) => join(directory, ".omc", "notepad-manual.md")

async function loadFile(file: string, fallback: string): Promise<string> {
  try {
    return await readFile(file, "utf8")
  } catch {
    return fallback
  }
}

async function saveFile(file: string, text: string): Promise<void> {
  await mkdir(dirname(file), { recursive: true })
  await writeFile(file, text, "utf8")
}

function splitSections(text: string): Map<Section, string> {
  const map = new Map<Section, string>()
  let current: Section | null = null
  const buf: string[] = []
  const flush = () => {
    if (current) map.set(current, buf.join("\n"))
    buf.length = 0
  }
  for (const line of text.split("\n")) {
    const m = line.match(/^## (.+)$/)
    if (m) {
      flush()
      current = (SECTIONS as readonly string[]).includes(m[1]) ? (m[1] as Section) : null
      continue
    }
    if (current) buf.push(line)
  }
  flush()
  return map
}

function rebuild(text: string, sections: Map<Section, string>): string {
  const head = text.split("\n").find((l) => l.startsWith("# Notepad")) ?? "# Notepad — iac-module-library"
  const out = [head, ""]
  for (const s of SECTIONS) {
    out.push(`## ${s}`, "", (sections.get(s) ?? "").trim(), "")
  }
  return out.join("\n").replace(/\n+$/, "\n") + "\n"
}

function nowStamp(): string {
  const d = new Date()
  const p = (n: number) => String(n).padStart(2, "0")
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}

const NOTEPAD_DIRECT_EDIT_TOOLS = new Set(["edit", "write", "apply_patch"])

export const NotepadPlugin: Plugin = async ({ directory }) => {
  const file = notepadPath(directory)
  const manualFile = manualPath(directory)

  return {
    tool: {
      notepad_read: tool({
        description:
          "priority(우선순위 포인터, .omc/notepad.md) | working(최근 7일 세션 서술, .omc/notepad.md) | manual(영구 아카이브, .omc/notepad-manual.md — 2026-08-30 별도 파일로 분리) 중 하나를 읽는다.",
        args: { section: tool.schema.string() },
        async execute(args) {
          const section = (args.section as string).toLowerCase()

          if (section.startsWith("man")) {
            const text = await loadFile(manualFile, DEFAULT_MANUAL)
            return text.trim() || "[manual 아카이브 비어 있음]"
          }

          const key = SECTIONS.filter((s) => s !== "MANUAL").find(
            (s) => s.toLowerCase().startsWith(section) || section.startsWith(s.toLowerCase().slice(0, 4)),
          )
          if (!key) {
            throw new Error(`알 수 없는 section: ${args.section} — priority | working | manual 중 하나`)
          }
          const text = await loadFile(file, DEFAULT_CONTENT)
          const sections = splitSections(text)
          return sections.get(key)?.trim() || `[${key} 섹션 비어 있음]`
        },
      }),

      notepad_write_priority: tool({
        description:
          ".omc/notepad.md의 Priority Context를 전체 교체한다(append 아님). 내용은 500자 이내로 유지한다. 이 repo의 SSOT 포인터·미결 항목 요약만 담는다.",
        args: { content: tool.schema.string() },
        async execute(args) {
          const content = (args.content as string).trim()
          if (content.length > 500) {
            throw new Error(`Priority Context가 ${content.length}자로 500자 초과 — 500자 이내로 줄여 다시 제출`)
          }
          const text = await loadFile(file, DEFAULT_CONTENT)
          const sections = splitSections(text)
          sections.set("Priority Context", content)
          await saveFile(file, rebuild(text, sections))
          return `Priority Context 교체 완료 (${content.length}자)`
        },
      }),

      notepad_write_working: tool({
        description:
          ".omc/notepad.md의 Working Memory에 세션 서술 항목을 추가한다(prepend). 날짜 스탬프가 자동 붙는다. 7일 지난 항목은 수동 정리가 대상이다.",
        args: { content: tool.schema.string() },
        async execute(args) {
          const content = (args.content as string).trim()
          if (!content) throw new Error("content가 비어 있음")
          const entry = `### ${nowStamp()}\n${content}`
          const text = await loadFile(file, DEFAULT_CONTENT)
          const sections = splitSections(text)
          const current = sections.get("Working Memory") ?? ""
          sections.set("Working Memory", current ? `${entry}\n\n${current}` : entry)
          await saveFile(file, rebuild(text, sections))
          return `Working Memory에 항목 추가 완료 (${nowStamp()})`
        },
      }),

      notepad_write_manual: tool({
        description:
          ".omc/notepad-manual.md(영구 아카이브, 별도 파일 — 2026-08-30 분리)에 항목을 추가한다(append). 제목과 본문을 받는다. notepad.md의 MANUAL 섹션은 건드리지 않는다(포인터만 유지).",
        args: {
          title: tool.schema.string(),
          content: tool.schema.string(),
        },
        async execute(args) {
          const title = (args.title as string).trim()
          const content = (args.content as string).trim()
          if (!title || !content) throw new Error("title과 content 둘 다 필요")
          const entry = `### ${title} (${nowStamp()})\n${content}`
          const text = await loadFile(manualFile, DEFAULT_MANUAL)
          const trimmed = text.trim()
          const updated = trimmed ? `${trimmed}\n\n${entry}\n` : `${DEFAULT_MANUAL.trim()}\n\n${entry}\n`
          await saveFile(manualFile, updated)
          return `MANUAL 아카이브(.omc/notepad-manual.md)에 항목 추가 완료 (${title})`
        },
      }),
    },

    "tool.execute.before": async (input, output) => {
      const t = input.tool
      if (!NOTEPAD_DIRECT_EDIT_TOOLS.has(t)) return
      const args = output?.args ?? {}
      const fp = (args.filePath ?? args.path ?? "").replace(/\\/g, "/") as string
      if (fp.endsWith(".omc/notepad.md")) {
        throw new Error(
          "notepad.md 직접 편집 금지 — notepad_read / notepad_write_priority / notepad_write_working / notepad_write_manual 툴을 사용할 것",
        )
      }
      if (fp.endsWith(".omc/notepad-manual.md")) {
        throw new Error("notepad-manual.md 직접 편집 금지 — notepad_read(section=manual) / notepad_write_manual 툴을 사용할 것")
      }
    },
  }
}

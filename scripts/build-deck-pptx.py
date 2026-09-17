#!/usr/bin/env python3
# presentations/<연월>-<주제>/slides.html 을 PowerPoint(.pptx)로 변환한다.
#
# 슬라이드마다 headless Chrome 으로 1920x1080 PNG 를 찍고, 그 이미지를 16:9 슬라이드에
# 전면 배치한다. 덱이 CSS Grid·SVG·코드 하이라이트를 쓰기 때문에 텍스트를 PowerPoint
# 도형으로 재구성하면 레이아웃이 어긋난다 — 이미지 배치가 화면과 인쇄물을 일치시키는
# 유일한 방법이다. 대신 PowerPoint 에서 본문을 고칠 수 없으므로, 내용을 바꿀 때는
# slides.html 을 고치고 이 스크립트를 다시 돌린다.
#
# 산출물(.pptx)은 커밋하지 않는다(.gitignore). 3MB 바이너리를 저장소에 쌓는 대신
# 이 스크립트를 남겨 누구나 재생성하게 한다.
#
# 각 장 제목은 발표자 노트에 넣는다. 이미지 배치라 본문 검색이 안 되는 약점을 개요
# 보기와 노트 검색으로 메운다.
#
# 필요한 것: python-pptx, Google Chrome.
#   pip install python-pptx
#
# 실행 (repo 루트에서):
#   python3 scripts/build-deck-pptx.py presentations/2026-09-iac-asset/slides.html [출력.pptx]
#   출력 경로를 안 주면 slides.html 과 같은 디렉토리에 deck.pptx 로 쓴다.

import http.server
import re
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Emu, Inches

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DECK_BG = RGBColor(0x0D, 0x11, 0x17)  # slides.html 의 --bg 와 맞춘다
WIDTH, HEIGHT = 1920, 1080

# 렌더 전 주입하는 CSS/JS.
#  - .slide 의 등장 애니메이션은 IntersectionObserver 가 켜는데 headless 에서는 돌지
#    않아 전 슬라이드가 투명하게 찍힌다. opacity 를 강제로 연다.
#  - 진행 바·점 네비게이션·조작 힌트는 화면 UI 라 인쇄물에 남기지 않는다.
#
# ⚠️ CSS 는 중괄호를 쓰므로 str.format 에 통과시키지 않는다. 슬라이드 번호만 바꾸면
#    되니 JS 쪽만 문자열을 이어 붙인다.
INJECT_CSS = (
    "<style>"
    ".slide{opacity:1!important;transform:none!important;transition:none!important}"
    ".bar,.dots,.hint{display:none!important}"
    "</style>"
)


def inject(idx: int) -> str:
    return (
        INJECT_CSS
        + '<script>window.addEventListener("load",function(){'
        + f'document.querySelectorAll(".slide")[{idx}]'
        + '.scrollIntoView({behavior:"instant"});'
        + "});</script>"
    )


def slide_titles(html: str):
    """슬라이드별 제목을 순서대로 뽑는다(발표자 노트용)."""
    out = []
    for sec in re.split(r'<section class="slide', html)[1:]:
        m = (
            re.search(r"<h1>(.*?)</h1>", sec, re.S)
            or re.search(r'<h2 class="divider__t">(.*?)</h2>', sec, re.S)
            or re.search(r"<h2>(.*?)</h2>", sec, re.S)
        )
        title = re.sub(r"<[^>]+>", " ", m.group(1)) if m else ""
        out.append(re.sub(r"\s+", " ", title).strip())
    return out


def serve(directory: Path):
    """file:// 은 스크립트 실행이 막히는 경우가 있어 로컬 HTTP 로 띄운다."""

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(directory), **kw)

        def log_message(self, *a):
            pass

    httpd = socketserver.TCPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd, httpd.server_address[1]


def render(html_path: Path, png_dir: Path, count: int):
    html = html_path.read_text(encoding="utf-8")
    work = Path(tempfile.mkdtemp())
    httpd, port = serve(work)
    try:
        for idx in range(count):
            page = html.replace("</body>", inject(idx) + "</body>")
            (work / "_render.html").write_text(page, encoding="utf-8")
            out = png_dir / f"s{idx + 1:02d}.png"
            subprocess.run(
                [
                    CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    f"--window-size={WIDTH},{HEIGHT}",
                    "--virtual-time-budget=6000",
                    f"--screenshot={out}",
                    f"http://127.0.0.1:{port}/_render.html",
                ],
                check=True, capture_output=True,
            )
            print(f"  {idx + 1:02d}/{count} 렌더", file=sys.stderr)
    finally:
        httpd.shutdown()
        shutil.rmtree(work, ignore_errors=True)


def build(html_path: Path, out_path: Path):
    if not Path(CHROME).exists():
        sys.exit(f"Chrome 을 찾지 못했다: {CHROME}")

    html = html_path.read_text(encoding="utf-8")
    titles = slide_titles(html)
    if not titles:
        sys.exit(f"슬라이드를 찾지 못했다: {html_path}")

    png_dir = Path(tempfile.mkdtemp())
    try:
        render(html_path, png_dir, len(titles))

        prs = Presentation()
        prs.slide_width = Inches(13.333)
        prs.slide_height = Inches(7.5)
        blank = prs.slide_layouts[6]

        for idx, title in enumerate(titles):
            slide = prs.slides.add_slide(blank)
            fill = slide.background.fill
            fill.solid()
            fill.fore_color.rgb = DECK_BG
            slide.shapes.add_picture(
                str(png_dir / f"s{idx + 1:02d}.png"), Emu(0), Emu(0),
                width=prs.slide_width, height=prs.slide_height,
            )
            if title:
                notes = slide.notes_slide.notes_text_frame
                notes.text = f"{idx + 1}/{len(titles)} · {title}"

        prs.save(str(out_path))
        print(f"{out_path} — {len(titles)}장")
    finally:
        shutil.rmtree(png_dir, ignore_errors=True)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("사용법: python3 scripts/build-deck-pptx.py <slides.html> [출력.pptx]")
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else src.with_name("deck.pptx")
    build(src, dst)

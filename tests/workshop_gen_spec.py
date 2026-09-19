#!/usr/bin/env python3
"""Guard on workshop/workshop.txt: its description= block must equal what
tools/gen-workshop-txt.py produces from description.bbcode + gif_url.txt
(so the two never drift by hand edit), and no [img][/img] pair anywhere in
the tracked workshop material may carry an empty URL."""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "tools"))
import importlib.util

spec = importlib.util.spec_from_file_location("gen_workshop_txt", REPO / "tools" / "gen-workshop-txt.py")
gen_workshop_txt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen_workshop_txt)

WORKSHOP_TXT = REPO / "workshop" / "workshop.txt"
BBCODE = REPO / "workshop" / "description.bbcode"

EMPTY_IMG_RE = re.compile(r"\[img\]\s*\[/img\]")

fail = False

actual_desc = [
    line for line in WORKSHOP_TXT.read_text(encoding="utf-8").splitlines()
    if line.startswith("description=")
]
expected_desc = gen_workshop_txt.gen_description_lines()

if actual_desc != expected_desc:
    print("FAIL: workshop/workshop.txt description= lines are stale; run tools/gen-workshop-txt.py")
    fail = True

for path in (WORKSHOP_TXT, BBCODE):
    text = path.read_text(encoding="utf-8")
    if EMPTY_IMG_RE.search(text):
        print(f"FAIL: {path} has an [img][/img] tag with an empty URL")
        fail = True

if fail:
    sys.exit(1)
print("workshop_gen_spec: OK")

# --- workshop id: generator token, set-workshop-id.sh, pack-workshop.sh guard ---
# Everything below runs against a throwaway temp repo, never the real
# ~/Zomboid/Workshop/ or this checkout's own workshop/ files.
import shutil
import subprocess
import tempfile

TOOLS = REPO / "tools"
WORKSHOP_ID_TOKEN = gen_workshop_txt.WORKSHOP_ID_TOKEN
WORKSHOP_ID_PLACEHOLDER = gen_workshop_txt.WORKSHOP_ID_PLACEHOLDER


def _fresh_tmp_repo(tmp):
    """A minimal repo copy under tmp: real tools/, a small workshop/, a
    README with the marker span, and empty stand-ins for the files
    pack-workshop.sh ships (their content does not matter, only that they
    exist)."""
    (tmp / "tools").mkdir()
    for name in ("gen-workshop-txt.py", "pack-workshop.sh", "set-workshop-id.sh",
                 "fill-readme-link.py", "changelog-steam.py"):
        shutil.copy(TOOLS / name, tmp / "tools" / name)
    (tmp / "CHANGELOG.md").write_text(
        "# Changelog\n\n## Unreleased\n\n## 1.0.0 - 2026-09-18\n\n- A line.\n",
        encoding="utf-8",
    )
    (tmp / "workshop").mkdir()
    (tmp / "workshop" / "description.bbcode").write_text(
        f"[h1]T[/h1]\nWorkshop ID: {WORKSHOP_ID_TOKEN}\n", encoding="utf-8"
    )
    (tmp / "workshop" / "gif_url.txt").write_text("", encoding="utf-8")
    (tmp / "workshop" / "preview.png").write_text("", encoding="utf-8")
    (tmp / "workshop" / "workshop.txt").write_text(
        "version=1\ntitle=T\ndescription=x\ntags=\nvisibility=private\n", encoding="utf-8"
    )
    (tmp / "README.md").write_text(
        "## Install\n\n**From the Steam Workshop.** "
        "<!-- workshop-link:start -->Coming soon (not yet uploaded).<!-- workshop-link:end -->\n",
        encoding="utf-8",
    )
    for name, is_dir in (("mod.info", False), ("poster.png", False), ("poster2.png", False),
                          ("media", True), ("42", True), ("common", True)):
        p = tmp / name
        p.mkdir() if is_dir else p.write_text("", encoding="utf-8")
    return tmp


def _run(tmp, script, *args, env_extra=None):
    env = dict(**__import__("os").environ)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["bash", str(tmp / "tools" / script), *args],
        capture_output=True, text=True, env=env,
    )


def check_generator_token():
    """{{WORKSHOP_ID}} resolves to the placeholder with no workshop_id.txt,
    and to the digits once one is written."""
    with tempfile.TemporaryDirectory() as d:
        tmp = _fresh_tmp_repo(Path(d))
        lines = gen_workshop_txt.gen_description_lines(
            tmp / "workshop" / "description.bbcode", tmp / "workshop" / "gif_url.txt",
            tmp / "workshop" / "workshop_id.txt",
        )
        if f"description=Workshop ID: {WORKSHOP_ID_PLACEHOLDER}" not in lines:
            return "generator: expected the placeholder with no workshop_id.txt"
        (tmp / "workshop" / "workshop_id.txt").write_text("42\n", encoding="utf-8")
        lines = gen_workshop_txt.gen_description_lines(
            tmp / "workshop" / "description.bbcode", tmp / "workshop" / "gif_url.txt",
            tmp / "workshop" / "workshop_id.txt",
        )
        if "description=Workshop ID: 42" not in lines:
            return "generator: expected the id once workshop_id.txt holds one"
    return None


def check_set_id_digits_and_staged_read():
    with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as stage_d:
        tmp = _fresh_tmp_repo(Path(d))
        stage = Path(stage_d)

        r = _run(tmp, "set-workshop-id.sh", "abc")
        if r.returncode == 0:
            return "set-workshop-id.sh: accepted a non digit id"

        (stage / "workshop.txt").write_text("version=1\nid=999888777\ntitle=T\n", encoding="utf-8")
        r = _run(tmp, "set-workshop-id.sh", env_extra={"DEADWEIGHT_STAGE": str(stage)})
        if r.returncode != 0 or "999888777" not in (tmp / "workshop" / "workshop_id.txt").read_text():
            return f"set-workshop-id.sh: did not read the staged id: {r.stdout} {r.stderr}"
        if "id=999888777" not in (tmp / "workshop" / "workshop.txt").read_text():
            return "set-workshop-id.sh: did not write id= into workshop.txt"
    return None


def check_set_id_idempotent_and_refuses():
    with tempfile.TemporaryDirectory() as d:
        tmp = _fresh_tmp_repo(Path(d))
        r = _run(tmp, "set-workshop-id.sh", "111")
        if r.returncode != 0:
            return f"set-workshop-id.sh: first set failed: {r.stderr}"
        before = (tmp / "README.md").read_text()

        r = _run(tmp, "set-workshop-id.sh", "111")
        after = (tmp / "README.md").read_text()
        if r.returncode != 0 or before != after:
            return "set-workshop-id.sh: rerunning the same id was not a no-op"

        r = _run(tmp, "set-workshop-id.sh", "222")
        if r.returncode == 0:
            return "set-workshop-id.sh: accepted a different id without --force"

        r = _run(tmp, "set-workshop-id.sh", "222", "--force")
        if r.returncode != 0 or "222" not in (tmp / "workshop" / "workshop_id.txt").read_text():
            return "set-workshop-id.sh: --force did not accept a different id"
    return None


def check_pack_guard():
    with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as stage_d:
        tmp = _fresh_tmp_repo(Path(d))
        stage = Path(stage_d)
        (stage / "workshop.txt").write_text("version=1\nid=333\ntitle=T\n", encoding="utf-8")

        r = _run(tmp, "pack-workshop.sh", env_extra={"DEADWEIGHT_STAGE": str(stage)})
        if r.returncode == 0 or "REFUSING" not in r.stdout + r.stderr:
            return f"pack-workshop.sh: did not refuse an id unknown to the repo: {r.stdout} {r.stderr}"
        if (stage / "workshop.txt").read_text() != "version=1\nid=333\ntitle=T\n":
            return "pack-workshop.sh: staged workshop.txt was touched despite refusing"

        r = _run(tmp, "pack-workshop.sh", "--clean", env_extra={"DEADWEIGHT_STAGE": str(stage)})
        if r.returncode == 0 or "REFUSING" not in r.stdout + r.stderr:
            return "pack-workshop.sh --clean: did not refuse an id unknown to the repo"

        r = _run(tmp, "set-workshop-id.sh", "333", env_extra={"DEADWEIGHT_STAGE": str(stage)})
        if r.returncode != 0:
            return f"set-workshop-id.sh: could not teach the repo id 333: {r.stderr}"
        r = _run(tmp, "pack-workshop.sh", env_extra={"DEADWEIGHT_STAGE": str(stage)})
        if r.returncode != 0:
            return f"pack-workshop.sh: refused a known id: {r.stdout} {r.stderr}"
    return None


for check in (check_generator_token, check_set_id_digits_and_staged_read,
              check_set_id_idempotent_and_refuses, check_pack_guard):
    problem = check()
    if problem:
        print(f"FAIL: {problem}")
        sys.exit(1)
print("workshop_gen_spec (id): OK")

#!/usr/bin/env python3 -B
"""Asset-free synthetic LAn chain fixture for P1-A04 bridge tests.

Creates a tiny self-authored game dir under artifacts/godot/chain-fixture-*
exercising real bridge init/loading WITHOUT copying any owned game bytes.

Actual-format references (no forging Ready):
- RW chunks: gta-reversed/vendor/librw/src/rwbase.h (MAKEPLUGINID, chunk
  header type/size/version), clump.cpp (Clump/Atomic layout), geometry.cpp
  (Geometry/Material/MatList layout), frame.cpp (FrameList), texture.cpp
  (TexDictionary empty), base.cpp (version 0x36003, libraryIDPack).
- COL3: source/game_sa/Collision/ColHelpers.h (FileHeader 0x20, V2 Header
  0x4C, V3 Header 88, offsets relative to chunk+4, flags 2=not-empty),
  gta-reversed/source/app/platform/linux/NativeCollisionAssets.cpp (Parse
  bounds, ValidatedHeaderId, Empty) and ColLoad.cpp (ParseV234Chunk).
- IMG VER2: StreamPager.cpp BuildImgIndex/ImgReadBytes (off U32 sector,
  size U32 low 15 bits sector count, name 24), NativeCollisionAssets.cpp
  Load (.col scan, sector slack).
- DAT/IDE/IPL text: StreamPager.cpp CollectDatLists/ParseIdeText/
  ParseIplText, NativeWorldEntityInfo.cpp (objs grammar, draw/flags,
  object.dat boundary, Building mask), NativeLodCatalog.cpp ReadCatalog/
  Assemble (record order, Lod binding, DiskValidated).

Synthetic profile (mirrors real LAn record0/3991 -> record24/4043):
- child record0 model3991 gsfreeway7_lan draw180, parent record24
  model4043 lodgsfreeway7_lan draw450, both objs/flags0/interior0,
  quat 90deg about Z, pos (1608.195313, -1721.804688, 26.0), child Lod24,
  parent Lod-1, child before parent, same text source
  data\\maps\\LA\\LAn.IPL, each ID/name unique.
- records1..23 are filler objs IDs 5000..5022 with Lod-1 and valid IDE.
  Record1 has its own synthetic DFF near the Roads camera, to test cap-edge
  reservation; the rest are far, with intentionally absent unselected DFFs.
- TXDs are empty valid TEXDICTIONARYs named lanroad/lanlod (IDE owns
  names; bridge preserves sourceTxdName).
- COL is one-triangle COL3 for the child (header3991, nonempty,
  ValidatedHeaderId true); parent has no chunk (KnownAbsent).
- 3 indexed IMG archives (gta3, gta_int, player), models/coll dir exists.

Cases:
- baseline: child+parent DFF, both TXDs, child COL.
- missing-parent: omit parent DFF only (metadata/COL valid). Open
  succeeds (catalog+COL+chain evaluate); first Roads load with the
  configured supplement fails on parent geometry.
- missing-col: omit COL entirely (no loose, no IMG .col). Open fails
  during collision-assets load / chain closure, before publication.

CLI:
  python3 -B tools/godot-chain-fixture.py \\
    --output artifacts/godot/chain-fixture-baseline --case baseline
  python3 -B tools/godot-chain-fixture.py \\
    --output artifacts/godot/chain-fixture-missing-parent \\
    --case missing-parent
  python3 -B tools/godot-chain-fixture.py \\
    --output artifacts/godot/chain-fixture-missing-col --case missing-col

All bytes are generated below; no external writer, game reads or build step.
"""
import argparse
import struct
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ALLOWED_BASE = REPO_ROOT / "artifacts" / "godot"
PREFIX = "chain-fixture-"

CHILD_ID = 3991
PARENT_ID = 4043
CHILD_NAME = "gsfreeway7_lan"
PARENT_NAME = "lodgsfreeway7_lan"
CHILD_TXD = "lanroad"
PARENT_TXD = "lanlod"
CHILD_DRAW = 180.0
PARENT_DRAW = 450.0
FILLER_DRAW = 100.0
CHILD_POS = (1608.195313, -1721.804688, 26.0)
FILLER_IDS = list(range(5000, 5023))  # 23 fillers: 5000..5022
IPL_KEY_DAT = "data\\maps\\LA\\LAn.IPL"
IDE_KEY_DAT = "data\\maps\\LA\\LAn.IDE"

# --- RenderWare minimal writer (see module docstring for spec refs) ---
RW_VERSION = 0x36003
RW_BUILD = 0xFFFF

def _lib_id(version=RW_VERSION, build=RW_BUILD):
    if version <= 0x31000:
        return (version >> 8) & 0xFFFFFFFF
    return (((version - 0x30000) & 0x3FF00) << 14) | ((version & 0x3F) << 16) | (build & 0xFFFF)

_STAMP = _lib_id()

ID_STRUCT = 0x01
ID_EXTENSION = 0x03
ID_MATERIAL = 0x07
ID_MATLIST = 0x08
ID_FRAMELIST = 0x0E
ID_GEOMETRY = 0x0F
ID_CLUMP = 0x10
ID_ATOMIC = 0x14
ID_TEXDICTIONARY = 0x16
ID_GEOMETRYLIST = 0x1A

def _chunk(ctype, payload):
    return struct.pack("<III", ctype, len(payload), _STAMP) + payload

def dff_single_triangle():
    frame_data = struct.pack("<12f", 1.0, 0.0, 0.0, 0.0, 1.0, 0.0,
                             0.0, 0.0, 1.0, 0.0, 0.0, 0.0) + struct.pack("<2i", -1, 0)
    framelist_struct = _chunk(ID_STRUCT, struct.pack("<i", 1) + frame_data)
    framelist = _chunk(ID_FRAMELIST, framelist_struct + _chunk(ID_EXTENSION, b""))
    geo_header = struct.pack("<Iiii", 0, 1, 3, 1)
    tri = struct.pack("<II", 1, 131072)  # (0,1) (2,mat0)
    morph = (struct.pack("<4f2i", 0.5, 0.5, 0.0, 1.0, 1, 0)
             + struct.pack("<9f", 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0))
    geo_struct = _chunk(ID_STRUCT, geo_header + tri + morph)
    matlist_struct = _chunk(ID_STRUCT, struct.pack("<2i", 1, -1))
    mat_struct = _chunk(ID_STRUCT, struct.pack("<i4B2i", 0, 255, 255, 255, 255, 0, 0)
                        + struct.pack("<3f", 1.0, 1.0, 1.0))
    material = _chunk(ID_MATERIAL, mat_struct + _chunk(ID_EXTENSION, b""))
    matlist = _chunk(ID_MATLIST, matlist_struct + material)
    geometry = _chunk(ID_GEOMETRY, geo_struct + matlist + _chunk(ID_EXTENSION, b""))
    geolist = _chunk(ID_GEOMETRYLIST, _chunk(ID_STRUCT, struct.pack("<i", 1)) + geometry)
    atomic = _chunk(ID_ATOMIC, _chunk(ID_STRUCT, struct.pack("<4i", 0, 0, 5, 0))
                    + _chunk(ID_EXTENSION, b""))
    clump_struct = _chunk(ID_STRUCT, struct.pack("<3i", 1, 0, 0))
    return _chunk(ID_CLUMP, clump_struct + framelist + geolist + atomic
                  + _chunk(ID_EXTENSION, b""))

def txd_empty():
    return _chunk(ID_TEXDICTIONARY, _chunk(ID_STRUCT, struct.pack("<2h", 0, 0))
                  + _chunk(ID_EXTENSION, b""))

# --- COL3 single-triangle writer (ColHelpers V3, NativeCollisionAssets Parse) ---
def col3_child(name=CHILD_NAME, header_id=CHILD_ID):
    nb = name.encode("ascii")
    if not (1 <= len(nb) <= 22) or any(c < 32 or c >= 127 for c in nb):
        raise ValueError("bad COL model name")
    vert_bytes = b"".join(struct.pack("<3h", int(round(x * 128)),
                                      int(round(y * 128)), int(round(z * 128)))
                          for x, y, z in ((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)))
    face_bytes = struct.pack("<HHHBB", 0, 1, 2, 0, 0)
    off_v, off_f = 116, 134  # byte_pos - 4; header ends at 120
    h88 = (struct.pack("<10f", 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.5, 0.5, 0.0, 1.0)
           + struct.pack("<HHHBB", 0, 0, 1, 0, 0)
           + struct.pack("<I", 2)
           + struct.pack("<6I", 0, 0, 0, off_v, off_f, 0)
           + struct.pack("<3I", 0, 0, 0))
    assert len(h88) == 88
    total = 32 + 88 + len(vert_bytes) + len(face_bytes)
    head = (b"COL3" + struct.pack("<I", total - 8) + nb + b"\0" * (22 - len(nb))
            + struct.pack("<H", header_id))
    assert len(head) == 32
    return head + h88 + vert_bytes + face_bytes

# --- IMG VER2 writer (StreamPager BuildImgIndex) ---
SECTOR = 2048

def write_img(path, entries):
    if not (1 <= len(entries) <= 300000):
        raise ValueError("IMG entry count out of range")
    sectors = []
    for name, data in entries:
        nb = name.encode("ascii")
        if not (1 <= len(nb) <= 23) or b"\0" in nb:
            raise ValueError("bad IMG member name: %r" % name)
        if len(data) == 0:
            raise ValueError("empty IMG member: %s" % name)
        sectors.append((len(data) + SECTOR - 1) // SECTOR)
    header_len = 8 + len(entries) * 32
    start = (header_len + SECTOR - 1) // SECTOR
    out = bytearray(b"VER2" + struct.pack("<I", len(entries)))
    off = start
    for (name, _), nsec in zip(entries, sectors):
        nb = name.encode("ascii")
        out += struct.pack("<II", off, nsec) + nb + b"\0" * (24 - len(nb))
        off += nsec
    out += b"\0" * (start * SECTOR - len(out))
    for (_, data), nsec in zip(entries, sectors):
        out += data + b"\0" * (nsec * SECTOR - len(data))
    Path(path).write_bytes(bytes(out))

def _validate_output(arg):
    if not arg or "\0" in arg:
        raise ValueError("--output must be a non-empty path without NUL bytes")
    resolved = (Path.cwd() / arg).resolve() if not Path(arg).is_absolute() else Path(arg).resolve()
    if "Grand-Theft-Auto-San-Andreas" in resolved.parts:
        raise ValueError("refusing output inside the owned game install")
    if resolved == Path("/game") or "/game" in str(resolved):
        # String check covers /game/... without resolving the mount.
        if resolved.parts[:2] == ("/", "game"):
            raise ValueError("refusing output inside /game")
    try:
        rel = resolved.relative_to(ALLOWED_BASE.resolve())
    except ValueError:
        raise ValueError("output must live under artifacts/godot/chain-fixture-*")
    if resolved.name == "godot" or not resolved.name.startswith(PREFIX):
        raise ValueError("output dir basename must start with %r" % PREFIX)
    if len(rel.parts) != 1:
        raise ValueError("output must be exactly artifacts/godot/%s... (no deeper nesting)" % PREFIX)
    if resolved.exists():
        raise ValueError("output already exists (refusing to change existing data): %s" % resolved)
    parent = resolved.parent
    if not parent.is_dir():
        raise ValueError("parent does not exist (only the explicit new prefix dir is created): %s" % parent)
    if resolved == REPO_ROOT.resolve() or resolved == Path("/").resolve():
        raise ValueError("refusing unsafe output at repo/filesystem root")
    return resolved

def _ide_text():
    lines = ["objs"]
    lines.append("%d %s %s %g %d" % (CHILD_ID, CHILD_NAME, CHILD_TXD, CHILD_DRAW, 0))
    for i, mid in enumerate(FILLER_IDS):
        lines.append("%d fx_fill_%02d %s %g %d" % (mid, i, CHILD_TXD, FILLER_DRAW, 0))
    lines.append("%d %s %s %g %d" % (PARENT_ID, PARENT_NAME, PARENT_TXD, PARENT_DRAW, 0))
    lines.append("end")
    return "\n".join(lines) + "\n"

def _ipl_text():
    lines = ["inst"]
    x, y, z = CHILD_POS
    lines.append("%d %s 0 %s %s %s 0 0 0.7071067811865476 0.7071067811865476 24" % (CHILD_ID, CHILD_NAME, repr(x), repr(y), repr(z)))
    for i, mid in enumerate(FILLER_IDS):
        position = (1532.054688, -1662.289063, 12.460938) if i == 0 else (9000.0 + i * 10.0, 9000.0, 10.0)
        lines.append("%d fx_fill_%02d 0 %s %s %s 0 0 0 1 -1"
                     % (mid, i, *(repr(value) for value in position)))
    lines.append("%d %s 0 %s %s %s 0 0 0.7071067811865476 0.7071067811865476 -1" % (PARENT_ID, PARENT_NAME, repr(x), repr(y), repr(z)))
    lines.append("end")
    return "\n".join(lines) + "\n"

def _default_dat():
    return ("IDE %s\nIMG MODELS\\GTA3.IMG\nIMG MODELS\\GTA_INT.IMG\n"
            "IMG MODELS\\PLAYER.IMG\nIPL %s\nEXIT\n" % (IDE_KEY_DAT, IPL_KEY_DAT))

def main(argv=None):
    ap = argparse.ArgumentParser(description="Create asset-free synthetic LAn chain fixture.")
    ap.add_argument("--output", required=True, help="artifacts/godot/chain-fixture-... (new dir)")
    ap.add_argument("--case", required=True, choices=("baseline", "missing-parent", "missing-col"))
    args = ap.parse_args(argv)
    try:
        out = _validate_output(args.output)
    except ValueError as e:
        print("godot-chain-fixture: %s" % e, file=sys.stderr)
        return 2

    out.mkdir(parents=False, exist_ok=False)
    (out / "data" / "maps" / "LA").mkdir(parents=True, exist_ok=False)
    (out / "models" / "coll").mkdir(parents=True, exist_ok=False)
    try:
        dff_bytes, txd_bytes = dff_single_triangle(), txd_empty()
        col_bytes = col3_child()
    except SystemExit:
        raise
    except Exception as e:
        print("godot-chain-fixture: fixture byte generation failed: %s" % e, file=sys.stderr)
        return 2

    (out / "data" / "default.dat").write_text(_default_dat(), encoding="ascii")
    (out / "data" / "gta.dat").write_text("EXIT\n", encoding="ascii")
    (out / "data" / "object.dat").write_text("* stop\n", encoding="ascii")
    (out / "data" / "maps" / "LA" / "LAn.IDE").write_text(_ide_text(), encoding="ascii")
    (out / "data" / "maps" / "LA" / "LAn.IPL").write_text(_ipl_text(), encoding="ascii")

    gta3 = []
    gta3.append((CHILD_NAME + ".dff", dff_bytes))
    gta3.append(("fx_fill_00.dff", dff_bytes))
    if args.case != "missing-parent":
        gta3.append((PARENT_NAME + ".dff", dff_bytes))
    gta3.append((CHILD_TXD + ".txd", txd_bytes))
    gta3.append((PARENT_TXD + ".txd", txd_bytes))
    if args.case != "missing-col":
        gta3.append(("lan_2.col", col_bytes))
    write_img(out / "models" / "gta3.img", gta3)
    write_img(out / "models" / "gta_int.img", [("dummy_int.dat", b"SYNTHETIC-CHAIN-FIXTURE-DUMMY\n")])
    write_img(out / "models" / "player.img", [("dummy_player.dat", b"SYNTHETIC-CHAIN-FIXTURE-DUMMY\n")])

    print("chain-fixture-ok case=%s output=%s gta3_entries=%d records=25 "
          "child=%d@0 parent=%d@24 col=%s" % (
              args.case, out, len(gta3), CHILD_ID, PARENT_ID,
              "absent" if args.case == "missing-col" else "lan_2.col:3991/1-face"))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

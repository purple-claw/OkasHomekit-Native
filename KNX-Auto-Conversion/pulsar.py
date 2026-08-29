#!/usr/bin/env python3
"""
Pulsar — ETS Convertor Script specifically fine tuned for OKAS Homekit.

Built and developed by Nithin.J<nithin.j@miantic.com> Under the Supervision of Anil.K Chikkam (Head R&D) - for Miantic AV Distribution Pvt.Ltd.

Note : This Script is developed by the development team at Miantic AV Distribution(2026-27). All Sole rights belongs to Miantic, 
copying and using this script without the permission is not accepatable & such practices are not encouraged.

# Bug Fixes : Previous V1 Version has Name based Hard coded heustricts, 
  So I dumped that version and did spent a lot of time doing R&D, and Implemented new Parsing Logic.
    -> ETS evidence only: DPT, ObjectSize, ComObject C/R/W/T/U flags,
    -> Function blocks, GroupObjectTree channels, Locations/Space.
    -> No name heuristics. Integrator translations cannot break this.

"""
import argparse, json, pathlib, re, shutil, sys, tempfile, zipfile
from dataclasses import dataclass, field
from typing import Optional
from xml.etree import ElementTree

# C/R/W/T/U — the six flag attributes every ComObject carries.
fK = ("Communication", "Read", "Write", "Transmit", "Update", "ReadOnInit")
# schema < 14 uses <Connectors> Send/Receive; >= 14 uses Links attr. Mysterious.
ETS_4_5 = 14

# Okas JSON contract. Don't touch order, the board's makFile.php reads it.
oGA = {
    "Switch":  ["Swt", "Sta"],
    "Dimmer":  ["Swt", "Sta", "Dim", "Bri", "Bvi"],
    "RGB":     ["Swt", "Sta", "Dim", "Bri", "Bvi", "Clc", "Clv"],
    "Tunable": ["Swt", "Sta", "Dim", "Bri", "Bvi", "Tuc", "Tuv"],
    "HVAC":    ["Swt", "Sta", "Trm", "Tsp", "Fsc", "Fsv", "Tmc", "Tmv"],
    "Fan":     ["Swt", "Sta", "Fsc", "Fsv"],
    "Curtain": ["Mov", "Mvi", "Stp", "Pos", "Pvi"],
    "Scene":   ["Scn"],
}
oXDef = {
    "Tunable": {"Kmn": "2700", "Kmx": "6500"},
    "HVAC":    {"Tmn": "16", "Tmx": "30", "Smx": "3", "Fst": "1"},
    "Fan":     {"Smx": "3", "Fst": "1"},
    "Scene":   {"Scn": "1"},
}
cK = ("Swt", "Dim", "Bri", "Clc", "Tuc", "Mov", "Stp", "Pos", "Fsc", "Trm", "Tsp", "Tmc", "Scn", "Thc")
sK = ("Sta", "Bvi", "Clv", "Tuv", "Mvi", "Pvi", "Fsv", "Tmv")


# --- tiny helpers ---
def stNs(t): return t.split("}", 1)[-1] if "}" in t else t

def pFlg(v): return None if v is None else v == "Enabled"

# "DPST 7-600", "DPST-1-1", "DPT 9.001" -> "7.600", "1.001", "9.001". Sigh.
def nDpt(d):
    s = (d or "").strip()
    if not s: return ""
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"^(?:DPST|DPT)[ \-]*", "", s)
    ps = [p for p in s.replace(".", "-").split("-") if p]
    if not ps: return ""
    try:
        if len(ps) == 1: return f"{int(ps[0])}"
        return f"{int(ps[0])}.{int(ps[1]):03d}"
    except ValueError:
        if re.match(r"^\d+\.\d+$", s):
            m, x = s.split(".", 1)
            try: return f"{int(m)}.{int(x):03d}"
            except ValueError: pass
        return s

def pDptLst(d):
    if not d: return []
    return [n for n in (nDpt(t) for t in d.split()) if n]

# 5/3/8 for ThreeLevel, 5/11 for TwoLevel, plain int for Free. Knx spec.
def fGa(r, st):
    s = (st or "").lower()
    if s == "threelevel": return f"{(r>>11)&0x1F}/{(r>>8)&0x07}/{r&0xFF}"
    if s == "twolevel":   return f"{(r>>11)&0x1F}/{r&0x7FF}"
    return str(r)

# (main, sub) -> {ctl, sta} okas keys. None = any sub of that main.
dptSlt = {
    (1, 1):  {"ctl": "Swt", "sta": "Sta"},
    (1, 7):  {"ctl": "Stp"},
    (1, 8):  {"ctl": "Mov", "sta": "Mvi"},
    (1, 9):  {"ctl": "Mov", "sta": "Mvi"},
    (1, 10): {"ctl": "Mov"},
    (1, 11): {"sta": "Mvi"},
    (1, 100):{"ctl": "Thc", "sta": "Thc"},
    (1, 400):{"ctl": "Scn", "sta": "Scn"},
    (1, None):{"ctl": "Swt", "sta": "Sta"},
    (2, None):{"ctl": "Swt", "sta": "Sta"},
    (3, 7):  {"ctl": "Dim"},
    (3, 8):  {"ctl": "Dim"},
    (3, None):{"ctl": "Dim"},
    (5, 1):  {"ctl": "Bri", "sta": "Bvi"},
    (5, 3):  {"ctl": "Pos", "sta": "Pvi"},  # curtain angle -> Pos
    (5, 4):  {"ctl": "Bri", "sta": "Bvi"},
    (5, 10): {"ctl": "Bri", "sta": "Bvi"},
    (5, 100):{"ctl": "Fsc", "sta": "Fsv"},
    (5, None):{"ctl": "Bri", "sta": "Bvi"},
    (7, 1):  {"ctl": "Bri"},
    (7, 13): {"ctl": "Bri", "sta": "Bvi"},
    (7, 600):{"ctl": "Tuc", "sta": "Tuv"},
    (7, None):{"ctl": "Bri", "sta": "Bvi"},
    (9, 1):  {"ctl": "Tsp", "sta": "Trm"},
    (9, 24): {"ctl": "Bri", "sta": "Bvi"},
    (9, None):{"ctl": "Tsp", "sta": "Trm"},
    (14, 19):{"ctl": "Bri", "sta": "Bvi"},  # current
    (14, 56):{"ctl": "Bri", "sta": "Bvi"},  # power
    (14, None):{"ctl": "Bri", "sta": "Bvi"},
    (17, 1): {"ctl": "Scn", "sta": "Scn"},
    (17, None):{"ctl": "Scn", "sta": "Scn"},
    (18, 1): {"ctl": "Scn"},
    (18, None):{"ctl": "Scn"},
    (20, 102):{"ctl": "Tmc", "sta": "Tmv"},
    (20, 105):{"ctl": "Tmc", "sta": "Tmv"},
    (20, 600):{"ctl": "Tmc", "sta": "Tmv"},
    (20, None):{"ctl": "Tmc", "sta": "Tmv"},
    (232, 600):{"ctl": "Clc", "sta": "Clv"},
    (234, 600):{"ctl": "Clc", "sta": "Clv"},
    (237, 600):{"ctl": "Clc", "sta": "Clv"},
    (238, 600):{"ctl": "Clc", "sta": "Clv"},
    (251, 600):{"ctl": "Clc", "sta": "Clv"},
}
# when only main is known, pick the most useful sub.
dDftSub = {1: 1, 2: 1, 3: 7, 5: 1, 7: 13, 9: 1, 14: 56,
           17: 1, 18: 1, 20: 102, 232: 600, 234: 600, 237: 600, 238: 600, 251: 600}
# ObjectSize -> main. Last-ditch when DPT is empty.
oSz2M = {
    "1": 1, "1 Bit": 1, "2 Bit": 2,
    "4 Bit": 3,
    "1 Byte": 5, "1byte": 5, "1-byte": 5,
    "2 Bytes": 7, "2 Bytes (Float)": 9,
    "4 Bytes": 12, "4 Bytes (Float)": 14,
    "6 Bytes": 232, "8 Bytes": 251, "14 Bytes": 251,
}


def sDpt(d):
    # returns (main:int|None, sub:int|None)
    if not d: return None, None
    d = nDpt(d)
    if "." in d:
        m, s = d.split(".", 1)
        try: return int(m), int(s)
        except ValueError: return (int(m) if m.isdigit() else None), None
    if d.isdigit(): return int(d), dDftSub.get(int(d))
    return None, None


def sFor(d, role):
    # (DPT, 'ctl'|'sta') -> okas key | None. The only heuristic left.
    m, s = sDpt(d)
    if m is None: return None
    e = dptSlt.get((m, s)) or dptSlt.get((m, None))
    return e.get(role) if e else None


def dDptFrmSz(o):
    if not o: return ""
    m = oSz2M.get(o.strip())
    if m is None: return ""
    return f"{m}.{dDftSub.get(m, 0):03d}"


# --- data records ---
@dataclass
class cDef:  # ComObject/ComObjectRef definition
    id: str = ""
    isRef: bool = False
    refId: str = ""
    dpts: list = field(default_factory=list)
    osz: str = ""
    flags: dict = field(default_factory=dict)
    text: str = ""
    ftext: str = ""
    chan: str = ""


@dataclass
class cInst:  # ComObjectInstanceRef (effective)
    refId: str = ""
    text: str = ""
    ftext: str = ""
    dpts: list = field(default_factory=list)
    flags: dict = field(default_factory=dict)
    chan: str = ""
    links: list = field(default_factory=list)


@dataclass
class Dev:
    addr: str = ""    # "1.2.5" full area.line.device
    octet: str = ""   # last octet only
    devId: str = ""
    product: str = ""
    hwId: str = ""
    appId: str = ""
    cos: list = field(default_factory=list)     # [cInst]
    chans: list = field(default_factory=list)  # [(refId, text, gois)]
    isAct: bool = False
    sPath: list = field(default_factory=list)


@dataclass
class Ga:
    id: str = ""      # full P-xxx_GA-5
    key: str = ""     # bare GA-5 after project-prefix strip
    raw: int = 0
    addr: str = ""
    name: str = ""    # labels are labels. never used to classify.
    dpt: str = ""
    rPath: list = field(default_factory=list)  # GroupRange path (room hint)


# --- dpt -> okas typ (occupied keys => typ). One direction; the only "heuristic".
def typ4k(keys):
    if "Scn" in keys: return "Scene", oGA["Scene"]
    if "Clc" in keys or "Clv" in keys: return "RGB", oGA["RGB"]
    if "Tuc" in keys or "Tuv" in keys: return "Tunable", oGA["Tunable"]
    if "Mov" in keys or "Mvi" in keys or "Stp" in keys: return "Curtain", oGA["Curtain"]
    if "Tsp" in keys or "Trm" in keys or "Tmc" in keys or "Tmv" in keys or "Thc" in keys:
        return "HVAC", oGA["HVAC"]
    if "Fsc" in keys or "Fsv" in keys: return "Fan", oGA["Fan"]
    if "Dim" in keys or "Bri" in keys or "Bvi" in keys: return "Dimmer", oGA["Dimmer"]
    return "Switch", oGA["Switch"]


# --- read project info from project.xml ---
def rdPrjInfo(p, sv):
    # sv = schema version (int)
    info = {"name": "", "tool": "", "ets": "ETS5/6", "style": "ThreeLevel"}
    if not p.is_file(): return info
    root = ElementTree.parse(str(p)).getroot()
    info["tool"] = root.get("ToolVersion", "")
    info["ets"] = "ETS4" if ("ets4" in root.tag.lower() or sv < 14) else "ETS5/6"
    pi = root.find("{*}Project/{*}ProjectInformation")
    if pi is not None:
        info["name"] = pi.get("Name", "")
        s = pi.get("GroupAddressStyle", "ThreeLevel")
        if s: info["style"] = s
    return info


# --- stream 0.xml into devices / gas / spaces / functions ---
def rdP0(p0, style):
    """Returns (devs, devsById, gas, gaById, spaces, fns). One pass. Because who wants two."""
    devs: dict = {}    # addr -> Dev
    devsById: dict = {}  # full DevId -> addr
    gas: dict = {}     # gaKey -> Ga
    gaById: dict = {}  # full GA id -> key (passthrough for connectors)
    rng: list = []     # GroupRange name stack
    fSt: list = []     # Function/Space nest stack (room path)
    curD: Optional[Dev] = None
    curCO: Optional[dict] = None
    spaces: list = []
    fns: list = []
    for evt, el in ElementTree.iterparse(str(p0), events=("start", "end")):
        tag = stNs(el.tag)
        if evt == "start":
            if tag == "DeviceInstance":
                a = el.get("Address")
                if a:
                    d = Dev(addr=a, octet=a.split(".")[-1] if a else "",
                            devId=el.get("Id", ""),
                            hwId=el.get("Hardware2ProgramRefId", ""))
                    devs[a] = d
                    if d.devId: devsById[d.devId] = a
                    curD = d
                else:
                    curD = None
            elif tag == "GroupAddress":
                gid = el.get("Id", "")
                # Capture the project prefix from the first GA we see.
                if "_GA-" in gid and not any(gas.values()):
                    pass  # prefix already taken care of in gaById map; we keep the full id
                try: raw = int(el.get("Address", "0") or "0")
                except ValueError: raw = 0
                if gid: gaById[gid] = gid
                gas[gid] = Ga(id=gid, key=gid, raw=raw,
                                addr=fGa(raw, style),
                                name=el.get("Name", ""),
                                dpt=el.get("DatapointType", "") or "",
                                rPath=list(rng))
            elif tag == "GroupRange":
                rng.append(el.get("Name", ""))
            elif tag == "ComObjectInstanceRef" and curD is not None:
                # collect per-ref data, defer build to </end>
                curCO = {
                    "refId": el.get("RefId", ""),
                    "text": el.get("Text", "") or "",
                    "ftext": el.get("FunctionText", "") or "",
                    "chan": el.get("ChannelId", "") or "",
                    "flags": {k: pFlg(el.get(k + "Flag")) for k in fK},
                    "linksAttr": el.get("Links", "") or "",
                    "linksConn": [],
                }
            elif tag in ("Send", "Receive") and curCO is not None:
                curCO["linksConn"].append(el.get("GroupAddressRefId", ""))
            elif tag == "Node" and curD is not None and el.get("Type") == "Channel":
                gois = el.get("GroupObjectInstances", "")
                if gois: curD.chans.append((el.get("RefId", ""), el.get("Text", ""), gois.split()))
            elif tag in ("Locations", "Buildings"):
                pass
            elif tag in ("Space", "BuildingPart"):
                sp = {"name": el.get("Name", ""),
                      "type": el.get("Type", ""),
                      "path": [s["name"] for s in fSt] + [el.get("Name", "")],
                      "devIds": [], "fnIds": [], "kids": []}
                if fSt: fSt[-1]["kids"].append(sp)
                else: spaces.append(sp)
                fSt.append(sp)
            elif tag == "Function":
                fn = {"id": el.get("Id", "").split("_", 1)[-1] if el.get("Id", "") else "",
                      "name": el.get("Name", "") or "",
                      "type": el.get("Type", "") or "",
                      "sPath": [s["name"] for s in fSt],
                      "gaRefs": []}  # list of (gid, role)
                fns.append(fn)
                if fSt: fSt[-1]["fnIds"].append(fn["id"])
                fSt.append(fn)
            elif tag == "DeviceInstanceRef" and fSt:
                fSt[-1]["devIds"].append(el.get("RefId", ""))
            elif tag == "GroupAddressRef" and fSt:
                fSt[-1]["gaRefs"].append((el.get("RefId", ""), el.get("Role", "") or ""))
        else:  # end
            if tag == "DeviceInstance": curD = None
            elif tag == "ComObjectInstanceRef" and curCO is not None:
                if curD is not None:
                    # Schema >= 14: Links; older: <Connectors> Send/Receive.
                    links = curCO["linksAttr"].split() if curCO["linksAttr"] else list(curCO["linksConn"])
                    co = cInst(refId=curCO["refId"],
                               text=curCO["text"], ftext=curCO["ftext"],
                               chan=curCO["chan"], flags=dict(curCO["flags"]),
                               links=[l for l in links if l])
                    curD.cos.append(co)
                curCO = None
            elif tag == "GroupRange":
                if rng: rng.pop()
            elif tag in ("Space", "BuildingPart", "Function") and fSt:
                fSt.pop()
        el.clear()
    return devs, devsById, gas, gaById, spaces, fns


def attachD2S(devsById, spaces, devs):
    # Walk space tree, deepest wins per device.
    def w(sp):
        for dr in sp["devIds"]:
            a = devsById.get(dr)
            if a and a in devs and not devs[a].sPath:
                devs[a].sPath = list(sp["path"])
        for c in sp["kids"]: w(c)
    for s in spaces: w(s)


# --- HW catalog (product text + HW->AppProgram map) ---
def rdHw(d):
    prods: dict = {}
    hw2a: dict = {}
    for hwx in d.glob("M-*/Hardware.xml"):
        try: t = ElementTree.parse(str(hwx))
        except Exception: continue
        for el in t.iter():
            tn = stNs(el.tag)
            if tn == "Product":
                if el.get("Id"): prods[el.get("Id")] = el.get("Text", "") or ""
            elif tn == "Hardware2Program":
                hid = el.get("Id", "")
                for ap in el.iter():
                    if stNs(ap.tag) == "ApplicationProgramRef" and hid:
                        hw2a[hid] = ap.get("RefId", "")
                        break
    return prods, hw2a


# --- app program defs (ComObject / ComObjectRef) ---
def rdApps(d):
    apps: dict = {}
    for ax in d.glob("M-*/*_A-*.xml"):
        try: ctx = ElementTree.iterparse(str(ax), events=("start", "end"))
        except Exception: continue
        appId = ""
        defs: dict = {}
        for evt, el in ctx:
            tag = stNs(el.tag)
            if evt == "start" and tag in ("ComObject", "ComObjectRef"):
                cid = el.get("Id", "")
                if cid:
                    defs[cid] = cDef(
                        id=cid, isRef=(tag == "ComObjectRef"),
                        refId=el.get("RefId", "") or "",
                        dpts=pDptLst(el.get("DatapointType", "") or ""),
                        osz=el.get("ObjectSize", "") or "",
                        flags={k: pFlg(el.get(k + "Flag")) for k in fK},
                        text=el.get("Text", "") or "",
                        ftext=el.get("FunctionText", "") or "",
                        chan=el.get("ChannelId", "") or "",
                    )
            elif evt == "start" and tag == "ApplicationProgram" and not appId:
                appId = el.get("Id", "")
            el.clear()
        if appId and defs: apps[appId] = defs
    return apps


# Module instances prepend "MD-x_M-x_MI-x_" to refId; the app def omits
# that whole prefix. Strip it before suffix matching.
def fDef(defs, refId):
    if not refId: return None
    e = defs.get(refId)
    if e: return e
    tail = re.sub(r"^MD-\d+_M-\d+_MI-\d+_", "", refId)
    cs = [k for k in defs if k.endswith(tail)]
    if len(cs) == 1: return defs[cs[0]]
    if len(cs) > 1:
        # Disambiguate by matching the original refId tail (last underscore chunk).
        cs2 = [k for k in cs if k.endswith(refId.rsplit("_", 1)[-1])]
        if len(cs2) == 1: return defs[cs2[0]]
        return defs[cs[0]]
    return None


def resInst(inst, dev, apps):
    # instance > ComObjectRef > ComObject. DPTs and flags both.
    defs = apps.get(dev.appId)
    if not defs: return
    e = fDef(defs, inst.refId)
    if not e: return
    if e.isRef: ref, co = e, defs.get(e.refId)
    else: ref, co = None, e
    if not co: return
    if not inst.dpts:
        inst.dpts = list(ref.dpts) if ref and ref.dpts else list(co.dpts)
    # DPT fallback through ObjectSize when all of instance/ref/co have nothing.
    if not inst.dpts and co.osz:
        d = dDptFrmSz(co.osz)
        if d: inst.dpts = [d]
    for k in fK:
        if inst.flags.get(k) is None:
            v = co.flags.get(k)
            if v is None and ref is not None: v = ref.flags.get(k)
            if v is not None: inst.flags[k] = v
    if not inst.ftext and (e.ftext or co.ftext): inst.ftext = e.ftext or co.ftext
    if not inst.text and (e.text or co.text): inst.text = e.text or co.text


# Device is an actuator iff it W-consumes a GA that no other device also W-consumes.
# Pure structural rule, no name lookup.
def clsDev(devs):
    wC: dict = {}  # ga id -> set(devAddrs)
    tP: dict = {}
    for d in devs.values():
        for c in d.cos:
            if not c.links: continue
            if c.flags.get("Write") is True and c.flags.get("Communication") is True:
                for l in c.links: wC.setdefault(l, set()).add(d.addr)
            if c.flags.get("Transmit") is True and c.flags.get("Communication") is True:
                for l in c.links: tP.setdefault(l, set()).add(d.addr)
    for d in devs.values():
        ok = False
        anyW = False
        for c in d.cos:
            if not c.links: continue
            if c.flags.get("Write") is not True or c.flags.get("Communication") is not True: continue
            anyW = True
            for l in c.links:
                if len(wC.get(l, ())) == 1 and d.addr in wC[l]:
                    ok = True; break
            if ok: break
        d.isAct = anyW and ok


# Build a load from a list of cInsts. Returns dict or None.
# functionRole: optional {gaId: "Control"|"Status"} from <Function>.
def bldLdFrmCmb(name, sPath, comobjs, gaM, functionRole=None):
    functionRole = functionRole or {}
    keys: dict = {}   # ga id -> okas key
    dpts: dict = {}   # ga id -> DPT string used
    for c in comobjs:
        if not c.links: continue
        for l in c.links:
            gaId = l
            rfn = functionRole.get(gaId)
            d = c.dpts[0] if c.dpts else ""
            if not d: continue
            slot = None
            if rfn == "Control":
                slot = sFor(d, "ctl") or sFor(d, "sta")
            elif rfn == "Status":
                slot = sFor(d, "sta")
            else:
                isCtl = c.flags.get("Write") is True and c.flags.get("Communication") is True
                isSta = c.flags.get("Transmit") is True and c.flags.get("Communication") is True
                if isCtl and isSta: slot = sFor(d, "ctl") or sFor(d, "sta")
                elif isCtl: slot = sFor(d, "ctl")
                elif isSta: slot = sFor(d, "sta")
            if not slot: continue
            if gaId not in keys:
                keys[gaId] = slot
                dpts[gaId] = d
    if not keys: return None
    occupied = set(keys.values())
    typ, order = typ4k(occupied)
    gaD = {k: "" for k in order}
    for gid, k in keys.items():
        if k in gaD and not gaD[k]:
            a = gaM.get(gid, "")
            if a: gaD[k] = a
    if not any(v for k, v in gaD.items() if k in cK): return None
    return {"ldNm": name, "ldTyp": typ,
            "gAdd": [gaD[k] for k in order],
            "GA": {k: v for k, v in gaD.items() if v},
            "room": " / ".join(sPath) if sPath else "Unassigned",
            "rPath": tuple(sPath),
            "_dpts": dpts}


def attDef(e):
    # Apply Okas default extras (Tunable K range, HVAC Tmin/Tmax, ...).
    for k, v in oXDef.get(e["ldTyp"], {}).items(): e.setdefault(k, v)


# Build a typed load from a fixed slot dict (used by GA-only clustering).
def mkTypLd(typ, slotAddrs, name, room):
    order = oGA[typ]
    gD = {k: slotAddrs.get(k, "") for k in order}
    return {"ldNm": name, "ldTyp": typ,
            "gAdd": [gD[k] for k in order],
            "GA": {k: v for k, v in gD.items() if v},
            "room": room, "rPath": tuple(), "_dpts": {}}


# --- GA clustering: grow a raw-adjacent window while ONE Okas type can absorb
# every GA in it. DPT decides the slot; raw order decides ctl-before-sta.
# This is how the app distinguishes loads (makFile.php $lT2gT contract). ---
# --- DPT -> slot, strictly from KNX spec semantics (verified against xknx
# dpt registry: DPTSwitch 1.001, DPTStep 1.007 dec/inc, DPTUpDown 1.008,
# DPTOpenClose 1.009, DPTStart 1.010 start/stop, DPTState 1.011,
# DPTHeatCool 1.100, DPTControlDimming 3.007, DPTControlBlinds 3.008,
# DPTScaling 5.001 %, DPTAngle 5.003, DPTPercentU8 5.004, DPTFanStage 5.100,
# DPTBrightness 7.013 lx, DPTColorTemperature 7.600 K, DPTTemperature 9.001,
# DPTHVACMode 20.102, DPTHVACContrMode 20.105, DPTSceneNumber 17.001,
# DPTSceneControl 18.001, DPTColorRGB 232.600, DPTColorRGBW 251.600).
# Measurement DPTs (9.007 humidity, 9.024 lux, 13/14 power/energy, 7.012
# current, 5.010 pulses) map to NO slot — they audit out as sensors. ---
def _slotIn(typ, dpt, taken):
    # DPT -> free okas slot of `typ`, or None if this type can't represent it.
    d = nDpt(dpt)
    m, s = (1, None) if not d else sDpt(d)
    def put(a, b):
        if not taken.get(a): return a
        if b and not taken.get(b): return b
        return None
    if typ == "Switch":
        # generic binary family: switch/bool/enable/ramp/alarm/binary/trigger/
        # step/start/state — direction (ctl vs sta) comes from raw order.
        return put("Swt", "Sta") if m in (1, 2) else None
    if typ == "Dimmer":
        if m in (1, 2): return put("Swt", "Sta")
        if m == 3 and s == 7: return put("Dim", None)      # relative dim
        if m == 5 and s in (1, 4): return put("Bri", "Bvi")  # % brightness
        if m == 7 and s == 13: return put("Bri", "Bvi")    # lux level
        return None
    if typ == "Tunable":
        r = _slotIn("Dimmer", dpt, taken)
        if r: return r
        return put("Tuc", "Tuv") if (m == 7 and s == 600) else None
    if typ == "RGB":
        r = _slotIn("Dimmer", dpt, taken)
        if r: return r
        return put("Clc", "Clv") if m in (232, 234, 237, 238, 242, 251) else None
    if typ == "Curtain":
        # 1.008 up/down + 1.009 open/close are the movement objects; 1.007 step
        # and 1.010 start/stop are the stop objects; 5.001/5.003 position/slat.
        # Generic 1.001/1.002 may fill Mvi (Movement Value = feedback) ONLY
        # after real movement evidence (Mov) exists — otherwise switch pairs
        # with a stray 1.007 would fabricate Curtains.
        if m == 1 and s in (7, 10): return put("Stp", None)
        if m == 1 and s in (8, 9): return put("Mov", "Mvi")
        if m == 1 and s == 11: return "Mvi" if not taken.get("Mvi") else None
        if m in (1, 2) and taken.get("Mov"):
            return "Mvi" if not taken.get("Mvi") else None
        if m == 3 and s == 8: return put("Stp", None)
        if m == 5 and s in (1, 3, 4): return put("Pos", "Pvi")
        return None
    if typ == "Fan":
        if m in (1, 2): return put("Swt", "Sta")
        if m == 5 and s == 100: return put("Fsc", "Fsv")   # fan stage
        if m == 3: return put("Fsc", None)                 # relative speed step
        return None
    if typ == "HVAC":
        if m in (1, 2): return put("Swt", "Sta")
        if m == 9 and s == 1: return put("Tsp", "Trm")     # °C setpoint/actual
        if m == 20: return put("Tmc", "Tmv")               # mode/contr-mode
        if m == 5 and s == 100: return put("Fsc", "Fsv")   # fan stage
        if m == 1 and s == 100: return None                # heat/cool: no Okas slot
        return None
    if typ == "Scene":
        return put("Scn", None) if m in (17, 18) else None
    return None

# --- Slot decision principle (general, no per-file tuning):
# 1. A window (raw-adjacent GAs) is admissible for a type if EVERY GA fills a
#    free slot of that type. 2. Among admissible types pick the one filling the
#    most SPECIALTY slots (evidence beyond the universal Swt/Sta pair). Ties go
#    to the simplest type. A lone 1.007 gives Curtain one specialty slot but
#    Curtain cannot hold its 1.001 neighbours — Switch wins on both counts. ---
_CUR_SLOTS = ("Mov", "Mvi", "Stp", "Pos", "Pvi")
_BASE = ("Swt", "Sta")
# Slots the board can actuate. A load needs >=1 anchor — feedback-only
# fragments (lone Bri/Bvi/Trm) are telemetry, not loads.
_ANCHORS = ("Swt", "Dim", "Tuc", "Clc", "Mov", "Stp", "Pos", "Fsc", "Tsp", "Tmc", "Scn")

def _fitTyp(grp):
    """grp: [Ga] raw-sorted. Returns (typ, {slot: addr}) or None."""
    best = None  # (specCount, orderIdx, typ, slots)
    for idx, typ in enumerate(("Switch", "Dimmer", "Tunable", "RGB",
                               "Curtain", "Fan", "HVAC", "Scene")):
        taken: dict = {}
        ok = True
        for g in grp:
            k = _slotIn(typ, g.dpt, taken)
            if not k: ok = False; break
            taken[k] = g.addr
        if not ok: continue
        spec = sum(1 for k in taken if k not in _BASE)
        if best is None or spec > best[0]:
            best = (spec, idx, typ, taken)
    return (best[2], best[3]) if best else None

def clstrGAs(gas, used, devsById, devs):
    """Returns (loads, skips, usedKeys). skips = [(addr, reason)] for non-load GAs."""
    gis = sorted((g for g in gas.values() if g.key not in used), key=lambda g: g.raw)
    def mkRm(g):
        if g.rPath: return " / ".join(g.rPath[-2:]) if len(g.rPath) >= 2 else g.rPath[-1]
        return "Unassigned"
    def mkNm(g): return g.name or g.addr
    loads: list = []
    skips: list = []
    usedK: set = set()
    n = len(gis)
    i = 0
    while i < n:
        j = i
        fit = None
        while j < n:
            # Raw-gap boundary: GAs >4 apart belong to different loads even if
            # DPTs would fit. Without this the window swallows strangers from
            # the next main group and their addresses end up in one load.
            if j > i and gis[j].raw - gis[j - 1].raw > 4: break
            f = _fitTyp(gis[i:j + 1])
            if f is None: break
            fit = f; j += 1
        if fit is None:
            # Single GA no type can hold: measurement/sensor/diagnostic. Audit it.
            skips.append((gis[i].addr, f"DPT {gis[i].dpt or '?'} not a load GA"))
            i += 1
            continue
        typ, slots = fit
        if not any(k in _ANCHORS for k in slots):
            # Feedback-only fragment (e.g. lone 5.001 sensor value): not operable.
            for g in gis[i:j]:
                skips.append((g.addr, f"feedback-only {typ} fragment"))
            i = j
            continue
        loads.append(mkTypLd(typ, slots, mkNm(gis[i]), mkRm(gis[i])))
        for g in gis[i:j]: usedK.add(g.key)
        i = j
    return loads, skips, usedK


# --- ZIP extraction with path-traversal guard. Because unzipping is dangerous. ---
class Xtr:
    def __init__(self, src, out):
        self.src = src.resolve()
        self.out = out.resolve()

    def extract(self):
        if not self.src.is_file(): return False
        try:
            self.out.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(self.src, "r") as zf:
                for mb in zf.namelist():
                    mp = pathlib.Path(mb)
                    tp = (self.out / mp).resolve()
                    if not str(tp).startswith(str(self.out)): raise RuntimeError("traversal")
                    if mp.suffix.lower() == ".xml" or mp.name in ("knx_master.xml", "0.xml"):
                        zf.extract(mb, path=self.out)
            return True
        except Exception: return False


# --- the main pipeline. Long. Linear. No clever abstractions. ---
def convert(p, outDir, audit=False):
    # Extract into a tempdir we own and always purge. No xmls litter on the board.
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="pulsar_"))
    try:
        if not Xtr(p, tmp).extract():
            return {"ok": False, "reason": "extract failed"}
        return _convertInner(p, outDir, audit, tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _convertInner(p, outDir, audit, tmp):
    km = tmp / "knx_master.xml"
    p0s = list(tmp.glob("P-*/0.xml"))
    if not km.is_file() or not p0s: return {"ok": False, "reason": "missing knx_master or P-*/0.xml"}
    # Schema version is encoded in the knx_master root tag namespace.
    sv = 14
    try:
        m = re.search(r"/project/(\d+)\.(\d+)/", ElementTree.parse(str(km)).getroot().tag)
        if m: sv = int(m.group(1)) * 100 + int(m.group(2))  # e.g. 16
    except Exception: pass
    pXml = tmp / p0s[0].parent.name / "project.xml"
    info = rdPrjInfo(pXml if pXml.is_file() else pathlib.Path(""), sv)
    style = info["style"]
    devs, devsById, gas, gaById, spaces, fns = rdP0(p0s[0], style)
    attachD2S(devsById, spaces, devs)
    prods, hw2a = rdHw(tmp)
    apps = rdApps(tmp)
    for d in devs.values(): d.appId = hw2a.get(d.hwId, "")
    # product text keyed by productRefId -> resolve from 0.xml
    try:
        for dev in ElementTree.parse(str(p0s[0])).iter():
            if stNs(dev.tag) != "DeviceInstance": continue
            d = devs.get(dev.get("Address"))
            if d is not None: d.product = prods.get(dev.get("ProductRefId", ""), "")
    except Exception: pass
    for d in devs.values():
        for c in d.cos: resInst(c, d, apps)
    clsDev(devs)
    # Normalize co.links to keys in `gas` (full id, or project-stripped).
    gaM = {gid: g.addr for gid, g in gas.items()}
    for d in devs.values():
        for c in d.cos:
            nl = []
            for l in c.links:
                if l in gaM: nl.append(l); continue
                idx = l.rfind("_GA-")
                if idx >= 0:
                    s = "GA-" + l[idx + 4:]
                    if s in gas: nl.append(s); continue
                if l in gaById: nl.append(gaById[l])
                else: nl.append(l)
            c.links = nl
    aud: list = []   # per-GA disposition
    flat: list = []   # all loads in order
    used: set = set()  # GA keys already assigned to a load
    # 1) <Function> blocks: integrator-defined loads. Authoritative when present.
    for fn in fns:
        rm = {g[0]: g[1] for g in fn["gaRefs"]}
        # accept both full id and short id forms
        for gid, role in list(rm.items()):
            if "_GA-" in gid:
                rm["GA-" + gid.rsplit("_GA-", 1)[1]] = role
        cLst: list = []
        for gid, _ in fn["gaRefs"]:
            for d in devs.values():
                for c in d.cos:
                    if gid in c.links:
                        # Re-stamp flags to honour the Function's explicit role.
                        tc = cInst(refId=c.refId, text=c.text, ftext=c.ftext,
                                   dpts=list(c.dpts), flags=dict(c.flags),
                                   chan=c.chan, links=list(c.links))
                        for k in fK: tc.flags[k] = None
                        if _ == "Control":
                            tc.flags["Communication"] = True; tc.flags["Write"] = True
                        elif _ == "Status":
                            tc.flags["Communication"] = True; tc.flags["Transmit"] = True
                        cLst.append(tc)
        ent = bldLdFrmCmb(fn["name"] or "Function", fn["sPath"], cLst, gaM, functionRole=rm)
        if ent is None:
            aud.append(("function", fn["name"], "no control GA", [g[0] for g in fn["gaRefs"]]))
            continue
        attDef(ent)
        flat.append({k: v for k, v in ent.items() if not k.startswith("_")})
        for gid, _ in fn["gaRefs"]:
            used.add(gid)
            if "_GA-" in gid: used.add("GA-" + gid.rsplit("_GA-", 1)[1])
    # 2) Actuator device channels: per-channel grouping of bound ComObjectInsts.
    for d in sorted(devs.values(), key=lambda x: (x.addr or "")):
        if not d.isAct: continue
        chM: dict = {}  # goi -> [(cid, ctext)]
        for cid, ctext, gois in d.chans:
            for g in gois: chM.setdefault(g, []).append((cid, ctext))
        bC: dict = {}
        for c in d.cos:
            mem = chM.get(c.refId) or chM.get(c.refId.rsplit("_", 1)[-1])
            if mem:
                for cid, ctext in mem: bC.setdefault((cid, ctext), []).append(c)
            else:
                bC.setdefault(("__default__", d.product or d.appId or "Load"), []).append(c)
        for (cid, ctext), cos in bC.items():
            ent = bldLdFrmCmb(ctext or f"{d.product or 'Load'} {d.addr}", d.sPath, cos, gaM)
            if ent is None: continue
            new = [l for c in cos for l in c.links if l not in used and l in gaM]
            if not new and cos:
                # All GAs already used by a Function above; skip duplicate emit.
                if not any(l in gaM for c in cos for l in c.links): continue
            attDef(ent)
            flat.append({k: v for k, v in ent.items() if not k.startswith("_")})
            for c in cos:
                for l in c.links: used.add(l)
            aud.append(("channel", f"{d.addr}/{ctext}", "used", []))
    # 3) GA inventory clustering: type-fitting windows (DPT + adjacency).
    cLds, cSkips, cUsed = clstrGAs(gas, used, devsById, devs)
    used |= cUsed
    for ent in cLds:
        attDef(ent)
        flat.append({k: v for k, v in ent.items() if not k.startswith("_")})
        aud.append(("ga-cluster", ent["ldNm"], "used", []))
    for addr, why in cSkips:
        aud.append(("ga", addr, "skipped", [why]))
    # 4) Audit leftovers. Never silent. The integrator wants to know.
    for gid, g in gas.items():
        if gid in used: continue
        aud.append(("ga", g.addr, "unreferenced" if not g.dpt else "unresolved", []))
    # 5) Group loads into rooms by their resolved Space path.
    rM: dict = {}
    for i, ld in enumerate(flat, start=1):
        rM.setdefault(ld["room"], []).append(i)
    outDir.mkdir(parents=True, exist_ok=True)
    knx = {"prjNm": info["name"], "knxIp": "", "knxPort": 3671,
           "loads": [], "rooms": [{"name": rn, "loads": ls} for rn, ls in rM.items()]}
    for ld in flat:
        e = {"ldNm": ld["ldNm"], "ldTyp": ld["ldTyp"], "gAdd": ld["gAdd"]}
        for ek in ("Kmn", "Kmx", "Tmn", "Tmx", "Smx", "Fst", "Scn"):
            if ek in ld: e[ek] = ld[ek]
        knx["loads"].append(e)
    (outDir / "KNXdata.json").write_text(json.dumps(knx, indent=2, ensure_ascii=False))
    # okas_tuned.json: service.py reads its stats block for logging. Legacy shim.
    (outDir / "okas_tuned.json").write_text(json.dumps(
        {"project_name": info["name"], "group_address_style": style,
         "rooms": [{"name": rn, "loads": []} for rn in rM],
         "flat_loads": [], "stats": {"rooms": len(rM), "loads": len(flat), "gas": len(gas)}},
        indent=2, ensure_ascii=False))
    if audit: (outDir / "audit.json").write_text(json.dumps(aud, indent=2, ensure_ascii=False))
    return {"ok": True, "name": info["name"], "loads": len(flat), "rooms": len(rM),
            "ga_total": len(gas),
            "ga_used": sum(1 for gid in gas if gid in used),
            "ga_unref": sum(1 for r in aud if r[1] == "unreferenced"),
            "ga_unres": sum(1 for r in aud if r[1] == "unresolved")}


def main() -> int:
    ap = argparse.ArgumentParser(description="pulsar: ETS -> Okas")
    ap.add_argument("--knxproj", required=True, help=".knxproj path")
    ap.add_argument("--out-dir", default=".")
    ap.add_argument("--audit", action="store_true", help="also write audit.json")
    # parse_known_args: board service passes legacy flags (--board) we ignore.
    a, _ = ap.parse_known_args()
    p = pathlib.Path(a.knxproj)
    if not p.is_file():
        print(f"not found: {p}", file=sys.stderr); return 2
    r = convert(p, pathlib.Path(a.out_dir), audit=a.audit)
    if not r.get("ok"):
        print(f"failed: {r.get('reason')}", file=sys.stderr); return 1
    print(f"OK {r.get('name','?')}: loads={r['loads']} rooms={r['rooms']} "
          f"ga={r['ga_total']} used={r['ga_used']} "
          f"unref={r['ga_unref']} unres={r['ga_unres']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

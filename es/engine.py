import re
from pathlib import Path

import clips

KB_PATH = Path(__file__).with_name("knowledge_base.clp")
SERVICE_RULES = {"cf-new-hypothesis", "cf-combine"}


class TraceRouter(clips.Router):
    def __init__(self):
        super().__init__("trace", 30)
        self.lines = []

    def query(self, name):
        return name in ("wtrace", "stdout")

    def write(self, name, message):
        self.lines.append(message)


def _new_env():
    env = clips.Environment()
    env.load(str(KB_PATH))
    return env


def _symbol(value):
    return str(value)


def catalog():
    env = _new_env()
    env.reset()
    symptoms = [
        {"code": _symbol(f["code"]), "group": f["group"], "text": f["text"], "applies": _symbol(f["applies"])}
        for f in env.find_template("symptom-info").facts()
    ]
    rules = [{"name": r.name, "source": str(r)} for r in env.rules()]
    templates = [{"name": t.name, "source": str(t)} for t in env.templates() if t.name != "initial-fact"]
    counts = {
        name: len(list(env.find_template(name).facts()))
        for name in ("symptom-info", "fault-info", "part")
    }
    return {"symptoms": symptoms, "rules": rules, "templates": templates, "counts": counts}


def diagnose(vehicle_type, symptoms, mileage=0, battery_age=-1):
    env = _new_env()
    router = TraceRouter()
    env.add_router(router)
    env.eval("(watch rules)")
    env.reset()

    env.find_template("vehicle").assert_fact(
        type=clips.Symbol(vehicle_type), mileage=int(mileage), **{"battery-age": int(battery_age)}
    )
    symptom_tpl = env.find_template("symptom")
    for code in dict.fromkeys(symptoms):
        symptom_tpl.assert_fact(code=clips.Symbol(code))

    fired = env.run()
    router.delete()

    facts = {}
    for f in env.facts():
        facts.setdefault(f.template.name, []).append(f)

    info = {_symbol(f["code"]): f for f in facts.get("fault-info", [])}
    part_order = {(_symbol(p["fault"]), p["name"]): p.index for p in facts.get("part", [])}
    evidence = facts.get("evidence", [])
    recs = facts.get("recommendation", [])
    threshold = env.find_global("threshold").value

    diagnoses = []
    for h in facts.get("fault", []):
        code = _symbol(h["code"])
        fi = info[code]
        diagnoses.append({
            "code": code,
            "name": fi["name"],
            "severity": _symbol(fi["severity"]),
            "advice": fi["advice"],
            "cf": round(h["cf"], 3),
            "accepted": h["cf"] >= threshold,
            "explanation": [
                {"rule": _symbol(e["rule"]), "cf": e["cf"], "text": e["text"]}
                for e in sorted(evidence, key=lambda e: e.index)
                if _symbol(e["fault"]) == code
            ],
            "parts": [
                {"name": r["part"], "category": r["category"]}
                for r in sorted(
                    (r for r in recs if _symbol(r["fault"]) == code),
                    key=lambda r: part_order[(code, r["part"])],
                )
            ],
        })
    diagnoses.sort(key=lambda d: -d["cf"])

    trace = []
    for line in "".join(router.lines).splitlines():
        m = re.match(r"FIRE\s+(\d+)\s+(\S+):\s*(.*)", line.strip())
        if m:
            trace.append({"n": int(m.group(1)), "rule": m.group(2), "facts": m.group(3),
                          "service": m.group(2) in SERVICE_RULES})

    return {
        "threshold": threshold,
        "rules_fired": fired,
        "diagnoses": diagnoses,
        "warnings": [
            w["text"] for w in sorted(
                facts.get("warning", []),
                key=lambda w: [d["code"] for d in diagnoses].index(_symbol(w["fault"])),
            )
        ],
        "conclusions": [c["text"] for c in facts.get("conclusion", [])],
        "trace": trace,
    }

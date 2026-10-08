from flask import Flask, jsonify, request, send_from_directory

from es import engine

app = Flask(__name__, static_folder="static")
CATALOG = engine.catalog()
KNOWN_SYMPTOMS = {s["code"] for s in CATALOG["symptoms"]}


@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.get("/api/catalog")
def catalog():
    return jsonify(CATALOG)


@app.post("/api/diagnose")
def diagnose():
    data = request.get_json(force=True)
    vehicle_type = data.get("type")
    if vehicle_type not in ("car", "moto"):
        return jsonify(error="Укажите тип техники: car или moto"), 400
    try:
        mileage = max(0, int(data.get("mileage") or 0))
        battery_age = int(data.get("battery_age", -1))
    except (TypeError, ValueError):
        return jsonify(error="Пробег и возраст АКБ должны быть целыми числами"), 400
    symptoms = [s for s in data.get("symptoms", []) if s in KNOWN_SYMPTOMS]
    return jsonify(engine.diagnose(vehicle_type, symptoms, mileage, battery_age))


if __name__ == "__main__":
    app.run(port=5050, debug=False)

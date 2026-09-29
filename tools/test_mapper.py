import import_cards as ic

SAMPLE = [
    {"id": "BT1-010", "name": "Agumon", "type": "Digimon", "color": "Red", "level": "3",
     "play_cost": "3", "dp": "3000", "digi_type": "Reptile", "evolution_cost": "2",
     "evolution_color": "Red", "evolution_level": "2", "rarity": "C",
     "set_name": "BT-01: Booster New Evolution", "image_url": "https://x/BT1-010.jpg"},
    {"id": "BT1-010", "name": "Agumon", "type": "Digimon", "color": "Red", "level": "3",
     "rarity": "C", "image_url": "https://x/BT1-010_P1.jpg"},
    {"id": "BT1-001", "name": "Yokomon", "type": "Digi-Egg", "color": "Red", "level": "2"},
    {"name": "sem código"},
]
sets, cards, prints = ic.map_all(SAMPLE)
assert set(cards) == {"BT1-010", "BT1-001"}, cards.keys()
assert sets["BT1"].startswith("BT-01")
ids = {p["id"]: p for p in prints}
assert ids["BT1-010_P1"]["is_alternate"] and not ids["BT1-010"]["is_alternate"]
assert cards["BT1-010"]["level"] == 3 and cards["BT1-010"]["dp"] == 3000
assert cards["BT1-001"]["dp"] is None
print("ok")

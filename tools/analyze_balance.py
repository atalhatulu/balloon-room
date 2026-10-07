#!/usr/bin/env python3
"""Read-only diagnosis of the F1 telemetry JSON (veri.txt)."""

import json
import sys
from pathlib import Path


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Desktop" / "veri.txt"
    if not path.is_file():
        print(f"Telemetry bulunamadı: {path}")
        return 2
    data = json.loads(path.read_text(encoding="utf-8"))
    samples = sorted(data.get("minute_snapshots", []), key=lambda s: s.get("minute", 0))
    print(f"Oturum: {data.get('session_playtime_seconds', 0) / 60:.1f} dk, "
          f"{data.get('total_pops', 0):,} gerçek patlatma, {len(samples)} dakika örneği")
    if len(samples) < 2:
        print("Güvenilir süre ve darboğaz analizi için en az iki dakikalık normal oynanış gerekli.")
        return 0

    room_targets = {"small_room": 15000, "medium_room": 250000,
                    "hangar": 1000000}
    for previous, current in zip(samples, samples[1:]):
        minutes = max(1, int(current.get("minute", 0)) - int(previous.get("minute", 0)))
        popped = int(current.get("pops", 0)) - int(previous.get("pops", 0))
        pop_rate = popped / (60 * minutes)
        spawned = float(current.get("actual_spawn_rate", 0))
        nominal = float(current.get("nominal_spawn_rate", current.get("current_spawn_rate", 0)))
        physical = int(current.get("physical_balloons", 0))
        budget = max(1, int(current.get("physics_budget", 1)))
        expenses = sum(int(e.get("cost", 0)) for e in data.get("timeline_events", [])
                       if int(previous.get("minute", 0)) < int(e.get("minute", -1)) <= int(current.get("minute", 0)))
        collected = int(current.get("coins", 0)) - int(previous.get("coins", 0)) + expenses
        coin_per_pop = collected / popped if popped > 0 else 0.0
        causes = []
        if nominal > 0 and spawned < nominal * 0.75:
            causes.append("üretim nominalin altında")
        if physical >= budget * 0.75:
            causes.append("fizik bütçesi doluyor")
        if spawned > 1 and pop_rate < spawned * 0.70:
            causes.append("patlatma üretime yetişmiyor")
        print(f"Dakika {current.get('minute', 0):>3}: patlatma {pop_rate:>6.1f}/sn, "
              f"üretim {spawned:>6.1f}/{nominal:.1f}/sn, coin/patlatma {coin_per_pop:.2f}"
              + (" | " + ", ".join(causes) if causes else ""))

    recent = samples[-min(6, len(samples)):]
    elapsed = max(1, (int(recent[-1].get("minute", 0)) - int(recent[0].get("minute", 0))) * 60)
    rate = (int(recent[-1].get("pops", 0)) - int(recent[0].get("pops", 0))) / elapsed
    current = samples[-1]
    current_pops = int(current.get("pops", 0))
    room = str(current.get("room", ""))
    target = room_targets.get(room, 1000000)
    if rate > 0:
        print(f"Son pencere hızı {rate:.1f}/sn. Aynı hız sürerse {target:,} eşiğine "
              f"yaklaşık {max(0, target - current_pops) / rate / 60:.1f} dk kalır.")
    else:
        print("Son pencerede ilerleme yok; süre tahmini yapılamıyor.")
    print("Bu tahmin yeni boru, cihaz, oda, oyuncu davranışı ve coin harcamasını öngörmez.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

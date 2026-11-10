"""Lab 1, section 5.1: mean speed and flow against the number of cars, from BehaviorSpace.

Run from the project folder, with the .venv:  .venv\\Scripts\\python lab1\\plot_experiment.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

HERE = Path(__file__).parent
ROAD_CELLS = 100

df = pd.read_csv(HERE / "experiment.csv", skiprows=6)  # the first six lines are the BehaviorSpace header
df = df.rename(columns={"mean [ speed ] of cars": "mean_speed"})
df["flow"] = df["number-of-cars"] / ROAD_CELLS * df["mean_speed"]  # cars passing a point per tick

summary = df.groupby(["p-brake", "number-of-cars"])[["mean_speed", "flow"]].mean().reset_index()

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4))
for p, g in summary.groupby("p-brake"):
    ax1.plot(g["number-of-cars"], g["mean_speed"], marker="o", label=f"p-brake {p}")
    ax2.plot(g["number-of-cars"], g["flow"], marker="o", label=f"p-brake {p}")
ax1.set(xlabel="number of cars (on 100 cells)", ylabel="mean speed at tick 500 (cells/tick)", title="Mean speed")
ax2.set(xlabel="number of cars (on 100 cells)", ylabel="flow = density x mean speed", title="Fundamental diagram")
ax1.legend()
fig.tight_layout()
fig.savefig(HERE / "fundamental-diagram.png", dpi=120)

print("Peak flow per p-brake (mean of 5 runs):")
for p, g in summary.groupby("p-brake"):
    best = g.loc[g["flow"].idxmax()]
    print(f"  p-brake {p}: flow {best['flow']:.2f} at {int(best['number-of-cars'])} cars")

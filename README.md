# Multi-Agent Systems — labs (M2 SIA, 2026–2027)

My work for the labs of the Multi-Agent Systems course (Université Gustave Eiffel). The labs follow one
running example, *a city in motion*: cars on a ring road, a traffic light, and later taxis and travellers.

| Lab | Folder | Tool | What it is |
| --- | --- | --- | --- |
| 1 — Emergence by hand | [`lab1/`](lab1/) | NetLogo 7 | Models Library experiments (Wolf Sheep Predation, Flocking, Segregation), then a Nagel–Schreckenberg ring road with a traffic light, a BehaviorSpace sweep and the fundamental diagram |
| 2 — Agents that talk | [`lab2/`](lab2/) | NetLogo 7 | The lab 1 road with 8 ways for agents to communicate (brake lights, marks, blackboard, unicast, broadcast, publish/subscribe, FIPA-Request), each measured as hard brakes avoided against messages sent |

Each lab folder has its own `README.md` with the results and the answers to the lab's questions.

## Repository layout

```
lab1/
├─ city-in-motion.nlogo     the model (contains the BehaviorSpace experiment "fundamental-diagram")
├─ experiment.csv           BehaviorSpace table: 200 runs
├─ plot_experiment.py       plots experiment.csv -> fundamental-diagram.png
├─ runs/*.txt               the Command Center commands behind every number
├─ measurements.txt         their output
└─ README.md
lab2/
├─ city-talks.nlogo         the model, with the measure procedure
├─ results.csv              one row per value of talk
├─ experiments.txt          commands; output in measurements.txt
├─ extra-checks.txt         checks behind answers 5 and 6; output in extra-checks-output.txt
└─ README.md
tools/
├─ NLRun.java               runs NetLogo commands headless, as if typed in the Command Center
├─ nl.sh                    wrapper: tools/nl.sh <model> < commands.txt
└─ bs.sh                    runs a BehaviorSpace experiment headless: tools/bs.sh <model> <experiment> <table.csv>
```

## Requirements

- [NetLogo 7.0.4](https://www.netlogo.org/download/), installed in `C:\Program Files\NetLogo 7.0.4`
  (edit the path in `tools/nl.sh` otherwise)
- A JDK (17 or newer) to compile the runner, only if you want to re-run the experiments
- Python with `pandas` and `matplotlib`, only for `lab1/plot_experiment.py`

## Opening the models

Open `lab1/city-in-motion.nlogo` or `lab2/city-talks.nlogo` in NetLogo, then press **setup** and **go**. In
lab 2, choose a value of `talk` before **setup**, and type `measure 10` in the Command Center to measure it.

## Reproducing the numbers

The Command Center runs (`runs/*.txt`, `experiments.txt`, `extra-checks.txt`) are seeded with `random-seed`, so
they give the same numbers as the READMEs. The BehaviorSpace sweep is not seeded: re-running it gives a
slightly different `experiment.csv`, with the same shape. Use Git Bash from the repository root.

```bash
# once: compile the headless runner
javac --release 17 -cp "C:/Program Files/NetLogo 7.0.4/app/netlogo-7.0.4.jar" -d tools tools/NLRun.java

# lab 1: the traffic model (sections 3.5, 4, 5.3)
cd lab1 && ../tools/nl.sh city-in-motion.nlogo < runs/city.txt
# lab 1: Models Library (sections 1.1-1.3), e.g.
../tools/nl.sh "C:/Program Files/NetLogo 7.0.4/models/Sample Models/Social Science/Segregation.nlogox" < runs/segregation.txt
# lab 1: the BehaviorSpace sweep (section 5.1) and its plot
../tools/bs.sh city-in-motion.nlogo fundamental-diagram experiment.csv
python plot_experiment.py

# lab 2: every measurement of the lab, then the extra checks
cd ../lab2 && ../tools/nl.sh city-talks.nlogo < experiments.txt
../tools/nl.sh city-talks.nlogo < extra-checks.txt
```

## Main results

- **Lab 1.** Phantom jams appear with no accident and drift backwards. Random dawdling (`p-brake`) seeds them,
  and density decides whether they last. Peak flow is 0.80 at 20 cars with `p-brake` 0, and 0.59 at 15 cars
  with `p-brake` 0.2. The traffic light costs 51 % of the mean speed at 10 cars but only 24 % at 50, when the
  road is already the bottleneck.
- **Lab 2.** Communicating through the environment (marks, the blackboard) cuts hard brakes from 0.86 to about
  0.37 per tick with zero messages. Broadcast reaches 0.41, but at 23.7 messages per tick. With the light on,
  publish/subscribe cuts hard brakes from 0.45 to 0.33 per tick for 1.1 messages per tick. Talking makes driving smoother,
  not faster: the mean speed stays at about 2.0 in every row without a light.

# Lab 2 — Agents that talk (NetLogo)

Names:

NetLogo 7.0.4. The commands I ran are in `experiments.txt` (the Command Center lines of the lab, plus a
`random-seed` so they can be reproduced), and their output is in `measurements.txt`.

| File | What it is |
| --- | --- |
| `city-talks.nlogo` | the lab 1 model, extended through sections 1–5: the `talk` chooser with 8 values, mailboxes, the light's protocols, plus the `measure` procedure of section 1.3. The `arc` link shape is included |
| `results.csv` | the table of section 6 |
| `experiments.txt`, `measurements.txt` | the commands and their output |
| `extra-checks.txt`, `extra-checks-output.txt` | the checks behind answers 5 and 6, and the precise `request` cost |

## Results

Parameters: `number-of-cars` 25, `p-brake` 0.2, `max-speed` 5, `talk-range` 15, `light-period` 30,
`evaporation` 0.2, `p-loss` 0. Each line is `measure 10`, which means 10 runs of 800 ticks, averaged.

| `talk` | light | who is addressed | hard brakes / tick | messages / tick | mean speed |
| --- | --- | --- | --- | --- | --- |
| `none` | off | nobody | 0.86 | 0 | 2.00 |
| `brake lights` | off | whoever looks | 0.71 | 0 | 2.00 |
| `marks` | off | whoever passes | 0.37 | 0 | 1.96 |
| `blackboard` | off | everybody | 0.36 | 0 | 1.98 |
| `unicast` | off | one car | 0.56 | 6.4 | 2.00 |
| `broadcast` | off | all in range | 0.41 | 23.7 | 1.99 |
| `none` | on | nobody | 0.45 | 0 | 1.09 |
| `subscribe` | on | the subscribers | 0.33 | 1.1 | 1.10 |
| `request` | on | the light | 0.67 | 0.043 | 1.50 (ambulance 1.42) |

`measure` prints messages with one decimal, so `request` showed 0. The 0.043 comes from a separate run that
counted `sent` over 10 × 800 ticks.

**How precise is this?** I ran the same `measure 10` twice for the light-off rows, in section 2 and again in
section 6. `none` gave 0.90 then 0.86, and `brake lights` gave 0.78 then 0.71. Ten runs are therefore good to
about ±0.05 hard brakes per tick. Brake lights' small effect is at the edge of that noise. Every other
difference in the table is far larger.

Other measurements:

| experiment | result |
| --- | --- |
| `marks`, `evaporation` 0.05 / 0.2 / 0.5 / 0.8 | 0.14 / 0.35 / 0.40 / 0.89 hard brakes per tick, mean speed 1.71 / 1.96 / 2.01 / 2.02 |
| `unicast`, `p-loss` 0 / 0.5 / 1 | 0.54 / 0.77 / 0.86 hard brakes, 6.3 / 6.0 / 5.7 messages per tick |
| `broadcast`, `p-loss` 0 / 0.5 / 1 | 0.43 / 0.56 / 0.88 hard brakes, 23.2 / 26.8 / 30.1 messages per tick |

## Questions

1. **Which ways reduced the hard brakes most, and at what cost?** Against the baseline of 0.86:

   | `talk` | hard brakes avoided / tick | messages / tick | avoided per message |
   | --- | --- | --- | --- |
   | `blackboard` | 0.50 | 0 | free |
   | `marks` | 0.49 | 0 | free |
   | `brake lights` | 0.15 (within noise) | 0 | free, but almost no effect |
   | `subscribe` (vs 0.45, light on) | 0.12 | 1.1 | 0.11 |
   | `unicast` | 0.30 | 6.4 | 0.047 |
   | `broadcast` | 0.45 | 23.7 | 0.019 |

   Ranked by benefit per message: marks and the blackboard first, since they send no messages at all. Next come
   subscribe, unicast, and broadcast last. Broadcast avoids the most hard brakes of the message-based ways,
   but each message buys the least. One caveat about "free": the blackboard is a global variable that every car
   reads instantly. In a real city it would be a server that every car sends to and polls, so its messages are
   hidden, not absent. It is also a single point of failure.

2. **Brake lights barely help, marks help a lot. What is the difference?** *How far:* a brake light is
   read only by the next car behind, so the news travels one car back per tick. A mark is read by every car
   up to `talk-range` (15) cells ahead of it, so it warns a car that cannot yet see the queue. *How long:* a
   brake light lasts only while the car is stopped. A mark stays where the jam *was* and fades slowly. Because
   a jam moves backwards, a mark left behind is often exactly where the next cars meet the queue. The
   evaporation sweep shows how much the lifetime matters. A mark is read while `warning` > 0.3, and it
   evaporates once in the same tick it is written. So:
   - at `evaporation` 0.8 it falls to 0.2 before anyone reads it. Marks are never heard, and the result
     (0.89) is the baseline;
   - at 0.5 a mark lives 1 tick (0.40);
   - at 0.2 it lives about 5 ticks (0.35);
   - at 0.05 it lives about 23 ticks. Hard brakes drop to 0.14, but cars slow down for jams that dissolved long
     ago, and the mean speed falls to 1.71.

   The best lifetime is a trade-off. Around `evaporation` 0.2, a mark lasts about as long as a jam, keeping
   most of the benefit without costing speed.

3. **Why is driving smoother but not faster?** The mean speed is set by the road's capacity, and that
   depends on the density (25 cars on 100 cells, above the critical density of lab 1) and on rule 3's random
   dawdling. Neither changes when cars talk. A message can only *lower* a car's `advice`, never raise it above
   `max-speed`, and safety still comes from rule 2. What talking changes is *when* a car slows down: earlier and
   by one step at a time, instead of 5 → 0 in one tick. The same queue is reached more gently. If cars are told
   too much, as with marks at `evaporation` 0.05, they slow down for nothing and the mean speed actually drops.

4. **Unicast against broadcast.** *Benefit:* broadcast avoids more hard brakes (0.41 against 0.56). *Cost:*
   it sends 3.7 times the messages (23.7 against 6.4 per tick), and most of them reach cars ahead of the
   jam, for which they are useless. *Robustness:* at `p-loss` 0.5, unicast loses most of its benefit
   (0.54 → 0.77, close to the baseline), while broadcast keeps about half of it (0.43 → 0.56). Unicast news
   hops backwards car by car, so one lost message cuts the chain for every car behind. Broadcast is redundant:
   each car hears from all the stopped cars in range. At `p-loss` 1 both are back to the baseline.
   **Lost messages never cause a crash** because messages only advise. They can lower `advice`, but
   rule 2 (never drive into what you *see* ahead) is applied after it, from perception, in every case.
   Losing a message only means losing the early warning.

5. **Why do broadcast's messages grow with `p-loss`?** `send` counts a message *before* deciding whether it is
   lost, so lost messages still count. And losing warnings creates more of them. I counted cars that *just
   stopped*, which is the event that triggers a broadcast: 2.29 per tick at `p-loss` 0, 2.49 at 0.5, 2.80 at 1.
   Cars that miss the warning arrive at full speed and stop dead, each of those stops broadcasts to about 10
   cars, and messages rise from 22.8 to 29.9 per tick. Less information gets through, which causes more stops,
   which causes more messages.

6. **The conversation of section 5.1.** With the trace line in `send` (`random-seed 7`, light on):

   ```
   tick 51: (car 12) -> (light 25)  request [green]
   tick 52: (light 25) -> (car 12)  agree [green]
   tick 58: (light 25) -> (car 12)  inform [done]
   ```

   - Tick 51: the ambulance (car 12) comes within 15 cells of the light and sends `request`. Its state
     becomes `waiting`.
   - Tick 52: the light reads its mail one tick later (told at *t*, heard at *t* + 1). It answers `agree`,
     turns green, sets `hold?` and publishes.
   - Tick 58: the ambulance has passed the light. The light sends `inform done`, drops `hold?` and returns to
     its cycle.

   A detail in the code: "passed" is tested as `distance-ahead` from the ambulance to the light being greater
   than `talk-range`. Right after the ambulance crosses the light, that distance wraps around to about 99. So
   `done` is sent as soon as the ambulance is past, not once it is 15 cells beyond as the lab text says.

   **If the `agree` were lost:** the light has *already* switched to green and is holding it. Traffic does
   not change. The ambulance stays in `waiting`, but its state does not affect how it drives. It returns to
   `idle` once it is past the light. **If the `request` were lost**, it is worse: the light never holds green,
   and the ambulance, stuck in `waiting`, never asks again on that lap. That is what the deadline of
   section 7, exercise 2, would fix. I did not do the section 7 exercises.

   **A result I did not expect:** with `request`, hard brakes are *higher* than with the light and no talk
   (0.67 against 0.45). I checked where they happen. Within 5 cells before the light: 0.07 against 0.05.
   Everywhere else: 0.58 against 0.41. The light turns red about as often (14.7 against 14.0 red phases per
   800 ticks). So the extra hard brakes are not at the light. My interpretation: holding green for the
   ambulance makes everyone faster (mean speed 1.50 against 1.09), and a car can only drop by 3 or more if it
   is going fast. The three rows agree with that: 0.45 hard brakes at speed 1.09, 0.67 at 1.50, 0.86 at 2.00
   (no light). I have not proven it.

7. **Why does a multi-agent system not use `ask f [ set speed 0 ]`?** Because that is mind control: car 0's
   code runs inside car 1 and changes its state directly. An agent is autonomous. It controls its own
   state and decides what to do with what it is told. `send` only drops a list in a mailbox. The receiver reads
   it at the next tick and decides what it means: a `braking` message only lowers `advice`, and rule 2 still
   has the last word. It is also how real distributed agents work: two cars do not share memory. A message
   takes time, can be lost (`p-loss`) or ignored, and can be counted, which is exactly what the
   `messages / tick` column measures. With `ask`, none of that would exist, and the comparison of this lab
   would be meaningless.

;; A city that talks -- session 3, Multi-Agent Systems, M2 SIA, Universite Gustave Eiffel.
;; The ring road of lab 1 (Nagel and Schreckenberg 1992), plus one way of communicating per value of TALK.

breed [ lights light ]                  ; declared first, so cars are drawn on top of it
breed [ cars car ]
directed-link-breed [ msgs msg ]        ; drawing only: a message sent this tick
directed-link-breed [ subscriptions subscription ]   ; light -> car: "tell me when you change"

globals [ board  sent  hard-brakes ]    ; the blackboard; messages sent and hard brakes this tick
turtles-own [ inbox ]                   ; every agent has a mailbox: a list of messages
patches-own [ warning ]                 ; a mark left on the road; it evaporates
cars-own [ speed  last-speed  advice  odometer  ambulance?  light-phase  switch-at  state ]
lights-own [ hold?  requester ]

to setup
  clear-all
  set board []
  ask patches with [ pycor = 0 ] [ set pcolor gray - 3 ]   ; the road: one lane
  set-default-shape cars "car"
  ask n-of number-of-cars patches with [ pycor = 0 ] [
    sprout-cars 1 [
      set heading 90     ; east, along the road
      set speed 0
      set color white
      set inbox []
      set ambulance? false
      set state "idle"
    ]
  ]
  if traffic-light? or talk = "subscribe" or talk = "request" [
    ask patch 50 0 [
      sprout-lights 1 [ set shape "circle"  set color green  set inbox []  set hold? false ]
    ]
  ]
  if talk = "request" [ ask one-of cars [ set ambulance? true  set color sky ] ]
  reset-ticks
end

to go
  set sent 0
  set hard-brakes 0
  ask msgs [ die ]                                 ; drawing only: last tick's messages and radio waves
  ask patches with [ abs pycor = 1 ] [ set pcolor black ]
  ask lights [ act-light ]
  ask cars [ adjust-speed ]          ; every car listens and decides, from the same picture of the road...
  ask cars [ fd speed  set odometer odometer + speed  recolor ]   ; ...then every car moves...
  ask cars with [ advice < max-speed ] [ ask patch-at 0 -1 [ set pcolor turquoise - 2 ] ]   ; drawing only: who listened
  ask cars [ tell ]                  ; ...then talks: the others hear it at the next tick
  update-environment
  tick
end

;;; driving: the rules of lab 1, with a speed ADVICE coming from what the car heard

to adjust-speed  ; car procedure
  set last-speed speed
  set advice max-speed
  listen                                             ; what the others said may lower ADVICE
  ;; 1. accelerate up to the advice -- or slow down gently towards it
  ifelse speed < advice [ set speed speed + 1 ] [ if speed > advice [ set speed speed - 1 ] ]
  ;; 2. never drive into what is ahead
  let free free-cells-ahead
  if speed > free [ set speed free ]
  ;; 3. sometimes brake for no reason
  if speed > 0 and random-float 1 < p-brake [ set speed speed - 1 ]
  if last-speed - speed >= 3 [ set hard-brakes hard-brakes + 1 ]
end

to-report free-cells-ahead  ; car reporter: empty cells before the next car or red light
  let d 1
  while [ d <= max-speed and not blocked? (patch-ahead d) ] [ set d d + 1 ]
  report d - 1
end

to-report blocked? [ p ]  ; car reporter: is there a car, or a red light, on patch p?
  report any? cars-on p or any? (lights-on p) with [ color = red ]
end

to recolor  ; car procedure: red when stopped, yellow when slowed down, white at full speed
  if ambulance? [ stop ]
  ifelse speed = 0
    [ set color red ]
    [ ifelse speed < max-speed [ set color yellow ] [ set color white ] ]
end

to-report distance-ahead [ x ]  ; turtle reporter: cells from me to column x, driving east
  report (x - pxcor) mod world-width
end

;;; listening: one way of hearing the others per value of TALK

to listen  ; car procedure
  if talk = "brake lights" [ watch-brake-lights ]
  if talk = "marks"        [ smell-marks ]
  if talk = "blackboard"   [ read-board ]
  if member? talk [ "unicast" "broadcast" "subscribe" "request" ] [ read-mail ]
  if talk = "subscribe"    [ follow-light-advice ]
end

to watch-brake-lights  ; signal: is the next car, up to TALK-RANGE cells ahead, showing red?
  let d 1
  while [ d <= talk-range and not any? cars-on patch-ahead d ] [ set d d + 1 ]
  if d <= talk-range and [ color ] of one-of cars-on patch-ahead d = red [ set advice min list advice 2 ]
end

to smell-marks  ; stigmergy: a fresh mark on the road, up to TALK-RANGE cells ahead
  let road-ahead patch-set map [ d -> patch-ahead d ] (range 1 (talk-range + 1))
  if any? road-ahead with [ warning > 0.3 ] [ set advice min list advice 2 ]
end

to read-board  ; blackboard: has a stopped car been posted less than TALK-RANGE cells ahead?
  let near filter [ note -> distance-ahead (first note) <= talk-range ] board
  if not empty? near [ set advice min list advice 2 ]
end

to read-mail  ; car procedure: handle the messages received last tick, then empty the mailbox
  foreach inbox [ m -> handle m ]
  set inbox []
end

to handle [ m ]  ; car procedure: what each message means for me
  let c content-of m
  if first c = "braking" [ set advice min list advice (item 1 c + 1) ]          ; unicast, from the car ahead
  if first c = "jam" and (distance-ahead item 1 c) <= talk-range [ set advice min list advice 2 ]   ; broadcast
  if first c = "phase" [ set light-phase item 1 c  set switch-at item 2 c ]     ; published by the light
  if performative-of m = "agree"  [ set state "agreed" ]                        ; answers to my request
  if performative-of m = "refuse" [ set state "idle" ]
  if performative-of m = "inform" and first c = "done" [ set state "idle" ]
end

to follow-light-advice  ; GLOSA: the light will still be red when I get there, so arrive later instead of stopping
  if light-phase = red and switch-at > ticks [
    let d distance-ahead [ pxcor ] of one-of lights
    set advice min list advice max list 1 floor (d / (switch-at - ticks))
  ]
end

;;; telling: one way of informing the others per value of TALK (heard at the next tick)

to tell  ; car procedure
  let just-stopped? speed = 0 and last-speed > 0
  if talk = "marks"      and speed = 0 [ set warning 1 ]                         ; write on the road
  if talk = "blackboard" and speed = 0 [ set board lput (list pxcor ticks) board ]
  if talk = "unicast"    and speed < last-speed [
    let f follower
    if f != nobody [ send "inform" f (list "braking" speed) ]
  ]
  if talk = "broadcast"  and just-stopped? [ broadcast "inform" (list "jam" pxcor) ]
  if talk = "subscribe" [ manage-subscription ]
  if talk = "request" and ambulance? [ ask-for-green ]
end

to-report follower  ; car reporter: the first car behind me, up to TALK-RANGE cells back
  let d 1
  while [ d <= talk-range and not any? cars-on patch-ahead (- d) ] [ set d d + 1 ]
  report ifelse-value (d <= talk-range) [ one-of cars-on patch-ahead (- d) ] [ nobody ]
end

to manage-subscription  ; car procedure: subscribe to the light when it is near, cancel once past it
  let l one-of lights
  let d distance-ahead [ pxcor ] of l
  if d > 0 and d <= talk-range and not in-subscription-neighbor? l [ send "subscribe" l (list "phase") ]
  if (d = 0 or d > talk-range) and in-subscription-neighbor? l [ send "cancel" l (list "phase")  set light-phase 0 ]
end

to ask-for-green  ; ambulance procedure: the initiator of a FIPA-request
  let l one-of lights
  let d distance-ahead [ pxcor ] of l
  if state = "idle" and d > 0 and d <= talk-range [ send "request" l (list "green")  set state "waiting" ]
  if d > talk-range [ set state "idle" ]           ; past the light: the conversation is over
end

;;; the traffic light: a timer, a mailbox, and the participant side of the protocols

to act-light  ; light procedure: read the mail, then switch -- unless holding green for an ambulance
  foreach inbox [ m -> light-handle m ]
  set inbox []
  ifelse hold?
    [ if [ distance-ahead [ pxcor ] of myself ] of requester > talk-range [   ; the ambulance has passed
        send "inform" requester (list "done")
        set hold? false ] ]
    [ if ticks mod light-period = 0 [ toggle  publish ] ]
end

to light-handle [ m ]  ; light procedure
  let p performative-of m
  let s sender-of m
  if p = "subscribe" [ create-subscription-to s [ set color lime  set shape "arc"  set thickness 0.12 ]  send "inform" s (list "phase" color next-switch) ]
  if p = "cancel" [ let l out-subscription-to s  if l != nobody [ ask l [ die ] ] ]
  if p = "request" [
    ifelse hold?
      [ send "refuse" s (list "green" "busy") ]
      [ send "agree" s (list "green")  set hold? true  set requester s  set color green  publish ]
  ]
end

to toggle  ; light procedure: red becomes green, green becomes red
  ifelse color = red [ set color green ] [ set color red ]
end

to publish  ; light procedure: tell every subscriber my phase and when it ends
  foreach sort out-subscription-neighbors [ c -> send "inform" c (list "phase" color next-switch) ]
end

to-report next-switch  ; light reporter: the tick of the next change
  report ticks + light-period - ticks mod light-period
end

;;; messages: (list performative sender content)

to send [ performative receiver content ]  ; turtle procedure: drop a message in the receiver's mailbox
  set sent sent + 1
  if random-float 1 < p-loss [ stop ]                 ; lost on the way
  let m (list performative self content)
  ask receiver [ set inbox lput m inbox ]             ; the receiver decides later what to do with it
  create-msg-to receiver [ set color yellow  set shape "arc"  set thickness 0.12 ]
end

to broadcast [ performative content ]  ; car procedure: one message to every car within TALK-RANGE
  foreach sort other cars in-radius talk-range [ c -> send performative c content ]
  ask patches with [ pycor = 1 and distance myself <= talk-range ] [ set pcolor sky - 2 ]   ; drawing only
end

to-report performative-of [ m ]  report item 0 m  end
to-report sender-of [ m ]  report item 1 m  end
to-report content-of [ m ]  report item 2 m  end

;;; the environment

to update-environment  ; marks evaporate, old notes leave the board
  ask patches with [ warning > 0 ] [
    set warning warning * (1 - evaporation)
    if warning < 0.05 [ set warning 0 ]
    set pcolor ifelse-value (warning > 0) [ orange - 4.5 + 2 * warning ] [ gray - 3 ]
  ]
  set board filter [ note -> ticks - last note < 2 ] board
  ask patches with [ pycor = 2 ] [ set pcolor black ]
  foreach board [ note -> ask patch (first note) 2 [ set pcolor violet ] ]
end

to-report ambulance-speed  ; mean speed of the ambulance since setup (0 when there is none)
  let a cars with [ ambulance? ]
  report ifelse-value (any? a and ticks > 0) [ [ odometer ] of one-of a / ticks ] [ 0 ]
end

;;; a measuring instrument for the lab (section 1.3), not part of the model

to measure [ runs ]  ; observer procedure: RUNS runs of 800 ticks, averaged
  let hb 0
  let ms 0
  let sp 0
  repeat runs [
    setup
    repeat 800 [ go  set hb hb + hard-brakes  set ms ms + sent  set sp sp + mean [ speed ] of cars ]
  ]
  let n runs * 800
  print (word talk ": " precision (hb / n) 2 " hard brakes / tick, "
    precision (ms / n) 1 " messages / tick, mean speed " precision (sp / n) 2)
end
@#$#@#$#@
GRAPHICS-WINDOW
10
265
918
337
-1
-1
9.0
1
10
1
1
1
0
1
0
1
0
99
-3
3
1
1
1
ticks
30.0

BUTTON
10
10
100
45
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
110
10
200
45
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
10
55
210
88
number-of-cars
number-of-cars
1
90
25.0
1
1
NIL
HORIZONTAL

SLIDER
10
93
210
126
max-speed
max-speed
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
10
131
210
164
p-brake
p-brake
0
0.5
0.2
0.01
1
NIL
HORIZONTAL

SWITCH
10
175
210
208
traffic-light?
traffic-light?
1
1
-1000

SLIDER
10
213
210
246
light-period
light-period
5
100
30.0
5
1
ticks
HORIZONTAL

CHOOSER
220
10
420
55
talk
talk
"none" "brake lights" "marks" "blackboard" "unicast" "broadcast" "subscribe" "request"
0

SLIDER
220
65
420
98
talk-range
talk-range
1
30
15.0
1
1
cells
HORIZONTAL

SLIDER
220
103
420
136
p-loss
p-loss
0
1
0.0
0.05
1
NIL
HORIZONTAL

SLIDER
220
141
420
174
evaporation
evaporation
0
1
0.2
0.05
1
NIL
HORIZONTAL

PLOT
430
10
750
250
mean speed
ticks
cells per tick
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"mean speed" 1.0 0 -16777216 true "" "plot mean [ speed ] of cars"

MONITOR
760
10
910
55
mean speed
mean [ speed ] of cars
2
1
11

MONITOR
760
60
910
105
stopped cars
count cars with [ speed = 0 ]
0
1
11

MONITOR
760
110
910
155
messages / tick
sent
0
1
11

MONITOR
760
160
910
205
hard brakes / tick
hard-brakes
0
1
11

MONITOR
760
210
910
255
ambulance speed
ambulance-speed
2
1
11

@#$#@#$#@
## WHAT IS IT?

The ring road of lab 1 (Nagel and Schreckenberg 1992), with one way for the agents to communicate per value of the TALK chooser:

- none: perception only, as in lab 1;
- brake lights: a signal, the colour of the car ahead;
- marks: stigmergy, stopped cars mark the road and the marks evaporate;
- blackboard: stopped cars post their position on a shared board;
- unicast: a car that slows down sends a message to the car behind;
- broadcast: a car that stops sends a message to every car within TALK-RANGE;
- subscribe: cars near the light subscribe to it, the light publishes its phase (GLOSA);
- request: an ambulance (blue) asks the light for green, FIPA-request style.

## HOW TO USE IT

Choose TALK, press SETUP, then GO. Messages sent during a tick are drawn as yellow arcs and read at the next tick. P-LOSS drops messages at random. Compare MEAN SPEED, HARD BRAKES / TICK and MESSAGES / TICK between the values of TALK.

## CREDITS AND REFERENCES

Session 3 of the Multi-Agent Systems course, M2 SIA, Universite Gustave Eiffel. Builds on lab 1, city-in-motion.nlogo.
Nagel, K. and Schreckenberg, M. (1992). A cellular automaton model for freeway traffic. Journal de Physique I, 2(12), 2221-2229.
FIPA (2002). FIPA ACL Message Structure Specification, SC00061G; FIPA Request Interaction Protocol Specification, SC00026H.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
setup
repeat 180 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

arc
1.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0

@#$#@#$#@
1
@#$#@#$#@

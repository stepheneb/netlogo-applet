; Detergent Model
; Bob Tinker
; copyright the Concord Consortium 2011 under the LGPL open source license
; March 2, 2011

breed [drops drop]
breed [ions ion]
breed [oils oil]
breed [soaps soap]
breed [dots dot]

drops-own [vx vy ]
dots-own [vx vy fx fy owner]   ; the owner is the who of a drop that owns a phospho-lipid, or (if zero) the oil-water surface. 

globals [
  surface     ; y-value of the oil-water surface
  drift       ; the average drift velocity
  running?
  oil-area    ; the total oil area in this model
  oil-top     ; the top of the oil
  impulse     ; a force per cycle applied to dots
  vmax        ; the maximum allowed velocity component
  old-distance ; used with moving magenta dots 
  history      ; this will be used to store the data needed to record a run. 
  mode        ; detemines the mode: running, re-running, setting, finding an event
  old-slider   ; keeps the previous slider position
  current-state  ; 
  rerun-index  ; 
  combine-event?        ; used to tag a frame in which oil drops combine
  merge-event?          ; used to tag a frame in which an oil drop merge with the oil layer
]

to startup 
  ca
  set mode 0   ; start (and restart) in mode 0, which runs the simulation
  set old-slider tape-position   ; read the slider and save its position
  set history [ ] 
  set running? true
  set oil-area 1800  ; the constant oil area
  set oil-top max-pycor - 3
  set surface (max-pycor / 2) - oil-top      ; this is where the horizontal surface appears
  set drift .05                 ; the drift speed of oil and ions toward their preferred location
  set impulse .05             ; controls the acceleration of drops 
  set vmax .1
  draw-patches oil-area         ; draw the background showing air, oil, and water
  create-drops 1 [die]          ; flush out turtle 0 (a hack--  
end  ; I forgot that turtles start with zero and I need 0 to identify dots attached to the surface. )

to draw-patches [oil-in-layer]      ; draw patches that show this amount of oil in the top layer
  let oil-height round (oil-in-layer / (2 * max-pxcor)) ;  This is the vertical hieght of the oil layer
  set surface oil-top - oil-height
  ask patches [
    ifelse pycor >= oil-top [set pcolor white ]
     [ifelse pycor >= surface 
        [set pcolor 48]           ; light yellow
        [set pcolor blue]]]
end

to go            ; this is the main loop--it switches, depending on mode
                 ; 0 = run model. 1 = pause. 2 = re-run  3 = find next event 4 = find previous event 5 = use slider
  if old-slider != tape-position [   ; the modes are set by the corresponding buttons except for the slider
    set old-slider tape-position
    set mode 5]
  if mode = 0 [run-model] 
  if mode = 2 [re-run]
  if mode = 3 [find-next]
  if mode = 4 [find-previous]
  if mode = 5 [use-slider]
end

to run-model  
  every .01  [         ; run this every .01 sec. 
    if running?  [ 
      set tape-position 100
      find-owners      ; teach each soap molecule its owner, the drop to which it is attached, if any 
      drop-dots 
      move-drops
      move-dots]]
  every .02 [save-state]   ; record the state of the system
end

to drop-dots
  let cnum read-from-string mystery-molecule 
  if mouse-down? and mouse-inside? [
      create-dots 1 [                     ; create a mystery particle at the mouse location
        set vx vmax * random-between -1 1
        set vy vmax * random-between -1 1
        set shape "circle"
        set size 4  
        set color cnum
        let x mouse-xcor
        let y mouse-ycor
        setxy x y
        set owner -1
;        set label owner
      ]
    wait .1]
end

to move-dots
  ask dots [
    set fx 0                        ; the dots are subject to various forces 
    set fy 0 ]                      ; the forces are recomputed each cycle
  
  ask dots [                        ; some rules that apply to all dots   
    if ycor > oil-top - 2 [         ; if any dots are too near the top of the oil, aim them down. 
      set vy 0 - abs vy ]           ; set vy negative, even if this is called multiple times
    if ycor < min-pycor + 2 [       ; if any dots are too near the bottom, send them up. 
      set vy abs vy ] 

    ask dots in-radius 4            ; push away other dots
      [ if not (who = [who] of myself) [    ;ignore me
          face myself               ; ask the second dot to face the first
          set fx fx - impulse * sin heading  ; give it an impluse away
          set fy fy - impulse * cos heading
        ]]]
  
  ask drops [                     ; handle dot motion in and out of drops
    ask dots in-radius ( .55  * size ) [   ; talk to dots near each drop
      ifelse color = magenta  [         ; come on in
        let new-distance distance myself
        if new-distance > .4 * [size] of myself and new-distance > old-distance 
           [  ; aim toward center of drop if already inside and moving outward
           face myself 
           set fx fx + impulse * sin heading  ; give it an impluse 
           set fy fy + impulse * cos heading ]
         set old-distance new-distance ]
       [if color = green  [          ; go away from drop
            face myself 
            set heading heading + 180]
          if color = black and ycor < surface [            ; trap them in the boundary
            face myself
            if distance myself < .5 * [size] of myself [
              set heading heading + 180 ]]
      
        set fx fx + impulse * sin heading  ; give it an impluse 
        set fy fy + impulse * cos heading ]]]   
       
  ; move the free magenta dots
  ask dots with [color = magenta][
;    if (ycor < surface + 2)  [         ; if below the surface, move upward, toward the horizontal oil surface
;      set ycor ycor + drift ]
    if ycor > surface and ycor < surface + 1 and vy < 0 [ ; if coming down from above
      set vy 0 - vy ]               ; turn it around
     ]
  
  ; move the green dots into the water
  ask dots with [color = green][
;    if ycor > surface - 2 
;      [set ycor ycor - drift ]
     if ycor < surface and ycor > surface - 1 and vy > 0 [ ; if coming up from below
       set vy 0 - vy ]               ; turn it around
     ]
   
  ; move the black dots to the horizontal interface
  ask dots with [color = black ][
     ifelse owner = 0 [    ; if owned by the horizontal surface
       set vy 0 ]     ; trap the dot at the surface
       [ if ycor > max-pycor / 2 [ set fy .002 * drift ]]]   ; these float upward, helping ensure a soaped horizontal layer

  ; finally, move the dots. 
  ask dots with [owner < 0 ][    ; these are the free-floating dots
    if random 1000 = 0 [         ; every once in a while, hit with a random force direction
      set fx fx + impulse * random-between -1 1 
      set fy fy + impulse * random-between -1 1      
      ]
   advance-dots
    ] 
  
  ask dots with [owner = 0 ][                 ; ask dots on the horizontal surface
    set vy 0 set fy 0
    set vx vx + fx  
    advance-dots]  ; rattle back and forth 
  
  ask dots with [owner > 0 ] [                  ; ask dots owned by a drop
    ask drops with [who = [owner] of myself] [
        ask myself [
           set vx [vx] of myself                ; the dot adopts the velocity of the owner
           set vy [vy] of myself ]]             
   advance-dots ]
end

to advance-dots  ; in dot context, moves dot along
    set vx vx + fx  
    set vy vy + fy 
    if vx < 0 - vmax [set vx 0 - vmax]
    if vx > vmax [set vx vmax]
    if vy < 0 - vmax [set vy 0 - vmax]
    if vy > vmax [set vy vmax]
    set xcor xcor + vx  ; move them
    set ycor ycor + vy 
end

to shake  ; causes drops to be created in the oil layer
  if surface < oil-top [
    create-drops 1 [                      ; create a drop
      set shape "circle"
;      set label who
      set vx drift * random-between -2 2 ;  left or right
      set vy 0 -  drift ;  drift downward
      set color 48
      set size random-between 4 10
      let rad size / 2
      set xcor random-between 0 (2 * max-pxcor)
      set ycor surface + rad
    ] ] 
end
  
to find-owners  ; looks at every black dot and assigns it an owner
  ; this is used in the calculation of the soap-soap repulsion 
  ; an owner of -1 means unowned
  ; an owner of 0 means the dot is at the water-oil surface
  ; an owner of w means that the dot is owned by a drop with a who? of w (w>0)
  ask dots with [color = black] [     
    set owner -1
    ifelse abs (ycor - surface) < .4   ; if it is near the horizontal surface
       [set owner 0 ]
       [               ; if not near the horizontal surface, is it on the surface of any drop?
          ask drops [                    ; check every drop
            let drop-who who             ; save the who of this drop
            let d distancexy ([xcor] of myself) ([ycor] of myself)  ; d is the distance between dot and drop
            if ((abs (d - .5 * size ) < 1) and ([ycor] of myself < surface )) [  ; for black dots on the surface of a drop and below the surface
              ask myself [set owner drop-who ]]]]   ; set the owner of the dot to the who of the drop  
  ]
end                       

to move-drops ; handles the motion of drops
 
  ; first adjust the surface level based on where the drops are
  let area 0    ; add up the area of drops below the surface
  ask drops [
    let drop-area  pi * (size ^ 2) / 4   ; the area of a droplet
    ifelse (ycor  > surface + size / 2 )  [ ] ; if the drop is entirely in the oil, do nothing
      [ifelse (ycor + size / 2 < surface ) [set area area + drop-area ]  ; if it entirely in the water, add the drop area. 
        ; you get here if the droplet is partly in the water, partly in the oil
        [let f (surface - ycor + (size / 2 )) / size    ; calculate the fraction of the drop in the water 
           set area area + drop-area * f ]]]
     ; area now contains the total area of drops. 
     if area < 0 [set area 0 ]
   draw-patches (oil-area - area)  ; redraw that background showing a new oil layer
   
  ; now look for overlapping drops and combine them, preserving area. 
  ask drops [
    ask drops with [who > [who] of myself] [          ; look around for other drops 
     let d distancexy ([xcor] of myself ) ([ycor] of myself )  ; the distance to the other drop
     if d < .4 * (size + ([size] of myself)) [ ; if they overlap by a bit
        let new-size sqrt (size ^ 2 + ([size] of myself ) ^ 2 ) ; the size of the combined droplet
        ask myself [set size new-size]  ; make me bigger
        set combine-event? true           ; this logical is used to tag this frame
        die
        ]]]     ; kill off the other drop
  
  ask drops [  ; kill off drops that are in the oil going upward
    if ((ycor >= surface + .5 * size)  and (vy >= 0 )) [
      set merge-event? true              ; this logical is used to tag this frame
      die
      ]]   ; used to also allow "or (ycor > oil-top - 5))"
  
  ask dots [   ; kick drops apart that have soap molecules between them  *** this stabelizes droplets coated with oil ***
    if any? dots in-radius 2 with [owner != ([owner] of myself) and owner >= 0 ] [   ; if there are any  nearby dots that have some other owner
      ask drops with [who =  [owner] of myself ][         ;  ask my owner to move away 
        face myself                                       ; face me and move away
        let kick .3 * drift                               ; change in velocity per collision
        set vx vx - kick * sin heading                    ; apply a force to part the dot and drop
        set vy vy - kick * cos heading 
        if vx < 0 - vmax [set vx 0 - vmax ]               ; limit the velocity vectors 
        if vx > vmax [set vx vmax]
        if vy < 0 - vmax [set vy 0 - vmax ]
        if vy > vmax [set vy vmax]
        ]]]                               ; 
  
    
  ; add some randomness to the motion and then move the drop
  ask drops [
    if (ycor > oil-top) [die]  ; kill off any drops that get above the oil top
    if (ycor < surface - size / 2) and  ; if the drop is below the surface 
      (( random 1000 ) = 0 )[       ; change direction once in a while
        set vx drift * random-between -2 2
        set vy drift * (random-between -2 2 )]
        if size > 20 and ycor < 0 [ set vy vy + .002 * drift ] ; slowly drift upward if it is big
    ; finally, move the drop    
    set xcor xcor + vx 
    if ycor < min-pycor + size / 2 [
      set vy abs vy ]             ; bounce off the bottom  
    set ycor ycor + vy ]
end
  
to show-molecules   ; converts each dot into a molecule
  ask dots [
    set size 8
    if color = magenta [
      set shape "oil"]
    if color = green [
      set shape "ion"]
    if color = black [
      if abs (ycor - surface) < 3  ; if near the horizontal surface
        [set heading 0
          set shape "soap2"
          set size 10
          ]  
    ]]
  
   ask drops [          ;look for black dots on the surface of drops
     ask dots with [color = black] [
       if abs (distancexy ([xcor] of myself) ([ycor] of myself)) - [size] of myself < .5 [  ; here 'myself' is the drop]
         face myself 
         set shape "soap2"
         ]  
    ]]
    ; fianlly, convert any remaining black dots.
    ask dots with [color = black and shape = "circle" ] [
      set shape "soap2"
      
      ]       
end

to remove-molecules ; get rid of 10% of the molecules of the color selected in the mystery-molecule pull down
  let cnum read-from-string mystery-molecule 
  let n round (count dots with [color = cnum ]) * .1
    repeat n [
      ask one-of dots with [color = cnum ] [die]
    ]
end

to hide-molecules
  ask dots [ set size 4 set shape "circle"]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; tape recorder proceedures ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to save-state  
    ; this will be all the information needed to re-draw a frame using 'history'
    ; and all the information needed to restart the model using 'current-state'
    ; a frame will store a list consisting of information on the drops, dots, and surface level
    ; frame is added to the end of history, the global that records all the history of a run
  let drop-info []
  let full-drop-info []
  ask drops [
    set drop-info lput (list xcor ycor size) drop-info  ; save just the location and size into history
    set full-drop-info lput (list xcor ycor size vx vy) full-drop-info
    ]   
  let dot-info []
  let full-dot-info []
  ask dots [
    set dot-info lput (list xcor ycor color) dot-info    ; save just the location and color
    set full-dot-info lput (list xcor ycor color vx vy fx fy owner) full-dot-info
    ]
  let logicals list combine-event? merge-event?    
  let frame (list surface drop-info dot-info logicals)    ; create a list of all the information on a frame. 
  set history lput frame history                 ; frame becomes the last item in the history
  set current-state (list surface full-drop-info full-dot-info)  ; used to restart the model
  set merge-event? false       ; reset these two flags
  set combine-event? false 
end

to restore-state [i]    ; looks into history and re-draws frame i
  let frame item i history   ; get the right frame, which has all the information needed to re-draw a frame. 
  let surface-level first frame    ; first, redraw the patches 
  ask patches [
    ifelse pycor >= oil-top [set pcolor white ]
     [ifelse pycor >= surface-level 
        [set pcolor 48]           ; light yellow
        [set pcolor blue]]]
  
  let drop-info item 1 frame     ; recreate the drops
  let ndrops length drop-info 
  ask drops [die]
  let j 0
  while [j < ndrops] [
    create-drops 1 [
      let data item j drop-info
      setxy (first data) (item 1 data)
      set size item 2 data
      set color 48 
      set shape "circle" ]
    set j j + 1 ]
  
  let dot-info item 2 frame      ; recreate the dots
  let ndots length dot-info 
  ask dots [die]
  set j 0
  while [j < ndots] [
    create-dots 1 [
      let data item j dot-info
      setxy (first data) (item 1 data)
      set color item 2 data
      set size 4
      set shape "circle" ]
    set j j + 1 ]
  
  set tape-position location-of i
  set rerun-index i
end

to process-rerun              ; the re-run button goes here
  set mode 2
  set rerun-index current-index ; start the rerun at the current tape-position
end

to re-run                              ; in mode 2 this is called from the main loop
  every .02 [                          ; every .02 sec 
    restore-state rerun-index          ; restore the state for rerun-index
    ifelse (rerun-index + 2 >= (length history)) 
      [ set mode 1 ]             ; switch to idle if the last state in history has been restored
      [ set rerun-index rerun-index + 1  ; otherwise advance the rerun index
        set tape-position location-of rerun-index ; 
        set old-slider tape-position  ; needed to avoid switching to mode 5
        ]  
    ]
end

to use-slider                     ;  reads the tape slider and restores the right frame
  if length history > 0 [
    restore-state current-index
    set old-slider tape-position
    wait .01 ]
end

to restart-model  
  set mode 0  ; 
  let surface-level first current-state    ; first, redraw the patches 
  ask patches [
    ifelse pycor >= oil-top [set pcolor white ]
     [ifelse pycor >= surface-level 
        [set pcolor 48]           ; light yellow
        [set pcolor blue]]]
  
  let drop-info item 1 current-state     ; recreate the drops
  let ndrops length drop-info 
  ask drops [die]
  let j 0
  while [j < ndrops] [
    create-drops 1 [
      let data item j drop-info
      setxy (first data) (item 1 data)
      set size item 2 data
      set vx item 3 data
      set vy item 4 data
      set color 48 
      set shape "circle" ]
    set j j + 1 ]
  
  let dot-info item 2 current-state      ; recreate the dots
  let ndots length dot-info 
  ask dots [die]
  set j 0
  while [j < ndots] [
    create-dots 1 [
      let data item j dot-info
      setxy (first data) (item 1 data)
      set color item 2 data
      set vx item 3 data
      set vy item 4 data
      set fx item 5 data
      set fy item 6 data
      set owner last data
      set size 4
      set shape "circle" ]
    set j j + 1 ]
  set tape-position 100
  set old-slider 100
end

to find-next   ; This is mode 3, Advances model to find when drops merge
               ; if one is found, it shows the frame just before merger
  let i 3 + current-index  ; get the index into history for the current tape position slider and advance a few steps
  let stop? false
  while [i < length history and not stop? ] [  ; repeat for all states starting with the current index until a stop is found
                                         ; pull out the current state of the system ...
    let logicals item 3 item i history   ; get is a list of two flags: combine-event? merge-event? 
                                         ; these flags are true if one of these events happened in step i
    set stop? ((merge-type = 1 or merge-type = 3) and first logicals ) or 
      ((merge-type = 2 or merge-type = 3) and last logicals)
    set i i + 1
    ]  ; exit if a stop is found or if none found
  if stop? [ 
    ifelse i > 1 [set i i - 1 ][ set i 0 ]   ; avoid making a negative index
    set tape-position i                      ;  set display to one before the merge event
    restore-state i ]
  set mode 1   ; set to idle
end

to find-previous  ; This is mode 4, Runs model backward to find when drops merge
                 ; if one is found, it shows the frame just before merger
  let i current-index - 3  ; get the index into history for the current tape position slider and advance a few steps
  let stop? false
  while [i >= 0 and not stop? ] [  ; repeat for all states starting with the current index until a stop is found
                                         ; pull out the current state of the system ...
    let logicals item 3 item i history   ; get is a list of two flags: combine-event? merge-event? 
                                         ; these flags are true if one of these events happened in step i
    set stop? ((merge-type = 1 or merge-type = 3) and first logicals ) or 
      ((merge-type = 2 or merge-type = 3) and last logicals)
    set i i - 1
    ]  ; exit if a stop is found or if none found
  if stop? [ 
    ifelse i > 1 [set i i - 1 ][ set i 0 ]   ; avoid making a negative index
    set tape-position i                      ;  set display to one before the merge event
    restore-state i ]
  set mode 1   ; set to idle
end

to step-forward
  set mode 1
  set rerun-index rerun-index + 1
  restore-state rerun-index 
end

to step-backward
  set mode 1
  set rerun-index rerun-index - 1
  restore-state rerun-index 
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; support functions ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report merge-type 
  if (type-of-merge = "Two oil drops merge") [report 1]
  if (type-of-merge = "One drop merges with the surface") [report 2]
  if (type-of-merge = "Both kinds") [report 3]
end

to-report current-index     ; reads the tape position and returns an index that varies from 0 to 100 in steps of .1
  let len length history    ; the length of history runs from 
  report floor ((len - 1 ) * tape-position * .01)
end

to-report location-of [i]     ; returns the location of the Tape-position slider (0-100) given i, the current index into history
  let len length history
  ifelse len > 1 and i < len
   [report precision (100 * i / (len - 1 ) ) 1 ]
   [report 0]
end

to-report random-between [a b] ; returns a number in the range [a, b] inclusive in steps of .01
  let range (100 * ( b - a ) + 1)
  report a + .01 * random range
end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
@#$#@#$#@
GRAPHICS-WINDOW
148
10
783
466
62
42
5.0
1
10
1
1
1
0
1
1
1
-62
62
-42
42
0
0
1
ticks

BUTTON
3
25
80
58
Reset
startup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

CHOOSER
1
272
144
317
Mystery-molecule
Mystery-molecule
"black" "magenta" "green"
0

BUTTON
2
315
145
348
Show Mystery Molecules
set running? false \nshow-molecules
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
82
25
147
58
On
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
2
347
145
380
Hide Mystery Molecules
set running? true \nhide-molecules
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
38
102
105
135
NIL
Shake
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
2
411
145
444
Remove some molecules
Remove-molecules
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
3
478
66
511
Re-run
Process-rerun
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SLIDER
3
511
294
544
Tape-position
Tape-position
0
100
92.6
.2
1
%
HORIZONTAL

BUTTON
327
484
427
517
Find next 
Set mode 3
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
428
484
526
517
Find previous
Set mode 4
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

TEXTBOX
326
468
539
496
Find frames where oil drops merge
11
0.0
1

BUTTON
0
174
75
207
Compute
restart-model
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
75
174
145
207
Pause
set mode 1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

TEXTBOX
26
10
131
28
To start, click \"On\"
11
0.0
1

TEXTBOX
3
74
153
102
\"Shake\" makes oil drops. Each click makes one drop.
11
0.0
1

TEXTBOX
11
147
132
175
Use these to run and stop the model:
11
0.0
1

TEXTBOX
6
229
156
268
Click on the view to make mystry molecules. \nPick the kind here:
11
0.0
1

TEXTBOX
12
544
239
567
Re-run starts at the current tape position. 
11
0.0
1

CHOOSER
526
472
784
517
Type-of-merge
Type-of-merge
"Two oil drops merge" "One drop merges with the surface" "Both kinds"
0

BUTTON
66
478
175
511
Step Forward
step-forward
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
175
477
294
510
Step Backward
step-backward
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

@#$#@#$#@
WHAT IS IT?
-----------
This is a model of detergents designed to have students think about the molecular properties of detergents and why they are effective at dispursing oil.


HOW TO USE IT
-------------
The model starts with a layer of yellow oil floating over blue water. If you shake it, the oil forms droplets in the water. These will recombine with the oil in a while unless you do somenting. 

Three mystery molecules are available. Drop them in the solution by selecting the color of mystery molecule you want, and then clicking on the model. You can explore what the molecules do. 

You can always see what the molecules look like, but that stops the model. Black stringy molecules are hydrocarbons that do not dissolve in water, red charged atoms are ions, that like the highly polarized environment of water.  

THINGS TO TRY
-------------
Try adding lots of molecules and see what their effect is on the oil. 

THINGS TO NOTICE
----------------
Look at how one of the mystery molecules find the surfaces and line up. Why does this stabelize the oil droplets


RELATED MODELS
--------------
This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.


CREDITS AND REFERENCES
----------------------
Copyright 2011 (c) the Concord Consortium. You can use this for any purpose, providing you follow the LGPL license. 
Designed and porgrammed by Robert Tinker for the VISUAL project. 
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

ion
true
0
Circle -2674135 true false 120 105 58
Circle -2674135 true false 118 133 62
Line -16777216 false 135 135 165 135
Line -16777216 false 150 150 150 180
Line -16777216 false 135 165 165 165

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

oil
true
0
Circle -16777216 true false 135 60 30
Circle -16777216 true false 120 15 60
Circle -16777216 true false 120 240 60
Circle -1184463 true false 150 120 30
Circle -16777216 true false 135 90 60
Circle -16777216 true false 135 90 30
Circle -16777216 true false 105 150 60
Circle -16777216 true false 150 150 30
Circle -16777216 true false 165 135 30
Circle -16777216 true false 135 225 30
Circle -16777216 true false 120 210 30

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

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

soap
true
0
Circle -1184463 true false 120 0 30
Circle -1184463 true false 135 60 30
Circle -1184463 true false 135 210 30
Circle -1184463 true false 150 120 30
Circle -1184463 true false 150 105 30
Circle -1184463 true false 135 90 30
Circle -1184463 true false 135 165 30
Circle -1184463 true false 150 150 30
Circle -1184463 true false 165 135 30
Circle -1184463 true false 150 195 30
Circle -1184463 true false 150 180 30
Circle -1184463 true false 135 60 30
Circle -1184463 true false 135 15 30
Circle -1184463 true false 135 45 30
Circle -1184463 true false 150 30 30
Circle -1184463 true false 135 225 30
Circle -2674135 true false 114 234 42
Circle -2674135 true false 129 249 42

soap2
true
4
Circle -1184463 true true 105 210 30
Circle -1184463 true true 120 120 30
Circle -1184463 true true 105 105 30
Circle -1184463 true true 120 90 30
Circle -1184463 true true 120 165 30
Circle -1184463 true true 105 150 30
Circle -1184463 true true 120 135 30
Circle -1184463 true true 120 195 30
Circle -1184463 true true 120 180 30
Circle -1184463 true true 120 60 30
Circle -1184463 true true 105 15 30
Circle -1184463 true true 105 45 30
Circle -1184463 true true 120 30 30
Circle -2674135 true false 84 234 42
Circle -2674135 true false 114 219 42
Circle -1184463 true true 135 75 30
Circle -1184463 true true 180 210 30
Circle -1184463 true true 180 180 30
Circle -1184463 true true 180 165 30
Circle -1184463 true true 180 135 30
Circle -1184463 true true 195 120 30
Circle -1184463 true true 165 150 30
Circle -1184463 true true 180 105 30
Circle -1184463 true true 195 90 30
Circle -1184463 true true 210 75 30
Circle -1184463 true true 180 45 30
Circle -1184463 true true 195 60 30
Circle -1184463 true true 165 15 30
Circle -1184463 true true 165 195 30
Circle -1184463 true true 180 30 30
Circle -2674135 true false 189 219 42
Circle -2674135 true false 159 234 42
Line -16777216 false 90 255 120 255
Line -16777216 false 120 240 150 240
Line -16777216 false 165 255 195 255
Line -16777216 false 135 255 135 225
Line -16777216 false 195 240 225 240
Line -16777216 false 210 255 210 225

soap3
true
4
Circle -1184463 true true 60 15 30
Circle -1184463 true true 135 60 30
Circle -1184463 true true 135 210 30
Circle -1184463 true true 150 120 30
Circle -1184463 true true 150 105 30
Circle -1184463 true true 135 90 30
Circle -1184463 true true 135 165 30
Circle -1184463 true true 150 150 30
Circle -1184463 true true 165 135 30
Circle -1184463 true true 150 195 30
Circle -1184463 true true 150 180 30
Circle -1184463 true true 135 60 30
Circle -1184463 true true 135 15 30
Circle -1184463 true true 135 45 30
Circle -1184463 true true 150 30 30
Circle -1184463 true true 60 210 30
Circle -2674135 true false 114 234 42
Circle -2674135 true false 144 219 42
Circle -1184463 true true 75 30 30
Circle -1184463 true true 75 60 30
Circle -1184463 true true 75 90 30
Circle -1184463 true true 90 105 30
Circle -1184463 true true 90 120 30
Circle -1184463 true true 90 135 30
Circle -1184463 true true 75 150 30
Circle -1184463 true true 60 165 30
Circle -1184463 true true 75 180 30
Circle -1184463 true true 75 195 30
Circle -1184463 true true 60 45 30
Circle -1184463 true true 120 75 30
Circle -1184463 true true 60 75 30
Circle -1184463 true true 60 75 30
Circle -1184463 true true 210 210 30
Circle -1184463 true true 210 180 30
Circle -1184463 true true 195 165 30
Circle -1184463 true true 210 150 30
Circle -1184463 true true 225 135 30
Circle -1184463 true true 225 120 30
Circle -1184463 true true 225 105 30
Circle -1184463 true true 210 90 30
Circle -1184463 true true 195 75 30
Circle -1184463 true true 210 60 30
Circle -1184463 true true 210 45 30
Circle -1184463 true true 210 15 30
Circle -1184463 true true 225 195 30
Circle -1184463 true true 225 30 30
Circle -2674135 true false 219 219 42
Circle -2674135 true false 189 234 42
Circle -2674135 true false 69 219 42
Circle -2674135 true false 39 234 42
Line -16777216 false 60 240 60 270
Line -16777216 false 135 240 135 270
Line -16777216 false 210 240 210 270
Line -16777216 false 150 255 120 255
Line -16777216 false 225 255 195 255
Line -16777216 false 75 255 45 255
Line -16777216 false 255 240 225 240
Line -16777216 false 180 240 150 240
Line -16777216 false 105 240 75 240

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
NetLogo 4.1.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@

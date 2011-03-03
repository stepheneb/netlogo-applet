globals [
  insert-on?   ; tells whether the insert is visible--only happens for an occultation
  insert-size  ; tells the size of the square insert
  old-simulation-speed ; used to store simulation-speed while slowed down for occultation
  G            ; the universal constant in HKS units 
  star-diameter
;  star-mass
  AU 
  sec/yr
  radial-v-data                                ; a list of radial-velocity points each store-interval
  store-interval                               ; the number of seconds between data points in radial-v-data

  mouse-was-up?                                ; needed to call once when the mouse is first clicked
  mousex  mousey                               ; cumulative motion of the mouse
  starting-mousex  starting-mousey             ; starting location of the mouse for the current drag
  phi theta                                    ; the rotation and tilt of the scene
  dist                                         ; the distance from the observer to the star
  old-distance                                 ; stores the old distance to the star
  grid-size
  scale                                        ; the number of patches per AU 
  old-theta                                    ; these remember the angles when a mouse drag event started
  old-phi 

  slow-speed                                   ; simulation speed during occultation
  star new-planet the-arrowhead                ; will store the who of these objects
  delta-t                                      ; the integration step size in years
  first-step?                                  ; when the integration starts, it taks a half-step. This tells whether any step is the first. 
  bread-crumb-lifetime                                 ; the number of years bread-crumbs last
  elapsed-time                                 ; the total amount of time since the last planet-making 
  last-bread-crumb-time                                ; the last time a bread-crumb was left behind
  time/bread-crumb                                     ; how often bread-crumbs are created
  v-scale                                      ; scales the velocity vector so that a velocity of v shows as v-scale * v  distance in the grid
;  old-change-planet
  last-plot-time
  brightness
  new-planet-flag
  planet-mass
  ]

breed [spots]                                 ; grid end-points are used to make the grid
breed [arrowheads arrowhead]                  ; used for velocity vector
breed [bread-crumbs]                          ; used to mark where the planet has been
breed [planets planet]
breed [insert-background]
breed [insert-star]
breed [insert-planet]


planets-own [x-cor y-cor vx vy mass phase w-cor w-vel]  ; the x-y pairs are measured in AU w-cor is measured in screen coords
spots-own [xs ys]                              ; the x-y pairs are measured in AU
bread-crumbs-own [xd yd age]                           ; as they age, they fade away and eventually die
arrowheads-own [xa ya]                         ; the problem coordinats of the arrowhead

to startup
  ca
  ;  set startup variable values
  set insert-on? false                         ; code stest this true around occulations
  set insert-size 2 * max-pycor / 3            ; the patch size of the insert square-- 1/3 of the vertical height
  set G 0 - 2 * 5.922e-5                           ; the universal gravitational constant in AU, years, and earth-mass units
  set AU 1.5e8
  set star-diameter 1.39e6 / AU                ; the star's diameter in AU    
  set sec/yr 3.16e7
  set store-interval 1 / 365.12                ; a day in years 
  set radial-v-data [ ]                        ; this declares it as a list
  set slow-speed .5                             ; simulation speed during occultation
  
  set phi 15
  set theta 65
  set scale 100                                ; in units of patches per AU
  set grid-size 5                              ; total distance from left to right (and top to bottom) of grid
  set old-distance 10                          ; distance to observer (always 2x grid size for reasonable distortion) 
  set distance-to-star 10
  set old-simulation-speed 1
  
  set mouse-was-up? true

  
  set delta-t  .000003                         ; the integration step size in years (gets multiplied by the simulation-speed which goes from 0 to 100. 
  set first-step? true                         ; makes the first integration step a half-step. 
  set bread-crumb-lifetime  3                          ; the number of years bread-crumbs last
  set elapsed-time 0
  set time/bread-crumb .05                             ; the time between bread-crumbs
  set v-scale .3                               ; a multiplier of v to determine the lenght of the velocity vector
  set new-planet-flag false
  set last-plot-time 0
  set brightness 1                             ; default brightness of the star
  
  ; create various turtles
  create-planets 2 [set shape "circle" ]       ; create two 'planets' first
  set star turtle 0                            ; whichever has who=0 is called star
  set new-planet turtle 1                      ; whichever has who=1 is called new-planet
  create-arrowheads 1 [set shape "default" set color red set size 3 ht]
  set the-arrowhead turtle 2

  create-insert-background 1 [ 
    setxy (min-pxcor + insert-size / 2 ) (max-pycor - insert-size / 2 )
    set shape "frame"
    set size  insert-size 
    ht]                                         ; hide for the time being 
  create-insert-star 1 [
    setxy (min-pxcor + insert-size / 2 ) (max-pycor - insert-size / 2 )
    set shape "circle"
    set size insert-size / 2
    set color yellow 
    ht ]
  create-insert-planet 1 [
    set shape "circle 2"
    set color yellow 
    setxy (min-pxcor + insert-size / 2 ) (max-pycor - insert-size / 2 ) 
    ht ]

  new-grid grid-size                             ; creates the grid but doesn't show it
  ask bread-crumbs [ht set label-color black ]
  set dist distance-to-star
  
  ask star [
    set color yellow
    set mass 1.99e30 / 5.97e24  
    setxy 0 0 
    set size 3
    set label "Star " ]
  ask new-planet [
    create-links-with arrowheads
    set color blue
    set size 2 
    set x-cor .707                               ; place it about 1/8 around an orbit
    set y-cor .707
    set vx -2 * pi * .707
    set vy 2 * pi * .707                          ; in astronomical units per year. At r = 1 it travels 2pi AU per year
    let loc (screen-coords x-cor y-cor)
    let u first loc   let v item 1 loc
    if in-view? u v  [ setxy u v ]
    set label "New Planet"
    ]
  set simulation-speed 50
  scale-variables distance-to-star  
  update-screen
end

to go                                            ; this is called from a forever button
  set-planet-mass                                ; read the diameter slider and rocky planet switch to generate the planet mass
  ifelse new-planet-flag                         ; make the program modal depending on the "starting-place" switch
    [ handle-presets 
      set first-step? true ]                     ; when starting a new integration, the first step is special                      
    [ handle-occultation                         ; if the user isn't changing the planet, then run the simulation
      new-angles                                 ; read the mouse and set theta and phi
      do-scale-change                            ; check for scale change
      step-forward-in-time              
      support-graphs
      set first-step? false  ]                   ; reset the first-step detector 
end
                
to handle-occultation                            ; looks for an occultation and sets globals to slow the simulation, show the insert, and warn the user. 
 if near-occ? and not insert-on? [               ; check for an occultation starting
    set old-simulation-speed simulation-speed
    set simulation-speed slow-speed
    set insert-on? true 
    output-print "A transit is coming up!!"
    ifelse planet-diameter > 4.2  
        [output-print "Watch the insert."]
        [output-print "The planet is too small to see."]
    output-print "Simulation slowed" ]
  if insert-on? and not near-occ? [               ; check for an occultation ending
    set simulation-speed old-simulation-speed     ; resume prior speed
    set insert-on? false                          ; remove the insert
    clear-output ]                                ; remove the message about occultation
end

to do-scale-change                                    ; handles scale changes     
  let d 0                                         ; gives d the scope of this proceedure
  ifelse distance-to-star = "From Earth"
    [set d 1e4] [set d distance-to-star]         ; handle string in distance-to-star chooser
  update-scale d
end

to update-scale [d]                              ; handles scale change if needed
  ifelse ( old-distance = d)                     ; check to see whether the distance has changed 
    [                                            ; go here if there is no change in the distance to star
      set dist d                                 ; dist is used in 'screen-coords'  This line is probably unnecessary
      ifelse d <= 500 
        [ update-screen 
          ask spots [st]
          ask arrowheads [st]
          ask bread-crumbs [st]  
          ask planets [st] 
          ask links [show-link]
          ]                          ; draw the grid, only if at 100 AU or close 
        [ ask spots [ht]
          ask arrowheads [ht]
          ask bread-crumbs [ht]  
          ask planets [ht] 
          ask links [hide-link]
          create-spots 1 [st setxy 0 0 set size 1 set color white]
          ]]                         ; grid end-points are used to make the grid

    [                                             ; user changed view. pan to new value and redraw the grid
      let n 50                                    ; in n steps
      set dist old-distance                       ; starting at the old distance
      let dd ( d - old-distance ) / n             ; step size
      ifelse dd > 0                               ; check to see whether the grid is contracting (first option) or expanding (second)
        [                                         ; if contracting (getting farther away), pan first, then redraw
          repeat n [                              ; 
            set dist dist + dd                    ; don't need first step--that's old
            update-screen
          wait .06 ]
          set old-distance d
          set grid-size d / 2                     ; redraw grid with a size that is half the distance to the star. 
;          ask spots [die]                        ; restore this if we hate keeping the smaller grid 
          new-grid grid-size ]
        [                                         ; if expanding (getting closer) redraw first then pan
          set grid-size d / 2                     ; redraw grid with a size that is half the distance to the star. 
          ask spots [die]
          new-grid grid-size 
          repeat n [                              ; 
            set dist dist + dd                    ; don't need first step--that's old
            update-screen
            wait .06 ]
          set old-distance d
        ]                                          ; end of pan
    ; for the new scale, we need new values of time/bread-crumb, bread-crumb-lifetime,  v-scale, and delta-t. They scale as d ^.5
;    scale-variables d
     ]
end
    
to scale-variables [d]
    let f d ^ 1.5
    set bread-crumb-lifetime  .08 *  f            ; the number of years bread-crumbs last
    set time/bread-crumb .0006 *   f              ; the time between bread-crumbs in years
    set v-scale .003 * f
    set delta-t .0000002 * f                      ; the time step, in earth-years                                      
end 

to update-screen                                  ; uses dist, and redraws the star, planet, grid, arrowhead and bread-crumbs.  
    ask spots                                     ; moves grid end-points using the new value of phi and theta
      [ st
        let loc screen-coords xs ys
        let u first loc   let v item 1 loc
        ifelse in-view? u v 
          [setxy u v st]
          [ht ]]
    ask planets [
       let loc screen-coords x-cor y-cor
       let u first loc   let v item 1 loc
       set w-cor last loc                          ; w-cor is the distance in or out of the screen of the planets in patch units. 

       ifelse in-view? u v 
          [setxy u v st]
          [ht ]]
    ask bread-crumbs [
       let loc screen-coords xd yd
       let u first loc   let v item 1 loc
       ifelse in-view? u v 
          [setxy u v st]
          [ht ]
        set age age + delta-t
        if age > bread-crumb-lifetime [die] 
        set color (bread-crumb-lifetime - age ) * 9.9 / bread-crumb-lifetime  ; Starts white, faces to black over bread-crumb-lifetime time. 
          ] 
    ask arrowheads [  
        st
        set xa ([x-cor] of new-planet) + v-scale * ([vx] of new-planet)
        set ya ([y-cor] of new-planet) + v-scale * ([vy] of new-planet )
        set heading 180 + towards-nowrap new-planet  
        let loc screen-coords xa ya
        let u first loc   let v item 1 loc
        ifelse in-view? u v 
          [setxy u v st]
          [ht ]]  
    ifelse insert-on? ; support the insert if the insert condition is on
      [ ask insert-star [st]       ; turn on the inserts
        ask insert-background [st]
        ask insert-planet [
          st 
          set size (insert-size * planet-diameter ) / 218   ; 218 is twice the ratio of sun to earth diameters. Insert-size / 2 is the size of the star
          let x-center min-pxcor + insert-size / 2  ; the center of the insert
          let y-center max-pycor - insert-size / 2 
          let u1 [xcor] of new-planet
          let u2 [xcor] of star
          let v1 [ycor] of new-planet
          let v2 [ycor] of star
          let mag 50 ; magnification of the motion of the planet in the insert
          let du mag * (u1 - u2) ; displacement from center (in insert-screen units)
          let dv mag * (v1 - v2)
          let u x-center + du   ; the insert-planet x-coordinate
          let v y-center + dv   ; the insert-planet y-coordinate
          ifelse in-insert? u v [st setxy u v] [ht]
          ifelse (du ^ 2 + dv ^ 2) < (insert-size / 4 ) ^ 2 ; if the planet is inside the star (which is insert-size / 2 in diameter)
            [set brightness 1 - ( size * 2 / insert-size ) ^ 2 ] ; the drop in brighhtness is the
            [set brightness 1 ]                                             ;    square of the ratio of diameters of the planet and star
        ]]
      [ ask insert-star [ht]           ; turn off inserts
        ask insert-background [ht]
        ask insert-planet [ht]]
end

to-report in-insert? [u v]
  ifelse u > min-pxcor and u < min-pxcor + insert-size
     and v < max-pycor and v > max-pycor - insert-size 
     [report true ][ report false ]
end
  

  
to-report in-view? [u v]        ;tests to see wherther the point u, v can be seen in the view
  let val ( u > min-pxcor and u < max-pxcor
    and v > min-pycor and v < max-pycor )          ; tests whether within the screen
  ifelse insert-on?                                ; further tests are needed if the insert is showing
    [report val and not in-insert? u v ]
    [report val]
end

to set-planet-mass
  let rel-density 1 / 4.13                         ; the relative density of Jupiter compared to Earth
  if rocky-planet [set rel-density 1 ]
  ;  report the mass in terms of the earth's mass
  let pm rel-density * ( planet-diameter ) ^ 3 
  ifelse pm < 30 
     [set planet-mass precision pm 2 ] ; the planet diameter is in multiples of the earth's diameter. The earth mass is 1 
     [set planet-mass round pm ]       ; show decimals only for low masses
  ask new-planet [set mass pm]  
end   

to adjust-planet                                   ; support the mouse as it adjusts the location and speed of the planet
  scale-variables distance-to-star
  if mouse-inside? and mouse-down? [                ; put up velocity vector, support user movements 
             ; first determine whether the planet or the arrowhead is nearer, then move the nearest
     let loc-planet screen-coords ([x-cor] of new-planet) ([y-cor] of new-planet)   
     let loc-arrowhead screen-coords ([xa] of the-arrowhead) ([ya] of the-arrowhead)
     let loc-mouse (list mouse-xcor mouse-ycor 0)
     ifelse dist-between loc-mouse loc-planet < dist-between loc-mouse loc-arrowhead
        [   ; do this block if the planet is closest
            ; convert the screen coordinates of the mouse to problem cooridinates (x, y)
            ; this is simplified because the view is fixed perpendicular to the user. Thus theta is zero and both z and zpp are zero. 
        ask new-planet [
          let u mouse-xcor  let v mouse-ycor
          set x-cor dist  * (u * cos(phi) + v * sin(phi)) / scale   ; this is the inverse transformation from screen coords to problem coords. 
          set y-cor dist  * (v * cos(phi) - u * sin(phi)) / scale ]
        ask arrowheads [ 
         set xa ([x-cor] of new-planet + v-scale * [vx] of new-planet ) 
         set ya ([y-cor] of new-planet + v-scale * [vy] of new-planet  )
         set heading 180 + towards-nowrap new-planet  ]]
        [  ; do this block if the arrowhead is nearest the cursor 
        ask the-arrowhead [
          let u mouse-xcor  let v mouse-ycor
          set xa dist  * (u * cos(phi) + v * sin(phi)) / scale     ; this is the inverse transformation from screen coords to problem coords. 
          set ya dist  * (v * cos(phi) - u * sin(phi)) / scale 
          set heading 180 + towards-nowrap new-planet]
        ask new-planet [                                           ; set its vx and vy
          set vx ([xa] of the-arrowhead  - x-cor ) / v-scale
          set vy ([ya] of the-arrowhead  - y-cor ) / v-scale
        ]]]
  ; I should set the sizes of the star and planet here @@@
  update-screen
end


to-report near-occ?                 ; Tests for occultation. This will result in showing the insert and slowing the simulation
  let u1 [xcor] of new-planet       ; xcor is the horizontal screen location
  let u2 [xcor] of star
  let v1 [ycor] of new-planet       ; xcor is the horizontal screen location
  let v2 [ycor] of star
  let w1 [w-cor] of new-planet      ; this is the distance in or out of the screen toward the user
  let w2 [w-cor] of star
  ifelse (2 * abs (v1 - v2) + abs (u1 - u2)) < .3 and w1 < w2 
    [report true ]       ; if the star and new-planet are near each other
                         ;   and the planet is on the observer's side of the star, an occultation is near. 
    [report false ]      ; 
end

to step-forward-in-time 
  ; moves the planet and star ahead one integration step. Creates bread crumbs. The results are stored in the objects, not shown, yet
  let time-step delta-t * simulation-speed    
  if first-step? [
    ask star [
      set w-cor last screen-coords x-cor y-cor ]      ; initialize w-cor--used for sun velocity and occultation calculations 
      set last-bread-crumb-time 0  ]                  ; initialize the bread-crumb timer 
  ask new-planet [                                    ; standard Euler integration, but with half-step
    set x-cor x-cor + vx * time-step / 2              ; move ahead a half-interval, to get a better average x for the acceleration
    set y-cor y-cor + vy * time-step / 2  
    let factor G * [mass] of star / ( x-cor ^ 2 + y-cor ^ 2 ) ^ 1.5 
    let ax x-cor * factor                             ; note G is negative
    let ay y-cor * factor
    set vx vx + ax * time-step
    set vy vy + ay * time-step
    set x-cor x-cor + vx * time-step / 2              ; move ahead the other half-interval
    set y-cor y-cor + vy * time-step / 2   
    set elapsed-time elapsed-time + time-step ]
  if last-bread-crumb-time + time/bread-crumb
        < elapsed-time [                               ; time to create a new bread-crumb
    set last-bread-crumb-time elapsed-time             ; used to be "last-bread-crumb-time + time/bread-crumb"
    create-bread-crumbs 1 [
      set shape "dot"
      set size 1
      set color orange
      set age 0
      set xd [x-cor] of new-planet
      set yd [y-cor] of new-planet ]]
  ask star [
    let rho 0 - [mass] of new-planet / mass             ; the ratio of the massses of the star and planet determine the star's distance from 0,0
    set x-cor rho * [x-cor] of new-planet 
    set y-cor rho * [y-cor] of new-planet 
    set vx rho * [vx] of new-planet
    set vy rho * [vy] of new-planet 
    let old-w-cor w-cor
    set w-cor last screen-coords x-cor y-cor            ; calculate the apparent motion away from the viewer
    set w-vel (w-cor - old-w-cor ) / time-step
    ]
  ask bread-crumbs [set age age + time-step ]
end

to select-circular-velocity   ; reads the current distance and computes a velocity that would result in a circular orbit. 
  ask new-planet [
    let x x-cor
    let y y-cor
    let a atan x y
    let d sqrt (x-cor ^ 2 + y-cor ^ 2) ; the distance to the CofM. 
    ; for d = 1, v = 2pi. I think v will scale as sqrt d 
    let v 2 * pi / sqrt d 
    set vx 0 - v * cos a
    set vy v * sin a ]
  update-screen   ; get the result shown
end

to support-graphs
  ; the radial velocity is stored in the sun as w-vel
  ask star [
    ifelse first-step?  
      [ clear-all-plots
        set elapsed-time 0
        set last-plot-time 0 
        set last-bread-crumb-time 0
;        ask bread-crumbs [die]  ; perhaps it is nice to leave the old breadcrumbs to die slowly, so the user can see the old orbit. 
        ]
      [let time-step  delta-t * simulation-speed
        let plot-interval .002
        if insert-on? [set plot-interval .0001 ]
        let b brightness
        if elapsed-time > last-plot-time + plot-interval [ ; permits one plotted point every .002 year except during transit 
          set last-plot-time elapsed-time
          let v w-vel
          if noise? [
            set v w-vel + .3 * rand-noise / telescope-precision 
            set b brightness + 2 * rand-noise / telescope-precision ]
          set-current-plot "Velocity of Star Away From Viewer"
          plotxy elapsed-time  v 
          set-current-plot "Light Intensity"
          plotxy elapsed-time b ]
      ]]
end

to handle-presets                                       ; sets up the planet parameters for the preset condition

  ifelse Preset-planets = "None. Set with mouse."  
     [ set theta 0                                        ; force a planar view by calling update once with this angle
       adjust-planet                                      ; allow user to adjust the planet 
       do-scale-change  ]       
     [ ask new-planet [
        if Preset-planets = "Earth" [                     ; remember: mass in earth-masses, distances in AU, time in years
          set x-cor 1 / sqrt 2                            ; starts this off 45¡ around the orbit
          set y-cor 1 / sqrt 2
          select-circular-velocity                        ; computes vx and vy for a circular orbit at this radius
          set distance-to-star 5                          ; should be about 5x the orbital radius
          set planet-diameter 1                           ; the earth is one earth diameter!!
          set rocky-planet true]
      if Preset-planets = "Mars" [   
          set x-cor 1.5 / sqrt 2
          set y-cor 1.5 / sqrt 2
          select-circular-velocity
          set distance-to-star 10
          set planet-diameter precision (.107 ^ .3333) 3       ; the diameter sets the mass, so this reverses the process, computing the diameter that would get .107 earth masses
          set rocky-planet true]
      if Preset-planets = "Jupiter" [ 
          set x-cor 5.2 / sqrt 2
          set y-cor 5.2 / sqrt 2
          select-circular-velocity
          set distance-to-star 20
          set planet-diameter precision ((4.13 * 10.5) ^ .3333) 3       ; the diameter sets the mass, so this reverses the process, computing the diameter that would get .107 earth masses
          set rocky-planet false]
      if Preset-planets = "Venus" [   
          set x-cor .728 / sqrt 2
          set y-cor .728  / sqrt 2
          select-circular-velocity
          set distance-to-star 5
          set planet-diameter precision (.815 ^ .3333) 3       ; the diameter sets the mass, so this reverses the process, computing the diameter that would get .107 earth masses
          set rocky-planet true ]
      if Preset-planets = "Like Mercury but 10x larger diameter" [   
          set x-cor .467 / sqrt 2
          set y-cor .467  / sqrt 2
          select-circular-velocity
          set distance-to-star 2
          set planet-diameter precision (55 ^ .3333) 3       ; the diameter sets the mass, so this reverses the process, computing the diameter that would get .107 earth masses
          set rocky-planet true ]
      if Preset-planets = "Like Earth but 10x larger diameter" [   
          set x-cor 1 / sqrt 2                            ; starts this off 45¡ around the orbit
          set y-cor 1 / sqrt 2
          select-circular-velocity                        ; computes vx and vy for a circular orbit at this radius
          set distance-to-star 5                          ; should be about 5x the orbital radius
          set planet-diameter 10                           ; the earth is one earth diameter!!
          set rocky-planet true]
      if Preset-planets = "Earth-like planet near the star" [   
          set x-cor .2 / sqrt 2
          set y-cor .2  / sqrt 2
          select-circular-velocity
          set distance-to-star 1
          set planet-diameter 1       ; the diameter sets the mass, so this reverses the process, computing the diameter that would get .107 earth masses
          set rocky-planet true ]
      if Preset-planets = "Large rocky planet very near the star" [ 
          set x-cor .1 / sqrt 2
          set y-cor .1  / sqrt 2
          select-circular-velocity
          set distance-to-star 1
          set planet-diameter 50      ; the diameter sets the mass, so this reverses the process, computing the diameter that would get .107 earth masses
          set rocky-planet true ] 
     scale-variables distance-to-star ]]
end

to-report rand-noise ; makes a bell-shaped distribution w/ sd = 1
  report ((random 11 + random 11 + random 11 + random 11 + random 11 ) - 25 ) / 15 ; a normal distribution around zero with a sd of about 1
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;  general mouse rotation proceedures ;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report screen-coords [x y]     ; given phi, theta, scale, and dist (the distance to the observer in problem units), the grid-size (in problem units) 
                                  ;         this returns u v in screen coordinates 
   let cphi cos(phi)              ; assuming the sin and cos calculations are slow, these two steps save looking them up twice. 
   let sphi sin(phi)
   let xpp x * cphi - y * sphi    ; rotate around the z-axis to the prime coordinates
   let yp x * sphi + y * cphi
   let ypp yp * cos(theta)        ; rotate around the x-axis to the prime-prime coordinates in which the observer is on the z-axis at infinity. 
   let zpp yp * sin(theta) 
   let u scale * xpp / (dist + zpp )      ; this compensates for distortion for small values of dist
   let v scale * ypp  / (dist + zpp )     ; scale has units of (patch size) / (problem distance units)   
;   every .2 [output-print (list theta "  " phi)]
   report (list u v zpp)
end

to new-angles   ; supports the mouse and sets new values for the globals theta and phi
  if mouse-down? and mouse-inside? [         ; ignore if the mouse is not down inside the view
    if mouse-was-up? [                       ; detect the first time the mouse is clicked
       set mouse-was-up? false               ; reset the mouse-was-up? logical                  
       set starting-mousex mouse-xcor        ; set the starting location of the mouse from which changes will be accumulated
       set starting-mousey mouse-ycor
       set old-phi phi                       ; remember the theta and phi when the mouse was pressed
       set old-theta theta]
    let dmx mouse-xcor - starting-mousex      ; the amount added this mouse-down is (mouse-xcor - starting-mousex)
    let dmy mouse-ycor - starting-mousey
    set phi old-phi + dmx * 360 / (max-pxcor - min-pxcor)   ; this gives a 360 rotation for a movement across the view
    set theta old-theta + dmy * 180 / (max-pycor - min-pycor)   ; this gives a 180 rotation for a movement up or down the view
    if theta > 90 [set theta 90]              ; constrain theta to between 0 and 90
    if theta < 0 [ set theta 0 ]
    ]   
 if (not mouse-down? and not mouse-was-up?) [ ; detect the first time the mouse was released after being down
   set mouse-was-up? true ]                   ; set the mouse-was-up? logical
end

to new-grid [dia]              ; creates a 10x10 grid of total extent dia. Grid spacing is dia/10
  let rad dia / 2
  let spacing dia / 10         ; Grid spacing is dia/10
    let x 0 - rad              ; first make grid lines parallel to the x-axis
    let y 0 - rad
    let s false       ; show every other grid label
    while [x <= rad] [
      create-spots 1 [
        set xs x 
        set ys y
        if s [
          set label precision x 2]
        set s not s
        ]  ; toggle show-label
      set x x + spacing ]
    set x 0 - rad
    set y rad
    while [x <= rad] [
      create-spots 1 [
        set xs x 
        set ys y 
        create-links-with spots with [xs = x and ys = 0 - rad]]
      set x x + spacing ]
    
    set x 0 - rad
    set y 0 - rad
    set s false       ; show every other grid label
    while [y <= rad] [
      create-spots 1 [
        set xs x 
        set ys y
        if s [
          set label precision y 2 ]
        set s not s
        set y y + spacing ]]
    set x rad
    set y 0 - rad
    while [y <= rad] [
      create-spots 1 [
        set xs x 
        set ys y 
        create-links-with spots with [xs = 0 - rad and ys = y]]
      set y y + spacing ]
      ask spots [set size .01 set label-color gray]  ; I don't care about the spots, just the lines between them
end

to-report dist-between [a b]   ; a and b are lists of x, y, z values; z is ignored
  report sqrt ((first a - first b) ^ 2 + (item 1 a - item 1 b) ^ 2)
end
@#$#@#$#@
GRAPHICS-WINDOW
260
10
847
508
52
42
5.5
1
10
1
1
1
0
0
0
1
-52
52
-42
42
0
0
0
ticks

BUTTON
169
12
235
45
reset
startup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SLIDER
5
162
257
195
planet-diameter
planet-diameter
.2
50
3.513
.2
1
earth diameters
HORIZONTAL

PLOT
6
206
259
354
Velocity of Star Away From Viewer
Time (years)
NIL
0.0
1.0E-12
-1.0E-8
1.0E-8
true
false
PENS
"default" 1.0 0 -16777216 true

CHOOSER
6
83
149
128
Distance-to-star
Distance-to-star
1 2 5 10 20 50 100 200 "From Earth"
3

SLIDER
25
537
245
570
telescope-precision
telescope-precision
5
50
50
1
1
NIL
HORIZONTAL

PLOT
6
353
258
501
Light Intensity
Time (years)
NIL
0.0
1.0E-12
0.95
1.05
true
false
PENS
"default" 1.0 0 -16777216 true

SLIDER
6
50
256
83
Simulation-speed
Simulation-speed
1
100
50
1
1
NIL
HORIZONTAL

SWITCH
6
128
148
161
Rocky-planet
Rocky-planet
1
1
-1000

OUTPUT
265
509
583
591
12

BUTTON
35
12
119
45
Run/Pause
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

CHOOSER
592
542
846
587
Preset-Planets
Preset-Planets
"None. Set with mouse." "Earth" "Mars" "Jupiter" "Venus" "Like Mercury but 10x larger diameter" "Like Earth but 10x larger diameter" "Earth-like planet near the star" "Large rocky planet very near the star"
0

BUTTON
7
505
136
538
Reset graphs
set first-step? true\nset elapsed-time 0
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SWITCH
136
504
258
537
Noise?
Noise?
1
1
-1000

BUTTON
675
510
762
543
Make circular
select-circular-velocity
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
592
510
676
543
New Planet
set new-planet-flag true
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
763
509
846
542
Resume
set new-planet-flag false
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

MONITOR
160
99
245
144
Planet Mass
Planet-Mass
17
1
11

@#$#@#$#@
WHAT IS IT?
-----------
This software allows you to explore how star-planet systems outside the solar system can be identified. It allows you to create different planets orbiting a star like our sun. These systems can be identified from Earth in two ways:

1) The wobble that the planet causes in the star can be detected. This involves detecting slight changes in the location of spectral lines in the light from the star due to the Doppler shift caused by the wobble. 
2) Dimming of the light from the star when the planet passes in front of the star, called a transit or occultation. 

This software calculates both these signals for any size of any orbiting planetÑthe wobble and the drop of light level. 

Real instruments on Earth cannot necessarily see these signals because any measurement necessarily is accompanied by noiseÑunwanted random variations in the signal. One way to reduce this noise is to use a bigger, more precise telescope. This model allows you to see the signal without noise and with an amount of noise that depends on the precision of the telescope. 


HOW TO USE IT
-------------
Press Run/Pause to start. You will see an earth-like planet orbiting a star. You can leave this button in the ÒRunÓ position. 

You can drag the cursor over the grid to change the viewing angle while the planet orbits. You can look at the system straight down, edge on or anything between. 

When the planet passes in front of the star, a magnified insert pops up and the model slows way down so you can see the transit. Earth is too small to see at this scale, but slide the planet diameter slider up to 4.5 or larger, an you can see the planet to scale during the transit. Note that the simulation speed is automatically slowed down during the transit--otherwise it would be too fast to see.

If you select a large diameter planet, you can see the star wobbling, too. The simulation shows both the planet and star orbiting around the center of mass.

All the time you are playing, the two graphs are busy. The result can be a mess because of noise. Turn off 'noise?' (just below the graph) and click on 'Reset Graphs' (also below). Now you can see what the graphs would look like if there was no noise. Too bad scientists donÕt have a noise switch like this!!

The upper graph shows the "proper" motion of the star--that is the motion away from you, the viewer. Note that if you look straight down on the grid (drag your mouse downward) there is no proper motion--the graph is flat. Do you understand why?

For most planets and viewing angles, the upper graph goes up and down as the planet orbits. But look at the scale. The actual amplitude can vary enormously. Earth gives 2e-5. A monster planet 50x Earth's diameter (125,000 x its mass) gives an amplitude of 2.5, more than 100,000 times larger. The significance of this is apparent if you turn on the noise. The normal Earth is invisible in the noise, but the monster is hardly effected.

The issue here as is common throughout research is the signal-to-noise ratio. You can just about see the signal for a planet 4x the Earth's diameter. Note: reset the graphs each time you change the diameter.

You can explore whether a closer planet would generate a larger signal. To experiment with a different planet, press the ÒNew PlanetÓ button in the lower right. This stops the simulation and allows you to select a preset planet or make one of your own. 

You can use the ÒPreset-PlanetsÓ pull-down menu to select a planet and to make your own. Several kinds of planets have been pre-loaded that you use to explore the signals they would make. 

If you select ÒNone. Set with mouse.Ó This automatically sets a straight-down view and allows you to use the mouse to move the planet or the tip of its velocity vector. It is sometimes hard to select a velocity that doesnÕt cause the planet to zoom away or crash into the sun. To simplify this, there is a 'Make circular' that generates a velocity that gives a circular orbit.

You can also change the ÒDistance-to-starÓ to make planets with small or large orbits. It is easy to loose the planet off-screen if you are not careful. If the planet is lost, you can always hit 'reset' to start over or use the Preset-Planets button

The lower graph shows the star's brightness, which only changes during a transit of the planet. First look at it with no noise and then experiment with orbits and masses that give a signal that you can see.


THINGS TO NOTICE
----------------
By exploring this model, you can answer the following questions:

1. What is the origin of a starÕs wobble? What kinds of planet result in the greatest wobble? 
2. What kinds of planets and inclinations are necessary to detect the wobble?
3. Under what conditions is there a drop in star intensity? 
4. In this model, what is the smallest planet that causes enough wobble to be detected above the noise?
5. In this model, what is the smallest planet that causes enough drop in start intensity to be detected above the noise?
6. Estimate the fraction of star-planet systems with large planets that we can detect through intensity drop and through wobble? 
7. Why have most planets detected so far been too large to support life? 



CREDITS AND REFERENCES
----------------------
Created by Bob Tinker
October 2010
Design assistance by Dan Damelin
This software is available under the GNU open srouce license. 
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
Circle -16777216 true false 15 15 270

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

frame
false
0
Rectangle -1 false false 0 0 300 300

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

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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

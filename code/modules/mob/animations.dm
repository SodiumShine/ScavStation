/*
adds a dizziness amount to a mob
use this rather than directly changing var/dizziness
since this ensures that the dizzy_process proc is started
currently only humans get dizzy

value of dizziness ranges from 0 to 1000
below 100 is not dizzy
*/

/mob/var/dizziness = 0//Carbon
/mob/var/is_dizzy = 0

/mob/proc/make_dizzy(var/amount)
	if(!istype(src, /mob/living/carbon/human)) // for the moment, only humans get dizzy
		return

	dizziness = min(1000, dizziness + amount)	// store what will be new value
													// clamped to max 1000
	if(dizziness > 100 && !is_dizzy)
		spawn(0)
			dizzy_process()


/*
dizzy process - wiggles the client's pixel offset over time
spawned from make_dizzy(), will terminate automatically when dizziness gets <100
note dizziness decrements automatically in the mob's Life() proc.
*/
/mob/proc/dizzy_process()
	is_dizzy = 1
	while(dizziness > 100)
		if(client)
			var/amplitude = dizziness*(sin(dizziness * 0.044 * world.time) + 1) / 70
			client.pixel_x = amplitude * sin(0.008 * dizziness * world.time)
			client.pixel_y = amplitude * cos(0.008 * dizziness * world.time)

		sleep(1)
	//endwhile - reset the pixel offsets to zero
	is_dizzy = 0
	if(client)
		client.pixel_x = 0
		client.pixel_y = 0

// jitteriness - copy+paste of dizziness
/mob/var/is_jittery = FALSE
/mob/var/jitteriness = 0//Carbon

/mob/proc/make_jittery(var/amount)
	return //Only for living/carbon/human/

/mob/living/carbon/human/make_jittery(var/amount)
	if(jittery_damage())
		jitteriness = Clamp(jitteriness + amount, 0, 1000)
		if(jitteriness > 100)
			jittery_process()

// Typo from the original coder here, below lies the jitteriness process. So make of his code what you will, the previous comment here was just a copypaste of the above.
/mob/proc/jittery_process()
	set waitfor = 0
	if(is_jittery)
		return
	is_jittery = TRUE
	while(jitteriness > 100)
		var/amplitude = min(4, jitteriness / 100)
		do_jitter(amplitude)
		sleep(1)
	//endwhile - reset the pixel offsets to zero
	is_jittery = FALSE
	do_jitter(0)

/mob/proc/do_jitter(amplitude)
	pixel_x = default_pixel_x + rand(-amplitude, amplitude)
	pixel_y = default_pixel_y + rand(-amplitude/3, amplitude/3)

//handles up-down floaty effect in space and zero-gravity
/mob/var/is_floating = 0
/mob/var/floatiness = 0

/mob/proc/update_floating()

	if(anchored || buckled || has_gravity())
		make_floating(0)
		return

	if(check_space_footing())
		make_floating(0)
		return

	make_floating(1)
	return

/mob/proc/make_floating(var/n)
	floatiness = n

	if(floatiness && !is_floating)
		start_floating()
	else if(!floatiness && is_floating)
		stop_floating()

/mob/proc/start_floating()

	is_floating = 1

	var/amplitude = 2 //maximum displacement from original position
	var/period = 36 //time taken for the mob to go up >> down >> original position, in deciseconds. Should be multiple of 4

	var/top = default_pixel_z + amplitude
	var/bottom = default_pixel_z - amplitude
	var/half_period = period / 2
	var/quarter_period = period / 4

	animate(src, pixel_z = top, time = quarter_period, easing = SINE_EASING | EASE_OUT, loop = -1)		//up
	animate(pixel_z = bottom, time = half_period, easing = SINE_EASING, loop = -1)						//down
	animate(pixel_z = default_pixel_z, time = quarter_period, easing = SINE_EASING | EASE_IN, loop = -1)			//back

/mob/proc/stop_floating()
	animate(src, pixel_z = default_pixel_z, time = 5, easing = SINE_EASING | EASE_IN) //halt animation
	//reset the pixel offsets to zero
	is_floating = 0

/atom/movable/proc/do_attack_animation(atom/A, atom/movable/weapon)

	var/pixel_x_diff = 0
	var/pixel_y_diff = 0
	var/direction = get_dir(src, A)
	switch(direction)
		if(NORTH)
			pixel_y_diff = 8
		if(SOUTH)
			pixel_y_diff = -8
		if(EAST)
			pixel_x_diff = 8
		if(WEST)
			pixel_x_diff = -8
		if(NORTHEAST)
			pixel_x_diff = 8
			pixel_y_diff = 8
		if(NORTHWEST)
			pixel_x_diff = -8
			pixel_y_diff = 8
		if(SOUTHEAST)
			pixel_x_diff = 8
			pixel_y_diff = -8
		if(SOUTHWEST)
			pixel_x_diff = -8
			pixel_y_diff = -8

	var/default_pixel_x = initial(pixel_x)
	var/default_pixel_y = initial(pixel_y)
	var/mob/mob = src
	if(istype(mob))
		default_pixel_x = mob.default_pixel_x
		default_pixel_y = mob.default_pixel_y

	animate(src, pixel_x = pixel_x + pixel_x_diff, pixel_y = pixel_y + pixel_y_diff, time = 2)
	animate(pixel_x = default_pixel_x, pixel_y = default_pixel_y, time = 2)

/mob/do_attack_animation(atom/A, atom/movable/weapon)
	..()
	is_floating = 0 // If we were without gravity, the bouncing animation got stopped, so we make sure we restart the bouncing after the next movement.

	// What are we attacking with?
	if(!weapon)
		weapon = get_active_hand()
		if(!weapon)
			return

	// Create an image to show to viewers.
	// Reset plane and layer so that it doesn't inherit the UI settings from equipped items.
	var/image/I = new(loc = A)
	I.appearance = weapon
	I.plane = DEFAULT_PLANE
	I.layer = A.layer + 0.1
	I.pixel_x = 0
	I.pixel_y = 0
	I.pixel_z = 0
	I.pixel_w = 0

	// Who can see the attack?
	var/list/viewing = list()
	for(var/mob/M in viewers(A))
		if(M.client)
			viewing |= M.client
	flick_overlay(I, viewing, 5) // 5 ticks/half a second

	// Scale the icon.
	I.transform *= 0.75
	// Set the direction of the icon animation.
	var/direction = get_dir(src, A)
	if(direction & NORTH)
		I.pixel_y = -16
	else if(direction & SOUTH)
		I.pixel_y = 16

	if(direction & EAST)
		I.pixel_x = -16
	else if(direction & WEST)
		I.pixel_x = 16

	if(!direction) // Attacked self?!
		I.pixel_z = 16

	// And animate the attack!
	animate(I, alpha = 175, pixel_x = 0, pixel_y = 0, pixel_z = 0, time = 3)

/mob/proc/spin(spintime, speed)
	spawn()
		var/D = dir
		while(spintime >= speed)
			sleep(speed)
			switch(D)
				if(NORTH)
					D = EAST
				if(SOUTH)
					D = WEST
				if(EAST)
					D = SOUTH
				if(WEST)
					D = NORTH
			set_dir(D)
			spintime -= speed
	return

/mob/proc/phase_in(var/turf/T)
	if(!T)
		return

	playsound(T, 'sound/effects/phasein.ogg', 25, 1)
	playsound(T, 'sound/effects/sparks2.ogg', 50, 1)
	anim(src,'icons/mob/mob.dmi',,"phasein",,dir)

/mob/proc/phase_out(var/turf/T)
	if(!T)
		return
	playsound(T, "sparks", 50, 1)
	anim(src,'icons/mob/mob.dmi',,"phaseout",,dir)

/mob/living/proc/on_structure_offset(var/offset = 0)

	var/next_x = default_pixel_x
	var/next_y = default_pixel_y
	var/next_z = default_pixel_z

	if(offset)
		next_z += offset
	else if(pixel_z != default_pixel_z)
		var/turf/T = get_turf(src)
		for(var/obj/structure/S in T.contents)
			if(S && S.mob_offset)
				return

	if(buckled && buckled.buckle_pixel_shift)
		var/list/pixel_shift = cached_json_decode(buckled.buckle_pixel_shift)
		next_x = default_pixel_x + pixel_shift["x"]
		next_y = default_pixel_y + pixel_shift["y"]
		next_z = default_pixel_z + pixel_shift["z"]
	
	if(pixel_x != next_x || pixel_y != next_y || pixel_z != next_z)
		animate(src, pixel_x = next_x, pixel_y = next_y, pixel_z = next_z, 2, 1, SINE_EASING)

/mob/living/Move()
	. = ..()
	on_structure_offset(0)

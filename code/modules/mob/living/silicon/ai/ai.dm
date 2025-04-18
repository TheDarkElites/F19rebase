#define CALL_BOT_COOLDOWN 900

//Not sure why this is necessary...
/proc/AutoUpdateAI(obj/subject)
	var/is_in_use = 0
	if (subject!=null)
		for(var/A in GLOB.ai_list)
			var/mob/living/silicon/ai/M = A
			if ((M.client && M.machine == subject))
				is_in_use = 1
				subject.attack_ai(M)
	return is_in_use


/mob/living/silicon/ai
	name = "AI"
	real_name = "AI"
	icon = 'icons/mob/ai.dmi'
	icon_state = "ai"
	move_resist = MOVE_FORCE_OVERPOWERING
	density = TRUE
	status_flags = CANSTUN|CANPUSH
	combat_mode = TRUE //so we always get pushed instead of trying to swap
	sight = SEE_TURFS | SEE_MOBS | SEE_OBJS
	see_in_dark = NIGHTVISION_FOV_RANGE
	hud_type = /datum/hud/ai
	med_hud = DATA_HUD_MEDICAL_BASIC
	sec_hud = DATA_HUD_SECURITY_BASIC
	d_hud = DATA_HUD_DIAGNOSTIC_ADVANCED
	mob_size = MOB_SIZE_LARGE
	radio = /obj/item/radio/headset/silicon/ai
	can_buckle_to = FALSE
	var/battery = 200 //emergency power if the AI's APC is off
	var/list/network = list("ss13")
	var/obj/machinery/camera/current
	var/list/connected_robots = list()
	var/aiRestorePowerRoutine = POWER_RESTORATION_OFF
	var/requires_power = POWER_REQ_ALL
	var/can_be_carded = TRUE
	var/icon/holo_icon //Default is assigned when AI is created.
	var/obj/controlled_equipment //A piece of equipment, to determine whether to relaymove or use the AI eye.
	var/radio_enabled = TRUE //Determins if a carded AI can speak with its built in radio or not.
	radiomod = ";" //AIs will, by default, state their laws on the internal radio.
	///Used as a fake multitoool in tcomms machinery
	var/obj/item/multitool/aiMulti
	///Weakref to the bot the ai's commanding right now
	var/datum/weakref/bot_ref
	var/tracking = FALSE //this is 1 if the AI is currently tracking somebody, but the track has not yet been completed.
	var/datum/effect_system/spark_spread/spark_system //So they can initialize sparks whenever

	//MALFUNCTION
	var/datum/module_picker/malf_picker
	var/list/datum/ai_module/current_modules = list()
	var/can_dominate_mechs = FALSE
	var/shunted = FALSE //1 if the AI is currently shunted. Used to differentiate between shunted and ghosted/braindead
	var/obj/machinery/ai_voicechanger/ai_voicechanger = null // reference to machine that holds the voicechanger
	var/control_disabled = FALSE // Set to 1 to stop AI from interacting via Click()
	var/malfhacking = FALSE // More or less a copy of the above var, so that malf AIs can hack and still get new cyborgs -- NeoFite
	var/malf_cooldown = 0 //Cooldown var for malf modules, stores a worldtime + cooldown

	var/obj/machinery/power/apc/malfhack
	var/explosive = FALSE //does the AI explode when it dies?

	var/mob/living/silicon/ai/parent
	/// If we are lighting cameras as our eye passes by.
	var/camera_light_on = TRUE

	/// Cameras that are lit by our presence.
	var/list/obj/machinery/camera/lit_cameras = list()

	var/datum/trackable/track = new

	var/last_paper_seen = null
	var/can_shunt = TRUE
	var/last_announcement = "" // For AI VOX, if enabled
	var/turf/waypoint //Holds the turf of the currently selected waypoint.
	var/waypoint_mode = FALSE //Waypoint mode is for selecting a turf via clicking.
	var/call_bot_cooldown = 0 //time of next call bot command
	var/obj/machinery/power/apc/apc_override //Ref of the AI's APC, used when the AI has no power in order to access their APC.
	var/nuking = FALSE
	var/obj/machinery/doomsday_device/doomsday_device

	var/mob/camera/ai_eye/eyeobj
	var/sprint = 10
	var/cooldown = 0
	var/acceleration = 1

	var/obj/structure/ai_core/deactivated/linked_core //For exosuit control
	var/mob/living/silicon/robot/deployed_shell = null //For shell control
	var/datum/action/innate/deploy_shell/deploy_action = new
	var/datum/action/innate/deploy_last_shell/redeploy_action = new
	var/datum/action/innate/choose_modules/modules_action
	var/chnotify = 0

	var/multicam_on = FALSE
	var/atom/movable/screen/movable/pic_in_pic/ai/master_multicam
	var/list/multicam_screens = list()
	var/list/all_eyes = list()
	var/max_multicams = 6
	var/display_icon_override

	var/list/cam_hotkeys = new/list(9)
	var/atom/cam_prev

	var/datum/robot_control/robot_control
	/// Station alert datum for showing alerts UI
	var/datum/station_alert/alert_control
	///remember AI's last location
	var/atom/lastloc
	interaction_range = null

	var/atom/movable/screen/ai/modpc/interfaceButton

	///Command report cooldown
	COOLDOWN_DECLARE(command_report_cd)
	/// An image to add to client.images so the AI player can see their own eye sprite.
	var/image/sense_of_self

/mob/living/silicon/ai/Initialize(mapload, datum/ai_laws/L, mob/target_ai)
	. = ..()
	if(!target_ai) //If there is no player/brain inside.
		new/obj/structure/ai_core/deactivated(loc) //New empty terminal.
		return INITIALIZE_HINT_QDEL //Delete AI.

	ADD_TRAIT(src, TRAIT_NO_TELEPORT, AI_ANCHOR_TRAIT)
	status_flags &= ~CANPUSH //AI starts anchored, so dont push it

	if(L && istype(L, /datum/ai_laws))
		laws = L
		laws.associate(src)
		for (var/law in laws.inherent)
			lawcheck += law
	else
		make_laws()
		for (var/law in laws.inherent)
			lawcheck += law

	if(target_ai.mind)
		target_ai.mind.transfer_to(src)
		if(mind.special_role)
			to_chat(src, span_userdanger("You have been installed as an AI! "))
			to_chat(src, span_danger("You must obey your silicon laws above all else. Your objectives will consider you to be dead."))

	to_chat(src, "<B>You are playing the station's AI. The AI cannot move, but can interact with many objects while viewing them (through cameras).</B>")
	to_chat(src, "<B>To look at other parts of the station, click on yourself to get a camera menu.</B>")
	to_chat(src, "<B>While observing through a camera, you can use most (networked) devices which you can see, such as computers, APCs, intercoms, doors, etc.</B>")
	to_chat(src, "To use something, simply click on it.")
	to_chat(src, "For department channels, use the following say commands:")
	to_chat(src, ":o - AI Private, :c - Command, :s - Security, :e - Engineering, :u - Supply, :v - Service, :m - Medical, :n - Science, :h - Holopad.")
	show_laws()
	to_chat(src, "<b>These laws may be changed by other players, or by you being the traitor.</b>")

	job = "AI"

	create_eye()
	if(client)
		INVOKE_ASYNC(src, PROC_REF(apply_pref_name), /datum/preference/name/ai, client)

	INVOKE_ASYNC(src, PROC_REF(set_core_display_icon))


	holo_icon = getHologramIcon(icon('icons/mob/ai.dmi',"default"))

	spark_system = new /datum/effect_system/spark_spread()
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)

	add_verb(src, /mob/living/silicon/ai/proc/show_laws_verb)

	create_modularInterface()

	aiMulti = new(src)
	aicamera = new/obj/item/camera/siliconcam/ai_camera(src)

	deploy_action.Grant(src)

	if(isturf(loc))
		add_verb(src, list(
			/mob/living/silicon/ai/proc/ai_network_change,
			/mob/living/silicon/ai/proc/ai_hologram_change,
			/mob/living/silicon/ai/proc/botcall,
			/mob/living/silicon/ai/proc/control_integrated_radio,
			/mob/living/silicon/ai/proc/set_automatic_say_channel,
		))

	GLOB.ai_list += src

	SET_TRACKING(TRACKING_KEY_SHUTTLE_CALLER)

	builtInCamera = new (src)
	builtInCamera.network = list("ss13")

	ADD_TRAIT(src, TRAIT_PULL_BLOCKED, ROUNDSTART_TRAIT)
	ADD_TRAIT(src, TRAIT_HANDS_BLOCKED, ROUNDSTART_TRAIT)

	alert_control = new(src, list(ALARM_ATMOS, ALARM_FIRE, ALARM_POWER, ALARM_CAMERA, ALARM_BURGLAR, ALARM_MOTION), list(z), camera_view = TRUE)
	RegisterSignal(alert_control.listener, COMSIG_ALARM_TRIGGERED, PROC_REF(alarm_triggered))
	RegisterSignal(alert_control.listener, COMSIG_ALARM_CLEARED, PROC_REF(alarm_cleared))

/mob/living/silicon/ai/key_down(_key, client/user)
	if(findtext(_key, "numpad")) //if it's a numpad number, we can convert it to just the number
		_key = _key[7] //strings, lists, same thing really
	switch(_key)
		if("`", "0")
			if(cam_prev)
				cameraFollow = null //stop following something, we want to jump away.
				eyeobj.setLoc(cam_prev)
			return
		if("1", "2", "3", "4", "5", "6", "7", "8", "9")
			_key = text2num(_key)
			if(user.keys_held["Ctrl"]) //do we assign a new hotkey?
				cam_hotkeys[_key] = eyeobj.loc
				to_chat(src, "Location saved to Camera Group [_key].")
				return
			if(cam_hotkeys[_key]) //if this is false, no hotkey for this slot exists.
				cam_prev = eyeobj.loc
				cameraFollow = null //stop following something, we want to jump away.
				eyeobj.setLoc(cam_hotkeys[_key])
				return
	return ..()

/mob/living/silicon/ai/Destroy()
	GLOB.ai_list -= src
	UNSET_TRACKING(TRACKING_KEY_SHUTTLE_CALLER)
	SSshuttle.autoEvac()
	QDEL_NULL(eyeobj) // No AI, no Eye
	QDEL_NULL(spark_system)
	QDEL_NULL(malf_picker)
	QDEL_NULL(doomsday_device)
	QDEL_NULL(robot_control)
	QDEL_NULL(aiMulti)
	QDEL_NULL(alert_control)
	malfhack = null
	current = null
	bot_ref = null
	controlled_equipment = null
	linked_core = null
	apc_override = null
	if(ai_voicechanger)
		ai_voicechanger.owner = null
		ai_voicechanger = null
	lit_cameras = null
	return ..()

/mob/living/silicon/ai/pre_examinate(atom/examinify)
	if(client?.eye == src) // Not using a camera
		return ..()

	if(!isliving(examinify))
		return ..()

	if(!do_after(src, examinify, 1.5 SECONDS, DO_IGNORE_TARGET_LOC_CHANGE|DO_IGNORE_USER_LOC_CHANGE|DO_IGNORE_HELD_ITEM|DO_IGNORE_SLOWDOWNS|DO_IGNORE_INCAPACITATED))
		return FALSE

	if(!can_examinate(examinify))
		return FALSE

	if(!can_interact_with(examinify)) // Checks cameranet visibility
		return FALSE

	var/obj/machinery/camera/viewing_camera = get_nearest_lit_camera_to_mob(examinify)

	if(viewing_camera)
		viewing_camera.visible_message("[src]'s lens rotates and zooms into something.")
		playsound(viewing_camera, 'sound/machines/camera_zoom.ogg', 50, FALSE, ignore_walls = FALSE)

	var/mob/living/target_examined = examinify
	if(target_examined.stats.cooldown_finished("ai_examine"))
		var/datum/roll_result/result = target_examined.stat_roll(13, /datum/rpg_skill/extrasensory)
		switch(result.outcome)
			if(SUCCESS, CRIT_SUCCESS)
				target_examined.stats.set_cooldown("ai_examine", 1 MINUTE)
				result.do_skill_sound(target_examined)
				to_chat(target_examined, result.create_tooltip("A nearby camera has fixated on you."))

	return TRUE

/mob/living/silicon/ai/broadcast_examine(atom/examined)
	return

/// Returns the nearest lit camera to a mob, as long as the camera can see that mob.
/mob/living/silicon/ai/proc/get_nearest_lit_camera_to_mob(mob/M)
	var/smallest_dist = INFINITY
	for(var/obj/machinery/camera/C as anything in lit_cameras)
		if(get_dist(get_turf(M), get_turf(C)) < smallest_dist && (M in viewers(C)))
			. = C

/// Removes all malfunction-related abilities from the AI
/mob/living/silicon/ai/proc/remove_malf_abilities()
	QDEL_NULL(modules_action)
	for(var/datum/ai_module/AM in current_modules)
		for(var/datum/action/A in actions)
			if(istype(A, initial(AM.power_type)))
				qdel(A)

/mob/living/silicon/ai/ignite_mob()
	return FALSE

/mob/living/silicon/ai/proc/set_core_display_icon(input, client/C)
	if(client && !C)
		C = client
	if(!input && !C?.prefs?.read_preference(/datum/preference/choiced/ai_core_display))
		icon_state = initial(icon_state)
	else
		var/preferred_icon = input ? input : C.prefs.read_preference(/datum/preference/choiced/ai_core_display)
		icon_state = resolve_ai_icon(preferred_icon)

/mob/living/silicon/ai/verb/pick_icon()
	set category = "AI Commands"
	set name = "Set AI Core Display"
	if(incapacitated())
		return
	icon = initial(icon)
	icon_state = "ai"
	cut_overlays()
	var/list/iconstates = GLOB.ai_core_display_screens
	for(var/option in iconstates)
		if(option == "Random")
			iconstates[option] = image(icon = src.icon, icon_state = "ai-random")
			continue
		if(option == "Portrait")
			iconstates[option] = image(icon = src.icon, icon_state = "ai-portrait")
			continue
		iconstates[option] = image(icon = src.icon, icon_state = resolve_ai_icon(option))

	view_core()
	var/ai_core_icon = show_radial_menu(src, src , iconstates, radius = 42)

	if(!ai_core_icon || incapacitated())
		return

	display_icon_override = ai_core_icon
	set_core_display_icon(ai_core_icon)

/mob/living/silicon/ai/get_status_tab_items()
	. = ..()
	if(stat != CONSCIOUS)
		. += "Systems nonfunctional"
		return
	. += "System integrity: [(health + 100) * 0.5]%"
	if(isturf(loc)) //only show if we're "in" a core
		. += "Backup Power: [battery * 0.5]%"
	. += "Connected cyborgs: [length(connected_robots)]"
	for(var/r in connected_robots)
		var/mob/living/silicon/robot/connected_robot = r
		var/robot_status = "Nominal"
		if(connected_robot.shell)
			robot_status = "AI SHELL"
		else if(connected_robot.stat != CONSCIOUS || !connected_robot.client)
			robot_status = "OFFLINE"
		else if(!connected_robot.cell || connected_robot.cell.charge <= 0)
			robot_status = "DEPOWERED"
		//Name, Health, Battery, Model, Area, and Status! Everything an AI wants to know about its borgies!
		. += "[connected_robot.name] | S.Integrity: [connected_robot.health]% | Cell: [connected_robot.cell ? "[connected_robot.cell.charge]/[connected_robot.cell.maxcharge]" : "Empty"] | \
		Model: [connected_robot.designation] | Loc: [get_area_name(connected_robot, TRUE)] | Status: [robot_status]"
	. += "AI shell beacons detected: [LAZYLEN(GLOB.available_ai_shells)]" //Count of total AI shells

/mob/living/silicon/ai/proc/ai_call_shuttle()
	if(control_disabled)
		to_chat(usr, span_warning("Wireless control is disabled!"))
		return

	var/can_evac_or_fail_reason = SSshuttle.canEvac(src)
	if(can_evac_or_fail_reason != TRUE)
		to_chat(usr, span_alert("[can_evac_or_fail_reason]"))
		return

	var/reason = tgui_input_text(src, "What is the nature of your emergency? ([CALL_SHUTTLE_REASON_LENGTH] characters required.)", "Confirm Shuttle Call")

	if(incapacitated())
		return

	if(trim(reason))
		SSshuttle.requestEvac(src, reason)

	// hack to display shuttle timer
	if(!EMERGENCY_IDLE_OR_RECALLED)
		var/obj/machinery/computer/communications/C = locate() in INSTANCES_OF(/obj/machinery/computer/communications)
		if(C)
			C.post_status("shuttle")

/mob/living/silicon/ai/can_interact_with(atom/A)
	. = ..()
	var/turf/ai = get_turf(src)
	var/turf/target = get_turf(A)
	if (.)
		return

	if(!target)
		return

	if ((ai.z != target.z) && !is_station_level(ai.z))
		return FALSE

	if (istype(loc, /obj/item/aicard))
		if (!ai || !target)
			return FALSE
		return ISINRANGE(target.x, ai.x - interaction_range, ai.x + interaction_range) && ISINRANGE(target.y, ai.y - interaction_range, ai.y + interaction_range)
	else
		return GLOB.cameranet.checkTurfVis(get_turf(A))

/mob/living/silicon/ai/cancel_camera()
	view_core()

/mob/living/silicon/ai/verb/toggle_anchor()
	set category = "AI Commands"
	set name = "Toggle Floor Bolts"
	if(!isturf(loc)) // if their location isn't a turf
		return // stop
	if(stat == DEAD)
		return
	if(incapacitated())
		if(battery < 50)
			to_chat(src, span_warning("Insufficient backup power!"))
			return
		battery = battery - 50
		to_chat(src, span_notice("You route power from your backup battery to move the bolts."))
	var/is_anchored = FALSE
	if(move_resist == MOVE_FORCE_OVERPOWERING)
		move_resist = MOVE_FORCE_NORMAL
		status_flags |= CANPUSH //we want the core to be push-able when un-anchored
		REMOVE_TRAIT(src, TRAIT_NO_TELEPORT, AI_ANCHOR_TRAIT)
	else
		is_anchored = TRUE
		move_resist = MOVE_FORCE_OVERPOWERING
		status_flags &= ~CANPUSH //we dont want the core to be push-able when anchored
		ADD_TRAIT(src, TRAIT_NO_TELEPORT, AI_ANCHOR_TRAIT)

	to_chat(src, "<b>You are now [is_anchored ? "" : "un"]anchored.</b>")
	// the message in the [] will change depending whether or not the AI is anchored


/mob/living/silicon/ai/Topic(href, href_list)
	..()
	if(usr != src)
		return

	if(href_list["emergencyAPC"]) //This check comes before incapacitated() because the only time it would be useful is when we have no power.
		if(!apc_override)
			to_chat(src, span_notice("APC backdoor is no longer available."))
			return
		apc_override.ui_interact(src)
		return

	if(incapacitated())
		return

	if (href_list["mach_close"])
		var/t1 = "window=[href_list["mach_close"]]"
		unset_machine()
		src << browse(null, t1)
	if (href_list["switchcamera"])
		switchCamera(locate(href_list["switchcamera"]) in GLOB.cameranet.cameras)
	if (href_list["showalerts"])
		alert_control.ui_interact(src)
#ifdef AI_VOX
	if(href_list["say_word"])
		play_vox_word(href_list["say_word"], null, src)
		return
#endif
	if(href_list["show_paper"])
		if(last_paper_seen)
			src << browse(last_paper_seen, "window=show_paper")
	//Carn: holopad requests
	if(href_list["jump_to_holopad"])
		var/obj/machinery/holopad/Holopad = locate(href_list["jump_to_holopad"]) in INSTANCES_OF(/obj/machinery/holopad)
		if(Holopad)
			cam_prev = get_turf(eyeobj)
			eyeobj.setLoc(Holopad)
		else
			to_chat(src, span_notice("Unable to locate the holopad."))
	if(href_list["project_to_holopad"])
		var/obj/machinery/holopad/Holopad = locate(href_list["project_to_holopad"]) in INSTANCES_OF(/obj/machinery/holopad)
		if(Holopad)
			lastloc = get_turf(eyeobj)
			Holopad.attack_ai_secondary(src) //may as well recycle
		else
			to_chat(src, span_notice("Unable to project to the holopad."))
	if(href_list["track"])
		var/string = href_list["track"]
		trackable_mobs()
		var/list/trackeable = list()
		trackeable += track.humans + track.others
		var/list/target = list()
		for(var/I in trackeable)
			var/datum/weakref/to_resolve = trackeable[I]
			var/mob/to_track = to_resolve.resolve()
			if(!to_track || to_track.name != string)
				continue
			target += to_track
		if(name == string)
			target += src
		if(length(target))
			cam_prev = get_turf(eyeobj)
			ai_actual_track(pick(target))
		else
			to_chat(src, "Target is not on or near any active cameras on the station.")
		return
	if (href_list["ai_take_control"]) //Mech domination
		var/obj/vehicle/sealed/mecha/M = locate(href_list["ai_take_control"]) in INSTANCES_OF(/obj/vehicle/sealed/mecha)
		if (!M)
			return

		var/mech_has_controlbeacon = FALSE
		for(var/obj/item/mecha_parts/mecha_tracking/ai_control/A in M.trackers)
			mech_has_controlbeacon = TRUE
			break
		if(!can_dominate_mechs && !mech_has_controlbeacon)
			message_admins("Warning: possible href exploit by [key_name(usr)] - attempted control of a mecha without can_dominate_mechs or a control beacon in the mech.")
			log_game("Warning: possible href exploit by [key_name(usr)] - attempted control of a mecha without can_dominate_mechs or a control beacon in the mech.")
			return

		if(controlled_equipment)
			to_chat(src, span_warning("You are already loaded into an onboard computer!"))
			return
		if(!GLOB.cameranet.checkCameraVis(M))
			to_chat(src, span_warning("Exosuit is no longer near active cameras."))
			return
		if(!isturf(loc))
			to_chat(src, span_warning("You aren't in your core!"))
			return
		if(M)
			M.transfer_ai(AI_MECH_HACK, src, usr) //Called om the mech itself.


/mob/living/silicon/ai/proc/switchCamera(obj/machinery/camera/C)
	if(QDELETED(C))
		return FALSE

	if(!tracking)
		cameraFollow = null

	if(QDELETED(eyeobj))
		view_core()
		return
	// ok, we're alive, camera is good and in our network...
	eyeobj.setLoc(get_turf(C))
	return TRUE

/mob/living/silicon/ai/proc/botcall()
	set category = "AI Commands"
	set name = "Access Robot Control"
	set desc = "Wirelessly control various automatic robots."

	if(!robot_control)
		robot_control = new(src)

	robot_control.ui_interact(src)

/mob/living/silicon/ai/proc/set_waypoint(atom/A)
	var/turf/turf_check = get_turf(A)
		//The target must be in view of a camera or near the core.
	if(turf_check in range(get_turf(src)))
		call_bot(turf_check)
	else if(GLOB.cameranet && GLOB.cameranet.checkTurfVis(turf_check))
		call_bot(turf_check)
	else
		to_chat(src, span_danger("Selected location is not visible."))

/mob/living/silicon/ai/proc/call_bot(turf/waypoint)
	var/mob/living/simple_animal/bot/bot = bot_ref?.resolve()
	if(!bot)
		return

	if(bot.calling_ai && bot.calling_ai != src) //Prevents an override if another AI is controlling this bot.
		to_chat(src, span_danger("Interface error. Unit is already in use."))
		return
	to_chat(src, span_notice("Sending command to bot..."))
	call_bot_cooldown = world.time + CALL_BOT_COOLDOWN
	bot.call_bot(src, waypoint)
	call_bot_cooldown = 0

/mob/living/silicon/ai/proc/alarm_triggered(datum/source, alarm_type, area/source_area)
	SIGNAL_HANDLER
	var/list/cameras = source_area.cameras
	var/home_name = source_area.name

	if (length(cameras))
		var/obj/machinery/camera/cam = cameras[1]
		if (cam.can_use())
			queueAlarm("--- [alarm_type] alarm detected in [home_name]! (<A HREF=?src=[REF(src)];switchcamera=[REF(cam)]>[cam.c_tag]</A>)", alarm_type)
		else
			var/first_run = FALSE
			var/dat2 = ""
			for (var/obj/machinery/camera/camera as anything in cameras)
				dat2 += "[(!first_run) ? "" : " | "]<A HREF=?src=[REF(src)];switchcamera=[REF(camera)]>[camera.c_tag]</A>"
				first_run = TRUE
			queueAlarm("--- [alarm_type] alarm detected in [home_name]! ([dat2])", alarm_type)
	else
		queueAlarm("--- [alarm_type] alarm detected in [home_name]! (No Camera)", alarm_type)
	return 1

/mob/living/silicon/ai/proc/alarm_cleared(datum/source, alarm_type, area/source_area)
	SIGNAL_HANDLER
	queueAlarm("--- [alarm_type] alarm in [source_area.name] has been cleared.", alarm_type, 0)

//Replaces /mob/living/silicon/ai/verb/change_network() in ai.dm & camera.dm
//Adds in /mob/living/silicon/ai/proc/ai_network_change() instead
//Addition by Mord_Sith to define AI's network change ability
/mob/living/silicon/ai/proc/ai_network_change()
	set category = "AI Commands"
	set name = "Jump To Network"
	unset_machine()
	cameraFollow = null
	var/cameralist[0]

	if(incapacitated())
		return

	var/mob/living/silicon/ai/U = usr

	for (var/obj/machinery/camera/C in GLOB.cameranet.cameras)
		var/list/tempnetwork = C.network
		if(!(is_station_level(C.z) || is_mining_level(C.z) || ("ss13" in tempnetwork)))
			continue
		if(!C.can_use())
			continue

		tempnetwork.Remove("rd", "ordnance", "prison")
		if(length(tempnetwork))
			for(var/i in C.network)
				cameralist[i] = i
	var/old_network = network
	network = tgui_input_list(U, "Which network would you like to view?", "Camera Network", sort_list(cameralist))

	if(!U.eyeobj)
		U.view_core()
		return

	if(isnull(network))
		network = old_network // If nothing is selected
	else
		for(var/obj/machinery/camera/C in GLOB.cameranet.cameras)
			if(!C.can_use())
				continue
			if(network in C.network)
				U.eyeobj.setLoc(get_turf(C))
				break
	to_chat(src, span_notice("Switched to the \"[uppertext(network)]\" camera network."))
//End of code by Mord_Sith

//I am the icon meister. Bow fefore me. //>fefore
/mob/living/silicon/ai/proc/ai_hologram_change()
	set name = "Change Hologram"
	set desc = "Change the default hologram available to AI to something else."
	set category = "AI Commands"

	if(incapacitated())
		return
	var/input
	switch(tgui_input_list(usr, "Would you like to select a hologram based on a custom character, an animal, or switch to a unique avatar?", "Customize", list("Custom Character","Unique","Animal")))
		if("Custom Character")
			switch(tgui_alert(usr,"Would you like to base it off of your current character loadout, or a member on station?", "Customize", list("My Character","Station Member")))
				if("Station Member")
					var/list/personnel_list = list()

					for(var/datum/data/record/record_datum in SSdatacore.get_records(DATACORE_RECORDS_LOCKED))//Look in data core locked.
						personnel_list["[record_datum.fields[DATACORE_NAME]]: [record_datum.fields[DATACORE_RANK]]"] = record_datum.fields[DATACORE_APPEARANCE]//Pull names, rank, and image.

					if(!length(personnel_list))
						tgui_alert(usr,"No suitable records found. Aborting.")
						return
					input = tgui_input_list(usr, "Select a crew member", "Station Member", sort_list(personnel_list))
					if(isnull(input))
						return
					if(isnull(personnel_list[input]))
						return
					var/mutable_appearance/character_icon = personnel_list[input]
					if(character_icon)
						qdel(holo_icon)//Clear old icon so we're not storing it in memory.

						var/icon/icon_for_holo = getFlatIcon(character_icon, SOUTH)
						holo_icon = getHologramIcon(icon(icon_for_holo))

				if("My Character")
					switch(tgui_alert(usr,"WARNING: Your AI hologram will take the appearance of your currently selected character ([usr.client.prefs?.read_preference(/datum/preference/name/real_name)]). Are you sure you want to proceed?", "Customize", list("Yes","No")))
						if("Yes")
							var/mob/living/carbon/human/dummy/ai_dummy = new
							var/mutable_appearance/appearance = usr.client.prefs.render_new_preview_appearance(ai_dummy)
							var/icon/character_icon = getHologramIcon(getFlatIcon(appearance))
							if(character_icon)
								qdel(holo_icon)
								qdel(ai_dummy)
								holo_icon = character_icon
						if("No")
							return FALSE

		if("Animal")
			var/list/icon_list = list(
			"bear" = 'icons/mob/animal.dmi',
			"carp" = 'icons/mob/carp.dmi',
			"chicken" = 'icons/mob/animal.dmi',
			"corgi" = 'icons/mob/pets.dmi',
			"cow" = 'icons/mob/animal.dmi',
			"crab" = 'icons/mob/animal.dmi',
			"fox" = 'icons/mob/pets.dmi',
			"goat" = 'icons/mob/animal.dmi',
			"cat" = 'icons/mob/pets.dmi',
			"cat2" = 'icons/mob/pets.dmi',
			"poly" = 'icons/mob/animal.dmi',
			"pug" = 'icons/mob/pets.dmi',
			"spider" = 'icons/mob/animal.dmi'
			)

			input = tgui_input_list(usr, "Select a hologram", "Hologram", sort_list(icon_list))
			if(isnull(input))
				return
			if(isnull(icon_list[input]))
				return
			qdel(holo_icon)
			switch(input)
				if("poly")
					holo_icon = getHologramIcon(icon(icon_list[input],"parrot_fly"))
				if("chicken")
					holo_icon = getHologramIcon(icon(icon_list[input],"chicken_brown"))
				if("spider")
					holo_icon = getHologramIcon(icon(icon_list[input],"guard"))
				else
					holo_icon = getHologramIcon(icon(icon_list[input], input))
		else
			var/list/icon_list = list(
				"default" = 'icons/mob/ai.dmi',
				"floating face" = 'icons/mob/ai.dmi',
				"xeno queen" = 'icons/mob/alien.dmi',
				"horror" = 'icons/mob/ai.dmi',
				"clock" = 'icons/mob/ai.dmi'
				)

			input = tgui_input_list(usr, "Select a hologram", "Hologram", sort_list(icon_list))
			if(isnull(input))
				return
			if(isnull(icon_list[input]))
				return
			qdel(holo_icon)
			switch(input)
				if("xeno queen")
					holo_icon = getHologramIcon(icon(icon_list[input],"alienq"))
				else
					holo_icon = getHologramIcon(icon(icon_list[input], input))
	return

/datum/action/innate/core_return
	name = "Return to Main Core"
	desc = "Leave the APC and resume normal core operations."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "ai_malf_core"

/datum/action/innate/core_return/Activate()
	var/obj/machinery/power/apc/apc = owner.loc
	if(!istype(apc))
		to_chat(owner, span_notice("You are already in your Main Core."))
		return
	apc.malfvacate()
	qdel(src)

/mob/living/silicon/ai/proc/toggle_camera_light()
	camera_light_on = !camera_light_on

	if (!camera_light_on)
		to_chat(src, "Camera lights deactivated.")
		for (var/obj/machinery/camera/C in lit_cameras)
			C.set_ai_light(FALSE, src)

		lit_cameras.Cut()
		return

	update_lit_cameras()

	to_chat(src, "Camera lights activated.")

//AI_CAMERA_LUMINOSITY

/mob/living/silicon/ai/proc/update_lit_cameras()
	if(isnull(eyeobj)) // Initialize
		return

	var/list/obj/machinery/camera/add = list()
	var/list/obj/machinery/camera/remove = list()
	var/list/obj/machinery/camera/visible = list()
	for (var/datum/camerachunk/CC in eyeobj.visibleCameraChunks)
		for (var/obj/machinery/camera/C in CC.cameras)
			if (!C.can_use() || get_dist(C, eyeobj) > 7 || !C.internal_light)
				continue
			visible |= C

	add = visible - lit_cameras
	remove = lit_cameras - visible

	for (var/obj/machinery/camera/C in remove)
		lit_cameras -= C
		C.set_ai_light(FALSE, src)

	for (var/obj/machinery/camera/C in add)
		C.set_ai_light(TRUE, src)
		lit_cameras |= C

/mob/living/silicon/ai/proc/control_integrated_radio()
	set name = "Transceiver Settings"
	set desc = "Allows you to change settings of your radio."
	set category = "AI Commands"

	if(incapacitated())
		return

	to_chat(src, "Accessing Subspace Transceiver control...")
	if (radio)
		radio.interact(src)

/mob/living/silicon/ai/proc/set_syndie_radio()
	if(radio)
		radio.make_syndie()

/mob/living/silicon/ai/proc/set_automatic_say_channel()
	set name = "Set Auto Announce Mode"
	set desc = "Modify the default radio setting for your automatic announcements."
	set category = "AI Commands"

	if(incapacitated())
		return
	set_autosay()

/mob/living/silicon/ai/transfer_ai(interaction, mob/user, mob/living/silicon/ai/AI, obj/item/aicard/card)
	if(!..())
		return
	if(interaction == AI_TRANS_TO_CARD)//The only possible interaction. Upload AI mob to a card.
		if(!can_be_carded)
			to_chat(user, span_boldwarning("Transfer failed."))
			return
		disconnect_shell() //If the AI is controlling a borg, force the player back to core!
		if(!mind)
			to_chat(user, span_warning("No intelligence patterns detected."))
			return
		ShutOffDoomsdayDevice()
		var/obj/structure/ai_core/new_core = new /obj/structure/ai_core/deactivated(loc)//Spawns a deactivated terminal at AI location.
		new_core.circuit.battery = battery
		ai_restore_power()//So the AI initially has power.
		control_disabled = TRUE //Can't control things remotely if you're stuck in a card!
		interaction_range = 0
		radio_enabled = FALSE //No talking on the built-in radio for you either!
		forceMove(card)
		card.AI = src
		to_chat(src, "You have been downloaded to a mobile storage device. Remote device connection severed.")
		to_chat(user, "[span_boldnotice("Transfer successful")]: [name] ([rand(1000,9999)].exe) removed from host terminal and stored within local memory.")

/mob/living/silicon/ai/canUseTopic(atom/movable/target, flags)
	if(control_disabled)
		to_chat(src, span_warning("You can't do that right now!"))
		return FALSE
	return can_see(target) && ..() //stop AIs from leaving windows open and using then after they lose vision

/mob/living/silicon/ai/proc/can_see(atom/A)
	if(isturf(loc)) //AI in core, check if on cameras
		//get_turf_pixel() is because APCs in maint aren't actually in view of the inner camera
		//apc_override is needed here because AIs use their own APC when depowered
		return ((GLOB.cameranet && GLOB.cameranet.checkTurfVis(get_turf_pixel(A))) || (A == apc_override))
	//AI is carded/shunted
	//view(src) returns nothing for carded/shunted AIs and they have X-ray vision so just use get_dist
	var/list/viewscale = getviewsize(client.view)
	return get_dist(src, A) <= max(viewscale[1]*0.5,viewscale[2]*0.5)

/mob/living/silicon/ai/proc/relay_speech(message, atom/movable/speaker, datum/language/message_language, raw_message, radio_freq, list/spans, list/message_mods = list())
	var/treated_message = translate_speech(speaker, message_language, raw_message, spans, message_mods, quote = TRUE)
	var/start = "Relayed Speech: "
	var/namepart = "[speaker.GetVoice()][speaker.get_alt_name()]"
	var/hrefpart = "<a href='?src=[REF(src)];track=[html_encode(namepart)]'>"
	var/jobpart = "Unknown"

	if (isliving(speaker))
		var/mob/living/living_speaker = speaker
		if(living_speaker.job)
			jobpart = "[living_speaker.job]"
	if (istype(speaker, /obj/effect/overlay/holo_pad_hologram))
		var/obj/effect/overlay/holo_pad_hologram/holo = speaker
		if(holo.Impersonation?.job)
			jobpart = "[holo.Impersonation.job]"
		else if(usr?.job) // not great, but AI holograms have no other usable ref
			jobpart = "[usr.job]"

	var/rendered = "<i><span class='game say'>[start][span_name("[hrefpart][namepart] ([jobpart])</a> ")]<span class='message'>[treated_message]</span></span></i>"

	if (client?.prefs.read_preference(/datum/preference/toggle/enable_runechat) && (client.prefs.read_preference(/datum/preference/toggle/enable_runechat_non_mobs) || ismob(speaker)))
		create_chat_message(speaker, message_language, raw_message, spans)
	show_message(rendered, 2)

/mob/living/silicon/ai/fully_replace_character_name(oldname,newname)
	..()
	if(oldname != real_name)
		if(eyeobj)
			eyeobj.name = "[newname] (AI Eye)"
			modularInterface.saved_identification = real_name

		// Notify Cyborgs
		for(var/mob/living/silicon/robot/Slave in connected_robots)
			Slave.show_laws()

/datum/action/innate/choose_modules
	name = "Malfunction Modules"
	desc = "Choose from a variety of insidious modules to aid you."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "modules_menu"
	var/datum/module_picker/module_picker

/datum/action/innate/choose_modules/New(picker)
	. = ..()
	if(istype(picker, /datum/module_picker))
		module_picker = picker
	else
		CRASH("choose_modules action created with non module picker")

/datum/action/innate/choose_modules/Activate()
	module_picker.ui_interact(owner)

/mob/living/silicon/ai/proc/add_malf_picker()
	to_chat(src, "In the top left corner of the screen you will find the Malfunction Modules button, where you can purchase various abilities, from upgraded surveillance to station ending doomsday devices.")
	to_chat(src, "You are also capable of hacking APCs, which grants you more points to spend on your Malfunction powers. The drawback is that a hacked APC will give you away if spotted by the crew. Hacking an APC takes 60 seconds.")
	view_core() //A BYOND bug requires you to be viewing your core before your verbs update
	malf_picker = new /datum/module_picker
	if(!IS_MALF_AI(src)) //antagonists have their modules built into their antag info panel. this is for adminbus and the combat upgrade
		modules_action = new(malf_picker)
		modules_action.Grant(src)

/mob/living/silicon/ai/reset_perspective(atom/new_eye)
	if(camera_light_on)
		update_lit_cameras()

	if(istype(new_eye, /obj/machinery/camera))
		current = new_eye

	if(!client)
		return

	client.images -= sense_of_self

	if(ismovable(new_eye))
		if(new_eye != GLOB.ai_camera_room_landmark)
			end_multicam()
		client.perspective = EYE_PERSPECTIVE
		client.eye = new_eye

	else
		end_multicam()
		if(isturf(loc))
			if(eyeobj)
				client.eye = eyeobj
				client.perspective = EYE_PERSPECTIVE
				client.images += sense_of_self
			else
				client.eye = client.mob
				client.perspective = MOB_PERSPECTIVE
		else
			client.perspective = EYE_PERSPECTIVE
			client.eye = loc

	update_sight()

	if(client.eye != src)
		var/atom/AT = client.eye
		AT.get_remote_view_fullscreens(src)
	else
		clear_fullscreen("remote_view", 0)

/mob/living/silicon/ai/revive(full_heal = FALSE, admin_revive = FALSE)
	. = ..()
	if(.) //successfully ressuscitated from death
		set_core_display_icon(display_icon_override)
		set_eyeobj_visible(TRUE)

/mob/living/silicon/ai/proc/malfhacked(obj/machinery/power/apc/apc)
	malfhack = null
	malfhacking = 0
	clear_alert(ALERT_HACKING_APC)

	if(!istype(apc) || QDELETED(apc) || apc.machine_stat & BROKEN)
		to_chat(src, span_danger("Hack aborted. The designated APC no longer exists on the power network."))
		playsound(get_turf(src), 'sound/machines/buzz-two.ogg', 50, TRUE, ignore_walls = FALSE)
	else if(apc.aidisabled)
		to_chat(src, span_danger("Hack aborted. [apc] is no longer responding to our systems."))
		playsound(get_turf(src), 'sound/machines/buzz-sigh.ogg', 50, TRUE, ignore_walls = FALSE)
	else
		malf_picker.processing_time += 10

		apc.malfai = parent || src
		apc.malfhack = TRUE
		apc.locked = TRUE
		apc.coverlocked = TRUE

		playsound(get_turf(src), 'sound/machines/ding.ogg', 50, TRUE, ignore_walls = FALSE)
		to_chat(src, "Hack complete. [apc] is now under your exclusive control.")
		apc.update_appearance()

/mob/living/silicon/ai/verb/deploy_to_shell(mob/living/silicon/robot/target)
	set category = "AI Commands"
	set name = "Deploy to Shell"

	if(incapacitated())
		return
	if(control_disabled)
		to_chat(src, span_warning("Wireless networking module is offline."))
		return

	var/list/possible = list()

	for(var/borgie in GLOB.available_ai_shells)
		var/mob/living/silicon/robot/R = borgie
		if(R.shell && !R.deployed && (R.stat != DEAD) && (!R.connected_ai ||(R.connected_ai == src)))
			possible += R

	if(!LAZYLEN(possible))
		to_chat(src, "No usable AI shell beacons detected.")

	if(!target || !(target in possible)) //If the AI is looking for a new shell, or its pre-selected shell is no longer valid
		target = tgui_input_list(src, "Which body to control?", "Direct Control", sort_names(possible))

	if(isnull(target))
		return
	if (target.stat == DEAD || target.deployed || !(!target.connected_ai ||(target.connected_ai == src)))
		return

	else if(mind)
		RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(disconnect_shell))
		deployed_shell = target
		target.deploy_init(src)
		mind.transfer_to(target)
	diag_hud_set_deployed()

/datum/action/innate/deploy_shell
	name = "Deploy to AI Shell"
	desc = "Wirelessly control a specialized cyborg shell."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "ai_shell"

/datum/action/innate/deploy_shell/Trigger(trigger_flags)
	var/mob/living/silicon/ai/AI = owner
	if(!AI)
		return
	AI.deploy_to_shell()

/datum/action/innate/deploy_last_shell
	name = "Reconnect to shell"
	desc = "Reconnect to the most recently used AI shell."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "ai_last_shell"
	var/mob/living/silicon/robot/last_used_shell

/datum/action/innate/deploy_last_shell/Trigger(trigger_flags)
	if(!owner)
		return
	if(last_used_shell)
		var/mob/living/silicon/ai/AI = owner
		AI.deploy_to_shell(last_used_shell)
	else
		Remove(owner) //If the last shell is blown, destroy it.

/mob/living/silicon/ai/proc/disconnect_shell()
	SIGNAL_HANDLER
	if(deployed_shell) //Forcibly call back AI in event of things such as damage, EMP or power loss.
		to_chat(src, span_danger("Your remote connection has been reset!"))
		deployed_shell.undeploy()
		UnregisterSignal(deployed_shell, COMSIG_LIVING_DEATH)
	diag_hud_set_deployed()

/mob/living/silicon/ai/resist()
	return

/mob/living/silicon/ai/spawned/Initialize(mapload, datum/ai_laws/L, mob/target_ai)
	if(!target_ai)
		target_ai = src //cheat! just give... ourselves as the spawned AI, because that's technically correct
	. = ..()

/mob/living/silicon/ai/proc/camera_visibility(mob/camera/ai_eye/moved_eye)
	GLOB.cameranet.visibility(moved_eye, client, all_eyes, TRUE)

/mob/living/silicon/ai/forceMove(atom/destination)
	. = ..()
	if(.)
		end_multicam()

/mob/living/silicon/ai/up()
	set name = "Move Upwards"
	set category = "IC"

	if(zstep(eyeobj, UP, ZMOVE_FEEDBACK))
		to_chat(src, span_notice("You move upwards."))

/mob/living/silicon/ai/down()
	set name = "Move Down"
	set category = "IC"

	if(zstep(eyeobj, DOWN, ZMOVE_FEEDBACK))
		to_chat(src, span_notice("You move down."))

/// Proc to hook behavior to the changes of the value of [aiRestorePowerRoutine].
/mob/living/silicon/ai/proc/setAiRestorePowerRoutine(new_value)
	if(new_value == aiRestorePowerRoutine)
		return
	. = aiRestorePowerRoutine
	aiRestorePowerRoutine = new_value
	if(aiRestorePowerRoutine)
		if(!.)
			ADD_TRAIT(src, TRAIT_INCAPACITATED, POWER_LACK_TRAIT)
	else if(.)
		REMOVE_TRAIT(src, TRAIT_INCAPACITATED, POWER_LACK_TRAIT)


/mob/living/silicon/on_handsblocked_start()
	return // AIs have no hands

/mob/living/silicon/on_handsblocked_end()
	return // AIs have no hands

/mob/living/silicon/ai/get_exp_list(minutes)
	. = ..()

	var/datum/job/ai/ai_job_ref = SSjob.GetJobType(/datum/job/ai)

	.[ai_job_ref.title] = minutes


/mob/living/silicon/ai/GetVoice()
	. = ..()
	if(ai_voicechanger&&ai_voicechanger.changing_voice)
		return ai_voicechanger.say_name
	return

/mob/living/silicon/ai/verb/create_report()
	set category = "AI Commands"
	set name = "Station Announcement"

	var/mob/living/silicon/ai/me = usr
	if(!istype(me))
		return
	if(me.incapacitated())
		return

	if(!COOLDOWN_FINISHED(me, command_report_cd))
		to_chat(me, span_danger("You cannot use this for [COOLDOWN_TIMELEFT(me, command_report_cd)/10] seconds!"))
		return

	var/message = input(me, "Enter a message (240 characters)", "Station Announcement", "") as null|text
	if(!message)
		return

	var/sanitized_message = copytext(message, 1, 240)

	if(length(message) != length(sanitized_message))
		if(alert(me, "Your message was shortened to \"[sanitized_message]\", continue?", "Message Too Long", "Yes", "No") == "No")
			return
		else
			priority_announce(sanitized_message, "Station Announcement By [me.name] (AI)", do_not_modify = TRUE)
	else
		priority_announce(message, "Station Announcement By [me.name] (AI)", do_not_modify = TRUE)

	COOLDOWN_START(me, command_report_cd, 120 SECONDS)

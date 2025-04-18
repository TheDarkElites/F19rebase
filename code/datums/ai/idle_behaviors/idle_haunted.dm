///If not held, teleport somewhere else
/datum/ai_behavior/idle_ghost_item
	///Chance for item to teleport somewhere else
	var/teleport_chance = 4

/datum/ai_behavior/idle_ghost_item/perform(delta_time, datum/ai_controller/controller)
	var/obj/item/item_pawn = controller.pawn
	if(ismob(item_pawn.loc)) //Being held. dont teleport
		return BEHAVIOR_PERFORM_FAILURE

	if(DT_PROB(teleport_chance, delta_time))
		playsound(item_pawn.loc, 'sound/items/haunted/ghostitemattack.ogg', 100, TRUE)
		do_teleport(item_pawn, get_turf(item_pawn), 4, channel = TELEPORT_CHANNEL_MAGIC)

	return BEHAVIOR_PERFORM_COOLDOWN | BEHAVIOR_PERFORM_SUCCESS

/datum/job
	///With this set to TRUE, the loadout will be applied before a job clothing will be
	var/no_dresscode
	//Whether the job can use the loadout system
	var/loadout = TRUE
	//List of banned quirks in their names(dont blame me, that's how they're stored), players can't join as the job if they have the quirk. Associative for the purposes of performance
	var/list/banned_quirks
	///A list of slots that can't have loadout items assigned to them if no_dresscode is applied, used for important items such as ID, PDA, backpack and headset
	var/list/blacklist_dresscode_slots
	//Blacklist of species for this job.
	var/list/species_blacklist
	// /// Which languages does the job require, associative to LANGUAGE_UNDERSTOOD or LANGUAGE_SPOKEN
	// var/list/required_languages = list(/datum/language/common = LANGUAGE_SPOKEN)

	///Is this job veteran only? If so, then this job requires the player to be in the veteran_players.txt
	var/veteran_only = FALSE


/datum/job/proc/has_banned_quirk(datum/preferences/pref)
	if(!pref) //No preferences? We'll let you pass, this time (just a precautionary check,you dont wanna mess up gamemode setting logic)
		return FALSE
	if(banned_quirks)
		for(var/Q in pref.read_preference(/datum/preference/blob/quirks))
			if(banned_quirks[Q])
				return TRUE
	return FALSE

// Misc
/datum/job/assistant
	no_dresscode = TRUE
	blacklist_dresscode_slots = list(ITEM_SLOT_EARS,ITEM_SLOT_BELT,ITEM_SLOT_ID,ITEM_SLOT_BACK) //headset, PDA, ID, backpack are important items

//Security
/datum/job/security_officer
	banned_quirks = list(SEC_RESTRICTED_QUIRKS)

/datum/job/detective
	banned_quirks = list(SEC_RESTRICTED_QUIRKS)

/datum/job/warden
	banned_quirks = list(SEC_RESTRICTED_QUIRKS)

/datum/job/security_medic
	banned_quirks = list(SEC_RESTRICTED_QUIRKS)

/datum/job/blueshield
	banned_quirks = list(SEC_RESTRICTED_QUIRKS)

/datum/job/nanotrasen_consultant
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

// Command
/datum/job/captain
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

/datum/job/head_of_security
	banned_quirks = list(SEC_RESTRICTED_QUIRKS, HEAD_RESTRICTED_QUIRKS)

/datum/job/augur
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

/datum/job/chief_engineer
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS, "Paraplegic" = TRUE)

/datum/job/research_director
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

/datum/job/head_of_personnel
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

/datum/job/quartermaster
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

//Silicon
/datum/job/ai
	loadout = FALSE

/datum/job/cyborg
	loadout = FALSE

//Service
/datum/job/station_engineer
	banned_quirks = list(TECH_RESTRICTED_QUIRKS)

/datum/job/atmospheric_technician
	banned_quirks = list(TECH_RESTRICTED_QUIRKS)

// /datum/job/proc/has_required_languages(datum/preferences/pref)
// 	if(!required_languages)
// 		return TRUE
// 	for(var/lang in required_languages)
// 		//Doesnt have language, or the required "level" is too low (understood, while needing spoken)
// 		if(!pref.languages[lang] || pref.languages[lang] < required_languages[lang])
// 			return FALSE
// 	return TRUE

// Nanotrasen Fleet
/datum/job/fleetmaster
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

/datum/job/operations_inspector
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

/datum/job/deck_crew
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

/datum/job/bridge_officer
	banned_quirks = list(HEAD_RESTRICTED_QUIRKS)

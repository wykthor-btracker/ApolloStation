//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:33

/mob/new_player
	var/ready = 0
	var/spawning = 0//Referenced when you want to delete the new_player later on in the code.
	var/global/totalPlayers = 0		 //Player counts for the Lobby tab
	var/global/totalPlayersReady = 0
	var/global/list/statMessage = list() // The message displayed on the lobby panel
	universal_speak = 1

	invisibility = 101

	density = 0
	stat = 2
	canmove = 0

	anchored = 1	//  don't get pushed around

	New()
		mob_list += src

	verb/new_player_panel()
		set src = usr
		new_player_panel_proc()


	proc/new_player_panel_proc()
		var/output = "<div align='center'><B>New Player Options</B>"
		output +="<hr>"
		output += "<p><a href='byond://?src=\ref[src];show_preferences=1'>Character Setup</A></p>"

		if(!ticker || ticker.current_state <= GAME_STATE_PREGAME)
			if(ready)
				output += "<p>\[ <b>Ready</b> | <a href='byond://?src=\ref[src];ready=0'>Not Ready</a> \]</p>"
			else
				output += "<p>\[ <a href='byond://?src=\ref[src];ready=1'>Ready</a> | <b>Not Ready</b> \]</p>"

		else
			output += "<a href='byond://?src=\ref[src];manifest=1'>View the Crew Manifest</A><br><br>"
			output += "<p><a href='byond://?src=\ref[src];late_join=1'>Join Game!</A></p>"

		output += "<p><a href='byond://?src=\ref[src];observe=1'>Observe</A></p>"

		if(!IsGuestKey(src.key))
			establish_db_connection()

			if(dbcon.IsConnected())
				var/isadmin = 0
				if(src.client && src.client.holder)
					isadmin = 1
				var/DBQuery/query = dbcon.NewQuery("SELECT id FROM poll_question WHERE [(isadmin ? "" : "adminonly = false AND")] Now() BETWEEN starttime AND endtime AND id NOT IN (SELECT pollid FROM poll_vote WHERE ckey = \"[ckey]\") AND id NOT IN (SELECT pollid FROM poll_textreply WHERE ckey = \"[ckey]\")")
				query.Execute()
				var/newpoll = 0
				while(query.NextRow())
					newpoll = 1
					break

				if(newpoll)
					output += "<p><b><a href='byond://?src=\ref[src];showpoll=1'>Show Player Polls</A> (NEW!)</b></p>"
				else
					output += "<p><a href='byond://?src=\ref[src];showpoll=1'>Show Player Polls</A></p>"

		output += "</div>"

		var/datum/browser/popup = new(src, "playersetup", "New Player Options", 210, 280)
		popup.window_options = "focus=0;can_close=0;"
		popup.set_content(output)
		popup.open()

	Stat()
		..()

		if( !client )
			return

		if( ticker )
			statpanel("Lobby")

		if( client.statpanel == "Lobby" )
			if( !statMessage )
				statMessage = list()

			statMessage["Time To Start:"] = "[ticker.pregame_timeleft][going ? "" : " (DELAYED)"]"

			if( ticker.current_state == GAME_STATE_PREGAME && statMessage )
				for( var/variable in statMessage )
					var/list/L = statMessage[variable]
					if( !istype( L ))
						stat( "[variable]", "[L]" )
					else
						stat( "[variable]", null )
						for( var/V in L )
							stat( null, "[V]" )

	Topic(href, href_list[])
		if(!client)	return 0

		if( href_list["preference"] )
			if( client.prefs.process_links( src, href_list ))
				return 1

		if( href_list["show_preferences"] )
			client.prefs.ClientMenu( src )
			return 1

		if(href_list["ready"])
			if( !client.prefs.selected_character )
				client << "<span class='notice'>You have no character selected!</span>"
				return

			if( !client.prefs.selected_character.canJoin() )
				client << "<span class='notice'>You're not allowed to join the game as that character!</span>"
				return

			if((!ticker || ticker.current_state <= GAME_STATE_PREGAME)) // Make sure we don't ready up after the round has started, or without a selected character
				ready = !ready
			else
				ready = 0

			totalPlayers = 0
			totalPlayersReady = 0

			statMessage = list( "Time To Start:" = null, "Players Ready:" = null, "------------  Department  ------------" = "------------  Readied Roles  ------------")
			for( var/D in job_master.getDepartmentNames() )
				statMessage[D] = list()

			for(var/mob/new_player/player in player_list)
				totalPlayers++
				if( player.ready && player.client )
					var/client/C = player.client
					if( !istype( C ))
						continue
					if( !C.prefs )
						continue
					if( !C.prefs.selected_character )
						continue

					totalPlayersReady++

					var/datum/character/H = C.prefs.selected_character
					var/datum/job/J = job_master.GetJob( H.GetHighestLevelJob() )

					var/datum/department/D = job_master.GetDepartment( J.department_id )
					var/department = D.name

					if( !department )
						continue

					var/list/L = statMessage[department]
					if( !L )
						L = list()

					L += J.title // Adding this character's job
					statMessage[department] = L

			statMessage["Players Ready:"] = "[totalPlayersReady] / [totalPlayers]"

		if(href_list["refresh"])
			src << browse(null, "window=playersetup") //closes the player setup window
			new_player_panel_proc()

		if(href_list["observe"])
			if(alert(src,"Are you sure you wish to observe? You will have to wait 30 minutes before being able to respawn!","Player Setup","Yes","No") == "Yes")
				if(!client)	return 1
				var/mob/dead/observer/observer = new()

				spawning = 1
				src << sound(null, repeat = 0, wait = 0, volume = 85, channel = 1) // MAD JAMS cant last forever yo

				observer.started_as_observer = 1
				close_spawn_windows()
				src << "<span class='notice'>Now teleporting.</span>"
				observer.loc = observer_start[rand(1,observer_start.len)]
				observer.timeofdeath = world.time // Set the time of death so that the respawn timer works correctly.

				announce_ghost_joinleave(src)
				if( client && client.prefs && client.prefs.selected_character )
					client.prefs.selected_character.update_preview_icon()
					observer.icon = client.prefs.selected_character.preview_icon
					observer.real_name = client.prefs.selected_character.name
					observer.name = observer.real_name

				observer.alpha = 127

				if(!client.holder && !config.antag_hud_allowed)           // For new ghosts we remove the verb from even showing up if it's not allowed.
					observer.verbs -= /mob/dead/observer/verb/toggle_antagHUD        // Poor guys, don't know what they are missing!
				observer.key = key
				qdel(src)

				return 1

		if(href_list["late_join"])
			if(!ticker || ticker.current_state != GAME_STATE_PLAYING)
				usr << alert( "The round is either not ready, or has already finished..." )
				return 0

			if( !client || !client.prefs || !client.prefs.selected_character )
				usr << alert( "You have not selected a character!" )
				return 0

			var/species = client.prefs.selected_character.species

			if( !is_alien_whitelisted(src, species ))
				src << alert("You are currently not whitelisted to play [species].")
				return 0

			var/datum/species/S = all_species[species]

			if( !istype( S ))
				src << alert("Your select species does not exist!")
				return 0

			if( S.flags & IS_RESTRICTED )
				src << alert("Your current species, [species], is not available for play on the station.")
				return 0

			var/active_mobs = getActiveMobs()

			if( active_mobs >= config.player_hard_cap )
				var/answer = alert("The server has passed its max player cap. Would you like to join the thunderdome instead?","Thunderdome","Yes","No")
				if( answer == "Yes" )
					create_gladiator( src )
			else if( active_mobs >= config.player_soft_cap && !client.client_exists_in_db())
				var/answer = alert("The server has passed its new player cap. Since you have not played here before, you cannot join. Would you like to join the thunderdome instead?","Thunderdome","Yes","No")
				if( answer == "Yes" )
					create_gladiator( src )
			else
				LateChoices()

		if(href_list["manifest"])
			ViewManifest()

		if(href_list["SelectedJob"])
			if(!config.enter_allowed)
				usr << alert("There is an administrative lock on entering the game!")
				return

			if(ticker && ticker.mode && ticker.mode.explosion_in_progress)
				usr << alert("The station is currently exploding. Joining would go poorly.")
				return

			if( !client.prefs.selected_character )
				usr << alert("You have not selected a character to join as!")
				return

			var/species = client.prefs.selected_character.species

			if( !is_alien_whitelisted( src, species ))
				src << alert("You are currently not whitelisted to play [species]!")
				return 0

			var/datum/species/S = all_species[species]

			if( !S )
				src << alert("Your select species does not exist!")
				return 0

			if( S.flags & IS_RESTRICTED )
				src << alert("Your current species, [S], is not available for play on the station.")
				return 0

			AttemptLateSpawn(href_list["SelectedJob"],client.prefs.selected_character.spawnpoint)
			return

		if(!ready && href_list["preference"])
			if(client)
				client.prefs.Topic(src, href_list)
		else if(!href_list["late_join"])
			new_player_panel()

		if(href_list["showpoll"])

			handle_player_polling()
			return

		if(href_list["pollid"])

			var/pollid = href_list["pollid"]
			if(istext(pollid))
				pollid = text2num(pollid)
			if(isnum(pollid))
				src.poll_player(pollid)
			return

		if(href_list["votepollid"] && href_list["votetype"])
			var/pollid = text2num(href_list["votepollid"])
			var/votetype = href_list["votetype"]
			switch(votetype)
				if("OPTION")
					var/optionid = text2num(href_list["voteoptionid"])
					vote_on_poll(pollid, optionid)
				if("TEXT")
					var/replytext = href_list["replytext"]
					log_text_poll_reply(pollid, replytext)
				if("NUMVAL")
					var/id_min = text2num(href_list["minid"])
					var/id_max = text2num(href_list["maxid"])

					if( (id_max - id_min) > 100 )	//Basic exploit prevention
						usr << "The option ID difference is too big. Please contact administration or the database admin."
						return

					for(var/optionid = id_min; optionid <= id_max; optionid++)
						if(!isnull(href_list["o[optionid]"]))	//Test if this optionid was replied to
							var/rating
							if(href_list["o[optionid]"] == "abstain")
								rating = null
							else
								rating = text2num(href_list["o[optionid]"])
								if(!isnum(rating))
									return

							vote_on_numval_poll(pollid, optionid, rating)
				if("MULTICHOICE")
					var/id_min = text2num(href_list["minoptionid"])
					var/id_max = text2num(href_list["maxoptionid"])

					if( (id_max - id_min) > 100 )	//Basic exploit prevention
						usr << "The option ID difference is too big. Please contact administration or the database admin."
						return

					for(var/optionid = id_min; optionid <= id_max; optionid++)
						if(!isnull(href_list["option_[optionid]"]))	//Test if this optionid was selected
							vote_on_poll(pollid, optionid, 1)

	proc/IsJobAvailable(rank)
		var/datum/job/job = job_master.GetJob(rank)
		if(!job) return 0
		if(!job.can_join( src.client )) return 0
		return 1

	proc/AttemptLateSpawn(rank,var/spawning_at)
		if (src != usr)
			return 0
		if(!ticker || ticker.current_state != GAME_STATE_PLAYING)
			usr << "<span class='alert'>The round is either not ready, or has already finished...</span>"
			return 0
		if(!config.enter_allowed)
			usr << "<span class='notice'>There is an administrative lock on entering the game!</span>"
			return 0
		if( !client.prefs.selected_character )
			usr << "<span class='notice'>You have no character selected!</span>"
			return
		if( !client.prefs.selected_character.canJoin() )
			usr << "<span class='notice'>You're not allowed to join the game as that character!</span>"
			return 0
		if(!IsJobAvailable(rank))
			src << alert("[rank] is not available. Please try another.")
			return 0

		spawning = 1
		close_spawn_windows()

		job_master.AssignRole(src, rank, 1)

		var/mob/living/character = create_character()	//creates the human and transfers vars and mind
		character = job_master.EquipRank(character, rank, 1)					//equips the human
		UpdateFactionList(character)
		EquipCustomItems(character)

		//Find our spawning point.
		var/join_message
		var/datum/spawnpoint/S

		if(spawning_at)
			S = spawntypes[spawning_at]

		if(S && istype(S))
			if(S.check_job_spawning(rank))
				character.loc = pick(S.turfs)
				join_message = S.msg
			else
				character << "Your chosen spawnpoint ([S.display_name]) is unavailable for your chosen job. Spawning you at the Arrivals shuttle instead."
				character.loc = pick(latejoin)
				join_message = "has arrived on the station"
		else
			character.loc = pick(latejoin)
			join_message = "has arrived on the station"

		character.lastarea = get_area(loc)
		// Moving wheelchair if they have one
		if(character.buckled && istype(character.buckled, /obj/structure/bed/chair/wheelchair))
			character.buckled.loc = character.loc
			character.buckled.set_dir(character.dir)

		ticker.mode.latespawn(character)

		//ticker.mode.latespawn(character)

		if(character.mind.assigned_role != "Cyborg")
			data_core.manifest_inject(character)
			ticker.minds += character.mind//Cyborgs and AIs handle this in the transform proc.	//TODO!!!!! ~Carn

			//Grab some data from the character prefs for use in random news procs.

			AnnounceArrival(character, rank, join_message)
		else
			AnnounceCyborg(character, rank, join_message)

		qdel(src)

	proc/AnnounceArrival(var/mob/living/carbon/human/character, var/rank, var/join_message)
		if (ticker.current_state == GAME_STATE_PLAYING)
			if(character.mind.role_alt_title)
				rank = character.mind.role_alt_title
			global_announcer.autosay("[character.real_name],[rank ? " [rank]," : " visitor," ] [join_message ? join_message : "has arrived on the station"].", "Arrivals Announcement Computer")

	proc/AnnounceCyborg(var/mob/living/character, var/rank, var/join_message)
		if (ticker.current_state == GAME_STATE_PLAYING)
			if(character.mind.role_alt_title)
				rank = character.mind.role_alt_title
			// can't use their name here, since cyborg namepicking is done post-spawn, so we'll just say "A new Cyborg has arrived"/"A new Android has arrived"/etc.
			global_announcer.autosay("A new[rank ? " [rank]" : " visitor" ] [join_message ? join_message : "has arrived on the station"].", "Arrivals Announcement Computer")


	proc/LateChoices()
		var/mills = world.time // 1/10 of a second, not real milliseconds but whatever
		//var/secs = ((mills % 36000) % 600) / 10 //Not really needed, but I'll leave it here for refrence.. or something
		var/mins = (mills % 36000) / 600
		var/hours = mills / 36000

		var/name = client.prefs.selected_character.name

		var/dat = "<html><body><center>"
		dat += "<b>Welcome, [name].<br></b>"
		dat += "Round Duration: [round(hours)]h [round(mins)]m<br>"

		if(emergency_shuttle) //In case Nanotrasen decides reposess CentComm's shuttles.
			if(emergency_shuttle.going_to_centcom()) //Shuttle is going to centcomm, not recalled
				dat += "<font color='red'><b>The station has been evacuated.</b></font><br>"
			if(emergency_shuttle.online())
				if (emergency_shuttle.evac)	// Emergency shuttle is past the point of no recall
					dat += "<font color='red'>The station is currently undergoing evacuation procedures.</font><br>"
				else						// Crew transfer initiated
					dat += "<font color='red'>The station is currently undergoing crew transfer procedures.</font><br>"

		dat += "Choose from the following open positions:<br>"
		for(var/role in client.prefs.selected_character.roles)
			var/datum/job/job = job_master.GetJob( role )

			if( !istype( job ))
				continue

			if( !job.can_join( client ))
				continue

			if(job && IsJobAvailable(job.title))
				var/active = 0
				// Only players with the job assigned and AFK for less than 10 minutes count as active
				for(var/mob/M in player_list) if(M.mind && M.client && M.mind.assigned_role == job.title && M.client.inactivity <= 10 * 60 * 10)
					active++
				dat += "<a href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] ([job.current_positions]) (Active: [active])</a><br>"

		dat += "</center>"
		src << browse(dat, "window=latechoices;size=300x640;can_close=1")


	proc/create_character()
		spawning = 1
		close_spawn_windows()

		var/mob/living/carbon/human/new_character

		var/datum/species/chosen_species
		if(client.prefs.selected_character.species)
			chosen_species = all_species[client.prefs.selected_character.species]
		if(chosen_species)
			// Have to recheck admin due to no usr at roundstart. Latejoins are fine though.
			if(is_species_whitelisted(chosen_species) || has_admin_rights())
				new_character = new(loc, client.prefs.selected_character.species)

		if(!new_character)
			new_character = new(loc)

		new_character.lastarea = get_area(loc)

		var/datum/language/chosen_language
		if(client.prefs.selected_character.additional_language)
			chosen_language = all_languages["[client.prefs.selected_character.additional_language]"]
		if(chosen_language)
			if(is_alien_whitelisted(src, client.prefs.selected_character.additional_language) || !config.usealienwhitelist || !(chosen_language.flags & WHITELISTED) || (new_character.species && (chosen_language.name in new_character.species.secondary_langs)))
				new_character.add_language("[client.prefs.selected_character.additional_language]")

		if(ticker.random_players)
			new_character.gender = pick(MALE, FEMALE)
			client.prefs.selected_character.name = random_name(new_character.gender)
			client.prefs.selected_character.randomize_appearance_for(new_character)
		else
			client.prefs.selected_character.copy_to(new_character)

		src << sound(null, repeat = 0, wait = 0, volume = 85, channel = 1) // MAD JAMS cant last forever yo

		if(mind)
			mind.active = 0					//we wish to transfer the key manually
			if(mind.assigned_role == "Clown")				//give them a clownname if they are a clown
				new_character.real_name = pick(clown_names)	//I hate this being here of all places but unfortunately dna is based on real_name!
				new_character.rename_self("clown")
			mind.original = new_character
			mind.transfer_to(new_character)					//won't transfer key since the mind is not active

		new_character.name = real_name
		new_character.dna.ready_dna(new_character)
		new_character.dna.b_type = client.prefs.selected_character.blood_type

		if(client.prefs.selected_character.disabilities)
			// Set defer to 1 if you add more crap here so it only recalculates struc_enzymes once. - N3X
			new_character.dna.SetSEState(GLASSESBLOCK,1,0)
			new_character.disabilities |= NEARSIGHTED

		// And uncomment this, too.
		//new_character.dna.UpdateSE()

		// Do the initial caching of the player's body icons.
		new_character.regenerate_icons()

		new_character.key = key		//Manually transfer the key to log them in

		return new_character

	proc/ViewManifest()
		var/dat = "<html><body>"
		dat += "<h4>Show Crew Manifest</h4>"
		dat += data_core.get_manifest(OOC = 1)

		var/datum/browser/popup = new(src, "manifest", "Show Crew Manifest", 370, 420)
		popup.set_content(dat)
		popup.open()

	Move()
		return 0

	proc/close_spawn_windows()
		winshow( src, "client_menu", 0)
		winshow( src, "select_character_menu", 0)
		winshow( src, "pref_menu", 0)

		src << browse(null, "window=latechoices") //closes late choices window
		src << browse(null, "window=playersetup") //closes the player setup window

	proc/has_admin_rights()
		return client.holder.rights & R_ADMIN

	proc/is_species_whitelisted(datum/species/S)
		if(!S) return 1
		return is_alien_whitelisted(src, S.name) || !config.usealienwhitelist || !(S.flags & IS_WHITELISTED)

/mob/new_player/get_species()
	var/datum/species/chosen_species
	if(client.prefs.selected_character.species)
		chosen_species = all_species[client.prefs.selected_character.species]

	if(!chosen_species)
		return "Human"

	if(is_species_whitelisted(chosen_species) || has_admin_rights())
		return chosen_species.name

	return "Human"

/mob/new_player/get_gender()
	if(!client || !client.prefs) ..()
	return client.prefs.selected_character.gender

/mob/new_player/is_ready()
	return ready && ..()

/mob/new_player/hear_say(var/message, var/verb = "says", var/datum/language/language = null, var/alt_name = "",var/italics = 0, var/mob/speaker = null)
	return

/mob/new_player/hear_radio(var/message, var/verb="says", var/datum/language/language=null, var/part_a, var/part_b, var/mob/speaker = null, var/hard_to_hear = 0)
	return

/proc/isBaldie( var/mob/living/carbon/human/C )
	if( C.character.hair_style == "Bald" && C.character.hair_face_style == "Shaved" )
		return 1
	return 0

/proc/getActiveMobs()
	var/active_mobs = 0

	for(var/mob/living/M in mob_list)
		if( M.client )
			active_mobs++

	return active_mobs

//Simple borg hand.
//Limited use.
/obj/item/gripper
	name = "magnetic gripper"
	desc = "A simple grasping tool specialized in construction and engineering work."
	icon = 'icons/obj/item/gripper.dmi'
	icon_state = "gripper"

	item_flags = ITEM_FLAG_NO_BLUDGEON
	force = 18 // Crowbar strength

	/// A whitelist of held items. If cant_hold is undefined, items not in this list can't be picked up. If defined, this list overrides definitions there.
	var/list/can_hold = list(
		/obj/item/cell,
		/obj/item/firealarm_electronics,
		/obj/item/airalarm_electronics,
		/obj/item/airlock_electronics,
		/obj/item/tracker_electronics,
		/obj/item/module/power_control,
		/obj/item/stock_parts,
		/obj/item/frame,
		/obj/item/floor_frame,
		/obj/item/camera_assembly,
		/obj/item/tank,
		/obj/item/circuitboard,
		/obj/item/smes_coil,
		/obj/item/assembly,
		/obj/item/assembly_holder,
		/obj/item/computer_hardware,
		/obj/item/pipe,
		/obj/item/paper,
		/obj/item/smallDelivery,
		/obj/item/gift,
		/obj/item/fuel_assembly
		)

	/// A blacklist of held items. Allows all unlisted items to be picked up if defined. Listed items/subtypes can be overridden using can_hold.
	var/list/cant_hold

	var/obj/item/wrapped

	var/force_holder
	var/mutable_appearance/item_overlay

/obj/item/gripper/examine(mob/user, distance, is_adjacent, infix, suffix, show_extended)
	. = ..()
	if(wrapped)
		wrapped.examine(arglist(args))

/obj/item/gripper/get_examine_text(mob/user, distance, is_adjacent, infix, suffix)
	. = ..()
	if(wrapped)
		. += SPAN_NOTICE("It is holding \the [wrapped].")

/**
 * Resets a gripper's force and icon if an item is dropped or otherwise moved from the gripper.
 * Returns TRUE if the object is still in the gripper.
 * Returns FALSE if the object has left the gripper or doesn't exist anymore.
 */
/obj/item/gripper/proc/grippersafety()
	SIGNAL_HANDLER
	// We don't have an item
	if(!wrapped)
		return FALSE
	//The object left the gripper but it still exists. Maybe placed on a table
	if(wrapped.loc != src)
		//Reset the force and then remove our reference to it
		wrapped.force = force_holder
		UnregisterSignal(wrapped, COMSIG_MOVABLE_MOVED)
		wrapped = null
		force_holder = null
		update_icon()
		return FALSE
	return TRUE

/**
 * Handles picking up an item using a gripper.
 *
 * Returns TRUE if we grabbed an item.
 * Returns FALSE if we couldn't grab an item.
 */
/obj/item/gripper/proc/grip_item(var/obj/item/target, var/mob/user, var/feedback = TRUE)
	if(!wrapped)
		if((can_hold && is_type_in_list(target, can_hold)) || (cant_hold && !is_type_in_list(target, cant_hold)))
			if(target.anchored)
				to_chat(user, SPAN_WARNING("\The [target] is anchored down!"))
				return FALSE
			if(!target.Adjacent(user))
				to_chat(user, SPAN_WARNING("\The [target] is too far away!"))
				return FALSE
			if(feedback)
				to_chat(user, SPAN_NOTICE("You collect \the [target]."))
			target.pickup(user)
			if(istype(target.loc, /obj/item/storage))
				var/obj/item/storage/our_container = target.loc
				our_container.remove_from_storage(target, src)
			else
				target.forceMove(src)
			wrapped = target
			RegisterSignal(wrapped, COMSIG_MOVABLE_MOVED, PROC_REF(grippersafety))
			wrapped.pixel_x = 0
			wrapped.pixel_y = 0
			update_icon()
			return TRUE
		if(feedback)
			to_chat(user, SPAN_WARNING("Your gripper cannot hold \the [target]."))
		return FALSE
	if(feedback)
		to_chat(user, SPAN_WARNING("Your gripper is already holding \the [wrapped]."))
	return FALSE

/// Puts the item's sprite on our gripper so the borg can keep track of what they're carrying
/obj/item/gripper/update_icon()
	CutOverlays(item_overlay)
	if(QDELETED(wrapped) || wrapped.loc != src)
		return
	if(wrapped)
		item_overlay = new(wrapped)
		item_overlay.pixel_y = -8
		AddOverlays(item_overlay)

/obj/item/gripper/attack_self(mob/user)
	if(wrapped)
		. = wrapped.attack_self(user)
		update_icon()
		return
	return ..()

/obj/item/gripper/AltClick(mob/user)
	if(wrapped)
		. = wrapped.AltClick(user)
		update_icon()
	return ..()

/obj/item/gripper/CtrlClick(mob/user)
	if(wrapped)
		drop(get_turf(src), user)
		return
	to_chat(user, SPAN_WARNING("\The [src] isn't gripping anything!"))

/obj/item/gripper/verb/drop_item()
	set name = "Drop Item"
	set desc = "Release an item from your magnetic gripper."
	set category = "Robot Commands"

	drop(get_turf(src), usr)

/**
 * Drop an item from the gripper onto the target
 *
 * * target - An `/atom` to drop (move) the item onto
 * * user - The `/mob` that is dropping it
 * * feedback - Boolean, if `TRUE` prints a message about the drop
 */
/obj/item/gripper/proc/drop(atom/target, mob/user, feedback = TRUE)
	if(!istype(target))
		crash_with("The target to drop the item onto is not specified or is incorrect!")

	if(!istype(user))
		crash_with("The user that is performing the drop is not specified or is incorrect!")


	if(wrapped)
		if(wrapped.loc != src)
			return
		if(force_holder)
			wrapped.force = force_holder
		UnregisterSignal(wrapped, COMSIG_MOVABLE_MOVED)
		wrapped.forceMove(target)
		wrapped.dropped(user)
		force_holder = null
		if(feedback)
			to_chat(user, SPAN_NOTICE("You release \the [wrapped]."))

	wrapped = null
	update_icon()
	return TRUE

/obj/item/gripper/attack(mob/living/target_mob, mob/living/user, target_zone)
	if(wrapped) //The force of the wrapped obj gets set to zero during the attack() and afterattack().
		force_holder = wrapped.force
		wrapped.force = 0

		var/resolved = wrapped.attack(target_mob, user)

		if(QDELETED(wrapped))
			drop(get_turf(src), user, FALSE)

		update_icon()

		return resolved

	else // mob interactions

		switch(user.a_intent)
			if(I_HELP)
				user.visible_message("\The [user] [pick("boops", "squeezes", "pokes", "prods", "strokes", "bonks")] \the [target_mob] with \the [src]")
			if(I_HURT)
				target_mob.attack_generic(user, user.mob_size * 1.5, "crushed")
				//Attack generic does a visible message so we dont need one here
				user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN * 3)
				playsound(user, 'sound/effects/attackblob.ogg', 60, 1)
				//Slow,powerful attack for borgs. No spamclicking
	return FALSE

/obj/item/gripper/attackby(obj/item/attacking_item, mob/user)
	var/resolved = FALSE

	if(wrapped)
		if(attacking_item == wrapped)
			attack_self(user) //Allows gripper to be clicked to use item.
			update_icon()
			return TRUE

		resolved = wrapped.attackby(attacking_item,user)

		if(!resolved)
			attacking_item.afterattack(wrapped, user, TRUE)//We pass along things targeting the gripper, to objects inside the gripper. So that we can draw chemicals from held beakers for instance

		update_icon()

	return resolved

/obj/item/gripper/afterattack(var/atom/target, var/mob/living/user, proximity, params)
 	// If we already have an item, we run its afterattack
	if(wrapped)
		wrapped.afterattack(target, user, proximity, params)
		grippersafety()
		if(QDELETED(wrapped))
			drop(get_turf(src), user, FALSE)
		return
	// Next bits require proximity, so bail out if we don't have it
	if(!proximity)
		return
	// Still no item, see if we can pick up our target
	if(istype(target, /obj/item))
		grip_item(target, user)
		return
	target.attack_ai(user)

/obj/item/gripper/resolve_attackby(atom/A, mob/user, var/click_parameters)
	if(wrapped)
		return wrapped.resolve_attackby(A, user, click_parameters)
	else
		. = ..()

/*
	//Definitions of gripper subtypes
*/
/**
* A limited gripper used by mining borgs. Basically only for swapping cells, upgrading drills, and upgrading custom KAs.
*/
/obj/item/gripper/miner
	name = "drill maintenance gripper"
	desc = "A simple grasping tool for the maintenance and upgrade of heavy drilling machines."
	icon_state = "gripper-mining"

	can_hold = list(
		/obj/item/cell,
		/obj/item/stock_parts,
		/obj/item/custom_ka_upgrade,
		/obj/item/warp_core,
		/obj/item/extraction_pack,
		/obj/item/paper,
		/obj/item/smallDelivery,
		/obj/item/gift,
		/obj/item/mine_bot_upgrade,
		/obj/item/spaceflare,
		/obj/item/orbital_dropper
	)

/obj/item/gripper/paperwork
	name = "paperwork gripper"
	desc = "A simple grasping tool for clerical work."

	can_hold = list(
		/obj/item/clipboard,
		/obj/item/paper,
		/obj/item/paper_bundle,
		/obj/item/canvas,
		/obj/item/pen,
		/obj/item/card/id,
		/obj/item/book,
		/obj/item/newspaper,
		/obj/item/stamp,
		/obj/item/ducttape,
		/obj/item/smallDelivery,
		/obj/item/gift,
		/obj/item/stack/packageWrap,
		/obj/item/stack/wrapping_paper,
		/obj/item/computer_hardware/hard_drive/portable,
		/obj/item/photo
		)

/**
 * A general-purpose gripper for research borgs. Allows them to interact with toxins/xenobio/xenoarch/robotics/etc.
 */
/obj/item/gripper/research
	name = "scientific gripper"
	icon_state = "gripper-sci"
	desc = "A simple grasping tool suited to assist in a wide array of research applications."

	can_hold = list(
		/obj/item/cell,
		/obj/item/stock_parts,
		/obj/item/mmi,
		/obj/item/robot_parts,
		/obj/item/mech_component,
		/obj/item/mecha_equipment,
		/obj/item/rig_module,
		/obj/item/radio/exosuit,
		/obj/item/borg/upgrade,
		/obj/item/flash, // to build borgs,
		/obj/item/organ/internal/brain, // to insert into MMIs,
		/obj/item/stack/cable_coil, // again, for borg building,
		/obj/item/circuitboard,
		/obj/item/slime_extract,
		/obj/item/slime_scanner,
		/obj/item/reagent_containers/glass,
		/obj/item/reagent_containers/food/snacks/monkeycube,
		/obj/item/seeds, // To be able to plant things for Xenobotany
		/obj/item/grown, // To be able to plant things for Xenobotany
		/obj/item/assembly,
		/obj/item/assembly_holder,
		/obj/item/healthanalyzer,// For building medibots
		/obj/item/disk,
		/obj/item/analyzer/plant_analyzer,//For farmbot construction
		/obj/item/material/minihoe, // Farmbots and xenoflora
		/obj/item/computer_hardware,
		/obj/item/slimesteroid,
		/obj/item/extract_enhancer,
		/obj/item/docility_serum,
		/obj/item/advanced_docility_serum,
		/obj/item/remote_mecha,
		/obj/item/smallDelivery,
		/obj/item/gift,
		/obj/item/integrated_circuit_printer,
		/obj/item/deployable_kit/remote_mech
		)

/**
 * A gripper designed to manipulate pharmaceutical and medical items.
 */
/obj/item/gripper/chemistry
	name = "medical gripper"
	icon_state = "gripper-sci"
	desc = "A specialised grasping tool designed for working in medical treatment facilities and pharmaceutical labs."

	can_hold = list(
		/obj/item/reagent_containers/glass,
		/obj/item/reagent_containers/food/snacks/monkeycube,
		/obj/item/organ,
		/obj/item/reagent_containers/pill,
		/obj/item/reagent_containers/spray,
		/obj/item/personal_inhaler,
		/obj/item/reagent_containers/personal_inhaler_cartridge,
		/obj/item/reagent_containers/inhaler,
		/obj/item/reagent_containers/hypospray,
		/obj/item/storage/pill_bottle,
		/obj/item/hand_labeler,
		/obj/item/paper,
		/obj/item/stack/material/phoron,
		/obj/item/reagent_containers/blood,
		/obj/item/reagent_containers/food/drinks/sillycup,
		/obj/item/clothing/mask/breath,
		/obj/item/tank,
		/obj/item/smallDelivery,
		/obj/item/gift,
		/obj/item/reagent_containers/chem_disp_cartridge
		)

/**
 * Used to handle food, drinks, and seeds.
 */
/obj/item/gripper/service
	name = "service gripper"
	icon_state = "gripper"
	desc = "A simple grasping tool used to perform tasks in the service sector, such as handling food, drinks, and seeds."

	can_hold = list(
		/obj/item/reagent_containers/glass,
		/obj/item/reagent_containers/food,
		/obj/item/seeds,
		/obj/item/grown,
		/obj/item/trash,
		/obj/item/reagent_containers/cooking_container,
		/obj/item/material/kitchen,
		/obj/item/reagent_containers/food/snacks,
		/obj/item/smallDelivery,
		/obj/item/gift,
		/obj/item/stack/packageWrap,
		/obj/item/stack/wrapping_paper,
		/obj/item/reagent_containers/chem_disp_cartridge //Drink cartridges
		)

/**
 * Used when you want a robot to be able to hold an item, but not able to 'use' the item.
 * E.g. picking up a stack to load it into a machine, but not building with the stack.
 */
/obj/item/gripper/no_use

/obj/item/gripper/no_use/attack_self(mob/user)
	return

/**
 * A gripper subtype used to disallow building with sheets.
 */
/obj/item/gripper/no_use/loader
	name = "sheet holder"
	desc = "A specialized holding device, designed to hold sheets of material or tiling."
	icon_state = "gripper-sheet"

	can_hold = list(
		/obj/item/stack/material,
		/obj/item/stack/tile
		)

/**
 * A general-purpose gripper used by maintenance drones.
 */
/obj/item/gripper/multi_purpose
	name = "multi-purpose gripper"
	desc = "An articulate gripper suited to carrying a wide variety of objects you could encounter on a space-faring vessel."
	can_hold = null
	cant_hold = list(
		/obj/item/stack,
		/obj/item/gun,
		/obj/item/clothing,
		/obj/item/storage,
		/obj/item/modular_computer,
		/obj/item/card/id
	)

/**
 * Debug gripper for bluespace borgs
 */
/obj/item/gripper/debug
	name = "articulated gripper"
	desc = "A complex articulated gripper. Essentially just a hand."
	can_hold = null
	cant_hold = list()

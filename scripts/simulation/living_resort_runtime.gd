class_name LivingResortRuntime
extends RefCounted
## Integration boundary for the population and its independently owned services.
## A restore stages a complete candidate; a broken service cannot partially load.
var layout: ResortLayout
var assets: ResortAssets
var simulation: RefCounted
var facilities: RefCounted
var cleanliness: RefCounted
var ledger: RefCounted
var challenges := ResortChallenges.new()
const SERVICES := {
	"simulation":"res://scripts/simulation/resort_simulation.gd",
	"facilities":"res://scripts/simulation/facility_sessions.gd",
	"cleanliness":"res://scripts/simulation/cleanliness_system.gd",
	"ledger":"res://scripts/simulation/operating_ledger.gd"
}
const RECEIPTS_PER_PAGE := 25

func configure(map: ResortLayout, library: ResortAssets) -> bool:
	layout=map
	challenges = ResortChallenges.new()
	assets=library if library!=null else ResortAssets.new()
	for name: String in ["guest_brain","guest_profiles"]:
		if not ResourceLoader.exists("res://scripts/simulation/%s.gd" % name): return false
	for key: String in SERVICES:
		if not ResourceLoader.exists(SERVICES[key]): return false
		var script := load(SERVICES[key]) as Script
		if script==null or not script.can_instantiate(): return false
		set(key,script.new())
	facilities.call("configure",layout,assets)
	cleanliness.call("configure",layout,assets)
	simulation.call("configure",layout,assets)
	_attach()
	return true

func _attach() -> void:
	simulation.set("facilities",facilities)
	simulation.set("cleanliness",cleanliness)
	simulation.set("ledger",ledger)
	simulation.set("upkeep_enabled", true)

func advance(delta: float) -> void:
	simulation.call("advance",delta)

func cash() -> int:
	return ResortEconomy.OPENING_CASH + int(ledger.call("profit"))

func record_construction(item: String, refund := false) -> bool:
	var price := ResortEconomy.purchase(item)
	if not refund and cash() < price: return false
	var sequence := int(ledger.call("receipt_count")) + 1
	return ledger.call("record", {"id": "resort:construction:%d" % sequence,
		"kind": "refund" if refund else "construction", "item": item, "quantity": 1, "unit_price": price,
		"amount": price if refund else -price, "time": float(simulation.get("clock"))})

func capture() -> Dictionary:
	var snapshot := {"version":1,"simulation":simulation.call("capture"),"facilities":facilities.call("capture"),"cleanliness":cleanliness.call("capture"),"ledger":ledger.call("capture")}
	var progress := challenges.capture()
	if not progress.claims.is_empty() or not progress.attempt.is_empty():
		snapshot["challenges"] = progress
	return snapshot

func restore(data: Dictionary) -> bool:
	if not _integer(data.get("version")) or int(data.version)!=1: return false
	for key: String in SERVICES:
		if not data.get(key) is Dictionary: return false
	var candidate := LivingResortRuntime.new()
	if not candidate.configure(layout,assets): return false
	if not candidate.simulation.call("restore",data.simulation): return false
	if not candidate.facilities.call("restore",data.facilities): return false
	if not candidate.cleanliness.call("restore",data.cleanliness): return false
	if not candidate.ledger.call("restore",data.ledger): return false
	if data.has("challenges"):
		if not data.challenges is Dictionary or not candidate.challenges.restore(data.challenges, float(candidate.simulation.get("clock")), candidate.ledger): return false
	if not candidate._cross_validate(): return false
	simulation=candidate.simulation
	facilities=candidate.facilities
	cleanliness=candidate.cleanliness
	ledger=candidate.ledger
	challenges=candidate.challenges
	_attach()
	return true

func import_legacy(data: Dictionary) -> bool:
	var candidate := LivingResortRuntime.new()
	if not candidate.configure(layout,assets): return false
	if not candidate.simulation.call("import_legacy",data): return false
	# Older stays have aggregate room/activity spending, no transaction journal.
	# Record honest opening totals instead of guessing which old meal was bought.
	var clock: float=candidate.simulation.get("clock")
	candidate.facilities.call("advance",0.0,clock,candidate.simulation.get("people"))
	candidate.cleanliness.call("advance",0.0,clock)
	for party: Dictionary in candidate.simulation.get("parties"):
		for item: Array in [["room",int(party.get("room_spent",0))],["legacy_income",int(party.get("activity_spent",0))]]:
			if item[1]>0:
				candidate.ledger.call("record",{"id":"import-%d-%s" % [party.id,item[0]],"kind":item[0],"amount":item[1],"time":clock,"party_id":party.id})
	# Reconstruct occupied furniture claims for old mid-activity saves. No fees
	# are charged here: the imported person's session_paid marker owns that fact.
	for person: Dictionary in candidate.simulation.get("people"):
		if int(person.get("facility_id",-1))<1 or not ResortServices.KINDS.has(person.get("activity", "")): continue
		if str(person.get("state","")) not in ["approaching_activity","sitting","eating","lying","volleyball","using_facility","leaving_activity"]: continue
		var ticket: Dictionary=candidate.facilities.call("request",person.id,person.party_id,person.facility_id,person.activity,clock)
		if str(ticket.get("status",""))=="expired": return false
		person.slot=int(ticket.get("slot",person.get("slot",0)))
		if person.state not in ["approaching_activity","leaving_activity"]: candidate.facilities.call("confirm_arrival",person.id,clock)
	if not candidate._cross_validate(): return false
	simulation=candidate.simulation
	facilities=candidate.facilities
	cleanliness=candidate.cleanliness
	ledger=candidate.ledger
	challenges=candidate.challenges
	_attach()
	return true

func inspect(selected_person_id: int=-1, following: bool=false, requested_page := 0) -> Dictionary:
	var view: Dictionary=simulation.call("inspect")
	view["facilities"]=facilities.call("inspect")
	view["cleanliness"]=cleanliness.call("inspect")
	view["operations"]=ledger.call("inspect",float(simulation.get("clock")))
	view.operations["cash"] = cash()
	view.operations["opening_cash"] = ResortEconomy.OPENING_CASH
	var pages := maxi(1, ceili(float(view.operations.event_count) / RECEIPTS_PER_PAGE))
	var page := clampi(requested_page, 0, pages - 1)
	view.operations["receipts"] = ledger.call("receipt_page", page, RECEIPTS_PER_PAGE)
	view.operations["receipt_page"] = page
	view.operations["receipt_pages"] = pages
	var prices := {}
	for service: String in ResortEconomy.DEFAULT_PRICES:
		prices[service] = layout.price(service)
	view["prices"] = prices
	view["challenges"] = challenges.inspect(float(simulation.get("clock")), ledger)
	view["statue_unlocked"] = challenges.statue_unlocked()
	view["selected_person_id"]=selected_person_id
	view["following"]=following
	return view

func protects(id: int) -> bool:
	return simulation.call("protects",id)

func access_survives(candidate: ResortLayout) -> bool:
	return simulation.call("access_survives",candidate) and cleanliness.call("access_survives",candidate)

func layout_changed() -> void:
	simulation.call("layout_changed")

func contains_person(rect: Rect2) -> bool:
	for person: Dictionary in simulation.get("people"):
		if person.get("state")!="departed" and rect.has_point(person.motion.position): return true
	var view: Dictionary=cleanliness.call("inspect")
	for person: Dictionary in view.get("staff",[]):
		if person.get("position") is Vector2 and rect.has_point(person.position): return true
	return false

func _cross_validate() -> bool:
	var shared_clock := float(simulation.get("clock"))
	if not challenges.statue_unlocked():
		for object in layout.objects:
			if object.kind == ResortChallenges.STATUE: return false
	for service: RefCounted in [facilities,cleanliness]:
		var state: Dictionary=service.call("capture")
		var value: Variant=state.get("clock")
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)-shared_clock)>0.000001: return false
	var people_ids: Dictionary={}
	var party_ids: Dictionary={}
	var booked: Dictionary={}
	for party: Dictionary in simulation.get("parties"):
		if not _integer(party.get("id")) or int(party.id)<1 or party_ids.has(int(party.id)): return false
		party_ids[int(party.id)]=party
		for key in ["nights","initial_budget","budget","cabin_id","paid_nights","room_spent","activity_spent"]:
			if not _integer(party.get(key)): return false
		if party.nights<1 or party.nights>3 or party.paid_nights<0 or party.paid_nights>party.nights or party.budget<0: return false
		if not ResortEconomy.valid_price(party.get("rate")) or party.room_spent!=party.paid_nights*party.rate or party.budget+party.room_spent+party.activity_spent!=party.initial_budget or party.activity_spent<0: return false
		if not party.get("member_ids") is Array or party.member_ids.is_empty() or party.member_ids.size()>2: return false
		if party.cabin_id>0:
			if layout.find_object(int(party.cabin_id)).get("kind")!="cabin" or booked.has(int(party.cabin_id)): return false
			booked[int(party.cabin_id)]=party.id
	for person: Dictionary in simulation.get("people"):
		if not _integer(person.get("id")) or int(person.id)<1 or people_ids.has(int(person.id)): return false
		if not _integer(person.get("party_id")) or not party_ids.has(int(person.party_id)): return false
		if not person.get("profile") is Dictionary or person.profile.get("variant") not in ["female","male"]: return false
		if not person.id in party_ids[int(person.party_id)].member_ids: return false
		people_ids[int(person.id)]=person
	for party: Dictionary in party_ids.values():
		var members: Dictionary={}
		for id: Variant in party.member_ids:
			if not _integer(id) or members.has(int(id)) or not people_ids.has(int(id)) or people_ids[int(id)].party_id!=party.id: return false
			members[int(id)]=true
	var raw: Dictionary=facilities.call("capture")
	var population: Dictionary=simulation.call("capture")
	var staff_state: Dictionary=cleanliness.call("capture")
	var tickets: Variant=raw.get("tickets",[])
	if tickets is Dictionary: tickets=tickets.values()
	if not tickets is Array: return false
	var slots: Dictionary={}
	var tickets_by_person: Dictionary={}
	for ticket: Variant in tickets:
		if not ticket is Dictionary or not _integer(ticket.get("person_id")): return false
		tickets_by_person[int(ticket.person_id)]=ticket
		if ticket.get("status")=="expired" and not ticket.get("claim_held",false): continue
		if not people_ids.has(int(ticket.person_id)): return false
		var owner: Dictionary=people_ids[int(ticket.person_id)]
		if owner.party_id!=ticket.get("party_id") or owner.facility_id!=ticket.get("facility_id") or owner.activity!=ticket.get("activity"): return false
		if ticket.get("claim_held",ticket.get("status") in ["reserved","active"]):
			var key := "%s/%s" % [ticket.get("facility_id"),ticket.get("slot")]
			if slots.has(key): return false
			slots[key]=true
	# Service validation alone permits an empty service. The population must
	# retain ownership in the opposite direction as well, including its exit.
	if population.sessions_external:
		for owner: Dictionary in people_ids.values():
			if owner.state not in ["to_facility","queueing","approaching_activity","sitting","eating","lying","volleyball","using_facility","waiting_partner","leaving_activity"]: continue
			var ticket: Dictionary=tickets_by_person.get(int(owner.id),{})
			if ticket.is_empty() or ticket.party_id!=owner.party_id or ticket.facility_id!=owner.facility_id or ticket.activity!=owner.activity: return false
			if owner.state in ["sitting","eating","lying","volleyball","using_facility"] and (not ticket.claim_held or ticket.status!="active" or ticket.slot!=owner.slot): return false
	var finances: Dictionary=ledger.call("inspect",float(simulation.get("clock")))
	for key in ["income_total","wages_total","net_total"]:
		if not _integer(finances.get(key)): return false
	if int(finances.income_total)!=int(simulation.get("total_room_income"))+int(simulation.get("total_activity_income"))+int(finances.reward_income): return false
	if int(finances.room_income)!=int(simulation.get("total_room_income")) or int(finances.activity_income)!=int(simulation.get("total_activity_income")): return false
	if not _integer(cleanliness.get("total_wages")) or int(finances.wages_total)!=int(cleanliness.get("total_wages")): return false
	if int(finances.net_total)!=int(finances.income_total)-int(finances.expenses_total): return false
	var journal: Dictionary=ledger.call("capture")
	if not journal.get("events") is Array: return false
	var receipt_ids: Dictionary={}
	var journal_ids: Dictionary={}
	var party_income: Dictionary={}
	for party: Dictionary in party_ids.values():
		party_income[int(party.id)]={"room":0,"activity":0}
		for receipt: Dictionary in party.receipts: receipt_ids[receipt.id]=receipt
	for index in journal.events.size():
		var event: Variant = journal.events[index]
		if not event is Dictionary or not (event.get("time") is int or event.get("time") is float): return false
		journal_ids[event.id]=true
		if not is_finite(float(event.time)) or event.time<0 or event.time>shared_clock+0.000001: return false
		if event.kind == "reward":
			if not challenges.matches_cash_receipt(event): return false
			continue
		if event.kind in OperatingLedger.CONSTRUCTION:
			if event.id != "resort:construction:%d" % (index + 1) or event.quantity != 1: return false
			continue
		if event.kind == "upkeep":
			var day := roundi(float(event.time) / OperatingLedger.DAY_SECONDS)
			if day < 1 or absf(float(event.time) - day * OperatingLedger.DAY_SECONDS) > 0.000001 or event.id != "resort:upkeep:%d:%s" % [day, event.item]: return false
			continue
		if not _valid_journal_owner(event,population,staff_state,people_ids,party_ids,receipt_ids): return false
		if party_income.has(int(event.get("party_id",0))):
			var totals: Dictionary=party_income[int(event.party_id)]
			totals["room" if event.kind=="room" else "activity"]+=int(event.amount)
	for party: Dictionary in party_ids.values():
		if party_income[int(party.id)].room!=party.room_spent or party_income[int(party.id)].activity!=party.activity_spent: return false
	for receipt_id: String in receipt_ids:
		if not journal_ids.has(receipt_id): return false
	return challenges.has_cash_receipts(journal_ids)

func _valid_journal_owner(event: Dictionary,population: Dictionary,staff_state: Dictionary,people: Dictionary,parties: Dictionary,receipts: Dictionary) -> bool:
	if event.kind=="wage":
		if not _integer(event.get("staff_id")) or event.staff_id<1 or event.staff_id>=staff_state.next_staff_id or event.amount!=-30: return false
		var day := roundi(float(event.time)/180.0)
		if day<1 or absf(float(event.time)-day*180.0)>0.000001 or event.id!="staff:wage:%d:%d" % [int(event.staff_id),day]: return false
		for staff: Dictionary in staff_state.staff:
			if staff.id==event.staff_id and (event.time<=staff.hired_at or day>staff.last_wage_day): return false
		return not event.has("party_id") and not event.has("person_id")
	if not _integer(event.get("party_id")) or event.party_id<1 or event.party_id>=population.next_party_id or event.has("staff_id"): return false
	var party: Dictionary=parties.get(int(event.party_id),{})
	if event.id=="import-%d-%s" % [int(event.party_id),event.kind]:
		if event.kind not in ["room","legacy_income"] or event.has("person_id"): return false
		return party.is_empty() or party.get("legacy",false)
	if event.kind=="room":
		var pieces: PackedStringArray=event.id.split(":")
		if pieces.size()!=4 or not pieces[3].is_valid_int(): return false
		var night := int(pieces[3])
		return night>=1 and night<=3 and event.id=="resort:room:%d:%d" % [int(event.party_id),night] and ResortEconomy.valid_guest_charge(event) and not event.has("person_id") and (party.is_empty() or (night<=party.paid_nights and event.amount==party.rate))
	if not ResortServices.KINDS.has(event.kind) or not ResortEconomy.valid_guest_charge(event) or not _integer(event.get("person_id")) or event.person_id<1 or event.person_id>=population.next_person_id: return false
	var pieces: PackedStringArray=event.id.split(":")
	if pieces.size()!=4 or not pieces[3].is_valid_int(): return false
	var sequence := int(pieces[3])
	if sequence<1 or event.id!="resort:activity:%d:%d" % [int(event.person_id),sequence]: return false
	if people.has(int(event.person_id)) and people[int(event.person_id)].party_id!=event.party_id: return false
	if party.is_empty(): return true # Pruned people retain journal history.
	if not receipts.has(event.id): return false
	var receipt: Dictionary=receipts[event.id]
	return receipt.kind==event.kind and receipt.amount==event.amount and receipt.person_id==event.person_id and receipt.party_id==event.party_id and absf(float(receipt.time)-float(event.time))<=0.000001

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value))

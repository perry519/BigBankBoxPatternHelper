local BB = _G.BigBankDepositPatternHighlighter
local ctx = BB.shared.probe_guide

local PATTERNS = ctx.PATTERNS or {}
local PROBE_GUIDE_MAX_BAG_SLOTS = ctx.PROBE_GUIDE_MAX_BAG_SLOTS or 5
local PROBE_GUIDE_INITIAL_SLOT_COUNT = ctx.PROBE_GUIDE_INITIAL_SLOT_COUNT or 2
local PROBE_GUIDE_MIN_BAG_SLOTS = ctx.PROBE_GUIDE_MIN_BAG_SLOTS or 3
local PROBE_GUIDE_MODE = ctx.PROBE_GUIDE_MODE
local PROBE_GUIDE_NEXT_SLOT_COUNT = ctx.PROBE_GUIDE_NEXT_SLOT_COUNT or 1
local PROBE_GUIDE_OPENED_ONLY_SLOT_ORDER = ctx.PROBE_GUIDE_OPENED_ONLY_SLOT_ORDER or {14, 10}
local PROBE_GUIDE_SLOT_PRIORITY = ctx.PROBE_GUIDE_SLOT_PRIORITY or {}

local PATTERN_ORDERS = {}
local PATTERN_SLOT_INDEX = {}
local PATTERN_SLOT_LOOKUP = {}

for order, pattern in pairs(PATTERNS) do
	PATTERN_ORDERS[#PATTERN_ORDERS + 1] = order
	PATTERN_SLOT_INDEX[order] = {}
	PATTERN_SLOT_LOOKUP[order] = {}

	for index, slot in ipairs(pattern) do
		PATTERN_SLOT_INDEX[order][slot] = index
		PATTERN_SLOT_LOOKUP[order][slot] = true
	end
end

table.sort(PATTERN_ORDERS)

local function slot_priority(slot)
	return PROBE_GUIDE_SLOT_PRIORITY[slot] or 999
end

local function variant_slot_has_loot(variant, slot)
	local index_by_slot = PATTERN_SLOT_INDEX[variant.pattern]
	local index = index_by_slot and index_by_slot[slot]
	return index ~= nil and index <= variant.bag_count
end

local function pattern_variant_possible(order, bag_count, evidence)
	local variant = { bag_count = bag_count, pattern = order }

	for slot in pairs(evidence.loot_slots or {}) do
		if not variant_slot_has_loot(variant, slot) then
			return false
		end
	end

	for slot in pairs(evidence.empty_slots or {}) do
		if variant_slot_has_loot(variant, slot) then
			return false
		end
	end

	return true
end

local function candidate_variants(evidence)
	local variants = {}

	for _, order in ipairs(PATTERN_ORDERS) do
		local pattern = PATTERNS[order] or {}
		local max_bag_count = math.min(PROBE_GUIDE_MAX_BAG_SLOTS, #pattern)

		for bag_count = PROBE_GUIDE_MIN_BAG_SLOTS, max_bag_count do
			if pattern_variant_possible(order, bag_count, evidence) then
				variants[#variants + 1] = { bag_count = bag_count, pattern = order }
			end
		end
	end

	return variants
end

local function unique_candidate_patterns(candidates)
	local patterns = {}
	local seen = {}

	for _, candidate in ipairs(candidates or {}) do
		local pattern = candidate.pattern or candidate

		if not seen[pattern] then
			seen[pattern] = true
			patterns[#patterns + 1] = pattern
		end
	end

	return patterns
end

local function sorted_candidate_slots(candidates, unavailable_slots)
	local seen = {}
	local slots = {}

	for _, candidate in ipairs(candidates) do
		for _, slot in ipairs(PATTERNS[candidate.pattern] or {}) do
			if not seen[slot] and not (unavailable_slots and unavailable_slots[slot]) then
				seen[slot] = true
				slots[#slots + 1] = slot
			end
		end
	end

	table.sort(slots, function(a, b)
		local a_priority = slot_priority(a)
		local b_priority = slot_priority(b)

		if a_priority ~= b_priority then
			return a_priority < b_priority
		end

		return a < b
	end)

	return slots
end

local function split_candidates(candidates, slot)
	local loot = {}
	local empty = {}

	for _, candidate in ipairs(candidates) do
		if variant_slot_has_loot(candidate, slot) then
			loot[#loot + 1] = candidate
		else
			empty[#empty + 1] = candidate
		end
	end

	return loot, empty
end

local score_cache = {}

local function unavailable_key(unavailable_slots)
	local slots = {}

	for slot in pairs(unavailable_slots or {}) do
		slots[#slots + 1] = slot
	end

	table.sort(slots)

	for index, slot in ipairs(slots) do
		slots[index] = tostring(slot)
	end

	return table.concat(slots, ",")
end

local function candidate_key(candidates, unavailable_slots)
	local parts = {}

	for index, candidate in ipairs(candidates) do
		parts[index] = tostring(candidate.pattern) .. ":" .. tostring(candidate.bag_count)
	end

	return table.concat(parts, ",") .. "|" .. unavailable_key(unavailable_slots)
end

local function best_score(candidates, unavailable_slots)
	if #unique_candidate_patterns(candidates) <= 1 then
		return { expected = 0, worst = 0 }
	end

	local key = candidate_key(candidates, unavailable_slots)
	local cached = score_cache[key]

	if cached then
		return cached
	end

	local best = nil

	for _, slot in ipairs(sorted_candidate_slots(candidates, unavailable_slots)) do
		local loot, empty = split_candidates(candidates, slot)

		if #loot > 0 and #empty > 0 then
			local loot_score = best_score(loot, unavailable_slots)
			local empty_score = best_score(empty, unavailable_slots)
			local score = {
				expected = 1 + (#loot / #candidates) * loot_score.expected + (#empty / #candidates) * empty_score.expected,
				slot = slot,
				worst = 1 + math.max(loot_score.worst, empty_score.worst)
			}

			if not best
				or score.worst < best.worst
				or (score.worst == best.worst and score.expected < best.expected)
				or (score.worst == best.worst and score.expected == best.expected and slot_priority(score.slot) < slot_priority(best.slot))
				or (score.worst == best.worst and score.expected == best.expected and slot_priority(score.slot) == slot_priority(best.slot) and score.slot < best.slot) then
				best = score
			end
		end
	end

	best = best or { expected = 0, worst = 0 }
	score_cache[key] = best

	return best
end

local function candidate_slot_scores(candidates, unavailable_slots)
	local scores = {}

	for _, slot in ipairs(sorted_candidate_slots(candidates, unavailable_slots)) do
		local loot, empty = split_candidates(candidates, slot)

		if #loot > 0 and #empty > 0 then
			local loot_score = best_score(loot, unavailable_slots)
			local empty_score = best_score(empty, unavailable_slots)

			scores[#scores + 1] = {
				expected = 1 + (#loot / #candidates) * loot_score.expected + (#empty / #candidates) * empty_score.expected,
				slot = slot,
				worst = 1 + math.max(loot_score.worst, empty_score.worst)
			}
		end
	end

	table.sort(scores, function(a, b)
		if a.worst ~= b.worst then
			return a.worst < b.worst
		end

		if a.expected ~= b.expected then
			return a.expected < b.expected
		end

		local a_priority = slot_priority(a.slot)
		local b_priority = slot_priority(b.slot)

		if a_priority ~= b_priority then
			return a_priority < b_priority
		end

		return a.slot < b.slot
	end)

	return scores
end

local function scores_tied(a, b)
	return a and b
		and a.worst == b.worst
		and math.abs(a.expected - b.expected) < 0.000001
end

local function tied_display_count(scores, base_count)
	local count = math.min(base_count or 1, #scores)
	local reference = scores[1]

	while scores[count + 1] and reference and scores_tied(scores[count + 1], reference) do
		count = count + 1
	end

	return count
end

local function any_slot(table_by_slot)
	for _ in pairs(table_by_slot or {}) do
		return true
	end

	return false
end

local function has_outcome_evidence(evidence)
	return any_slot(evidence.loot_slots) or any_slot(evidence.empty_slots)
end

local function opened_only_primary_count(unavailable_slots)
	local count = 0
	local seen = {}

	for _, slot in ipairs(PROBE_GUIDE_OPENED_ONLY_SLOT_ORDER) do
		if not seen[slot] and not (unavailable_slots and unavailable_slots[slot]) then
			count = count + 1
			seen[slot] = true
		end
	end

	return count
end

local function opened_only_next_slots(candidates, unavailable_slots)
	local slots = {}
	local seen = {}

	for _, slot in ipairs(PROBE_GUIDE_OPENED_ONLY_SLOT_ORDER) do
		if not seen[slot] and not (unavailable_slots and unavailable_slots[slot]) then
			slots[#slots + 1] = slot
			seen[slot] = true
		end
	end

	for _, slot in ipairs(sorted_candidate_slots(candidates, unavailable_slots)) do
		if not seen[slot] then
			slots[#slots + 1] = slot
			seen[slot] = true
		end
	end

	return slots
end

local function unavailable_opened_slots(evidence)
	local slots = {}

	for slot in pairs(evidence.opened_slots or {}) do
		slots[slot] = true
	end

	for slot in pairs(evidence.empty_slots or {}) do
		slots[slot] = true
	end

	for slot in pairs(evidence.loot_slots or {}) do
		slots[slot] = true
	end

	return slots
end

local function build_slot_state(slots, candidates, display_slot_count)
	local slot_by_slot = {}

	for _, slot in ipairs(slots) do
		slot_by_slot[slot] = true
	end

	return {
		candidates = unique_candidate_patterns(candidates),
		display_slot_count = display_slot_count or #slots,
		slot = slots[1],
		slot_by_slot = slot_by_slot,
		slots = slots
	}
end

local function build_pattern_state(order, locked)
	return { candidates = {order}, locked = locked == true, pattern = order }
end

function BB:ProbeGuideSlotOutcome(wall, slot)
	local evidence = self:UseProbeGuideEvidence(wall)

	if not evidence or not slot then
		return nil
	end

	if evidence.loot_slots[slot] then
		return "loot"
	end

	if evidence.empty_slots[slot] then
		return "empty"
	end
end

function BB:ProbeGuideCandidatePatterns(wall)
	if not PROBE_GUIDE_MODE or not wall then
		return nil
	end

	local evidence = self:UseProbeGuideEvidence(wall)

	if not evidence then
		return nil
	end

	return unique_candidate_patterns(candidate_variants(evidence))
end

function BB:ProbeGuideStateIncludesSlot(state, slot)
	if not state or not slot then
		return false
	end

	return state.slot == slot or (state.slot_by_slot and state.slot_by_slot[slot]) == true
end

function BB:ProbeGuideState(wall)
	if not PROBE_GUIDE_MODE or not wall then
		return nil
	end

	local evidence = self:UseProbeGuideEvidence(wall)

	if not evidence then
		return nil
	end

	local resolved_pattern = wall.resolved_probe_pattern_order or evidence.resolved_pattern_order

	if resolved_pattern and PATTERNS[resolved_pattern] then
		return build_pattern_state(resolved_pattern, true)
	end

	local candidates = candidate_variants(evidence)
	local candidate_patterns = unique_candidate_patterns(candidates)

	if not candidates or #candidates == 0 then
		return nil
	end

	if #candidate_patterns == 1 then
		local pattern = candidate_patterns[1]
		evidence.resolved_pattern_order = pattern
		wall.resolved_probe_pattern_order = pattern

		return build_pattern_state(pattern, false)
	end

	local unavailable_slots = unavailable_opened_slots(evidence)
	local slot_count = PROBE_GUIDE_NEXT_SLOT_COUNT

	if not any_slot(evidence.opened_slots) and not any_slot(evidence.loot_slots) and not any_slot(evidence.empty_slots) then
		slot_count = PROBE_GUIDE_INITIAL_SLOT_COUNT
	end

	local slots = {}

	if any_slot(evidence.opened_slots) and not has_outcome_evidence(evidence) then
		slots = opened_only_next_slots(candidates, unavailable_slots)
		slot_count = math.max(slot_count, opened_only_primary_count(unavailable_slots))
	else
		local scores = candidate_slot_scores(candidates, unavailable_slots)
		slot_count = tied_display_count(scores, slot_count)

		for _, score in ipairs(scores) do
			slots[#slots + 1] = score.slot
		end
	end

	if #slots == 0 then
		return nil
	end

	return build_slot_state(slots, candidates, slot_count)
end

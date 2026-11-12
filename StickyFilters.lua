-- StickyFilters: remembers the trainer filters and the "Categorize" option
-- account-wide and enforces them against changes made by other addons.
-- Also tints merchant items the player already knows.

local ADDON_NAME = ...;

local TRAINER_FILTERS = { "available", "unavailable", "used" };
local TRAINER_DEFAULTS = { available = true, unavailable = true, used = false };

-- Tint for merchant items the player already knows (recipes, mounts, pets, ...).
-- Gray plus desaturated icon; overrides every other tint.
local KNOWN = { 0.22, 0.22, 0.22 };
-- Never usable by this character: wrong class/race, a recipe for a profession
-- the character does not have, or armor/weapon types the class can never use.
-- Darker than WhatsTraining's known-tome red (0.5, 0, 0).
local NEVER_USABLE = { 0.35, 0.0, 0.0 };
-- Armor/weapon proficiency the class can still learn but has not learned yet.
local LEARNABLE = { 0.75, 0.35, 0.0 };
-- Recipe for a profession the character does not have (yet): learnable in
-- theory after learning the profession, so its own very dark orange.
local PROFESSION_MISSING = { 0.4, 0.17, 0.0 };
-- Tint for usable items the player cannot afford, plus a small gold coin.
-- Unusable items keep Blizzard's red.
local TOO_EXPENSIVE = { 0.35, 0.5, 1.0 };

local db;
local applying = false;
local debugMode = false;
local lastError; -- last error printed by the pcall wrappers (avoids spam)

-- UI strings: English fallback, German when the client runs in German.
local L = {
	ADDON_TITLE = "StickyFilters",
	MISSING = "Missing",
	AFTER_BUY = "After buy",
	SEARCH = "Search",
	FILTER = "Filter",
	SHOW_ALL = "Show all",
	HIDE_ALL = "Hide all",
	LEVEL_WINDOW = "Only up to +%d levels",
	MATCHES_ON_PAGES = "Matches on page %s",
	NO_MATCHES = "No matches",
	CAT_KNOWN = "Already known",
	CAT_PROFESSION = "Profession missing",
	CAT_NEVER = "Never usable",
	CAT_SKILL = "Skill missing",
	CAT_EXPENSIVE = "Too expensive",
	CAT_LEVEL = "Level too low",
	CAT_OTHER = "Other requirement",
	CAT_NORMAL = "Available",
	WHY_KNOWN = "Gray: already known",
	WHY_PROFESSION = "Orange: recipe for a profession you have not learned",
	WHY_NEVER = "Dark red: your character can never use this (class, race, armor or weapon type)",
	WHY_SKILL = "Orange: armor or weapon skill not learned yet, your class can learn it",
	WHY_TRAINER_SKILL = "Orange: profession skill or previous rank missing",
	WHY_EXPENSIVE = "Blue: you cannot afford it",
	WHY_OTHER = "Red: another requirement is not met",
	WHY_LEVEL = "Red: your level is too low",
	DIM_CATEGORY = "Dimmed: category is filtered out",
	DIM_LEVEL = "Dimmed: more than %d levels above you",
	DIM_SKILL = "Dimmed: more than %d profession points above your skill",
	SKILL_WINDOW = "Only up to +%d profession points",
	DIM_SEARCH = "Dimmed: does not match the search",
	SEARCH_MATCH = "Green animation: matches the search",
	SAVE_SEARCH = "Remember search",
	ERROR = "error",
	MSG_OPEN_MERCHANT = "open a merchant first.",
	MSG_DUMP_ADDED = "dump added (%d lines, %d total). /reload writes it to disk; /sf dump clear empties it.",
	MSG_DUMP_CLEARED = "dump log cleared.",
	MSG_STATUS = "loaded. Saved / current:",
	MSG_BLIZZ_DEFAULT = "Blizzard default",
	MSG_DEBUG = "debug",
	MSG_COMMANDS = "Commands",
	LBL_AVAILABLE = "Available",
	LBL_UNAVAILABLE = "Unavailable",
	LBL_USED = "Already known",
	LBL_CATEGORIZE = "Categorize",
	LANGUAGE = "Language",
	LANG_AUTO = "Automatic (client language)",
	LANG_RELOAD = "language changed, use 'Reload UI' in the options or type /reload to apply.",
	RELOAD_LABEL = "Apply language (only active after reload)",
	RELOAD_BUTTON = "Reload UI",
	RELOAD_TIP = "Reloads the interface so the chosen language is used. Same as typing /reload.",
	LANG_TIP = "Language of StickyFilters texts. Takes effect after /reload.\nExample: German client but English texts: choose English.",
	SEARCH_GLOBAL = "Same search for all",
	SEARCH_PER_NPC = "Separate search per NPC",
	HINT_SHOW = "Show hint",
	HINT_NEVER = "Don't show again",
	HINT_MERCHANT = "StickyFilters: search and filter this merchant up here. Colors and tooltips explain every item.\n\nThe filters start with the recommended settings so you only see what is relevant. Change them any time in the filter menu or under Options > AddOns > StickyFilters.",
	HINT_TRAINER = "StickyFilters: search and filter this trainer up here. Colors and tooltips explain every entry.\n\nThe filters start with the recommended settings so you only see what is relevant. Change them any time in the filter menu or under Options > AddOns > StickyFilters.",
	RESET_DONE = "all settings reset to defaults.",
	OPT_TRAINER = "Trainer",
	OPT_SEC_CATEGORIES = "Color categories (unchecked = dimmed)",
	OPT_SEC_RANGES = "Range filters",
	OPT_SEC_SEARCH = "Search and hint",
	OPT_SEC_BLIZZARD = "Blizzard trainer filters (remembered)",
	WINDOW_SIZE_LEVEL = "    N = levels above yours",
	WINDOW_SIZE_SKILL = "    N = points above your profession skill",
	OPT_MERCHANT = "Merchant",
	OPT_QUEST = "Quest rewards",
	OPT_PLUS_ROW = "MerchantPlus: color the whole row",
	OPT_QUEST_COLORS = "Color quest rewards",
	OPT_QUEST_CHECK = "Check mark on quest rewards",
	OPT_QUEST_TOOLTIP = "Explanations in the tooltip",
	OPT_ICON_COIN = "Crossed-out currency icon (cannot afford)",
	OPT_ICON_CHECK = "Green check mark (fits me)",
	OPT_RESET_HEADER = "Reset",
	OPT_RESET_LABEL = "Reset all settings",
	OPT_RESET_BUTTON = "Reset",
	OPT_RESET_TOOLTIP = "Restores every StickyFilters setting to its default.",
	ICONS = "Icons",
	ICON_COIN = "coin",
	ICON_CHECK = "check mark",
	ON = "on",
	OFF = "off",
	FITS_TITLE = "Check mark: fits me",
	FITS_CLASS = "My class",
	FITS_RACE = "My race",
	FITS_GEAR = "Fitting gear",
	FITS_RECIPE = "Recipes for my professions",
	WHY_FITS_CLASS = "Green check mark: made for your class",
	WHY_FITS_RACE = "Green check mark: made for your race",
	WHY_FITS_GEAR = "Green check mark: armor or weapon type you can use",
	WHY_FITS_RECIPE = "Green check mark: recipe for one of your professions",
};
-- German strings; applied on ADDON_LOADED depending on the language setting
-- (Automatic = client language, or forced English / German).
local currentLang = "en";
local function ApplyGerman()
	L.MISSING = "Fehlt";
	L.AFTER_BUY = "Nach Kauf";
	L.SEARCH = "Suchen";
	L.FILTER = "Filter";
	L.SHOW_ALL = "Alle anzeigen";
	L.HIDE_ALL = "Alle deaktivieren";
	L.LEVEL_WINDOW = "Nur bis +%d Stufen";
	L.MATCHES_ON_PAGES = "Treffer auf Seite %s";
	L.NO_MATCHES = "Keine Treffer";
	L.CAT_KNOWN = "Bereits bekannt";
	L.CAT_PROFESSION = "Beruf fehlt";
	L.CAT_NEVER = "Nie benutzbar";
	L.CAT_SKILL = "Fertigkeit fehlt";
	L.CAT_EXPENSIVE = "Zu teuer";
	L.CAT_LEVEL = "Stufe zu niedrig";
	L.CAT_OTHER = "Sonstige Bedingung";
	L.CAT_NORMAL = "Verf\195\188gbar";
	L.WHY_KNOWN = "Grau: bereits bekannt";
	L.WHY_PROFESSION = "Orange: Rezept f\195\188r einen Beruf, den du nicht gelernt hast";
	L.WHY_NEVER = "Dunkelrot: f\195\188r deinen Charakter nie benutzbar (Klasse, Volk, R\195\188stungs- oder Waffentyp)";
	L.WHY_SKILL = "Orange: R\195\188stungs- oder Waffenfertigkeit noch nicht gelernt, deine Klasse kann sie lernen";
	L.WHY_TRAINER_SKILL = "Orange: Berufsstufe oder Vorg\195\164nger-Rang fehlt";
	L.WHY_EXPENSIVE = "Blau: du kannst es dir nicht leisten";
	L.WHY_OTHER = "Rot: eine sonstige Bedingung ist nicht erf\195\188llt";
	L.WHY_LEVEL = "Rot: deine Stufe ist zu niedrig";
	L.DIM_CATEGORY = "Abgedunkelt: Kategorie ist herausgefiltert";
	L.DIM_LEVEL = "Abgedunkelt: mehr als %d Stufen \195\188ber dir";
	L.DIM_SKILL = "Abgedunkelt: mehr als %d Berufspunkte \195\188ber deiner Fertigkeit";
	L.SKILL_WINDOW = "Nur bis +%d Berufspunkte";
	L.DIM_SEARCH = "Abgedunkelt: passt nicht zur Suche";
	L.SEARCH_MATCH = "Gr\195\188ne Animation: passt zur Suche";
	L.SAVE_SEARCH = "Sucheingabe speichern";
	L.ERROR = "Fehler";
	L.MSG_OPEN_MERCHANT = "\195\150ffne zuerst einen H\195\164ndler.";
	L.MSG_DUMP_ADDED = "Dump erg\195\164nzt (%d Zeilen, %d insgesamt). /reload schreibt ihn auf die Platte; /sf dump clear leert ihn.";
	L.MSG_DUMP_CLEARED = "Dump-Log geleert.";
	L.MSG_STATUS = "geladen. Gespeichert / aktuell:";
	L.MSG_BLIZZ_DEFAULT = "Blizzard-Standard";
	L.MSG_DEBUG = "Debug";
	L.MSG_COMMANDS = "Befehle";
	L.LBL_AVAILABLE = "Verf\195\188gbar";
	L.LBL_UNAVAILABLE = "Nicht verf\195\188gbar";
	L.LBL_USED = "Bereits bekannt";
	L.LBL_CATEGORIZE = "Kategorisieren";
	L.LANGUAGE = "Sprache";
	L.LANG_AUTO = "Automatisch (Client-Sprache)";
	L.LANG_RELOAD = "Sprache ge\195\164ndert, mit 'UI neu laden' in den Optionen oder /reload \195\188bernehmen.";
	L.RELOAD_LABEL = "Sprache \195\188bernehmen (erst nach Neuladen aktiv)";
	L.RELOAD_BUTTON = "UI neu laden";
	L.RELOAD_TIP = "L\195\164dt die Oberfl\195\164che neu, damit die gew\195\164hlte Sprache gilt. Wie /reload.";
	L.LANG_TIP = "Sprache der StickyFilters-Texte. Wirkt nach /reload.\nBeispiel: deutscher Client, aber englische Texte: English w\195\164hlen.";
	L.SEARCH_GLOBAL = "Gleiche Suche f\195\188r alle";
	L.SEARCH_PER_NPC = "Eigene Suche pro NPC";
	L.HINT_SHOW = "Hinweis anzeigen";
	L.HINT_NEVER = "Nicht mehr anzeigen";
	L.HINT_MERCHANT = "StickyFilters: Hier oben kannst du diesen H\195\164ndler durchsuchen und filtern. Farben und Tooltips erkl\195\164ren jedes Item.\n\nDie Filter starten mit den empfohlenen Einstellungen, damit du nur Relevantes siehst. \195\132ndern kannst du sie jederzeit im Filter-Men\195\188 oder unter Optionen > AddOns > StickyFilters.";
	L.HINT_TRAINER = "StickyFilters: Hier oben kannst du diesen Lehrer durchsuchen und filtern. Farben und Tooltips erkl\195\164ren jeden Eintrag.\n\nDie Filter starten mit den empfohlenen Einstellungen, damit du nur Relevantes siehst. \195\132ndern kannst du sie jederzeit im Filter-Men\195\188 oder unter Optionen > AddOns > StickyFilters.";
	L.RESET_DONE = "alle Einstellungen auf Standard zur\195\188ckgesetzt.";
	L.OPT_TRAINER = "Lehrer";
	L.OPT_SEC_CATEGORIES = "Farbkategorien (abgew\195\164hlt = abgedunkelt)";
	L.OPT_SEC_RANGES = "Bereichsfilter";
	L.OPT_SEC_SEARCH = "Suche und Hinweis";
	L.OPT_SEC_BLIZZARD = "Blizzard-Lehrerfilter (gemerkt)";
	L.WINDOW_SIZE_LEVEL = "    N = Stufen \195\188ber deiner";
	L.WINDOW_SIZE_SKILL = "    N = Punkte \195\188ber deiner Berufsfertigkeit";
	L.OPT_MERCHANT = "H\195\164ndler";
	L.OPT_QUEST = "Questbelohnungen";
	L.OPT_PLUS_ROW = "MerchantPlus: ganze Zeile einf\195\164rben";
	L.OPT_QUEST_COLORS = "Questbelohnungen einf\195\164rben";
	L.OPT_QUEST_CHECK = "H\195\164kchen an Questbelohnungen";
	L.OPT_QUEST_TOOLTIP = "Erkl\195\164rungen im Tooltip";
	L.OPT_ICON_COIN = "Durchgestrichenes W\195\164hrungssymbol (zu wenig Geld)";
	L.OPT_ICON_CHECK = "Gr\195\188nes H\195\164kchen (passt zu mir)";
	L.OPT_RESET_HEADER = "Zur\195\188cksetzen";
	L.OPT_RESET_LABEL = "Alle Einstellungen zur\195\188cksetzen";
	L.OPT_RESET_BUTTON = "Zur\195\188cksetzen";
	L.OPT_RESET_TOOLTIP = "Setzt alle StickyFilters-Einstellungen auf die Standardwerte zur\195\188ck.";
	L.ICONS = "Symbole";
	L.ICON_COIN = "M\195\188nze";
	L.ICON_CHECK = "H\195\164kchen";
	L.ON = "an";
	L.OFF = "aus";
	L.FITS_TITLE = "H\195\164kchen: passt zu mir";
	L.FITS_CLASS = "Meine Klasse";
	L.FITS_RACE = "Mein Volk";
	L.FITS_GEAR = "Passende Ausr\195\188stung";
	L.FITS_RECIPE = "Rezepte meiner Berufe";
	L.WHY_FITS_CLASS = "Gr\195\188nes H\195\164kchen: f\195\188r deine Klasse";
	L.WHY_FITS_RACE = "Gr\195\188nes H\195\164kchen: f\195\188r dein Volk";
	L.WHY_FITS_GEAR = "Gr\195\188nes H\195\164kchen: R\195\188stungs- oder Waffentyp, den du benutzen kannst";
	L.WHY_FITS_RECIPE = "Gr\195\188nes H\195\164kchen: Rezept f\195\188r einen deiner Berufe";
end

local function Debug(...)
	if debugMode then
		print("|cff40c0ffSF|r", ...);
	end
end

local function TrainerState()
	local parts = {};
	for _, filter in ipairs(TRAINER_FILTERS) do
		parts[#parts + 1] = filter .. "=" .. tostring(GetTrainerServiceTypeFilter(filter));
	end
	return table.concat(parts, " ");
end

local function HasCategorizeAPI()
	return C_Trainer and C_Trainer.GetCategorizeTrainerUI and C_Trainer.SetCategorizeTrainerUI and true or false;
end

---------------------------------------------------------------------------
-- Trainer
---------------------------------------------------------------------------

local function ApplyTrainerFilters(source)
	if not db then return; end
	applying = true;
	for _, filter in ipairs(TRAINER_FILTERS) do
		local wanted = db.trainer[filter];
		if (GetTrainerServiceTypeFilter(filter) and true or false) ~= wanted then
			Debug(source, "set", filter, "->", tostring(wanted));
			SetTrainerServiceTypeFilter(filter, wanted);
		end
	end
	-- "Categorize" is only enforced after the user clicked it at least once;
	-- until then Blizzard's own saved value stays untouched.
	if db.categorize ~= nil and HasCategorizeAPI()
		and (C_Trainer.GetCategorizeTrainerUI() and true or false) ~= db.categorize then
		Debug(source, "set categorize ->", tostring(db.categorize));
		C_Trainer.SetCategorizeTrainerUI(db.categorize);
		if ClassTrainerFrame and ClassTrainerFrame:IsShown() and ClassTrainerFrame_Update then
			ClassTrainerFrame_Update(true);
		end
	end
	applying = false;
end

-- Deferred re-check: the client fires TRAINER_UPDATE synchronously inside
-- SetTrainerServiceTypeFilter, i.e. before the post-hooks below have stored
-- the user's new choice. Checking one frame later avoids reverting that click.
local pending = false;
local function ScheduleApply(source)
	if pending then return; end
	pending = true;
	C_Timer.After(0, function()
		pending = false;
		ApplyTrainerFilters(source);
	end);
end

-- Only clicks in the trainer filter menu count as a user choice. Other addons
-- (e.g. Warchive) switch all filters on while a trainer is open to scan the
-- full list; those calls must not overwrite the saved choice.
local function IsFilterMenuOpen()
	local dropdown = ClassTrainerFrame and ClassTrainerFrame.FilterDropdown;
	return dropdown and dropdown.IsMenuOpen and dropdown:IsMenuOpen() or false;
end

local function Source(byUser)
	return applying and "(StickyFilters)" or byUser and "(menu)" or "(other addon)";
end

hooksecurefunc("SetTrainerServiceTypeFilter", function(filter, value)
	local byUser = not applying and IsFilterMenuOpen();
	Debug("Set", filter, tostring(value), Source(byUser));
	if db and byUser and TRAINER_DEFAULTS[filter] ~= nil then
		db.trainer[filter] = value and true or false;
	elseif not applying then
		ScheduleApply("foreign+1");
	end
end);

if HasCategorizeAPI() then
	hooksecurefunc(C_Trainer, "SetCategorizeTrainerUI", function(value)
		local byUser = not applying and IsFilterMenuOpen();
		Debug("Set categorize", tostring(value), Source(byUser));
		if db and byUser then
			db.categorize = value and true or false;
		elseif not applying then
			ScheduleApply("foreign+1");
		end
	end);
end

---------------------------------------------------------------------------
-- Merchant: tint already known items
---------------------------------------------------------------------------

local LINE_USAGE_REQUIREMENT = Enum.TooltipDataLineType and Enum.TooltipDataLineType.UsageRequirement;
local REQ_NOT_ALREADY_KNOWN = Enum.TooltipDataUsageRequirementType and Enum.TooltipDataUsageRequirementType.NotAlreadyKnown;

-- Merchant tooltip data, cached for the current frame (classification asks
-- for the same item several times, the page hint for every item).
local tipCache, tipCacheTime = {}, nil;
local function GetTip(index)
	if not (C_TooltipInfo and C_TooltipInfo.GetMerchantItem) then return nil; end
	local now = GetTime();
	if tipCacheTime ~= now then
		tipCache, tipCacheTime = {}, now;
	end
	if tipCache[index] == nil then
		tipCache[index] = C_TooltipInfo.GetMerchantItem(index) or false;
	end
	return tipCache[index] or nil;
end

-- The item checks below work on tooltip data plus item ID, so merchant items
-- and quest rewards share them; the merchant wrappers pass GetTip(index).
local function IsItemKnown(data, itemID)
	-- Warlock pet tomes only show "Already known" while the matching demon is
	-- summoned. WhatsTraining remembers learned tomes per character; reuse that.
	if itemID and type(WT_LearnedPetAbilities) == "table" and WT_LearnedPetAbilities[itemID] == true then
		return true, "WhatsTraining";
	end
	if not data or not data.lines then return false; end
	for _, line in ipairs(data.lines) do
		if LINE_USAGE_REQUIREMENT and line.type == LINE_USAGE_REQUIREMENT
			and REQ_NOT_ALREADY_KNOWN and line.requirementType == REQ_NOT_ALREADY_KNOWN then
			return true, "requirementType";
		end
		local text = line.leftText;
		if type(text) == "string" and ITEM_SPELL_KNOWN and text:find(ITEM_SPELL_KNOWN, 1, true) then
			return true, "text";
		end
	end
	return false;
end

local function IsMerchantItemKnown(index)
	return IsItemKnown(GetTip(index), GetMerchantItemID(index));
end

local REQ_RACE_CLASS = Enum.TooltipDataUsageRequirementType and Enum.TooltipDataUsageRequirementType.RaceClass;
local REQ_SKILL = Enum.TooltipDataUsageRequirementType and Enum.TooltipDataUsageRequirementType.Skill;

-- Blizzard prints unmet requirements in red (RED_FONT_COLOR).
local function IsRedLine(line)
	local c = line.leftColor;
	return c and c.r and c.r > 0.9 and c.g < 0.3 and c.b < 0.3 or false;
end

local function OwnedProfessionNames()
	local names = {};
	if not (GetProfessions and GetProfessionInfo) then return names; end
	for _, index in pairs({ GetProfessions() }) do
		local name = GetProfessionInfo(index);
		if name then names[#names + 1] = name; end
	end
	return names;
end

-- Only two cases count as "never usable", both read from unmet (red)
-- requirement lines: a class/race restriction, and a skill requirement naming
-- a profession the character does not have. A too low level or profession
-- rank stays Blizzard red, because it becomes usable later.
local function IsNeverUsableData(data)
	if not LINE_USAGE_REQUIREMENT then return false; end
	if not data or not data.lines then return false; end
	for _, line in ipairs(data.lines) do
		if line.type == LINE_USAGE_REQUIREMENT and IsRedLine(line) then
			if REQ_RACE_CLASS and line.requirementType == REQ_RACE_CLASS then
				return true, "class";
			end
			if REQ_SKILL and line.requirementType == REQ_SKILL and type(line.leftText) == "string" then
				local hasProfession = false;
				for _, name in ipairs(OwnedProfessionNames()) do
					if line.leftText:find(name, 1, true) then
						hasProfession = true;
						break;
					end
				end
				if not hasProfession then
					return true, "profession";
				end
			end
		end
	end
	return false;
end

local function IsNeverUsable(index)
	return IsNeverUsableData(GetTip(index));
end

local LINE_EQUIP_SLOT = Enum.TooltipDataLineType and Enum.TooltipDataLineType.EquipSlot;
local ITEM_CLASS_WEAPON = Enum.ItemClass and Enum.ItemClass.Weapon;
local ITEM_CLASS_ARMOR = Enum.ItemClass and Enum.ItemClass.Armor;

-- Which weapon/armor types a class can EVER learn (classic rules). Used only to
-- decide between "learnable later" (orange) and "never" (dark red) once
-- Blizzard already marked the type red. Unknown classes/types count as
-- learnable, so a gap in this table can never produce a false "never".
local W, A = Enum.ItemWeaponSubclass or {}, Enum.ItemArmorSubclass or {};
local function Set(...)
	local t = {};
	for i = 1, select("#", ...) do
		local v = select(i, ...);
		if v ~= nil then t[v] = true; end
	end
	return t;
end
local CAN_EVER_USE = {
	WARRIOR = { weapon = Set(W.Axe1H, W.Axe2H, W.Bows, W.Guns, W.Mace1H, W.Mace2H, W.Polearm, W.Sword1H, W.Sword2H, W.Staff, W.Unarmed, W.Dagger, W.Thrown, W.Crossbow),
		armor = Set(A.Cloth, A.Leather, A.Mail, A.Plate, A.Shield) },
	PALADIN = { weapon = Set(W.Axe1H, W.Axe2H, W.Mace1H, W.Mace2H, W.Polearm, W.Sword1H, W.Sword2H),
		armor = Set(A.Cloth, A.Leather, A.Mail, A.Plate, A.Shield) },
	HUNTER = { weapon = Set(W.Axe1H, W.Axe2H, W.Bows, W.Guns, W.Polearm, W.Sword1H, W.Sword2H, W.Staff, W.Unarmed, W.Dagger, W.Thrown, W.Crossbow),
		armor = Set(A.Cloth, A.Leather, A.Mail) },
	ROGUE = { weapon = Set(W.Axe1H, W.Bows, W.Guns, W.Mace1H, W.Sword1H, W.Unarmed, W.Dagger, W.Thrown, W.Crossbow),
		armor = Set(A.Cloth, A.Leather) },
	PRIEST = { weapon = Set(W.Mace1H, W.Staff, W.Dagger, W.Wand), armor = Set(A.Cloth) },
	SHAMAN = { weapon = Set(W.Axe1H, W.Axe2H, W.Mace1H, W.Mace2H, W.Staff, W.Unarmed, W.Dagger),
		armor = Set(A.Cloth, A.Leather, A.Mail, A.Shield) },
	MAGE = { weapon = Set(W.Sword1H, W.Staff, W.Dagger, W.Wand), armor = Set(A.Cloth) },
	WARLOCK = { weapon = Set(W.Sword1H, W.Staff, W.Dagger, W.Wand), armor = Set(A.Cloth) },
	DRUID = { weapon = Set(W.Mace1H, W.Mace2H, W.Polearm, W.Staff, W.Unarmed, W.Dagger),
		armor = Set(A.Cloth, A.Leather) },
};

local function IsRedColor(c)
	return c and c.r and c.r > 0.9 and c.g < 0.3 and c.b < 0.3 or false;
end

-- Weapon/armor whose type Blizzard prints in red ("One-Hand | Sword" or
-- "Chest | Mail"): the character lacks that proficiency. Returns
-- "learnable", "never" or nil.
local function GetProficiencyStateData(data, itemID)
	if not (LINE_EQUIP_SLOT and C_Item and C_Item.GetItemInfoInstant) then return nil; end
	if not itemID then return nil; end
	local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID);
	local kind = (classID == ITEM_CLASS_WEAPON and "weapon") or (classID == ITEM_CLASS_ARMOR and "armor") or nil;
	if not kind then return nil; end
	if not data or not data.lines then return nil; end
	for _, line in ipairs(data.lines) do
		if line.type == LINE_EQUIP_SLOT then
			if not (IsRedColor(line.leftColor) or IsRedColor(line.rightColor)) then return nil; end
			local classRules = CAN_EVER_USE[select(2, UnitClass("player"))];
			if classRules and classRules[kind] and next(classRules[kind]) and not classRules[kind][subClassID] then
				return "never";
			end
			return "learnable";
		end
	end
	return nil;
end

local function GetProficiencyState(index)
	return GetProficiencyStateData(GetTip(index), GetMerchantItemID(index));
end

-- Small gold coin in the top-left corner of the item icon (created on demand).
-- Coin on any button; anchor is the icon region the coin sits on.
-- texture: nil = gold coin atlas, otherwise the icon of the missing currency.
-- Sizes are in UI units (they scale with the UI like everything else); they
-- are only snapped to whole screen pixels so thin lines stay crisp (min 1 px).
local function PX(frame, units)
	if PixelUtil and PixelUtil.GetNearestPixelSize then
		return PixelUtil.GetNearestPixelSize(units, frame:GetEffectiveScale(), 1);
	end
	return units;
end

local function IconEnabled(key)
	return not (db and db.icons and db.icons[key] == false);
end

local function SetCoinOn(itemButton, anchor, show, texture)
	if not itemButton then return; end
	show = show and IconEnabled("coin");
	if show and not itemButton.StickyFiltersCoin then
		-- Holder frame above the icon; coin plus a thin red cross ("not enough money").
		local holder = CreateFrame("Frame", nil, itemButton);
		holder:SetSize(10, 10);
		holder:SetFrameLevel(itemButton:GetFrameLevel() + 10); -- above the search effect (+6)
		holder:SetIgnoreParentAlpha(false);
		local coin = holder:CreateTexture(nil, "ARTWORK");
		coin:SetAllPoints();
		holder.coin = coin;
		-- Red cross from two thin rotated textures (Line objects can vanish at
		-- 1 px thickness depending on their screen position).
		holder.lines = {};
		for _, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
			local bar = holder:CreateTexture(nil, "OVERLAY");
			bar:SetColorTexture(1, 0.1, 0.1, 1);
			bar:SetPoint("CENTER");
			bar:SetRotation(angle);
			holder.lines[#holder.lines + 1] = bar;
		end
		itemButton.StickyFiltersCoin = holder;
	end
	local holder = itemButton.StickyFiltersCoin;
	if holder then
		if show then
			local size = PX(holder, 10 * (itemButton.StickyFiltersIconScale or 1));
			holder:SetSize(size, size);
			-- Left half outside the item icon, right half on it (MerchantPlus: fully outside).
			holder:ClearAllPoints();
			holder:SetPoint("TOPLEFT", anchor or itemButton, "TOPLEFT", -size * (itemButton.StickyFiltersIconOutside or 0.5), PX(holder, 1));
			for _, bar in ipairs(holder.lines) do
				bar:SetSize(size * 1.41, PX(holder, 1));
			end
			if texture then
				holder.coin:SetTexture(texture);
			else
				holder.coin:SetAtlas("coin-gold");
			end
		end
		holder:SetShown(show);
	end
end

-- Thin green frame around a search match; ignores the parent's alpha so a
-- match stays visible even when its row is dimmed by a category filter.
-- Size the autocast effect is drawn at before it is scaled to the icon.
local MATCH_GLOW_SIZE = 36;
local function SetMatchBorder(button, anchor, show)
	if not button then return; end
	if show and not button.StickyFiltersMatch then
		-- Preferred: Blizzard's pet autocast effect (rotating ants + corners), tinted green.
		local ok, glow = pcall(CreateFrame, "Frame", nil, button, "AutoCastOverlayTemplate");
		if ok and glow and glow.Corners then
			-- Built at action button size and scaled to the icon: on small icons
			-- (MerchantPlus rows) the animated part would not fit otherwise.
			glow:ClearAllPoints();
			glow:SetSize(MATCH_GLOW_SIZE, MATCH_GLOW_SIZE);
			glow.isScaledGlow = true;
			glow:SetFrameLevel(button:GetFrameLevel() + 6);
			glow:SetIgnoreParentAlpha(true);
			for _, tex in ipairs({ glow.Corners, glow.Shine }) do
				if tex then
					tex:SetDesaturated(true);
					tex:SetVertexColor(0.75, 1, 0.2, 0.85);
				end
			end
			if glow.ShowAutoCastEnabled then glow:ShowAutoCastEnabled(true); end
			button.StickyFiltersMatch = glow;
		end
	end
	if show and not button.StickyFiltersMatch then
		local holder = CreateFrame("Frame", nil, button);
		holder:SetPoint("TOPLEFT", anchor or button, "TOPLEFT", -2, 2);
		holder:SetPoint("BOTTOMRIGHT", anchor or button, "BOTTOMRIGHT", 2, -2);
		holder:SetFrameLevel(button:GetFrameLevel() + 6);
		holder:SetIgnoreParentAlpha(true);
		local edges = {
			{ "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
			{ "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
		};
		for _, e in ipairs(edges) do
			local t = holder:CreateTexture(nil, "OVERLAY");
			t:SetColorTexture(0.75, 1, 0.2, 0.5);
			t:SetPoint(e[1]);
			t:SetPoint(e[2]);
			if e[3] then t:SetWidth(e[3]); else t:SetHeight(e[4]); end
		end
		button.StickyFiltersMatch = holder;
	end
	local match = button.StickyFiltersMatch;
	if match then
		if show and match.isScaledGlow then
			local target = anchor or button;
			local width = target:GetWidth() or 0;
			if width > 0 then match:SetScale(width / MATCH_GLOW_SIZE); end
			match:ClearAllPoints();
			match:SetPoint("CENTER", target, "CENTER");
		end
		match:SetShown(show);
	end
end

local function SetCoin(i, show)
	SetCoinOn(_G["MerchantItem" .. i .. "ItemButton"], nil, show);
end

-- Merchant/trainer tooltips: "Missing" only when money is short, "After buy"
-- only when affordable, both in red-ish text with coin icons. Uses
-- TooltipDataProcessor because the tooltip is rebuilt from tooltip data (a
-- plain hook on SetMerchantItem loses its lines on rebuild).
local function CoinText(amount)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		return C_CurrencyInfo.GetCoinTextureString(amount);
	end
	return GetMoneyString(amount);
end

-- All costs of a merchant item: gold plus every currency/item cost.
-- Each entry: { texture = fileID or nil (gold), need = n, have = n, gold = bool }.
local function GetMerchantCosts(index)
	local costs = {};
	local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(index);
	if not info then return costs; end
	if info.price and info.price > 0 then
		costs[#costs + 1] = { gold = true, need = info.price, have = GetMoney() };
	end
	if info.hasExtendedCost and GetMerchantItemCostInfo and GetMerchantItemCostItem then
		for i = 1, (MAX_ITEM_COST or 3) do
			local texture, value, link = GetMerchantItemCostItem(index, i);
			if texture and value and value > 0 then
				local have;
				if link and link:find("|Hcurrency:", 1, true) and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfoFromLink then
					local cinfo = C_CurrencyInfo.GetCurrencyInfoFromLink(link);
					have = cinfo and cinfo.quantity;
				elseif link and C_Item and C_Item.GetItemCount then
					have = C_Item.GetItemCount(link, true);
				end
				costs[#costs + 1] = { texture = texture, need = value, have = have };
			end
		end
	end
	return costs;
end

-- First cost the player cannot pay, or nil. Unknown amounts (have == nil)
-- never count as missing.
local function FirstMissingCost(costs)
	for _, c in ipairs(costs) do
		if c.have and c.have < c.need then return c; end
	end
	return nil;
end

local function CostText(c, amount)
	if c.gold then return CoinText(amount); end
	return ("%s |T%s:0|t"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(amount) or tostring(amount), tostring(c.texture));
end

local function GetMerchantIndexFromOwner(owner)
	if not (owner and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1) then return nil; end
	-- MerchantPlus rows carry the merchant index in their element data.
	local plusBox = _G.MerchantPlusItemList and MerchantPlusItemList.ScrollBox;
	local ownerParent = owner.GetParent and owner:GetParent();
	if owner.GetElementData and plusBox and ownerParent and (ownerParent == plusBox or ownerParent == plusBox.ScrollTarget)
		and _G.MerchantPlusFrame and MerchantPlusFrame:IsVisible() then
		local ok, data = pcall(owner.GetElementData, owner);
		if ok and type(data) == "table" and tonumber(data.index) then return tonumber(data.index); end
	end
	local parent = owner.GetParent and owner:GetParent();
	local parentName = parent and parent.GetName and parent:GetName();
	if parentName and (parentName:match("^MerchantItem%d+$") or parentName:match("^EUI_MerchantItem%d+$")
		or parentName:match("^EUI_MerchantPage%d+$")) and owner.GetID then
		return owner:GetID();
	end
	return nil;
end

-- Buyback tab: Blizzard's tiles and EllesmereUI's list rows carry the buyback index.
local function GetBuybackIndexFromOwner(owner)
	if not (owner and MerchantFrame and MerchantFrame:IsShown() and MerchantFrame.selectedTab == 2 and owner.GetID) then return nil; end
	local parent = owner.GetParent and owner:GetParent();
	local parentName = parent and parent.GetName and parent:GetName();
	if parentName and (parentName:match("^MerchantItem%d+$") or parentName:match("^EUI_MerchantItem%d+$")) then
		local index = owner:GetID();
		if index and index > 0 and index <= GetNumBuybackItems() then return index; end
	end
	return nil;
end

-- Trainer skill buttons carry the service index as their ID.
local function GetTrainerCostFromOwner(owner)
	if not (owner and ClassTrainerFrame and ClassTrainerFrame:IsShown() and owner.money and owner.subText and owner.GetID) then return nil; end
	if C_Trainer and C_Trainer.GetTrainerType and Enum.TrainerType and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then return nil; end
	local _, serviceType = GetTrainerServiceInfo(owner:GetID());
	if serviceType == "used" then return nil; end
	local cost = GetTrainerServiceCost(owner:GetID());
	return cost and cost > 0 and cost or nil;
end

-- Assigned further down (needs the classification helpers): returns a list of
-- short explanations why the hovered entry has its color / is dimmed.
local GetReasonLines;
-- Assigned in the quest reward section: adds the explanation lines to a
-- tooltip that shows a quest reward item.
local AddQuestRewardLines;
local smallLines = {};

local reasonFont;
local function GetReasonFont()
	if not reasonFont then
		reasonFont = CreateFont("StickyFiltersReasonFont");
		reasonFont:CopyFontObject(GameTooltipTextSmall or GameTooltipText);
		local path, _, flags = reasonFont:GetFont();
		if path then reasonFont:SetFont(path, 9, flags); end
	end
	return reasonFont;
end

local function AddSmallGrayLine(tooltip, text)
	tooltip:AddLine(text, 0.6, 0.6, 0.6, true);
	-- Smaller font only on GameTooltip (its font is reset on clear below).
	if tooltip ~= GameTooltip then return; end
	local fs = _G[tooltip:GetName() .. "TextLeft" .. tooltip:NumLines()];
	if fs then
		fs:SetFontObject(GetReasonFont());
		fs:SetTextColor(0.6, 0.6, 0.6);
		smallLines[#smallLines + 1] = fs;
	end
end

GameTooltip:HookScript("OnTooltipCleared", function()
	for i = #smallLines, 1, -1 do
		smallLines[i]:SetFontObject(GameTooltipText);
		smallLines[i] = nil;
	end
end);

-- Tooltips filled by these C_TooltipInfo getters show a quest reward item, no
-- matter which addon owns the tooltip (Blizzard, Immersion, ...).
local QUEST_REWARD_GETTERS = { GetQuestItem = true, GetQuestLogItem = true };

local function AddMoneyLines(tooltip, tooltipData)
	local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo();
	if info and QUEST_REWARD_GETTERS[info.getterName] then
		if AddQuestRewardLines then AddQuestRewardLines(tooltip, tooltipData); end
		return;
	end
	if tooltip ~= GameTooltip then return; end
	local owner = tooltip:GetOwner();
	local reasons = GetReasonLines and GetReasonLines(owner) or {};
	local costs;
	local index = GetMerchantIndexFromOwner(owner);
	local buybackIndex = not index and GetBuybackIndexFromOwner(owner);
	if index then
		costs = GetMerchantCosts(index);
	elseif buybackIndex then
		local price = select(3, GetBuybackItemInfo(buybackIndex));
		costs = price and price > 0 and { { gold = true, need = price, have = GetMoney() } } or {};
	else
		local price = GetTrainerCostFromOwner(owner);
		costs = price and { { gold = true, need = price, have = GetMoney() } } or {};
	end
	local known = {};
	for _, c in ipairs(costs) do
		if c.have then known[#known + 1] = c; end
	end
	if #known == 0 and #reasons == 0 then return; end
	tooltip:AddLine(" ");
	if #known > 0 then
		local missing = {};
		for _, c in ipairs(known) do
			if c.have < c.need then missing[#missing + 1] = CostText(c, c.need - c.have); end
		end
		if #missing > 0 then
			tooltip:AddLine(L.MISSING .. ": " .. table.concat(missing, "  "), 1, 0.25, 0.25);
		else
			local after = {};
			for _, c in ipairs(known) do after[#after + 1] = CostText(c, c.have - c.need); end
			tooltip:AddLine(L.AFTER_BUY .. ": " .. table.concat(after, "  "), 1, 0.25, 0.25);
		end
	end
	for _, text in ipairs(reasons) do
		AddSmallGrayLine(tooltip, text);
	end
	tooltip:AddLine(" ");
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
	-- All types: merchant items are Item tooltips, trainer services are not.
	TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, AddMoneyLines);
end

---------------------------------------------------------------------------
-- Search + category filter (non-matches are dimmed, nothing is hidden, so
-- the buy/train buttons always keep Blizzard's own index mapping)
---------------------------------------------------------------------------

local DIM_ALPHA = 0.2;
-- The buyback tab has a light gray background: dimmed entries 10 points more visible.
local BUYBACK_DIM_ALPHA = DIM_ALPHA + 0.1;
-- Our coin/check icons on dimmed rows stay clearly visible (40% opacity).
local DIM_ICON_ALPHA = 0.4;
-- Trainer prices and requirement lines on dimmed rows: 10 points above the row.
local DIM_PRICE_ALPHA = DIM_ALPHA + 0.1;

local function SyncIconAlpha(button, dimmed)
	for _, key in ipairs({ "StickyFiltersCoin", "StickyFiltersCheck" }) do
		local icon = button and button[key];
		if icon then
			icon:SetIgnoreParentAlpha(true);
			icon:SetAlpha(dimmed and DIM_ICON_ALPHA or 1);
		end
	end
end
-- Window sizes: defaults +3 levels / +15 profession points, changeable per
-- merchant/trainer in the filter menu.
local WINDOW_DEFAULTS = { level = 3, skill = 15 };
local WINDOW_CHOICES = { level = { 1, 2, 3, 5, 10, 15, 20 }, skill = { 5, 10, 15, 25, 50, 75, 100 } };
local function WindowSize(kind, scope)
	local v = db and db.windowSize and db.windowSize[scope .. kind];
	return v or WINDOW_DEFAULTS[kind];
end

-- Current rank of an owned profession whose name appears in text, or nil.
local function OwnedProfessionRank(text)
	if type(text) ~= "string" or not (GetProfessions and GetProfessionInfo) then return nil; end
	for _, index in pairs({ GetProfessions() }) do
		local name, _, rank = GetProfessionInfo(index);
		if name and text:find(name, 1, true) then return rank; end
	end
	return nil;
end

local MERCHANT_CATS = { "known", "profession", "never", "skill", "expensive", "level", "other", "normal" };
local TRAINER_CATS = { "known", "skill", "expensive", "level", "other", "normal" };

-- Fuzzy: every whitespace-separated token must appear as a substring or, failing
-- that, as an in-order subsequence of the name (case-insensitive).
local function FuzzyMatch(name, query)
	if not query or query == "" then return true; end
	if type(name) ~= "string" then return false; end
	name = name:lower();
	for token in query:lower():gmatch("%S+") do
		if not name:find(token, 1, true) then
			local pos = 1;
			for c in token:gmatch(".") do
				local found = name:find(c, pos, true);
				if not found then return false; end
				pos = found + 1;
			end
		end
	end
	return true;
end

local merchantSearch, trainerSearch, merchantPageHint;

local function SearchText(box)
	return box and box:GetText() or "";
end

local function IsShownCategory(store, cat)
	return not (db and db[store] and db[store][cat] == false);
end

---------------------------------------------------------------------------
-- Trainer: same color language as the merchant
---------------------------------------------------------------------------

local function ClassifyTrainer(skillIndex, isPet)
	local _, serviceType, _, reqLevel = GetTrainerServiceInfo(skillIndex);
	if serviceType == "used" then return "known"; end
	if serviceType == "unavailable" then
		if reqLevel and reqLevel > 1 and UnitLevel(isPet and "pet" or "player") < reqLevel then
			return "level";
		end
		local _, _, hasSkillReq = GetTrainerServiceSkillReq(skillIndex);
		if hasSkillReq == false then return "skill"; end
		for i = 1, (GetTrainerServiceNumAbilityReq(skillIndex) or 0) do
			local ability, hasAbilReq = GetTrainerServiceAbilityReq(skillIndex, i);
			if ability and not hasAbilReq then return "skill"; end
		end
		return "other";
	end
	if not isPet then
		local cost = GetTrainerServiceCost(skillIndex);
		if cost and cost > 0 and GetMoney() < cost then return "expensive"; end
	end
	return "normal";
end

local function TintTrainerButton(skillButton, elementData)
	elementData = elementData and (elementData.data or elementData);
	if not (skillButton and skillButton.icon and elementData and elementData.skillIndex) then return; end
	local skillIndex = elementData.skillIndex;
	local isPet = elementData.trainerType == Enum.TrainerType.Pet;
	local icon = skillButton.icon;
	-- Buttons are recycled by the scroll box: always reset first.
	icon:SetVertexColor(1, 1, 1);
	skillButton:SetAlpha(1);
	SetCoinOn(skillButton, icon, false);
	SetMatchBorder(skillButton, icon, false);

	local cat = ClassifyTrainer(skillIndex, isPet);
	if cat == "known" then
		icon:SetDesaturated(true);
		icon:SetVertexColor(KNOWN[1], KNOWN[2], KNOWN[3]);
		-- Same darkened row background Blizzard uses for unavailable services.
		if skillButton.disabledBG then skillButton.disabledBG:Show(); end
	elseif cat == "level" then
		icon:SetDesaturated(false);
		icon:SetVertexColor(0.9, 0.1, 0.1);
	elseif cat == "skill" then
		icon:SetDesaturated(false);
		icon:SetVertexColor(LEARNABLE[1], LEARNABLE[2], LEARNABLE[3]);
	elseif cat == "expensive" then
		icon:SetVertexColor(TOO_EXPENSIVE[1], TOO_EXPENSIVE[2], TOO_EXPENSIVE[3]);
	end
	if cat ~= "known" and not isPet then
		local cost = GetTrainerServiceCost(skillIndex);
		SetCoinOn(skillButton, icon, cost and cost > 0 and GetMoney() < cost or false);
	end

	local name, serviceType, _, reqLevel = GetTrainerServiceInfo(skillIndex);
	local query = SearchText(trainerSearch);
	local visible = IsShownCategory("trainerShow", cat) and FuzzyMatch(name, query);
	-- Optional: profession services only count when at most the chosen number of points away.
	if visible and db and db.trainerSkillWindow then
		local skill, rank = GetTrainerServiceSkillReq(skillIndex);
		local myRank = skill and (OwnedProfessionRank(skill) or 0);
		if myRank and rank and rank > myRank + WindowSize("skill", "trainer") then visible = false; end
	end
	-- Optional: unavailable services only count when at most the chosen number of levels away.
	if visible and db and db.trainerLevelWindow and serviceType == "unavailable"
		and reqLevel and reqLevel > UnitLevel(isPet and "pet" or "player") + WindowSize("level", "trainer") then
		visible = false;
	end
	skillButton:SetAlpha(visible and 1 or DIM_ALPHA);
	SyncIconAlpha(skillButton, not visible);
	-- Price and the requirement line ("Requires: First Aid (50)") stay a bit more
	-- visible on dimmed rows; alpha can only be set per text line, not per word.
	for _, price in ipairs({ skillButton.money, skillButton.alternateCost, skillButton.subText }) do
		if price and price.SetIgnoreParentAlpha then
			price:SetIgnoreParentAlpha(not visible);
			price:SetAlpha(visible and 1 or DIM_PRICE_ALPHA);
		end
	end
	SetMatchBorder(skillButton, icon, query ~= "" and FuzzyMatch(name, query));
end

---------------------------------------------------------------------------
-- Merchant classification and tint
---------------------------------------------------------------------------

-- Usable (same rule as Blizzard's MerchantFrame_UpdateMerchantInfo) but not
-- affordable. Returns tooExpensive, soldOut, usable.
local function IsTooExpensive(index)
	local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(index);
	if not info then return false, false, true; end
	local itemID = GetMerchantItemID(index);
	local isHeirloom = itemID and C_Heirloom and C_Heirloom.IsItemHeirloom(itemID);
	local usable = info.isUsable or isHeirloom;
	-- Gold and every other currency are compared directly (CanAffordMerchantItem
	-- returns no value for affordable items).
	local cannotAfford = FirstMissingCost(GetMerchantCosts(index)) ~= nil;
	return usable and cannotAfford, info.numAvailable == 0, usable and info.isPurchasable ~= false;
end

local REQ_LEVEL_TYPE = Enum.TooltipDataUsageRequirementType and Enum.TooltipDataUsageRequirementType.Level;
local function LevelTooLowData(data)
	if not (data and data.lines and REQ_LEVEL_TYPE) then return false; end
	for _, line in ipairs(data.lines) do
		if line.type == LINE_USAGE_REQUIREMENT and line.requirementType == REQ_LEVEL_TYPE and IsRedLine(line) then
			return true;
		end
	end
	return false;
end

local function MerchantLevelTooLow(index)
	return LevelTooLowData(GetTip(index));
end

-- Returns category, soldOut.
local function ClassifyMerchant(index)
	local tooExpensive, soldOut, usable = IsTooExpensive(index);
	if IsMerchantItemKnown(index) then return "known", soldOut; end
	local never, why = IsNeverUsable(index);
	if never and why == "profession" then return "profession", soldOut; end
	local proficiency = GetProficiencyState(index);
	if proficiency == "never" or never then return "never", soldOut; end
	if proficiency == "learnable" then return "skill", soldOut; end
	if tooExpensive then return "expensive", soldOut; end
	if not usable then
		return MerchantLevelTooLow(index) and "level" or "other", soldOut;
	end
	return "normal", soldOut;
end

-- Required character level of a merchant item: item info first, otherwise the
-- tooltip's level requirement line (item info may not be cached yet).
local REQ_LEVEL = Enum.TooltipDataUsageRequirementType and Enum.TooltipDataUsageRequirementType.Level;
local function MinLevelData(data, itemID)
	if itemID and C_Item and C_Item.GetItemInfo then
		local minLevel = select(5, C_Item.GetItemInfo(itemID));
		if minLevel and minLevel > 0 then return minLevel; end
	end
	if data and data.lines and REQ_LEVEL then
		for _, line in ipairs(data.lines) do
			if line.type == LINE_USAGE_REQUIREMENT and line.requirementType == REQ_LEVEL and type(line.leftText) == "string" then
				local n = tonumber(line.leftText:match("(%d+)"));
				if n then return n; end
			end
		end
	end
	return nil;
end

local function GetMerchantItemMinLevel(index)
	return MinLevelData(GetTip(index), GetMerchantItemID(index));
end

-- Required rank of an owned profession ("Requires Cooking (50)"), plus the
-- character's current rank; nil if the item needs no owned profession.
local function SkillGapData(data)
	if not (data and data.lines and REQ_SKILL) then return nil; end
	for _, line in ipairs(data.lines) do
		if line.type == LINE_USAGE_REQUIREMENT and line.requirementType == REQ_SKILL then
			local need = tonumber(type(line.leftText) == "string" and line.leftText:match("%((%d+)%)") or nil);
			-- Not having the profession at all counts as rank 0.
			if need then return need, OwnedProfessionRank(line.leftText) or 0; end
		end
	end
	return nil;
end

local function GetMerchantSkillGap(index)
	return SkillGapData(GetTip(index));
end

-- "Fits me" checks (highlight only, never dims). Returns the first matching
-- criterion key: "class", "race", "gear" or "recipe"; nil if none applies.
local FITS_CRITERIA = { "class", "race", "gear", "recipe" };
local function Prefix(fmt)
	return type(fmt) == "string" and fmt:match("^(.-)%%s") or nil;
end
local CLASSES_PREFIX = Prefix(ITEM_CLASSES_ALLOWED);
local RACES_PREFIX = Prefix(ITEM_RACES_ALLOWED);

local function FitsMeData(data, itemID)
	local enabled = function(key) return not (db and db.fitsMe and db.fitsMe[key] == false); end;
	if data and data.lines then
		for _, line in ipairs(data.lines) do
			if line.type == LINE_USAGE_REQUIREMENT and not IsRedLine(line) and type(line.leftText) == "string" then
				if REQ_RACE_CLASS and line.requirementType == REQ_RACE_CLASS then
					local isRace = RACES_PREFIX and line.leftText:sub(1, #RACES_PREFIX) == RACES_PREFIX;
					local isClass = CLASSES_PREFIX and line.leftText:sub(1, #CLASSES_PREFIX) == CLASSES_PREFIX;
					if isClass and enabled("class") then return "class"; end
					if isRace and enabled("race") then return "race"; end
					if not isClass and not isRace and enabled("class") then return "class"; end
				elseif REQ_SKILL and line.requirementType == REQ_SKILL and enabled("recipe")
					and OwnedProfessionRank(line.leftText) then
					return "recipe";
				end
			end
		end
	end
	-- Gear: weapon/armor type the class can use and already knows (type line not red).
	if enabled("gear") and C_Item and C_Item.GetItemInfoInstant and data and data.lines then
		local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID or 0);
		local kind = (classID == ITEM_CLASS_WEAPON and "weapon") or (classID == ITEM_CLASS_ARMOR and "armor") or nil;
		local rules = CAN_EVER_USE[select(2, UnitClass("player"))];
		if kind and rules and rules[kind] and rules[kind][subClassID] then
			for _, line in ipairs(data.lines) do
				if line.type == LINE_EQUIP_SLOT then
					if not (IsRedColor(line.leftColor) or IsRedColor(line.rightColor)) then return "gear"; end
					break;
				end
			end
		end
	end
	return nil;
end

local function FitsMe(index)
	return FitsMeData(GetTip(index), GetMerchantItemID(index));
end

-- Green 7x7 check: directly below the coin if one is shown, else at the coin spot.
local CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready";
local function SetCheckOn(itemButton, anchor, show, belowCoin)
	if not itemButton then return; end
	show = show and IconEnabled("check");
	belowCoin = belowCoin and IconEnabled("coin");
	if show and not itemButton.StickyFiltersCheck then
		local holder = CreateFrame("Frame", nil, itemButton);
		holder:SetSize(10, 10);
		holder:SetFrameLevel(itemButton:GetFrameLevel() + 10); -- above the search effect (+6)
		local tex = holder:CreateTexture(nil, "ARTWORK");
		tex:SetTexture(CHECK_TEXTURE);
		tex:SetAllPoints();
		itemButton.StickyFiltersCheck = holder;
	end
	local holder = itemButton.StickyFiltersCheck;
	if not holder then return; end
	if show then
		local size = PX(holder, 10 * (itemButton.StickyFiltersIconScale or 1));
		holder:SetSize(size, size);
		holder:ClearAllPoints();
		if belowCoin and itemButton.StickyFiltersCoin then
			holder:SetPoint("TOPLEFT", itemButton.StickyFiltersCoin, "BOTTOMLEFT", 0, -PX(holder, 1));
		else
			holder:SetPoint("TOPLEFT", anchor or itemButton, "TOPLEFT", -size * (itemButton.StickyFiltersIconOutside or 0.5), PX(holder, 1));
		end
	end
	holder:SetShown(show);
end

local function IsMerchantVisible(index, cat)
	if not IsShownCategory("merchantShow", cat) then return false; end
	if db and db.merchantSkillWindow then
		local need, have = GetMerchantSkillGap(index);
		if need and need > have + WindowSize("skill", "merchant") then return false; end
	end
	if db and db.merchantLevelWindow then
		local minLevel = GetMerchantItemMinLevel(index);
		if minLevel and minLevel > UnitLevel("player") + WindowSize("level", "merchant") then return false; end
	end
	local query = SearchText(merchantSearch);
	if query == "" then return true; end
	local info = C_MerchantFrame.GetItemInfo(index);
	return info and FuzzyMatch(info.name, query) or false;
end

-- Merchant rows. Blizzard's 10 tiles (also when EllesmereUI skins them),
-- EllesmereUI's list rows ("Show As List", icon = the row's SlotTexture) and
-- its expanded tiles. Every row's ItemButton carries the real merchant index
-- as its ID, so all of them share one code path.
local MERCHANT_ROW_SETS = {
	{ prefix = "MerchantItem" },
	{ prefix = "EUI_MerchantItem", list = true },
	{ prefix = "EUI_MerchantPage" },
};

-- dim = Blizzard's darker variant (sold out); name frame is always half as bright.
local function Tint(row, itemButton, color, dim, list)
	local r, g, b = color[1], color[2], color[3];
	if dim then
		r, g, b = r * 0.5, g * 0.5, b * 0.5;
	end
	if list then
		if row.SlotTexture then row.SlotTexture:SetVertexColor(r, g, b); end
		return;
	end
	SetItemButtonNameFrameVertexColor(row, r * 0.6, g * 0.6, b * 0.6);
	SetItemButtonSlotVertexColor(row, r, g, b);
	SetItemButtonTextureVertexColor(itemButton, r, g, b);
	SetItemButtonNormalTextureVertexColor(itemButton, r, g, b);
end

local function EllesmereListActive()
	return _G.WSkinMerchantScrollFrame ~= nil and WSkinMerchantScrollFrame:IsVisible();
end

local function MerchantPlusActive()
	return _G.MerchantPlusFrame ~= nil and MerchantPlusFrame:IsVisible();
end

-- Merchant index of a MerchantPlus row (its element data), nil otherwise.
local function IsMerchantPlusRow(row)
	local list = _G.MerchantPlusItemList;
	local box = list and list.ScrollBox;
	local parent = row and row.GetParent and row:GetParent();
	return box ~= nil and parent ~= nil and (parent == box or parent == box.ScrollTarget);
end

local function MerchantPlusRowIndex(row)
	if not (row and row.GetElementData and MerchantPlusActive() and IsMerchantPlusRow(row)) then return nil; end
	local ok, data = pcall(row.GetElementData, row);
	return ok and type(data) == "table" and tonumber(data.index) or nil;
end

local function MerchantItemsPerPage()
	local eui = _G.EllesmereUI;
	if eui and eui._Merchant_ExpandActive and eui._Merchant_ExpandPerPage and eui._Merchant_ExpandActive() then
		local n = eui._Merchant_ExpandPerPage();
		if type(n) == "number" and n > 0 then return n; end
	end
	return MERCHANT_ITEMS_PER_PAGE;
end

-- The page hint is about the search only: without a search text it stays empty,
-- even when category or range filters are active. EllesmereUI's list has no pages.
local function UpdateMerchantPageHint()
	if not merchantPageHint then return; end
	local query = SearchText(merchantSearch);
	if query == "" or EllesmereListActive() or MerchantPlusActive() then
		merchantPageHint:SetText("");
		return;
	end
	local perPage = MerchantItemsPerPage();
	local pages, seen = {}, {};
	for index = 1, GetMerchantNumItems() do
		local info = C_MerchantFrame.GetItemInfo(index);
		if info and FuzzyMatch(info.name, query) then
			local page = math.ceil(index / perPage);
			if not seen[page] then
				seen[page] = true;
				pages[#pages + 1] = tostring(page);
			end
		end
	end
	merchantPageHint:SetText(#pages > 0 and L.MATCHES_ON_PAGES:format(table.concat(pages, ", ")) or L.NO_MATCHES);
end

-- Buyback items: same checks, fed with the buyback tooltip, link and price.
local function BuybackItemID(index)
	local link = GetBuybackItemLink and GetBuybackItemLink(index);
	if link and C_Item and C_Item.GetItemInfoInstant then return (C_Item.GetItemInfoInstant(link)); end
	return nil;
end

-- Returns category, tooltip data, item ID, name, price.
local function ClassifyBuyback(index)
	local name, _, price, _, _, isUsable = GetBuybackItemInfo(index);
	local data = C_TooltipInfo and C_TooltipInfo.GetBuybackItem and C_TooltipInfo.GetBuybackItem(index) or nil;
	local itemID = BuybackItemID(index);
	local cat;
	if IsItemKnown(data, itemID) then
		cat = "known";
	else
		local never, why = IsNeverUsableData(data);
		local proficiency = GetProficiencyStateData(data, itemID);
		if never and why == "profession" then cat = "profession";
		elseif proficiency == "never" or never then cat = "never";
		elseif proficiency == "learnable" then cat = "skill";
		elseif isUsable and price and price > GetMoney() then cat = "expensive";
		elseif not isUsable then cat = LevelTooLowData(data) and "level" or "other";
		else cat = "normal"; end
	end
	return cat, data, itemID, name, price;
end

-- Window/search checks on tooltip data: returns visible, levelHidden, skillHidden.
local function DataVisible(cat, data, itemID, name)
	local levelHidden, skillHidden = false, false;
	if db and db.merchantSkillWindow then
		local need, have = SkillGapData(data);
		skillHidden = need ~= nil and need > have + WindowSize("skill", "merchant");
	end
	if db and db.merchantLevelWindow then
		local minLevel = MinLevelData(data, itemID);
		levelHidden = minLevel ~= nil and minLevel > UnitLevel("player") + WindowSize("level", "merchant");
	end
	local query = SearchText(merchantSearch);
	local searchOk = query == "" or (name ~= nil and FuzzyMatch(name, query));
	return IsShownCategory("merchantShow", cat) and not levelHidden and not skillHidden and searchOk, levelHidden, skillHidden;
end

-- Everything a row shows for one entry: category, sold out, coin (true =
-- gold, texture = other currency), visible, search match, fits me.
local function MerchantEntryState(index, query)
	local cat, soldOut = ClassifyMerchant(index);
	local coin = false;
	local missingCost = FirstMissingCost(GetMerchantCosts(index));
	if missingCost then coin = missingCost.gold and true or missingCost.texture; end
	local info = query ~= "" and C_MerchantFrame.GetItemInfo(index);
	return cat, soldOut, coin, IsMerchantVisible(index, cat), info and FuzzyMatch(info.name, query) or false, FitsMe(index) ~= nil;
end

local function BuybackEntryState(index, query)
	local cat, data, itemID, name, price = ClassifyBuyback(index);
	local coin = price ~= nil and price > GetMoney();
	local visible = DataVisible(cat, data, itemID, name);
	local match = query ~= "" and name ~= nil and FuzzyMatch(name, query) or false;
	return cat, false, coin, visible, match, FitsMeData(data, itemID) ~= nil;
end

-- Purple (epic) item names are hard to read in dimmed rows: only there the
-- name ignores the row's alpha and uses a lighter purple. MerchantPlus puts
-- the quality color into the text itself, so that color code is swapped too.
local QUALITY_EPIC = (Enum.ItemQuality and Enum.ItemQuality.Epic) or 4;
local EPIC_HEX, EPIC_DIM_HEX = "ffa335ee", "ffb86bf7";
local DIM_EPIC_NAME_ALPHA = 0.35;
local function IsEpicItem(itemID)
	return itemID ~= nil and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID) == QUALITY_EPIC or false;
end

local function SetDimmedEpicName(fs, on)
	if not fs then return; end
	fs:SetIgnoreParentAlpha(on and true or false);
	fs:SetAlpha(on and DIM_EPIC_NAME_ALPHA or 1);
	if on then
		if not fs.StickyFiltersNameColor then fs.StickyFiltersNameColor = { fs:GetTextColor() }; end
		fs:SetTextColor(0.72, 0.42, 0.97);
	elseif fs.StickyFiltersNameColor then
		-- Restore only if nobody repainted the name since (Blizzard does on updates).
		local r, g, b = fs:GetTextColor();
		if math.abs(r - 0.72) < 0.01 and math.abs(g - 0.42) < 0.01 and math.abs(b - 0.97) < 0.01 then
			fs:SetTextColor(unpack(fs.StickyFiltersNameColor));
		end
		fs.StickyFiltersNameColor = nil;
	end
	local text = fs:GetText();
	if type(text) == "string" then
		local from, to = on and EPIC_HEX or EPIC_DIM_HEX, on and EPIC_DIM_HEX or EPIC_HEX;
		local swapped = text:gsub("|c" .. from, "|c" .. to);
		if swapped ~= text then fs:SetText(swapped); end
	end
end

local function TintMerchantRow(row, rowName, list, numItems, query, buyback)
	local itemButton = row.ItemButton or _G[rowName .. "ItemButton"];
	if not itemButton then return; end
	local icon = list and row.SlotTexture or nil;
	-- EllesmereUI list rows: icons on top of the item icon (1 unit to the left,
	-- as before); tiles keep them half outside.
	itemButton.StickyFiltersIconOutside = list and 0.1 or nil;
	-- Empty slots keep their old ID: merchant slots are told apart by hasItem
	-- (Blizzard, EllesmereUI list rows and expanded tiles all set it), buyback
	-- slots by their shown item button.
	local index;
	if buyback then
		index = itemButton:IsShown() and itemButton:GetID() or 0;
		if index > 0 and not GetBuybackItemInfo(index) then index = 0; end
	else
		index = itemButton.hasItem and itemButton:GetID() or 0;
	end
	local coin, match, fits = false, false, false;
	local nameFS = row.Name or _G[rowName .. "Name"];
	local epicDimmed = false;
	row:SetAlpha(1);
	if index > 0 and index <= numItems then
		local cat, soldOut, visible;
		if buyback then
			cat, soldOut, coin, visible, match, fits = BuybackEntryState(index, query);
		else
			cat, soldOut, coin, visible, match, fits = MerchantEntryState(index, query);
		end
		if buyback and cat ~= "known" and not list then
			SetItemButtonDesaturated(itemButton, false);
		end
		if cat == "known" then
			Tint(row, itemButton, KNOWN, false, list);
			-- Blizzard and EllesmereUI reset desaturation on every update.
			if list then
				if row.SlotTexture then row.SlotTexture:SetDesaturated(true); end
			else
				SetItemButtonDesaturated(itemButton, true);
			end
		elseif cat == "profession" then
			Tint(row, itemButton, PROFESSION_MISSING, false, list);
		elseif cat == "never" then
			Tint(row, itemButton, NEVER_USABLE, false, list);
		elseif cat == "skill" then
			Tint(row, itemButton, LEARNABLE, soldOut, list);
		elseif cat == "expensive" then
			Tint(row, itemButton, TOO_EXPENSIVE, soldOut, list);
		end
		if coin == true and _G[rowName .. "MoneyFrame"] then
			SetMoneyFrameColor(rowName .. "MoneyFrame", "red");
		end
		if not visible then
			row:SetAlpha(buyback and BUYBACK_DIM_ALPHA or DIM_ALPHA);
			local itemID;
			if buyback then itemID = BuybackItemID(index); else itemID = GetMerchantItemID(index); end
			epicDimmed = IsEpicItem(itemID);
		end
	end
	SetDimmedEpicName(nameFS, epicDimmed);
	SetCoinOn(itemButton, icon, coin and true or false, type(coin) ~= "boolean" and coin or nil);
	SetCheckOn(itemButton, icon, fits, coin and true or false);
	SyncIconAlpha(itemButton, row:GetAlpha() < 1);
	SetMatchBorder(itemButton, icon, match);
end

-- MerchantPlus: rows of its own scrolling table, recycled while scrolling, so
-- every row gets its full state (including white / not desaturated).
local BLIZZARD_RED = { 0.9, 0, 0 };
local PLUS_COLORS = { known = KNOWN, profession = PROFESSION_MISSING, never = NEVER_USABLE, skill = LEARNABLE,
	expensive = TOO_EXPENSIVE, level = BLIZZARD_RED, other = BLIZZARD_RED };
-- Opacity of the whole-row color behind a MerchantPlus row.
local PLUS_ROW_ALPHA = 0.3;

local function PlusRowColorEnabled()
	return not (db and db.plusRowColor == false);
end

local function TintMerchantPlusRow(row)
	local index = MerchantPlusRowIndex(row);
	if not index then return; end
	local icon, nameFS;
	for _, child in ipairs({ row:GetChildren() }) do
		if child.Icon and child.IconBorder then icon, nameFS = child.Icon, child.Text; break; end
	end
	-- Cells not built yet: the deferred pass decorates the row later, so the
	-- icons are never anchored to the row corner.
	if not icon then return; end
	-- The table rows are only 20 units high: icons 25% smaller.
	row.StickyFiltersIconScale = 0.75;
	-- Fully left of the small icon (merchant tiles: half outside).
	row.StickyFiltersIconOutside = 1;
	local query = SearchText(merchantSearch);
	local cat, _, coin, visible, match, fits = MerchantEntryState(index, query);
	local color = PLUS_COLORS[cat];
	icon:SetVertexColor(color and color[1] or 1, color and color[2] or 1, color and color[3] or 1);
	icon:SetDesaturated(cat == "known");
	-- Whole row in the category color (option, on by default).
	if not row.StickyFiltersRowTint then
		local tint = row:CreateTexture(nil, "BACKGROUND", nil, 1);
		tint:SetAllPoints(row);
		row.StickyFiltersRowTint = tint;
	end
	if color and PlusRowColorEnabled() then
		row.StickyFiltersRowTint:SetColorTexture(color[1], color[2], color[3], PLUS_ROW_ALPHA);
		row.StickyFiltersRowTint:Show();
	else
		row.StickyFiltersRowTint:Hide();
	end
	row:SetAlpha(visible and 1 or DIM_ALPHA);
	SetDimmedEpicName(nameFS, not visible and IsEpicItem(GetMerchantItemID(index)));
	SetCoinOn(row, icon, coin and true or false, type(coin) ~= "boolean" and coin or nil);
	SetCheckOn(row, icon, fits, coin and true or false);
	SyncIconAlpha(row, row:GetAlpha() < 1);
	-- Same animated search effect as on merchant tiles, around the square icon.
	SetMatchBorder(row, icon, match);
end

local function TintMerchantPlusRows()
	local list = _G.MerchantPlusItemList;
	if not (MerchantPlusActive() and list and list.ScrollBox and list.ScrollBox.ForEachFrame) then return; end
	list.ScrollBox:ForEachFrame(function(row)
		local ok, err = pcall(TintMerchantPlusRow, row);
		if not ok then Debug("MerchantPlus row", err); end
	end);
end

local function TintMerchantItems()
	if not MerchantFrame then return; end
	local buyback = MerchantFrame.selectedTab == 2;
	if MerchantFrame.selectedTab ~= 1 and not buyback then return; end
	if not buyback then TintMerchantPlusRows(); end
	local numItems = buyback and GetNumBuybackItems() or GetMerchantNumItems();
	local query = SearchText(merchantSearch);
	for _, set in ipairs(MERCHANT_ROW_SETS) do
		local i = 1;
		while _G[set.prefix .. i] do
			local row = _G[set.prefix .. i];
			-- IsVisible: EllesmereUI parks Blizzard's tiles in a hidden holder.
			if row:IsVisible() then
				TintMerchantRow(row, set.prefix .. i, set.list, numItems, query, buyback);
			end
			i = i + 1;
		end
	end
	if buyback then
		if merchantPageHint then merchantPageHint:SetText(""); end
	else
		UpdateMerchantPageHint();
	end
end

---------------------------------------------------------------------------
-- Quest rewards: quest log preview and quest giver (accept / turn in).
-- Buttons: every UI that updates its reward buttons through Blizzard's item
-- button helpers (Blizzard, Immersion and most reskins) is covered, because
-- such buttons carry type ("choice"/"reward") and the reward index as ID.
-- Tooltips: recognized by their C_TooltipInfo getter, see AddMoneyLines.
---------------------------------------------------------------------------

local QUEST_REWARD_TYPES = { choice = true, reward = true };
local QUEST_COLORS = { known = KNOWN, profession = PROFESSION_MISSING, never = NEVER_USABLE, skill = LEARNABLE };

local function QuestOption(key)
	return not (db and db.quest and db.quest[key] == false);
end

local function IsQuestRewardButton(button)
	return type(button) == "table" and QUEST_REWARD_TYPES[button.type] and button.GetID ~= nil
		and (button:GetID() or 0) > 0 or false;
end

-- Blizzard's own reward frames while they show a quest log entry (map side
-- panel, quest popup). Everything else uses the quest giver API.
local function IsQuestLogButton(button)
	if not (QuestInfoFrame and QuestInfoFrame.questLog) then return false; end
	local parent = button:GetParent();
	return parent ~= nil and (parent == QuestInfoRewardsFrame or parent == MapQuestInfoRewardsFrame);
end

local function GetQuestRewardData(button)
	if not C_TooltipInfo then return nil; end
	local data;
	if IsQuestLogButton(button) then
		data = C_TooltipInfo.GetQuestLogItem and C_TooltipInfo.GetQuestLogItem(button.type, button:GetID(), button.questID);
	else
		data = C_TooltipInfo.GetQuestItem and C_TooltipInfo.GetQuestItem(button.type, button:GetID());
	end
	return data;
end

-- Same categories as merchant items, without "expensive".
local function ClassifyQuestReward(data, itemID)
	if IsItemKnown(data, itemID) then return "known"; end
	local never, why = IsNeverUsableData(data);
	if never and why == "profession" then return "profession"; end
	local proficiency = GetProficiencyStateData(data, itemID);
	if proficiency == "never" or never then return "never"; end
	if proficiency == "learnable" then return "skill"; end
	if LevelTooLowData(data) then return "level"; end
	if data and data.lines and LINE_USAGE_REQUIREMENT then
		for _, line in ipairs(data.lines) do
			if line.type == LINE_USAGE_REQUIREMENT and IsRedLine(line) then return "other"; end
		end
	end
	return "normal";
end

-- Item ID of tooltip data (id, or the hyperlink as fallback).
local function TipItemID(data)
	if not data then return nil; end
	if data.id then return data.id; end
	if data.hyperlink and C_Item and C_Item.GetItemInfoInstant then
		return (C_Item.GetItemInfoInstant(data.hyperlink));
	end
	return nil;
end

local function QuestIcon(button)
	local name = button.GetName and button:GetName();
	return button.Icon or button.icon or (name and _G[name .. "IconTexture"]) or nil;
end

local questTinting = false;
local function DecorateQuestReward(button)
	local isItem = button.objectType == nil or button.objectType == "item";
	local data = isItem and GetQuestRewardData(button) or nil;
	local itemID = TipItemID(data);
	local icon = QuestIcon(button);
	local cat = data and ClassifyQuestReward(data, itemID) or "normal";
	local color = QuestOption("colors") and QUEST_COLORS[cat] or nil;
	if color then
		questTinting = true;
		SetItemButtonTextureVertexColor(button, color[1], color[2], color[3]);
		SetItemButtonNameFrameVertexColor(button, color[1], color[2], color[3]);
		questTinting = false;
	end
	if icon and icon.SetDesaturated then icon:SetDesaturated(color == KNOWN); end
	SetCheckOn(button, icon, QuestOption("check") and data ~= nil and FitsMeData(data, itemID) ~= nil, false);
	-- Item not cached yet: its tooltip lacks the requirement lines. Decorate
	-- again once it is loaded, if the button still shows the same reward.
	if isItem and itemID and C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID)
		and Item and Item.CreateFromItemID then
		local rewardType, rewardID = button.type, button:GetID();
		Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
			if button.type == rewardType and button:GetID() == rewardID then DecorateQuestReward(button); end
		end);
	end
end

-- Blizzard and other UIs color reward buttons through this helper whenever
-- they (re)draw them, including after item data finished loading.
hooksecurefunc("SetItemButtonTextureVertexColor", function(button)
	if questTinting or not IsQuestRewardButton(button) then return; end
	DecorateQuestReward(button);
end);

AddQuestRewardLines = function(tooltip, data)
	if not (QuestOption("tooltip") and data and data.lines) then return; end
	local itemID = TipItemID(data);
	local lines = {};
	local cat = ClassifyQuestReward(data, itemID);
	if L["WHY_" .. cat:upper()] then lines[#lines + 1] = L["WHY_" .. cat:upper()]; end
	local fits = FitsMeData(data, itemID);
	if fits then lines[#lines + 1] = L["WHY_FITS_" .. fits:upper()]; end
	if #lines == 0 then return; end
	tooltip:AddLine(" ");
	for _, text in ipairs(lines) do
		AddSmallGrayLine(tooltip, text);
	end
end;

-- Explanations shown in gray under Missing/After buy.
GetReasonLines = function(owner)
	local lines = {};
	local buybackIndex = GetBuybackIndexFromOwner(owner);
	if buybackIndex then
		local cat, data, itemID, name = ClassifyBuyback(buybackIndex);
		if L["WHY_" .. cat:upper()] then lines[#lines + 1] = L["WHY_" .. cat:upper()]; end
		local fits = FitsMeData(data, itemID);
		if fits then lines[#lines + 1] = L["WHY_FITS_" .. fits:upper()]; end
		local _, levelHidden, skillHidden = DataVisible(cat, data, itemID, name);
		if not IsShownCategory("merchantShow", cat) then lines[#lines + 1] = L.DIM_CATEGORY; end
		if levelHidden then lines[#lines + 1] = L.DIM_LEVEL:format(WindowSize("level", "merchant")); end
		if skillHidden then lines[#lines + 1] = L.DIM_SKILL:format(WindowSize("skill", "merchant")); end
		local query = SearchText(merchantSearch);
		if query ~= "" then
			lines[#lines + 1] = (name and FuzzyMatch(name, query)) and L.SEARCH_MATCH or L.DIM_SEARCH;
		end
		return lines;
	end
	local index = GetMerchantIndexFromOwner(owner);
	if index then
		local cat = ClassifyMerchant(index);
		if L["WHY_" .. cat:upper()] then lines[#lines + 1] = L["WHY_" .. cat:upper()]; end
		local fits = FitsMe(index);
		if fits then lines[#lines + 1] = L["WHY_FITS_" .. fits:upper()]; end
		if not IsShownCategory("merchantShow", cat) then lines[#lines + 1] = L.DIM_CATEGORY; end
		if db and db.merchantLevelWindow then
			local minLevel = GetMerchantItemMinLevel(index);
			if minLevel and minLevel > UnitLevel("player") + WindowSize("level", "merchant") then
				lines[#lines + 1] = L.DIM_LEVEL:format(WindowSize("level", "merchant"));
			end
		end
		if db and db.merchantSkillWindow then
			local need, have = GetMerchantSkillGap(index);
			if need and need > have + WindowSize("skill", "merchant") then lines[#lines + 1] = L.DIM_SKILL:format(WindowSize("skill", "merchant")); end
		end
		local query = SearchText(merchantSearch);
		if query ~= "" then
			local info = C_MerchantFrame.GetItemInfo(index);
			lines[#lines + 1] = (info and FuzzyMatch(info.name, query)) and L.SEARCH_MATCH or L.DIM_SEARCH;
		end
		return lines;
	end
	if owner and ClassTrainerFrame and ClassTrainerFrame:IsShown() and owner.subText and owner.GetID then
		local skillIndex = owner:GetID();
		local isPet = C_Trainer and C_Trainer.GetTrainerType and Enum.TrainerType and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet;
		local cat = ClassifyTrainer(skillIndex, isPet);
		local key = "WHY_" .. (cat == "skill" and "TRAINER_SKILL" or cat:upper());
		if L[key] then lines[#lines + 1] = L[key]; end
		if not IsShownCategory("trainerShow", cat) then lines[#lines + 1] = L.DIM_CATEGORY; end
		local name, serviceType, _, reqLevel = GetTrainerServiceInfo(skillIndex);
		if db and db.trainerLevelWindow and serviceType == "unavailable" and reqLevel
			and reqLevel > UnitLevel(isPet and "pet" or "player") + WindowSize("level", "trainer") then
			lines[#lines + 1] = L.DIM_LEVEL:format(WindowSize("level", "trainer"));
		end
		if db and db.trainerSkillWindow then
			local skill, rank = GetTrainerServiceSkillReq(skillIndex);
			local myRank = skill and (OwnedProfessionRank(skill) or 0);
			if myRank and rank and rank > myRank + WindowSize("skill", "trainer") then lines[#lines + 1] = L.DIM_SKILL:format(WindowSize("skill", "trainer")); end
		end
		local query = SearchText(trainerSearch);
		if query ~= "" then
			lines[#lines + 1] = FuzzyMatch(name, query) and L.SEARCH_MATCH or L.DIM_SEARCH;
		end
	end
	return lines;
end;

---------------------------------------------------------------------------
-- Filter UI (search box + filter menu) for merchant and trainer
---------------------------------------------------------------------------

local function CategoryMenu(rootDescription, store, cats, refresh)
	rootDescription:CreateTitle(L.ADDON_TITLE);
	local function IsSelected(cat) return IsShownCategory(store, cat); end
	local function SetSelected(cat)
		db[store] = db[store] or {};
		db[store][cat] = not IsShownCategory(store, cat);
		refresh();
	end
	for _, cat in ipairs(cats) do
		rootDescription:CreateCheckbox(L["CAT_" .. cat:upper()], IsSelected, SetSelected, cat);
	end
	rootDescription:CreateButton(L.SHOW_ALL, function()
		db[store] = {};
		refresh();
	end);
	rootDescription:CreateButton(L.HIDE_ALL, function()
		db[store] = {};
		for _, cat in ipairs(cats) do db[store][cat] = false; end
		refresh();
	end);
end

-- Search text survives closing the window when "Save search" is on.
local function SearchSaved(key)
	return not (db and db.saveSearch and db.saveSearch[key] == false);
end

-- Saved search scope: "global" (one text for all merchants/trainers) or "npc"
-- (one text per NPC, keyed by the NPC id from its GUID).
local function SearchPerNpc(key)
	local v = db and db.searchPerNpc and db.searchPerNpc[key];
	if v == nil then return true; end -- default: separate search per NPC
	return v;
end

local function CurrentNpcID()
	local guid = UnitGUID("npc");
	return guid and tonumber((select(6, strsplit("-", guid)))) or nil;
end

local function SavedSearchSlot(key)
	db.searchText = db.searchText or {};
	if SearchPerNpc(key) then
		local npc = CurrentNpcID();
		if not npc then return nil; end
		db.searchTextNpc = db.searchTextNpc or {};
		db.searchTextNpc[key] = db.searchTextNpc[key] or {};
		return db.searchTextNpc[key], npc;
	end
	return db.searchText, key;
end

local function HookSearchPersistence(box, frame, key)
	box:HookScript("OnTextChanged", function(self)
		if db and SearchSaved(key) and frame:IsShown() then
			local tbl, slot = SavedSearchSlot(key);
			if tbl then tbl[slot] = self:GetText() ~= "" and self:GetText() or nil; end
		end
	end);
	frame:HookScript("OnShow", function()
		local saved = "";
		if SearchSaved(key) then
			local tbl, slot = SavedSearchSlot(key);
			saved = tbl and tbl[slot] or "";
		end
		if box:GetText() ~= saved then box:SetText(saved); end
	end);
	frame:HookScript("OnHide", function()
		if not SearchSaved(key) and box:GetText() ~= "" then box:SetText(""); end
	end);
end

-- "Only up to +N ..." checkbox; hovering it opens a submenu to pick N.
local function WindowCheckbox(rootDescription, kind, scope, refresh)
	local flag = scope .. (kind == "level" and "LevelWindow" or "SkillWindow");
	local label = (kind == "level" and L.LEVEL_WINDOW or L.SKILL_WINDOW):format(WindowSize(kind, scope));
	local cb = rootDescription:CreateCheckbox(label,
		function() return db and db[flag] or false; end,
		function()
			db[flag] = not db[flag];
			refresh();
		end);
	for _, n in ipairs(WINDOW_CHOICES[kind]) do
		cb:CreateRadio("+" .. n,
			function(v) return WindowSize(kind, scope) == v; end,
			function(v)
				db.windowSize = db.windowSize or {};
				db.windowSize[scope .. kind] = v;
				db[flag] = true;
				refresh();
			end, n);
	end
end

local function SaveSearchCheckbox(rootDescription, key, refresh)
	local cb = rootDescription:CreateCheckbox(L.SAVE_SEARCH,
		function() return SearchSaved(key); end,
		function()
			db.saveSearch = db.saveSearch or {};
			db.saveSearch[key] = not SearchSaved(key);
			if not SearchSaved(key) and db.searchText then db.searchText[key] = nil; end
			refresh();
		end);
	-- Submenu: global or per NPC.
	for _, perNpc in ipairs({ false, true }) do
		cb:CreateRadio(perNpc and L.SEARCH_PER_NPC or L.SEARCH_GLOBAL,
			function(v) return SearchPerNpc(key) == v; end,
			function(v)
				db.searchPerNpc = db.searchPerNpc or {};
				db.searchPerNpc[key] = v;
				db.saveSearch = db.saveSearch or {};
				db.saveSearch[key] = true;
			end, perNpc);
	end
end

-- One-time hint pointing at the search box and filter menu. X closes it for
-- this session, "Don't show again" turns it off (re-enable in the filter menu).
local hintClosed = {};
local function HintEnabled(key)
	return not (db and db.hintOff and db.hintOff[key]);
end

-- EllesmereUI skinning API: our own controls (search boxes, filter buttons,
-- hint boxes) get the user's EllesmereUI look. The callback runs at login and
-- only while the user keeps third-party skinning on for StickyFilters;
-- controls created before or after it are queued or skinned directly.
local euiSkin;
local skinQueue = {};
local function ApplySkin(S, kind, frame)
	if kind == "editbox" and S.EditBox then S.EditBox(frame);
	elseif kind == "dropdown" and S.Dropdown then S.Dropdown(frame);
	elseif kind == "button" and S.Button then S.Button(frame);
	elseif kind == "close" and S.CloseButton then S.CloseButton(frame);
	elseif kind == "panel" and S.Panel then
		if frame.ClearBackdrop then frame:ClearBackdrop(); end
		S.Panel(frame);
	end
end

local function Skin(kind, frame)
	if not frame then return; end
	if euiSkin then
		pcall(ApplySkin, euiSkin, kind, frame);
	else
		skinQueue[#skinQueue + 1] = { kind, frame };
	end
end

if EllesmereUI and EllesmereUI.RegisterSkin then
	EllesmereUI.RegisterSkin(ADDON_NAME, function(S)
		euiSkin = S;
		for _, entry in ipairs(skinQueue) do
			pcall(ApplySkin, S, entry[1], entry[2]);
		end
		skinQueue = {};
	end);
end

local function CreateHint(parent, target, key, text)
	local hint = CreateFrame("Frame", nil, parent, "BackdropTemplate");
	hint:SetSize(230, 74);
	hint:SetFrameStrata("DIALOG");
	hint:SetPoint("LEFT", target, "RIGHT", 30, 0); -- to the right of the filter / search, room for the arrow
	hint:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	});
	hint:SetBackdropColor(0.05, 0.05, 0.08, 0.95);
	hint:SetBackdropBorderColor(1, 0.82, 0, 1);
	local label = hint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	label:SetPoint("TOPLEFT", 10, -10);
	label:SetWidth(196);
	label:SetJustifyH("LEFT");
	label:SetText(text);
	-- Height follows the text: top padding, text, a gap, the button, bottom padding.
	local function FitHeight()
		hint:SetHeight(10 + label:GetStringHeight() + 10 + 20 + 8);
	end
	FitHeight();
	hint:SetScript("OnShow", FitHeight);
	-- Blizzard's help-plate arrow (points down in the file), rotated to point
	-- left at the target; it gently bobs left and right. It lives on its own
	-- child frame: skins (EllesmereUI's panel) fade every texture of the hint.
	local arrowHolder = CreateFrame("Frame", nil, hint);
	arrowHolder:SetAllPoints(hint);
	local arrow = arrowHolder:CreateTexture(nil, "OVERLAY");
	arrow:SetTexture("Interface\\TalentFrame\\TalentFrame-Parts");
	arrow:SetTexCoord(0.78515625, 0.99218750, 0.54687500, 0.58789063);
	arrow:SetSize(30, 12);
	arrow:SetRotation(-math.pi / 2);
	arrow:SetPoint("CENTER", hint, "LEFT", -14, 0);
	-- Smooth sine bob (an AnimationGroup BOUNCE snaps at the turning point).
	local elapsed = 0;
	hint:SetScript("OnUpdate", function(_, dt)
		elapsed = (elapsed + dt) % 1.2;
		local offset = -2.5 + 2.5 * math.cos(elapsed / 1.2 * 2 * math.pi);
		arrow:SetPoint("CENTER", hint, "LEFT", -14 + offset, 0);
	end);
	local close = CreateFrame("Button", nil, hint, "UIPanelCloseButton");
	close:SetSize(20, 20);
	close:SetPoint("TOPRIGHT", 0, 0);
	close:SetScript("OnClick", function()
		hintClosed[key] = true;
		hint:Hide();
	end);
	local never = CreateFrame("Button", nil, hint, "UIPanelButtonTemplate");
	never:SetSize(130, 20);
	never:SetPoint("BOTTOMLEFT", 8, 8);
	never:SetText(L.HINT_NEVER);
	never:SetScript("OnClick", function()
		db.hintOff = db.hintOff or {};
		db.hintOff[key] = true;
		hint:Hide();
	end);
	Skin("panel", hint);
	Skin("close", close);
	Skin("button", never);
	hint:Hide();
	parent:HookScript("OnShow", function()
		hint:SetShown(HintEnabled(key) and not hintClosed[key]);
	end);
	parent:HookScript("OnHide", function() hint:Hide(); end);
	return hint;
end

local function HintCheckbox(rootDescription, key)
	rootDescription:CreateCheckbox(L.HINT_SHOW,
		function() return HintEnabled(key); end,
		function()
			db.hintOff = db.hintOff or {};
			db.hintOff[key] = HintEnabled(key) or nil;
			hintClosed[key] = nil;
		end);
end

local function CreateSearchBox(parent, onChange)
	local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate");
	box:SetSize(150, 20);
	box:SetAutoFocus(false);
	if box.Instructions then box.Instructions:SetText(L.SEARCH); end
	box:HookScript("OnTextChanged", onChange);
	Skin("editbox", box);
	return box;
end

local function RefreshMerchant()
	if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update(); end
end

local function RefreshTrainer()
	if ClassTrainerFrame and ClassTrainerFrame:IsShown() and ClassTrainerFrame_Update then
		ClassTrainerFrame_Update(true);
	end
end

local function CreateMerchantUI()
	if merchantSearch or not MerchantFrame then return; end
	-- Placed just above the frame so nothing of Blizzard's layout is covered.
	merchantSearch = CreateSearchBox(MerchantFrame, RefreshMerchant);
	merchantSearch:SetPoint("BOTTOMRIGHT", MerchantFrame, "TOPRIGHT", -6, 2);
	local dropdown = CreateFrame("DropdownButton", nil, MerchantFrame, "WowStyle1FilterDropdownTemplate");
	Skin("dropdown", dropdown);
	merchantSearch:ClearAllPoints();
	merchantSearch:SetPoint("BOTTOMRIGHT", MerchantFrame, "TOPRIGHT", -102, 2);
	dropdown:SetPoint("LEFT", merchantSearch, "RIGHT", 6, 0);
	if AnchorUtil and dropdown.SetMenuAnchor then
		dropdown:SetMenuAnchor(AnchorUtil.CreateAnchor("TOPLEFT", dropdown, "TOPRIGHT", 2, 0));
	end
	dropdown:SetWidth(90);
	dropdown:SetText(L.FILTER);
	dropdown:SetupMenu(function(_, rootDescription)
		CategoryMenu(rootDescription, "merchantShow", MERCHANT_CATS, RefreshMerchant);
		rootDescription:CreateDivider();
		WindowCheckbox(rootDescription, "level", "merchant", RefreshMerchant);
		WindowCheckbox(rootDescription, "skill", "merchant", RefreshMerchant);
		rootDescription:CreateDivider();
		rootDescription:CreateTitle(L.FITS_TITLE);
		for _, key in ipairs(FITS_CRITERIA) do
			rootDescription:CreateCheckbox(L["FITS_" .. key:upper()],
				function() return not (db and db.fitsMe and db.fitsMe[key] == false); end,
				function()
					db.fitsMe = db.fitsMe or {};
					db.fitsMe[key] = (db.fitsMe[key] == false);
					RefreshMerchant();
				end);
		end
		rootDescription:CreateDivider();
		SaveSearchCheckbox(rootDescription, "merchant", RefreshMerchant);
		HintCheckbox(rootDescription, "merchant");
	end);
	merchantPageHint = MerchantFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	merchantPageHint:SetPoint("BOTTOM", MerchantPageText, "TOP", 0, 3);
	HookSearchPersistence(merchantSearch, MerchantFrame, "merchant");
	CreateHint(MerchantFrame, dropdown, "merchant", L.HINT_MERCHANT);
end

local trainerHooked = false;
local function InstallTrainerHook()
	if trainerHooked or not ClassTrainerFrame_InitServiceButton then return; end
	trainerHooked = true;
	hooksecurefunc("ClassTrainerFrame_InitServiceButton", function(skillButton, elementData)
		local ok, err = pcall(TintTrainerButton, skillButton, elementData);
		if not ok and err ~= lastError then
			lastError = err;
			print("|cffff4040StickyFilters " .. L.ERROR .. ":|r " .. tostring(err));
		end
	end);
	trainerSearch = CreateSearchBox(ClassTrainerFrame, RefreshTrainer);
	trainerSearch:SetPoint("BOTTOMRIGHT", ClassTrainerFrame, "TOPRIGHT", -102, 2);
	-- Own filter button (same as the merchant); Blizzard's trainer menu stays untouched.
	local trainerDropdown = CreateFrame("DropdownButton", nil, ClassTrainerFrame, "WowStyle1FilterDropdownTemplate");
	Skin("dropdown", trainerDropdown);
	trainerDropdown:SetPoint("LEFT", trainerSearch, "RIGHT", 6, 0);
	trainerDropdown:SetWidth(90);
	trainerDropdown:SetText(L.FILTER);
	if AnchorUtil and trainerDropdown.SetMenuAnchor then
		trainerDropdown:SetMenuAnchor(AnchorUtil.CreateAnchor("TOPLEFT", trainerDropdown, "TOPRIGHT", 2, 0));
	end
	trainerDropdown:SetupMenu(function(_, rootDescription)
		CategoryMenu(rootDescription, "trainerShow", TRAINER_CATS, RefreshTrainer);
		rootDescription:CreateDivider();
		WindowCheckbox(rootDescription, "level", "trainer", RefreshTrainer);
		WindowCheckbox(rootDescription, "skill", "trainer", RefreshTrainer);
		rootDescription:CreateDivider();
		SaveSearchCheckbox(rootDescription, "trainer", RefreshTrainer);
		HintCheckbox(rootDescription, "trainer");
	end);
	-- Blizzard's trainer filter menu opens to the right instead of over the list.
	local tdd = ClassTrainerFrame.FilterDropdown;
	if tdd and tdd.SetMenuAnchor and AnchorUtil then
		tdd:SetMenuAnchor(AnchorUtil.CreateAnchor("TOPLEFT", tdd, "TOPRIGHT", 2, 0));
	end
	HookSearchPersistence(trainerSearch, ClassTrainerFrame, "trainer");
	CreateHint(ClassTrainerFrame, trainerDropdown, "trainer", L.HINT_TRAINER);
end

-- Installed on PLAYER_LOGIN (after all addons loaded) so this hook runs after
-- other addons' hooks (e.g. WhatsTraining tints known tomes dark red) and the
-- "known" gray wins.
local function SafeTintMerchantItems()
	local ok, err = pcall(TintMerchantItems);
	if not ok and err ~= lastError then
		lastError = err;
		print("|cffff4040StickyFilters " .. L.ERROR .. ":|r " .. tostring(err));
	end
end

-- EllesmereUI fills its list one frame after MerchantFrame_Update and refills
-- its expanded tiles on page flips without one. One extra pass two frames
-- later (debounced) runs after both.
local deferredTintPending = false;
local function DeferredTint()
	if deferredTintPending or not (C_Timer and C_Timer.After) then return; end
	deferredTintPending = true;
	C_Timer.After(0, function()
		C_Timer.After(0, function()
			deferredTintPending = false;
			if MerchantFrame and MerchantFrame:IsShown() then SafeTintMerchantItems(); end
		end);
	end);
end

-- Money, learned recipes and bag contents change coins, "known" and buyback
-- entries without a merchant update; re-tint while the window is open.
local merchantEventFrame = CreateFrame("Frame");
for _, event in ipairs({ "PLAYER_MONEY", "NEW_RECIPE_LEARNED", "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE" }) do
	pcall(merchantEventFrame.RegisterEvent, merchantEventFrame, event);
end
merchantEventFrame:SetScript("OnEvent", function()
	if MerchantFrame and MerchantFrame:IsShown() then DeferredTint(); end
end);

local function InstallMerchantHook()
	CreateMerchantUI();
	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
		Debug("tint pass, page", MerchantFrame and MerchantFrame.page);
		SafeTintMerchantItems();
	end);
	-- Buyback tab: clears our dimming and icons from the reused tiles.
	if MerchantFrame_UpdateBuybackInfo then hooksecurefunc("MerchantFrame_UpdateBuybackInfo", SafeTintMerchantItems); end
	-- MerchantPlus: tint a row whenever its item cell is filled (every time the
	-- scroll box reuses the row for another item while scrolling), and all
	-- rows after a refresh (search, filter or merchant update). The cell mixin
	-- is copied into each cell when MerchantPlus builds it (after login), so a
	-- hook on the mixin table reaches every cell.
	local plusList = _G.MerchantPlusItemList;
	if _G.MerchantPlusTableItemMixin and MerchantPlusTableItemMixin.Populate then
		hooksecurefunc(MerchantPlusTableItemMixin, "Populate", function(cell)
			local row = cell.GetParent and cell:GetParent();
			local ok, err = pcall(TintMerchantPlusRow, row);
			if not ok then Debug("MerchantPlus row", err); end
			-- Safety net in case the row's element data is bound after its cells.
			DeferredTint();
		end);
	end
	if plusList then
		for _, method in ipairs({ "RefreshScrollFrame", "SetSortOrder", "UpdateTableBuilderLayout" }) do
			if plusList[method] then hooksecurefunc(plusList, method, DeferredTint); end
		end
		if _G.MerchantPlusFrame then MerchantPlusFrame:HookScript("OnShow", DeferredTint); end
	end
	hooksecurefunc("MerchantFrame_Update", DeferredTint);
	if _G.EllesmereUI then
		-- Called for every row EllesmereUI fills (list and expanded tiles).
		if MerchantFrameItem_UpdateQuality then hooksecurefunc("MerchantFrameItem_UpdateQuality", DeferredTint); end
	end
end

-- Dumps the current merchant page into StickyFiltersDB.dump (written to
-- WTF\Account\<account>\SavedVariables\StickyFilters.lua on /reload or logout).
-- Dumps append, so several pages/merchants can be logged with a single
-- /reload at the end. "/stickyfilters dump clear" empties the log.
local MAX_DUMP_LINES = 5000;

local function DumpMerchantPage(note)
	if not (MerchantFrame and MerchantFrame:IsShown()) then
		print("|cff40c0ffStickyFilters|r " .. L.MSG_OPEN_MERCHANT);
		return;
	end
	db.dump = db.dump or {};
	local out = db.dump;
	local before = #out;
	out[#out + 1] = ("==== %s | npc=%s | page=%d | money=%d | note=%s"):format(date("%Y-%m-%d %H:%M:%S"), tostring((UnitName("npc"))), MerchantFrame.page, GetMoney(), note ~= "" and note or "-");
	local numItems = GetMerchantNumItems();
	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i;
		if index <= numItems then
			local info = C_MerchantFrame.GetItemInfo(index);
			local known, how = IsMerchantItemKnown(index);
			local tooExpensive = IsTooExpensive(index);
			local never, why = IsNeverUsable(index);
			out[#out + 1] = ("#%d %s id=%s known=%s(%s) never=%s(%s) proficiency=" .. tostring(GetProficiencyState(index)) .. " tooExpensive=%s usable=%s purchasable=%s canAfford=%s price=%s"):format(
				index, GetMerchantItemLink(index) or "?", tostring((GetMerchantItemID(index))), tostring(known), tostring(how),
				tostring(never), tostring(why), tostring(tooExpensive), tostring(info and info.isUsable), tostring(info and info.isPurchasable),
				-- Extra parentheses: CanAffordMerchantItem may return no value at all.
				tostring((CanAffordMerchantItem(index))), tostring(info and info.price));
			local data = GetTip(index);
			if data and data.lines then
				for n, line in ipairs(data.lines) do
					local c = line.leftColor;
					local color = c and ("%.2f/%.2f/%.2f"):format(c.r or -1, c.g or -1, c.b or -1) or "nil";
					local rc = line.rightColor;
					color = color .. " right=" .. (rc and ("%.2f/%.2f/%.2f"):format(rc.r or -1, rc.g or -1, rc.b or -1) or "nil");
					out[#out + 1] = ("    %d type=%s req=%s color=%s %s | %s"):format(n, tostring(line.type), tostring(line.requirementType), color, tostring(line.leftText), tostring(line.rightText));
				end
			end
		end
	end
	while #out > MAX_DUMP_LINES do
		table.remove(out, 1);
	end
	print(("|cff40c0ffStickyFilters|r " .. L.MSG_DUMP_ADDED):format(#out - before, #out));
end

---------------------------------------------------------------------------
-- Options panel (Options > AddOns > StickyFilters)
---------------------------------------------------------------------------

local optionsCategory;

local function RefreshAll()
	RefreshMerchant();
	RefreshTrainer();
end

-- Tooltips for the options page: { English, German }. Each explains the
-- setting and gives an example.
local TIPS = {
	plus_row = { "In MerchantPlus' list tab the whole row gets a light tint in the item's color, not only the icon.\nExample: a row with plate armor for a mage is tinted dark red.",
		"Im Listen-Reiter von MerchantPlus bekommt die ganze Zeile einen leichten Farbton in der Farbe des Items, nicht nur das Icon.\nBeispiel: eine Zeile mit Plattenr\195\188stung f\195\188r einen Magier wird dunkelrot get\195\182nt." },
	quest_colors = { "Same colors as at merchants, in the quest log and when you accept or turn in a quest.\nExample: plate armor for a mage is dark red.",
		"Gleiche Farben wie beim H\195\164ndler, im Questlog und beim Annehmen oder Abgeben einer Quest.\nBeispiel: Plattenr\195\188stung f\195\188r einen Magier ist dunkelrot." },
	quest_check = { "Green check on rewards that fit you, with the criteria from the Merchant page.\nExample: a leather chest for a rogue.",
		"Gr\195\188nes H\195\164kchen an Belohnungen, die zu dir passen, mit den Kriterien von der H\195\164ndler-Seite.\nBeispiel: eine Lederbrust f\195\188r einen Schurken." },
	quest_tooltip = { "Short gray explanation in the reward tooltip, also in addons that replace the quest window.\nExample: 'Dark red: your character can never use this'.",
		"Kurze graue Erkl\195\164rung im Tooltip der Belohnung, auch in Addons, die das Questfenster ersetzen.\nBeispiel: 'Dunkelrot: f\195\188r deinen Charakter nie benutzbar'." },
	blizz_available = { "Blizzard's own trainer filter, remembered by StickyFilters.\nExample: off = services you can learn right now are hidden.",
		"Blizzards eigener Lehrer-Filter, von StickyFilters gemerkt.\nBeispiel: aus = Eintr\195\164ge, die du sofort lernen kannst, werden ausgeblendet." },
	blizz_unavailable = { "Blizzard's own trainer filter, remembered by StickyFilters.\nExample: off = spells that need a higher level are hidden.",
		"Blizzards eigener Lehrer-Filter, von StickyFilters gemerkt.\nBeispiel: aus = Zauber, f\195\188r die du eine h\195\182here Stufe brauchst, werden ausgeblendet." },
	blizz_used = { "Blizzard's own trainer filter, remembered by StickyFilters.\nExample: off = ranks you already learned are hidden.",
		"Blizzards eigener Lehrer-Filter, von StickyFilters gemerkt.\nBeispiel: aus = bereits gelernte R\195\164nge werden ausgeblendet." },
	blizz_categorize = { "Blizzard's 'Categorize' option for profession trainers, enforced against other addons.\nExample: on = Cooking recipes are grouped by category.",
		"Blizzards Option 'Kategorisieren' bei Berufslehrern, gegen andere Addons durchgesetzt.\nBeispiel: an = Kochrezepte werden nach Kategorie gruppiert." },
	cat_known = { "Entries you already know (gray). Unchecked = dimmed.\nExample: a recipe you learned last week.",
		"Eintr\195\164ge, die du schon kennst (grau). Abgew\195\164hlt = abgedunkelt.\nBeispiel: ein Rezept, das du letzte Woche gelernt hast." },
	cat_profession = { "Recipes for a profession you have not learned (orange). Unchecked = dimmed.\nExample: a Blacksmithing plan while you are a Tailor.",
		"Rezepte f\195\188r einen Beruf, den du nicht hast (orange). Abgew\195\164hlt = abgedunkelt.\nBeispiel: ein Schmiedeplan, obwohl du Schneider bist." },
	cat_never = { "Things your character can never use (dark red): wrong class, race, armor or weapon type. Unchecked = dimmed.\nExample: plate armor for a mage.",
		"Was dein Charakter nie benutzen kann (dunkelrot): falsche Klasse, Volk, R\195\188stungs- oder Waffentyp. Abgew\195\164hlt = abgedunkelt.\nBeispiel: Plattenr\195\188stung f\195\188r einen Magier." },
	cat_skill = { "A skill is missing but can be learned (orange). Unchecked = dimmed.\nMerchant example: a sword before you trained Swords.\nTrainer example: a recipe that needs a higher profession skill.",
		"Eine Fertigkeit fehlt, ist aber lernbar (orange). Abgew\195\164hlt = abgedunkelt.\nH\195\164ndler-Beispiel: ein Schwert, bevor du Schwerter gelernt hast.\nLehrer-Beispiel: ein Rezept, das eine h\195\182here Berufsstufe braucht." },
	cat_expensive = { "Usable, but you cannot afford it (blue, crossed coin). Unchecked = dimmed.\nExample: a 20 silver bag while you have 8 silver.",
		"Benutzbar, aber zu teuer (blau, durchgestrichene M\195\188nze). Abgew\195\164hlt = abgedunkelt.\nBeispiel: eine Tasche f\195\188r 20 Silber bei 8 Silber im Geldbeutel." },
	cat_level = { "Your level is too low (red). Unchecked = dimmed.\nExample: food that requires level 25 while you are level 12.",
		"Deine Stufe ist zu niedrig (rot). Abgew\195\164hlt = abgedunkelt.\nBeispiel: Essen ab Stufe 25, du bist Stufe 12." },
	cat_other = { "Another requirement Blizzard marks as not met (red). Unchecked = dimmed.\nExample: an item that needs a reputation you do not have.",
		"Eine sonstige Bedingung, die Blizzard als unerf\195\188llt markiert (rot). Abgew\195\164hlt = abgedunkelt.\nBeispiel: ein Item, das einen Ruf braucht, den du nicht hast." },
	cat_normal = { "Everything you can use and afford right now. Unchecked = dimmed.\nExample: water and bread at the innkeeper.",
		"Alles, was du jetzt benutzen und bezahlen kannst. Abgew\195\164hlt = abgedunkelt.\nBeispiel: Wasser und Brot beim Gastwirt." },
	win_level = { "Dims entries that need more than N levels above yours.\nExample: N = 3 at level 20: level 23 stays visible, level 25 is dimmed.",
		"Dunkelt Eintr\195\164ge ab, die mehr als N Stufen \195\188ber deiner brauchen.\nBeispiel: N = 3 mit Stufe 20: Stufe 23 bleibt sichtbar, Stufe 25 wird dunkel." },
	win_skill = { "Dims profession entries that need more than N points above your skill (0 if you lack the profession).\nExample: N = 15 with Cooking 50: 65 stays visible, 75 is dimmed.",
		"Dunkelt Berufseintr\195\164ge ab, die mehr als N Punkte \195\188ber deiner Fertigkeit brauchen (0, wenn du den Beruf nicht hast).\nBeispiel: N = 15 mit Kochkunst 50: 65 bleibt sichtbar, 75 wird dunkel." },
	win_size = { "The N used by the range filter above.", "Das N f\195\188r den Bereichsfilter dar\195\188ber." },
	save_search = { "Keeps the search text after closing the window.\nExample: search 'potion', close, reopen: 'potion' is still there.",
		"Beh\195\164lt den Suchtext nach dem Schlie\195\159en.\nBeispiel: 'Trank' suchen, schlie\195\159en, wieder \195\182ffnen: 'Trank' steht noch da." },
	search_npc = { "Every NPC keeps its own search instead of one shared search.\nExample: 'arrow' at the bowyer, 'water' at the innkeeper.",
		"Jeder NPC beh\195\164lt seine eigene Suche statt einer gemeinsamen.\nBeispiel: 'Pfeil' beim Bogenmacher, 'Wasser' beim Gastwirt." },
	hint = { "Shows the small hint box next to the search and filter button.",
		"Zeigt das kleine Hinweisfenster neben Suche und Filter-Knopf." },
	fits_class = { "Green check on items made for your class.\nExample: a warlock tome at the warlock vendor.",
		"Gr\195\188nes H\195\164kchen an Items f\195\188r deine Klasse.\nBeispiel: ein Hexer-Foliant beim Hexer-H\195\164ndler." },
	fits_race = { "Green check on items made for your race.\nExample: a race-specific mount.",
		"Gr\195\188nes H\195\164kchen an Items f\195\188r dein Volk.\nBeispiel: ein volksspezifisches Reittier." },
	fits_gear = { "Green check on armor and weapons your class can use and already knows.\nExample: cloth armor for a mage.",
		"Gr\195\188nes H\195\164kchen an R\195\188stung und Waffen, die deine Klasse benutzen kann und schon beherrscht.\nBeispiel: Stoffr\195\188stung f\195\188r einen Magier." },
	fits_recipe = { "Green check on recipes for professions you have.\nExample: a Cooking recipe if you know Cooking.",
		"Gr\195\188nes H\195\164kchen an Rezepten f\195\188r deine Berufe.\nBeispiel: ein Kochrezept, wenn du Kochkunst hast." },
	icon_coin = { "Crossed-out coin (or currency icon) on everything you cannot afford.\nTurn off if another addon already draws icons there.",
		"Durchgestrichene M\195\188nze (oder W\195\164hrungssymbol) an allem, was du dir nicht leisten kannst.\nAusschalten, wenn ein anderes Addon dort schon Symbole zeichnet." },
	icon_check = { "Green check mark on items that fit you.\nTurn off if another addon already draws icons there.",
		"Gr\195\188nes H\195\164kchen an Items, die zu dir passen.\nAusschalten, wenn ein anderes Addon dort schon Symbole zeichnet." },
};
local function Tip(key)
	local t = TIPS[key];
	if not t then return nil; end
	return currentLang == "de" and t[2] or t[1];
end

local function CreateOptionsPanel()
	if optionsCategory or not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then return; end
	local BOOL = Settings.VarType.Boolean;
	local NUM = Settings.VarType.Number;
	local n = 0;

	local function Header(layout, text)
		if layout and CreateSettingsListSectionHeaderInitializer then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text));
		end
	end

	local function Checkbox(category, label, default, get, set, tooltip)
		n = n + 1;
		local setting = Settings.RegisterProxySetting(category, "STICKYFILTERS_OPT_" .. n, BOOL, label, default, get, set);
		Settings.CreateCheckbox(category, setting, tooltip);
	end

	local function Slider(category, label, default, minV, maxV, get, set, tooltip)
		n = n + 1;
		local setting = Settings.RegisterProxySetting(category, "STICKYFILTERS_OPT_" .. n, NUM, label, default, get, set);
		local options = Settings.CreateSliderOptions(minV, maxV, 1);
		if MinimalSliderWithSteppersMixin then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return "+" .. v; end);
		end
		Settings.CreateSlider(category, setting, options, tooltip);
	end

	local function ShowCategory(store, cat)
		return function() return IsShownCategory(store, cat); end,
			function(v) db[store] = db[store] or {}; db[store][cat] = v; RefreshAll(); end;
	end

	local function Flag(key, default)
		return function() if db[key] == nil then return default; end return db[key] and true or false; end,
			function(v) db[key] = v; RefreshAll(); end;
	end

	local function Window(category, kind, scope, minV, maxV)
		local label = (kind == "level" and L.LEVEL_WINDOW or L.SKILL_WINDOW):format(0):gsub("%+0", "+N");
		local flagGet, flagSet = Flag(scope .. (kind == "level" and "LevelWindow" or "SkillWindow"), true);
		Checkbox(category, label, true, flagGet, flagSet, Tip("win_" .. kind));
		Slider(category, "N", WINDOW_DEFAULTS[kind], minV, maxV,
			function() return WindowSize(kind, scope); end,
			function(v)
				db.windowSize = db.windowSize or {};
				db.windowSize[scope .. kind] = v;
				RefreshAll();
			end, Tip("win_size"));
	end

	local function SearchSettings(category, key)
		Checkbox(category, L.SAVE_SEARCH, true, function() return SearchSaved(key); end,
			function(v) db.saveSearch = db.saveSearch or {}; db.saveSearch[key] = v; end, Tip("save_search"));
		Checkbox(category, L.SEARCH_PER_NPC, true, function() return SearchPerNpc(key); end,
			function(v) db.searchPerNpc = db.searchPerNpc or {}; db.searchPerNpc[key] = v; end, Tip("search_npc"));
		Checkbox(category, L.HINT_SHOW, true, function() return HintEnabled(key); end,
			function(v) db.hintOff = db.hintOff or {}; db.hintOff[key] = not v or nil; end, Tip("hint"));
	end

	-- Main page: general
	local category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE);
	optionsCategory = category;
	Header(layout, L.LANGUAGE);
	do
		n = n + 1;
		local codes = { [0] = nil, [1] = "en", [2] = "de" };
		local setting = Settings.RegisterProxySetting(category, "STICKYFILTERS_OPT_" .. n, NUM, L.LANGUAGE, 0,
			function()
				if db.language == "en" then return 1; elseif db.language == "de" then return 2; end
				return 0;
			end,
			function(v)
				if db.language ~= codes[v] then
					db.language = codes[v];
					print("|cff40c0ffStickyFilters|r " .. L.LANG_RELOAD);
				end
			end);
		local function LanguageOptions()
			local container = Settings.CreateControlTextContainer();
			container:Add(0, L.LANG_AUTO);
			container:Add(1, "English");
			container:Add(2, "Deutsch");
			return container:GetData();
		end
		Settings.CreateDropdown(category, setting, LanguageOptions, L.LANG_TIP);
		-- A language change only takes effect after reloading the UI.
		if layout and CreateSettingsButtonInitializer and ReloadUI then
			layout:AddInitializer(CreateSettingsButtonInitializer(L.RELOAD_LABEL, L.RELOAD_BUTTON, function()
				ReloadUI();
			end, L.RELOAD_TIP, true));
		end
	end
	Header(layout, L.ICONS);
	Checkbox(category, L.OPT_ICON_COIN, true, function() return IconEnabled("coin"); end,
		function(v) db.icons = db.icons or {}; db.icons.coin = v; RefreshAll(); end, Tip("icon_coin"));
	Checkbox(category, L.OPT_ICON_CHECK, true, function() return IconEnabled("check"); end,
		function(v) db.icons = db.icons or {}; db.icons.check = v; RefreshAll(); end, Tip("icon_check"));
	if layout and CreateSettingsButtonInitializer then
		Header(layout, L.OPT_RESET_HEADER);
		layout:AddInitializer(CreateSettingsButtonInitializer(L.OPT_RESET_LABEL, L.OPT_RESET_BUTTON, function()
			SlashCmdList.STICKYFILTERS("reset");
		end, L.OPT_RESET_TOOLTIP, true));
	end

	-- Merchant page
	local mCat, mLayout = Settings.RegisterVerticalLayoutSubcategory(category, L.OPT_MERCHANT);
	Header(mLayout, L.OPT_SEC_CATEGORIES);
	for _, cat in ipairs(MERCHANT_CATS) do
		local get, set = ShowCategory("merchantShow", cat);
		Checkbox(mCat, L["CAT_" .. cat:upper()], not (cat == "known" or cat == "never"), get, set, Tip("cat_" .. cat));
	end
	Header(mLayout, L.OPT_SEC_RANGES);
	Window(mCat, "level", "merchant", 1, 60);
	Window(mCat, "skill", "merchant", 1, 300);
	Header(mLayout, L.FITS_TITLE);
	for _, key in ipairs(FITS_CRITERIA) do
		Checkbox(mCat, L["FITS_" .. key:upper()], true,
			function() return not (db.fitsMe and db.fitsMe[key] == false); end,
			function(v) db.fitsMe = db.fitsMe or {}; db.fitsMe[key] = v; RefreshAll(); end, Tip("fits_" .. key));
	end
	Header(mLayout, L.OPT_SEC_SEARCH);
	SearchSettings(mCat, "merchant");
	if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MerchantPlus") then
		Header(mLayout, "MerchantPlus");
		local plusGet, plusSet = Flag("plusRowColor", true);
		Checkbox(mCat, L.OPT_PLUS_ROW, true, plusGet, plusSet, Tip("plus_row"));
	end

	-- Trainer page
	local tCat, tLayout = Settings.RegisterVerticalLayoutSubcategory(category, L.OPT_TRAINER);
	Header(tLayout, L.OPT_SEC_BLIZZARD);
	local trainerLabels = { available = L.LBL_AVAILABLE, unavailable = L.LBL_UNAVAILABLE, used = L.LBL_USED };
	for _, filter in ipairs(TRAINER_FILTERS) do
		Checkbox(tCat, trainerLabels[filter], TRAINER_DEFAULTS[filter],
			function() return db.trainer[filter] and true or false; end,
			function(v)
				db.trainer[filter] = v;
				if ClassTrainerFrame and ClassTrainerFrame:IsShown() then ApplyTrainerFilters("options"); end
			end, Tip("blizz_" .. filter));
	end
	if HasCategorizeAPI() then
		Checkbox(tCat, L.LBL_CATEGORIZE, false,
			function()
				if db.categorize == nil then return C_Trainer.GetCategorizeTrainerUI() and true or false; end
				return db.categorize;
			end,
			function(v)
				db.categorize = v;
				if ClassTrainerFrame and ClassTrainerFrame:IsShown() then ApplyTrainerFilters("options"); end
			end, Tip("blizz_categorize"));
	end
	Header(tLayout, L.OPT_SEC_CATEGORIES);
	for _, cat in ipairs(TRAINER_CATS) do
		local get, set = ShowCategory("trainerShow", cat);
		Checkbox(tCat, L["CAT_" .. cat:upper()], cat ~= "known", get, set, Tip("cat_" .. cat));
	end
	Header(tLayout, L.OPT_SEC_RANGES);
	Window(tCat, "level", "trainer", 1, 60);
	Window(tCat, "skill", "trainer", 1, 300);
	Header(tLayout, L.OPT_SEC_SEARCH);
	SearchSettings(tCat, "trainer");

	-- Quest rewards page
	local qCat = Settings.RegisterVerticalLayoutSubcategory(category, L.OPT_QUEST);
	for _, key in ipairs({ "colors", "check", "tooltip" }) do
		Checkbox(qCat, L["OPT_QUEST_" .. key:upper()], true, function() return QuestOption(key); end,
			function(v) db.quest = db.quest or {}; db.quest[key] = v; RefreshAll(); end, Tip("quest_" .. key));
	end

	Settings.RegisterAddOnCategory(category);
end

local function OpenOptions()
	if optionsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(optionsCategory:GetID());
	end
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function Status()
	local function b(v) return v and L.ON or L.OFF; end
	print("|cff40c0ffStickyFilters|r " .. L.MSG_STATUS);
	for _, filter in ipairs(TRAINER_FILTERS) do
		print(("  %s: %s / %s"):format(L["LBL_" .. filter:upper()], b(db and db.trainer[filter]), b(GetTrainerServiceTypeFilter(filter))));
	end
	if HasCategorizeAPI() then
		local saved = db and db.categorize;
		print(("  %s: %s / %s"):format(L.LBL_CATEGORIZE, saved == nil and L.MSG_BLIZZ_DEFAULT or b(saved), b(C_Trainer.GetCategorizeTrainerUI())));
	end
	print("  " .. L.MSG_DEBUG .. ": " .. b(debugMode));
	print("  " .. L.MSG_COMMANDS .. ": /stickyfilters (/sf) [options | icons [coin|check|on|off] | reset | debug | dump [note] | dump clear]");
end

SLASH_STICKYFILTERS1 = "/stickyfilters";
SLASH_STICKYFILTERS2 = "/sf";
-- Defaults, applied once on first run (and by /stickyfilters reset).
local function ApplyFirstRunDefaults(t)
	t.initialized = true;
	t.categorize = false;
	t.trainer = { available = true, unavailable = true, used = false };
	t.defaultsVersion = 2;
	t.trainerShow = { known = false };
	t.merchantShow = { known = false, never = false };
	t.trainerLevelWindow = true;
	t.trainerSkillWindow = true;
	t.merchantLevelWindow = true;
	t.merchantSkillWindow = true;
end

SlashCmdList.STICKYFILTERS = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$");
	cmd = (cmd or ""):lower();
	if cmd == "icons" then
		db.icons = db.icons or {};
		local which = rest:lower();
		if which == "coin" or which == "check" then
			db.icons[which] = not IconEnabled(which);
		elseif which == "on" or which == "off" then
			db.icons.coin, db.icons.check = which == "on", which == "on";
		end
		local function b(v) return v and L.ON or L.OFF; end
		print(("|cff40c0ffStickyFilters|r %s: %s %s, %s %s"):format(L.ICONS, L.ICON_COIN, b(IconEnabled("coin")), L.ICON_CHECK, b(IconEnabled("check"))));
		print("  /sf icons coin | check | on | off");
		if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update(); end
		if ClassTrainerFrame and ClassTrainerFrame:IsShown() and ClassTrainerFrame_Update then ClassTrainerFrame_Update(true); end
		return;
	elseif cmd == "reset" then
		for k in pairs(StickyFiltersDB) do StickyFiltersDB[k] = nil; end
		ApplyFirstRunDefaults(StickyFiltersDB);
		ApplyTrainerFilters("reset");
		if MerchantFrame and MerchantFrame:IsShown() then MerchantFrame_Update(); end
		if ClassTrainerFrame and ClassTrainerFrame:IsShown() and ClassTrainerFrame_Update then ClassTrainerFrame_Update(true); end
		print("|cff40c0ffStickyFilters|r " .. L.RESET_DONE);
		return;
	elseif cmd == "debug" then
		debugMode = not debugMode;
		print("|cff40c0ffStickyFilters|r " .. L.MSG_DEBUG .. " " .. (debugMode and L.ON or L.OFF));
	elseif cmd == "dump" and rest:lower() == "clear" then
		db.dump = nil;
		print("|cff40c0ffStickyFilters|r " .. L.MSG_DUMP_CLEARED);
	elseif cmd == "dump" then
		DumpMerchantPage(rest or "");
	elseif cmd == "options" or cmd == "config" then
		OpenOptions();
	else
		Status();
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame");
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("TRAINER_SHOW");
frame:RegisterEvent("TRAINER_UPDATE");
frame:RegisterEvent("TRAINER_CLOSED");
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			local fresh = StickyFiltersDB == nil;
			StickyFiltersDB = StickyFiltersDB or {};
			if fresh then ApplyFirstRunDefaults(StickyFiltersDB); end
			-- Defaults v2: "Skill missing" is shown at trainers, otherwise the
			-- profession range filter would only reveal dimmed entries.
			if (StickyFiltersDB.defaultsVersion or 1) < 2 then
				StickyFiltersDB.defaultsVersion = 2;
				if StickyFiltersDB.trainerShow then StickyFiltersDB.trainerShow.skill = nil; end
			end
			local lang = StickyFiltersDB.language or (GetLocale() == "deDE" and "de" or "en");
			if lang == "de" then ApplyGerman(); end
			currentLang = lang;
			db = StickyFiltersDB;
			db.trainer = db.trainer or {};
			for filter, default in pairs(TRAINER_DEFAULTS) do
				if db.trainer[filter] == nil then
					db.trainer[filter] = default;
				end
			end
			db.merchantFilter = nil; -- merchant filter is disabled by a game rule in Forever
			for _, store in ipairs({ "merchantShow", "trainerShow" }) do
				local t = db[store];
				if t then
					if t.learnable ~= nil then t.skill, t.learnable = t.learnable, nil; end
					if t.unusable ~= nil then t.other, t.unusable = t.unusable, nil; end
				end
			end
		elseif arg1 == "Blizzard_TrainerUI" then
			InstallTrainerHook();
		end
		return;
	elseif event == "PLAYER_LOGIN" then
		InstallMerchantHook();
		InstallTrainerHook(); -- in case Blizzard_TrainerUI was already loaded
		local ok, err = pcall(CreateOptionsPanel);
		if not ok then print("|cffff4040StickyFilters " .. L.ERROR .. ":|r " .. tostring(err)); end
		return;
	end

	Debug(event, TrainerState());
	if event == "TRAINER_SHOW" then
		ApplyTrainerFilters("SHOW");
		ScheduleApply("SHOW+1");
	elseif event == "TRAINER_UPDATE" then
		ScheduleApply("UPDATE+1");
	end
end);

function BagCompanion_OnLoad(self)
	UIPanelWindows["BagCompanion"] = {
		area = "left",
		pushable = 1,
		whileDead = 1,
	}
	SetPortraitToTexture(self.portrait, "Interface\\Icons\\INV_Misc_EngGizmos_30")
	
	--Create the item slot
	self.items = {}
	for idx = 1, 24 do
		local item = CreateFrame("Button", "BagCompanion_Item" .. idx, self, "BagCompanionItemTemplate")
		item:RegisterForClicks("RightButtonUp")
		self.items[idx] = item
		if idx == 1 then
			item:SetPoint("TOPLEFT", 40, -73)
		elseif idx == 7 or idx == 13 or idx == 19 then
			item:SetPoint("TOPLEFT", self.items[idx-6], "BOTTOMLEFT", 0, -7)
		else
			item:SetPoint("TOPLEFT", self.items[idx-1], "TOPRIGHT", 12, 0)
		end
	end
	-- Create the filter buttons
	self.filters = {}
	for idx=0,5 do
		local button = CreateFrame("CheckButton", "BagCompanion_Filter" .. idx, self, "BagCompanionFilterTemplate")
		SetItemButtonTexture(button, "Interface\\ICONS\\INV_Misc_Gem_Pearl_03")
		self.filters[idx] = button
		if idx == 0 then
			button:SetPoint("BOTTOMLEFT", 40, 200)
		else
			button:SetPoint("TOPLEFT", self.filters[idx-1], "TOPRIGHT", 12, 0)
		end
		
		button.icon:SetVertexColor(GetItemQualityColor(idx))
		button:SetChecked(false)
		button.quality = idx
		button.glow:Hide()
	end
	
	self.filters[-1] = self.filters[0]
	
	--initialize to show the first page
	self.page = 1

	
	self.bagCounts = {}
	self:RegisterEvent("ADDON_LOADED")
end

local function itemNameSort(a, b)
	return a.name < b.name
end

local function itemTimeNameSort(a, b)
	--if the two items were looted at the same time
	local aTime = BagCompanion_ItemTimes[a.num]
	local bTime = BagCompanion_ItemTimes[b.num]
	if aTime == bTime then
		return a.name < b.name
	else
		return aTime >= bTime
	end
end

function BagCompanion_Update()
	local items = {}
	local nameFilter = BagCompanion.input:GetText():lower()
	
	-- Scan through the bag slots, looking for items
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 0, GetContainerNumSlots(bag) do
			local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)			
			if texture then
				local shown = true
			
				if BagCompanion.qualityFilter then
					shown = shown and BagCompanion.filters[quality]:GetChecked()
				end
			
				if #nameFilter > 0 then
					local lowerName = GetItemInfo(link):lower()
					shown = shown and string.find(lowerName, nameFilter, 1, true)
			end
			
				if shown then
				
				

					-- if found, grab the item number and store other data
					local itemNum = tonumber(link:match("|Hitem:(%d+):"))
					if not items[itemNum] then
						items[itemNum] = {
							texture = texture,
							count = count,
							quality = quality,
							name = GetItemInfo(link),
							link = link,
							num = itemNum,
						}
					else
						-- The item already exists in our table, just update the count
						items[itemNum].count = items[itemNum].count + count
					end
				end
			end
		end
	end
	
	local sortTbl = {}
	for link, entry in pairs(items) do
		table.insert(sortTbl, entry)
	end
	table.sort(sortTbl, itemTimeNameSort)
	
	--Now Update the BagCompanionFrame with the listed items(in order)
	local max = BagCompanion.page * 24
	local min = max - 23
	for idx = min, max do
		local button = BagCompanion.items[idx - min + 1]
		local entry = sortTbl[idx]
		
		if entry then
			--There is an item in this slot
			button:SetAttribute("item2", entry.name)
			button.link = entry.link
			button.icon:SetTexture(entry.texture)
			if entry.count > 1 then
				button.count:SetText(entry.count)
				button.count:Show()
			else
				button.count:Hide()
			end
			
			if entry.quality > 1 then
				button.glow:SetVertexColor(GetItemQualityColor(entry.quality))
				button.glow:Show()
			else
				button.glow:Hide()
			end
			button:Show()
		else
			button.link = nil
			button:Hide()
		end
	end
	--update page button
	if min > 1 then
		BagCompanion.prev:Enable()
	else
		BagCompanion.prev:Disable()
	end
	if max < #sortTbl then
		BagCompanion.next:Enable()
	else
		BagCompanion.next:Disable()
	end
	
	--update the status text
	if #sortTbl > 24 then
		local max =math.min(max, #sortTbl)
		local msg = string.format("Showing items %d - %d of %d", min, max, #sortTbl)
		BagCompanion.status:SetText(msg)
	else
		BagCompanion.status:SetText("Found " .. #sortTbl .. " items")
	end
end



function BagCompanion_Button_OnEnter(self, motion)
	if self.link then
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end
end
function BagCompanion_Button_OnLeave(self, motion)
	GameTooltip:Hide()
end

function BagCompanion_Filter_OnEnter(self, motion)
	GameTooltip:SetOwner(self,"ANCHOR_TOPRIGHT")
	GameTooltip:SetText(_G["ITEM_QUALITY" .. self.quality .. "_DESC"])
	GameTooltip:Show()
end

function BagCompanion_Filter_OnLeave(self, motion)
	GameTooltip:Hide()
end

function BagCompanion_Filter_OnClick(self, button)
	BagCompanion.qualityFilter = false
	for idx = 0, 5 do
		local button = BagCompanion.filters[idx]
		if button:GetChecked() then
			BagCompanion.qualityFilter = true
		end
	end
	BagCompanion.page = 1
	BagCompanion_Update()
end

function BagCompanion_NextPage(self)
	BagCompanion.page = BagCompanion.page + 1
	BagCompanion_Update(BagCompanion)
end

function BagCompanion_PrevPage(self)
	BagCompanion.page = BagCompanion.page - 1
	BagCompanion_Update(BagCompanion)
end

function BagCompanion_ScanBag(bag, initial)
	if not BagCompanion.bagCounts[bag] then
		BagCompanion.bagCounts[bag] = {}
	end
	
	local itemCounts = {}
	for slot = 0, GetContainerNumSlots(bag) do 
		local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
		
		if texture then
			local itemId  = tonumber(link:match("|Hitem:(%d+):"))
			if not itemCounts[itemId] then 
				itemCounts[itemId] = count
			else
				itemCounts[itemId] = itemCounts[itemId] + count
			end
		end
	end
	
	if initial then
		for itemId, count in pairs(itemCounts) do
			BagCompanion_ItemTimes[itemId] = BagCompanion_ItemTimes[itemId] or time()
		end
	else
		for itemId, count in pairs(itemCounts) do
			local oldCount = BagCompanion.bagCounts[bag][itemId] or 0
			if count > oldCount then
				BagCompanion_ItemTimes[itemId] = time()
			end
		end
	end
	
	BagCompanion.bagCounts[bag] = itemCounts
end

function BagCompanion_OnEvent(self, event, ...)
	if event == "ADDON_LOADED" and ... == "BagCompanion" then
		if not BagCompanion_ItemTimes then
			BagCompanion_ItemTimes = {}
		end
		for bag = 0, NUM_BAG_SLOTS do
			-- use the optional flag to skip updating times
			BagCompanion_ScanBag(bag, true)
		end
		self:UnregisterEvent("ADDON_LOADED")
		self:RegisterEvent("BAG_UPDATE")
	elseif event == "BAG_UPDATE" then
		local bag = ...
		if bag >= 0 then
			BagCompanion_ScanBag(bag)
			if BagCompanion:IsVisible() then
				BagCompanion_Update()
			end
		end
	end
end

SLASH_BAGCOMPANION1 = "/bc"
SLASH_BAGCOMPANION2 = "/bagcompanion"
SlashCmdList["BAGCOMPANION"] = function(msg, editbox)
	BagCompanion.input:SetText(msg)
	ShowUIPanel(BagCompanion)
end
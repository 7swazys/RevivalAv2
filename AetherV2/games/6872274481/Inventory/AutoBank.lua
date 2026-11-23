run(function()
	local Entity = entitylib
	local LocalPlayer = lplr
	local CollectionService = collectionService
	local ReplicatedStorage = replicatedStorage
	local AutoBank
	local Items
	local EnemyRange
	local ChestRange
	local Delay
	local NextDeposit: number = 0

	local function GetChest(LocalPosition: Vector3): BasePart?
		for _, v: Instance in CollectionService:GetTagged("personal-chest") do
			local Part: BasePart? = not v:IsA("Model") and v or (v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true))
			if Part and (Part.Position - LocalPosition).Magnitude <= ChestRange.Value then
				return Part
			end
		end
		return nil
	end

	local function EnemyNear(LocalPosition: Vector3): boolean
		for _, v: any in Entity.List do
			if v.Player and v.Targetable and v.Health > 0 and v.RootPart and (v.RootPart.Position - LocalPosition).Magnitude <= EnemyRange.Value then
				return true
			end
		end
		return false
	end

	local function Deposit()
		local Inventory: Instance? = ReplicatedStorage:FindFirstChild("Inventories")
		Inventory = Inventory and Inventory:FindFirstChild(`{LocalPlayer.Name}_personal`) or nil
		if not Inventory then
			return
		end

		for _, v: string in Items.ListEnabled do
			local Item = getItem(v)
			if Item then
				task.spawn(function()
					pcall(function()
						return bedwars.Client:GetNamespace("Inventory"):Get("ChestGiveItem"):CallServer(Inventory, Item.tool)
					end)
				end)
			end
		end
	end

	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = "AutoBank",
		Function = function(Callback: boolean)
			if Callback then
				NextDeposit = 0

				repeat
					task.wait()
				until store.matchState ~= 0 or (not AutoBank.Enabled)
				if not AutoBank.Enabled then
					return
				end

				repeat
					if Entity.isAlive and tick() >= NextDeposit and #Items.ListEnabled > 0 then
						local LocalPosition: Vector3 = Entity.character.RootPart.Position
						if EnemyNear(LocalPosition) and GetChest(LocalPosition) then
							NextDeposit = tick() + Delay.Value
							Deposit()
						end
					end
					task.wait(0.1)
				until not AutoBank.Enabled
			end
		end,
		Tooltip = "Banks your loot in your personal chest when an enemy gets close, so you don't drop it if you die"
	})

	Items = AutoBank:CreateItemPicker({
		Name = "Items",
		Multi = true,
		Items = bedwars.itemPickerList(nil, {Relevant = {'shop', 'resources'}}),
		Default = {"diamond", "emerald"},
		Tooltip = "What gets banked, add iron or gold if you want those safe too"
	})
	EnemyRange = AutoBank:CreateSlider({
		Name = "Enemy range",
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(Value: number)
			return Value <= 1 and "stud" or "studs"
		end,
		Tooltip = "How close an enemy has to get before your loot goes in the chest"
	})
	ChestRange = AutoBank:CreateSlider({
		Name = "Chest range",
		Min = 1,
		Max = 20,
		Default = 18,
		Suffix = function(Value: number)
			return Value <= 1 and "stud" or "studs"
		end,
		Tooltip = "How close to your personal chest you have to be, the server stops taking items at about 20"
	})
	Delay = AutoBank:CreateSlider({
		Name = "Delay",
		Min = 0,
		Max = 5,
		Decimal = 10,
		Default = 0.5,
		Suffix = "seconds"
	})
end)

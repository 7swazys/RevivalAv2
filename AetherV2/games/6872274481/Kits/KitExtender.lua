run(function()
	local KitExtender
	local Kaida
	local KaidaRange
	local OldMethods = {}
	local SummonRange: number?
	
	local BOOST_WINDOW = 0.6
	local HORIZONTAL = Vector3.new(1, 0, 1)
	local VERTICAL = Vector3.yAxis

	local function amplify(multiplier, mask)
		if multiplier <= 1 or not entitylib.isAlive then return end
		local character = entitylib.character.Character
		local root = entitylib.character.RootPart
		if not character or not root then return end

		local function scale(vector)
			local along = vector * mask
			return vector - along + along * multiplier
		end

		local baseline = (root.AssemblyLinearVelocity * mask).Magnitude
		local handledConstraint, handledVelocity = false, false
		local connections = {}
		local finish = tick() + BOOST_WINDOW

		local function scaleConstraint(obj)
			task.defer(function()
				if not obj.Parent then return end
				if obj:IsA('BodyVelocity') then
					obj.Velocity = scale(obj.Velocity)
					handledConstraint = true
				elseif obj:IsA('LinearVelocity') then
					if obj.VelocityConstraintMode == Enum.VelocityConstraintMode.Vector then
						obj.VectorVelocity = scale(obj.VectorVelocity)
					elseif obj.VelocityConstraintMode == Enum.VelocityConstraintMode.Line then
						obj.LineVelocity *= multiplier
					else
						obj.PlaneVelocity *= multiplier
					end
					handledConstraint = true
				end
			end)
		end

		table.insert(connections, character.DescendantAdded:Connect(scaleConstraint))
		table.insert(connections, runService.Heartbeat:Connect(function()
			if tick() > finish or not root.Parent then
				for _, connection in connections do connection:Disconnect() end
				table.clear(connections)
				return
			end
			if handledConstraint or handledVelocity then return end
			local velocity = root.AssemblyLinearVelocity
			local speed = (velocity * mask).Magnitude
			if speed > baseline + 8 and (mask ~= VERTICAL or velocity.Y > 0) then
				handledVelocity = true
				root.AssemblyLinearVelocity = scale(velocity)
			end
		end))
	end

	local Boosts = {
	    {
	        Name = "Jade Hammer",
	        Kit = "jade",
	        Controller = "JadeHammerController",
	        Method = "useJadeHammer",
	        Tooltip = 'Extends how far the Jade Hammer launches you',
	        Hook = function(Entry, Old)
	            return function(self, ...)
	                local Jumped: boolean = bedwars.AbilityController:canUseAbility("jade_hammer_jump", {disableBlockedAbilityAlert = true})
	                if Entry.Toggle.Enabled and Jumped and store.equippedKit == "jade" then
	                    amplify(Entry.Multiplier.Value, VERTICAL)
	                end
	                return Old(self, ...)
	            end
	        end
	    },
	    {
	        Name = "Void Regent Dash",
	        Kit = "regent",
	        Controller = "VoidAxeController",
	        Method = "useVoidAxe",
	        Tooltip = "Extends how far the Void Regent axe dash launches you",
	        Hook = function(Entry, Old)
	            return function(self, ...)
	                local Dashed: boolean = bedwars.AbilityController:canUseAbility("void_axe_jump", {disableBlockedAbilityAlert = true})
	                if Entry.Toggle.Enabled and Dashed and store.equippedKit == "regent" then
	                    amplify(Entry.Multiplier.Value, HORIZONTAL)
	                end
	                return Old(self, ...)
	            end
	        end
	    },
	    {
	        Name = "Yamini Pounce",
	        Kit = "cat",
	        Controller = "CatController",
	        Method = "leap",
	        Tooltip = "Extends how far the Yamini pounce launches you",
	        Hook = function(Entry, Old)
	            return function(self, Character: Model?, ...)
	                if Entry.Toggle.Enabled and store.equippedKit == "cat" and (Character == nil or Character == lplr.Character) then
	                    amplify(Entry.Multiplier.Value, HORIZONTAL)
	                end
	                return Old(self, Character, ...)
	            end
	        end
	    },
	    {
	        Name = "Yamini Wall Kick",
	        Kit = "cat",
	        Controller = "CatController",
	        Method = "dismountWall",
	        Tooltip = "Extends how high dropping off a climbed wall throws you",
	        Hook = function(Entry, Old)
	            return function(self, ...)
	                if Entry.Toggle.Enabled and store.equippedKit == "cat" then
	                    amplify(Entry.Multiplier.Value, VERTICAL)
	                end
	                return Old(self, ...)
	            end
	        end
	    },
	    {
	        Name = "Yuzi Dash",
	        Kit = "dasher",
	        Controller = "DaoController",
	        Method = "dashForward",
	        Tooltip = "Extends how far the yuzi dash launches you",
	        Hook = function(Entry, Old)
	            return function(self, ...)
	                if Entry.Toggle.Enabled and store.equippedKit == "dasher" then
	                    amplify(Entry.Multiplier.Value, HORIZONTAL)
	                end
	                return Old(self, ...)
	            end
	        end
	    },
	    {
	        Name = "Xurot Wing Flap",
	        Kit = "void_dragon",
	        Controller = "VoidDragonController",
	        Method = "flapWings",
	        Tooltip = "Extends how high each wing flap throws you",
	        Hook = function(Entry, Old)
	            return function(self, ...)
	                if Entry.Toggle.Enabled and store.equippedKit == "void_dragon" then
	                    amplify(Entry.Multiplier.Value, VERTICAL)
	                end
	                return Old(self, ...)
	            end
	        end
	    }
	}
	
	KitExtender = vape.Categories.Kits:CreateModule({
	    Name = "KitExtender",
	    Category = "Ability",
	    Function = function(Callback: boolean)
	        if Callback then
	            for i: number, v: any in Boosts do
	                local Controller = bedwars[v.Controller]
	                if Controller and Controller[v.Method] then
	                    OldMethods[i] = Controller[v.Method]
	                    Controller[v.Method] = v.Hook(v, OldMethods[i])
	                end
	            end
	
	            if Kaida.Enabled then
	                local Success, Balance = pcall(function()
	                    return require(replicatedStorage.TS.games.bedwars.kit.kits.summoner["summoner-kit-balance"]).SummonerKitBalance
	                end)
	                if Success and Balance then
	                    SummonRange = SummonRange or Balance.SPELL_CAST_RANGE
	                    Balance.SPELL_CAST_RANGE = math.max(KaidaRange.Value, SummonRange)
	                end
	            end
	        else
	            for i: number, v: any in Boosts do
	                local Controller = bedwars[v.Controller]
	                if Controller and OldMethods[i] then
	                    Controller[v.Method] = OldMethods[i]
	                end
	            end
	            table.clear(OldMethods)
	
	            if SummonRange then
	                local Success, Balance = pcall(function()
	                    return require(replicatedStorage.TS.games.bedwars.kit.kits.summoner["summoner-kit-balance"]).SummonerKitBalance
	                end)
	                if Success and Balance then
	                    Balance.SPELL_CAST_RANGE = SummonRange
	                end
	                SummonRange = nil
	            end
	        end
	    end,
	    Tooltip = "Extends multiple kit abilities"
	})
	
	for _, v: any in Boosts do
	    v.Toggle = KitExtender:CreateToggle({
	        Name = v.Name,
	        Function = function(Callback: boolean)
	            if v.Multiplier and v.Multiplier.Object then
	                v.Multiplier.Object.Visible = Callback
	            end
	        end,
	        Tooltip = v.Tooltip
	    })
	    v.Multiplier = KitExtender:CreateSlider({
	        Name = `{v.Name} multiplier`,
	        Min = 1,
	        Max = 5,
	        Decimal = 10,
	        Default = 2,
	        Darker = true,
	        Visible = false,
	        Suffix = "x"
	    })
	end
	Kaida = KitExtender:CreateGroup({
	    Name = "Kaida Summon Range",
	    Function = function(Callback: boolean)
	        if KitExtender.Enabled then
	            KitExtender:Toggle()
	            KitExtender:Toggle()
	        end
	    end,
	    Tooltip = 'Lets the summon circle land further away'
	})
	KaidaRange = Kaida:CreateSlider({
	    Name = "Range",
	    Min = 45,
	    Max = 120,
	    Function = function(Val: number)
	        if not KitExtender.Enabled or not SummonRange then
	            return
	        end
	        local Success, Balance = pcall(function()
	            return require(replicatedStorage.TS.games.bedwars.kit.kits.summoner["summoner-kit-balance"]).SummonerKitBalance
	        end)
	        if Success and Balance then
	            Balance.SPELL_CAST_RANGE = math.max(Val, SummonRange)
	        end
	    end,
	    Default = 75,
	    Darker = true,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

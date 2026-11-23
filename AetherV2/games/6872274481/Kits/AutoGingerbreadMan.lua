run(function()
	local function CanPlace() return not bedwars.BlockPlacementController.disabled and not isCasting() end
	local Entity = entitylib
	local GetHotbar = getHotbar
	local GetItem = getItem
	local GetPlacedBlock = getPlacedBlock
	local HotbarSwitch = hotbarSwitch
	local LocalPlayer = lplr
	local RoundPosition = roundPos
	local RunService = runService
	local Store = store
	local SwitchItem = switchItem
	local AutoGingerbread
	local Range
	local Delay
	local Break
	local Place
	local PlaceDelay
	local Jump
	local Switch
	local OwnOnly
	local SuccessfulOnly

	local Old
	local NextPlace: number = 0

	AutoGingerbread = kits:CreateModule({
		Name = "AutoGingerbreadMan",
		Function = function(Callback: boolean)
			if Callback then
				NextPlace = 0
				AutoGingerbread:Clean(RunService.Heartbeat:Connect(function()
					if Place.Enabled and Entity.isAlive and Store.equippedKit == "gingerbread_man" and tick() >= NextPlace and CanPlace() and GetItem("gumdrop_bounce_pad") then
						local Position: Vector3 = RoundPosition(Entity.character.RootPart.Position - Vector3.new(0, Entity.character.HipHeight + 1.5, 0))
						if not GetPlacedBlock(Position) then
							NextPlace = tick() + math.max(PlaceDelay.Value, 1 / bedwars.SharedConstants.BLOCK_PLACE_CPS)
							bedwars.placeBlock(Position, "gumdrop_bounce_pad")
						end
					end
				end))

				Old = bedwars.LaunchPadController.attemptLaunch
				bedwars.LaunchPadController.attemptLaunch = function(self, Block, ...)
					local LastLaunch = self and self.lastLaunch or 0
					local Call = Old(self, Block, ...)

					if not SuccessfulOnly.Enabled or self and self.lastLaunch and self.lastLaunch ~= LastLaunch then
						if Break.Enabled and Entity.isAlive and Store.equippedKit == "gingerbread_man" and Block and Block:IsA("BasePart") and (not OwnOnly.Enabled or Block:GetAttribute("PlacedByUserId") == LocalPlayer.UserId) and (Block.Position - Entity.character.RootPart.Position).Magnitude <= Range.Value then
							task.delay(Delay.Value, function()
								if AutoGingerbread.Enabled and Block.Parent then
									if Switch.Enabled then
										local ItemMeta = bedwars.ItemMeta[Block.Name]
										local BreakType = ItemMeta and ItemMeta.block and ItemMeta.block.breakType
										local Tool = BreakType and Store.tools[BreakType] or Store.tools.sword
										local Slot = Tool and GetHotbar(Tool.tool)
										if Slot then
											HotbarSwitch(Slot)
										elseif Tool then
											SwitchItem(Tool.tool)
										end
									end
									bedwars.breakBlock(Block, false, nil, nil, Switch.Enabled)
								end
							end)
						end

						if Jump.Enabled and Entity.isAlive then
							Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
					return Call
				end
			else
				bedwars.LaunchPadController.attemptLaunch = Old
			end
		end,
		Tooltip = 'Handles Gingerbread Man launch pads for you'
	})

	Place = AutoGingerbread:CreateGroup({
		Name = "Place pads",
		Tooltip = 'Keeps a bounce pad under you',
		Default = true
	})
	PlaceDelay = Place:CreateSlider({
		Name = "Place delay",
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Darker = true,
		Suffix = function(Val: number)
			return Val == 1 and "sec" or "secs"
		end
	})
	Break = AutoGingerbread:CreateGroup({
		Name = "Break launch pad",
		Function = function(Callback: boolean)
			if Range then
			end
		end,
		Default = true
	})
	Jump = AutoGingerbread:CreateToggle({Name = "Jump after launch"})

	Switch = Break:CreateToggle({
		Name = "Legit switch",
		Darker = true
	})
	OwnOnly = Break:CreateToggle({
		Name = "Own pads only",
		Default = true,
		Darker = true
	})
	SuccessfulOnly = AutoGingerbread:CreateToggle({
		Name = "Successful launch only",
		Default = true
	})
	Range = Break:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 30,
		Default = 30,
		Darker = true,
		Suffix = function(Val: number)
			return Val <= 1 and "stud" or "studs"
		end
	})
	Delay = Break:CreateSlider({
		Name = "Break delay",
		Min = 0,
		Max = 1,
		Default = 0.05,
		Decimal = 100,
		Darker = true,
		Suffix = function(Val: number)
			return Val == 1 and "sec" or "secs"
		end
	})
end)

run(function()
	local TargetInfo = targetinfo
	local TargetInfoOverlay = vape.Categories["Target Info"]
	if not (TargetInfo and TargetInfo.Object and TargetInfo.TargetChanged and TargetInfoOverlay and TargetInfoOverlay.CreateToggle) then
	    return
	end
	local ShowInventory
	local Card: Frame = TargetInfo.Object
	local Row: Frame?
	local Tiles: {Frame} = {}
	local Lifted: {[Frame]: boolean} = {}
	local TileSize: number = 30
	local TilePadding: number = 5
	local Columns: number = 7
	local Lift: number = 4
	local Looping: boolean = false
	
	local function CreateRow()
	    Row = Instance.new("Frame")
	    Row.Name = "Inventory"
	    Row.BackgroundTransparency = 1
	    Row.Position = UDim2.new(0, 0, 1, TilePadding + Lift)
	    Row.Size = UDim2.fromScale(1, 0)
	    Row.Visible = false
	    Row.Parent = Card
	    local Grid: UIGridLayout = Instance.new("UIGridLayout")
	    Grid.CellPadding = UDim2.fromOffset(TilePadding, TilePadding)
	    Grid.CellSize = UDim2.fromOffset(TileSize, TileSize)
	    Grid.SortOrder = Enum.SortOrder.LayoutOrder
	    Grid.Parent = Row
	end
	
	local function CreateTile(Index: number): Frame
	    local Cell: Frame = Instance.new("Frame")
	    Cell.Name = `Slot{Index}`
	    Cell.BackgroundTransparency = 1
	    Cell.LayoutOrder = Index
	    Cell.Parent = Row
	    local Tile: Frame = Instance.new("Frame")
	    Tile.Name = "Tile"
	    Tile.BackgroundColor3 = Color3.fromRGB(29, 36, 46)
	    Tile.BorderMode = Enum.BorderMode.Inset
	    Tile.BorderSizePixel = 1
	    Tile.Size = UDim2.fromScale(1, 1)
	    Tile.Parent = Cell
	    local Icon: ImageLabel = Instance.new("ImageLabel")
	    Icon.Name = "Icon"
	    Icon.AnchorPoint = Vector2.new(0.5, 0)
	    Icon.BackgroundTransparency = 1
	    Icon.Position = UDim2.fromScale(0.5, 0.15)
	    Icon.Size = UDim2.fromScale(0.8, 0.8)
	    Icon.Parent = Tile
	    local Amount: TextLabel = Instance.new("TextLabel")
	    Amount.Name = "Amount"
	    Amount.AnchorPoint = Vector2.new(1, 1)
	    Amount.BackgroundTransparency = 1
	    Amount.FontFace = Font.fromName("RobotoMono", Enum.FontWeight.Bold)
	    Amount.Position = UDim2.new(1, -2, 1, 0)
	    Amount.Size = UDim2.new(1, -2, 0, 12)
	    Amount.Text = ""
	    Amount.TextColor3 = Color3.new(1, 1, 1)
	    Amount.TextSize = 11
	    Amount.TextStrokeTransparency = 0.5
	    Amount.TextXAlignment = Enum.TextXAlignment.Right
	    Amount.ZIndex = 2
	    Amount.Parent = Tile
	    Tiles[Index] = Cell
	
	    return Cell
	end
	
	local function SetTile(Cell: Frame, Item, Held: boolean)
	    local Tile: Frame = Cell.Tile
	    Cell.Visible = true
	    Tile.Icon.Image = bedwars.getIcon(Item, true)
	    Tile.Amount.Text = (Item.amount or 1) > 1 and tostring(Item.amount) or ""
	    Tile.BackgroundTransparency = Held and 0.2 or 0.4
	    Tile.BorderColor3 = Held and Color3.new(1, 1, 1) or Color3.fromRGB(114, 126, 172)
	
	    if Lifted[Cell] ~= Held then
	        Lifted[Cell] = Held
	        tween:Tween(Tile, TweenInfo.new(0.12), {
	            Position = UDim2.fromOffset(0, Held and -Lift or 0)
	        })
	    end
	end
	
	local function GetItems(Inventory)
	    local Worn: {[Instance]: boolean} = {}
	    local Items = {}
	
	    for _, v: any in Inventory.armor do
	        if type(v) == "table" and v.tool then
	            Worn[v.tool] = true
	        end
	    end
	
	    for _, v: any in Inventory.items do
	        if v.tool and not Worn[v.tool] then
	            table.insert(Items, v)
	        end
	    end
	
	    table.sort(Items, function(First, Second): boolean
	        local FirstTime: number = First.addedToBackpackTime or 0
	        local SecondTime: number = Second.addedToBackpackTime or 0
	        if FirstTime ~= SecondTime then
	            return FirstTime < SecondTime
	        end
	
	        return First.itemType < Second.itemType
	    end)
	
	    return Items
	end
	
	local function Refresh(Target)
	    if not Row or not Card.Visible or not TargetInfoOverlay.Object.Visible then
	        return
	    end
	
	    local Player: Player? = Target and Target.Player or nil
	    local Inventory = Player and bedwars.getInventory and bedwars.getInventory(Player) or nil
	    local Items = Inventory and GetItems(Inventory) or {}
	    local Hand = Inventory and Inventory.hand or nil
	
	    for i: number, v: any in Items do
	        SetTile(Tiles[i] or CreateTile(i), v, Hand ~= nil and v.tool == Hand.tool)
	    end
	
	    for i: number = #Items + 1, #Tiles do
	        Tiles[i].Visible = false
	    end
	
	    local Rows: number = math.ceil(#Items / Columns)
	    Row.Size = UDim2.new(1, 0, 0, math.max(Rows * (TileSize + TilePadding) - TilePadding, 0))
	    Row.Visible = #Items > 0
	end
	
	local function Clear()
	    if Row then
	        Row:Destroy()
	        Row = nil
	    end
	
	    table.clear(Tiles)
	    table.clear(Lifted)
	end
	
	ShowInventory = TargetInfoOverlay:CreateToggle({
	    Name = "Show Inventory",
	    Function = function(Callback: boolean)
	        if not Callback then
	            Clear()
	            return
	        end
	
	        if not Row then
	            CreateRow()
	        end
	
	        if Looping then
	            return
	        end
	        Looping = true
	
	        task.spawn(function()
	            repeat
	                Refresh(TargetInfo.LastTarget)
	                task.wait(0.1)
	            until not ShowInventory.Enabled or vape.Loaded == nil
	
	            Looping = false
	        end)
	    end,
	    Tooltip = 'Shows the target\'s inventory under the card'
	})
	vape:Clean(TargetInfo.TargetChanged:Connect(function(Target)
	    Refresh(Target)
	end))
end)

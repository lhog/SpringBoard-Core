CommandWindow = LCS.class{}

function CommandWindow:init()
    self.commandsPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 0,
        y = 30,
        right = 0,
        bottom = 0,
        autosize = false,
        resizeItems = false,
        centerItems = false,
    }
    self.list = List()
    self.list.CompareItems = function(obj, id1, id2)
        return id1 - id2
    end
    self.window = Window:New {
        parent = screen0,
        caption = "Command stack",
        right = 501 + 376,
        bottom = 0,
        resizable = false,
        draggable = false,
        width = 375,
        height = 200,
        children = {
            self.list.ctrl,
        }
    }
    self.count = 0
    self.removedCount = 0
    self.undoCount = 0
end

function CommandWindow:PushCommand(display)
    self.count = self.count + 1
    local id = self.count
    Log.Debug("do", id)
    local lblVariableName = Label:New {
        caption = tostring(id) .. " " .. display,
        y = 0,
        height= 45,
        x = 0,
        width = 350,
        align = 'center',
        id = id,
        valign = 'center',
    }
    self.list:AddRow({lblVariableName}, id)
end

function CommandWindow:UndoCommand()
    Log.Debug("undo", self.count - self.undoCount)
    local row = self.list:GetRowItems(self.count - self.undoCount)
    local lbl = row[1]
    lbl._oldcaption = lbl.caption
    lbl:SetCaption("\255\100\100\100" .. lbl.caption .. "\b")
    lbl:Invalidate()
    self.commandsPanel:Invalidate()

    self.undoCount = self.undoCount + 1
end

function CommandWindow:RedoCommand()
    Log.Debug("redo", self.count - self.undoCount + 1)
    local row = self.list:GetRowItems(self.count - self.undoCount + 1)
    local lbl = row[1]
    lbl:SetCaption(lbl._oldcaption)
    lbl:Invalidate()
    self.commandsPanel:Invalidate()
    lbl._oldcaption = nil

    self.undoCount = self.undoCount - 1
end

function CommandWindow:RemoveFirstUndo()
    Log.Debug("remundo", self.removedCount + 1)
    self.removedCount = self.removedCount + 1
    self.list:RemoveRow(self.removedCount)
end

function CommandWindow:RemoveFirstRedo()
    Log.Debug(LOG.DEBUG, "remredo")
    self.list:RemoveRow(self.count)
    self.count = self.count - 1
    self.undoCount= self.undoCount - 1
end

function CommandWindow:ClearUndoStack()
    Log.Debug("clearundostack")
    while self.removedCount ~= self.count do
        self:RemoveFirstUndo()
    end
    Log.Debug("clearundostackend")
end

function CommandWindow:ClearRedoStack()
    Log.Debug("clearredostack")
    while self.undoCount ~= 0 do
        self:RemoveFirstRedo()
    end
    Log.Debug("clearredostackend")
end

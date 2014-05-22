MetaPanel = AbstractMainWindowPanel:extends{}

function MetaPanel:init()
	self:super("init")
    local btnTriggers = Button:New {
        caption = '',
        height = 80,
        width = 80,
        tooltip = "Trigger settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "applications-system.png", 
				height = 40, 
				width = 40,
				x = 10,
            },
			Label:New {
				caption = "Triggers",
				y = 40,
				x = 5,
			},
        },
    }
    local btnVariableSettings = Button:New {
        height = 80,
        width = 80,
        caption = '',
        tooltip = "Variable settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "format-text-bold.png", 
				height = 40, 
				width = 40,
                margin = {0, 0, 0, 0},
				x = 10,
            },
			Label:New {
				caption = "Variables",
				y = 40,
			},
        },
    }

	self.control:AddChild(
		Button:New {
			height = 80,
			width = 80,
			caption = '',
			OnClick = {
				function()
					SCEN_EDIT.stateManager:SetState(AddRectState())
				end
			},
			tooltip = "Add a rectangle area", 
			children = {
				Image:New {                                 
					file=SCEN_EDIT_IMG_DIR .. "view-fullscreen.png", 
					height = 40, 
					width = 40,
					margin = {0, 0, 0, 0},
					x = 10,
				},
				Label:New {
					caption = "Area",
					y = 40,
					x = 14,
				},
			},
		}
	)
	self.control:AddChild(Chili.LayoutPanel:New {
			height = btnTriggers.height,
			width = btnTriggers.width,
			children = {btnTriggers},
			padding = {0, 0, 0, 0},
			margin = {0, 0, 0, 0},
			itemMargin = {0, 0, 0, 0},
			itemPadding = {0, 0, 0, 0},
		}
	)
	self.control:AddChild(Chili.LayoutPanel:New {
			height = btnVariableSettings.height,
			width = btnVariableSettings.width,
			children = {btnVariableSettings},
			padding = {0, 0, 0, 0},
			margin = {0, 0, 0, 0},
			itemMargin = {0, 0, 0, 0},
			itemPadding = {0, 0, 0, 0},
		}
	)
	btnTriggers.OnClick = {
        function () 
            btnTriggers._toggle = TriggersWindow()
            btnTriggers.parent.disableChildrenHitTest = true
            btnTriggers.parent:Invalidate()
            table.insert(btnTriggers._toggle.window.OnDispose, 
                function()
                    if btnTriggers and btnTriggers.parent then
                        btnTriggers.parent.disableChildrenHitTest = false
                        btnTriggers.parent:Invalidate()
                    end
                end
            )
        end
    }

    btnVariableSettings.OnClick = {
        function()
            btnVariableSettings._toggle = VariableSettingsWindow()
            btnVariableSettings.parent.disableChildrenHitTest = true
            btnVariableSettings.parent:Invalidate()
            table.insert(btnVariableSettings._toggle.window.OnDispose, 
                function()
                    if btnVariableSettings and btnVariableSettings.parent then
                        btnVariableSettings.parent.disableChildrenHitTest = false
                        btnVariableSettings.parent:Invalidate()
                    end
                end
            )
        end
    }
end
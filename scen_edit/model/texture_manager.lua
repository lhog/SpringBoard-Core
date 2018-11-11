TextureManager = Observable:extends{}

local function CreateTextureObj(sizex, sizey, texOptions, fbo)
	local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0

    local newTexture = gl.CreateTexture(sizex, sizey, texOptions)
	local newFBO = fbo and gl.CreateFBO({
		color0 = newTexture,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	})
	return {texture = newTexture, fbo = newFBO}
end

local function DestroyTextureObj(texObject)
	if texObject and type(texObject) == "array" then
		if texObject.fbo then
			gl.DeleteFBO(texObject.brdfFBO)
		end
		if texObject.texture then
			gl.DeleteTexture(self.brdfTexture)
		end
	else
		local traceBack = (debug and debug.traceback()) or "unknown traceback"
		Log.Error("Attempt to call DestroyTextureObj() with invalid texObject object: at " .. traceBack)
	end
end

function TextureManager:init()
    self:super('init')
    self.TEXTURE_SIZE = 1024

    self.mapFBOTextures = {}
    self.oldMapFBOTextures = {}
    self.oldShadingTextures = {}
    self.stack = {}
    self.stackSize = 0
    self.tmps = {}

    self.cachedTextures = {}
    self.cachedTexturesMapping = {}
    self.maxCache = 20

    self.shadingTextures = {}
    self.shadingTextureDefs = {
        specular = {
            engineName = "$ssmf_specular",
        },
        splat_distr = {
            engineName = "$ssmf_splat_distr",
            alpha = true,
        },
        -- splat_detail = {
        --     engineName = "$ssmf_splat_detail",
        -- },
        splat_normals0 = {
            engineName = "$ssmf_splat_normals:0",
            _setParams = {"$ssmf_splat_normals", 0},
            alpha = true,
        },
        splat_normals1 = {
            engineName = "$ssmf_splat_normals:1",
            _setParams = {"$ssmf_splat_normals", 1},
            alpha = true,
        },
        splat_normals2 = {
            engineName = "$ssmf_splat_normals:2",
            _setParams = {"$ssmf_splat_normals", 2},
            alpha = true,
        },
        splat_normals3 = {
            engineName = "$ssmf_splat_normals:3",
            _setParams = {"$ssmf_splat_normals", 3},
            alpha = true,
        },
    }
    self.materialTextures = {
        diffuse = {
            suffix = "_diffuse",
            enabled = true,
        },
        specular = {
            suffix = "_specular",
            enabled = true,
        },
        normal = {
            suffix = "_normal",
            enabled = true,
        },
        emissive = {
            suffix = "_emissive",
            enabled = true,
        },
        height = {
            suffix = "_height",
            enabled = false,
        },
        glow = {
            suffix = "_glow",
            enabled = false,
        }
    }
    self.shadingTextureNames = {}
    for name, texDef in pairs(self.shadingTextureDefs) do
        texDef.name = name
        table.insert(self.shadingTextureNames, name)
    end

    SB.delayGL(function()
        self:generateMapTextures()
    end)
end

-- Texture def fields:
-- name: string
-- engineName: string
-- enabled: bool
function TextureManager:GetShadingTextureDefs()
    return self.shadingTextureDefs
end

function TextureManager:createMapTexture(notFBO, notMipMap)
    local min_filter
    if notMipMap then
        min_filter = GL.LINEAR
    else
        min_filter = GL.LINEAR --GL.LINEAR_MIPMAP_NEAREST
    end

	return CreateTextureObj(self.TEXTURE_SIZE, self.TEXTURE_SIZE, {
        border = false,
        min_filter = min_filter,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
    }, notFBO, notMipMap)
end

function TextureManager:SetupShader()
    local vertProg = VFS.LoadFile("shaders/SMFVertProg.glsl")
    local fragProg = VFS.LoadFile("shaders/SMFFragProg.glsl")
    TextureManager.mapShader = Shaders.Compile({
        vertex = [[
void main(void)
{
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

}
]],
        fragment = [[
uniform ivec2 texSquare;

varying vec2 diffuseTexCoords;
uniform sampler2D diffuseTex;
void main(void)
{
    vec2 diffTexCoords = diffuseTexCoords;
    vec4 diffuseCol = texture2D(diffuseTex, diffTexCoords);
    gl_FragColor = diffuseCol;
}
]]
    }, "TextureManager:SetupShader")
    Spring.SetMapShader(TextureManager.mapShader, TextureManager.mapShader)
end

function TextureManager:generateMapTextures()
    Log.Debug("Generating textures...")
    local oldMapTexture = self:createMapTexture(true, true)

    for i = 0, math.floor(Game.mapSizeX / self.TEXTURE_SIZE) do
        self.mapFBOTextures[i] = {}
        for j = 0, math.floor(Game.mapSizeZ / self.TEXTURE_SIZE) do
            local mapTexture = self:createMapTexture()

            Spring.GetMapSquareTexture(i, j, 0, oldMapTexture.texture)
            self:Blit(oldMapTexture.texture, mapTexture)
            --gl.GenerateMipmap(mapTexture)

            self.mapFBOTextures[i][j] = {
                texture = mapTexture,
                dirty = false,
            }
            Spring.SetMapSquareTexture(i, j, mapTexture.texture)
        end
    end

    local smftTexAniso, ssmfTexAniso = Spring.GetConfigInt("SMFTexAniso"), Spring.GetConfigInt("SSMFTexAniso")

    self.shadingTextures = {}
    for name, texDef in pairs(self.shadingTextureDefs) do
        texDef.enabled = false

        local engineName = texDef.engineName
        Log.Notice("Engine texture: " .. tostring(name))
        local success
        if texDef._setParams then
            success = Spring.SetMapShadingTexture(texDef._setParams[1], "", texDef._setParams[2])
        else
            success = Spring.SetMapShadingTexture(engineName, "")
        end
        if not success then
            Log.Error("Failed to reset texture: " .. tostring(name) .. ", engine name: " .. tostring(engineName))
        end
        --local tex = self:createMapTexture()
        local sizeX, sizeZ--[[ = Game.mapSizeX/2, Game.mapSizeZ/2]]
        local texInfo = gl.TextureInfo(engineName)
        if texInfo and texInfo.xsize > 0 then
            sizeX, sizeZ = texInfo.xsize, texInfo.ysize
        end

        if sizeX and sizeZ then
            local texOpt

            local min_filter = GL.LINEAR
            -- if name == "splat_distr" then
            --    min_filter = GL.LINEAR_MIPMAP_NEAREST
            -- end

            if engineName:find("splat_normals") then
                texOpt = {
                    border = false,
                    min_filter = GL.LINEAR_MIPMAP_NEAREST,
                    mag_filter = GL.LINEAR,
                    wrap_s = GL.REPEAT,
                    wrap_t = GL.REPEAT,
                    aniso = ssmfTexAniso,
                    fbo = true,
                }
                --gl.GenerateMipmap(tex)
            else
                texOpt = {
                    border = false,
                    min_filter = min_filter,
                    mag_filter = GL.LINEAR,
                    wrap_s = GL.CLAMP_TO_EDGE,
                    wrap_t = GL.CLAMP_TO_EDGE,
                    fbo = true,
                }
            end

			local texFboObj = CreateTextureObj(sizeX, sizeZ, texOpt, true)
    --         local engineTex = gl.Texture()
            self:Blit(engineName, texFboObj)

            if engineName:find("splat_normals") then
                gl.GenerateMipmap(texFboObj.texture)
            end

            self.shadingTextures[name] = {
                texture = texFboObj,
                dirty = true,
            }

            if texDef._setParams then
                success = Spring.SetMapShadingTexture(texDef._setParams[1], texFboObj.texture, texDef._setParams[2]) --what does 3rd param do?
            else
                success = Spring.SetMapShadingTexture(engineName, texFboObj.texture)
            end
            if not success then
                Log.Error("Failed to set new texture: " .. tostring(name) .. ", engine name: " .. tostring(engineName))
            end

            texDef.enabled = true
        end
    end

--      self:SetupShader()
end

local grayscaleShader
local function _GetDNTSShader()
    if not grayscaleShader then
        grayscaleShader = Shaders.Compile({
            fragment = [[
    uniform sampler2D normalTex;
    uniform sampler2D diffuseTex;
    void main(void)
    {
        vec4 normalColor = texture2D(normalTex, gl_TexCoord[0].st);
        vec4 diffuseColor = texture2D(diffuseTex, gl_TexCoord[0].st);

        float grayscale =  dot(diffuseColor.rgb, float3(0.3, 0.59, 0.11));
        gl_FragColor = vec4(normalColor.rgb, grayscale);
    }
    ]]
        }, "TextureManager:_GetDNTSShader")
        return grayscaleShader
    end
    return grayscaleShader
end

function TextureManager:SetDNTS(dntsIndex, material)
    local texObj = self.shadingTextures["splat_normals" .. tostring(dntsIndex)]
    local texture = texObj.texture
    local shader = _GetDNTSShader()

    gl.UseShader(shader)
    gl.Blending("disable")
    gl.Texture(0, material.normal)
    gl.Texture(1, material.diffuse)
    gl.RenderToTexture(texture, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)

    gl.GenerateMipmap(texture)
    texObj.dirty = true
end

function TextureManager:GetTMPs(num)
    for i = #self.tmps + 1, num do
        table.insert(self.tmps, self:createMapTexture())
    end
    local tmps = {}
    for i = 1, num do
        table.insert(tmps, self.tmps[i])
    end
    return tmps
end

function TextureManager:resetMapTextures()
    for i, v in pairs(self.mapFBOTextures) do
        for j, textureObj in pairs(v) do
            gl.DeleteTexture(textureObj.texture)
            Spring.SetMapSquareTexture(i, j, "")
        end
    end
    self.mapFBOTextures = {}
end

function TextureManager:getMapTexture(x, z)
    local i, j = math.floor(x / self.TEXTURE_SIZE), math.floor(z / self.TEXTURE_SIZE)
    return self.mapFBOTextures[i][j]
end

function TextureManager:backupMapShadingTexture(name)
    self:getOldShadingTexture(name)
end

function TextureManager:getOldShadingTexture(name)
    if self.oldShadingTextures[name] == nil then
        local texObj = self.shadingTextures[name]
        local texture = texObj.texture
        local texInfo = gl.TextureInfo(texture)
        local texSizeX, texSizeZ = texInfo.xsize, texInfo.ysize

		local oldTextureObj = CreateTextureObj(texSizeX, texSizeZ, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
        }, true)

        self:Blit(texture, oldTextureObj)

        self.oldShadingTextures[name] = oldTextureObj
    end

    return self.oldShadingTextures[name]
end

function TextureManager:getOldMapTexture(i, j)
    if self.oldMapFBOTextures[i] == nil then
        self.oldMapFBOTextures[i] = {}
    end
    if self.oldMapFBOTextures[i][j] == nil then
        -- doesn't exist so we create it
        local oldTexture = self:createMapTexture()

        local mapTexture = self.mapFBOTextures[i][j].texture

        self:Blit(mapTexture, oldTexture)
        local oldTextureObj = {
            texture = oldTexture,
            dirty = mapTexture.dirty,
        }
        self.oldMapFBOTextures[i][j] = oldTextureObj
    end

    return self.oldMapFBOTextures[i][j]
end

function TextureManager:getMapTextures(startX, startZ, endX, endZ)
    local textures = {}
    local textureSize = self.TEXTURE_SIZE

    local i1 = math.max(0, math.floor(startX / textureSize))
    local i2 = math.min(math.floor(Game.mapSizeX / textureSize),
                        math.floor(endX / textureSize))
    local j1 = math.max(0, math.floor(startZ / textureSize))
    local j2 = math.min(math.floor(Game.mapSizeZ / textureSize),
                        math.floor(endZ / textureSize))

    for i = i1, i2 do
        for j = j1, j2 do
            table.insert(textures, {
                self.mapFBOTextures[i][j], self:getOldMapTexture(i, j),
                { startX - i * textureSize, startZ - j * textureSize }
            })
        end
    end

    return textures
end

function TextureManager:Blit(srcTex, dstTexFboObj)
	--Spring.Echo("TextureManager:Blit", texSrc, texDst, texDstFBO)
	local dstFbo = dstTexFboObj.fbo
	if gl.IsValidFBO(dstFbo) then
		gl.Texture(srcTex)
		gl.ActiveFBO(dstFbo, function()
			gl.DepthTest(false)
			gl.Blending(false)
			gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
		end)
		gl.Texture(false)
	else
		local traceBack = (debug and debug.traceback()) or "unknown traceback"
		Log.Error("Attempt to call TextureManager:Blit() with invalid dstTexFboObj object: at " .. traceBack)
	end
end

function TextureManager:CacheTexture(name)
    SB.delayGL(function()
        if self.cachedTexturesMapping[name] ~= nil then
            return
        end
        -- maximum number of textures exceeded
        if #self.cachedTextures > self.maxCache then
            local obj = self.cachedTextures[1]
            DestroyTextureObj(obj.texture)
            self.cachedTexturesMapping[obj.name] = nil
            table.remove(self.cachedTextures, 1)
        end

        local texInfo = gl.TextureInfo(name)
		local textureObj = CreateTextureObj(texInfo.xsize, texInfo.ysize, { }, true)

        self:Blit(name, textureObj)

        self.cachedTexturesMapping[name] = textureObj
        table.insert(self.cachedTextures, textureObj)
    end)
end

function TextureManager:GetTexture(name)
    local cachedTex = self.cachedTexturesMapping[name]
    if cachedTex ~= nil then
        return cachedTex.texture
    else
        return name
    end
end

function TextureManager:_CalculateTextureMemorySize(texture)
    local texInfo = gl.TextureInfo(texture)
    local size = texInfo.xsize * texInfo.ysize * 4
    return size
end

function TextureManager:PushStack()
    local stackItem = {
        diffuse = self.oldMapFBOTextures,
    }
    for name, textureObj in pairs(self.oldShadingTextures) do
        stackItem[name] = textureObj
        self.stackSize = self.stackSize + self:_CalculateTextureMemorySize(textureObj.texture)
    end

    for _, row in pairs(stackItem.diffuse) do
        for _, textureObj in pairs(row) do
            self.stackSize = self.stackSize + self:_CalculateTextureMemorySize(textureObj.texture)
        end
    end

    table.insert(self.stack, stackItem)
    self.oldMapFBOTextures = {}
    self.oldShadingTextures = {}

    self:PrintMemory()
end

function TextureManager:RemoveStackItem(stackItem)
    if not stackItem then
        return
    end
    for name, value in pairs(stackItem) do
        if name == "diffuse" then
            local oldTextures = value
            for i, v in pairs(oldTextures) do
                for j, oldTextureObj in pairs(v) do
                    self.stackSize = self.stackSize - self:_CalculateTextureMemorySize(oldTextureObj.texture)

                    gl.DeleteTexture(oldTextureObj.texture)
                end
            end
        else
            self.stackSize = self.stackSize - self:_CalculateTextureMemorySize(value.texture)
            gl.DeleteTexture(value.texture)
        end
    end
end

function TextureManager:RestoreStackItem(stackItem)
    for name, value in pairs(stackItem) do
        if name == "diffuse" then
            local oldTextures = value
            for i, v in pairs(oldTextures) do
                for j, oldTextureObj in pairs(v) do

                    local mapTextureObj = self.mapFBOTextures[i][j]
                    local mapTexture = mapTextureObj.texture
                    self:Blit(oldTextureObj.texture, mapTexture)
                    mapTextureObj.dirty = oldTextureObj.dirty
                end
            end
        else
            local oldObject = value

            local shadingTexObj = self.shadingTextures[name]
            local shadingTex = shadingTexObj.texture
            self:Blit(oldObject.texture, shadingTex)
            shadingTexObj.dirty = oldObject.dirty
        end
    end
end

function TextureManager:RemoveFirst()
    local stackItem = self.stack[1]

    self:RemoveStackItem(stackItem)

    table.remove(self.stack, 1)
    self:PrintMemory()
end

function TextureManager:PopStack()
    local stackItem = self.stack[#self.stack]

    self:RestoreStackItem(stackItem)
    self:RemoveStackItem(stackItem)

    self.oldMapFBOTextures = {}
    self.oldShadingTextures = {}

    table.remove(self.stack, #self.stack)
    self:PrintMemory()
end

function TextureManager:PrintMemory()
    local mbSize = math.ceil(self.stackSize / 1024 / 1024)
    Log.Debug("Memory: " .. tostring(mbSize) .. "MB")
end

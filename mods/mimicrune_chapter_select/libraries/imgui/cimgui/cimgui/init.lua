-- Dear Imgui version: 1.88

-- local path = (...):gsub(".init$", "") .. "."
local path = (Mod.info.libs.imgui.path):gsub("/",".")..".cimgui.cimgui."

require(path .. "cdef")

---@class (partial) imgui
local M = require(path .. "master")
local ffi = require("ffi")

local library_path = assert(package.searchpath((Mod.libs.imgui.info.path):gsub("/",".")..".cimgui.cimgui", package.cpath))
M.C = ffi.load(library_path)

require(path .. "enums")
require(path .. "wrap")
require(path .. "love")
require(path .. "shortcuts")

-- remove access to M._common
M._common = nil

return M

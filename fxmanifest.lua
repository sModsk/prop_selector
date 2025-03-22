fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'prop_selector'
author 'sModsk'
version '1.0.0'

ui_page 'html/index.html'

files {
	"html/**/*",
}

client_scripts {
    'client/gizmo/keyMapper.lua',
    'client/gizmo/dataview.lua',
    'client/gizmo/gizmo.lua',
    'client/furniture.lua',
    'client/functions.lua',
    'client/client.lua'
}
fx_version 'cerulean'
game 'gta5'

author 'Market Stand Script Developer'
description 'Advanced Market Stand Script compatible with Qbox'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'shared/shared.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

lua54 'yes'
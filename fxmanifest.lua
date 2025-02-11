fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Way Scripts | Golden Meow'
description '[FREE] Sell Drugs'
version '1.0.1'

shared_script {
    '@ox_lib/init.lua',
    'config/*.lua',
    'locales/translate.lua'
}

client_script 'client/*.lua'
server_script 'server/*.lua'

dependencies {
    'ox_lib',
    'ox_target'
}

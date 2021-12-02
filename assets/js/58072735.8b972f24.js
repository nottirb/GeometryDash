"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[203],{29605:function(e){e.exports=JSON.parse('{"functions":[{"name":"ChangeState","desc":"Updates the map state based on the Character state. Currently just moves floors/ceilings up/down.","params":[{"name":"state","desc":"The character\'s new state","lua_type":"Character.Enum.State"},{"name":"speed","desc":"The speed at which to animate the state change","lua_type":"number"}],"returns":[],"function_type":"method","source":{"line":85,"path":"src/client/Controllers/MapController.lua"}},{"name":"LoadMap","desc":"Loads a map from a base located in ``ReplicatedStorage/Maps``. Displays a warning if the map does not exist.","params":[{"name":"mapName","desc":"The name of the map to load","lua_type":"string"},{"name":"leftVision","desc":"The vision the player should have to the left, defaults to LEFT_VISION","lua_type":"number"},{"name":"rightVision","desc":"The vision the player should have to the left defaults to RIGHT_VISION","lua_type":"number"}],"returns":[{"desc":"the map loaded, returns nil if the map with the given name does not exist","lua_type":"Map?"}],"function_type":"method","source":{"line":152,"path":"src/client/Controllers/MapController.lua"}},{"name":"ReloadMap","desc":"Reloads a Map around the starter position of the Map. Nearby chunks load instantly and do not run any animations.","params":[{"name":"map","desc":"The map to use, only necessary if you want to reload a specific Map object. Defaults to ``self.Map``.","lua_type":"Map?"}],"returns":[],"function_type":"method","source":{"line":179,"path":"src/client/Controllers/MapController.lua"}}],"properties":[{"name":"Map","desc":"The current ``Map`` component.","lua_type":"Map?","source":{"line":31,"path":"src/client/Controllers/MapController.lua"}},{"name":"StartPosition","desc":"The starting position on the current map.","lua_type":"Vector3?","source":{"line":37,"path":"src/client/Controllers/MapController.lua"}},{"name":"Chunks","desc":"The chunks of the current map. See: ``Map`` for the ``Chunks`` interface.","lua_type":"Chunks","source":{"line":43,"path":"src/client/Controllers/MapController.lua"}}],"types":[],"name":"MapController","desc":"Controls anything related to the map.","realm":["Client"],"source":{"line":21,"path":"src/client/Controllers/MapController.lua"}}')}}]);
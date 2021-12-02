--[[
    See test.project.json for test project structure, this script will be executed on studio run immediately after the project is built.
    See .github/workflows/ci.yaml for information on how the CI pipeline lints and runs tests.
]]

print("Running unit tests...")

local TestService = game:GetService("TestService")
local tests = {}

for _, test in ipairs(TestService.src:GetDescendants()) do
    if test:IsA("ModuleScript") then
        local name = (test.Name):match("(.+)%.spec")
        if name ~= nil then
            table.insert(tests, test)
        end
    end
end



require(TestService.Packages.TestEZ).TestBootstrap:run(tests)
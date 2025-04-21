local Router = {}
Router.__index = Router
Router.__name = "Router"
function Router.new()
    return setmetatable({
    }, Router)
end

return {

}

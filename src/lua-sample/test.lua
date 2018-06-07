module("luci.controller.test", package.seeall)

function index()
	entry({"admin", "system", "test-reboot"}, alias("admin", "system", "test-reboot", "do-reboot"), _("test lua controller"), 100).index=true
	entry({"admin", "system", "test-reboot", "do-reboot"}, call("test_func"), _("test lua do_reboot"), 2)
	entry({"admin", "system", "test-reboot", "show-info"}, cbi("lua_test"), _("show info"), 1)
end

function test_func()
	local click = luci.http.formvalue("reboot")
	luci.template.render("admin_system/test_reboot", {click=reboot})
	if click then
		luci.sys.reboot()
	end
end

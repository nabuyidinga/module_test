m=Map("show_info", translate("Show infomation test"))

s=m:section(TypedSection, "lua_test", translate("This is the section description"))
s.template = "cbi/tblsection"
s.addremove=true
s.anonymous=true

s:option(Flag, "date", translate("date now"))
list=s:option(ListValue, "action", translate("reboot"))
list:value("1", translate("do reboot"))
list:value("0", translate("do not reboot"))
s:option(Value, "delay", translate("sleep time before reboot"))

local apply=luci.http.formvalue("cbi.apply")
if apply then
	io.popen("/etc/init.d/reboot_test restart")
        io.popen("echo keytest > /dev/ttyS0")
end

return m

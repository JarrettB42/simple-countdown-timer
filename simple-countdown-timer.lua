--[[
	Simple Countdown Timer: A visibility controlled text timer countdown.
--]]

-- obs values
obs = obslua
hotkey_id = obs.OBS_INVALID_HOTKEY_ID

-- user values
duration = nil
final_text = nil
source_name = nil

-- internal values
remaining = 0
activated = false
previous_text = nil

-- Function to set the time text
function set_time_text()
	local text = final_text
	
	if remaining > 0 then
		local seconds       = math.floor(remaining % 60)
		local total_minutes = math.floor(remaining / 60)
		local minutes       = math.floor(total_minutes % 60)
		local hours         = math.floor(total_minutes / 60)
		if hours > 0 then
			text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
		else
			text = string.format("%02d:%02d", minutes, seconds)
		end
	end
	
	if text ~= previous_text then
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
		previous_text = text
	end
end

function timer_callback()
	remaining = remaining - 1
	
	if remaining < 0 then
		remaining = 0
		obs.remove_current_callback()
	end
	
	set_time_text()
end

function activate(activating)
	if activated == activating then
		return
	end
	
	activated = activating
	
	if activating then
		remaining = duration
		set_time_text()
		obs.timer_add(timer_callback, 1000) -- once per second
	else
		obs.timer_remove(timer_callback)
	end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end
	
	activate(false)
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local active = obs.obs_source_active(source)
		obs.obs_source_release(source)
		activate(active)
	end
end

function reset_button_clicked(props, p)
	reset(true)
end

function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_int(props, "duration", "Duration (Minutes)", 1, 600, 1)
	obs.obs_properties_add_text(props, "final_text", "Final Text", obs.OBS_TEXT_DEFAULT)
	
	local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_gdiplus_v2" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	
	obs.obs_properties_add_button(props, "reset_button", "Reset Countdown", reset_button_clicked)
	
	return props
end

function script_description()
	return "Makes a text source start a countdown timer when it becomes visible."
end

function script_update(settings)
	activate(false)
	
	duration = obs.obs_data_get_int(settings, "duration") * 60
	final_text = obs.obs_data_get_string(settings, "final_text")
	source_name = obs.obs_data_get_string(settings, "source")
	
	reset(true)
end

function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "duration", 10)
	obs.obs_data_set_default_string(settings, "final_text", "Starting Soon!™")
end

function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "reset_countdown", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

function script_load(settings)
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)
	
	hotkey_id = obs.obs_hotkey_register_frontend("reset_countdown", "Reset Countdown", reset)
	local hotkey_save_array = obs.obs_data_get_array(settings, "reset_countdown")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end


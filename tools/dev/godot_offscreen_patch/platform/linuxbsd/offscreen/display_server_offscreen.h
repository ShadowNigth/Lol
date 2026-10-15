/**************************************************************************/
/*  display_server_offscreen.h                                            */
/*  Optional development patch (Vaelmoor project): a display server that  */
/*  renders with the real RenderingDevice renderer into an offscreen      */
/*  (headless) Vulkan surface. Lets automated tests capture screenshots   */
/*  through Viewport.get_texture() without X11/Wayland.                   */
/*  Usage: --display-driver offscreen --rendering-driver vulkan           */
/*         --rendering-method mobile --resolution 1280x720                */
/**************************************************************************/

#pragma once

#include "servers/display/display_server_headless.h"

class RenderingContextDriver;
class RenderingDevice;

class DisplayServerOffscreen : public DisplayServerHeadless {
	GDSOFTCLASS(DisplayServerOffscreen, DisplayServerHeadless);

	Size2i size = Size2i(1280, 720);
	String rendering_driver;

#if defined(RD_ENABLED)
	RenderingContextDriver *rendering_context = nullptr;
	RenderingDevice *rendering_device = nullptr;
#endif

	static Vector<String> get_rendering_drivers_func();
	static DisplayServer *create_func(const String &p_rendering_driver, DisplayServerEnums::WindowMode p_mode, DisplayServerEnums::VSyncMode p_vsync_mode, uint32_t p_flags, const Vector2i *p_position, const Vector2i &p_resolution, int p_screen, DisplayServerEnums::Context p_context, int64_t p_parent_window, Error &r_error);

public:
	String get_name() const override { return "offscreen"; }

	int get_screen_count() const override { return 1; }
	Size2i screen_get_size(int p_screen = DisplayServerEnums::SCREEN_OF_MAIN_WINDOW) const override { return size; }
	Rect2i screen_get_usable_rect(int p_screen = DisplayServerEnums::SCREEN_OF_MAIN_WINDOW) const override { return Rect2i(Point2i(), size); }

	Vector<DisplayServerEnums::WindowID> get_window_list() const override;
	void window_set_size(const Size2i p_size, DisplayServerEnums::WindowID p_window = DisplayServerEnums::MAIN_WINDOW_ID) override;
	Size2i window_get_size(DisplayServerEnums::WindowID p_window = DisplayServerEnums::MAIN_WINDOW_ID) const override { return size; }
	Size2i window_get_size_with_decorations(DisplayServerEnums::WindowID p_window = DisplayServerEnums::MAIN_WINDOW_ID) const override { return size; }
	DisplayServerEnums::WindowMode window_get_mode(DisplayServerEnums::WindowID p_window = DisplayServerEnums::MAIN_WINDOW_ID) const override { return DisplayServerEnums::WINDOW_MODE_WINDOWED; }
	bool window_can_draw(DisplayServerEnums::WindowID p_window = DisplayServerEnums::MAIN_WINDOW_ID) const override { return true; }
	bool can_any_window_draw() const override { return true; }
	int window_get_current_screen(DisplayServerEnums::WindowID p_window = DisplayServerEnums::MAIN_WINDOW_ID) const override { return 0; }

	static void register_offscreen_driver();

	DisplayServerOffscreen(const String &p_rendering_driver, const Vector2i &p_resolution, Error &r_error);
	~DisplayServerOffscreen();
};

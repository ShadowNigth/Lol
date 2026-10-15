/**************************************************************************/
/*  display_server_offscreen.cpp                                          */
/*  Optional development patch (Vaelmoor project).                        */
/**************************************************************************/

#include "display_server_offscreen.h"

#include "core/config/project_settings.h"
#include "core/os/os.h"
#include "servers/rendering/dummy/rasterizer_dummy.h"

#if defined(RD_ENABLED)
#include "servers/rendering/renderer_rd/renderer_compositor_rd.h"
#include "servers/rendering/rendering_device.h"
#endif

#if defined(VULKAN_ENABLED)
#include "rendering_context_driver_vulkan_headless.h"
#endif

Vector<String> DisplayServerOffscreen::get_rendering_drivers_func() {
	Vector<String> drivers;
#if defined(VULKAN_ENABLED)
	drivers.push_back("vulkan");
#endif
	drivers.push_back("dummy");
	return drivers;
}

DisplayServer *DisplayServerOffscreen::create_func(const String &p_rendering_driver, DisplayServerEnums::WindowMode p_mode, DisplayServerEnums::VSyncMode p_vsync_mode, uint32_t p_flags, const Vector2i *p_position, const Vector2i &p_resolution, int p_screen, DisplayServerEnums::Context p_context, int64_t p_parent_window, Error &r_error) {
	DisplayServer *ds = memnew(DisplayServerOffscreen(p_rendering_driver, p_resolution, r_error));
	if (r_error != OK) {
		memdelete(ds);
		return nullptr;
	}
	return ds;
}

void DisplayServerOffscreen::register_offscreen_driver() {
	register_create_function("offscreen", create_func, get_rendering_drivers_func);
}

Vector<DisplayServerEnums::WindowID> DisplayServerOffscreen::get_window_list() const {
	Vector<DisplayServerEnums::WindowID> list;
	list.push_back(DisplayServerEnums::MAIN_WINDOW_ID);
	return list;
}

void DisplayServerOffscreen::window_set_size(const Size2i p_size, DisplayServerEnums::WindowID p_window) {
	if (p_size.x <= 0 || p_size.y <= 0) {
		return;
	}
	size = p_size;
#if defined(RD_ENABLED)
	if (rendering_context) {
		rendering_context->window_set_size(DisplayServerEnums::MAIN_WINDOW_ID, size.width, size.height);
	}
#endif
}

DisplayServerOffscreen::DisplayServerOffscreen(const String &p_rendering_driver, const Vector2i &p_resolution, Error &r_error) {
	r_error = OK;
	rendering_driver = p_rendering_driver;
	if (p_resolution.x > 0 && p_resolution.y > 0) {
		size = p_resolution;
	}

#if defined(RD_ENABLED) && defined(VULKAN_ENABLED)
	if (rendering_driver == "vulkan") {
		rendering_context = memnew(RenderingContextDriverVulkanHeadless);
		if (rendering_context->initialize() != OK) {
			ERR_PRINT("Offscreen: could not initialize the Vulkan rendering context.");
			memdelete(rendering_context);
			rendering_context = nullptr;
			r_error = ERR_CANT_CREATE;
			return;
		}
		RenderingContextDriverVulkanHeadless::WindowPlatformData wpd;
		Error err = rendering_context->window_create(DisplayServerEnums::MAIN_WINDOW_ID, &wpd);
		if (err != OK) {
			ERR_PRINT("Offscreen: could not create the headless Vulkan surface.");
			memdelete(rendering_context);
			rendering_context = nullptr;
			r_error = ERR_CANT_CREATE;
			return;
		}
		rendering_context->window_set_size(DisplayServerEnums::MAIN_WINDOW_ID, size.width, size.height);
		rendering_context->window_set_vsync_mode(DisplayServerEnums::MAIN_WINDOW_ID, DisplayServerEnums::VSYNC_DISABLED);

		rendering_device = memnew(RenderingDevice);
		if (rendering_device->initialize(rendering_context, DisplayServerEnums::MAIN_WINDOW_ID) != OK) {
			ERR_PRINT("Offscreen: could not initialize the RenderingDevice.");
			memdelete(rendering_device);
			rendering_device = nullptr;
			rendering_context->window_destroy(DisplayServerEnums::MAIN_WINDOW_ID);
			memdelete(rendering_context);
			rendering_context = nullptr;
			r_error = ERR_UNAVAILABLE;
			return;
		}
		rendering_device->screen_create(DisplayServerEnums::MAIN_WINDOW_ID);
		RendererCompositorRD::make_current();
		print_line(vformat("Offscreen display server: Vulkan headless surface %dx%d.", size.width, size.height));
		return;
	}
#endif

	RasterizerDummy::make_current();
}

DisplayServerOffscreen::~DisplayServerOffscreen() {
#if defined(RD_ENABLED)
	if (rendering_device) {
		rendering_device->screen_free(DisplayServerEnums::MAIN_WINDOW_ID);
	}
	if (rendering_context) {
		rendering_context->window_destroy(DisplayServerEnums::MAIN_WINDOW_ID);
	}
	if (rendering_device) {
		memdelete(rendering_device);
		rendering_device = nullptr;
	}
	if (rendering_context) {
		memdelete(rendering_context);
		rendering_context = nullptr;
	}
#endif
}

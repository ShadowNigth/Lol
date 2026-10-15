/**************************************************************************/
/*  rendering_context_driver_vulkan_headless.h                            */
/*  Optional development patch (Vaelmoor project): Vulkan rendering into  */
/*  a VK_EXT_headless_surface, used for automated screenshot tests on     */
/*  machines without a display server (e.g. SwiftShader in CI).           */
/**************************************************************************/

#pragma once

#ifdef VULKAN_ENABLED

#include "drivers/vulkan/rendering_context_driver_vulkan.h"

class RenderingContextDriverVulkanHeadless : public RenderingContextDriverVulkan {
private:
	virtual const char *_get_platform_surface_extension() const override final;

protected:
	SurfaceID surface_create(const void *p_platform_data) override final;

public:
	struct WindowPlatformData {
		int unused = 0;
	};

	RenderingContextDriverVulkanHeadless();
	~RenderingContextDriverVulkanHeadless();
};

#endif // VULKAN_ENABLED

/**************************************************************************/
/*  rendering_context_driver_vulkan_headless.cpp                          */
/*  Optional development patch (Vaelmoor project).                        */
/**************************************************************************/

#ifdef VULKAN_ENABLED

#include "rendering_context_driver_vulkan_headless.h"

#include "drivers/vulkan/godot_vulkan.h"

const char *RenderingContextDriverVulkanHeadless::_get_platform_surface_extension() const {
	return VK_EXT_HEADLESS_SURFACE_EXTENSION_NAME;
}

RenderingContextDriver::SurfaceID RenderingContextDriverVulkanHeadless::surface_create(const void *p_platform_data) {
	VkHeadlessSurfaceCreateInfoEXT create_info = {};
	create_info.sType = VK_STRUCTURE_TYPE_HEADLESS_SURFACE_CREATE_INFO_EXT;

	VkSurfaceKHR vk_surface = VK_NULL_HANDLE;
	VkResult err = vkCreateHeadlessSurfaceEXT(instance_get(), &create_info, get_allocation_callbacks(VK_OBJECT_TYPE_SURFACE_KHR), &vk_surface);
	ERR_FAIL_COND_V(err != VK_SUCCESS, SurfaceID());

	Surface *surface = memnew(Surface);
	surface->vk_surface = vk_surface;
	return SurfaceID(surface);
}

RenderingContextDriverVulkanHeadless::RenderingContextDriverVulkanHeadless() {
}

RenderingContextDriverVulkanHeadless::~RenderingContextDriverVulkanHeadless() {
}

#endif // VULKAN_ENABLED

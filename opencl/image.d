/**
 *	cl4d - object-oriented wrapper for the OpenCL C API
 *	written in the D programming language
 *
 *	Copyright:
 *		(C) 2009-2010 Andreas Hollandt
 *
 *	License:
 *		see LICENSE.txt
 */
module opencl.image;

import opencl.c.cl;
import opencl.context;
import opencl.error;
import opencl.memory;
import opencl.wrapper;

/**
 *	base class for the different image types
 *
 *	used to store a one-, two- or three- dimensional texture, frame-buffer or image.
 *	The elements of an image object are selected from a list of predefined image formats.
 *	The minimum number of elements in a memory object is one
 */
class CLImage : CLMemory
{
package:
	this() {}

	this(cl_mem object)
	{
		super(object);
	}

public:
	@property
	{
		//!image format descriptor specified when image was created
		// TODO: test if getInfo works here, cl_image_format is a struct
		auto format()
		{
			return getInfo!(cl_image_format, clGetImageInfo)(CL_IMAGE_FORMAT);
		}
		
		/**
		 *	size of each element of the image memory object given by image. An
		 *	element is made up of n channels. The value of n is given in cl_image_format descriptor.
		 */
		size_t elementSize()
		{
			return getInfo!(size_t, clGetImageInfo)(CL_IMAGE_ELEMENT_SIZE);
		}
		
		//! size in bytes of a row of elements of the image object given by image
		size_t rowPitch()
		{
			return getInfo!(size_t, clGetImageInfo)(CL_IMAGE_ROW_PITCH);
		}

		/**
		 *	size in bytes of a 2D slice for the 3D image object given by image.
		 *
		 *	For a 2D image object this value will be 0.
		 */
		size_t slicePitch()
		{
			return getInfo!(size_t, clGetImageInfo)(CL_IMAGE_SLICE_PITCH);
		}

		//! width in pixels
		size_t width()
		{
			return getInfo!(size_t, clGetImageInfo)(CL_IMAGE_WIDTH);
		}

		//! height in pixels 
		size_t height()
		{
			return getInfo!(size_t, clGetImageInfo)(CL_IMAGE_HEIGHT);
		}

		/**
		 *	depth of the image in pixels
		 *
		 *	For a 2D image object, depth = 0
		 */
		size_t depth()
		{
			return getInfo!(size_t, clGetImageInfo)(CL_IMAGE_DEPTH);
		}
	} // of @property
}

//! 2D Image
class CLImage2D : CLImage
{
public:
	/**
	 *	Params:
	 *		flags	= used to specify allocation and usage info for the image object
	 *		format	= describes image format properties
	 *		rowPitch= scan-line pitch in bytes
	 *		hostPtr	= can be a pointer to host-allocated image data to be used
	 */
	this(CLContext context, cl_mem_flags flags, const cl_image_format format, size_t width, size_t height, size_t rowPitch, void* hostPtr = null)
	{
		cl_int res;
		_object = clCreateImage2D(context.getObject(), flags, &format, width, height, rowPitch, hostPtr, &res);
		
		mixin(exceptionHandling(
			["CL_INVALID_CONTEXT",					""],
			["CL_INVALID_VALUE",					"invalid image flags"],
			["CL_INVALID_IMAGE_FORMAT_DESCRIPTOR",	"values specified in format are not valid or format is null"],
			["CL_INVALID_IMAGE_SIZE",				"width or height are 0 OR exceed CL_DEVICE_IMAGE2D_MAX_WIDTH or CL_DEVICE_IMAGE2D_MAX_HEIGHT resp. OR rowPitch is not valid"],
			["CL_INVALID_HOST_PTR",					"hostPtr is null and CL_MEM_USE_HOST_PTR or CL_MEM_COPY_HOST_PTR are set in flags or if hostPtr is not null but CL_MEM_COPY_HOST_PTR or CL_MEM_USE_HOST_PTR are not set in"],
			["CL_IMAGE_FORMAT_NOT_SUPPORTED",		"format is not supported"],
			["CL_MEM_OBJECT_ALLOCATION_FAILURE",	"couldn't allocate memory for image object"],
			["CL_INVALID_OPERATION",				"there are no devices in context that support images (i.e. CL_DEVICE_IMAGE_SUPPORT specified is CL_FALSE"],
			["CL_OUT_OF_RESOURCES",					""],
			["CL_OUT_OF_HOST_MEMORY",				""]
		));
	}
}
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
module opencl.wrapper;

import opencl.error;
import opencl.c.cl;
import opencl.kernel;
import opencl.platform;
import opencl.device;
import opencl.event;

package
{
	alias const(char) cchar;
	alias const(wchar) cwchar;
	alias const(dchar) cdchar;
	alias immutable(char) ichar;
	alias immutable(wchar) iwchar;
	alias immutable(dchar) idchar;
	alias const(char)[] cstring;
}

// alternate Info getter functions
private alias extern(C) cl_int function(const(void)*, const(void*), cl_uint, size_t, void*, size_t*) Func;

/**
 *	This is the base class of all CLObjects
 *	provides getInfo, retain and release functions
 */ 
package string CLWrapper(cstring T, cstring infoFunction)
{
//	pragma(msg, infoFunction.stringof);
	return cast(string)("private:\nalias " ~ T ~ " T;\n alias " ~ infoFunction ~ " infoFunction;\n" ~ q{
protected:
	T _object = null;

package:
	this() {}

private import std.stdio;
	/**
	 *	create a wrapper around a CL Object
	 *
	 *	Params:
	 *	    increment = increase the object's reference count, necessary e.g. in CLCollection
	 */
	this(T obj, bool increment = false)
	{
		_object = obj;
		debug writefln("new reference to %s object created. Reference count before was: %d", typeid(typeof(this)), referenceCount);
		// increment reference count
		if (increment)
			retain();
	}

	//! release the object
	~this()
	{
		debug writefln("%s object destroyed. Reference count before was: %d", typeid(typeof(this)), referenceCount);
		release();
	}

	// should only be used inside here so reference counting works
	package T getObject()
	{
		return _object;
	}
/+
	//! ensure that _object isn't null
	invariant()
	{
		assert(_object !is null);
	}
+/
public:
	//! increments the object reference count
	void retain()
	{
		// NOTE: cl_platform_id and cl_device_id don't have reference counting
		// T.stringof is compared instead of T itself so it also works with T being an alias
		// platform and device will have an empty retain() so it can be safely used in this()
		static if (T.stringof[$-3..$] != "_id")
		{
			mixin("cl_int res = clRetain" ~ toCamelCase(T.stringof[2..$].dup) ~ (T.stringof == "cl_mem" ? "Object" : "") ~ "(_object);");
			mixin(exceptionHandling(
				["CL_OUT_OF_RESOURCES",		""],
				["CL_OUT_OF_HOST_MEMORY",	""]
			));
		}
	}
	
	/**
	 *	decrements the context reference count
	 *	The object is deleted once the number of instances that are retained to it become zero
	 */
	void release()
	{
		static if (T.stringof[$-3..$] != "_id")
		{
			mixin("cl_int res = clRelease" ~ toCamelCase(T.stringof[2..$].dup) ~ (T.stringof == "cl_mem" ? "Object" : "") ~ "(_object);");
			mixin(exceptionHandling(
				["CL_OUT_OF_RESOURCES",		""],
				["CL_OUT_OF_HOST_MEMORY",	""]
			));
		}
	}
	private import std.string;
	/**
	 *	Return the reference count
	 *
	 *	The reference count returned should be considered immediately stale. It is unsuitable for general use in 
	 *	applications. This feature is provided for identifying memory leaks
	 */
	@property cl_uint referenceCount()
	{
		static if (T.stringof[$-3..$] != "_id")
			mixin("return getInfo!cl_uint(CL_" ~ (T.stringof == "cl_command_queue" ? "QUEUE" : toupper(T.stringof[3..$])) ~ "_REFERENCE_COUNT);");
		else
			return 0;
	}

protected:
	// used for all non-array types
	// TODO: make infoname type-safe, not cl_uint (can vary for certain _object, see cl_mem)
	U getInfo(U)(cl_uint infoname)
	{
		assert(_object !is null);
		cl_int res;
		
		debug
		{
			size_t needed;

			// get amount of memory necessary
			res = infoFunction(_object, infoname, 0, null, &needed);
	
			// error checking
			if (res != CL_SUCCESS)
				throw new CLException(res);
			
			assert(needed == U.sizeof);
		}
		
		U info;

		// get actual data
		res = infoFunction(_object, infoname, U.sizeof, &info, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return info;
	}
	
	// this special version is only used for clGetProgramBuildInfo and clGetKernelWorkgroupInfo
	U getInfo2(U, alias altFunction)( cl_device_id device, cl_uint infoname)
	{
		assert(_object !is null);
		cl_int res;
		
		debug
		{
			size_t needed;

			// get amount of memory necessary
			res = altFunction(_object, device, infoname, 0, null, &needed);
	
			// error checking
			if (res != CL_SUCCESS)
				throw new CLException(res);
			
			assert(needed == U.sizeof);
		}
		
		U info;

		// get actual data
		res = altFunction(_object, device, infoname, U.sizeof, &info, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return info;
	}
	
	// helper function for all OpenCL Get*Info functions
	// used for all array return types
	U[] getArrayInfo(U)(cl_uint infoname)
	{
		assert(_object !is null);
		size_t needed;
		cl_int res;

		// get number of needed memory
		res = infoFunction(_object, infoname, 0, null, &needed);

		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		auto buffer = new U[needed/U.sizeof];

		// get actual data
		res = infoFunction(_object, infoname, buffer.length, cast(void*)buffer.ptr, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return buffer;
	}
	
	// this special version is only used for clGetProgramBuildInfo and clGetKernelWorkgroupInfo
	// used for all array return types
	U[] getArrayInfo2(U, alias altFunction)(cl_device_id device, cl_uint infoname)
	{
		assert(_object !is null);
		size_t needed;
		cl_int res;

		// get number of needed memory
		res = altFunction(_object, device, infoname, 0, null, &needed);

		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		auto buffer = new U[needed/U.sizeof];

		// get actual data
		res = altFunction(_object, device, infoname, buffer.length, cast(void*)buffer.ptr, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return buffer;
	}
	
	string getStringInfo(cl_uint infoname)
	{
		return cast(string) getArrayInfo!(ichar)(infoname);
	}

}); // end of q{} wysiwyg string
}

/**
 *	a collection of OpenCL objects returned by some methods
 *	Params:
 *		T = an OpenCL C object like cl_kernel
 */
class CLObjectCollection(T)
{
protected:
	T[] _objects;

	static if(is(T == cl_platform_id))
		alias CLPlatform Wrapper;
	static if(is(T == cl_device_id))
		alias CLDevice Wrapper;
	static if(is(T == cl_kernel))
		alias CLKernel Wrapper;
	static if(is(T == cl_event))
		alias CLEvent Wrapper;
	// TODO: rest of the types

public:
	//! takes a list of OpenCL objects returned by some OpenCL functions like GetPlatformIDs
	this(T[] objects, bool increment = false)
	{
		_objects = objects.dup;
		
		if (increment)
		for(uint i=0; i<objects.length; i++)
		{
			// increment the reference counter so the objects won't be destroyed
			// TODO: is there a better way than replicating the retain/release code from above?
			static if (T.stringof[$-3..$] != "_id")
			{
				mixin("cl_int res = clRetain" ~ toCamelCase(T.stringof[2..$].dup) ~ (T.stringof == "cl_mem" ? "Object" : "") ~ "(objects[i]);");
				mixin(exceptionHandling(
					["CL_OUT_OF_RESOURCES",		""],
					["CL_OUT_OF_HOST_MEMORY",	""]
				));
			}
		}
	}
	
	//! release all objects
	~this()
	{
		for(uint i=0; i<_objects.length; i++)
		{
			// release all held objects
			static if (T.stringof[$-3..$] != "_id")
			{
				mixin("cl_int res = clRelease" ~ toCamelCase(T.stringof[2..$].dup) ~ (T.stringof == "cl_mem" ? "Object" : "") ~ "(_objects[i]);");
				mixin(exceptionHandling(
					["CL_OUT_OF_RESOURCES",		""],
					["CL_OUT_OF_HOST_MEMORY",	""]
				));
			}
		}
	}
	
	/// used to internally get the underlying object pointers
	package T[] getObjArray()
	{
		return _objects;
	}
	
	//!
	package @property T* ptr()
	{
		return _objects.ptr;
	}

	//! get number of Objects
	@property size_t length()
	{
		return _objects.length;
	}

	/// returns a new instance wrapping object i
	Wrapper opIndex(size_t i)
	{
		// increment reference count
		return new Wrapper(_objects[i], true);
	}
	
	/// for foreach to work
	int opApply(int delegate(ref Wrapper) dg)
	{
		int result = 0;
		
		for(uint i=0; i<_objects.length; i++)
		{
			Wrapper w = new Wrapper(_objects[i], true);
			result = dg(w);
			if(result)
				break;
		}
		
		return result;
	}
}
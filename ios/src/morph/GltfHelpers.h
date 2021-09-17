/*
 * Copyright (C) 2019 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef GLTFIO_GLTFHELPERS_H
#define GLTFIO_GLTFHELPERS_H

#include <cgltf.h>

static const uint8_t* cgltf_buffer_view_data(const cgltf_buffer_view* view) {
	if (view->data)
		return (const uint8_t*)view->data;

	if (!view->buffer->data)
		return NULL;

	const uint8_t* result = (const uint8_t*)view->buffer->data;
	result += view->offset;
	return result;
}

static cgltf_size cgltf_component_size(cgltf_component_type component_type) {
	switch (component_type)
	{
	case cgltf_component_type_r_8:
	case cgltf_component_type_r_8u:
		return 1;
	case cgltf_component_type_r_16:
	case cgltf_component_type_r_16u:
		return 2;
	case cgltf_component_type_r_32u:
	case cgltf_component_type_r_32f:
		return 4;
	case cgltf_component_type_invalid:
	default:
		return 0;
	}
}

static cgltf_size cgltf_component_read_index(const void* in, cgltf_component_type component_type) {
	switch (component_type)
	{
		case cgltf_component_type_r_16:
			return *((const int16_t*) in);
		case cgltf_component_type_r_16u:
			return *((const uint16_t*) in);
		case cgltf_component_type_r_32u:
			return *((const uint32_t*) in);
		case cgltf_component_type_r_32f:
			return (cgltf_size)*((const float*) in);
		case cgltf_component_type_r_8:
			return *((const int8_t*) in);
		case cgltf_component_type_r_8u:
			return *((const uint8_t*) in);
		default:
			return 0;
	}
}

static cgltf_float cgltf_component_read_float(const void* in, cgltf_component_type component_type, 
        cgltf_bool normalized) {
	if (component_type == cgltf_component_type_r_32f)
	{
		return *((const float*) in);
	}

	if (normalized)
	{
		switch (component_type)
		{
			// note: glTF spec doesn't currently define normalized conversions for 32-bit integers
			case cgltf_component_type_r_16:
				return *((const int16_t*) in) / (cgltf_float)32767;
			case cgltf_component_type_r_16u:
				return *((const uint16_t*) in) / (cgltf_float)65535;
			case cgltf_component_type_r_8:
				return *((const int8_t*) in) / (cgltf_float)127;
			case cgltf_component_type_r_8u:
				return *((const uint8_t*) in) / (cgltf_float)255;
			default:
				return 0;
		}
	}

	return (cgltf_float)cgltf_component_read_index(in, component_type);
}

static cgltf_bool cgltf_element_read_float(const uint8_t* element, cgltf_type type, 
        cgltf_component_type component_type, cgltf_bool normalized, cgltf_float* out, 
        cgltf_size element_size) {
	cgltf_size num_components = cgltf_num_components(type);

	if (element_size < num_components) {
		return 0;
	}

	// There are three special cases for component extraction, see #data-alignment in the 2.0 spec.

	cgltf_size component_size = cgltf_component_size(component_type);

	for (cgltf_size i = 0; i < num_components; ++i)
	{
		out[i] = cgltf_component_read_float(element + component_size * i, component_type, normalized);
	}
	return 1;
}

#endif // GLTFIO_GLTFHELPERS_H

class_name Message
#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2022, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"
const DEBUG_TAB : String = "  "

const  PROTO_VERSION = 3

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && varint[8] == 0xFF:
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		var value = 0
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_float()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_double()
		else:
			for i in range(index + count - 1, index - 1, -1):
				value |= (bytes[i] & 0xFF)
				if i != index:
					value <<= 8
		return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		for i in range(varint_bytes.size() - 1, -1, -1):
			value |= varint_bytes[i] & 0x7F
			if i != 0:
				value <<= 7
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var result : PackedByteArray = PackedByteArray()
		for i in range(index, bytes.size()):
			result.append(bytes[i])
			if !(bytes[i] & 0x80):
				break
		return result

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						#if obj != null && obj.size() > 0:
						#	data.append_array(pack_length_delimeted(type, field.tag, obj))
						#else:
						#	data = PackedByteArray()
						#	return data
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					#if obj != null && obj.size() > 0:
					#	data.append_array(obj)
					#	return pack_length_delimeted(type, field.tag, data)
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								str_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								val_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + String(value)
		else:
			result += String(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


enum ClinetType {
	UNKNOWN = 0,
	VISION = 1,
	ARM = 2,
	MONITOR = 3
}

enum V_CMD {
	V_UPDATE = 0
}

enum M_CMD {
	M_UPDATE_VISION = 0,
	M_UPDATE_CLIENTS = 1,
	M_CONTROL_ARM_RAW = 2,
	M_CONTROL_ARM_TARGET = 3,
	M_CONTROL_ARM_TARGET_FULL = 4
}

enum A_CMD {
	A_CONTROL_RAW = 0,
	A_CONTROL_TARGET = 1,
	A_CONTROL_TARGET_FULL = 2
}

class CSMessage:
	func _init():
		var service
		
		_client_type = PBField.new("client_type", PB_DATA_TYPE.ENUM, PB_RULE.REQUIRED, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _client_type
		data[_client_type.tag] = service
		
		_heartbeat = PBField.new("heartbeat", PB_DATA_TYPE.BOOL, PB_RULE.REQUIRED, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = _heartbeat
		data[_heartbeat.tag] = service
		
		_cs_vision_message = PBField.new("cs_vision_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _cs_vision_message
		service.func_ref = self.new_cs_vision_message
		data[_cs_vision_message.tag] = service
		
		_cs_arm_message = PBField.new("cs_arm_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _cs_arm_message
		service.func_ref = self.new_cs_arm_message
		data[_cs_arm_message.tag] = service
		
		_cs_monitor_message = PBField.new("cs_monitor_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _cs_monitor_message
		service.func_ref = self.new_cs_monitor_message
		data[_cs_monitor_message.tag] = service
		
	var data = {}
	
	var _client_type: PBField
	func get_client_type():
		return _client_type.value
	func clear_client_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_client_type.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_client_type(value) -> void:
		_client_type.value = value
	
	var _heartbeat: PBField
	func get_heartbeat() -> bool:
		return _heartbeat.value
	func clear_heartbeat() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_heartbeat.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_heartbeat(value : bool) -> void:
		_heartbeat.value = value
	
	var _cs_vision_message: PBField
	func get_cs_vision_message() -> CSVisionMessage:
		return _cs_vision_message.value
	func clear_cs_vision_message() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_cs_vision_message.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_cs_vision_message() -> CSVisionMessage:
		_cs_vision_message.value = CSVisionMessage.new()
		return _cs_vision_message.value
	
	var _cs_arm_message: PBField
	func get_cs_arm_message() -> CSArmMessage:
		return _cs_arm_message.value
	func clear_cs_arm_message() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_cs_arm_message.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_cs_arm_message() -> CSArmMessage:
		_cs_arm_message.value = CSArmMessage.new()
		return _cs_arm_message.value
	
	var _cs_monitor_message: PBField
	func get_cs_monitor_message() -> CSMonitorMessage:
		return _cs_monitor_message.value
	func clear_cs_monitor_message() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_cs_monitor_message.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_cs_monitor_message() -> CSMonitorMessage:
		_cs_monitor_message.value = CSMonitorMessage.new()
		return _cs_monitor_message.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SCMessage:
	func _init():
		var service
		
		_client_type = PBField.new("client_type", PB_DATA_TYPE.ENUM, PB_RULE.REQUIRED, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _client_type
		data[_client_type.tag] = service
		
		_heartbeat = PBField.new("heartbeat", PB_DATA_TYPE.BOOL, PB_RULE.REQUIRED, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = _heartbeat
		data[_heartbeat.tag] = service
		
		_sc_vision_message = PBField.new("sc_vision_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _sc_vision_message
		service.func_ref = self.new_sc_vision_message
		data[_sc_vision_message.tag] = service
		
		_sc_arm_message = PBField.new("sc_arm_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _sc_arm_message
		service.func_ref = self.new_sc_arm_message
		data[_sc_arm_message.tag] = service
		
		_sc_monitor_message = PBField.new("sc_monitor_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _sc_monitor_message
		service.func_ref = self.new_sc_monitor_message
		data[_sc_monitor_message.tag] = service
		
	var data = {}
	
	var _client_type: PBField
	func get_client_type():
		return _client_type.value
	func clear_client_type() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_client_type.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_client_type(value) -> void:
		_client_type.value = value
	
	var _heartbeat: PBField
	func get_heartbeat() -> bool:
		return _heartbeat.value
	func clear_heartbeat() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_heartbeat.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_heartbeat(value : bool) -> void:
		_heartbeat.value = value
	
	var _sc_vision_message: PBField
	func get_sc_vision_message() -> SCVisionMessage:
		return _sc_vision_message.value
	func clear_sc_vision_message() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_sc_vision_message.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_sc_vision_message() -> SCVisionMessage:
		_sc_vision_message.value = SCVisionMessage.new()
		return _sc_vision_message.value
	
	var _sc_arm_message: PBField
	func get_sc_arm_message() -> SCArmMessage:
		return _sc_arm_message.value
	func clear_sc_arm_message() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_sc_arm_message.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_sc_arm_message() -> SCArmMessage:
		_sc_arm_message.value = SCArmMessage.new()
		return _sc_arm_message.value
	
	var _sc_monitor_message: PBField
	func get_sc_monitor_message() -> SCMonitorMessage:
		return _sc_monitor_message.value
	func clear_sc_monitor_message() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_sc_monitor_message.value = DEFAULT_VALUES_2[PB_DATA_TYPE.MESSAGE]
	func new_sc_monitor_message() -> SCMonitorMessage:
		_sc_monitor_message.value = SCMonitorMessage.new()
		return _sc_monitor_message.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CSVisionMessage:
	func _init():
		var service
		
		_cmd = PBField.new("cmd", PB_DATA_TYPE.ENUM, PB_RULE.REQUIRED, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _cmd
		data[_cmd.tag] = service
		
		_color_image = PBField.new("color_image", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = _color_image
		data[_color_image.tag] = service
		
		_depth_image = PBField.new("depth_image", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = _depth_image
		data[_depth_image.tag] = service
		
	var data = {}
	
	var _cmd: PBField
	func get_cmd():
		return _cmd.value
	func clear_cmd() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_cmd.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_cmd(value) -> void:
		_cmd.value = value
	
	var _color_image: PBField
	func get_color_image() -> PackedByteArray:
		return _color_image.value
	func clear_color_image() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_color_image.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
	func set_color_image(value : PackedByteArray) -> void:
		_color_image.value = value
	
	var _depth_image: PBField
	func get_depth_image() -> PackedByteArray:
		return _depth_image.value
	func clear_depth_image() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_depth_image.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
	func set_depth_image(value : PackedByteArray) -> void:
		_depth_image.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CSArmMessage:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CSMonitorMessage:
	func _init():
		var service
		
		_cmd = PBField.new("cmd", PB_DATA_TYPE.ENUM, PB_RULE.REQUIRED, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _cmd
		data[_cmd.tag] = service
		
		_control_arm_raw_pos1 = PBField.new("control_arm_raw_pos1", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos1
		data[_control_arm_raw_pos1.tag] = service
		
		_control_arm_raw_pos2 = PBField.new("control_arm_raw_pos2", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos2
		data[_control_arm_raw_pos2.tag] = service
		
		_control_arm_raw_pos3 = PBField.new("control_arm_raw_pos3", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos3
		data[_control_arm_raw_pos3.tag] = service
		
		_control_arm_raw_pos4 = PBField.new("control_arm_raw_pos4", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos4
		data[_control_arm_raw_pos4.tag] = service
		
		_control_arm_raw_pos5 = PBField.new("control_arm_raw_pos5", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos5
		data[_control_arm_raw_pos5.tag] = service
		
		_control_arm_raw_pos6 = PBField.new("control_arm_raw_pos6", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos6
		data[_control_arm_raw_pos6.tag] = service
		
		_control_arm_target_x = PBField.new("control_arm_target_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _control_arm_target_x
		data[_control_arm_target_x.tag] = service
		
		_control_arm_target_y = PBField.new("control_arm_target_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _control_arm_target_y
		data[_control_arm_target_y.tag] = service
		
		_control_arm_target_r = PBField.new("control_arm_target_r", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 10, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _control_arm_target_r
		data[_control_arm_target_r.tag] = service
		
	var data = {}
	
	var _cmd: PBField
	func get_cmd():
		return _cmd.value
	func clear_cmd() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_cmd.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_cmd(value) -> void:
		_cmd.value = value
	
	var _control_arm_raw_pos1: PBField
	func get_control_arm_raw_pos1() -> int:
		return _control_arm_raw_pos1.value
	func clear_control_arm_raw_pos1() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos1.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos1(value : int) -> void:
		_control_arm_raw_pos1.value = value
	
	var _control_arm_raw_pos2: PBField
	func get_control_arm_raw_pos2() -> int:
		return _control_arm_raw_pos2.value
	func clear_control_arm_raw_pos2() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos2.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos2(value : int) -> void:
		_control_arm_raw_pos2.value = value
	
	var _control_arm_raw_pos3: PBField
	func get_control_arm_raw_pos3() -> int:
		return _control_arm_raw_pos3.value
	func clear_control_arm_raw_pos3() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos3.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos3(value : int) -> void:
		_control_arm_raw_pos3.value = value
	
	var _control_arm_raw_pos4: PBField
	func get_control_arm_raw_pos4() -> int:
		return _control_arm_raw_pos4.value
	func clear_control_arm_raw_pos4() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos4.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos4(value : int) -> void:
		_control_arm_raw_pos4.value = value
	
	var _control_arm_raw_pos5: PBField
	func get_control_arm_raw_pos5() -> int:
		return _control_arm_raw_pos5.value
	func clear_control_arm_raw_pos5() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos5.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos5(value : int) -> void:
		_control_arm_raw_pos5.value = value
	
	var _control_arm_raw_pos6: PBField
	func get_control_arm_raw_pos6() -> int:
		return _control_arm_raw_pos6.value
	func clear_control_arm_raw_pos6() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos6.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos6(value : int) -> void:
		_control_arm_raw_pos6.value = value
	
	var _control_arm_target_x: PBField
	func get_control_arm_target_x() -> float:
		return _control_arm_target_x.value
	func clear_control_arm_target_x() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_target_x.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_control_arm_target_x(value : float) -> void:
		_control_arm_target_x.value = value
	
	var _control_arm_target_y: PBField
	func get_control_arm_target_y() -> float:
		return _control_arm_target_y.value
	func clear_control_arm_target_y() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_target_y.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_control_arm_target_y(value : float) -> void:
		_control_arm_target_y.value = value
	
	var _control_arm_target_r: PBField
	func get_control_arm_target_r() -> float:
		return _control_arm_target_r.value
	func clear_control_arm_target_r() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_target_r.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_control_arm_target_r(value : float) -> void:
		_control_arm_target_r.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SCVisionMessage:
	func _init():
		var service
		
		_cmd = PBField.new("cmd", PB_DATA_TYPE.ENUM, PB_RULE.REQUIRED, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _cmd
		data[_cmd.tag] = service
		
	var data = {}
	
	var _cmd: PBField
	func get_cmd():
		return _cmd.value
	func clear_cmd() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_cmd.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_cmd(value) -> void:
		_cmd.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SCArmMessage:
	func _init():
		var service
		
		_cmd = PBField.new("cmd", PB_DATA_TYPE.ENUM, PB_RULE.REQUIRED, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _cmd
		data[_cmd.tag] = service
		
		_control_arm_raw_pos1 = PBField.new("control_arm_raw_pos1", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos1
		data[_control_arm_raw_pos1.tag] = service
		
		_control_arm_raw_pos2 = PBField.new("control_arm_raw_pos2", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos2
		data[_control_arm_raw_pos2.tag] = service
		
		_control_arm_raw_pos3 = PBField.new("control_arm_raw_pos3", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos3
		data[_control_arm_raw_pos3.tag] = service
		
		_control_arm_raw_pos4 = PBField.new("control_arm_raw_pos4", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos4
		data[_control_arm_raw_pos4.tag] = service
		
		_control_arm_raw_pos5 = PBField.new("control_arm_raw_pos5", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos5
		data[_control_arm_raw_pos5.tag] = service
		
		_control_arm_raw_pos6 = PBField.new("control_arm_raw_pos6", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 7, false, DEFAULT_VALUES_2[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _control_arm_raw_pos6
		data[_control_arm_raw_pos6.tag] = service
		
		_control_arm_target_x = PBField.new("control_arm_target_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _control_arm_target_x
		data[_control_arm_target_x.tag] = service
		
		_control_arm_target_y = PBField.new("control_arm_target_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _control_arm_target_y
		data[_control_arm_target_y.tag] = service
		
		_control_arm_target_r = PBField.new("control_arm_target_r", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 10, false, DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = _control_arm_target_r
		data[_control_arm_target_r.tag] = service
		
	var data = {}
	
	var _cmd: PBField
	func get_cmd():
		return _cmd.value
	func clear_cmd() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_cmd.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_cmd(value) -> void:
		_cmd.value = value
	
	var _control_arm_raw_pos1: PBField
	func get_control_arm_raw_pos1() -> int:
		return _control_arm_raw_pos1.value
	func clear_control_arm_raw_pos1() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos1.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos1(value : int) -> void:
		_control_arm_raw_pos1.value = value
	
	var _control_arm_raw_pos2: PBField
	func get_control_arm_raw_pos2() -> int:
		return _control_arm_raw_pos2.value
	func clear_control_arm_raw_pos2() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos2.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos2(value : int) -> void:
		_control_arm_raw_pos2.value = value
	
	var _control_arm_raw_pos3: PBField
	func get_control_arm_raw_pos3() -> int:
		return _control_arm_raw_pos3.value
	func clear_control_arm_raw_pos3() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos3.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos3(value : int) -> void:
		_control_arm_raw_pos3.value = value
	
	var _control_arm_raw_pos4: PBField
	func get_control_arm_raw_pos4() -> int:
		return _control_arm_raw_pos4.value
	func clear_control_arm_raw_pos4() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos4.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos4(value : int) -> void:
		_control_arm_raw_pos4.value = value
	
	var _control_arm_raw_pos5: PBField
	func get_control_arm_raw_pos5() -> int:
		return _control_arm_raw_pos5.value
	func clear_control_arm_raw_pos5() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos5.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos5(value : int) -> void:
		_control_arm_raw_pos5.value = value
	
	var _control_arm_raw_pos6: PBField
	func get_control_arm_raw_pos6() -> int:
		return _control_arm_raw_pos6.value
	func clear_control_arm_raw_pos6() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_raw_pos6.value = DEFAULT_VALUES_2[PB_DATA_TYPE.INT32]
	func set_control_arm_raw_pos6(value : int) -> void:
		_control_arm_raw_pos6.value = value
	
	var _control_arm_target_x: PBField
	func get_control_arm_target_x() -> float:
		return _control_arm_target_x.value
	func clear_control_arm_target_x() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_target_x.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_control_arm_target_x(value : float) -> void:
		_control_arm_target_x.value = value
	
	var _control_arm_target_y: PBField
	func get_control_arm_target_y() -> float:
		return _control_arm_target_y.value
	func clear_control_arm_target_y() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_target_y.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_control_arm_target_y(value : float) -> void:
		_control_arm_target_y.value = value
	
	var _control_arm_target_r: PBField
	func get_control_arm_target_r() -> float:
		return _control_arm_target_r.value
	func clear_control_arm_target_r() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_control_arm_target_r.value = DEFAULT_VALUES_2[PB_DATA_TYPE.FLOAT]
	func set_control_arm_target_r(value : float) -> void:
		_control_arm_target_r.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SCMonitorMessage:
	func _init():
		var service
		
		_cmd = PBField.new("cmd", PB_DATA_TYPE.ENUM, PB_RULE.REQUIRED, 1, false, DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _cmd
		data[_cmd.tag] = service
		
		_color_image = PBField.new("color_image", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = _color_image
		data[_color_image.tag] = service
		
		_sim_depth_image = PBField.new("sim_depth_image", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 3, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = _sim_depth_image
		data[_sim_depth_image.tag] = service
		
		_syn_depth_image = PBField.new("syn_depth_image", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 4, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = _syn_depth_image
		data[_syn_depth_image.tag] = service
		
		_pred_result_json = PBField.new("pred_result_json", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, false, DEFAULT_VALUES_2[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _pred_result_json
		data[_pred_result_json.tag] = service
		
		_client_arm_online = PBField.new("client_arm_online", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 6, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = _client_arm_online
		data[_client_arm_online.tag] = service
		
		_client_vision_online = PBField.new("client_vision_online", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 7, false, DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = _client_vision_online
		data[_client_vision_online.tag] = service
		
	var data = {}
	
	var _cmd: PBField
	func get_cmd():
		return _cmd.value
	func clear_cmd() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_cmd.value = DEFAULT_VALUES_2[PB_DATA_TYPE.ENUM]
	func set_cmd(value) -> void:
		_cmd.value = value
	
	var _color_image: PBField
	func get_color_image() -> PackedByteArray:
		return _color_image.value
	func clear_color_image() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_color_image.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
	func set_color_image(value : PackedByteArray) -> void:
		_color_image.value = value
	
	var _sim_depth_image: PBField
	func get_sim_depth_image() -> PackedByteArray:
		return _sim_depth_image.value
	func clear_sim_depth_image() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_sim_depth_image.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
	func set_sim_depth_image(value : PackedByteArray) -> void:
		_sim_depth_image.value = value
	
	var _syn_depth_image: PBField
	func get_syn_depth_image() -> PackedByteArray:
		return _syn_depth_image.value
	func clear_syn_depth_image() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_syn_depth_image.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BYTES]
	func set_syn_depth_image(value : PackedByteArray) -> void:
		_syn_depth_image.value = value
	
	var _pred_result_json: PBField
	func get_pred_result_json() -> String:
		return _pred_result_json.value
	func clear_pred_result_json() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_pred_result_json.value = DEFAULT_VALUES_2[PB_DATA_TYPE.STRING]
	func set_pred_result_json(value : String) -> void:
		_pred_result_json.value = value
	
	var _client_arm_online: PBField
	func get_client_arm_online() -> bool:
		return _client_arm_online.value
	func clear_client_arm_online() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_client_arm_online.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_client_arm_online(value : bool) -> void:
		_client_arm_online.value = value
	
	var _client_vision_online: PBField
	func get_client_vision_online() -> bool:
		return _client_vision_online.value
	func clear_client_vision_online() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_client_vision_online.value = DEFAULT_VALUES_2[PB_DATA_TYPE.BOOL]
	func set_client_vision_online(value : bool) -> void:
		_client_vision_online.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################

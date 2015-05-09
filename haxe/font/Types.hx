package font;

// var check = require('./check');

class Types
{
	public static var LIMIT16 = 32768; // The limit at which a 16-bit number switches signs == 2^15
	public static var LIMIT32 = 2147483648; // The limit at which a 32-bit number switches signs == 2 ^ 31
    
	public var decode = {};
	public var encode = {};
	public var sizeOf = {};
	
}

class Encode
{
	// OpenType data types //////////////////////////////////////////////////////

	// Convert an 8-bit unsigned integer to a list of 1 byte.
	public function BYTE (v)
	{
		check.argument(v >= 0 && v <= 255, 'Byte value should be between 0 and 255.');
		return [v];
	}

	// Convert a 8-bit signed integer to a list of 1 byte.
	public function CHAR (v)
	{
		return [v.charCodeAt(0)];
	}

	// Convert an ASCII string to a list of bytes.
	public function CHARARRAY (v)
	{
		var b = [];
		for (var i = 0; i < v.length; i += 1)
		{
			b.push(v.charCodeAt(i));
		}
		return b;
	}

	// Convert a 16-bit unsigned integer to a list of 2 bytes.
	public function USHORT (v)
	{
		return [(v >> 8) & 0xFF, v & 0xFF];
	}

	// Convert a 16-bit signed integer to a list of 2 bytes.
	public function SHORT (v)
	{
		// Two's complement
		if (v >= LIMIT16){
			v = - ( 2 * LIMIT16 - v);
		}
		return [(v >> 8) & 0xFF, v & 0xFF];
	}

	// Convert a 24-bit unsigned integer to a list of 3 bytes.
	public function UINT24 (v)
	{
		return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
	}

	// Convert a 32-bit unsigned integer to a list of 4 bytes.
	public function ULONG (v)
	{
		return [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
	}

	// Convert a 32-bit unsigned integer to a list of 4 bytes.
	public function LONG (v)
	{
		// Two's complement
		if (v >= LIMIT32)
		{
			v = - ( 2 * LIMIT32 - v);
		}
		return [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
	}

	public function FWORD = SHORT;

	public function UFWORD = USHORT;


	// FIXME Implement LONGDATETIME
	public function LONGDATETIME ():Array<Int>
	{
		return [0, 0, 0, 0, 0, 0, 0, 0];
	}

	// Convert a 4-char tag to a list of 4 bytes.
	public function TAG (v:String):Array<Int>
	{
		if (v.length > 4) return null;
		return [v.charCodeAt (0), v.charCodeAt (1), v.charCodeAt (2), v.charCodeAt (3)];
	}

	public function FIXED = ULONG;

	// CFF data types ///////////////////////////////////////////////////////////

	public function Card8 = BYTE;

	public function Card16 = USHORT;

	public function OffSize = BYTE;

	public function SID = USHORT;

	// Convert a numeric operand or charstring number to a variable-size list of bytes.
	public function NUMBER (v)
	{
		if (v >= -107 && v <= 107)
		{
			return [v + 139];
		}
		
		if (v >= 108 && v <= 1131)
		{
			v = v - 108;
			return [(v >> 8) + 247, v & 0xFF];
		}
		
		if (v >= -1131 && v <= -108)
		{
			v = -v - 108;
			return [(v >> 8) + 251, v & 0xFF];
		}
		
		if (v >= -32768 && v <= 32767)
			return NUMBER16(v);
		
		return NUMBER32(v);
	}

	// Convert a signed number between -32768 and +32767 to a three-byte value.
	// This ensures we always use three bytes, but is not the most compact format.
	public function NUMBER16 (v)
	{
		return [28, (v >> 8) & 0xFF, v & 0xFF];
	}
	
	// Convert a signed number between -(2^31) and +(2^31-1) to a four-byte value.
	// This is useful if you want to be sure you always use four bytes,
	// at the expense of wasting a few bytes for smaller numbers.
	public function NUMBER32 (v)
	{
		return [29, (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
	}
	
	public function NAME = CHARARRAY;

	public function STRING = CHARARRAY;

	// Convert a ASCII string to a list of UTF16 bytes.
	public function UTF16 (v) {
		var b = [];
		for (var i = 0; i < v.length; i += 1) {
			b.push(0);
			b.push(v.charCodeAt(i));
		}
		return b;
	};

	// Convert a list of values to a CFF INDEX structure.
	// The values should be objects containing name / type / value.
	public function INDEX (l) {
		var offSize, offset, offsets, offsetEncoder, encodedOffsets, encodedOffset, data,
			dataSize, i, v;
		// Because we have to know which data type to use to encode the offsets,
		// we have to go through the values twice: once to encode the data and
		// calculate the offets, then again to encode the offsets using the fitting data type.
		offset = 1; // First offset is always 1.
		offsets = [offset];
		data = [];
		dataSize = 0;
		
		for (i in 0 ... l.length)
		{
			v = encode.OBJECT(l[i]);
			Array.prototype.push.apply(data, v);
			dataSize += v.length;
			offset += v.length;
			offsets.push (offset);
		}

		if (data.length === 0)
			return [0, 0];

		encodedOffsets = [];
		offSize = (1 + Math.floor(Math.log(dataSize)/Math.log(2)) / 8) | 0;
		offsetEncoder = [undefined, encode.BYTE, encode.USHORT, encode.UINT24, encode.ULONG][offSize];
		for (i in 0 ... offsets.length)
		{
			encodedOffset = offsetEncoder (offsets[i]);
			Array.prototype.push.apply (encodedOffsets, encodedOffset);
		}
		
		return Array.prototype.concat(encode.Card16(l.length), 
							   encode.OffSize(offSize),
							   encodedOffsets,
							   data);
	};

	// Convert an object to a CFF DICT structure.
	// The keys should be numeric.
	// The values should be objects containing name / type / value.
	public static function DICT (m)
	{
		var d = [];
		var keys = Object.keys(m);
		var length = keys.length;

		for (i in 0 ... length)
		{
			// Object.keys() return string keys, but our keys are always numeric.
			var k = parseInt(keys[i], 0);
			var v = m[k];
			// Value comes before the key.
			d = d.concat(encode.OPERAND(v.value, v.type));
			d = d.concat(encode.OPERATOR(k));
		}

		return d;
	};

	public static function OPERATOR (v) {
		if (v < 1200) {
			return [v];
		} else {
			return [12, v - 1200];
		}
	};

	public static function OPERAND (v, type) {
		var d, i;
		d = [];
		if (Array.isArray(type)) {
			for (i = 0; i < type.length; i += 1) {
				check.argument(v.length === type.length, 'Not enough arguments given for type' + type);
				d = d.concat(encode.OPERAND(v[i], type[i]));
			}
		} else {
			if (type === 'SID') {
				d = d.concat(encode.NUMBER(v));
			} else if (type === 'offset') {
				// We make it easy for ourselves and always encode offsets as
				// 4 bytes. This makes offset calculation for the top dict easier.
				d = d.concat(encode.NUMBER32(v));
			} else {
				// FIXME Add support for booleans
				d = d.concat(encode.NUMBER(v));
			}
		}
		return d;
	};

	public static function OP = BYTE;

	// memoize charstring encoding using WeakMap if available
	var wmm = typeof WeakMap === 'function' && new WeakMap();
	// Convert a list of CharString operations to bytes.
	public static function CHARSTRING (ops)
	{
		if ( wmm && wmm.has( ops ) ) {
			return wmm.get( ops );
		}

		var d = [],
			length = ops.length,
			op,
			i;

		for (i = 0; i < length; i += 1) {
			op = ops[i];
			d = d.concat( encode[op.type](op.value) );
		}

		if ( wmm ) {
			wmm.set( ops, d );
		}

		return d;
	};

	// Utility functions ////////////////////////////////////////////////////////

	// Convert an object containing name / type / value to bytes.
	public static function OBJECT (v) {
		var encodingFunction = encode[v.type];
		check.argument(encodingFunction !== undefined, 'No encoding function for type ' + v.type);
		return encodingFunction(v.value);
	};

	// Convert a table object to bytes.
	// A table contains a list of fields containing the metadata (name, type and default value).
	// The table itself has the field values set as attributes.
	public static function TABLE (table)
	{
		var d = [];
		var length = table.fields.length;
		
		for (i = 0; i < length; i += 1) {
			var field = table.fields[i];
			var encodingFunction = encode[field.type];
			check.argument(encodingFunction !== undefined, 'No encoding function for field type ' + field.type);
			var value = table[field.name];
			if (value === undefined) {
				value = field.value;
			}
			var bytes = encodingFunction(value);
			d = d.concat(bytes);
		}
		return d;
	}

	// Merge in a list of bytes.
	public static function LITERAL (v)
	{
		return v;
	}
}

class SizeOf
{
	public function BYTE ()
	{
		return 1;
	}

	public function CHARARRAY (v)
	{
		return v.length;
	}

	public function USHORT ()
	{
		return 2;
	}

	public function SHORT ()
	{
		return 2;
	}

	public function UINT24 ()
	{
		return 3;
	}

	public function ULONG ()
	{
		return 4;
	}
	
	public function LONG ()
	{
		return 4;
	}
	
	public function NAME = CHARARRAY;
	public function STRING = CHARARRAY;
	
	public function FIXED = ULONG;
	
	public function FWORD = SHORT;
	
	public function UFWORD = USHORT;

	public function LONGDATETIME ()
	{
		return 8;
	}

	public function TAG ()
	{
		return 4;
	}
	
	public function Card8 = BYTE;
	
	public function Card16 = USHORT;
	
	public function OffSize = BYTE;
	
	public function SID = USHORT;

	public function NUMBER (v)
	{
		return encode.NUMBER(v).length;
	}
	
	public function NUMBER16 ()
	{
		return 2;
	}
	
	public function NUMBER32 ()
	{
		return 4;
	}
	
	public function UTF16 (v)
	{
		return v.length * 2;
	}

	public function INDEX (v)
	{
		return encode.INDEX(v).length;
	}

	public function DICT (m)
	{
		return encode.DICT(m).length;
	}
	
	public function OP = BYTE;

	public function CHARSTRING (ops)
	{
		return encode.CHARSTRING(ops).length;
	}

	public function LITERAL (v)
	{
		return v.length;
	}
}
	// exports.decode = decode;
	// exports.encode = encode;
	// exports.public function = 
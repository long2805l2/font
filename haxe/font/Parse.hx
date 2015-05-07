package font;

class Parser
{

	// Retrieve an unsigned byte from the DataView.
	public static function getByte (dataView, offset)
	{
		return dataView.getUint8(offset);
	}

	public static function getCard8 = exports.getByte;

	// Retrieve an unsigned 16-bit short from the DataView.
	// The value is stored in big endian.
	public static function getUShort (dataView, offset)
	{
		return dataView.getUint16(offset, false);
	}

	public static function getCard16 = exports.getUShort;

	// Retrieve a signed 16-bit short from the DataView.
	// The value is stored in big endian.
	public static getShort (dataView, offset)
	{
		return dataView.getInt16(offset, false);
	}

	// Retrieve an unsigned 32-bit long from the DataView.
	// The value is stored in big endian.
	public static getULong (dataView, offset)
	{
		return dataView.getUint32(offset, false);
	};

	// Retrieve a 32-bit signed fixed-point number (16.16) from the DataView.
	// The value is stored in big endian.
	public static getFixed (dataView, offset)
	{
		var decimal, fraction;
		decimal = dataView.getInt16(offset, false);
		fraction = dataView.getUint16(offset + 2, false);
		return decimal + fraction / 65535;
	};

	// Retrieve a 4-character tag from the DataView.
	// Tags are used to identify tables.
	public static getTag (dataView, offset) 
	{
		var tag = '', i;
		for (i = offset; i < offset + 4; i += 1)
		{
			tag += String.fromCharCode(dataView.getInt8(i));
		}
		return tag;
	};

	// Retrieve an offset from the DataView.
	// Offsets are 1 to 4 bytes in length, depending on the offSize argument.
	public static getOffset (dataView, offset, offSize)
	{
		var i, v;
		v = 0;
		for (i = 0; i < offSize; i += 1) {
			v <<= 8;
			v += dataView.getUint8(offset + i);
		}
		return v;
	};

	// Retrieve a number of bytes from start offset to the end offset from the DataView.
	public static getBytes (dataView, startOffset, endOffset)
	{
		var bytes, i;
		bytes = [];
		for (i = startOffset; i < endOffset; i += 1) {
			bytes.push(dataView.getUint8(i));
		}
		return bytes;
	};

	// Convert the list of bytes to a string.
	public static bytesToString (bytes)
	{
		var s, i;
		s = '';
		for (i = 0; i < bytes.length; i += 1)
		{
			s += String.fromCharCode(bytes[i]);
		}
		return s;
	};

	var typeOffsets = {
		byte: 1,
		uShort: 2,
		short: 2,
		uLong: 4,
		fixed: 4,
		longDateTime: 8,
		tag: 4
	};

	// A stateful parser that changes the offset whenever a value is retrieved.
	// The data is a DataView.
	function Parser(data, offset)
	{
		this.data = data;
		this.offset = offset;
		this.relativeOffset = 0;
	}

	public function parseByte ()
	{
		var v = this.data.getUint8(this.offset + this.relativeOffset);
		this.relativeOffset += 1;
		return v;
	}

	public function parseChar ()
	{
		var v = this.data.getInt8(this.offset + this.relativeOffset);
		this.relativeOffset += 1;
		return v;
	}

	public function parseCard8 = parseByte;

	public function parseUShort () {
		var v = this.data.getUint16(this.offset + this.relativeOffset);
		this.relativeOffset += 2;
		return v;
	};
	public function parseCard16 = parseUShort;
	public function parseSID = parseUShort;
	public function parseOffset16 = parseUShort;

	public function parseShort ()
	{
		var v = this.data.getInt16(this.offset + this.relativeOffset);
		this.relativeOffset += 2;
		return v;
	}

	public function parseF2Dot14 ()
	{
		var v = this.data.getInt16(this.offset + this.relativeOffset) / 16384;
		this.relativeOffset += 2;
		return v;
	}

	public function parseULong ()
	{
		var v = exports.getULong(this.data, this.offset + this.relativeOffset);
		this.relativeOffset += 4;
		return v;
	}

	public function parseFixed ()
	{
		var v = exports.getFixed(this.data, this.offset + this.relativeOffset);
		this.relativeOffset += 4;
		return v;
	}

	public function parseUShortList (count)
	{
		var offsets = [];
		var dataView = this.data;
		var offset = this.offset + this.relativeOffset;
		
		for (i in 0 ... count)
		{
			offsets[i] = exports.getUShort(dataView, offset);
			offset += 2;
		}
		this.relativeOffset += count * 2;
		return offsets;
	}

	public function parseOffset16List = parseUShortList;

	public function parseString (length)
	{
		var dataView = this.data,
			offset = this.offset + this.relativeOffset,
			string = '';
		this.relativeOffset += length;
		for (var i = 0; i < length; i++)
		{
			string += String.fromCharCode(dataView.getUint8(offset + i));
		}
		return string;
	}

	public function parseTag ()
	{
		return this.parseString(4);
	}

	// LONGDATETIME is a 64-bit integer.
	// JavaScript and unix timestamps traditionally use 32 bits, so we
	// only take the last 32 bits.
	public function parseLongDateTime = function()
	{
		var v = exports.getULong(this.data, this.offset + this.relativeOffset + 4);
		this.relativeOffset += 8;
		return v;
	}

	public function parseFixed = function()
	{
		var v = exports.getULong(this.data, this.offset + this.relativeOffset);
		this.relativeOffset += 4;
		return v / 65536;
	}

	public function parseVersion = function()
	{
		var major = exports.getUShort(this.data, this.offset + this.relativeOffset);
		// How to interpret the minor version is very vague in the spec. 0x5000 is 5, 0x1000 is 1
		// This returns the correct number if minor = 0xN000 where N is 0-9
		var minor = exports.getUShort(this.data, this.offset + this.relativeOffset + 2);
		this.relativeOffset += 4;
		return major + minor / 0x1000 / 10;
	}

	public function skip (type, amount)
	{
		if (amount == null) amount = 1;
		this.relativeOffset += typeOffsets[type] * amount;
	}
}
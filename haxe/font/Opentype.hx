package font;
import Encoding.CmapEncoding;
import Encoding.GlyphNames;

// var _font = require('./font');
// var glyph = require('./glyph');
// var parse = require('./parse');
// var path = require('./path');
// var cmap = require('./tables/cmap');
// var cff = require('./tables/cff');
// var glyf = require('./tables/glyf');
// var gpos = require('./tables/gpos');
// var head = require('./tables/head');
// var hhea = require('./tables/hhea');
// var hmtx = require('./tables/hmtx');
// var kern = require('./tables/kern');
// var loca = require('./tables/loca');
// var maxp = require('./tables/maxp');
// var _name = require('./tables/name');
// var os2 = require('./tables/os2');
// var post = require('./tables/post');

class OpenType
{
	// File loaders /////////////////////////////////////////////////////////

	// Convert a Node.js Buffer to an ArrayBuffer
	public function toArrayBuffer (buffer)
	{
		var arrayBuffer = new ArrayBuffer (buffer.length);
		var data = new Uint8Array (arrayBuffer);

		for (i = 0; i < buffer.length; i += 1)
		{
			data[i] = buffer[i];
		}

		return arrayBuffer;
	}

	public function loadFromFile(path, callback)
	{
		var fs = require('fs');
		fs.readFile(path, function (err, buffer)
		{
			if (err)
			{
				return callback(err.message);
			}

			callback(null, toArrayBuffer(buffer));
		});
	}

	public function loadFromUrl(url, callback)
	{
		var request = new XMLHttpRequest();
		request.open('get', url, true);
		request.responseType = 'arraybuffer';
		request.onload = function ()
		{
			if (request.status !== 200)
			{
				return callback('Font could not be loaded: ' + request.statusText);
			}
			return callback(null, request.response);
		};
		request.send();
	}

	// Public API ///////////////////////////////////////////////////////////

	// Parse the OpenType file data (as an ArrayBuffer) and return a Font object.
	// If the file could not be parsed (most likely because it contains Postscript outlines)
	// we return an empty Font object with the `supported` flag set to `false`.
	public function parseBuffer(buffer)
	{
		var font, data, version, numTables, i, p, tag, offset, hmtxOffset, glyfOffset, locaOffset,
			cffOffset, kernOffset, gposOffset, indexToLocFormat, numGlyphs, locaTable,
			shortVersion;
		// OpenType fonts use big endian byte ordering.
		// We can't rely on typed array view types, because they operate with the endianness of the host computer.
		// Instead we use DataViews where we can specify endianness.

		font = new _font.Font();
		data = new DataView(buffer, 0);

		version = parse.getFixed(data, 0);
		if (version === 1.0)
		{
			font.outlinesFormat = 'truetype';
		}
		else
		{
			version = parse.getTag(data, 0);
			if (version === 'OTTO')
			{
				font.outlinesFormat = 'cff';
			}
			else
			{
				throw new Error('Unsupported OpenType version ' + version);
			}
		}

		numTables = parse.getUShort(data, 4);

		// Offset into the table records.
		p = 12;
		for (i = 0; i < numTables; i += 1)
		{
			tag = parse.getTag(data, p);
			offset = parse.getULong(data, p + 8);
			switch (tag)
			{
				case 'cmap':
				font.tables.cmap = cmap.parse (data, offset);
				font.encoding = new CmapEncoding (font.tables.cmap);
				if (!font.encoding)
				{
					font.supported = false;
				}
				
				case 'head':
				font.tables.head = head.parse(data, offset);
				font.unitsPerEm = font.tables.head.unitsPerEm;
				indexToLocFormat = font.tables.head.indexToLocFormat;
				
				case 'hhea':
				font.tables.hhea = hhea.parse(data, offset);
				font.ascender = font.tables.hhea.ascender;
				font.descender = font.tables.hhea.descender;
				font.numberOfHMetrics = font.tables.hhea.numberOfHMetrics;
				
				case 'hmtx':
				hmtxOffset = offset;
				
				case 'maxp':
				font.tables.maxp = maxp.parse(data, offset);
				font.numGlyphs = numGlyphs = font.tables.maxp.numGlyphs;
				
				case 'name':
				font.tables.name = _name.parse(data, offset);
				font.familyName = font.tables.name.fontFamily;
				font.styleName = font.tables.name.fontSubfamily;
				
				case 'OS/2':
				font.tables.os2 = os2.parse(data, offset);
				
				case 'post':
				font.tables.post = post.parse(data, offset);
				font.glyphNames = new GlyphNames(font.tables.post);
				
				case 'glyf':
				glyfOffset = offset;
				
				case 'loca':
				locaOffset = offset;
				
				case 'CFF ':
				cffOffset = offset;
				
				case 'kern':
				kernOffset = offset;
				
				case 'GPOS':
				gposOffset = offset;
			}
			p += 16;
		}

		if (glyfOffset && locaOffset)
		{
			shortVersion = indexToLocFormat === 0;
			locaTable = loca.parse(data, locaOffset, numGlyphs, shortVersion);
			font.glyphs = glyf.parse(data, glyfOffset, locaTable, font);
			hmtx.parse(data, hmtxOffset, font.numberOfHMetrics, font.numGlyphs, font.glyphs);
			Encoding.addGlyphNames(font);
		}
		else if (cffOffset)
		{
			cff.parse(data, cffOffset, font);
			Encoding.addGlyphNames(font);
		}
		else
		{
			font.supported = false;
		}

		if (font.supported)
		{
			if (kernOffset)
			{
				font.kerningPairs = kern.parse(data, kernOffset);
			}
			else
			{
				font.kerningPairs = {};
			}

			if (gposOffset)
			{
				gpos.parse(data, gposOffset, font);
			}
		}

		return font;
	}

	// Asynchronously load the font from a URL or a filesystem. When done, call the callback
	// with two arguments `(err, font)`. The `err` will be null on success,
	// the `font` is a Font object.
	//
	// We use the node.js callback convention so that
	// opentype.js can integrate with frameworks like async.js.
	public function load (url, callback)
	{
		var isNode = typeof window === 'undefined';
		var loadFn = isNode ? loadFromFile : loadFromUrl;
		loadFn(url, function (err, arrayBuffer)
		{
			if (err)
			{
				return callback(err);
			}

			var font = parseBuffer(arrayBuffer);
			if (!font.supported)
			{
				return callback('Font is not supported (is this a Postscript font?)');
			}
			return callback(null, font);
		});
	}

	// exports.Font = _font.Font;
	// exports.Glyph = glyph.Glyph;
	// exports.Path = path.Path;
	// exports.parse = parseBuffer;
	// exports.load = load;
}